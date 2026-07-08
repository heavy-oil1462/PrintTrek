#!/usr/bin/env python3
"""
Structural hand-calcs for the PrintTrek trailer: RHS section properties,
bending/shear stresses, bolt-group checks, and safety factors for the
governing load cases.

Zero dependencies (pure stdlib) so it runs anywhere. This is the same math
as the sizing comment in cad/frame.scad, kept executable so any geometry or
mass change can be re-checked in seconds:

    python3 scripts/beam_check.py

Sources for the assumptions:
  - Dynamic factors: 3g vertical on the tongue and 0.3g lateral at the
    coupling are conservative off-road envelopes (cf. ECE R55 D/V-value
    philosophy; corrugated-road spectra peak around 2-3g).
  - Material: S355J2H for VKR/KKR tubes (EN 10219), yield 355 MPa up to
    t = 16 mm. Aluminum plates 6082-T6: yield 260 MPa.
  - Section properties use the sharp-corner approximation
    I = (B*H^3 - b*h^3)/12, which is within ~2-3 % of EN 10219 tables
    for these sizes (slightly conservative for W).

For anything beyond beam bending (plate buckling, joint stress
concentrations), escalate to CalculiX FEA — see fea/README.md.
"""

from dataclasses import dataclass

G = 9.81  # m/s^2

# ----------------------------------------------------------------------
# Materials (MPa)
# ----------------------------------------------------------------------
YIELD_S355 = 355.0     # VKR tubes EN 10219 S355J2H
YIELD_8_8 = 640.0      # bolt class 8.8 (fyb); fub = 800
FUB_8_8 = 800.0

# ----------------------------------------------------------------------
# Trailer parameters — keep in sync with cad/*.scad and calculate_mass.py
# ----------------------------------------------------------------------
TOTAL_MASS = 800.0        # kg, registered design weight
TONGUE_MASS = 80.0        # kg, static tongue load (target 5-10 % of total)
LEVER_VERT = 1.09         # m, coupling -> front crossbeam support
LAP_BASE = 1.20           # m, drawbar lap: front crossbeam -> axle crossbeam
DYN_VERT = 3.0            # g, vertical dynamic factor (off-road)
DYN_LAT = 0.3             # g, lateral factor on total mass at the coupling

FRAME_PAYLOAD = 400.0     # kg carried on the frame deck (body+cargo, no axle/drawbar)
RAIL_SPAN = 1.20          # m, side-rail span front crossbeam -> axle crossbeam


# ----------------------------------------------------------------------
# RHS (rectangular hollow section) properties
# ----------------------------------------------------------------------
@dataclass
class RHS:
    name: str
    B: float  # outer width, mm  (bending axis: horizontal)
    H: float  # outer height, mm (load applied vertically -> strong axis if H > B)
    t: float  # wall, mm

    @property
    def area(self):  # mm^2
        return self.B * self.H - (self.B - 2 * self.t) * (self.H - 2 * self.t)

    def I(self, about="strong"):  # mm^4
        B, H, t = self.B, self.H, self.t
        if about == "weak":
            B, H = H, B
        return (B * H**3 - (B - 2 * t) * (H - 2 * t)**3) / 12.0

    def W(self, about="strong"):  # mm^3, elastic section modulus
        half = (self.H if about == "strong" else self.B) / 2.0
        return self.I(about) / half

    @property
    def mass_per_m(self):  # kg/m
        return self.area * 1e-6 * 7850


PROFILES = {
    "VKR 50x50x3":   RHS("VKR 50x50x3", 50, 50, 3),
    "VKR 60x40x3":   RHS("VKR 60x40x3", 40, 60, 3),
    "VKR 100x50x4":  RHS("VKR 100x50x4", 50, 100, 4),   # drawbar, standing on edge
    "VKR 120x60x4":  RHS("VKR 120x60x4", 60, 120, 4),   # upsizing option
}


# ----------------------------------------------------------------------
# Checks
# ----------------------------------------------------------------------
def sf(stress, yield_=YIELD_S355):
    return yield_ / stress if stress > 0 else float("inf")


def report(title, lines):
    print(f"\n--- {title} " + "-" * max(0, 58 - len(title)))
    for l in lines:
        print("  " + l)


