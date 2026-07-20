---
name: protocol-test
description: Run the PrintTrek MQTT protocol integration test (throwaway authenticated mosquitto + mock device, asserts availability/retained telemetry/setpoint round trip/direct actuator echo/LWT). Use after changing tools/mock_device.py, docs/PROTOCOL.md semantics, MQTT topic layout, or anything in esphome/trailer-base.yaml's mqtt section.
---

# PrintTrek protocol integration test

Harness: esphome_skills.protocol_test. The PrintTrek entities asserted are
in tools/test_protocol.py: battery_voltage telemetry, pump_low_water_cutoff
setpoint round trip, pump_enabled switch round trip, a direct
(non-retained) exterior_lights actuator echo, plus the shared availability
and LWT steps.

```bash
nix develop -c python3 tools/test_protocol.py
```

Exit code 0 = pass. No Docker, no hardware. Runs as part of
scripts/verify_design.sh.

Keep in sync: if the contract changes, change `docs/PROTOCOL.md`,
`esphome/`, `tools/mock_device.py` and `tools/test_protocol.py` together.
Setpoints use retained commands, raw actuators never do (replay hazard).

Canonical doc and failure notes (mock log first, LWT timing):
https://github.com/heavy-oil1462/esphome-skills/blob/main/skills/protocol-test.md
