#!/usr/bin/env python3
"""
Generate the GLOBAL chassis FEA decks: the entire load-bearing structure
in one model — side rails, crossbeams, the drawbar, and the lap joints
as short stiff links.

    python3 scripts/gen_frame_fea.py     # writes fea/frame_global_*.inp
    scripts/run_fea.sh                   # solve + render everything

Drawbar variants (v_drawbar in cad/design_params.scad, DEFAULT = V):
  V-drawbar   — two straight VKR 50x50x3 arms from the coupling apex,
                tied by the apex-plate sandwich (arms share the apex
                node), lapped under the front crossbeam and the rail
                ends (short vertical connectors = the bolted laps)
  single bar  — legacy: central VKR 100x50x4 hanging 85 mm below the
                frame centerline, angle clamp + rear lap connectors

Writes two decks:
  frame_global_3g.inp    — 3g vertical on the 400 kg deck payload,
                           supported at coupling + axle brackets
  frame_global_twist.inp — diagonal racking: three corners held, the
                           fourth lifted 30 mm (frame torsion, the
                           classic weakness of a BOLTED frame)

Joint modeling honesty: member intersections share nodes (= rigid), and
BOLTS ARE NOT MODELED DISCRETELY — no preload, no contact, no friction.
That is a fair approximation for the preloaded double-sandwich plate
joints IN BENDING (full preload keeps faying surfaces closed, so the
joint moves as one body until slip), but it overestimates torsional
joint stiffness — treat twist-case stresses as load-path indicators,
not exact values. Bolt-level checks (preload, friction grip, shear,
bearing, net-section fatigue) live in beam_check.py (check_v_joints,
check_bolts); a true preload+contact model of one joint is listed in
fea/README.md as future work.

Units mm/N/MPa. Steel S355 beams throughout (plates don't appear in a
beam model; their checks are corner_plate_bending.inp + beam_check.py).
"""

FRAME_L = 2000.0
FRAME_W = 1200.0
AXLE_X = 1200.0
DRAWBAR_Z = -85.0        # 25 (half tube) + 10 (spacer/cradle web) + 50 (half bar)
COUPLING_X = -1090.0
DECK_KG = 400.0
G = 9.81
# Design toggles come from the single source cad/design_params.scad
# (env vars override, e.g. FLOOR_CROSSBARS=true — see design_params.py).
from design_params import PARAMS

# OPTIONAL floor crossbars at x=500/1500. FEA verdict: frame-member
# stresses are unchanged either way (they serve the floor, not the frame).
FLOOR_CROSSBARS = PARAMS["floor_crossbars"]
V_DRAWBAR = PARAMS["v_drawbar"]

# V-drawbar geometry (matches cad/frame.scad, in the FEA's rail-centerline
# idealization: rails at y=0/FRAME_W, so the half-spread is FRAME_W/2)
V_ATTACH_X = 600.0       # arm rear ends under the rails
V_APEX_X = -1000.0       # arm centerline convergence (apex plates)
V_Z = -35.0              # arm centerline: 10 (plate gap) + 25 (half tube)

nodes = {}      # (x,y,z) -> id
coords = []


def nid(x, y, z):
    key = (round(x, 2), round(y, 2), round(z, 2))
    if key not in nodes:
        nodes[key] = len(nodes) + 1
        coords.append(key)
    return nodes[key]


def line_nodes(p0, p1, nint):
    """nint intervals (must be even for B32R pairing) -> node id list."""
    return [nid(p0[0] + (p1[0] - p0[0]) * i / nint,
                p0[1] + (p1[1] - p0[1]) * i / nint,
                p0[2] + (p1[2] - p0[2]) * i / nint) for i in range(nint + 1)]


elements = []   # (elset, [n1, n2, n3])


def beam(p0, p1, nint, elset):
    ids = line_nodes(p0, p1, nint)
    for k in range(0, nint, 2):
        elements.append((elset, [ids[k], ids[k + 1], ids[k + 2]]))
    return ids


# --- geometry (centerlines) -------------------------------------------
MID_X = 1000.0   # mid crossmember: rear drawbar lap (the beam ends at
                 # x=1020, short of the axle tube crossing at x 1070-1150)

railL = beam((0, 0, 0), (FRAME_L, 0, 0), 20, "RAILS")
railR = beam((0, FRAME_W, 0), (FRAME_L, FRAME_W, 0), 20, "RAILS")

# arm crossing points under the front crossbeam (V-drawbar): the front
# crossbeam is generated in segments so shared nodes exist exactly there
Y_CROSS = FRAME_W / 2 * (0 - V_APEX_X) / (V_ATTACH_X - V_APEX_X)  # 375 off-center
if V_DRAWBAR:
    beam((0, 0, 0), (0, FRAME_W / 2 - Y_CROSS, 0), 4, "CROSS")
    beam((0, FRAME_W / 2 - Y_CROSS, 0), (0, FRAME_W / 2 + Y_CROSS, 0), 8, "CROSS")
    beam((0, FRAME_W / 2 + Y_CROSS, 0), (0, FRAME_W, 0), 4, "CROSS")
