---
name: protocol-test
description: Run the PrintTrek MQTT protocol integration test (throwaway authenticated mosquitto + mock device, asserts availability/retained telemetry/setpoint round trip/direct actuator echo/LWT). Use after changing tools/mock_device.py, docs/PROTOCOL.md semantics, MQTT topic layout, or anything in esphome/trailer-base.yaml's mqtt section.
---

# PrintTrek protocol integration test

Boots a throwaway authenticated mosquitto on an ephemeral port, runs the mock
device against it, and asserts the contract in `docs/PROTOCOL.md`:

1. retained availability (`status` = online)
2. telemetry is numeric and retained (late subscriber gets it)
3. number setpoint command -> retained state echo
4. enable-switch command -> state echo
5. direct actuator command (lights) -> immediate state echo
6. SIGKILL -> broker publishes LWT `offline`

## Run

```bash
nix develop -c python3 tools/test_protocol.py
```

Exit code 0 = pass. No Docker, no hardware, no network beyond localhost.
Also runs as step 7 of `scripts/verify_design.sh` (the verify skill).

## When it fails

- The mock device's own log is printed on failure — read it first.
- `mosquitto up ...` failing: port clash is auto-avoided, so suspect the
  mosquitto binary (are you in the devshell?).
- LWT check is timing-sensitive (keepalive 2 s, allow ~15 s) — rerun once
  before digging.

## Important semantic note

The ESPHome firmware and the mock intentionally publish state on
`<prefix>/<component>/<object_id>/state` with `retain=true`, and HA
discovery uses retained commands for setpoints ONLY (never raw actuator
switches — replay hazard). If you change either side, change
`docs/PROTOCOL.md`, `esphome/`, `tools/mock_device.py`, and this test
together.
