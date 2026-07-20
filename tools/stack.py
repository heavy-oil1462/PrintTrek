#!/usr/bin/env python3
"""PrintTrek server stack management (mosquitto + Home Assistant).

Usage:
    python3 tools/stack.py init      # generate server/.env + mosquitto passwd
    python3 tools/stack.py up        # start the stack (docker compose up -d)
    python3 tools/stack.py smoke     # end-to-end health check (see below)
    python3 tools/stack.py status    # compose ps
    python3 tools/stack.py logs [service]
    python3 tools/stack.py down
    python3 tools/stack.py passwd <user> <password>   # add/update an MQTT user

`smoke` verifies the stack:
    1. MQTT round trip (authenticated publish + subscribe)
    2. Home Assistant answers on http://localhost:8123

Plumbing: esphome_skills.stack. Requires Docker on the host. `init` prefers
a local mosquitto_passwd (devshell) and falls back to running it inside the
mosquitto image. Remember the one-time UI step: add HA's MQTT integration
(host "mosquitto", credentials from server/.env); it cannot be
YAML-provisioned.
"""

from __future__ import annotations

import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project import PROJECT  # noqa: E402

from esphome_skills import stack  # noqa: E402
from esphome_skills.lib import fail, heading, mqtt_client, ok  # noqa: E402

HA_URL = "http://localhost:8123"


def smoke(project, env) -> int:
    failures = 0

    heading("1. MQTT round trip")
    received: list[str] = []
    client = mqtt_client("printtrek-smoke", env["MQTT_USER"],
                         env["MQTT_PASSWORD"])
    client.on_message = \
        lambda _c, _u, msg: received.append(msg.payload.decode())
    try:
        client.connect(stack.MQTT_HOST, stack.MQTT_PORT, keepalive=10)
    except OSError as err:
        fail(f"cannot connect to broker: {err}")
        return 1
    client.loop_start()
    client.subscribe("printtrek/smoketest/echo")
    time.sleep(0.5)
    client.publish("printtrek/smoketest/echo", "ping")
    deadline = time.time() + 5
    while time.time() < deadline and "ping" not in received:
        time.sleep(0.1)
    if "ping" in received:
        ok("authenticated publish/subscribe round trip")
    else:
        fail("no echo received within 5 s")
        failures += 1
    client.loop_stop()
    client.disconnect()

    heading("2. Home Assistant reachable")
    reachable = False
    deadline = time.time() + 60
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(HA_URL, timeout=5) as resp:
                if resp.status == 200:
                    reachable = True
                    break
        except (urllib.error.URLError, OSError):
            pass
        time.sleep(2)
    if reachable:
        ok(f"Home Assistant answering at {HA_URL}")
    else:
        fail(f"Home Assistant not reachable at {HA_URL} within 60 s "
             "(first boot takes a minute - check: "
             "python3 tools/stack.py logs homeassistant)")
        failures += 1

    heading("summary")
    (ok if failures == 0 else fail)(f"smoke test: {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(stack.main(
        PROJECT,
        smoke=smoke,
        extra_env=lambda: {"TZ": "Europe/Stockholm"},
        endpoints={"Home Assistant": HA_URL},
        next_steps=("  * open http://localhost:8123, finish onboarding, add "
                    "the MQTT\n    integration (host: mosquitto, credentials "
                    "from server/.env)"),
        usage=__doc__,
    ))
