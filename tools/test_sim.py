#!/usr/bin/env python3
"""PrintTrek simulation integration test — the REAL firmware, no hardware.

Compiles esphome/sim-trailer.yaml (actual esp32 build), boots it under
Espressif QEMU against a throwaway authenticated mosquitto, drives it through
sim/webui.py's HTTP API exactly like a person at the control panel, and
asserts that the on-device rules behave:

    1. node comes up: retained status "online" + MQTT discovery
    2. injected sensor values surface under the real sensor ids
    3. direct control: lights ON command -> lights ON state
    4. dry-run protection: water 3 % -> pump command is refused/forced off
    5. battery 12.7 V -> tier 1 sheds the lights
    6. battery 12.3 V -> tier 2;  11.8 V -> tier 3 cuts the fridge relay
    7. battery 13.4 V -> cascaded recovery; fridge relay restores itself

Needs: esphome able to *compile* (pip install esphome if the nix platformio
wrapper can't sandbox), qemu-system-xtensa with the esp32 machine (in the
devshell / QEMU_ESP32 env), mosquitto + mosquitto_passwd, paho-mqtt, and the
ability to bind udp/123 (root or CAP_NET_BIND_SERVICE) so the firmware's SNTP
can reach the simulated clock — port 123 is fixed in lwIP.

    sudo -E nix develop .#sim -c python3 tools/test_sim.py

Slow: one esp32 compile (cached in .esphome-sim/) plus several minutes of
emulated control-loop time. Not part of the default verification gate.
"""

from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from _lib import REPO_ROOT, fail, heading, mqtt_client, ok, require  # noqa: E402
from sim import _build  # noqa: E402

NODE = "printtrek-sim"
ROOT = "printtrek"
PREFIX = f"{ROOT}/{NODE}"
USER, PASSWORD = "sim", "simpass"
BROKER_PORT = 1883  # fixed: baked into the compiled firmware (10.0.2.2:1883)
NTP_PORT = 123      # fixed: lwIP SNTP always queries udp/123
WORKDIR = REPO_ROOT / ".esphome-sim"


def find_esphome() -> str:
    for candidate in (os.environ.get("ESPHOME_BIN"),
                      str(REPO_ROOT / ".venv" / "bin" / "esphome"),
                      shutil.which("esphome")):
        if candidate and Path(candidate).exists():
            return candidate
    fail("no esphome binary found (ESPHOME_BIN / .venv / PATH)")
    sys.exit(2)


def find_qemu() -> str:
    candidate = os.environ.get("QEMU_ESP32") or shutil.which(
        "qemu-system-xtensa")
    if not candidate:
        fail("qemu-system-xtensa not found — enter the devshell "
             "(nix develop .#sim) or set QEMU_ESP32=/path/to/qemu-system-xtensa")
        sys.exit(2)
    return candidate


