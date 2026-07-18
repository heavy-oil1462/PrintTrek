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

Requires Docker on the host. `init` prefers a local mosquitto_passwd
(devshell) and falls back to running it inside the mosquitto image.
Remember the one-time UI step: add HA's MQTT integration (host "mosquitto",
credentials from server/.env) — it cannot be YAML-provisioned.
"""

from __future__ import annotations

import secrets as pysecrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _lib import SERVER_DIR, compose_cmd, fail, heading, load_env, ok, run, warn  # noqa: E402

ENV_FILE = SERVER_DIR / ".env"
PASSWD_FILE = SERVER_DIR / "mosquitto/passwd"

MQTT_HOST = "localhost"
MQTT_PORT = 1883
HA_URL = "http://localhost:8123"


def mosquitto_passwd(user: str, password: str, create: bool) -> bool:
    """Add/update a user in the mosquitto password file."""
    PASSWD_FILE.parent.mkdir(parents=True, exist_ok=True)
    create_flag = ["-c"] if create or not PASSWD_FILE.exists() else []
    if shutil.which("mosquitto_passwd"):
        proc = run(["mosquitto_passwd", *create_flag, "-b", str(PASSWD_FILE), user, password])
        if proc.returncode != 0:
            fail(f"mosquitto_passwd: {proc.stderr.strip()}")
            return False
        return True
    if shutil.which("docker"):
        warn("mosquitto_passwd not on PATH, using the docker image instead")
        PASSWD_FILE.touch()
        proc = run([
            "docker", "run", "--rm",
            "-v", f"{PASSWD_FILE.parent.resolve()}:/pw",
            "eclipse-mosquitto:2.0",
            "mosquitto_passwd", *create_flag, "-b", "/pw/passwd", user, password,
        ])
        if proc.returncode != 0:
            fail(f"mosquitto_passwd (docker): {proc.stderr.strip()}")
            return False
        return True
    fail("need mosquitto_passwd (nix develop) or docker to hash the password")
    return False


def cmd_init() -> int:
    if ENV_FILE.exists():
        warn(f"{ENV_FILE} already exists — leaving it untouched")
        env = load_env(ENV_FILE)
    else:
        env = {
            "MQTT_USER": "printtrek",
            "MQTT_PASSWORD": pysecrets.token_urlsafe(16),
            "TZ": "Europe/Stockholm",
        }
        ENV_FILE.write_text(
            "".join(f"{key}={value}\n" for key, value in env.items())
        )
        ok(f"wrote {ENV_FILE} with a generated password")

    if not mosquitto_passwd(env["MQTT_USER"], env["MQTT_PASSWORD"], create=True):
        return 1
    ok(f"wrote {PASSWD_FILE} for user '{env['MQTT_USER']}'")
    print(
        "\nNext steps:\n"
        "  * put MQTT credentials into esphome/secrets.yaml\n"
        "  * python3 tools/stack.py up\n"
        "  * python3 tools/stack.py smoke\n"
        "  * open http://localhost:8123, finish onboarding, add the MQTT\n"
        "    integration (host: mosquitto, credentials from server/.env)"
    )
    return 0


def ensure_initialized() -> dict[str, str]:
    if not ENV_FILE.exists() or not PASSWD_FILE.exists():
        fail("stack not initialized — run: python3 tools/stack.py init")
        sys.exit(1)
    return load_env(ENV_FILE)


def cmd_up() -> int:
    ensure_initialized()
    proc = subprocess.run([*compose_cmd(), "up", "-d"], cwd=SERVER_DIR)
    if proc.returncode != 0:
        return proc.returncode
    ok("stack started")
    print(f"Home Assistant: {HA_URL}")
    print(f"MQTT:           {MQTT_HOST}:{MQTT_PORT}")
    return 0


def cmd_down() -> int:
    return subprocess.run([*compose_cmd(), "down"], cwd=SERVER_DIR).returncode


def cmd_status() -> int:
    return subprocess.run([*compose_cmd(), "ps"], cwd=SERVER_DIR).returncode


def cmd_logs(service: str | None) -> int:
    args = [*compose_cmd(), "logs", "--tail", "100"]
    if service:
        args.append(service)
    return subprocess.run(args, cwd=SERVER_DIR).returncode


def cmd_smoke() -> int:
    env = ensure_initialized()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from _lib import mqtt_client

    failures = 0

    heading("1. MQTT round trip")
    received: list[str] = []
    client = mqtt_client("printtrek-smoke", env["MQTT_USER"], env["MQTT_PASSWORD"])
    client.on_message = lambda _c, _u, msg: received.append(msg.payload.decode())
    try:
        client.connect(MQTT_HOST, MQTT_PORT, keepalive=10)
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
             "(first boot takes a minute — check: "
             "python3 tools/stack.py logs homeassistant)")
        failures += 1

    heading("summary")
    (ok if failures == 0 else fail)(f"smoke test: {failures} failure(s)")
    return 1 if failures else 0


def main() -> int:
    argv = sys.argv[1:]
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    command = argv[0]
    if command == "init":
        return cmd_init()
    if command == "up":
        return cmd_up()
    if command == "down":
        return cmd_down()
    if command == "status":
        return cmd_status()
    if command == "logs":
        return cmd_logs(argv[1] if len(argv) > 1 else None)
    if command == "smoke":
        return cmd_smoke()
    if command == "passwd":
        if len(argv) != 3:
            fail("usage: stack.py passwd <user> <password>")
            return 2
        return 0 if mosquitto_passwd(argv[1], argv[2], create=False) else 1
    fail(f"unknown command: {command}")
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
