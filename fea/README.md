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

## Next candidates for FEA (when the design firms up)
- **Drawbar cradle joint** (`cad/drawbar_cradle.scad`): contact model of
  cradle + beam + crossbeam confirming the no-hole-in-flange concept —
  see `check_joint_hole` in `scripts/beam_check.py` for why the bolt hole
  at the front crossbeam is the fatigue-governing detail.
- Local wall bending of the 4 mm RHS around the crush sleeves under the
  lateral couple.
- Frame torsion: one wheel on a 300 mm rock, diagonal twist of the bolted
  (non-welded) frame — bolted joints are torsionally softer than welds.
