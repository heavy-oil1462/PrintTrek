#!/usr/bin/env python3
"""PrintTrek mock device — a software twin of the trailer's ESPHome node.

Speaks the exact MQTT contract from docs/PROTOCOL.md so you can develop and
test the server stack and Home Assistant integration without hardware:

  * LWT `<root>/<node>/status` -> "offline" (retained); "online" on connect
  * retained telemetry on `<root>/<node>/sensor/<object_id>/state`
  * retained actuator/setpoint states (switch/binary_sensor/number)
  * subscribes to `*/command` topics and echoes accepted values to the
    retained state topic, like ESPHome does — including the direct actuator
    switches (water_pump, exterior_lights), which it gates with the same
    local rules as the firmware
  * optional Home Assistant MQTT discovery (--discovery)
  * optional radio duty cycle simulation (--duty-cycle): connect, publish a
    snapshot, linger, disconnect — storage-mode behaviour (the real node is
    always-on by default)

The simulated trailer has real dynamics: solar charge follows a diurnal
curve, the fridge compressor duty-cycles and pulls the battery down at
night, the pump drains the tank while on, and the battery triggers the same
load-shed tiers as the firmware (lights at tier 1, pump at tier 2, fridge at
tier 3, with recovery hysteresis). One simulated day passes in --day-seconds
(default 300 s) so you can watch a full cycle in minutes.

Usage:
    python3 tools/mock_device.py                          # creds from server/.env
    python3 tools/mock_device.py --scenario low-battery --discovery
    python3 tools/mock_device.py --duty-cycle --interval 30
    python3 tools/mock_device.py --broker 192.168.1.10 --username x --password y

Scenarios: normal, sunny, cloudy, low-battery, heatwave.
Stop with Ctrl-C (clean "offline") or SIGKILL to test the broker's LWT.
"""

from __future__ import annotations

import argparse
import json
import math
import signal
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _lib import SERVER_DIR, load_env, mqtt_client  # noqa: E402

SCENARIOS = {
    #             temp base, temp amp, sun scale, battery start V
    "normal":      (14.0,      8.0,     1.0,      13.2),
    "sunny":       (20.0,     10.0,     1.3,      13.3),
    "cloudy":      (12.0,      4.0,     0.3,      13.0),
    "low-battery": (14.0,      8.0,     0.1,      12.45),
    "heatwave":    (26.0,     10.0,     1.2,      13.2),
}

TIER_THRESHOLDS = (12.8, 12.4, 12.0)  # tier 1 / 2 / 3
TIER_HYSTERESIS = 0.25
TIER_NAMES = ["Normal", "Tier 1 - conserve", "Tier 2 - critical", "Tier 3 - emergency"]

TANK_L = 40.0
PANEL_PEAK_A = 12.0    # 200 W panel through the MPPT at ~13 V, ideal noon
BASE_LOAD_A = 0.9      # router + controller + parasitics
FRIDGE_RUN_A = 3.5     # CFX compressor current while running
FRIDGE_DUTY = 0.4      # nominal compressor duty at moderate ambient
PUMP_A = 4.0
LIGHTS_A = 1.5
PUMP_LPM = 4.0         # pump flow, liters per minute


