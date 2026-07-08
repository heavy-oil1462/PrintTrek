#!/usr/bin/env bash
# Run CalculiX (ccx) headlessly via nix — no system install needed.
#
# Usage: scripts/run_ccx.sh fea/drawbar_cantilever
#        (path to the .inp WITHOUT the extension, as ccx expects)
#
# Results land next to the deck: .dat (printed output), .frd (field results).
set -euo pipefail

DECK="${1:?usage: run_ccx.sh <path/to/deck-without-.inp>}"

# Known-good store path (built 2026-07-08); falls back to nix-build.
CCX_STORE="/nix/store/6s7v4njrfr0jv79f5mxjggb58a7kjgxv-calculix-ccx-2.22"
if [ ! -x "$CCX_STORE/bin/ccx" ]; then
    CCX_STORE=$(nix-build -I nixpkgs=channel:nixos-25.05 '<nixpkgs>' -A calculix --no-out-link)
fi

# IMPORTANT: the sandbox sets LD_LIBRARY_PATH=/lib, which makes nix binaries
# load the system libc and segfault. Always unset it for nix store binaries.
cd "$(dirname "$DECK")"
exec env -u LD_LIBRARY_PATH "$CCX_STORE/bin/ccx" "$(basename "$DECK")"
