#!/usr/bin/env bash
# Headless OpenSCAD renderer (no GUI, no X server needed).
#
# Toolchain resolution, first hit wins (nix is optional, not enforced):
#   1. $OPENSCAD           explicit binary path
#   2. openscad on PATH    must be a dev snapshot (2024+): the 2021.01
#                          release has no Manifold backend, so it cannot
#                          drive this pipeline
#   3. nix                 openscad-unstable + Mesa (software GL) from
#                          the pinned channel (scripts/nixpkgs_channel),
#                          rendered through EGL surfaceless
#
# Usage:
#   scripts/render_scad.sh <file.scad> [output.(png|stl|dxf)] [extra openscad args...]
#
# Examples:
#   scripts/render_scad.sh cad/frame.scad                       # -> cad/frame.png
#   scripts/render_scad.sh cad/frame.scad /tmp/top.png --camera=0,0,0,0,0,0,4000
#   scripts/render_scad.sh cad/corner_plate.scad corner.stl     # manifold check/export
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# single source for the pinned channel; run_ccx.sh, run_fea.sh and
# verify_design.sh read it too
CHANNEL="$(cat "$HERE/nixpkgs_channel")"

build() { nix-build -I "nixpkgs=$CHANNEL" '<nixpkgs>' -A "$1" --no-out-link 2>/dev/null | tail -1; }

year_of() { "$1" --version 2>&1 | sed -n 's/.*version \([0-9][0-9][0-9][0-9]\).*/\1/p' | head -1; }

ENV_ARGS=()
if [ -n "${OPENSCAD:-}" ]; then
  BIN="$OPENSCAD"
elif command -v openscad >/dev/null 2>&1; then
  BIN="$(command -v openscad)"
  YEAR="$(year_of "$BIN")"
  if [ -z "$YEAR" ] || [ "$YEAR" -lt 2024 ]; then
    if command -v nix-build >/dev/null 2>&1; then
      BIN=""    # too old, fall through to nix
    else
      echo "openscad on PATH is too old ($("$BIN" --version 2>&1 | head -1))." >&2
      echo "Need a 2024+ dev snapshot (Manifold backend):" >&2
      echo "set \$OPENSCAD to a nightly AppImage or install nix." >&2
      exit 1
    fi
  fi
else
  BIN=""
fi

if [ -n "$BIN" ]; then
  # system/explicit binary: force software EGL only when there is no
  # display to fall back on, and never touch LD_LIBRARY_PATH
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    ENV_ARGS=(EGL_PLATFORM=surfaceless LIBGL_ALWAYS_SOFTWARE=1)
  fi
else
  if ! command -v nix-build >/dev/null 2>&1; then
    echo "no usable openscad: set \$OPENSCAD, put a 2024+ snapshot on PATH," >&2
    echo "or install nix for the pinned toolchain." >&2
    exit 1
  fi
  BIN="$(build openscad-unstable)/bin/openscad"
  MESA="$(build mesa)"
  GLVND="$(build libglvnd)"
  # LD_LIBRARY_PATH pollution breaks nix binaries: override it with only
  # the GL libs the nix loader should see
  ENV_ARGS=(
    LD_LIBRARY_PATH="$GLVND/lib:$MESA/lib"
    __EGL_VENDOR_LIBRARY_FILENAMES="$MESA/share/glvnd/egl_vendor.d/50_mesa.json"
    EGL_PLATFORM=surfaceless
    LIBGL_ALWAYS_SOFTWARE=1
  )
fi

IN="$1"
OUT="${2:-${1%.scad}.png}"
shift; [ $# -gt 0 ] && shift

EXTRA_ARGS=()
case "$OUT" in
  *.png) EXTRA_ARGS+=(--imgsize 1600,1200 --viewall --autocenter) ;;
esac

exec env "${ENV_ARGS[@]}" "$BIN" --backend Manifold "${EXTRA_ARGS[@]}" -o "$OUT" "$@" "$IN"
