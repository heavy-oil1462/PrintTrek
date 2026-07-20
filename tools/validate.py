#!/usr/bin/env python3
"""PrintTrek control-system validation gate.

This is the SOFTWARE half of the repo's verification: the design half
(CAD/FEA/mass) lives in scripts/verify_design.sh, which invokes this script
as its final step. Run either directly:

    python3 tools/validate.py                 # everything
    python3 tools/validate.py yaml esphome    # a subset
    python3 tools/validate.py --list          # show available checks

Checks (framework and generic checks: esphome_skills):
    yaml       yamllint over the whole repo (.yamllint.yaml rules)
    esphome    `esphome config` on the example and sim compositions
               (auto-provisions esphome/secrets.yaml)
    compose    Docker Compose file parses (`docker compose config -q`)
    mosquitto  mosquitto.conf enforces auth + persistence
    ha         Home Assistant package/blueprint/dashboard YAML parses, and
               the compose file mounts every repo HA directory it references
    sim        project injection keys match sim-sensors.yaml topics; the sim
               container staging sources exist
    python     tools/*.py byte-compile

Intended entry points: the verify skill, CI, and pre-commit. Run inside the
devshell (`nix develop`) so all binaries are present.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from project import PROJECT  # noqa: E402

from esphome_skills import checks, validate  # noqa: E402

# The dev stack must mount the repo dirs the docs promise it does.
HA_MOUNTS = ("../homeassistant/packages",
             "../homeassistant/blueprints/automation/printtrek",
             "./homeassistant/configuration.yaml")

CHECKS = {
    "yaml": checks.check_yaml,
    "esphome": checks.check_esphome,
    "compose": checks.check_compose,
    "mosquitto": checks.check_mosquitto,
    "ha": lambda p: checks.check_ha(p, mounts=HA_MOUNTS),
    "sim": checks.check_sim,
    "python": checks.check_python,
}

if __name__ == "__main__":
    sys.exit(validate.main(PROJECT, CHECKS))
