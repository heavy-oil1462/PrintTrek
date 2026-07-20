#!/usr/bin/env python3
"""PrintTrek mock device - a software twin of the trailer control node.

The MQTT plumbing (LWT, retained state, command echo, HA discovery, duty
cycle) lives in esphome_skills.mock; this file is the trailer physics:
solar charge, fridge compressor duty cycling, pump draining the tank,
lights, and the firmware's local protection rules (dry-run cutoff,
load-shed tiers). One simulated day passes in --day-seconds (default
300 s).

Usage:
    python3 tools/mock_device.py                          # creds from server/.env
    python3 tools/mock_device.py --scenario low-battery --discovery
    python3 tools/mock_device.py --duty-cycle --interval 30
    python3 tools/mock_device.py --broker 192.168.1.10 --username x --password y

Scenarios: normal, sunny, cloudy, low-battery, heatwave.
Stop with Ctrl-C (clean "offline") or SIGKILL to test the broker's LWT.
"""

from __future__ import annotations

import math
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project import PROJECT  # noqa: E402

from esphome_skills import mock  # noqa: E402

TIER_THRESHOLDS = (12.8, 12.4, 12.0)  # tier 1 / 2 / 3
TIER_HYSTERESIS = 0.25
TIER_NAMES = ["Normal", "Tier 1 - conserve", "Tier 2 - critical",
              "Tier 3 - emergency"]

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

    SCENARIOS = {
        #             temp base, temp amp, sun scale, battery start V
        "normal":      (14.0,      8.0,     1.0,      13.2),
        "sunny":       (20.0,     10.0,     1.3,      13.3),
        "cloudy":      (12.0,      4.0,     0.3,      13.0),
        "low-battery": (14.0,      8.0,     0.1,      12.45),
        "heatwave":    (26.0,     10.0,     1.2,      13.2),
    }

    def __init__(self, scenario: str, day_seconds: float):
        self.temp_base, self.temp_amp, self.sun_scale, batt = \
            self.SCENARIOS[scenario]
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

        # setpoints - mirror the ESPHome number/switch entities
        self.setpoints: dict[str, float] = {
            "pump_low_water_cutoff": 5.0,
        }
        self.pump_enabled = True
        self.fridge_enabled = True
        self.radio_always_on = True
        # initialize derived readings so a snapshot can be published
        # before the first real tick (on_connect fires immediately)
        self.tick(0.0)

    # --- simulated time ---------------------------------------------------
    def sim_hour(self) -> float:
        return ((time.time() - self.start) / self.day_seconds * 24.0
                + 8.0) % 24.0

    def sun(self) -> float:
        """0..1 daylight curve."""
        h = self.sim_hour()
        return max(0.0, math.sin((h - 6.0) / 12.0 * math.pi)) \
            if 6.0 <= h <= 20.0 else 0.0

    # --- physics tick -----------------------------------------------------
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
            self.fridge_temp += (self.temp - self.fridge_temp) \
                * min(1.0, dt / 600.0)

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
                             self.battery_v
                             + self.battery_a * dt / 3600.0 * 0.15))
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
                             or self.water
                             < self.setpoints["pump_low_water_cutoff"]):
            self.pump_on = False

    def command_pump(self, on: bool) -> None:
        if not on:
            self.pump_on = False
            return
        if (self.tier >= 2 or not self.pump_enabled
                or self.water < self.setpoints["pump_low_water_cutoff"]):
            return  # refused, like the firmware
        self.pump_on = True

    def command_lights(self, on: bool) -> None:
        if not on:
            self.lights_on = False
            return
        if self.tier >= 1:
            return
        self.lights_on = True

    # --- esphome_skills.mock interface --------------------------------------
    def entities(self) -> list[tuple[str, str, str]]:
        sensors = {
            "battery_voltage": f"{self.battery_v:.2f}",
            "battery_current": f"{self.battery_a:.2f}",
            "battery_power": f"{self.battery_w:.1f}",
            "water_level": f"{self.water:.0f}",
            "water_volume": f"{self.water * TANK_L / 100.0:.1f}",
            "interior_temperature": f"{self.temp:.1f}",
            "interior_humidity": f"{self.rh:.0f}",
            "fridge_temperature": f"{self.fridge_temp:.1f}",
            "pump_used_today": f"{self.pump_used_s:.0f}",
            "wifi_rssi": f"{-55 - 10 * self.sun():.0f}",
            "uptime": f"{time.time() - self.uptime0:.0f}",
            "load_shed_tier": str(self.tier),
        }
        out = [("sensor", object_id, value)
               for object_id, value in sensors.items()]
        out += [
            ("switch", "water_pump", "ON" if self.pump_on else "OFF"),
            ("switch", "exterior_lights", "ON" if self.lights_on else "OFF"),
            ("switch", "pump_enabled", "ON" if self.pump_enabled else "OFF"),
            ("switch", "fridge_enabled",
             "ON" if self.fridge_enabled else "OFF"),
            ("switch", "radio_always_on",
             "ON" if self.radio_always_on else "OFF"),
            ("binary_sensor", "fridge_power",
             "ON" if self.fridge_power else "OFF"),
            ("text_sensor", "load_shed_state", TIER_NAMES[self.tier]),
        ]
        out += [("number", object_id, f"{value:g}")
                for object_id, value in self.setpoints.items()]
        return out

    def handle_command(self, component: str, object_id: str,
                       payload: str) -> str | None:
        if component == "number" and object_id in self.setpoints:
            try:
                self.setpoints[object_id] = float(payload)
            except ValueError:
                return None
            return f"{float(payload):g}"
        if component == "switch" and object_id == "pump_enabled":
            self.pump_enabled = payload == "ON"
            return payload
        if component == "switch" and object_id == "fridge_enabled":
            self.fridge_enabled = payload == "ON"
            return payload
        if component == "switch" and object_id == "radio_always_on":
            self.radio_always_on = payload == "ON"
            return payload
        if component == "switch" and object_id == "water_pump":
            self.command_pump(payload == "ON")
            return "ON" if self.pump_on else "OFF"
        if component == "switch" and object_id == "exterior_lights":
            self.command_lights(payload == "ON")
            return "ON" if self.lights_on else "OFF"
        return None

    def discovery_entities(self) -> list[tuple[str, str, dict]]:
        # "retain" per entity: setpoints only, never raw actuators
        # (PROTOCOL.md retention rules)
        return [
            ("sensor", "battery_voltage",
             {"unit_of_measurement": "V", "device_class": "voltage"}),
            ("sensor", "battery_current",
             {"unit_of_measurement": "A", "device_class": "current"}),
            ("sensor", "battery_power",
             {"unit_of_measurement": "W", "device_class": "power"}),
            ("sensor", "water_level", {"unit_of_measurement": "%"}),
            ("sensor", "water_volume", {"unit_of_measurement": "L"}),
            ("sensor", "interior_temperature",
             {"unit_of_measurement": "°C", "device_class": "temperature"}),
            ("sensor", "fridge_temperature",
             {"unit_of_measurement": "°C", "device_class": "temperature"}),
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

    def status_line(self) -> str:
        return (f"t={self.sim_hour():04.1f}h "
                f"batt={self.battery_v:.2f}V ({self.battery_a:+.1f}A) "
                f"tier={self.tier} water={self.water:.0f}% "
                f"fridge={self.fridge_temp:.1f}C"
                f"{' PUMP' if self.pump_on else ''}"
                f"{' LIGHTS' if self.lights_on else ''}")


if __name__ == "__main__":
    sys.exit(mock.main(PROJECT, MockTrailer))
