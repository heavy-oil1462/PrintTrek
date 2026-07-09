---
name: verify
description: Verify the PrintTrek design end-to-end before committing — CAD renders in all toggle states, committed FEA decks match the generator, mass/tongue budget has no flags, hand calcs run, and global FEA safety factors stay above 1.5. One command, read-only.
---

# Verify the design

```bash
scripts/verify_design.sh
```

Read-only (writes only to a temp dir), exits non-zero on failure. Run it
before EVERY commit, and after `scripts/regen_all.sh`.

What it checks:

1. **CAD renders** — `cad/main_assembly.scad` renders headlessly with
   `floor_crossbars` both true and false (catches OpenSCAD errors and
   broken toggles). Add new design toggles to this step when introduced.
2. **FEA deck drift** — regenerates the decks in a temp dir and compares
   byte-for-byte with the committed `fea/frame_global_*.inp`. A drift
   means someone changed the generator (or a deck by hand) without
   running `scripts/regen_all.sh`.
3. **Mass & tongue budget** — `scripts/calculate_mass.py` must print no
   `[!]` lines (tongue 5–12 % window, axle rating).
4. **Hand calcs** — `scripts/beam_check.py` must run clean. Informational
   only: it prints rejected comparison profiles with `!!` on purpose, so
   the gate is the exit code, not the markers.
5. **Global FEA SF** — if `ccx` is available (found via `$CCX` → PATH →
   nix), solves both global decks in a temp dir and requires
   **SF ≥ 1.5 vs S355 yield** for every member group in both load cases.
   Skipped with a hint when no solver exists.

## Interpreting results

- A `[FAIL]` in deck drift → run `scripts/regen_all.sh`, review the diff,
  commit decks together with the change that caused them.
- A `[FAIL]` in FEA SF → a real design regression; do not "fix" by
  lowering the threshold. Check the geometry/load change that caused it,
  cross-check with `scripts/beam_check.py`.
- `[skip]` for ccx is acceptable in minimal sandboxes but NOT on the
  host — the host has CalculiX installed.
