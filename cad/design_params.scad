// ============================================================
// DESIGN TOGGLES — the single source of truth.
//
// Read by ALL THREE consumers, so a value changed here flips the
// whole pipeline at once:
//   - cad/main_assembly.scad   (include <design_params.scad>)
//   - scripts/calculate_mass.py \  via scripts/design_params.py,
//   - scripts/gen_frame_fea.py  /  which parses this file
//
// One-off overrides WITHOUT editing this file:
//   - OpenSCAD:  -D floor_crossbars=true   (-D beats the include)
//   - Python:    FLOOR_CROSSBARS=true python3 scripts/...  (env var,
//                UPPERCASE of the name below)
//   - Pipeline:  the same env vars work for scripts/regen_all.sh,
//                which forwards them to the renders as -D flags.
//
// Keep this file to simple `name = value;` lines — the Python parser
// (scripts/design_params.py) only understands booleans and numbers.
// ============================================================

// OPTIONAL floor crossbars at x=500/1500 incl. their T-plate
// sandwiches (frame-neutral per FEA — they serve the formply floor
// span, lashing points, and the water-tank hanger).
floor_crossbars = false;

// Drawbar variant — DECIDED 2026-07-15: the V-drawbar (A-frame) is the
// DEFAULT design. Two straight square-cut 50x50x3 arms (same profile as
// the frame) + flat CNC apex-plate sandwich; combined-case SF 3.0 vs
// 1.8 for the single bar, lateral loads go axial (check_v_drawbar and
// check_v_joints in scripts/beam_check.py). false = the legacy single
// central VKR 100x50x4 bar, kept fully modeled as the alternative.
v_drawbar = true;
