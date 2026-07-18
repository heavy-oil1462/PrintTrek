#!/usr/bin/env bash
# Design verification — read-only, writes NOTHING into the repo.
# Run before every commit:
#
#     scripts/verify_design.sh
#
# Checks, in order:
#   1. cad/main_assembly.scad renders headlessly in BOTH floor_crossbars
#      states (catches OpenSCAD errors and broken toggles)
#   2. Committed fea/frame_global_*.inp match what gen_frame_fea.py
#      produces today (no generator/deck drift)
#   3. Mass & tongue budget has no [!] flags
#   4. Hand calcs (beam_check.py) run clean — informational: it prints
#      rejected comparison profiles on purpose, so only the exit code gates
#   5. If CalculiX is available: solve the global decks in a temp dir and
#      require SF >= 1.5 vs S355 yield for every member group in the
#      bounding 3g case (skipped with a hint if ccx is missing)
#   6. Control-system validation (tools/validate.py: yamllint, esphome
#      config, compose/mosquitto/HA checks, sim contract, python)
#   7. MQTT protocol integration test (tools/test_protocol.py: throwaway
#      broker + mock device)
#
# Steps 6-7 need the devshell toolchain (esphome, yamllint, mosquitto,
# paho-mqtt). They run directly if the tools are on PATH, else through
# `nix develop`. Missing toolchain is a FAILURE, not a skip.
set -uo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
FAIL=0

