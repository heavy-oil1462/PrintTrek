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
LAP_BASE = 0.95           # m, drawbar lap: front crossbeam -> mid crossmember
                          # (the beam stops short of the axle tube, so the
                          # rear lap sits at x~975, not at the axle beam)
DYN_VERT = 3.0            # g, vertical dynamic factor (off-road)
DYN_LAT = 0.3             # g, lateral factor on total mass at the coupling

FRAME_PAYLOAD = 400.0     # kg carried on the frame deck (body+cargo, no axle/drawbar)
RAIL_SPAN = 1.20          # m, governing side-rail span (front crossbeam ->
                          # axle-bracket support; mid crossbeam is a tie,
                          # not a vertical support)


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
    "VKR 100x50x5":  RHS("VKR 100x50x5", 50, 100, 5),   # thicker wall, same outer
    "VKR 100x50x6":  RHS("VKR 100x50x6", 50, 100, 6),   # thicker still
    "VKR 120x60x4":  RHS("VKR 120x60x4", 60, 120, 4),   # deeper profile option
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


def check_v_drawbar(profile: RHS, attach_x=0.600, apex_x=-1.000,
                    coupling_x=-1.090, half_spread=0.575, cross_x=0.025):
    """V-drawbar (A-frame) alternative: two straight square-cut tubes from
    the coupling apex, bolted under the front crossbeam and the side-rail
    ends. No welds, no miter cuts — the apex is tied by a CNC-milled
    V-plate top+bottom sandwich (cad/v_apex_plate.scad) and the angled
    laps get wedge spacer plates (cad/drawbar_wedge_plate.scad).

    Why it beats the single bar: the lateral load case (which governs the
    single bar as weak-axis bending + a lap couple) resolves into pure
    AXIAL tension/compression through the triangle. Vertical tongue load
    splits over two arms. Geometry defaults match cad/frame.scad."""
    import math
    dx = attach_x - apex_x                       # 1.600 m plan run
    theta = math.atan2(half_spread, dx)          # arm half-angle ~19.8 deg
    # arm crossing point under the front crossbeam (offset from centerline)
    y_cross = half_spread * (cross_x - apex_x) / dx
    lever1 = math.hypot(cross_x - coupling_x, y_cross)   # coupling -> crossing
    back = math.hypot(attach_x - cross_x, half_spread - y_cross)  # crossing -> rail end
    arm_free = (cross_x - apex_x) / math.cos(theta)      # apex -> crossing, along arm

    out = [f"Profile: 2x {profile.name} straight arms "
           f"(half-angle {math.degrees(theta):.1f} deg, "
           f"~{(math.hypot(dx, half_spread)):.2f} m each, "
           f"{2*math.hypot(dx, half_spread)*profile.mass_per_m:.1f} kg the pair)"]

    # LC1 — vertical: dynamic tongue load shared by both arms
    M1 = (TONGUE_MASS / 2) * DYN_VERT * G * lever1        # Nm per arm
    s1 = M1 * 1e3 / profile.W("strong")
    out.append(f"LC1 vertical  {DYN_VERT:.0f}g x {TONGUE_MASS:.0f} kg over 2 arms x "
               f"{lever1:.2f} m = {M1:.0f} Nm/arm -> {s1:.0f} MPa   SF = {sf(s1):.2f}")

    # LC2 — lateral: resolves AXIALLY through the V (one arm tension,
    # one compression) instead of weak-axis bending
    F2 = DYN_LAT * TOTAL_MASS * G
    N = F2 / (2 * math.sin(theta))
    s2 = N / profile.area
    out.append(f"LC2 lateral   {F2:.0f} N -> AXIAL {N/1e3:.1f} kN per arm "
               f"-> {s2:.0f} MPa   SF = {sf(s2):.0f}  (single bar: bending!)")

    # Buckling of the compression arm (pinned apex -> crossbeam crossing)
    Pcr = math.pi**2 * 210000 * profile.I("weak") / (arm_free * 1e3)**2
    out.append(f"Arm buckling  Pcr = {Pcr/1e3:.0f} kN vs {N/1e3:.1f} kN "
               f"-> SF = {Pcr/N:.0f}")

    # LC3 — combined: 2g vertical + full lateral (linear interaction)
    s3 = (2.0 / DYN_VERT) * s1 + s2
    out.append(f"LC3 combined  2g vertical + LC2 lateral -> {s3:.0f} MPa   "
               f"SF = {sf(s3):.2f}")

    # Front crossbeam bending from the arm's vertical reaction at the
    # crossing (load lands at y_cross instead of mid-span like the single bar)
    R = (TONGUE_MASS / 2) * DYN_VERT * G * (lever1 + back) / back
    # two symmetric loads R at +/- y_cross, supports at the rail
    # centerlines (+/- half_spread): M under the load = R x edge distance
    M_cb = R * (half_spread - y_cross)   # Nm
    s_cb = M_cb * 1e3 / PROFILES["VKR 50x50x3"].W("strong")
    out.append(f"Crossbeam     reaction {R/1e3:.1f} kN at {1000*y_cross:.0f} mm "
               f"off-center -> {M_cb:.0f} Nm -> {s_cb:.0f} MPa   SF = {sf(s_cb):.2f}")

    worst = max(s1, s2, s3)
    verdict = "OK" if sf(worst) >= 2.0 else "!! SF < 2.0 — upsize or steepen the V"
    out.append(f"Worst case:   {worst:.0f} MPa vs S355 -> SF = {sf(worst):.2f}   [{verdict}]")
    out.append("Same profile as the frame -> ONE tube size for the whole trailer;")
    out.append("no lap couple into the mid crossbeam (frees the space under the deck).")
    report(f"V-DRAWBAR (A-frame) — 2x {profile.name}, straight square-cut arms", out)
    return sf(worst)


