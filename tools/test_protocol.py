#!/usr/bin/env python3
"""PrintTrek protocol integration test - no Docker, no hardware.

Boots a throwaway authenticated mosquitto, runs tools/mock_device.py
against it, and asserts the MQTT contract from docs/PROTOCOL.md (harness:
esphome_skills.protocol_test). Entities asserted here are PrintTrek's:
battery_voltage telemetry, the pump_low_water_cutoff setpoint, the
pump_enabled switch, plus an extra step for a direct (non-retained)
actuator command on exterior_lights.

Run inside the devshell (needs mosquitto + mosquitto_passwd + paho-mqtt):
    nix develop -c python3 tools/test_protocol.py

Exit code 0 = all assertions passed.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project import PROJECT  # noqa: E402

from esphome_skills.protocol_test import ProtocolSpec, run  # noqa: E402


def extra(ctx) -> None:
    ctx.heading("4b. direct actuator command (not retained)")
    ctx.watcher.publish(f"{ctx.prefix}/switch/exterior_lights/command", "ON")
    echo = ctx.watcher.wait_for(f"{ctx.prefix}/switch/exterior_lights/state",
                                lambda v: v == "ON")
    ctx.check(echo is not None, "lights ON command echoed on state topic")
    ctx.watcher.publish(f"{ctx.prefix}/switch/exterior_lights/command", "OFF")
    echo = ctx.watcher.wait_for(f"{ctx.prefix}/switch/exterior_lights/state",
                                lambda v: v == "OFF")
    ctx.check(echo is not None, "lights OFF command echoed on state topic")


SPEC = ProtocolSpec(
    telemetry_sensor="battery_voltage",
    telemetry_ok=lambda v: 10.0 < float(v) < 15.0,
    number="pump_low_water_cutoff",
    number_value="12",
    switch="pump_enabled",
    extra=extra,
)

if __name__ == "__main__":
    sys.exit(run(PROJECT, SPEC))