PY="${PYTHON:-python3}"
PYRUN=(env); case "$PY" in /nix/store/*) PYRUN=(env -u LD_LIBRARY_PATH);; esac

step() { echo; echo "== $*"; }
bad()  { echo "   [FAIL] $*"; FAIL=1; }
ok()   { echo "   [ok] $*"; }

step "[1/7] CAD renders (all design-toggle states)"
if scripts/render_scad.sh cad/main_assembly.scad "$TMP/def.png" >/dev/null 2>&1; then
    ok "default toggles render (cad/design_params.scad)"
else
    bad "cad/main_assembly.scad does not render (default toggles)"
fi
for ovr in "floor_crossbars=true" "floor_crossbars=false" \
           "v_drawbar=true" "v_drawbar=false"; do
    if scripts/render_scad.sh cad/main_assembly.scad "$TMP/ovr.png" \
            -D "$ovr" >/dev/null 2>&1; then
        ok "$ovr renders"
    else
        bad "cad/main_assembly.scad does not render with $ovr"
    fi
done

step "[2/7] FEA deck drift (gen_frame_fea.py vs committed fea/*.inp)"
mkdir -p "$TMP/gen/fea"
(cd "$TMP/gen" && "${PYRUN[@]}" "$PY" "$ROOT/scripts/gen_frame_fea.py" >/dev/null)
# (python comparison — busybox-ish hosts may lack diff/cmp)
same() { "${PYRUN[@]}" "$PY" -c \
    'import sys,filecmp; sys.exit(0 if filecmp.cmp(sys.argv[1],sys.argv[2],shallow=False) else 1)' \
    "$1" "$2"; }
for inp in fea/frame_global_3g.inp fea/frame_global_twist.inp; do
    if same "$inp" "$TMP/gen/$inp"; then
        ok "$inp matches the generator"
    else
        bad "$inp drifted — run scripts/regen_all.sh and commit the result"
    fi
done

step "[3/7] Mass & tongue-load budget"
MASS_OUT=$("${PYRUN[@]}" "$PY" scripts/calculate_mass.py)
if echo "$MASS_OUT" | grep -F '[!]'; then
    bad "budget raises [!] flags (see above)"
else
    echo "$MASS_OUT" | grep -E "Tongue load|Curb weight" | sed 's/^/   /'
    ok "no [!] flags"
fi

step "[4/7] Hand calcs (beam_check.py, informational)"
if "${PYRUN[@]}" "$PY" scripts/beam_check.py > "$TMP/beam.txt" 2>&1; then
    grep -E "Worst case|Rule of thumb" "$TMP/beam.txt" | sed 's/^/   /'
    ok "beam_check.py ran clean (rejected comparison profiles print !! on purpose)"
else
    bad "beam_check.py crashed:"; tail -5 "$TMP/beam.txt"
fi

step "[5/7] Global FEA safety factors (needs ccx)"
if [ -n "${CCX:-}" ]; then :
elif command -v ccx >/dev/null 2>&1; then CCX=$(command -v ccx)
elif command -v nix-build >/dev/null 2>&1; then
    CCX="$(nix-build -I nixpkgs=channel:nixos-25.05 '<nixpkgs>' -A calculix --no-out-link 2>/dev/null)/bin/ccx"
fi
if [ -x "${CCX:-/nonexistent}" ]; then
    RUN=(env); case "$CCX" in /nix/store/*) RUN=(env -u LD_LIBRARY_PATH);; esac
    cp fea/frame_global_3g.inp fea/frame_global_twist.inp "$TMP/"
    for deck in frame_global_3g frame_global_twist; do
        (cd "$TMP" && "${RUN[@]}" "$CCX" "$deck" >/dev/null 2>&1)
    done
    if "${PYRUN[@]}" "$PY" - "$TMP" <<'EOF'
import re, sys
YIELD, SF_MIN, fail = 355.0, 1.5, False
for deck in ("frame_global_3g", "frame_global_twist"):
    txt = open(f"{sys.argv[1]}/{deck}.dat").read()
    parts = re.split(r" stresses \(.*?\) for set (\w+) and time.*\n", txt)
    for name, block in zip(parts[1::2], parts[2::2]):
        vm = 0.0
        for line in block.splitlines():
            p = line.split()
            if len(p) == 8:
                sxx, syy, szz, sxy, sxz, syz = map(float, p[2:8])
                vm = max(vm, (0.5*((sxx-syy)**2+(syy-szz)**2+(szz-sxx)**2)
                              + 3*(sxy**2+sxz**2+syz**2))**0.5)
        sf = YIELD / vm if vm else float("inf")
        mark = "ok" if sf >= SF_MIN else "FAIL"
        if sf < SF_MIN: fail = True
        print(f"   [{mark}] {deck} {name:8s} max vM {vm:6.1f} MPa  SF {sf:4.1f}")
sys.exit(1 if fail else 0)
EOF
    then ok "all member groups SF >= 1.5 vs S355"
    else bad "a member group is below SF 1.5 — see table above"
    fi
else
    echo "   [skip] ccx not found — install calculix or set CCX=/path/to/ccx"
fi

run_sw() {
    # Run a control-system tool with the devshell toolchain.
    if command -v esphome >/dev/null 2>&1 && command -v yamllint >/dev/null 2>&1 \
            && command -v mosquitto >/dev/null 2>&1; then
        "${PYRUN[@]}" "$PY" "$@"
    elif command -v nix >/dev/null 2>&1; then
        nix develop "$ROOT" --command python3 "$@"
    else
        echo "   [FAIL] no devshell toolchain and no nix — cannot run $1"
        return 1
    fi
}

step "[6/7] Control-system validation (tools/validate.py)"
if run_sw tools/validate.py > "$TMP/validate.txt" 2>&1; then
    ok "tools/validate.py green"
else
    bad "tools/validate.py failed:"; tail -30 "$TMP/validate.txt"
fi

step "[7/7] MQTT protocol integration test (tools/test_protocol.py)"
if run_sw tools/test_protocol.py > "$TMP/protocol.txt" 2>&1; then
    ok "protocol test green"
else
    bad "tools/test_protocol.py failed:"; tail -30 "$TMP/protocol.txt"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    echo "[ok] design verification PASSED"
else
    echo "[FAIL] design verification FAILED — fix the items above before committing"
    exit 1
fi
