#!/usr/bin/env python3
"""Builds Valtara, this game's small map (2026-11-12: "one more map, only smaller"): a ring of land
around an inner sea, with islands off its coasts. 1000 x 500 tiles (a quarter of Eldoria's), about a third of
its land, for quicker matches with fewer players.

Same format as the other maps (make_maps.write_module): the terrain goes to src/server/MapData/Valtara.luau
(server only; a client downloads it when a match on it starts, Net/MapFetch) and its row to the registry
src/shared/Data/MapList.luau (own_maps.py). Nothing is downloaded: the land comes from noise, so the same
SEED always gives the same map. Needs numpy, scipy, Pillow, zstandard.

The land: a wide oval (OVAL), hollowed in the middle by the inner sea (SEA), which two straits (STRAITS)
join to the ocean, cutting the ring into a western and an eastern land; all of it pushed around and roughened by noise. No land comes within EDGE tiles of
the map's edge: the view shows open sea past it (client/Map/MapSurface.OUTSIDE), so a coast cut by the
edge would end in a straight line.

Usage (from the repo root): python3 tools/maps/make_small_map.py [--preview <dir>] [--seed N]
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_maps as M  # noqa: E402
import make_fantasy_world as F  # noqa: E402  (its noise)
import own_maps  # noqa: E402

SEED = 21
W, H = 1000, 500
NATIONS = 24
MIN_GAP = 24
MIN_HOME = 400  # a kingdom's island has at least this many tiles
#: tiles in one unit of the noise
UNIT = 160.0
#: the land's oval: centre x, y, radius x, y (tiles)
OVAL = (500, 250, 420, 200)
#: the inner sea: centre x, y, radius x, y
SEA = (485, 255, 175, 74)
#: the straits from the inner sea to the ocean, which cut the ring in two lands: from, to (x, y), half-width
STRAITS = [((560, 285), (660, 470), 12), ((400, 225), (300, 30), 11)]
#: no land this close (tiles) to the map's edge; the line wobbles by EDGE_WOBBLE
EDGE = 26
EDGE_WOBBLE = 8

NAMES = [
    "Albamar", "Brisaforte", "Cardevale", "Dourado", "Espinhal", "Ferromonte", "Gralhavia", "Hortelar",
    "Ilhabela", "Juncal", "Lagoalta", "Marefria", "Nogueiral", "Olivença", "Portovelho", "Quintana",
    "Roseiral", "Salgueira", "Trigal", "Urzal", "Valverde", "Vilarinho", "Amendoal", "Bragança",
    "Cedrovia", "Durandal", "Faial", "Giesta", "Louredo", "Mirante", "Navalha", "Pinhalva",
]


def shape(seed):
    xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    x, y = xs.ravel(), ys.ravel()
    flat = np.stack([x / UNIT, y / UNIT, np.full(len(x), 5.0)], -1).astype(np.float32)
    # the points pushed around, so no coast follows an oval
    px = x + 46 * F.fbm(flat, seed + 10, 4, 1.9)
    py = y + 34 * F.fbm(flat, seed + 20, 4, 1.9)
    ox, oy, rx, ry = OVAL
    oval = 1 - np.hypot((px - ox) / rx, (py - oy) / ry)
    sx, sy, srx, sry = SEA
    sea = 1 - np.hypot((px - sx) / srx, (py - sy) / sry)
    rough = F.fbm(flat, seed + 30, 7, 3.4, 0.58)
    height = np.minimum(oval * 2.6, 0.75) - 2.4 * np.clip(sea, 0, 1) + 0.52 * rough
    # the strait: a band of sea along a line that wobbles
    for (ax, ay), (bx, by), half in STRAITS:
        t = np.clip(((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / ((bx - ax) ** 2 + (by - ay) ** 2), 0, 1)
        off = np.hypot(px - (ax + t * (bx - ax)), py - (ay + t * (by - ay)))
        height -= 1.6 * np.clip(1 - off / half, 0, 1)
    level = 0.2
    land = height > level
    # islands off the coasts, and a few in the inner sea
    isles = F.fbm(flat, seed + 40, 5, 13.0, 0.55)
    land |= (height > level - 0.34) & (isles > 0.2)
    wobble = EDGE_WOBBLE * F.fbm(flat, seed + 50, 4, 9.0)
    from_edge = np.minimum(np.minimum(x, W - x), np.minimum(y, H - y)) + wobble
    land &= from_edge > EDGE + EDGE_WOBBLE
    land = land.reshape(H, W)
    # lakes: the deepest hollows well inside the land
    hollow = F.fbm(flat, seed + 60, 4, 6.0).reshape(H, W)
    inside = ndimage.distance_transform_edt(land)
    land &= ~((hollow < -0.5) & (inside > 8))
    M.tidy(land)
    # heights: low at the coast, mountain chains along ridged noise (as Eldoria's)
    inside = ndimage.distance_transform_edt(land)
    ridge = 1 - np.abs(F.fbm(flat, seed + 70, 5, 3.0)).reshape(H, W)
    chains = np.clip((F.fbm(flat, seed + 75, 2, 1.6).reshape(H, W) + 0.3) * 2.5, 0, 1)
    ridge = np.clip((ridge - 0.9) / 0.1, 0, 1) * chains
    hills = (F.fbm(flat, seed + 80, 5, 7.0).reshape(H, W) + 1) / 2
    elev = np.clip(inside / 60.0, 0, 1) * 520 * (0.35 + hills) + ridge * 3600 * np.clip(inside / 6.0, 0, 1)
    elev += hills * 120
    mag = M.magnitude(elev)
    typed = np.where(land, M.LAND | mag, 0).astype(np.uint8)
    tiles = M.postprocess(typed.tobytes(), W, H)
    grid = np.frombuffer(tiles, np.uint8).reshape(H, W)
    return land, tiles, grid, inside


def kingdoms(land, inside):
    """Spread as far from each other as they can be (farthest first), each well inside land big enough
    for it; the first is the land's most inland place. Named in the order of their place, west to east."""
    lab, _ = ndimage.label(land, structure=M.FOUR)
    big = np.bincount(lab.ravel())[lab] >= MIN_HOME
    heart = ndimage.maximum_filter(inside, size=25) * 0.75
    ok = land & big & (inside >= np.minimum(12, heart)) & (inside >= 3)
    cy, cx = np.nonzero(ok[::3, ::3])
    cy, cx = cy * 3, cx * 3
    first = int(np.argmax(inside[cy, cx]))
    spots = [(int(cx[first]), int(cy[first]))]
    best = (cx - spots[0][0]).astype(np.float64) ** 2 + (cy - spots[0][1]).astype(np.float64) ** 2
    while len(spots) < NATIONS:
        i = int(np.argmax(best))
        if best[i] < MIN_GAP ** 2:
            break
        spots.append((int(cx[i]), int(cy[i])))
        best = np.minimum(best, (cx - cx[i]).astype(np.float64) ** 2 + (cy - cy[i]).astype(np.float64) ** 2)
    spots.sort()
    return [dict(name=NAMES[k], flag="", x=x, y=y) for k, (x, y) in enumerate(spots)]