def check_v_joints(attach_x=0.600, apex_x=-1.000, coupling_x=-1.090,
                   half_spread=0.575, cross_x=0.025):
    """Bolt preload & FRICTION-GRIP budget for the V-drawbar's bolted
    joints. The global FEA idealizes joints as rigid shared nodes and
    does NOT model bolts (gen_frame_fea.py header) — THIS check is where
    the bolts live.

    Design philosophy the numbers below verify: torque every M12 to full
    preload (the crush sleeves exist exactly so the RHS walls survive
    that), and the PRELOAD FRICTION carries all service loads — the
    bolts never work in shear/bearing, the plates never slip, and the
    holes stay clamped shut (which is also the fatigue story)."""
    import math
    profile = PROFILES["VKR 50x50x3"]
    dx = attach_x - apex_x
    theta = math.atan2(half_spread, dx)
    y_cross = half_spread * (cross_x - apex_x) / dx
    lever1 = math.hypot(cross_x - coupling_x, y_cross)
    back = math.hypot(attach_x - cross_x, half_spread - y_cross)

    # --- demands (N), from the same geometry as check_v_drawbar -------
    F_ax = DYN_LAT * TOTAL_MASS * G / (2 * math.sin(theta))  # LC2 axial/arm
    F_v = (TONGUE_MASS / 2) * DYN_VERT * G                   # 3g vertical/arm
    R_cb = F_v * (lever1 + back) / back                      # crossbeam lap
    R_rail = R_cb - F_v                                      # rail-end lap
    D_apex = math.hypot(F_ax, F_v)
    D_cb = math.hypot(F_ax, R_cb)      # all axial dumped at one lap (conservative)
    D_rail = math.hypot(F_ax, R_rail)

    # --- capacity: M12 8.8 at FULL preload, friction grip -------------
    A_s = 84.3                                   # mm2 stress area
    Fp = 0.7 * FUB_8_8 * A_s                     # EC3 F_p,C = 47.2 kN
    torque = 0.16 * 12.0 * Fp / 1e3              # Nm, lightly oiled (K=0.16)
    mu = 0.2   # conservative: galvanized zinc / milled 6082 with Duralac
    slip = mu * Fp                               # per bolt, per interface
    cap_apex = 2 * 2 * slip   # 2 bolts/arm x 2 planes (top+bottom plate)
    cap_lap = 2 * slip        # 2 bolts, stack interfaces in series

    out = [
        f"Preload: M12 8.8 F_p,C = 0.7 x fub x As = {Fp/1e3:.1f} kN "
        f"(~{torque:.0f} Nm, needs the crush sleeves)",
        f"Slip capacity per bolt & interface: mu={mu} x Fp = {slip/1e3:.1f} kN",
        f"Apex plates  demand {D_apex/1e3:.1f} kN vs grip {cap_apex/1e3:.1f} kN"
        f"   SF = {cap_apex/D_apex:.1f}  (2 bolts x 2 faying planes)",
        f"Crossbeam lap demand {D_cb/1e3:.1f} kN vs grip {cap_lap/1e3:.1f} kN"
        f"   SF = {cap_lap/D_cb:.1f}",
        f"Rail-end lap  demand {D_rail/1e3:.1f} kN vs grip {cap_lap/1e3:.1f} kN"
        f"   SF = {cap_lap/D_rail:.1f}",
        f"(bolt SHEAR capacity if friction were lost entirely: "
        f"{0.6*FUB_8_8*A_s/1e3:.1f} kN/plane — an order above any demand)",
    ]

    # --- fatigue: why the CROSSBEAM lap must be a CLAMP ----------------
    # The crossbeam crossing is the arm's peak-moment point. A 13 mm hole
    # through the flanges there fails the fatigue check; a clamp (square
    # U-bolts + the wedge plate, no holes in the arm) passes with margin.
    d_hole, t = 13.0, profile.t
    half = profile.H / 2 - t / 2
    W_net = (profile.I("strong") - 2 * (d_hole * t) * half**2) / (profile.H / 2)
    M_fat = (TONGUE_MASS / 2) * 2.0 * G * lever1 * 1e3       # 2g washboard, Nmm
    ds_hole = M_fat / W_net                                  # EC3 cat ~90
    ds_gross = M_fat / profile.W("strong")                   # plain member cat ~160
    out += [
        f"Fatigue at the crossbeam crossing (arm peak moment, 2g range):",
        f"  with 13 mm flange holes: {ds_hole:.0f} MPa vs cat 90 -> "
        f"{'OK' if ds_hole < 90 else 'NOT OK'} — so NO holes there;",
        f"  clamped (square U-bolts, no holes): {ds_gross:.0f} MPa vs "
        f"cat 160 -> OK (margin {160/ds_gross:.2f}x)",
        "  -> DECIDED: crossbeam lap = M12 square U-bolt clamp + wedge",
        "     plate; through-bolts only at the rail ends and apex plates",
        "     (arm moment ~zero there — holes are harmless).",
    ]
    report("V-DRAWBAR JOINTS — preload, friction grip, fatigue", out)


