---
name: openscad-review
description: Render and review the OpenSCAD models in /cad headlessly (no GUI needed). Use after any .scad change, or when asked to verify/review the CAD. Checks compile warnings, visual correctness, manifold geometry, and this project's design rules.
---

# OpenSCAD Review

Review OpenSCAD changes by actually rendering them — never approve a .scad edit from source reading alone.

## Rendering (headless)

Use the helper script — it renders without any display:

```bash
scripts/render_scad.sh cad/<file>.scad <out.png|out.stl> [extra openscad args]
```

It resolves OpenSCAD as `$OPENSCAD`, then a 2024+ openscad on PATH, then
nix (openscad-unstable + Mesa from the channel pinned in
scripts/nixpkgs_channel). Nix is the fallback, not a requirement.

Notes learned the hard way (do not rediscover these):
- `nix-shell --run` segfaults in some sandboxes; the script uses `nix-build` store paths directly instead.
- The sandbox's `LD_LIBRARY_PATH=/lib` makes nix binaries load the system libc and segfault. The script overrides `LD_LIBRARY_PATH` with only the nix GL libs (and never touches it for a PATH/AppImage binary). If you run openscad manually, do the same.
- PNG rendering needs GL: with no display the script forces Mesa software rendering via `EGL_PLATFORM=surfaceless` (no X/xvfb required). CI runs it under xvfb with the system GL runtime instead; both work.
- The 2021.01 release openscad is too old (no Manifold backend); the script rejects it and falls through to nix.

## Review procedure

1. **Render every changed .scad to PNG** (into the scratchpad dir). Capture stderr. Any `WARNING:`/`ERROR:` line or nonzero exit is a finding. Zero warnings is the expected baseline for this repo.

2. **Library-only files** (e.g. `corner_plate.scad`, `t_plate.scad` — modules with no top-level instantiation) render empty. Wrap them — the `use <>` path MUST be absolute (it resolves relative to the wrapper file, not the repo):
   ```bash
   echo 'use </workspace/cad/corner_plate.scad>; corner_plate();' > "$SCRATCH/wrap.scad"
   scripts/render_scad.sh "$SCRATCH/wrap.scad" "$SCRATCH/corner_plate.png"
   ```
   A silently-empty render (`Current top level object is empty`, or "Ignoring unknown module" warnings) usually means this path was wrong.

3. **Look at the PNGs** (Read tool). Check at minimum:
   - Parts are where they should be; nothing floating, missing, or obviously interpenetrating.
   - Plates sit flush on tubes (no z-gaps except the intentional 10 mm drawbar spacer gap).
   - Bolt holes present and inside the plate outlines.
   For assemblies, render a second orthographic top view to check 2D layout:
   ```bash
   scripts/render_scad.sh cad/frame.scad "$SCRATCH/top.png" --camera=0,700,0,0,0,0,4500 --projection=o
   ```

4. **Manifold check for CNC/print parts**: export STL and confirm no errors and a non-empty result:
   ```bash
   scripts/render_scad.sh "$SCRATCH/wrap.scad" "$SCRATCH/part.stl"
   ```

5. **Run the calculation scripts** and sanity-check their output against the change:
   ```bash
   python3 scripts/calculate_tubes.py   # steel cut list — lengths must match the CAD intent
   python3 scripts/calculate_mass.py    # weight / CG / tongue load — 5-10% tongue target
   ```
   `calculate_tubes.py` counts literal `cube()` calls in `frame.scad`/`cabin.scad`; a tube instantiated in a loop or module counts once, so keep one cube call per physical tube in those files.

## Project design rules to verify

- Bolt holes: 13 mm for M12 — ONE bolt size for every structural plate joint (reamed after hot-dip galvanizing). M10 (11 mm) survives only in non-structural mounts (gas-box bearers) and the legacy single-bar parts.
- Every through-bolt in RHS gets an internal crush sleeve — joints must have straight-through access for sleeves.
- Tube profiles: 50x50 mm (chassis), 40x40 mm (cabin). Plates: 8-10 mm 6082-T6.
- Bolt hole edge distance: washer (Ø24 for M12) must sit fully on both plate and tube face.
- Drawbar: V/A-frame is the DEFAULT (`v_drawbar` in `cad/design_params.scad`) — two straight VKR 50x50x3 arms from the coupling apex, lapped under the front crossbeam (sleeve clamp, NO holes in the arm at the crossing) and the rail ends. The single central VKR 100x50x4 bar is the preserved legacy alternative (`v_drawbar=false`); if enabled it laps to the MID crossmember (x 950-1000), ends at x=1020, and must NOT reach the torsion-axle tube (x 1070-1150, same depth). Sizing in frame.scad header and scripts/beam_check.py.
- Plate bolt patterns: 2x M12 per plate arm on the tube CENTERLINE (e2 = 1.9·d0; rationale in corner_plate.scad and check_plate_bolts in beam_check.py). The old 3x M10 zig-zag is retired — flag any NEW off-center hole that lands closer than 1.2·d0 to a tube edge.
- Gas stays right side / electrical left side; the corner "cable tunnel" radius must stay ≥ the LMR coax bend radius (~80 mm). One documented exception: the 230V CEE inlet on the front wall's right half (high), >500 mm from gas equipment.
- Galley order: LEFT front → rear: kitchen side-drawer (out through the left wall), storage cabinet. RIGHT: electrical bay, then fridge drawer out through a fridge-sized hatch on the rear RIGHT (500x520, sill-free at the floor) — the rest of the rear wall is solid. No spare wheel on the trailer (the Ranger's serves both).

## Report

Summarize per file: render OK/warnings, visual findings, rule violations. Include the rendered PNG paths so the user can look at them.
