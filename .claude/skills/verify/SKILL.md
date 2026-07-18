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

Steps 6-7 need the devshell toolchain (esphome, yamllint, mosquitto); the
script uses PATH binaries when present and falls back to `nix develop`.
A missing toolchain is a FAILURE, not a skip.

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

## Notes (sandbox landmines)

- In sandboxes where nix lacks a build group, export first:
  `export NIX_CONFIG="experimental-features = nix-command flakes
  build-users-group =
  sandbox = false"`
- Without nix: needs `yamllint`, `esphome` (or `.venv/bin/esphome`),
  `mosquitto`, and python3.11+ with pyyaml + paho-mqtt on PATH.
- Full firmware C++ build is NOT part of the gate (slow):
  `nix develop -c esphome compile esphome/example-trailer.yaml` after
  touching lambdas — `esphome config` does not catch C++ errors.