def check_side_rail(profile: RHS):
    # Each rail carries half the deck payload as a UDL; governing span is
    # front crossbeam -> axle-bracket support (rear of frame is a cantilever
    # with less moment). Simply-supported is conservative vs. the real
    # continuous beam.
    w = (FRAME_PAYLOAD / 2.0) * DYN_VERT * G / 2.0   # N/m over the 2 m rail
    M = w * RAIL_SPAN**2 / 8.0
    s = M * 1e3 / profile.W("strong")
    verdict = "OK" if sf(s) >= 2.0 else "!! SF < 2.0"
    report(f"SIDE RAIL — {profile.name}, {RAIL_SPAN} m span", [
        f"UDL {w:.0f} N/m ({DYN_VERT:.0f}g on {FRAME_PAYLOAD:.0f} kg deck, per rail)",
        f"M = wL2/8 = {M:.0f} Nm -> {s:.0f} MPa   SF = {sf(s):.2f}   [{verdict}]",
    ])
    return sf(s)


def check_joint_hole(profile: RHS, d_hole=13.0):
    """The REAL weak point of the bolted drawbar: the bolt hole through the
    tension flange at the front crossbeam — exactly where the bending moment
    peaks. Net-section loss is modest, but the hole is a stress raiser
    (kt ~ 2.5) sitting at the fatigue hot spot."""
    t = profile.t
    half = profile.H / 2 - t / 2
    dI = 2 * (d_hole * t) * half**2          # hole through both flanges
    I_net = profile.I("strong") - dI
    W_net = I_net / (profile.H / 2)

    M = TONGUE_MASS * DYN_VERT * G * LEVER_VERT     # 3g event, Nm
    s_gross = M * 1e3 / profile.W("strong")
    s_net = M * 1e3 / W_net
    kt = 2.5
    s_peak = s_net * kt

    # Fatigue: washboard driving cycles the tongue load roughly 0..2g.
    M_fat = TONGUE_MASS * 2.0 * G * LEVER_VERT
    ds_net = M_fat * 1e3 / W_net                    # nominal net-section range
    CAT = 90.0   # EC3 detail category, net section at unfilled hole [MPa]

    report(f"DRAWBAR JOINT — {d_hole:.0f} mm hole at the front crossbeam "
           f"({profile.name})", [
        f"W gross {profile.W('strong')/1e3:.1f} -> net {W_net/1e3:.1f} cm3 "
        f"({100*(1 - W_net/profile.W('strong')):.0f}% loss)",
        f"3g event:  gross {s_gross:.0f} / net {s_net:.0f} / "
        f"peak at hole edge (kt={kt}) {s_peak:.0f} MPa   "
        f"static SF = {sf(s_net):.1f}",
        f"Fatigue:   2g washboard range = {ds_net:.0f} MPa net vs detail "
        f"category ~{CAT:.0f} MPa -> {'OK' if ds_net < CAT else 'NOT OK'}"
        f" (margin {CAT/ds_net:.2f}x)",
        "-> Statically fine; FATIGUE is what governs this hole. A preloaded",
        "   bolt + crush sleeve improves it (filled hole, load bypass via",
        "   friction). Best fix: NO hole at the peak-moment joint — clamp",
        "   the beam in a milled cradle instead (cad/drawbar_cradle.scad):",
        "   vertical bolts pass BESIDE the beam, horizontal bolts through",
        "   the webs at the NEUTRAL AXIS where bending stress is ~zero.",
    ])


