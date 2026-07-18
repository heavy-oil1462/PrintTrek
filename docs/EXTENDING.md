# Extending the PrintTrek control system

The firmware is adopted by **composing packages and overriding
substitutions** — never by editing `trailer-base.yaml` or the stock
packages. If you find yourself editing core files to adapt to your hardware,
that's a design bug; open an issue.

## How composition works

Your node config (start from `esphome/example-trailer.yaml`) includes
packages and overrides their substitutions:

```yaml
substitutions:
  node_name: my-trailer
  water_adc_pin: GPIO32          # overrides the package default
  pump_max_runtime_s: "300"

packages:
  base: !include trailer-base.yaml               # always
  radio: !include packages/radio-wifi.yaml       # exactly one radio package
  i2c: !include packages/bus-i2c.yaml            # once, if any I2C sensor
  battery: !include packages/sensor-battery-shunt.yaml
  pump: !include packages/actuator-pump.yaml
  water_guard: !include packages/automation-water.yaml
  my_sensor: !include packages/sensor-my-thing.yaml   # your own
```

ESPHome merges substitutions with the **including file winning**, so package
defaults are exactly that — defaults. Values you must quote: anything used
inside a lambda as a number (`"600"`, `"12.8"`).

## The id contracts

Packages talk to each other only through entity/global ids, resolved via
substitutions so any package can be swapped for a compatible one:

| id (default) | Kind | Provided by | Consumed by |
|---|---|---|---|
| `load_shed_tier` | global int 0-3 | **base** (always 0 without the load-shedding package) | every actuator/automation package |
| `radio_on` / `radio_off` | scripts | the radio package (radio-wifi, radio-openeth) | base's radio-window scheduler |
| `net_time` | time component | base | automation-water (daily counter reset) |
| `battery_voltage` | sensor (V) | sensor-battery-shunt | automation-load-shedding (`loadshed_battery_sensor`) |
| `water_level` | sensor (%) | sensor-water-level, or water-no-sensor (constant stub — pump without a level sender) | automation-water (`water_sensor`) |
| `water_pump` | switch | actuator-pump | automation-water (`water_pump_switch`) |
| `interior_temperature` / `interior_humidity` | sensors | sensor-sht3x | HA dew-point template |
| `fridge_temperature` | sensor | sensor-fridge-ds18b20 | HA warm-fridge alert |
| `bus_a` | i2c bus | bus-i2c | all I2C sensor packages |

Swapping hardware = writing a package that provides the same id. A hall-effect
flow-based level estimate, an SHTC3 instead of the SHT3x, a smart-shunt with
a serial interface — all fine as long as the id and unit match. The
simulator is the extreme case: `packages/sim-sensors.yaml` provides all the
sensor ids from MQTT injections and `packages/radio-openeth.yaml` provides
the radio scripts for an emulated NIC, and every automation runs unchanged
(docs/SIMULATION.md).

## Where does *my* node config live?

Not in this repo — node configs are downstream consumers. Two good homes:

* **A private config repo cloned inside your PrintTrek checkout** (the repo
  gitignores `printtrek-config/`). Your config is substitutions + a package
  list with `!include ../esphome/...` paths, so it always builds against the
  checkout you have:

  ```bash
  cd PrintTrek && git clone <your-private-config-repo> printtrek-config
  esphome run printtrek-config/trailer.yaml
  ```

* **ESPHome remote packages** — no local checkout needed, pin a ref:

  ```yaml
  packages:
    printtrek:
      url: https://github.com/heavy-oil1462/PrintTrek
      ref: main            # pin a tag for production
      refresh: 1d
      files: [esphome/trailer-base.yaml, esphome/packages/radio-wifi.yaml, ...]
  ```

Every package file is standalone (no cross-`!include`s) and `!secret` always
resolves against *your* config's secrets.yaml, so both forms work unchanged.

## Radio (transport) packages

`trailer-base.yaml` never touches wifi directly. It drives the duty cycle
through two scripts that exactly one included radio package must provide:

* `radio_on` — bring the transport up
* `radio_off` — take it down (called only when "Radio Always On" is off)

