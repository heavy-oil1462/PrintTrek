---
name: regen-outputs
description: Regenerate ALL derived artifacts for PrintTrek in one command (FEA decks, CalculiX solve, stress PNGs, chassis.png, main_assembly.png, mass budget). Use after ANY change to cad/*.scad, scripts/gen_frame_fea.py, or scripts/calculate_mass.py — never hand-run individual openscad/ccx/plot commands.
---

# Regenerate derived outputs

One command rebuilds everything that is committed but derived:

```bash
scripts/regen_all.sh
```

Pipeline order (each step wraps its own tool discovery — $CCX/PATH/nix,
`env -u LD_LIBRARY_PATH` for nix binaries):

1. `scripts/gen_frame_fea.py` → `fea/frame_global_3g.inp`, `fea/frame_global_twist.inp`
2. `scripts/run_fea.sh` → solves every `fea/*.inp`, renders `fea/*_stress.png`
3. `scripts/render_scad.sh` → `chassis.png` (structure only) + `main_assembly.png`
4. `scripts/calculate_mass.py` → mass / CG / tongue-load summary on stdout

## Rules

- Do NOT compose ad-hoc render/solve command lines; if a new artifact
  appears, add it to `regen_all.sh` so the pipeline stays the single
  entry point.
- After running, eyeball the outputs: read the PNGs back, and compare the
  per-member FEA stresses against the tables in `fea/README.md` — if a
  number moved, update that table AND the relevant SPECS.md bullet.
- The committed PNGs (`chassis.png`, `main_assembly.png`,
  `fea/*_stress.png`) are build products of this pipeline — regenerate
  them in the same change that alters their sources, never edit around
  them.
- Design toggles must stay in sync in THREE places:
  `cad/main_assembly.scad` (e.g. `floor_crossbars`),
  `scripts/calculate_mass.py` (`FLOOR_CROSSBARS`),
  `scripts/gen_frame_fea.py` (`FLOOR_CROSSBARS`).
- Finish with `scripts/verify_design.sh` (see the `verify` skill) before
  any commit.