class MockTrailer:
    """Simulated trailer physics + the firmware's local protection rules."""

    def __init__(self, scenario: str, day_seconds: float):
        self.temp_base, self.temp_amp, self.sun_scale, batt = SCENARIOS[scenario]
        self.day_seconds = day_seconds
        self.battery_v = batt
        self.water = 80.0
        self.tier = 0
        self.pump_on = False
        self.lights_on = False
        self.fridge_compressing = False
        self.fridge_temp = 4.0
        self.pump_used_s = 0.0
        self.start = time.time()
        self.uptime0 = time.time()

        # setpoints — mirror the ESPHome number/switch entities
        self.setpoints: dict[str, float] = {
            "pump_low_water_cutoff": 5.0,
        }
        self.pump_enabled = True
        self.fridge_enabled = True
        self.radio_always_on = True
        # initialize derived readings so a snapshot can be published
        # before the first real tick (on_connect fires immediately)
        self.tick(0.0)

    # --- simulated time -------------------------------------------------
    def sim_hour(self) -> float:
        return ((time.time() - self.start) / self.day_seconds * 24.0 + 8.0) % 24.0

    def sun(self) -> float:
        """0..1 daylight curve."""
        h = self.sim_hour()
        return max(0.0, math.sin((h - 6.0) / 12.0 * math.pi)) if 6.0 <= h <= 20.0 else 0.0

    # --- physics tick ----------------------------------------------------
    def tick(self, dt: float) -> None:
        sun = self.sun() * self.sun_scale

        self.temp = self.temp_base + self.temp_amp * sun
        self.rh = max(20.0, min(99.0, 80.0 - self.temp * 1.1))

        # fridge: relay = enabled && tier < 3; compressor duty-cycles
        self.fridge_power = self.fridge_enabled and self.tier < 3
        if self.fridge_power:
            duty = min(0.95, FRIDGE_DUTY + 0.02 * max(0.0, self.temp - 20.0))
            self.fridge_compressing = (time.time() % 60.0) < 60.0 * duty
            target = 4.0 if self.fridge_compressing else self.fridge_temp + 0.2
            self.fridge_temp += (target - self.fridge_temp) * min(1.0, dt / 30.0)
        else:
            self.fridge_compressing = False
            self.fridge_temp += (self.temp - self.fridge_temp) * min(1.0, dt / 600.0)

        # water: pump drains the tank
        if self.pump_on:
            self.water -= PUMP_LPM * dt / 60.0 / TANK_L * 100.0
            self.pump_used_s += dt
        self.water = max(0.0, min(100.0, self.water))

        # battery: solar in; base load, fridge, pump, lights out
        charge_a = PANEL_PEAK_A * sun
        load_a = BASE_LOAD_A
        if self.fridge_compressing:
            load_a += FRIDGE_RUN_A
        if self.pump_on:
            load_a += PUMP_A
        if self.lights_on:
            load_a += LIGHTS_A
        self.battery_a = charge_a - load_a
        # crude voltage model: net Ah nudges the (flat) LiFePO4 curve
        self.battery_v = max(10.5, min(14.4,
                             self.battery_v + self.battery_a * dt / 3600.0 * 0.15))
        self.battery_w = self.battery_a * self.battery_v

        self.update_tier()
        self.enforce_gates()

    def update_tier(self) -> None:
        v, t = self.battery_v, self.tier
        t1, t2, t3 = TIER_THRESHOLDS
        if v < t3:
            t = 3
        elif v < t2:
            t = max(t, 2)
        elif v < t1:
            t = max(t, 1)
        if t == 3 and v >= t3 + TIER_HYSTERESIS:
            t = 2
        if t == 2 and v >= t2 + TIER_HYSTERESIS:
            t = 1
        if t == 1 and v >= t1 + TIER_HYSTERESIS:
            t = 0
        self.tier = t

    def enforce_gates(self) -> None:
        """The firmware's local protection rules (see the actuator packages)."""
        if self.lights_on and self.tier >= 1:
            self.lights_on = False
        if self.pump_on and (self.tier >= 2 or not self.pump_enabled
                             or self.water < self.setpoints["pump_low_water_cutoff"]):
            self.pump_on = False

    def command_pump(self, on: bool) -> bool:
        if not on:
            self.pump_on = False
            return True
        if (self.tier >= 2 or not self.pump_enabled
                or self.water < self.setpoints["pump_low_water_cutoff"]):
            return False  # refused, like the firmware
        self.pump_on = True
        return True

    def command_lights(self, on: bool) -> bool:
        if not on:
            self.lights_on = False
            return True
        if self.tier >= 1:
            return False
        self.lights_on = True
        return True


