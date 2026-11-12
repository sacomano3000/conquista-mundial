#!/usr/bin/env python3
"""Uma prévia do baú 3D (src/shared/Assets/CrateModel.luau), para conferir o desenho fora do Roblox:
lê os blocos do arquivo e os desenha com a mesma câmera da tela (client/UI/ChestView), fechado e aberto.

  python3 tools/arte/bau.py        grava assets/previa-bau.png

É só uma conferência de formas e cores: o Roblox desenha com a própria luz e os próprios materiais.
"""
import math, os, re

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "src", "shared", "Assets", "CrateModel.luau")
FOV, EYE, AT, YAW = 28.0, np.array([0, 6.2, -18.0]), np.array([0, 2.3, 0.0]), math.radians(24)
LIGHT = np.array([0.45, -1.0, 0.55])
AMBIENT = 150 / 255.0


def read_model():
    s = open(SRC).read()
    consts = {k: [float(x) for x in v.split(",")] for k, v in re.findall(r"local (\w+) = \{ ([\d., ]+) \}", s)}
    hinge = [float(x) for x in re.search(r"hinge = \{ ([\d., -]+) \}", s).group(1).split(",")]
    parts = []
    for name, lid, size, at, color in re.findall(r'block\("(\w+)", (true|false), \{ ([\d., -]+) \}, \{ ([\d., -]+) \}, (\w+),', s):
        parts.append((name, lid == "true", [float(x) for x in size.split(",")], [float(x) for x in at.split(",")], consts[color]))
    return parts, hinge


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def render(lid_deg, side=420):
    parts, hinge = read_model()
    hinge = np.array(hinge)
    fwd = (AT - EYE) / np.linalg.norm(AT - EYE)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    th = math.tan(math.radians(FOV / 2))
    light = -LIGHT / np.linalg.norm(LIGHT)
    R = rot_y(YAW)
    L = rot_x(math.radians(lid_deg))
    faces = []
    for name, lid, size, at, color in parts:
        h = np.array(size) / 2
        for axis in range(3):
            for sign in (-1, 1):
                n = np.zeros(3); n[axis] = sign
                a1, a2 = (axis + 1) % 3, (axis + 2) % 3
                quad = []
                for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                    p = np.array(at, float)
                    p[axis] += sign * h[axis]; p[a1] += s1 * h[a1]; p[a2] += s2 * h[a2]
                    quad.append(p)
                if lid:
                    quad = [hinge + L @ (p - hinge) for p in quad]
                    n = L @ n
                quad = [R @ p for p in quad]
                n = R @ n
                centre = sum(quad) / 4
                if np.dot(n, EYE - centre) <= 0:
                    continue
                shade = min(1.0, AMBIENT + 0.6 * max(0.0, float(np.dot(n, light))))
                pts = []
                for p in quad:
                    d = p - EYE
                    z = np.dot(d, fwd)
                    pts.append((side / 2 + np.dot(d, right) / (z * th) * side / 2, side / 2 - np.dot(d, up) / (z * th) * side / 2))
                # (Roblox's camera looks down -Z with +X to its right: mirror to match the screen)
                pts = [(side - x, y) for x, y in pts]
                faces.append((pts, [float(np.dot(p - EYE, fwd)) for p in quad], tuple(int(c * shade) for c in color)))
    # cada face em dois triângulos, com a profundidade de cada ponto (o mais perto fica)
    img = np.zeros((side, side, 3), np.uint8)
    img[:] = (38, 32, 36)
    depth = np.full((side, side), np.inf)
    ys, xs = np.mgrid[0:side, 0:side].astype(np.float64) + 0.5
    for pts, zs, col in faces:
        for tri in ((0, 1, 2), (0, 2, 3)):
            (x0, y0), (x1, y1), (x2, y2) = (pts[i] for i in tri)
            z0, z1, z2 = (zs[i] for i in tri)
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-9:
                continue
            w0 = ((y1 - y2) * (xs - x2) + (x2 - x1) * (ys - y2)) / den
            w1 = ((y2 - y0) * (xs - x2) + (x0 - x2) * (ys - y2)) / den
            w2 = 1 - w0 - w1
            z = w0 * z0 + w1 * z1 + w2 * z2
            hit = (w0 >= 0) & (w1 >= 0) & (w2 >= 0) & (z < depth - 1e-4)
            depth[hit] = z[hit]
            img[hit] = col
    return Image.fromarray(img, "RGB")


if __name__ == "__main__":
    sheet = Image.new("RGB", (420 * 3, 420), (38, 32, 36))
    for i, deg in enumerate((0, 40, 140)):
        sheet.paste(render(deg), (i * 420, 0))
    out = os.path.join(ROOT, "assets", "previa-bau.png")
    sheet.save(out)
    print(out)
