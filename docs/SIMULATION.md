# Simulating the trailer — the real firmware, no hardware

PrintTrek ships a simulator that is not a re-implementation of the rules: it
is the **actual firmware**, compiled for a stock `esp32dev` board and
executed under [Espressif's QEMU fork](https://github.com/espressif/qemu),
wired to *your* MQTT broker and therefore *your* Home Assistant. The pump
protection, lights shedding, and fridge-relay decisions you observe are made
by the same C++ that runs in the trailer.

```
┌────────────────────────── podman container ──────────────────────────┐
│                                                                      │
│  ┌───────────────────────────────┐      ┌─────────────────────────┐  │
│  │ QEMU (machine esp32)          │ SNTP │ webui.py                │  │
│  │  REAL firmware:               │─────►│  · simulated clock      │  │
│  │  sim-trailer.yaml             │ :123 │  · sensor injections    │  │
│  │  = trailer-base               │      │  · live entity view     │  │
│  │  + radio-openeth (emu eth)    │      └───────────▲─────────────┘  │
│  │  + sim-sensors (injectable)   │                  │ http :8080     │
│  │  + REAL actuators/automations │                  │                │
│  └───────────────┬───────────────┘                  │                │
└──────────────────┼──────────────────────────────────┼────────────────┘
                   │ MQTT (discovery, telemetry,      │
                   ▼        retained setpoints)     browser
            YOUR broker ──► YOUR Home Assistant
```

## Quickstart

```bash
python3 tools/sim_container.py build                # once (~minutes)
python3 tools/sim_container.py run \
    --broker 192.168.1.10 --username printtrek --password ...
python3 tools/sim_container.py logs                 # firmware serial console
```

Open **http://localhost:8080**: sliders for every sensor, a time-of-day
control, presets ("Low battery (tier 2)", "Tank nearly empty", ...), and a
live view of everything the node publishes. The node appears in Home
Assistant via MQTT discovery as `printtrek-sim`, indistinguishable from
hardware — flip its light switch in HA and watch the entity react.

The first `run` compiles the firmware inside the container against your
broker settings; the `printtrek-sim-cache` volume makes later starts fast.
If the broker runs on the container host, use `--broker
host.containers.internal` (the entrypoint resolves it to an IP before baking
it into the firmware — QEMU's user-mode network can't see container DNS).

## How each input reaches the real firmware

| Input          | Mechanism |
|----------------|-----------|
| Sensor values  | Retained MQTT topics `printtrek/<node>/sim/<key>`; `packages/sim-sensors.yaml` subscribes with the **real sensor ids** (`water_level`, `battery_voltage`, ...) so the stock automation packages run unmodified |
| Time of day    | webui.py answers the firmware's SNTP queries (`sntp_server: 10.0.2.2`, re-sync every 15 s) with an offset clock — the daily pump counter resets on it |
| Setpoints & switches | Nothing special — the standard `.../command` topics (PROTOCOL.md); drive them from HA or the UI like on hardware |

Injection keys: `battery` V · `battery_current` A · `water` % ·
`temperature` degC · `humidity` % · `fridge_temp` degC. (`battery_power`
and `water_volume` are derived on-device.) Until a value is injected the
sensor has no state (NaN) and the fail-safes behave exactly as with broken
hardware: the pump refuses to run, load shedding holds its tier.

## Radio behaviour in the simulator

The node defaults to "Radio Always On", so the sim stays connected and
reacts instantly. To rehearse storage mode, press **Duty-cycled radio** (or
flip the switch in HA): an emulated NIC can't be powered down, so
`packages/radio-openeth.yaml` emulates the duty cycle at the MQTT layer —
`radio_off` publishes the retained `status: offline` (standing in for the
LWT an abrupt WiFi power-down would trigger) and disconnects; `radio_on`
reconnects. `telemetry_interval_min` is `2` in `sim-trailer.yaml`, so
windows come quickly.

## Testing "if this then that" from Home Assistant

Because the sim is a protocol-faithful node on your real broker, it is the
safe place to rehearse HA automations: point them at the `printtrek-sim`
entities, drag the battery slider to 12.3 V, and check your low-battery
alert fires; set water to 3 % and watch the pump refuse to start — driven
by the on-device rules, not HA.

## The automated version: tools/test_sim.py

The same loop, CI-style — throwaway mosquitto, web UI driven over HTTP,
assertions on the broker:

```bash
sudo -E nix develop .#sim -c python3 tools/test_sim.py
```

asserts boot/discovery, injection round-trips, direct lights control, the
low-water pump refusal, tier 1/2/3 escalation (lights shed, fridge cut),
and cascaded recovery with the fridge relay restoring itself.
Requirements: an esphome that can compile (pip fallback if the nix
platformio wrapper can't run its sandbox), `qemu-esp32` (in the `.#sim`
devshell via the `nix-qemu-espressif` flake input — kept out of the default
shell because it may build QEMU from source once), and the ability to bind
udp/123 (root/CAP_NET_BIND_SERVICE) — lwIP's SNTP port is not configurable.
Slow (a compile plus several minutes of emulated control-loop time);
deliberately not part of the default verification gate.

## Limitations

- **Not cycle-accurate**: QEMU timing is roughly wall clock, good enough for
  minute-scale control loops; don't benchmark on it.
- **GPIO goes nowhere**: relay pins drive emulated pins; observe actuators
  via their entities (which is what HA sees too).
- **Clean-disconnect offline**: see radio note above.
- **Timezone**: the UI's time slider is interpreted in `--timezone`
  (default Europe/Stockholm) — keep it equal to the firmware's `timezone`
  substitution.
- **OTA/safe-mode exist but are pointless** in a container that rebuilds
  from source each config change.
