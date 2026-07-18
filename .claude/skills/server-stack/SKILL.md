---
name: server-stack
description: Bring up, check, or manage the PrintTrek DEV server stack (mosquitto + Home Assistant via docker compose). Use when the user wants the dev stack running, MQTT credentials created, smoke tests, logs, or is debugging why the node isn't reaching HA. The production stack (nix on the trailer Raspberry Pi) is separate and not in this repo yet.
---

# PrintTrek dev server stack

Everything goes through `tools/stack.py` — do not run raw `docker compose`
or craft ad-hoc mosquitto commands. This stack is dev/test only; production
will be a nix-managed stack on the trailer's Raspberry Pi (HA, Grafana,
Loki, Prometheus), maintained separately.

## Commands

```bash
python3 tools/stack.py init    # once: generate server/.env + mosquitto passwd
python3 tools/stack.py up      # docker compose up -d (requires init)
python3 tools/stack.py smoke   # MQTT round trip + HA reachable
python3 tools/stack.py status
python3 tools/stack.py logs [mosquitto|homeassistant]
python3 tools/stack.py down
python3 tools/stack.py passwd <user> <password>   # extra MQTT users
```

Needs Docker on the host. `init` needs `mosquitto_passwd` (devshell:
`nix develop -c python3 tools/stack.py init`) or falls back to the docker
image. Generated secrets land in `server/.env` (gitignored).

## Endpoints after `up`

- Home Assistant: http://localhost:8123 (first boot takes ~1 min)
- MQTT: localhost:1883 (authenticated, no anonymous)

## One-time HA setup (cannot be YAML-provisioned)

After first `up`: open HA, finish onboarding, then Settings -> Devices and
Services -> Add integration -> MQTT, host `mosquitto`, credentials from
`server/.env`. The trailer package and blueprints are already mounted from
the repo's homeassistant/ directory.

## Debugging

- Node/mock connects but no entities in HA: the MQTT integration is not
  configured (see above), or discovery topics were cleared — restart the
  node/mock with `--discovery`.
- Live traffic inspection: the mock-device skill plus
  `mosquitto_sub -h localhost -u <user> -P <pass> -t 'printtrek/#' -v`.
- Auth failures: regenerate with `init` after deleting server/.env and
  server/mosquitto/passwd.
