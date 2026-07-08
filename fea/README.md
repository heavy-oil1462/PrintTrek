# FEA — CalculiX models

Finite-element checks for cases where the hand-calcs in
`scripts/beam_check.py` aren't enough (joint details, plate bending,
combined load paths). Solver: **CalculiX (ccx)**, open source.

## Run it (any host)

```bash
scripts/run_fea.sh          # solves every fea/*.inp + renders PNGs
```

The script finds `ccx` via `$CCX` → PATH → nix-build fallback
(Debian/Ubuntu: `apt install calculix-ccx`). Renders need
`python3` with numpy + matplotlib (`pip install numpy matplotlib`);
without them the solve still runs and the script prints a hint.
Single deck: `scripts/run_ccx.sh fea/<deck>` (no `.inp` extension).
Render manually: `python3 scripts/plot_fea.py fea/*.frd`.

## Materials (configured per part, units mm/N/MPa)

| Material | Used for | E [MPa] | ν | Yield [MPa] |
|---|---|---|---|---|
| **S355J2H steel** (`*MATERIAL, NAME=S355`) | VKR beams: frame, drawbar, crossbeams | 210 000 | 0.30 | 355 |
| **6082-T6 aluminum** (`*MATERIAL, NAME=AL6082T6`) | CNC-milled plates: corner, T, spacer, cradle | 70 000 | 0.33 | 260 |

## Conventions
- Beam models use `B32R` elements (`SECTION=BOX` requires the reduced-
  integration type in ccx); solid plate models use `C3D8I` (good in bending).
- Every deck header states the load case and the expected hand-calc result —
  a model that can't be sanity-checked is worse than no model.
- Only `.inp` decks and `_stress.png` renders are versioned; `.dat`/`.frd`
  solver output is disposable (gitignored).

## Models

### drawbar_cantilever.inp — steel, VALIDATED ✔
Drawbar LC1: VKR 100x50x4 standing, 1090 mm cantilever, 3g × 80 kg = 2354 N
tip load.

| Quantity | Hand calc | ccx |
|---|---|---|
| Tip deflection | 3.36 mm | 3.36 mm |
| Root bending stress | 89.0 MPa | 84.7 MPa* |

![Drawbar stress](drawbar_cantilever_stress.png)

### corner_plate_bending.inp — aluminum, VALIDATED ✔
Corner plate prying bound: 200×200×10 mm 6082-T6 plate, clamped strip over
the tube face, 2.5 kN transverse at the free edge (≈ drawbar-lap couple).
Conservative: one plate takes what the top+bottom sandwich pair shares.

| Quantity | Hand calc | ccx |
|---|---|---|
| Edge deflection | 2.15 mm (plate-stiffened) | 2.23 mm |
| Clamp-line stress | 113 MPa | 105.5 MPa* |

SF vs 6082-T6 yield (260 MPa): **~2.5** even in this bounding case.

![Corner plate stress](corner_plate_bending_stress.png)

\* ccx reports stress at integration points slightly inside the extreme
fiber / clamp line — reading a few % below the hand-calc envelope is
expected; use the hand calc as the conservative number.

### frame_global_3g.inp + frame_global_twist.inp — WHOLE CHASSIS
The entire load-bearing structure in one beam model: rails, THREE
crossbeams (front, mid at x 950-1000 for the drawbar lap, rear — no
beam over the axle, the bolted axle tube ties the rails there), drawbar
85 mm below the frame plane ending ahead of the axle tube, lap joints
as connectors. Vertical supports sit on the RAILS at the axle brackets
(x≈1100). Generated parametrically: `python3 scripts/gen_frame_fea.py`.

The front lap is modeled as the **angle-bracket pair** (2× L80x80x8,
`cad/drawbar_angle_joint.scad`, vertical legs lumped to a 120×16
connector); the rear lap (mid crossbeam) as the bolted spacer joint.

**LC 3g vertical** (400 kg deck × 3g, supported at coupling + axle
brackets) — max von Mises per member group:

| Member group | max vM | SF vs 355 |
|---|---|---|
| Side rails | 130 MPa | 2.7 |
| Crossbeams | 27 MPa | 13 |
| Drawbar | 19 MPa | 19* |
| Angle pair / rear lap | 4 / 34 MPa | their governing case is the *lateral* couple (~118 MPa, SF 3.0, `check_angle_joint`), not this vertical LC |

\* the isolated 3g-tongue cantilever (89 MPa) remains the drawbar's
governing envelope — dynamic pitching loads the tongue independently of
the deck. Note the rails took over from the deleted axle crossbeam:
SF dropped from ~4 to 2.7 in this bounding case (full 400 kg payload at
3g) — the price of one clean middle beam, still comfortable.

**LC diagonal racking** (three corners held, fourth lifted 30 mm): rails
65 / crossbeams 65 / drawbar 24 MPa; the rear-lap connector reads
81 MPa (load-path indicator for the bolted joint). The open ladder frame
is torsionally soft — good off-road, and stresses stay low. (A "one
wheel up" case with a ball coupling is a near-rigid roll of the whole
trailer — verified zero stress — because the ball transmits no roll
moment.)

![Global 3g](frame_global_3g_stress.png)
![Global racking](frame_global_twist_stress.png)

**Joint modeling honesty:** member intersections are rigid shared nodes
and the laps are stiff links. Bolt-level behavior (shear, bearing,
net-section fatigue at the hole) is covered by `scripts/beam_check.py`;
a true preload+contact model of one bolted joint is still open work.

## Next candidates for FEA (when the design firms up)
- **Drawbar cradle joint** (`cad/drawbar_cradle.scad`): preload+contact
  model of cradle + beam + crossbeam confirming the no-hole-in-flange
  concept — see `check_joint_hole` in `scripts/beam_check.py`.
- Local wall bending of the 4 mm RHS around the crush sleeves under the
  lateral couple.
- Semi-rigid joint stiffness in the global model (springs calibrated from
  a single-joint contact model) instead of rigid shared nodes.
