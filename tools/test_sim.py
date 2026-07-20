#!/usr/bin/env python3
"""PrintTrek simulation integration test - the REAL firmware, no hardware.

Compiles esphome/sim-trailer.yaml (actual esp32 build), boots it under
Espressif QEMU against a throwaway authenticated mosquitto, drives it
through the web UI's HTTP API (harness: esphome_skills.sim_test), and
asserts that the on-device rules behave:

    1. node comes up: retained status "online" + MQTT discovery
    2. injected sensor values surface under the real sensor ids
    3. exterior lights follow direct HA commands
    4. dry-run protection: 3 % water blocks/stops the pump
    5. battery 12.7 V -> tier 1 sheds the lights
    6. 12.3 V -> tier 2; 11.8 V -> tier 3 cuts the fridge relay
    7. battery 13.4 V -> cascaded recovery, fridge restores itself

    sudo -E nix develop .#sim -c python3 tools/test_sim.py

Slow: one esp32 compile (cached in .esphome-sim/) plus minutes of emulated
control-loop time. Not part of the default validation gate. See the
harness docstring for requirements (QEMU, udp/123, mosquitto).
"""

import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project import PROJECT  # noqa: E402

from esphome_skills.sim_test import run  # noqa: E402

# Retained injections published before the firmware boots: healthy battery,
# mild day, full tank, cold fridge.
BOOT = {"battery": 13.2, "battery_current": 1.0, "water": 80,
        "temperature": 18, "humidity": 55, "fridge_temp": 4}


def scenario(ctx) -> None:
    ctx.heading("2. injected sensors surface under real ids")
    water = ctx.wait_state("sensor/water_level",
                           lambda v: v and abs(float(v) - 80) < 1)
    ctx.check(water is not None, "water injection 80 % -> water_level")
    batt = ctx.wait_state("sensor/battery_voltage",
                          lambda v: v and abs(float(v) - 13.2) < .1)
    ctx.check(batt is not None, "battery injection 13.2 V -> battery_voltage")

    ctx.heading("3. direct control: lights follow HA commands")
    ctx.watcher.publish(f"{ctx.prefix}/switch/exterior_lights/command", "ON")
    lights = ctx.wait_state("switch/exterior_lights",
                            lambda v: v == "ON", timeout=60)
    ctx.check(lights is not None, "lights ON command took effect")
    ctx.watcher.publish(f"{ctx.prefix}/switch/exterior_lights/command", "OFF")
    lights = ctx.wait_state("switch/exterior_lights",
                            lambda v: v == "OFF", timeout=60)
    ctx.check(lights is not None, "lights OFF command took effect")

    ctx.heading("4. dry-run protection: low water blocks the pump")
    ctx.inject(water=3)
    ctx.wait_state("sensor/water_level",
                   lambda v: v and float(v) < 5, timeout=60)
    ctx.watcher.publish(f"{ctx.prefix}/switch/water_pump/command", "ON")
    # The automation tick (10 s) force-stops it; accept either the brief
    # ON->OFF bounce or an unchanged OFF.
    time.sleep(20)
    pump = ctx.watcher.messages.get(f"{ctx.prefix}/switch/water_pump/state")
    ctx.check(pump is not None and pump[0] == "OFF",
              "pump forced/held OFF at 3 % water")
    ctx.inject(water=80)

    ctx.heading("5. tier 1 sheds the lights")
    ctx.watcher.publish(f"{ctx.prefix}/switch/exterior_lights/command", "ON")
    ctx.wait_state("switch/exterior_lights", lambda v: v == "ON", timeout=60)
    ctx.inject(battery=12.7)
    tier = ctx.wait_state("sensor/load_shed_tier",
                          lambda v: v and float(v) == 1)
    ctx.check(tier is not None, "12.7 V -> tier 1")
    lights = ctx.wait_state("switch/exterior_lights",
                            lambda v: v == "OFF")
    ctx.check(lights is not None, "tier 1 forced the lights off")

    ctx.heading("6. deeper shedding cuts pump, then fridge")
    ctx.inject(battery=12.3)
    tier = ctx.wait_state("sensor/load_shed_tier",
                          lambda v: v and float(v) == 2)
    ctx.check(tier is not None, "12.3 V -> tier 2")
    ctx.inject(battery=11.8)
    tier = ctx.wait_state("sensor/load_shed_tier",
                          lambda v: v and float(v) == 3)
    ctx.check(tier is not None, "11.8 V -> tier 3")
    fridge = ctx.wait_state("binary_sensor/fridge_power",
                            lambda v: v == "OFF")
    ctx.check(fridge is not None, "tier 3 cut the fridge relay")
    state = ctx.wait_state("text_sensor/load_shed_state",
                           lambda v: "3" in v, timeout=60)
    ctx.check(state is not None, "load shed state text published")

    ctx.heading("7. recovery cascades; fridge restores itself")
    ctx.inject(battery=13.4)
    tier = ctx.wait_state("sensor/load_shed_tier",
                          lambda v: v and float(v) == 0, timeout=120)
    ctx.check(tier is not None, "13.4 V -> back to Normal")
    fridge = ctx.wait_state("binary_sensor/fridge_power",
                            lambda v: v == "ON")
    ctx.check(fridge is not None, "fridge relay came back without manual help")


if __name__ == "__main__":
    sys.exit(run(PROJECT, scenario, boot_injections=BOOT))
