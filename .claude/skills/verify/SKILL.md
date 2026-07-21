---
name: verify
description: Verify the PrintTrek design end-to-end before committing — CAD renders in all toggle states, committed FEA decks match the generator, mass/tongue budget has no flags, hand calcs run, global FEA safety factors stay above 1.5, the control-system configs validate (yamllint, esphome config, compose/HA/sim contracts), and the MQTT protocol test passes. One command, read-only.
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
   `[!]` lines (tongue 5-12 % window, axle rating).
4. **Hand calcs** — `scripts/beam_check.py` must run clean. Informational
   only: it prints rejected comparison profiles with `!!` on purpose, so
   the gate is the exit code, not the markers.
5. **Global FEA SF** — if `ccx` is available (found via `$CCX` -> PATH ->
   nix), solves both global decks in a temp dir and requires
   **SF >= 1.5 vs S355 yield** for every member group in both load cases.
   Skipped with a hint when no solver exists.
6. **Control-system validation** — `tools/validate.py`: yamllint, `esphome
   config` on both node compositions, docker compose parses, mosquitto
   auth/persistence, HA yaml + compose mounts, sim injection-key contract,
   python byte-compile.
7. **MQTT protocol test** — `tools/test_protocol.py`: throwaway broker +
   mock device, asserts the docs/PROTOCOL.md contract.

Nix is optional. Steps 6-7 need esphome, yamllint and mosquitto: from
PATH (`pip install -r requirements.txt` plus the mosquitto system
package) or, as fallback, `nix develop`. OpenSCAD resolves as
`$OPENSCAD`, then a 2024+ openscad on PATH, then nix; ccx as `$CCX`,
PATH, then nix. A missing step 6-7 toolchain is a FAILURE, not a skip.

## Interpreting results

- A `[FAIL]` in deck drift -> run `scripts/regen_all.sh`, review the diff,
  commit decks together with the change that caused them.
- A `[FAIL]` in FEA SF -> a real design regression; do not "fix" by
  lowering the threshold. Check the geometry/load change that caused it,
  cross-check with `scripts/beam_check.py`.
- `[skip]` for ccx is acceptable in minimal sandboxes but NOT on the
  host — the host has CalculiX installed.
- A `[FAIL]` in step 6/7 prints the tool's tail; run the tool directly for
  the full report (`nix develop -c python3 tools/validate.py`).

## CI

CI (.github/workflows) runs the same gates from pip, no nix, split by
paths: validate.yml runs tools/validate.py + tools/test_protocol.py on
every change; design.yml runs the full scripts/verify_design.sh (apt
CalculiX, OpenSCAD snapshot AppImage) when cad/fea/scripts/tools move;
firmware.yml compiles both node configs when esphome/ moves. Never let
CI and this skill drift apart: a check added here gets added there in
the same change.

## Notes

The control-system gate framework lives in the esphome-skills package
(flake input); the repo side is tools/project.py + tools/validate.py.
Canonical doc and landmines (NIX_CONFIG for sandboxes, running without
nix, esphome config vs compile):
https://github.com/heavy-oil1462/esphome-skills/blob/main/skills/verify.md