def build(seed, preview):
    spec = dict(own_maps.SPECS["valtara"], width=W, height=H, lon0=0.0, lat_top=30.0, ppd=W / 120.0, lat_std=0.0,
                nations=NATIONS, min_gap=MIN_GAP)
    proj = M.Proj(spec)
    land, tiles, grid, inside = shape(seed)
    land_tiles = int(land.sum())
    nations = kingdoms(land, inside)
    gap = min(math.sqrt(min((a["x"] - b["x"]) ** 2 + (a["y"] - b["y"]) ** 2 for b in nations if b is not a)) for a in nations)
    zbytes = M.write_module(spec, proj, tiles, land_tiles, nations)
    path = M.module_path(spec)
    s = open(path, encoding="utf-8").read()
    s = s.replace("-- GENERATED by tools/maps/make_maps.py from public-domain data (Natural Earth, NOAA ETOPO1). Do not edit.",
                  "-- GENERATED by tools/maps/make_small_map.py (seed %d): an invented land. Do not edit." % seed)
    open(path, "w", encoding="utf-8").write(s)
    own_maps.write_registry([(spec, proj, land_tiles, len(nations))])

    m = grid & 0x1F
    is_land = (grid & M.LAND) != 0
    lake = int((~is_land & ((grid & M.OCEAN) == 0)).sum())
    cls = [int((is_land & (m < 10)).sum()), int((is_land & (m >= 10) & (m < 20)).sum()), int((is_land & (m >= 20)).sum())]
    lab, n_lands = ndimage.label(is_land, structure=M.FOUR)
    sizes = sorted(np.bincount(lab.ravel())[1:].tolist(), reverse=True)
    print("%s: %dx%d, %d land tiles (%.1f%%), plains/highland/mountain %s, %d lake tiles, %d kingdoms (closest two %.0f tiles apart), %d KB zstd"
          % (spec["name"], W, H, land_tiles, 100.0 * land_tiles / (W * H), cls, lake, len(nations), gap, zbytes // 1024))
    print("lands: %d, the largest %s" % (n_lands, sizes[:6]))
    edge_land = int(is_land[:, 0].sum() + is_land[:, -1].sum() + is_land[0].sum() + is_land[-1].sum())
    edge_deep = int(((m[:, 0] >= 10) & ~is_land[:, 0]).sum() + ((m[:, -1] >= 10) & ~is_land[:, -1]).sum()
                    + ((m[0] >= 10) & ~is_land[0]).sum() + ((m[-1] >= 10) & ~is_land[-1]).sum())
    print("the map's edge: %d land tiles, %d of its %d tiles open water at its darkest" % (edge_land, edge_deep, 2 * W + 2 * H))
    if preview:
        img = np.zeros((H, W, 3), np.uint8)
        water = ~is_land
        img[water] = np.stack([18 + 0 * m[water], 52 - m[water], 96 - m[water] * 2], -1)
        img[water & ((grid & M.OCEAN) == 0)] = (70, 140, 210)
        img[is_land & (m < 10)] = (96, 150, 78)
        img[is_land & (m >= 10) & (m < 20)] = (160, 150, 96)
        img[is_land & (m >= 20)] = (224, 224, 228)
        im = Image.fromarray(img)
        d = ImageDraw.Draw(im)
        for n in nations:
            d.rectangle([n["x"] - 3, n["y"] - 3, n["x"] + 3, n["y"] + 3], fill=(255, 60, 60))
            d.text((n["x"] + 5, n["y"] - 6), n["name"], fill=(255, 255, 255))
        os.makedirs(preview, exist_ok=True)
        im.save(os.path.join(preview, "valtara.png"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    ap.add_argument("--seed", type=int, default=SEED)
    a = ap.parse_args()
    build(a.seed, a.preview)
