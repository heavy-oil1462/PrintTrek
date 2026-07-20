"""PrintTrek project declaration.

Single source of truth for the names the shared esphome-skills tools need:
topic root, node names, compositions, sim injections and presets. Injection
keys are the sim/<key> topics of esphome/packages/sim-sensors.yaml
(validate's sim check enforces the match).
"""

from pathlib import Path

from esphome_skills import Project

PROJECT = Project(
    name="printtrek",
    device="trailer node",
    mqtt_root="printtrek",
    sim_node="printtrek-sim",
    sim_yaml="sim-trailer.yaml",
    compositions=("example-trailer.yaml", "sim-trailer.yaml"),
    injections={
        "battery": ("Battery Voltage", "V", 10.0, 14.6, 0.05, 13.2),
        "battery_current": ("Battery Current", "A", -25.0, 25.0, 0.5, 0.0),
        "water": ("Water Level", "%", 0.0, 100.0, 1.0, 80.0),
        "temperature": ("Interior Temperature", "°C", -25.0, 45.0, 0.5, 18.0),
        "humidity": ("Interior Humidity", "%", 0.0, 100.0, 1.0, 55.0),
        "fridge_temp": ("Fridge Temperature", "°C", -20.0, 30.0, 0.5, 4.0),
    },
    presets={
        "Sunny camp (charging)": {"time": "12:30", "battery": 13.4,
                                  "battery_current": 8, "water": 80,
                                  "temperature": 24, "humidity": 45,
                                  "fridge_temp": 4},
        "Night, fridge cycling": {"time": "02:00", "battery": 13.1,
                                  "battery_current": -3, "temperature": 10,
                                  "humidity": 75, "fridge_temp": 5},
        "Low battery (tier 2)": {"battery": 12.3, "battery_current": -2},
        "Critical battery (tier 3)": {"battery": 11.8, "battery_current": -1},
        "Tank nearly empty": {"water": 3},
        "Fridge door open": {"fridge_temp": 14},
    },
    mock_node="printtrek-trailer",
    radio_switch="radio_always_on",
    repo_root=Path(__file__).resolve().parent.parent,
    python_dirs=("tools",),
)
