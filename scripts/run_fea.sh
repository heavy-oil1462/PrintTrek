#!/usr/bin/env bash
# PrintTrek FEA pipeline — runs every deck in fea/ through CalculiX and
# renders the results (deformed shape, von Mises) to fea/<name>_stress.png.
#
# Designed to run DIRECTLY ON ANY HOST:
#     scripts/run_fea.sh
#
# Needs:
#   - CalculiX ccx  — found via (in order): $CCX, ccx on PATH, nix-build.
#     Debian/Ubuntu: apt install calculix-ccx      macOS: brew install calculix
#   - python3 with numpy + matplotlib for the renders (skipped with a hint
#     if missing):  pip install numpy matplotlib
set -euo pipefail
cd "$(dirname "$0")/.."

# --- locate ccx --------------------------------------------------------
if [ -n "${CCX:-}" ]; then
    :
elif command -v ccx >/dev/null 2>&1; then
    CCX=$(command -v ccx)
elif command -v nix-build >/dev/null 2>&1; then
    echo "[i] ccx not on PATH - building via nix (first run downloads ~40 MB)"
    CCX="$(nix-build -I "nixpkgs=$(cat scripts/nixpkgs_channel)" '<nixpkgs>' -A calculix --no-out-link)/bin/ccx"
else
    echo "ERROR: CalculiX 'ccx' not found." >&2
    echo "  Debian/Ubuntu:  sudo apt install calculix-ccx" >&2
    echo "  Or set CCX=/path/to/ccx" >&2
    exit 1
fi

# Nix store binaries must not see a host LD_LIBRARY_PATH (loads wrong libc)
RUN=(env)
case "$CCX" in /nix/store/*) RUN=(env -u LD_LIBRARY_PATH);; esac
echo "[i] using ccx: $CCX"

# --- solve every deck --------------------------------------------------
for inp in fea/*.inp; do
    deck="${inp%.inp}"
    echo "== solving ${deck}"
    (cd fea && "${RUN[@]}" "$CCX" "$(basename "$deck")" > /dev/null)
done

# --- render results ----------------------------------------------------
PY="${PYTHON:-python3}"
PYRUN=(env)
case "$PY" in /nix/store/*) PYRUN=(env -u LD_LIBRARY_PATH);; esac
if "${PYRUN[@]}" "$PY" -c "import numpy, matplotlib" 2>/dev/null; then
    "${PYRUN[@]}" "$PY" scripts/plot_fea.py fea/*.frd
else
    echo "[!] Skipping renders: python3 with numpy+matplotlib not found."
    echo "    pip install numpy matplotlib   then:  python3 scripts/plot_fea.py fea/*.frd"
fi

# transient solver files are noise
rm -f fea/*.cvg fea/*.sta fea/*.12d fea/spooles.out
echo "[ok] done - results: fea/*.dat (numbers), fea/*_stress.png (renders)"
