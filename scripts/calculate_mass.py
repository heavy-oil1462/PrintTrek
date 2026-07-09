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

# OPTIONAL floor crossbars at x=500/1500 (frame-neutral per FEA; they
# serve the formply floor span, lashing, and the water-tank hanger).
# Mirror of the `floor_crossbars` toggle in cad/main_assembly.scad.
FLOOR_CROSSBARS = True

# (name, mass_kg, x_mm of the component's center of gravity)
COMPONENTS = [
    # --- Chassis (steel, hot-dip galvanized: raw mass x ~1.06) ---
    ("Side rails 2x 2.0 m VKR 50x50x3 (4.31 kg/m)",   18.3, 1000),
    ("Front crossbeam 1.1 m VKR 50x50x3",              5.0,   25),
    ("Mid crossbeam (drawbar lap) 1.1 m VKR 50x50x3",  5.0,  975),
    ("Rear crossbeam 1.1 m VKR 50x50x3",               5.0, 1975),
    ("Central drawbar 2.02 m VKR 100x50x4 (8.6 kg/m)", 18.4,   10),
    ("Coupling head (type-approved) + bolts",           4.0, COUPLING_X),
    ("Crush sleeves, bolts, nuts, washers",             6.0,  900),

    # --- Aluminum plates (6082-T6) ---
    ("Corner plates 8x 200x200x10 (1.08 kg ea)",        8.6, 1000),
    ("T-plates mid crossbeam 4x (~1.5 kg ea)",          6.0,  975),
    ("Drawbar wedge/spacer plates",                     3.0,  100),
    ("Drawbar angle brackets 2x L80x80x8 x 120 mm",     2.3,   25),
]

if FLOOR_CROSSBARS:
    COMPONENTS += [
        ("Floor crossbar 1.1 m VKR 50x50x3",               5.0,  500),
        ("Floor crossbar (tank hanger) 1.1 m VKR 50x50x3", 5.0, 1500),
        # Bottom T-plate per end (same CNC part as the mid-crossbeam
        # plates); the formply floor closes the joint from above.
        ("T-plates floor crossbars 4x bottom (~1.5 kg)",   3.0,  500),
        ("T-plates floor crossbars (rear pair)",           3.0, 1500),
    ]

COMPONENTS += [

    # --- Running gear ---
    ("Torsion axle, braked, 6x139.7 + dampers",        75.0, AXLE_X),
    ("Wheels 2x 265/60R18 on Ranger rims (~32 kg)",    64.0, AXLE_X),
    ("Fenders + brackets",                              6.0, AXLE_X),
    ("Jockey wheel",                                    5.0, -800),

    # --- Body ---
    ("Floor formply 2.0x1.2 m x 15 mm (680 kg/m3)",    24.5, 1000),
    ("Cabin skeleton ~12 m 40x40x2 alu (0.85 kg/m)",   10.2, 1000),
    ("Walls + roof Dibond 3 mm (~7.9 m2, 3.8 kg/m2)",  30.0, 1000),
    ("Rear door, hinges, locks, seals",                 8.0, 1950),
    ("Roof racks + roof tent",                         70.0, 1000),

    # --- Water (PLACEHOLDER: tank removed from the CAD assembly while
    #     the mounting is reworked. Candidate spot: BEHIND the axle,
    #     centered (x~1400) — freed up when the spare wheel left the
    #     trailer; no drawbar down there (beam ends at 1020) and it
    #     pulls the tongue back into the window with the gas box up
    #     front. Note: tongue RISES as water is consumed - see the
    #     dry-tank line in the output.) ---
    ("Water tank 40 L FULL + tank (mounting TBD)",     45.0, 1400),
    ("Skid plate 3 mm alu tread (mounting TBD)",        6.5, 1400),
    ("Pump, hoses, filler, drain valve",                4.0, 1200),

    # --- Electrical (right side, bay ahead of the fridge drawer) ---
    ("Power station box (200Ah LiFePO4, inverter, chargers)", 40.0, 920),
    ("Solar panel 200 W rigid + roof brackets",        14.0, 1000),
    ("IP65 cabinet, wiring, conduits, lighting",       12.0,  800),
    ("Teltonika router, antenna, coax",                 3.0,  600),

    # --- Gas (right side / drawbar) ---
    ("Propane P6 bottle FULL (6 kg gas + steel)",      14.0, -230),
    ("Gas locker box + bearers/clamps (caravan style)", 10.0, -230),
    ("Gas piping, quick-connects, niches",              4.0, 1400),

    # --- Galley (kitchen/storage LEFT, electrical bay/fridge RIGHT) ---
    ("Kitchen side-drawer + 150 kg slides (front left)", 15.0, 320),
    ("Storage cabinet plywood (mid left)",              10.0,  925),
    ("Stove (stored) + utensils in cabinet",             8.0,  925),
    ("Electrical bay cabinet plywood (mid right)",      10.0,  925),
    ("Fridge drawer tray + slides (rear right)",         8.0, 1650),
    ("12V compressor fridge (e.g., Dometic CFX3 45)",   19.0, 1650),
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

    # Tongue with the water tank EMPTY (worst case moves as the tank is
    # consumed; water sits behind the axle, so draining RAISES the tongue)
    dry = [(n, m, x) for n, m, x in COMPONENTS if "Water tank" not in n]
    total_d = sum(m for _, m, _ in dry)
    tongue_d = sum(m * (AXLE_X - x) for _, m, x in dry) / (AXLE_X - COUPLING_X)
    print(f"  Tongue load (water empty):        {tongue_d:6.1f} kg ({100*tongue_d/total_d:.1f}%)")

    # Target: 5-10% classic guidance; up to ~12% is fine (and stability-
    # positive) as long as the coupling S-value and the Ranger's rated
    # ball load are respected.
    for label, t, tot in (("full", tongue, total), ("water empty", tongue_d, total_d)):
        pct = 100 * t / tot
        if pct > 12 or pct < 5:
            print(f"  [!] Tongue ({label}) {pct:.1f}% outside 5-12% — move the axle or heavy components.")
        elif pct > 10:
            print(f"  [i] Tongue ({label}) {pct:.1f}% — above the classic 10%, OK if within the coupling S-value / towbar ball rating.")
        else:
            print(f"  [ok] Tongue ({label}) {pct:.1f}% within the 5-10% target.")

    if max(tongue, tongue_d) > 100:
        print(f"  [!] Check the Ford Ranger towbar's rated ball load (typical 75-100 kg for EU spec).")


if __name__ == "__main__":
    main()
