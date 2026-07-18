#!/usr/bin/env python3
"""
12V energy budget and autonomy calculator for the PrintTrek trailer.

Answers: "how long can I stay parked before the battery (or gas) runs out?"
for different SETUPS (battery size x solar x fridge type) across different
solar conditions. Companion to calculate_mass.py.

All loads are estimates — refine with measured values once installed
(the ESPHome node reports battery voltage AND net current via the INA226
shunt — Home Assistant history gives real consumption for free).
"""

SYSTEM_V = 12.8              # LiFePO4 nominal
USABLE_FRACTION = 0.90       # LiFePO4 usable depth of discharge
SOLAR_SYSTEM_EFF = 0.75      # MPPT, cabling, temperature, dirt
DCDC_A = 30                  # DC-DC charger current while driving

GAS_BOTTLE_G = 6000          # P6 propane bottle
ABSORPTION_GAS_G_DAY = 270   # typical absorption fridge propane burn

# --- Base loads, always present (name, avg_power_W, hours_per_day) ---
BASE_LOADS = [
    ("Teltonika 5G router + antenna",       8.0, 24),
    ("LED lighting (interior + exterior)", 10.0,  3),
    ("Water pump (Seaflo/Shurflo)",        60.0,  0.2),
    ("ESP32 controller + RPi server",       4.0, 24),
    ("Phone/laptop/device charging",       30.0,  2),
]

# --- Fridge models: avg W on 12V while camped, plus gas burn if any ---
FRIDGES = {
    # CFX3 45-class: ~45 W compressing, ~40% duty at 25 C, pre-chilled
    "compressor":     {"w": 18.0,  "gas_g_day": 0,
                       "note": "works off-level, no flame"},
    # Fixed-mount absorption on gas: only ignition electronics on 12V
    "absorption_gas": {"w": 0.5,   "gas_g_day": ABSORPTION_GAS_G_DAY,
                       "note": "needs fixed flue/vents (EN 1949), <3 deg level"},
    # Absorption on its 12V heating element: no thermostat, driving only
    "absorption_12v": {"w": 120.0, "gas_g_day": 0,
                       "note": "12V mode is for driving ONLY - shown as a warning"},
}

# --- Setups to compare: (name, battery_Ah, solar_W, fridge_key) ---
SETUPS = [
    ("Original plan: 100 Ah, no solar, compressor",  100,   0, "compressor"),
    ("100 Ah + 200 W solar, compressor",             100, 200, "compressor"),
    ("DECIDED: 200 Ah + 200 W solar, compressor",    200, 200, "compressor"),
    ("Big: 300 Ah + 400 W solar, compressor",        300, 400, "compressor"),
    ("Absorption fridge on GAS (fixed mount)",       100,   0, "absorption_gas"),
    ("Absorption fridge on 12 V (DON'T)",            100,   0, "absorption_12v"),
]

# Equivalent full-sun hours per day hitting the panel
SOLAR_SCENARIOS = [
    ("Swedish summer, sun",  5.0),
    ("Spring/autumn/shade",  2.5),
    ("Overcast forest camp", 1.0),
]


def autonomy_days(battery_ah, solar_w, sun_h, load_ah_day, gas_g_day):
    usable = battery_ah * USABLE_FRACTION
    solar_ah = solar_w * sun_h * SOLAR_SYSTEM_EFF / SYSTEM_V
    net = load_ah_day - solar_ah
    batt_days = float("inf") if net <= 0 else usable / net
    gas_days = float("inf") if gas_g_day == 0 else GAS_BOTTLE_G / gas_g_day
    return min(batt_days, gas_days), batt_days, gas_days


def fmt_days(d):
    return "  indef." if d == float("inf") else f"{d:7.1f}"


def main():
    base_ah = sum(w * h / SYSTEM_V for _, w, h in BASE_LOADS)

    print("=======================================================")
    print(" PrintTrek 12V Energy Budget & Setup Comparison")
    print("=======================================================\n")

    width = max(len(n) for n, _, _ in BASE_LOADS)
    print(f"  Base loads (all setups)          avg W   h/day   Ah/day")
    for name, w, h in BASE_LOADS:
        print(f"  {name:<{width}}  {w:6.1f}  {h:6.1f}  {w*h/SYSTEM_V:7.1f}")
    print(f"  {'Total base load':<{width}}  {'':6}  {'':6}  {base_ah:7.1f}\n")

    header = "".join(f"{n:>24}" for n, _ in SOLAR_SCENARIOS)
    print(f"  Autonomy in DAYS parked (limited by battery or 6 kg gas bottle):\n")
    print(f"  {'Setup':<46}{header}")
    print("  " + "-" * (46 + 24 * len(SOLAR_SCENARIOS)))

    for name, batt, solar, fridge_key in SETUPS:
        fridge = FRIDGES[fridge_key]
        load = base_ah + fridge["w"] * 24 / SYSTEM_V
        cells = ""
        for _, sun_h in SOLAR_SCENARIOS:
            total, _, _ = autonomy_days(batt, solar, sun_h, load, fridge["gas_g_day"])
            cells += f"{fmt_days(total):>24}"
        print(f"  {name:<46}{cells}")
        print(f"  {'':4}({load:.0f} Ah/day, {fridge['note']})")

    print(f"\n  Notes:")
    print(f"  - 'indef.': solar harvest exceeds daily consumption.")
    print(f"  - Even the gas-fridge setup is BATTERY-limited without solar: the base")
    print(f"    loads (router, RPi, lights) drain the bank in ~3 days regardless of")
    print(f"    fridge choice. Solar is needed either way — which removes the gas")
    print(f"    fridge's main selling point. The bottle itself lasts "
          f"~{GAS_BOTTLE_G/ABSORPTION_GAS_G_DAY:.0f} days, but a gas")
    print(f"    fridge requires FIXED mounting with flue/vents per EN 1949, near-level")
    print(f"    parking, and a CO alarm (sleeping in the roof tent above). "
          f"Not compatible")
    print(f"    with the slide-out drawer.")
    print(f"  - DC-DC while driving ({DCDC_A} A): one day of the DECIDED "
          f"setup's consumption")
    decided_load = base_ah + FRIDGES['compressor']['w'] * 24 / SYSTEM_V
    print(f"    (~{decided_load:.0f} Ah) is recovered in "
          f"~{decided_load/DCDC_A:.1f} h of driving; "
          f"empty-to-full in ~{200*USABLE_FRACTION/DCDC_A:.0f} h.")


if __name__ == "__main__":
    main()