def check_angle_joint(leg=80.0, t=8.0, length=120.0):
    """Budget alternative to the milled cradle: two hot-rolled steel angles
    (e.g. L80x80x8, 120 mm long) flanking the beam at the front crossbeam.
    Same concept: horizontal M12 through the beam WEBS at the neutral axis,
    vertical M10 through the horizontal legs beside the beam. The angles'
    weak spot is leg bending about the corner ("prying") under the lateral
    couple — that is what this check sizes."""
    F_lat = DYN_LAT * TOTAL_MASS * G
    F_joint = F_lat * LEVER_VERT / LAP_BASE + F_lat   # worst crossbeam, N

    lever = 60.0        # mm, corner (at crossbeam face) -> web bolt line (NA)
    m = F_joint * lever / length                      # Nmm per mm of angle
    W_mm = t**2 / 6.0
    s_one = m / W_mm                                  # one angle alone
    s_pair = s_one / 2.0                              # through-bolts couple both

    report(f"ANGLE-BRACKET JOINT — 2x L{leg:.0f}x{leg:.0f}x{t:.0f} "
           f"x {length:.0f} mm (cradle alternative)", [
        f"Lateral force at worst joint: {F_joint/1e3:.1f} kN, "
        f"lever corner->NA bolt = {lever:.0f} mm",
        f"Leg bending: one angle {s_one:.0f} MPa / pair sharing "
        f"{s_pair:.0f} MPa   SF = {sf(s_pair):.1f}",
        f"(t=6 mm would give {s_pair*(t/6.0)**2:.0f} MPa -> "
        f"SF {sf(s_pair*(t/6.0)**2):.1f} — use 8 mm legs)",
        "Same fatigue advantage as the cradle: NO holes in the beam",
        "flanges; web holes at the neutral axis. Angles are hot-rolled",
        "S355, galvanized with the frame — no galvanic interface at all.",
    ])


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

    # THE drawbar (DEFAULT design): V of two 50x50x3 arms + its joints
    check_v_drawbar(PROFILES["VKR 50x50x3"])
    check_v_joints()
    # Legacy comparison: the single central bar it replaced, and why one
    # thin bar alone never worked:
    check_drawbar(PROFILES["VKR 100x50x4"])
    check_drawbar(PROFILES["VKR 50x50x3"])
    check_side_rail(PROFILES["VKR 50x50x3"])
    check_joint_hole(PROFILES["VKR 100x50x4"])
    check_angle_joint()
    check_bolts()

    print("\nRule of thumb: SF >= 2.0 on yield for dynamic off-road cases.")
    print("Re-run after any change to masses, lever arms, or profiles.")


if __name__ == "__main__":
    main()