class MockDevice:
    def __init__(self, args: argparse.Namespace):
        self.args = args
        self.root = args.root
        self.node = args.node
        self.prefix = f"{args.root}/{args.node}"
        self.sim = MockTrailer(args.scenario, args.day_seconds)
        self.client = mqtt_client(f"mock-{args.node}", args.username, args.password)
        self.client.will_set(f"{self.prefix}/status", "offline", retain=True)
        self.client.on_connect = self.on_connect
        self.client.on_message = self.on_message

    # --- MQTT contract ----------------------------------------------------
    def on_connect(self, *_a, **_kw) -> None:
        self.client.publish(f"{self.prefix}/status", "online", retain=True)
        for component in ("number", "switch"):
            self.client.subscribe(f"{self.prefix}/{component}/+/command")
        self.publish_snapshot()
        print(f"[mock] connected as {self.prefix}")

    def on_message(self, _client, _userdata, msg) -> None:
        parts = msg.topic.split("/")
        component, object_id = parts[-3], parts[-2]
        payload = msg.payload.decode()
        sim = self.sim
        print(f"[mock] command: {component}/{object_id} = {payload}")

        if component == "number" and object_id in sim.setpoints:
            try:
                sim.setpoints[object_id] = float(payload)
            except ValueError:
                return
            self.pub("number", object_id, f"{float(payload):g}")
        elif component == "switch" and object_id == "pump_enabled":
            sim.pump_enabled = payload == "ON"
            self.pub("switch", object_id, payload)
        elif component == "switch" and object_id == "fridge_enabled":
            sim.fridge_enabled = payload == "ON"
            self.pub("switch", object_id, payload)
        elif component == "switch" and object_id == "radio_always_on":
            sim.radio_always_on = payload == "ON"
            self.pub("switch", object_id, payload)
        elif component == "switch" and object_id == "water_pump":
            sim.command_pump(payload == "ON")
            self.pub("switch", object_id, "ON" if sim.pump_on else "OFF")
        elif component == "switch" and object_id == "exterior_lights":
            sim.command_lights(payload == "ON")
            self.pub("switch", object_id, "ON" if sim.lights_on else "OFF")

    def pub(self, component: str, object_id: str, value) -> None:
        self.client.publish(f"{self.prefix}/{component}/{object_id}/state",
                            str(value), retain=True)

    def publish_snapshot(self) -> None:
        sim = self.sim
        sensors = {
            "battery_voltage": f"{sim.battery_v:.2f}",
            "battery_current": f"{sim.battery_a:.2f}",
            "battery_power": f"{sim.battery_w:.1f}",
            "water_level": f"{sim.water:.0f}",
            "water_volume": f"{sim.water * TANK_L / 100.0:.1f}",
            "interior_temperature": f"{sim.temp:.1f}",
            "interior_humidity": f"{sim.rh:.0f}",
            "fridge_temperature": f"{sim.fridge_temp:.1f}",
            "pump_used_today": f"{sim.pump_used_s:.0f}",
            "wifi_rssi": f"{-55 - 10 * sim.sun():.0f}",
            "uptime": f"{time.time() - sim.uptime0:.0f}",
            "load_shed_tier": str(sim.tier),
        }
        for object_id, value in sensors.items():
            self.pub("sensor", object_id, value)
        self.pub("switch", "water_pump", "ON" if sim.pump_on else "OFF")
        self.pub("switch", "exterior_lights", "ON" if sim.lights_on else "OFF")
        self.pub("switch", "pump_enabled", "ON" if sim.pump_enabled else "OFF")
        self.pub("switch", "fridge_enabled", "ON" if sim.fridge_enabled else "OFF")
        self.pub("switch", "radio_always_on", "ON" if sim.radio_always_on else "OFF")
        self.pub("binary_sensor", "fridge_power", "ON" if sim.fridge_power else "OFF")
        self.pub("text_sensor", "load_shed_state", TIER_NAMES[sim.tier])
        for object_id, value in sim.setpoints.items():
            self.pub("number", object_id, f"{value:g}")

    def publish_discovery(self) -> None:
        """Minimal HA MQTT discovery, mirroring what ESPHome would publish."""
        device = {
            "identifiers": [f"mock-{self.node}"],
            "name": self.node,
            "manufacturer": "PrintTrek (mock)",
        }
        entities = [
            ("sensor", "battery_voltage", {"unit_of_measurement": "V",
             "device_class": "voltage"}),
            ("sensor", "battery_current", {"unit_of_measurement": "A",
             "device_class": "current"}),
            ("sensor", "battery_power", {"unit_of_measurement": "W",
             "device_class": "power"}),
            ("sensor", "water_level", {"unit_of_measurement": "%"}),
            ("sensor", "water_volume", {"unit_of_measurement": "L"}),
            ("sensor", "interior_temperature", {"unit_of_measurement": "°C",
             "device_class": "temperature"}),
            ("sensor", "fridge_temperature", {"unit_of_measurement": "°C",
             "device_class": "temperature"}),
            ("sensor", "load_shed_tier", {}),
            ("binary_sensor", "fridge_power", {"device_class": "power"}),
            ("switch", "water_pump", {}),
            ("switch", "exterior_lights", {}),
            ("switch", "pump_enabled", {"retain": True}),
            ("switch", "fridge_enabled", {"retain": True}),
            ("number", "pump_low_water_cutoff",
             {"min": 0, "max": 50, "step": 1, "unit_of_measurement": "%",
              "retain": True}),
        ]
        for component, object_id, extra in entities:
            config = {
                "name": object_id.replace("_", " ").title(),
                "unique_id": f"mock_{self.node}_{object_id}",
                "state_topic": f"{self.prefix}/{component}/{object_id}/state",
                "device": device,
                **extra,
            }
            if component in ("switch", "number"):
                config["command_topic"] = f"{self.prefix}/{component}/{object_id}/command"
                # "retain" was set per-entity above: setpoints only, never
                # raw actuators (PROTOCOL.md retention rules)
            self.client.publish(
                f"homeassistant/{component}/{self.node}/{object_id}/config",
                json.dumps(config), retain=True)
        print("[mock] published HA discovery")

    # --- main loop ----------------------------------------------------------
    def run(self) -> int:
        args = self.args
        try:
            self.client.connect(args.broker, args.port, keepalive=args.keepalive)
        except OSError as err:
            print(f"[mock] cannot connect to {args.broker}:{args.port}: {err}",
                  file=sys.stderr)
            return 1
        self.client.loop_start()
        time.sleep(0.5)
        if args.discovery:
            self.publish_discovery()

        stop_at = time.time() + args.duration if args.duration else None

        def clean_exit(*_sig) -> None:
            print("\n[mock] clean shutdown (retained status stays 'online'; "
                  "SIGKILL me to test LWT)")
            self.client.loop_stop()
            self.client.disconnect()
            sys.exit(0)

        signal.signal(signal.SIGINT, clean_exit)
        signal.signal(signal.SIGTERM, clean_exit)

        last = time.time()
        while stop_at is None or time.time() < stop_at:
            now = time.time()
            self.sim.tick(now - last)
            last = now

            if args.duty_cycle:
                self.publish_snapshot()
                time.sleep(2)  # linger: let retained commands arrive
                self.client.publish(f"{self.prefix}/status", "offline", retain=True)
                self.client.loop_stop()
                self.client.disconnect()
                print(f"[mock] radio off, sleeping {args.interval}s "
                      f"(tier {self.sim.tier}, batt {self.sim.battery_v:.2f} V)")
                time.sleep(args.interval)
                self.client.reconnect()
                self.client.loop_start()
                time.sleep(0.5)
            else:
                self.publish_snapshot()
                print(f"[mock] t={self.sim.sim_hour():04.1f}h "
                      f"batt={self.sim.battery_v:.2f}V ({self.sim.battery_a:+.1f}A) "
                      f"tier={self.sim.tier} water={self.sim.water:.0f}% "
                      f"fridge={self.sim.fridge_temp:.1f}C"
                      f"{' PUMP' if self.sim.pump_on else ''}"
                      f"{' LIGHTS' if self.sim.lights_on else ''}")
                time.sleep(args.interval)

        clean_exit()
        return 0