def check_drawbar(profile: RHS):
    out = []
    out.append(f"Profile: {profile.name}  (A={profile.area:.0f} mm2, "
               f"{profile.mass_per_m:.1f} kg/m)")
    out.append(f"  W_strong = {profile.W('strong')/1e3:.1f} cm3   "
               f"W_weak = {profile.W('weak')/1e3:.1f} cm3")

    # LC1 — vertical: dynamic tongue load on the cantilever
    M1 = TONGUE_MASS * DYN_VERT * G * LEVER_VERT           # Nm
    s1 = M1 * 1e3 / profile.W("strong")                    # MPa
    out.append(f"LC1 vertical  {DYN_VERT:.0f}g x {TONGUE_MASS:.0f} kg x {LEVER_VERT} m "
               f"= {M1:.0f} Nm -> {s1:.0f} MPa   SF = {sf(s1):.2f}")

    # LC2 — lateral: side force at the coupling, weak-axis bending
    F2 = DYN_LAT * TOTAL_MASS * G                          # N
    M2 = F2 * LEVER_VERT
    s2 = M2 * 1e3 / profile.W("weak")
    out.append(f"LC2 lateral   {DYN_LAT}g x {TOTAL_MASS:.0f} kg = {F2:.0f} N x {LEVER_VERT} m "
               f"= {M2:.0f} Nm -> {s2:.0f} MPa   SF = {sf(s2):.2f}")

    # LC3 — combined: reduced vertical (2g) simultaneous with full lateral.
    # Linear interaction of the two corner stresses (conservative).
    M3v = TONGUE_MASS * 2.0 * G * LEVER_VERT
    s3 = M3v * 1e3 / profile.W("strong") + s2
    out.append(f"LC3 combined  2g vertical + LC2 lateral -> {s3:.0f} MPa   "
               f"SF = {sf(s3):.2f}")

    # Attachment: the lateral moment resolves as a force couple across the lap
    Fc = M2 / LAP_BASE
    out.append(f"Lap couple    M_lat / {LAP_BASE} m = {Fc:.0f} N per crossbeam "
               f"(plus {F2:.0f} N direct shear)")

    worst = max(s1, s2, s3)
    verdict = "OK" if sf(worst) >= 2.0 else "!! SF < 2.0 — upsize or shorten lever"
    out.append(f"Worst case:   {worst:.0f} MPa vs S355 -> SF = {sf(worst):.2f}   [{verdict}]")
    report(f"DRAWBAR — {profile.name}, standing, cantilever to coupling", out)
    return sf(worst)


def check_side_rail(profile: RHS):
    # Each rail carries half the deck payload as a UDL; governing span is
    # front crossbeam -> axle crossbeam (rear of frame is a cantilever with
    # less moment). Simply-supported is conservative vs. the real continuous
    # beam over three supports.
    w = (FRAME_PAYLOAD / 2.0) * DYN_VERT * G / 2.0   # N/m over the 2 m rail
    M = w * RAIL_SPAN**2 / 8.0
    s = M * 1e3 / profile.W("strong")
    verdict = "OK" if sf(s) >= 2.0 else "!! SF < 2.0"
    report(f"SIDE RAIL — {profile.name}, {RAIL_SPAN} m span", [
        f"UDL {w:.0f} N/m ({DYN_VERT:.0f}g on {FRAME_PAYLOAD:.0f} kg deck, per rail)",
        f"M = wL2/8 = {M:.0f} Nm -> {s:.0f} MPa   SF = {sf(s):.2f}   [{verdict}]",
    ])
    return sf(s)


def check_bolts():
    # Drawbar-to-crossbeam M12 8.8 through-bolts with crush sleeves.
    # Governing action: lap couple from LC2 + direct shear, single shear plane
    # per tube wall pair -> treat as double shear through the RHS.
    F_lat = DYN_LAT * TOTAL_MASS * G
    M_lat = F_lat * LEVER_VERT
    F_couple = M_lat / LAP_BASE + F_lat            # worst crossbeam, N

    A_s = 84.3                                     # mm2, M12 stress area
    F_shear_cap = 0.6 * FUB_8_8 * A_s              # N per shear plane (EC3 6.2.2)
    n_planes = 2
    sf_bolt = n_planes * F_shear_cap / F_couple

    # Bearing on the 4 mm drawbar wall via the 20x3 crush sleeve (d=20 contact)
    F_bear_cap = 2.5 * 510 * 20 * 4                # ~2.5*fu*d*t, S355 fu=510
    sf_bear = 2 * F_bear_cap / F_couple            # two walls

    # Vertical: dynamic tongue reaction at the front crossbeam pair
    F_vert = TONGUE_MASS * DYN_VERT * G * (1 + LEVER_VERT / LAP_BASE)
    sf_vert = 2 * n_planes * F_shear_cap / F_vert  # 2 bolts share it

    report("DRAWBAR ATTACHMENT — 2x M12 8.8 per crossbeam, crush sleeves", [
        f"Lateral couple + shear on worst bolt: {F_couple/1e3:.1f} kN   "
        f"SF shear = {sf_bolt:.1f}",
        f"Bearing on 4 mm wall via 20 mm sleeve:              SF = {sf_bear:.1f}",
        f"Vertical reaction {F_vert/1e3:.1f} kN over 2 bolts:          SF = {sf_vert:.1f}",
        "Note: with full preload + crush sleeves the joint works in friction",
        "grip and these shear numbers are a lower bound.",
    ])


def main():
    print("=" * 64)
    print(" PrintTrek structural hand-calcs (beam bending + bolts)")
    print(f" Assumptions: {TOTAL_MASS:.0f} kg total, {TONGUE_MASS:.0f} kg tongue, "
          f"{DYN_VERT:.0f}g vert / {DYN_LAT}g lat")
    print("=" * 64)

    print("\nSection library (sharp-corner approximation):")
    for p in PROFILES.values():
        print(f"  {p.name:<14} A={p.area:6.0f} mm2  {p.mass_per_m:4.1f} kg/m  "
              f"W_strong={p.W('strong')/1e3:5.1f} cm3  W_weak={p.W('weak')/1e3:5.1f} cm3")

    check_drawbar(PROFILES["VKR 100x50x4"])
    # Show why the original thin bar failed, and the next size up for margin:
    check_drawbar(PROFILES["VKR 50x50x3"])
    check_side_rail(PROFILES["VKR 50x50x3"])
    check_bolts()

    print("\nRule of thumb: SF >= 2.0 on yield for dynamic off-road cases.")
    print("Re-run after any change to masses, lever arms, or profiles.")


if __name__ == "__main__":
    main()