else:
    beam((0, 0, 0), (0, FRAME_W, 0), 12, "CROSS")
beam((MID_X, 0, 0), (MID_X, FRAME_W, 0), 12, "CROSS")
beam((FRAME_L, 0, 0), (FRAME_L, FRAME_W, 0), 12, "CROSS")
if FLOOR_CROSSBARS:
    beam((500, 0, 0), (500, FRAME_W, 0), 12, "CROSS")     # floor crossbar
    beam((1500, 0, 0), (1500, FRAME_W, 0), 12, "CROSS")   # floor crossbar / tank hanger
# No crossbeam over the axle: the bolted torsion-axle tube ties the
# rails there. Its rail brackets (near x=1100) are the vertical supports.

if V_DRAWBAR:
    # V-drawbar: two straight arms, rail end -> crossbeam crossing ->
    # apex. Both arms SHARE the apex node = the top+bottom apex-plate
    # sandwich that ties them (cad/v_apex_plate.scad). The bolted laps
    # (wedge plates + M12/U-bolt clamps) become short vertical
    # connectors, elset VJOINT — their stress indicates joint loading.
    # APEX = the plate-pair nose region carrying the coupling head.
    for s in (-1, 1):
        y_rail = FRAME_W / 2 + s * FRAME_W / 2          # 0 / 1200
        y_c = FRAME_W / 2 + s * Y_CROSS                 # 225 / 975
        beam((V_ATTACH_X, y_rail, V_Z), (0, y_c, V_Z), 6, "DRAWBAR")
        beam((0, y_c, V_Z), (V_APEX_X, FRAME_W / 2, V_Z), 10, "DRAWBAR")
        beam((V_ATTACH_X, y_rail, 0), (V_ATTACH_X, y_rail, V_Z), 2, "VJOINT")
        beam((0, y_c, 0), (0, y_c, V_Z), 2, "VJOINT")
    beam((V_APEX_X, FRAME_W / 2, V_Z), (COUPLING_X, FRAME_W / 2, V_Z), 2, "APEX")
    coupling = nid(COUPLING_X, FRAME_W / 2, V_Z)
else:
    # Single central bar (legacy alternative)
    beam((COUPLING_X, FRAME_W / 2, DRAWBAR_Z), (0, FRAME_W / 2, DRAWBAR_Z), 20, "DRAWBAR")
    beam((0, FRAME_W / 2, DRAWBAR_Z), (MID_X, FRAME_W / 2, DRAWBAR_Z), 10, "DRAWBAR")
    beam((MID_X, FRAME_W / 2, DRAWBAR_Z), (MID_X + 20, FRAME_W / 2, DRAWBAR_Z), 2, "DRAWBAR")
    # Lap joints: short links crossbeam centerline -> drawbar centerline.
    # Front lap = the ANGLE-BRACKET pair (2x L80x80x8, see
    # cad/drawbar_angle_joint.scad): modeled as a connector with the two
    # vertical legs lumped into one RECT 120x16 section — its stresses
    # indicate how hard the angles work. Rear lap (mid crossmember) = plain
    # bolted spacer joint, modeled as a stiff 30x30 connector.
    beam((0, FRAME_W / 2, 0), (0, FRAME_W / 2, DRAWBAR_Z), 2, "ANGLES")
    beam((MID_X, FRAME_W / 2, 0), (MID_X, FRAME_W / 2, DRAWBAR_Z), 2, "LAPLINK")
    coupling = nid(COUPLING_X, FRAME_W / 2, DRAWBAR_Z)
# Axle brackets clamp UNDER the rails at the tube (x~1100), not to a
# crossbeam — support the rail nodes there.
brk1 = nid(1100, 0, 0)
brk2 = nid(1100, FRAME_W, 0)


GROUPS = (("RAILS", "CROSS", "DRAWBAR", "APEX", "VJOINT") if V_DRAWBAR
          else ("RAILS", "CROSS", "DRAWBAR", "ANGLES", "LAPLINK"))