def main() -> int:
    env = load_env(SERVER_DIR / ".env")
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--broker", default="localhost")
    parser.add_argument("--port", type=int, default=1883)
    parser.add_argument("--username", default=env.get("MQTT_USER"))
    parser.add_argument("--password", default=env.get("MQTT_PASSWORD"))
    parser.add_argument("--root", default="printtrek", help="MQTT topic root")
    parser.add_argument("--node", default="printtrek-trailer")
    parser.add_argument("--scenario", choices=sorted(SCENARIOS), default="normal")
    parser.add_argument("--interval", type=float, default=10.0,
                        help="seconds between telemetry publishes (default 10)")
    parser.add_argument("--day-seconds", type=float, default=300.0,
                        help="wall seconds per simulated day (default 300)")
    parser.add_argument("--duration", type=float, default=0,
                        help="stop after N seconds (default: run forever)")
    parser.add_argument("--keepalive", type=int, default=10)
    parser.add_argument("--duty-cycle", action="store_true",
                        help="simulate storage-mode radio duty cycle "
                             "(connect/publish/disconnect)")
    parser.add_argument("--discovery", action="store_true",
                        help="publish Home Assistant MQTT discovery configs")
    args = parser.parse_args()
    return MockDevice(args).run()


if __name__ == "__main__":
    sys.exit(main())
