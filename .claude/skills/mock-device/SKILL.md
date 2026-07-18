---
name: mock-device
description: Simulate the PrintTrek trailer node over MQTT (diurnal solar/battery physics, fridge compressor cycling, load-shed tiers, pump/tank dynamics, HA discovery, duty-cycle mode). Use for demoing/testing the server stack or Home Assistant integration without hardware, and for generating test telemetry.
---

# PrintTrek mock device

`tools/mock_device.py` is a software twin of the trailer node — same topics,
same retained/LWT semantics, same local protection rules (docs/PROTOCOL.md).
One simulated day passes in 5 minutes by default.

## Run (against the local dev stack)

```bash
# stack must be up; creds are read from server/.env automatically
python3 tools/mock_device.py
python3 tools/mock_device.py --scenario low-battery      # watch tiers escalate
python3 tools/mock_device.py --scenario heatwave         # fridge works hard
python3 tools/mock_device.py --duty-cycle --interval 30  # storage-mode radio
python3 tools/mock_device.py --discovery                 # + HA MQTT discovery
python3 tools/mock_device.py --duration 120              # bounded run (CI/demo)
```

Remote broker: `--broker <host> --username <u> --password <p>`.
Scenarios: normal, sunny, cloudy, low-battery, heatwave.

## Behaviours worth knowing

- Ctrl-C / SIGTERM = clean exit (status stays "online" retained). SIGKILL =
  broker fires the LWT ("offline"), which is how you test offline alerting.
- It honors direct actuator commands (water_pump, exterior_lights) with the
  firmware's gates: lights refused at tier >= 1, pump refused at tier >= 2
  or below the low-water cutoff.
- It honors retained setpoint commands: publish to
  `printtrek/<node>/number/pump_low_water_cutoff/command` and watch the echo.
- Needs paho-mqtt: run inside `nix develop -c ...` if not installed.

## Typical uses

- Populate HA: start stack, run mock with --discovery, entities appear.
- Test HA alerts: `--discovery --scenario low-battery`, low-battery
  automation fires; kill -9 the mock for the offline alert.
- Regression-test protocol changes: the protocol-test skill runs this same
  mock under assertions.