def mesh_lines():
    out = ["*NODE, NSET=NALL"]
    for i, (x, y, z) in enumerate(coords, 1):
        out.append(f"{i}, {x}, {y}, {z}")
    for elset in GROUPS:
        out.append(f"*ELEMENT, TYPE=B32R, ELSET={elset}")
        for i, (es, conn) in enumerate(elements, 1):
            if es == elset:
                out.append(f"{i}, {conn[0]}, {conn[1]}, {conn[2]}")
    out += ["*MATERIAL, NAME=S355",
            "*ELASTIC", "210000., 0.3",
            "*BEAM SECTION, ELSET=RAILS, MATERIAL=S355, SECTION=BOX",
            "50., 50., 3., 3., 3., 3.", "0., 0., 1.",
            "*BEAM SECTION, ELSET=CROSS, MATERIAL=S355, SECTION=BOX",
            "50., 50., 3., 3., 3., 3.", "0., 0., 1."]
    if V_DRAWBAR:
        out += [
            # V arms: same profile as the frame
            "*BEAM SECTION, ELSET=DRAWBAR, MATERIAL=S355, SECTION=BOX",
            "50., 50., 3., 3., 3., 3.", "0., 0., 1.",
            # apex: the plate-pair nose (2x 10 mm plates ~60 mm apart)
            # lumped to a stiff RECT — stresses are load-path indicators
            "*BEAM SECTION, ELSET=APEX, MATERIAL=S355, SECTION=RECT",
            "110., 70.", "0., 1., 0.",
            # bolted laps (wedge plate + clamp): stiff 30x30 connectors
            "*BEAM SECTION, ELSET=VJOINT, MATERIAL=S355, SECTION=RECT",
            "30., 30.", "1., 0., 0."]
    else:
        out += [
            "*BEAM SECTION, ELSET=DRAWBAR, MATERIAL=S355, SECTION=BOX",
            "50., 100., 4., 4., 4., 4.", "0., 1., 0.",
            # front lap: angle pair L80x80x8 — two 120x8 vertical legs
            # lumped to RECT 120(x) x 16(y); stresses ~ angle loading
            "*BEAM SECTION, ELSET=ANGLES, MATERIAL=S355, SECTION=RECT",
            "120., 16.", "1., 0., 0.",
            # axle lap: plain bolted spacer joint, stiff 30x30 connector
            "*BEAM SECTION, ELSET=LAPLINK, MATERIAL=S355, SECTION=RECT",
            "30., 30.", "1., 0., 0."]
    return out


def write(path, extra):
    with open(path, "w") as f:
        f.write("\n".join(mesh_lines() + extra) + "\n")
    print(f"wrote {path}: {len(coords)} nodes, {len(elements)} elements")


# --- LC A: 3g vertical on the deck payload ----------------------------
rail_nodes = sorted(set(railL + railR))
F = -DECK_KG * 3.0 * G / len(rail_nodes)
lc_3g = ["** LC: 3g vertical, 400 kg deck payload spread over both rails.",
         f"** Total {DECK_KG*3*G:.0f} N down; supports: coupling + axle brackets.",
         "** Hand-calc envelope for comparison: isolated rail UDL gives ~64 MPa;",
         "** the continuous frame should come in lower.",
         "*BOUNDARY",
         f"{coupling}, 1, 3", f"{brk1}, 3, 3", f"{brk2}, 3, 3", f"{brk1}, 2, 2",
         "*STEP", "*STATIC", "*CLOAD"]
EL_PRINT = [x for g in GROUPS for x in (f"*EL PRINT, ELSET={g}", "S")]

lc_3g += [f"{n}, 3, {F:.3f}" for n in rail_nodes]
lc_3g += ["*NODE FILE", "U", "*EL FILE", "S"] + EL_PRINT
lc_3g += ["*NODE PRINT, NSET=NALL, TOTALS=ONLY", "RF", "*END STEP"]
write("fea/frame_global_3g.inp", lc_3g)

# --- LC B: frame torsion (diagonal racking test) ------------------------
# NOTE: "one wheel up" with a ball coupling is a near-rigid ROLL of the
# whole trailer (verified: zero stress) — the ball transmits no roll
# moment. Frame torsion really appears when the frame is racked
# diagonally: dynamic corner loads, diagonal jacking, twisted terrain
# under the stabilizers. Classic test: hold three corners, lift the 4th.
LIFT = 30.0   # mm diagonal racking
c1 = nid(0, 0, 0); c2 = nid(0, FRAME_W, 0)
c3 = nid(FRAME_L, 0, 0); c4 = nid(FRAME_L, FRAME_W, 0)
lc_tw = ["** LC: diagonal racking - three frame corners held, the fourth",
         "** lifted 30 mm. Shows the torsional load path of the BOLTED",
         "** (non-welded) frame. Joints idealized rigid -> stresses are",
         "** load-path indicators; RF at the lifted corner = torsional",
         "** stiffness of the ladder frame.",
         "*BOUNDARY",
         f"{c1}, 1, 3", f"{c2}, 1, 1", f"{c2}, 3, 3", f"{c3}, 3, 3",
         "*STEP", "*STATIC",
         "*BOUNDARY",
         f"{c4}, 3, 3, {LIFT}",
         "*NODE FILE", "U", "*EL FILE", "S"] + EL_PRINT + [
         "*NODE PRINT, NSET=NALL, TOTALS=ONLY", "RF", "*END STEP"]
write("fea/frame_global_twist.inp", lc_tw)