`packages/radio-wifi.yaml` is the hardware implementation (wifi +
wifi.enable/disable + RSSI diagnostics); `packages/radio-openeth.yaml` the
QEMU one (MQTT-layer disconnect). A wired-ethernet node is a new radio
package, not a base edit. Keep `reboot_timeout: 0s` semantics: a node must
never reboot just because the network is absent.

## Writing a sensor package

`packages/sensor-outside-ds18b20.yaml`:

```yaml
# =============================================================================
# PrintTrek — packages/sensor-outside-ds18b20.yaml
# Outside-air DS18B20 on its own 1-wire pin.
# Substitutions:
#   outside_onewire_pin  (default GPIO5)
#   outside_update_interval  (default 60s)
# Provides: sensor id outside_temperature (degC)
# =============================================================================
substitutions:
  outside_onewire_pin: GPIO5
  outside_update_interval: 60s

one_wire:
  - platform: gpio
    id: outside_onewire_bus
    pin: ${outside_onewire_pin}

sensor:
  - platform: dallas_temp
    one_wire_id: outside_onewire_bus
    name: Outside Temperature
    id: outside_temperature
    update_interval: ${outside_update_interval}
```

Conventions (enforced in review):

1. **Header block** documenting every substitution, its default, and what
   ids the package *provides* / *requires*.
2. Substitutions for every pin, threshold, and interval. Sane defaults.
3. Short `update_interval` is fine — sampling is local and nearly free.
4. Keep entity **names** stable — object_ids derived from them feed the HA
   package, dashboard, mock, and simulator (see PROTOCOL.md).

## Writing an actuator package — safety checklist

Actuators must protect themselves **locally**; assume every automation, HA,
and the network can fail at any moment:

- [ ] Fail-safe boot state (`restore_mode: ALWAYS_OFF` for pump/lights;
      the fridge relay restores ON — cold food beats a dark boot).
- [ ] A hard runtime cap on anything that draws power while active
      (see the watchdog script pattern in `actuator-pump.yaml`).
- [ ] A local tier gate: an `interval:` that forces the actuator to its safe
      state when `id(load_shed_tier)` exceeds its tier (lights: 1, pump: 2,
      fridge: 3).
- [ ] No retained MQTT commands (`command_retain` only on setpoints — replay
      hazard, PROTOCOL.md "Retention rules").

The tier ladder: tier 1 sheds comfort loads (lights), tier 2 leaves the
fridge only, tier 3 stops everything. Gate pattern:

```yaml
interval:
  - interval: 30s
    then:
      - if:
          condition:
            lambda: 'return id(load_shed_tier) >= 1 && id(awning_led).state;'
          then:
            - switch.turn_off: awning_led
```

## Writing an automation package

Follow `automation-water.yaml` as the reference: one `interval:` control
loop, all runtime knobs as `number`/`switch` template entities with
`restore_value: true` + `command_retain: true`, hard gates first (each one
actively forces the safe state, not just skips). Treat NaN sensor reads as a
fault and choose the fail-safe branch explicitly (no pumping / hold tier).

## Hooks

`automation-load-shedding.yaml` exposes a `loadshed_tier_changed` script that
runs on every tier change. Extend it from your node config without touching
the package:

```yaml
script:
  - id: !extend loadshed_tier_changed
    then:
      - if:
          condition:
            lambda: 'return id(load_shed_tier) >= 1;'
          then:
            - switch.turn_off: awning_led
```

## Home Assistant side

New entities flow through automatically via MQTT discovery. The repo's HA
package (`homeassistant/packages/trailer.yaml`) references entity ids
explicitly — extend it (and `homeassistant/dashboards/trailer.yaml`) when
you add sensors worth alerting on.

## Before you PR

```bash
nix develop -c python3 tools/validate.py        # must be green
nix develop -c python3 tools/test_protocol.py   # if you touched MQTT semantics
nix develop -c esphome compile esphome/example-trailer.yaml  # if you touched lambdas
```

If you changed protocol semantics, update `docs/PROTOCOL.md`,
`tools/mock_device.py`, and `tools/test_protocol.py` in the same PR.