def port_bindable(port: int, udp: bool = False) -> bool:
    kind = socket.SOCK_DGRAM if udp else socket.SOCK_STREAM
    try:
        with socket.socket(socket.AF_INET, kind) as sock:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            sock.bind(("0.0.0.0" if udp else "127.0.0.1", port))
        return True
    except OSError:
        return False


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def api(http_port: int, path: str, body: dict | None = None) -> dict:
    req = urllib.request.Request(
        f"http://127.0.0.1:{http_port}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method="POST" if body is not None else "GET")
    with urllib.request.urlopen(req, timeout=5) as resp:
        return json.loads(resp.read())


def inject(http_port: int, **values: float) -> None:
    for key, value in values.items():
        api(http_port, "/api/inject", {"key": key, "value": value})


class Collector:
    """MQTT test client collecting every message with its retain flag."""

    def __init__(self, port: int):
        self.messages: dict[str, tuple[str, bool]] = {}
        self.client = mqtt_client("simtest-watcher", USER, PASSWORD)
        self.client.on_message = self._on_message
        self.client.connect("127.0.0.1", port, keepalive=30)
        self.client.subscribe([(f"{ROOT}/#", 0), ("homeassistant/#", 0)])
        self.client.loop_start()

    def _on_message(self, _client, _userdata, msg) -> None:
        self.messages[msg.topic] = (msg.payload.decode(), bool(msg.retain))

    def wait_for(self, topic: str, predicate=lambda _v: True,
                 timeout: float = 30.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if topic in self.messages and predicate(self.messages[topic][0]):
                return self.messages[topic]
            time.sleep(0.2)
        return None

    def wait_any(self, topic_predicate, timeout: float = 30.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            for topic in list(self.messages):
                if topic_predicate(topic):
                    return topic
            time.sleep(0.2)
        return None

    def publish(self, topic: str, payload: str, retain: bool = False) -> None:
        self.client.publish(topic, payload, retain=retain)

    def stop(self) -> None:
        self.client.loop_stop()
        self.client.disconnect()


def main() -> int:
    require("mosquitto")
    require("mosquitto_passwd")
    esphome_bin = find_esphome()
    qemu_bin = find_qemu()

    if not port_bindable(BROKER_PORT):
        fail(f"tcp/{BROKER_PORT} is in use — the firmware is compiled for "
             "10.0.2.2:1883, stop whatever is listening there")
        return 2
    if not port_bindable(NTP_PORT, udp=True):
        fail(f"cannot bind udp/{NTP_PORT} (needs root or "
             "CAP_NET_BIND_SERVICE) — required for simulated firmware time")
        return 2

    failures = 0

    def check(condition: bool, label: str) -> None:
        nonlocal failures
        if condition:
            ok(label)
        else:
            fail(label)
            failures += 1

    heading("compiling the real firmware (cached in .esphome-sim/)")
    _build.sync_config(REPO_ROOT / "esphome", WORKDIR / "config")
    _build.write_secrets(WORKDIR / "config", "10.0.2.2", USER, PASSWORD)
    try:
        factory = _build.compile_firmware(WORKDIR / "config", NODE,
                                          esphome_bin=esphome_bin)
        flash = _build.make_flash_image(factory, WORKDIR / "flash.bin")
    except RuntimeError as err:
        fail(str(err))
        return 1
    ok(f"flash image ready: {flash}")

    http_port = free_port()
    with tempfile.TemporaryDirectory(prefix="printtrek-simtest-") as tmp:
        tmp_path = Path(tmp)
        passwd = tmp_path / "passwd"
        passwd.touch()
        os.chmod(passwd, 0o700)
        subprocess.run(["mosquitto_passwd", "-b", str(passwd), USER, PASSWORD],
                       check=True, capture_output=True)
        conf = tmp_path / "mosquitto.conf"
        conf.write_text(
            f"listener {BROKER_PORT}\n"
            "allow_anonymous false\n"
            f"password_file {passwd}\n"
            "persistence false\n"
            + ("user root\n" if os.geteuid() == 0 else ""))

        heading("starting broker + web UI + QEMU")
        broker = subprocess.Popen(["mosquitto", "-c", str(conf)],
                                  stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
        webui_log = (tmp_path / "webui.log").open("w")
        qemu_log = (tmp_path / "qemu.log").open("w")
        webui = qemu = None
        watcher = None
        try:
            time.sleep(0.5)
            check(broker.poll() is None,
                  f"mosquitto up on 127.0.0.1:{BROKER_PORT}")

            webui = subprocess.Popen(
                [sys.executable, str(REPO_ROOT / "sim" / "webui.py"),
                 "--broker", "127.0.0.1", "--port", str(BROKER_PORT),
                 "--username", USER, "--password", PASSWORD,
                 "--node", NODE, "--root", ROOT,
                 "--http-port", str(http_port), "--ntp-port", str(NTP_PORT)],
                stdout=webui_log, stderr=subprocess.STDOUT)
            deadline = time.time() + 15
            ui_up = False
            while time.time() < deadline and not ui_up:
                try:
                    api(http_port, "/api/state")
                    ui_up = True
                except OSError:
                    time.sleep(0.5)
            check(ui_up, f"web UI answering on 127.0.0.1:{http_port}")

            watcher = Collector(BROKER_PORT)
            # Retained injections land the moment the firmware connects.
            inject(http_port, battery=13.2, battery_current=1.0, water=80,
                   temperature=18, humidity=55, fridge_temp=4)

            qemu = subprocess.Popen(_build.qemu_cmd(qemu_bin, flash),
                                    stdout=qemu_log, stderr=subprocess.STDOUT,
                                    stdin=subprocess.DEVNULL)

            heading("1. boot: availability + discovery")
            status = watcher.wait_for(f"{PREFIX}/status",
                                      lambda v: v == "online", timeout=150)
            check(status is not None, "firmware connected: status 'online'")
            disco = watcher.wait_any(
                lambda t: t.startswith("homeassistant/")
                and f"/{NODE}/" in t and t.endswith("/config"))
            check(disco is not None, f"MQTT discovery published ({disco})")

            heading("2. injected sensors surface under real ids")
            water = watcher.wait_for(f"{PREFIX}/sensor/water_level/state",
                                     lambda v: v and abs(float(v) - 80) < 1)
            check(water is not None, "water injection 80 % -> water_level")
            batt = watcher.wait_for(f"{PREFIX}/sensor/battery_voltage/state",
                                    lambda v: v and abs(float(v) - 13.2) < .1)
            check(batt is not None, "battery injection 13.2 V -> battery_voltage")

            heading("3. direct control: lights follow HA commands")
            watcher.publish(f"{PREFIX}/switch/exterior_lights/command", "ON")
            lights = watcher.wait_for(f"{PREFIX}/switch/exterior_lights/state",
                                      lambda v: v == "ON", timeout=60)
            check(lights is not None, "lights ON command took effect")
            watcher.publish(f"{PREFIX}/switch/exterior_lights/command", "OFF")
            lights = watcher.wait_for(f"{PREFIX}/switch/exterior_lights/state",
                                      lambda v: v == "OFF", timeout=60)
            check(lights is not None, "lights OFF command took effect")

            heading("4. dry-run protection: low water blocks the pump")
            inject(http_port, water=3)
            watcher.wait_for(f"{PREFIX}/sensor/water_level/state",
                             lambda v: v and float(v) < 5, timeout=60)
            watcher.publish(f"{PREFIX}/switch/water_pump/command", "ON")
            # The automation tick (10 s) force-stops it; accept either the
            # brief ON->OFF bounce or an unchanged OFF.
            time.sleep(20)
            pump = watcher.messages.get(f"{PREFIX}/switch/water_pump/state")
            check(pump is not None and pump[0] == "OFF",
                  "pump forced/held OFF at 3 % water")
            inject(http_port, water=80)

            heading("5. tier 1 sheds the lights")
            watcher.publish(f"{PREFIX}/switch/exterior_lights/command", "ON")
            watcher.wait_for(f"{PREFIX}/switch/exterior_lights/state",
                             lambda v: v == "ON", timeout=60)
            inject(http_port, battery=12.7)
            tier = watcher.wait_for(f"{PREFIX}/sensor/load_shed_tier/state",
                                    lambda v: v and float(v) == 1, timeout=90)
            check(tier is not None, "12.7 V -> tier 1")
            lights = watcher.wait_for(f"{PREFIX}/switch/exterior_lights/state",
                                      lambda v: v == "OFF", timeout=90)
            check(lights is not None, "tier 1 forced the lights off")

            heading("6. deeper shedding cuts pump, then fridge")
            inject(http_port, battery=12.3)
            tier = watcher.wait_for(f"{PREFIX}/sensor/load_shed_tier/state",
                                    lambda v: v and float(v) == 2, timeout=90)
            check(tier is not None, "12.3 V -> tier 2")
            inject(http_port, battery=11.8)
            tier = watcher.wait_for(f"{PREFIX}/sensor/load_shed_tier/state",
                                    lambda v: v and float(v) == 3, timeout=90)
            check(tier is not None, "11.8 V -> tier 3")
            fridge = watcher.wait_for(f"{PREFIX}/binary_sensor/fridge_power/state",
                                      lambda v: v == "OFF", timeout=90)
            check(fridge is not None, "tier 3 cut the fridge relay")
            state = watcher.wait_for(f"{PREFIX}/text_sensor/load_shed_state/state",
                                     lambda v: "3" in v, timeout=60)
            check(state is not None, "load shed state text published")

            heading("7. recovery cascades; fridge restores itself")
            inject(http_port, battery=13.4)
            tier = watcher.wait_for(f"{PREFIX}/sensor/load_shed_tier/state",
                                    lambda v: v and float(v) == 0, timeout=120)
            check(tier is not None, "13.4 V -> back to Normal")
            fridge = watcher.wait_for(f"{PREFIX}/binary_sensor/fridge_power/state",
                                      lambda v: v == "ON", timeout=90)
            check(fridge is not None, "fridge relay came back without manual help")

            if failures:
                print("\n[topics seen]")
                for topic in sorted(watcher.messages):
                    print(f"  {topic} = {watcher.messages[topic][0]!r}")
                print("\n[qemu log tail]")
                print("\n".join(
                    (tmp_path / "qemu.log").read_text().splitlines()[-80:]))
                print("\n[webui log]")
                print((tmp_path / "webui.log").read_text())
        finally:
            if watcher:
                watcher.stop()
            for proc in (qemu, webui, broker):
                if proc and proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        proc.kill()
            webui_log.close()
            qemu_log.close()

    heading("summary")
    (ok if failures == 0 else fail)(f"sim test: {failures} failure(s)")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
