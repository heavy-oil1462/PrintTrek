# FEA — CalculiX models

Finite-element checks for cases where the hand-calcs in
`scripts/beam_check.py` aren't enough (joint details, plate buckling,
combined load paths). Solver: **CalculiX (ccx) 2.22** via nix — run decks with:

```bash
scripts/run_ccx.sh fea/drawbar_cantilever
```

## Conventions
- **Units: mm, N, MPa** (E steel = 210000, densities in tonne/mm³ if ever needed).
- Beam models use `B32R` elements (`SECTION=BOX` requires the reduced-
  integration type in ccx).
- Every deck header states the load case and the expected hand-calc result —
  a model that can't be sanity-checked is worse than no model.
- Printed results go to `<deck>.dat`; field output to `<deck>.frd`
  (viewable in CalculiX GraphiX `cgx` or PrePoMax on a desktop machine).
  Output files are disposable — only `.inp` decks are versioned.

## Models

### drawbar_cantilever.inp — VALIDATED ✔
Drawbar LC1: VKR 100x50x4 standing, 1090 mm cantilever, 3g × 80 kg = 2354 N
tip load.

| Quantity           | Hand calc | ccx (B32R box) |
|--------------------|-----------|----------------|
| Tip deflection     | 3.36 mm   | 3.36 mm        |
| Root bending stress| 89.0 MPa  | 83.9 MPa*      |

\* ccx reports stress at integration points slightly inside the extreme
fiber — the ~6 % gap is expected, hand calc is the conservative envelope.

## Next candidates for FEA (when the design firms up)
- Corner-plate sandwich joint: shell/solid model of the 10 mm 6082-T6 plates
  + bolt preload, to confirm the "double sandwich" spreads the moment.
- Drawbar-to-crossbeam lap: local wall bending of the 4 mm RHS around the
  crush sleeves under the lateral couple.
- Frame torsion: one wheel on a 300 mm rock, diagonal twist of the bolted
  (non-welded) frame — bolted joints are torsionally softer than welds.
