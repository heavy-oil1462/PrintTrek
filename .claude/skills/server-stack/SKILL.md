---
name: server-stack
description: Bring up, check, or manage the PrintTrek DEV server stack (mosquitto + Home Assistant via docker compose). Use when the user wants the dev stack running, MQTT credentials created, smoke tests, logs, or is debugging why the node isn't reaching HA. The production stack (nix on the trailer Raspberry Pi) is separate and not in this repo yet.
---

# PrintTrek dev server stack

Everything goes through `tools/stack.py` (plumbing: esphome_skills.stack);
do not run raw `docker compose` or craft ad-hoc mosquitto commands.
Services: mosquitto, homeassistant.

```bash
python3 tools/stack.py init    # once: server/.env + mosquitto passwd
python3 tools/stack.py up
python3 tools/stack.py smoke   # MQTT round trip + HA reachable
python3 tools/stack.py logs [mosquitto|homeassistant]
python3 tools/stack.py down
```

Endpoints after `up`: Home Assistant http://localhost:8123, MQTT
localhost:1883 (authenticated).

One-time HA setup that cannot be YAML-provisioned: open
http://localhost:8123, finish onboarding, add the MQTT integration (host
"mosquitto", credentials from server/.env). The compose file mounts the
repo's homeassistant/ package and blueprint dirs; tools/validate.py's ha
check keeps those mounts honest.

Canonical doc:
https://github.com/heavy-oil1462/esphome-skills/blob/main/skills/server-stack.md
