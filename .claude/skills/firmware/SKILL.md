---
name: firmware
description: Build, flash, or debug the PrintTrek ESPHome firmware (esphome config/compile/run/logs, secrets setup, adding packages to a node config). Use when the user wants firmware built or flashed, is editing esphome/*.yaml, or is adding support for new sensors/actuators.
---

# PrintTrek firmware workflow

## Setup

```bash
cp esphome/secrets.yaml.example esphome/secrets.yaml   # then edit real values
```

## Build / flash

```bash
nix develop -c esphome config esphome/example-trailer.yaml   # fast validation
nix develop -c esphome compile esphome/example-trailer.yaml  # full C++ build
nix develop -c esphome run esphome/example-trailer.yaml      # flash via USB/OTA
nix develop -c esphome logs esphome/example-trailer.yaml
```

Sandbox note: nixpkgs' platformio wrapper needs user namespaces. If compile
fails with `bwrap: ... Operation not permitted`, use a pip venv instead:
`python3 -m venv .venv && .venv/bin/pip install esphome && .venv/bin/esphome compile ...`

`esphome config` on both node configs is part of the verify gate
(tools/validate.py); run a full `compile` after touching lambdas — config
validation does NOT catch C++ errors.

## Editing rules (the OSS contract, see docs/EXTENDING.md)

- NEVER put user-specific tweaks in `trailer-base.yaml` or
  `packages/*.yaml` — node configs override via substitutions.
- New hardware = new package file in `esphome/packages/`, documented header,
  substitutions with sane defaults. Follow the id contracts:
  `battery_voltage`, `water_level`, `water_pump`, `fridge_enabled`,
  `interior_temperature/humidity`, `fridge_temperature`, global
  `load_shed_tier` (0-3).
- The node is radio-always-on by default (direct HA control). Anything that
  must survive storage mode (radio off): local automation + flash-restored
  setpoint with `command_retain: true` — setpoints only, never raw
  actuators (replay hazard, docs/PROTOCOL.md).
- Tier ladder for new loads: comfort loads gate on tier >= 1, pump-class on
  tier >= 2, only the fridge survives to tier 3.
