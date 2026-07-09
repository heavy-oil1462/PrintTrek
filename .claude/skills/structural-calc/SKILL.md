---
name: structural-calc
description: Calculate forces, stresses, and safety factors for the PrintTrek trailer structure. Use when sizing tubes/plates/bolts, when masses or lever arms change, or when asked "will it hold?". Covers quick hand-calcs (beam_check.py) and CalculiX FEA for detailed cases.
---

# Structural calculations for PrintTrek

Two tiers — always start with tier 1, escalate to tier 2 only when beam
theory genuinely can't answer the question.

## Tier 1 — hand-calcs: `scripts/beam_check.py`

```bash
python3 scripts/beam_check.py
```

Pure stdlib, runs anywhere. Contains:
- **RHS section library** (`PROFILES`): sharp-corner approximation,
  I/W/area/mass. Add profiles as one-liners.
- **Load cases**: drawbar vertical (3g × tongue), lateral (0.3g × total at
  coupling, weak axis), combined (2g + lateral, linear superposition —
  conservative), side-rail UDL, bolt-group shear/bearing for the drawbar lap.
- **Parameters at the top** must be kept in sync with `cad/frame.scad` and
  `scripts/calculate_mass.py` (TOTAL_MASS, TONGUE_MASS, LEVER_VERT = coupling
  to front crossbeam, LAP_BASE = crossbeam spacing).

Design rule: **SF ≥ 2.0 on yield (S355 = 355 MPa) for dynamic off-road
cases**; the 3g/0.3g factors are already conservative envelopes. Bolts are
8.8 (fub 800); aluminum plates 6082-T6 yield 260 MPa.

When any mass, profile, or geometry changes: update the parameters, re-run,
and copy any changed conclusion into SPECS.md (the sizing bullet under
"Drawbar" quotes these numbers).

## Tier 2 — FEA: CalculiX via nix

For joint details, plate buckling, frame torsion — see `fea/README.md`.

```bash
scripts/regen_all.sh                # ALL derived artifacts: decks + solve + renders + budget
scripts/verify_design.sh            # read-only pre-commit gate (see the `verify` skill)
scripts/run_fea.sh                  # FEA only: solve ALL decks + render PNGs
scripts/run_ccx.sh fea/<deck>       # single deck, path WITHOUT the .inp extension
python3 scripts/plot_fea.py fea/*.frd   # renders: deformed shape + von Mises PNG
```

Materials are per-part: steel `S355` (E=210000, nu=0.3) for VKR beams,
aluminum `AL6082T6` (E=70000, nu=0.33) for CNC plates — keep new decks
consistent. Rendering needs numpy+matplotlib; in this sandbox use the nix
python env (`nix-build -E 'with import <nixpkgs> {}; python3.withPackages
(ps: [ps.numpy ps.matplotlib])'`) and run it with `env -u LD_LIBRARY_PATH`.

- ccx store path (2026-07): `/nix/store/6s7v4njrfr0jv79f5mxjggb58a7kjgxv-calculix-ccx-2.22`;
  the wrapper falls back to `nix-build -I nixpkgs=channel:nixos-25.05 '<nixpkgs>' -A calculix --no-out-link`.
- **Must run with `env -u LD_LIBRARY_PATH`** (sandbox sets it to /lib which
  segfaults nix binaries) — the wrapper handles this.
- Units mm/N/MPa. Beam box sections require element type **B32R** (plain B32
  errors out).
- Results: grep `<deck>.dat` for `displacements` / `stresses` blocks.
  Columns in the stress block: elem, int.pt, sxx, syy, szz, sxy, sxz, syz.
- Validation reference: `fea/drawbar_cantilever.inp` reproduces the hand-calc
  (deflection exact, root stress within 6 % — integration points sit inside
  the extreme fiber, so ccx reads slightly LOW; treat the hand calc as the
  envelope for beam-like cases).

## Every deck / every check
- State the expected order-of-magnitude result BEFORE running; if the tool
  disagrees wildly, the model is wrong, not the structure.
- New FEA decks get a header comment with load case + expected hand-calc
  value, and a row in `fea/README.md`.
- Only `.inp` files are versioned; `.dat/.frd/.cvg/.sta/.12d` are disposable.
