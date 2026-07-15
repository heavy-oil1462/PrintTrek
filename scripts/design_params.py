#!/usr/bin/env python3
"""Single-source design toggles for the Python side of the pipeline.

cad/design_params.scad is the ONE place a design toggle lives. OpenSCAD
consumes it directly (main_assembly.scad does `include <design_params.scad>`);
the Python scripts import this module, which parses the same file — so
CAD, mass budget, and FEA can never drift apart.

Override precedence (highest first):
  1. environment variable, UPPERCASE of the toggle name
     (e.g. FLOOR_CROSSBARS=true python3 scripts/calculate_mass.py)
  2. the value in cad/design_params.scad

Zero dependencies (stdlib only). Usage:

    from design_params import PARAMS
    FLOOR_CROSSBARS = PARAMS["floor_crossbars"]
"""

import os
import re
from pathlib import Path

_SCAD = Path(__file__).resolve().parent.parent / "cad" / "design_params.scad"


def _parse(text):
    s = text.strip().lower()
    if s in ("true", "false"):
        return s == "true"
    try:
        return float(text) if "." in text else int(text)
    except ValueError:
        raise ValueError(
            f"design_params.scad: unsupported value {text!r} — "
            "keep the file to simple booleans/numbers")


def load():
    params = {}
    for m in re.finditer(r"(?m)^\s*(\w+)\s*=\s*([^;]+);", _SCAD.read_text()):
        params[m.group(1)] = _parse(m.group(2))
    for name in params:
        env = os.environ.get(name.upper())
        if env is not None:
            params[name] = _parse(env)
    return params


PARAMS = load()

if __name__ == "__main__":
    for k, v in PARAMS.items():
        print(f"{k} = {v}")
