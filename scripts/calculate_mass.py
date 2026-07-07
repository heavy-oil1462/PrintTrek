#!/usr/bin/env python3
"""
Weight, center-of-gravity, and tongue-load budget for the PrintTrek trailer.

This is THE document that decides:
  - braked vs. unbraked axle (750 kg total weight limit)
  - axle position (currently 60% back in the CAD)
  - whether the tongue load lands in the 5-10% target window

Coordinate system matches cad/frame.scad: x = 0 at the front of the frame,
positive x toward the rear. The coupling sits ~1060 mm ahead of the frame.

All masses are estimates — refine them as real components are chosen and
weighed. Update AXLE_X if the axle beam moves in the CAD.
"""

FRAME_LENGTH = 2000          # mm (see cad/frame.scad)
AXLE_X = FRAME_LENGTH * 0.6  # mm, center beam / torsion axle position
COUPLING_X = -1060           # mm, coupling point (drawbar_reach + head)

# Payload the trailer should be rated to carry on top of its own weight
# (food, gear, firewood, tools...). Included in the total-weight check.
PAYLOAD_ALLOWANCE = 150      # kg

# (name, mass_kg, x_mm of the component's center of gravity)
COMPONENTS = [
    # --- Chassis (steel, hot-dip galvanized: raw mass x ~1.06) ---
    ("Side rails 2x 2.0 m VKR 50x50x3 (4.31 kg/m)",   18.3, 1000),
    ("Front crossbeam 1.1 m VKR 50x50x3",              5.0,   25),
    ("Axle crossbeam 1.1 m VKR 50x50x3",               5.0, AXLE_X),
    ("Rear crossbeam 1.1 m VKR 50x50x3",               5.0, 1975),
    ("Drawbar arms 2x 1.70 m VKR 50x50x3",            15.5, -200),
    ("Coupling head (type-approved) + bolts",           4.0, COUPLING_X),
    ("Crush sleeves, bolts, nuts, washers",             6.0,  900),

    # --- Aluminum plates (6082-T6) ---
    ("Corner plates 8x 200x200x10 (1.08 kg ea)",        8.6, 1000),
    ("T-plates axle beam 4x (~1.5 kg ea)",              6.0, AXLE_X),
    ("Drawbar wedge/spacer plates",                     3.0,  100),

    # --- Running gear ---
    ("Torsion axle, braked, 6x139.7 + dampers",        75.0, AXLE_X),
    ("Wheels 2x 265/60R18 on Ranger rims (~32 kg)",    64.0, AXLE_X),
    ("Spare wheel (rear mount)",                       32.0, 1900),
    ("Fenders + brackets",                              6.0, AXLE_X),
    ("Jockey wheel",                                    5.0, -800),

    # --- Body ---
    ("Floor formply 2.0x1.2 m x 15 mm (680 kg/m3)",    24.5, 1000),
    ("Cabin skeleton ~12 m 40x40x2 alu (0.85 kg/m)",   10.2, 1000),
    ("Walls + roof Dibond 3 mm (~7.9 m2, 3.8 kg/m2)",  30.0, 1000),
    ("Rear door, hinges, locks, seals",                 8.0, 1950),
    ("Roof racks + roof tent",                         70.0, 1000),

    # --- Water (tank full) ---
    ("Water tank 40 L FULL + tank",                    45.0, 1100),
    ("Skid plate 3 mm alu tread (~0.8 m2)",             6.5, 1100),
    ("Pump, hoses, filler, drain valve",                4.0, 1200),

    # --- Electrical (left side) ---
    ("Power station box (200Ah LiFePO4, inverter, chargers)", 40.0, 400),
    ("Solar panel 200 W rigid + roof brackets",        14.0, 1000),
    ("IP65 cabinet, wiring, conduits, lighting",       12.0,  800),
    ("Teltonika router, antenna, coax",                 3.0,  600),

    # --- Gas (right side / drawbar) ---
    ("Propane P6 bottle FULL (6 kg gas + steel)",      14.0, -600),
    ("Cradle, stone guard, straps",                     7.0, -600),
    ("Gas piping, quick-connects, niches",              4.0, 1400),

    # --- Kitchen ---
    ("Kitchen drawer + 150 kg slides",                 22.0, 1700),
    ("12V compressor fridge (e.g., Dometic CFX3 45)",  19.0, 1700),
    ("Stove (stored) + utensils box",                   8.0, 1700),
]


def main():
    total = sum(m for _, m, _ in COMPONENTS)
    moment = sum(m * x for _, m, x in COMPONENTS)
    cg_x = moment / total

    # Static moments about the axle: positive = load on the coupling
    tongue = sum(m * (AXLE_X - x) for _, m, x in COMPONENTS) / (AXLE_X - COUPLING_X)
    axle_load = total - tongue
    laden = total + PAYLOAD_ALLOWANCE

    print("==================================================")
    print(" PrintTrek Weight & Tongue-Load Budget")
    print("==================================================\n")

    width = max(len(name) for name, _, _ in COMPONENTS)
    for name, m, x in COMPONENTS:
        print(f"  {name:<{width}}  {m:6.1f} kg   @ x={x:6.0f} mm")

    print("\n--------------------------------------------------")
    print(f"  Curb weight (water + gas full):   {total:6.1f} kg")
    print(f"  + payload allowance:              {PAYLOAD_ALLOWANCE:6.1f} kg")
    print(f"  = design total weight:            {laden:6.1f} kg")
    print(f"  Center of gravity:                x = {cg_x:.0f} mm (axle at {AXLE_X:.0f} mm)")
    print(f"  Tongue load (curb):               {tongue:6.1f} kg ({100*tongue/total:.1f}% of curb)")
    print(f"  Axle load (curb):                 {axle_load:6.1f} kg\n")

    # DECIDED: the trailer is braked (overrun brakes), so total weight may be
    # registered above 750 kg. Check against the axle rating instead.
    AXLE_RATING = 1300  # kg — typical braked torsion axle; update to the purchased unit
    print(f"  [i] Braked trailer (decided): register total weight with margin, e.g. {round(laden + 50, -2):.0f} kg.")
    if laden > AXLE_RATING:
        print(f"  [!] Design total weight exceeds the assumed axle rating ({AXLE_RATING} kg).")
    else:
        print(f"  [ok] Within assumed axle rating ({AXLE_RATING} kg — update to the purchased axle).")

    pct = 100 * tongue / total
    if not (5 <= pct <= 10):
        print(f"  [!] Tongue load {pct:.1f}% is outside the 5-10% target — move the axle or heavy components.")
    else:
        print(f"  [ok] Tongue load within 5-10% target.")

    if tongue > 100:
        print(f"  [!] Check the Ford Ranger towbar's rated ball load (typical 75-100 kg for EU spec).")


if __name__ == "__main__":
    main()
