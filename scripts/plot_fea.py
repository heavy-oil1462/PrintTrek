#!/usr/bin/env python3
"""
Render CalculiX .frd results to PNG: deformed shape colored by von Mises
stress. Pure numpy + matplotlib — runs on any host:

    python3 scripts/plot_fea.py fea/drawbar_cantilever.frd
    python3 scripts/plot_fea.py fea/*.frd --deform-scale 20

Needs: pip install numpy matplotlib   (or your distro's packages)

Handles solid hex meshes (C3D8*) and the C3D20 bricks that ccx expands
beam elements into. Output lands next to the input: <name>_stress.png
"""

import argparse
import math
import sys


def _floats(line, start, width=12):
    out = []
    s = line.rstrip("\n")
    i = start
    while i + width <= len(s) + 1 and s[i:i + width].strip():
        out.append(float(s[i:i + width]))
        i += width
    return out


def parse_frd(path):
    nodes = {}          # id -> (x, y, z)
    elems = []          # list of corner-node id lists (hex8 corners)
    disp = {}           # id -> (ux, uy, uz)
    stress = {}         # id -> (sxx, syy, szz, sxy, syz, szx)

    with open(path) as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        ln = lines[i]
        code = ln[:5].strip()

        if code == "2" and "2C" in ln[:8]:            # nodal coordinates
            i += 1
            while i < len(lines) and lines[i].startswith(" -1"):
                nid = int(lines[i][3:13])
                nodes[nid] = tuple(_floats(lines[i], 13)[:3])
                i += 1
            continue

        if code == "3" and "3C" in ln[:8]:            # elements
            i += 1
            while i < len(lines) and lines[i][:3] in (" -1", " -2"):
                if lines[i].startswith(" -1"):
                    etype = int(lines[i][13:18])
                    conn = []
                    j = i + 1
                    while j < len(lines) and lines[j].startswith(" -2"):
                        s = lines[j].rstrip("\n")
                        k = 3
                        while k + 10 <= len(s) + 1 and s[k:k + 10].strip():
                            conn.append(int(s[k:k + 10]))
                            k += 10
                        j += 1
                    # hex8 (frd type 1) and hex20 (type 4): first 8 = corners
                    if etype in (1, 4) and len(conn) >= 8:
                        elems.append(conn[:8])
                    i = j
                else:
                    i += 1
            continue

        if ln.startswith(" -4"):                       # result block
            name = ln[5:13].strip().upper()
            i += 1
            while i < len(lines) and lines[i].startswith(" -5"):
                i += 1
            while i < len(lines) and lines[i].startswith(" -1"):
                nid = int(lines[i][3:13])
                vals = _floats(lines[i], 13)
                if name.startswith("DISP"):
                    disp[nid] = tuple(vals[:3])
                elif name.startswith("STRESS"):
                    stress[nid] = tuple(vals[:6])
                i += 1
            continue

        i += 1

    return nodes, elems, disp, stress


def von_mises(s):
    sxx, syy, szz, sxy, syz, szx = s
    return math.sqrt(0.5 * ((sxx - syy) ** 2 + (syy - szz) ** 2 +
                            (szz - sxx) ** 2) +
                     3.0 * (sxy ** 2 + syz ** 2 + szx ** 2))


HEX_FACES = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]


def outer_faces(elems):
    """Faces that appear exactly once = the visible surface."""
    seen = {}
    for conn in elems:
        for f in HEX_FACES:
            quad = tuple(conn[k] for k in f)
            key = tuple(sorted(quad))
            if key in seen:
                seen[key] = None
            else:
                seen[key] = quad
    return [q for q in seen.values() if q]


def plot(path, deform_scale=None, out=None):
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from mpl_toolkits.mplot3d.art3d import Poly3DCollection

    nodes, elems, disp, stress = parse_frd(path)
    if not nodes or not elems:
        sys.exit(f"{path}: no solid mesh found (only hex meshes are supported)")

    vm = {nid: von_mises(s) for nid, s in stress.items()}
    vmax = max(vm.values()) if vm else 0.0
    umax = max((math.sqrt(sum(c * c for c in d)) for d in disp.values()),
               default=0.0)

    xyz = {nid: np.array(p) for nid, p in nodes.items()}
    bbox = np.ptp(np.array(list(xyz.values())), axis=0)
    diag = float(np.linalg.norm(bbox))
    scale = deform_scale if deform_scale is not None else \
        (0.1 * diag / umax if umax > 1e-12 else 0.0)

    def pos(nid):
        p = xyz[nid]
        d = disp.get(nid)
        return p + scale * np.array(d) if d is not None else p

    faces = outer_faces(elems)
    polys = [[pos(n) for n in quad] for quad in faces]
    face_vm = [np.mean([vm.get(n, 0.0) for n in quad]) for quad in faces]

    fig = plt.figure(figsize=(12, 8))
    ax = fig.add_subplot(111, projection="3d")
    coll = Poly3DCollection(polys, edgecolor="k", linewidths=0.15)
    coll.set_array(np.array(face_vm))
    coll.set_cmap("turbo")
    coll.set_clim(0, vmax if vmax > 0 else 1)
    ax.add_collection3d(coll)

    pts = np.array([pos(n) for n in nodes])
    c = pts.mean(axis=0)
    r = max(float(np.ptp(pts, axis=0).max()) / 2, 1.0)
    ax.set_xlim(c[0] - r, c[0] + r)
    ax.set_ylim(c[1] - r, c[1] + r)
    ax.set_zlim(c[2] - r, c[2] + r)
    ax.set_box_aspect((1, 1, 1))
    ax.set_axis_off()

    cb = fig.colorbar(coll, ax=ax, shrink=0.6, pad=0.02)
    cb.set_label("von Mises stress [MPa]")
    stem = path.rsplit("/", 1)[-1].rsplit(".", 1)[0]
    ax.set_title(f"{stem}\nmax von Mises = {vmax:.0f} MPa   "
                 f"max |u| = {umax:.2f} mm   (deformation x{scale:.0f})")

    out = out or path.rsplit(".", 1)[0] + "_stress.png"
    fig.savefig(out, dpi=110, bbox_inches="tight")
    plt.close(fig)
    print(f"{path}: max vM {vmax:.1f} MPa, max |u| {umax:.3f} mm -> {out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("frd", nargs="+", help=".frd result files")
    ap.add_argument("--deform-scale", type=float, default=None,
                    help="deformation magnification (default: auto ~10%% of model size)")
    args = ap.parse_args()
    for p in args.frd:
        plot(p, args.deform_scale)


if __name__ == "__main__":
    main()
