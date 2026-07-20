---
name: mock-device
description: Simulate the PrintTrek trailer node over MQTT (diurnal solar/battery physics, fridge compressor cycling, load-shed tiers, pump/tank dynamics, HA discovery, duty-cycle mode). Use for demoing/testing the server stack or Home Assistant integration without hardware, and for generating test telemetry.
---

# PrintTrek mock device

`tools/mock_device.py` is a software twin of the trailer node: same topics,
same retained/LWT semantics, same protection rules (docs/PROTOCOL.md).
Plumbing: esphome_skills.mock; the trailer physics (solar/battery, fridge
compressor, pump/tank, gates) is the repo side of the file. One simulated
day passes in 5 minutes by default.

```bash
# stack must be up; creds are read from server/.env automatically
python3 tools/mock_device.py
python3 tools/mock_device.py --scenario low-battery      # tiers escalate
python3 tools/mock_device.py --scenario heatwave         # fridge works hard
python3 tools/mock_device.py --duty-cycle --interval 30  # storage mode
python3 tools/mock_device.py --discovery                 # + HA discovery
```

Scenarios: normal, sunny, cloudy, low-battery, heatwave.

Typical uses: populate HA (stack up + mock + --discovery), test alerts
(--scenario low-battery), regression-test protocol changes (the
protocol-test skill runs this same mock under assertions).

Canonical doc and behaviours (clean exit vs SIGKILL/LWT, retained setpoint
commands):
https://github.com/heavy-oil1462/esphome-skills/blob/main/skills/mock-device.md
