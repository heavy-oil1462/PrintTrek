#!/usr/bin/env bash
# Run CalculiX (ccx) headlessly on a single deck.
#
# Usage: scripts/run_ccx.sh fea/drawbar_cantilever
#        (path to the .inp WITHOUT the extension, as ccx expects)
#
# ccx is found via (in order): $CCX, ccx on PATH, nix-build from the
# pinned channel (scripts/nixpkgs_channel). Nix is the fallback, not a
# requirement: apt install calculix-ccx / brew install calculix works.
#
# Results land next to the deck: .dat (printed output), .frd (field results).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DECK="${1:?usage: run_ccx.sh <path/to/deck-without-.inp>}"

if [ -n "${CCX:-}" ]; then
    :
elif command -v ccx >/dev/null 2>&1; then
    CCX=$(command -v ccx)
elif command -v nix-build >/dev/null 2>&1; then
    CCX="$(nix-build -I "nixpkgs=$(cat "$HERE/nixpkgs_channel")" '<nixpkgs>' -A calculix --no-out-link)/bin/ccx"
else
    echo "ERROR: CalculiX 'ccx' not found." >&2
    echo "  Debian/Ubuntu:  sudo apt install calculix-ccx" >&2
    echo "  Or set CCX=/path/to/ccx" >&2
    exit 1
fi

# IMPORTANT: the sandbox sets LD_LIBRARY_PATH=/lib, which makes nix binaries
# load the system libc and segfault. Always unset it for nix store binaries.
RUN=(env)
case "$CCX" in /nix/store/*) RUN=(env -u LD_LIBRARY_PATH);; esac

cd "$(dirname "$DECK")"
exec "${RUN[@]}" "$CCX" "$(basename "$DECK")"
