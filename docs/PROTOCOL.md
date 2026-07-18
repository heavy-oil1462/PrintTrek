# PrintTrek MQTT protocol

This document is the contract between the firmware (`esphome/`), the server
stack (`server/`), Home Assistant (`homeassistant/`), and the mock device
(`tools/mock_device.py`). `tools/test_protocol.py` asserts it. If you change
semantics here, change all of them together.

## Topic tree

All topics live under `<root>/<node>` where `root` defaults to `printtrek`
(substitution `mqtt_root`) and `node` is the ESPHome `node_name`.

```
printtrek/<node>/status                                availability (LWT/birth), retained
printtrek/<node>/sensor/<object_id>/state              numeric telemetry, retained
printtrek/<node>/text_sensor/<object_id>/state         text telemetry, retained
printtrek/<node>/binary_sensor/<object_id>/state       ON/OFF, retained
printtrek/<node>/switch/<object_id>/state              ON/OFF, retained
printtrek/<node>/switch/<object_id>/command            ON/OFF        <- HA/user writes
printtrek/<node>/number/<object_id>/state              float, retained
printtrek/<node>/number/<object_id>/command            float         <- HA/user writes
printtrek/<node>/button/<object_id>/command            PRESS
```

`object_id` is the ESPHome entity name, lowercased with underscores
("Battery Voltage" -> `battery_voltage`). These ids are **load-bearing**:
the HA package, dashboard, mock device, and simulator web UI all reference
them. Rename only with a sweep across all of them.

Simulated nodes (docs/SIMULATION.md) additionally consume a
`printtrek/<node>/sim/<key>` subtree — retained raw sensor injections for
the firmware's mqtt_subscribe twins. It is an input, not telemetry, and it
exists only when `packages/sim-sensors.yaml` is included. Real nodes have no
`sim/` topics.

## Radio modes: always-on (default) vs duty-cycled storage

The trailer node ships with **"Radio Always On" = ON**: the node stays
connected and behaves like any live ESPHome device — direct switch commands
(lights, pump) take effect immediately, which is the point of running Home
Assistant here.

Switching "Radio Always On" OFF puts the node in **storage mode**: the
radio is down by default and every `telemetry_interval_min` (default 10) it
opens a **radio window**:

```
 radio_on    --> MQTT connect --> publish "online" (retained)
             --> publish full state snapshot (every entity, retained)
             --> linger radio_linger_s (default 20 s):
                   retained setpoint commands arrive and are applied
             --> radio_off
 ...keepalive (15 s) expires --> broker publishes LWT: status = "offline"
```

`radio_on`/`radio_off` come from the node's radio package: on hardware
(`packages/radio-wifi.yaml`) they are `wifi.enable`/`wifi.disable` and the
abrupt power-down makes the broker fire the LWT one keepalive later. The
simulator (`packages/radio-openeth.yaml`) disconnects cleanly instead, so it
publishes the retained `offline` itself, immediately — same observable
protocol, slightly earlier timestamp.

Consequences, all deliberate:

* `status` means **"radio up right now"**, not "device alive". In storage
  mode a healthy node is `offline` ~95% of the time.
* Load-shed tier 2 multiplies the storage-mode period (default x3); tier 3
  drops to an hourly beacon (`loadshed_tier3_beacon_min`).
* **Device health = telemetry freshness.** A node that misses even the
  hourly beacon is genuinely down. The HA package alerts when the `uptime`
  sensor (always changing) is >90 min stale.

## Availability and Home Assistant discovery

ESPHome MQTT discovery is enabled (`homeassistant/...` prefix, retained), so
HA auto-creates every entity. The firmware **disables its birth message** and
publishes `status: online` manually. This is a deliberate trick: ESPHome only
attaches per-entity availability to discovery when birth and will messages
form a matched pair, so entities in HA **never go "unavailable"** while a
storage-mode radio sleeps — they keep their retained state and stay
editable. Do not "fix" the missing birth message.

## Retention rules

| Payload                          | Retained? | Why |
|----------------------------------|-----------|-----|
| `status`                         | yes       | late subscribers must know the last state |
| all `*/state`                    | yes       | HA must show data between radio windows |
| setpoint `*/command` (number, enable-type switches) | **yes** (`command_retain: true` in discovery) | edits made while the node sleeps are delivered at the next window |
| actuator `*/command` (pump/lights switches, buttons) | **no** | replay hazard: a retained `ON` would re-fire at every reconnect — imagine the pump starting hours after you clicked |

The asymmetry in the last two rows is a safety property, not an oversight.
With the default always-on radio it is invisible (commands land instantly
either way); in storage mode it means manual actuator control requires the
node to be online, while sleeping-safe control goes through setpoints (e.g.
`fridge_enabled`, `pump_enabled`).

Setpoints are also persisted to flash on the device (`restore_value`), so
they survive reboot and apply with no broker contact at all.

## Setpoints (retained, flash-persisted, HA-editable)

| Entity (object_id) | Type | Default | Meaning |
|---|---|---|---|
| `pump_enabled` | switch | ON | master enable for the pump relay |
| `pump_low_water_cutoff` | number, % | 5 | force pump off below this level (dry-run protection) |
| `fridge_enabled` | switch | ON | user intent for the fridge relay; relay = enabled AND tier < 3 |
| `radio_always_on` | switch | ON | live node (default) vs duty-cycled storage mode |

## Direct actuators (commands NOT retained)

| Entity (object_id) | Type | Local protection |
|---|---|---|
| `water_pump` | switch | max-runtime watchdog; refused at tier >= 2; forced off below the low-water cutoff or on sensor fault |
| `exterior_lights` | switch | auto-off watchdog (default 2 h); refused at tier >= 1 |

The fridge relay is deliberately NOT directly commandable — use
`fridge_enabled`. Its observable state is `binary_sensor/fridge_power`.

## Core telemetry (all retained)

| object_id | Unit | Source package |
|---|---|---|
| `battery_voltage` | V | sensor-battery-shunt (INA226) |
| `battery_current` | A (+ charge / - discharge) | sensor-battery-shunt |
| `battery_power` | W | sensor-battery-shunt |
| `water_level` (+ `water_level_raw_voltage`) | %, V | sensor-water-level |
| `water_volume` | L | sensor-water-level (derived) |
| `interior_temperature`, `interior_humidity` | degC, % | sensor-sht3x |
| `fridge_temperature` | degC | sensor-fridge-ds18b20 |
| `water_pump`, `exterior_lights` | ON/OFF | actuator packages |
| `fridge_power` | ON/OFF | actuator-fridge |
| `pump_used_today` | s | automation-water |
| `load_shed_tier` | 0-3 | base (numeric mirror of the global) |
| `load_shed_state` | text | automation-load-shedding |
| `wifi_rssi` | dBm | radio-wifi |
| `uptime` | s | base — freshness signal, see above |

## QoS and sessions

Everything is QoS 0 on the device side; correctness comes from retention,
not delivery guarantees — the next snapshot supersedes anything lost.

## Worked example: changing a setpoint while the node sleeps (storage mode)

1. 12:00:05 — HA user drags "Pump Low Water Cutoff" to 10. HA publishes
   `printtrek/trailer/number/pump_low_water_cutoff/command` = `10`,
   **retained**. The node is asleep; the broker stores the message.
2. 12:08:00 — node opens its radio window, connects, subscribes; broker
   delivers the retained `10`.
3. The number entity applies 10, saves it to flash, and echoes
   `.../state` = `10` (retained) — HA converges.
4. Every pump decision from this tick on uses 10, even if the broker
   burns down afterwards.
