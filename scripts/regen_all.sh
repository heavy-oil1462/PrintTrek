#!/usr/bin/env bash
# Regenerate EVERY derived artifact in the repo from its source of truth.
# One command after ANY design change — no ad-hoc command soup:
#
#     scripts/regen_all.sh
#
# What it rebuilds, in order:
#   fea/frame_global_*.inp   <- scripts/gen_frame_fea.py  (parametric decks)
#   fea/*_stress.png         <- CalculiX solve + scripts/plot_fea.py
#   chassis.png              <- cad/main_assembly.scad, structure only
#   main_assembly.png        <- cad/main_assembly.scad, full trailer
#   (stdout)                 <- mass & tongue-load budget summary
#
# Tool discovery (ccx, OpenSCAD, python deps) is handled by the wrapped
# scripts: $CCX / PATH / nix fallback. See scripts/run_fea.sh header.
set -euo pipefail
cd "$(dirname "$0")/.."

PY="${PYTHON:-python3}"
PYRUN=(env); case "$PY" in /nix/store/*) PYRUN=(env -u LD_LIBRARY_PATH);; esac

# Design toggles live in cad/design_params.scad (single source of truth).
# Env-var overrides (UPPERCASE name, e.g. FLOOR_CROSSBARS=true) already
# reach the Python steps via scripts/design_params.py; forward them to
# the OpenSCAD renders as -D flags so all consumers see the same values.
D_FLAGS=()
while read -r name; do
    up=$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')
    if [ -n "${!up:-}" ]; then
        D_FLAGS+=(-D "$name=${!up}")
        echo "   (env override: $name=${!up})"
    fi
done < <(sed -n 's/^[[:space:]]*\([a-z_][a-z0-9_]*\)[[:space:]]*=.*;.*/\1/p' cad/design_params.scad)

echo "== [1/4] FEA decks (scripts/gen_frame_fea.py)"
"${PYRUN[@]}" "$PY" scripts/gen_frame_fea.py

echo "== [2/4] FEA solve + stress renders (scripts/run_fea.sh)"
scripts/run_fea.sh

echo "== [3/4] CAD renders (scripts/render_scad.sh)"
scripts/render_scad.sh cad/main_assembly.scad chassis.png \
    -D show_cabin=false -D show_equipment=false
echo "   -> chassis.png"
scripts/render_scad.sh cad/main_assembly.scad main_assembly.png
echo "   -> main_assembly.png"

echo "== [4/4] Mass & tongue-load budget (scripts/calculate_mass.py)"
"${PYRUN[@]}" "$PY" scripts/calculate_mass.py | sed -n '/^----/,$p'

echo "[ok] all derived artifacts regenerated"
