#!/usr/bin/env python3
"""Builds this version's own world: an invented planet (continents, islands, mountain chains) and its
kingdoms, in the same format as make_maps.py's maps (src/shared/Data/Maps/World.luau and the registry
src/shared/Data/MapList.luau). Nothing is downloaded: the land comes from noise on a sphere, so the same
SEED always gives the same world. Needs numpy, scipy, Pillow, zstandard.

The grid is the World map's (2000 x 1000 tiles on the globe, the same projection as make_maps.py's World:
the top row is at 88.2 N). A tile is land where a height field passes a threshold: a few
continent cores (CORES: where, how wide, how strong), warped and roughened by noise, with smaller-scale
noise for islands and a cold land in the south. Heights: distance from the coast plus ridged noise for the
mountain chains, turned into the game's elevation classes by make_maps.magnitude.

Sea all around (2026-11-11). The game's map is flat: nothing wraps, and the view shows open sea past the
map's edge (client/Map/MapSurface.OUTSIDE). The first Eldoria was made like RoWorld's Earth, a globe cut
open: land ran off the left and right edges (507 of their 2000 tiles; RoWorld's Earth: 86) and a polar cap
filled the bottom edge, so zoomed out the land ended in straight lines against that sea. Now no land comes
within EDGE tiles of the left, right or bottom edge (the top never had any): the heights sink towards the
sides (EDGE_FADE), the cores that sat on the edge moved in (MOVED_IN), and the cap became a few cold
islands with sea beneath them (SOUTH). Every edge tile is open water at its darkest, the colour drawn
around the map. Away from the edges and the south the land is the first Eldoria's (`legacy=True` builds that
one: the sea level and the kingdoms are worked out on it).

Kingdoms: spread over the land as far from each other as they can be (farthest first), none on an island
too small to hold one; the cold ones get the cold names. A kingdom of the first Eldoria whose place is
still land keeps its place and its name; one whose land went gets a new place, the same name.

Usage (from the repo root): python3 tools/maps/make_fantasy_world.py [--preview <dir>] [--seed N]
"""
import argparse
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_maps as M  # noqa: E402

SEED = 7
W, H = 2000, 1000
NATIONS = 71
MIN_GAP = 30
LAND_SHARE = 0.33  # of the tiles (make_maps.py's World: 0.34)
MIN_HOME = 500  # a kingdom's island has at least this many tiles

WORLD_NAME = "Eldoria"
M.LICENSE = "Original"
M.ATTRIBUTION = ""
M.CREDITS = ""

# Continent cores: lon, lat, radius (degrees of arc), strength.
CORES = [
    # the north-west continent, long from north to south
    (-128, 50, 23, 1.00), (-110, 27, 21, 1.00), (-97, 8, 13, 0.90),
    # the south-west one
    (-66, -16, 23, 1.00), (-58, -41, 15, 0.90),
    # the middle one, and its western horn
    (-10, 40, 21, 1.00), (10, 22, 19, 0.95), (-27, 17, 11, 0.85),
    # the great eastern continent
    (42, 58, 14, 0.90), (62, 49, 24, 1.00), (96, 38, 27, 1.05), (121, 19, 17, 0.95),
    # the southern middle
    (28, -21, 21, 1.00), (46, -36, 13, 0.90),
    # the south-east
    (131, -29, 21, 1.00), (151, -15, 11, 0.85),
    # island realms
    (171, 26, 10, 0.75), (-160, -11, 10, 0.75), (-31, 66, 10, 0.75), (80, -55, 9, 0.70),
    (-171, 44, 8, 0.65), (0, -56, 8, 0.65), (100, -6, 7, 0.65), (-36, -6, 7, 0.65),
]
#: the cores that sat on the map's left / right edge, moved in (index in CORES -> lon, lat)
MOVED_IN = {16: (163, 26), 17: (-146, -11), 20: (170, 47)}
#: no land this close (tiles) to the left, right or bottom edge: the edge tiles are then open water at
#: its darkest (water magnitude = ceil(distance from the shore / 2) >= 10)
EDGE = 30
#: the heights sink from this far (tiles) from the left / right edge
EDGE_FADE = 120
#: the edge's line wobbles by up to this many tiles, so no coast follows it
EDGE_WOBBLE = 8
#: the cold islands of the south, where the cap was: x, y, half width, half height (tiles). Their noise
#: is read on the flat map, not on the globe: near a pole a row of tiles is a small circle of the globe,
#: and the globe's noise is stretched along it into straight streaks (the first Eldoria's cap was a bar).
SOUTH = [(235, 872, 175, 62), (640, 912, 115, 40), (985, 898, 165, 54), (1335, 926, 95, 30), (1760, 884, 175, 62)]
#: a cold island keeps this far (tiles) from every other land
SOUTH_GAP = 24
#: tiles in one unit of the globe's noise at the equator (the globe's radius in tiles)
RADIUS = W / (2 * math.pi)
#: the southern cap holds this many kingdoms (it is a wide strip of tiles but a small part of the globe)
CAP_NATIONS = 3
CAP_LAT = -66.0

NAMES = [
    "Valdoria", "Eldramar", "Aurelia", "Brumavale", "Castravia", "Dravena", "Elmoria", "Galdren",
    "Hesperia", "Ilvaren", "Jorvask", "Kaldora", "Lumeria", "Mirandel", "Novareia", "Pyrrhen",
    "Quendar", "Ravengard", "Solmere", "Tarsilia", "Umbraval", "Veltrana", "Wyrmoor", "Xandria",
    "Yselda", "Zarkhan", "Altavera", "Belmora", "Corvanth", "Dornhal", "Esmeria", "Fenmarch",
    "Grifonia", "Halvar", "Istrava", "Kormund", "Lothara", "Morwyn", "Nerath", "Orinth",
    "Pelagia", "Rhovana", "Sylvaria", "Thalmyr", "Ulmar", "Vespera", "Ardenmor", "Brannoch",
    "Cindral", "Dunmere", "Everon", "Faldir", "Glaeria", "Hartwyn", "Ironvale", "Kestrava",
    "Leovara", "Marovia", "Nimvara", "Carvalhal", "Pedralva", "Monteclaro", "Serravento", "Ouroverde",
    "Lancaster", "Pratavia", "Rubranor", "Torreal", "Vindara", "Zefira", "Montalvo", "Dracovia",
]
NAMES.remove("Lancaster")
COLD_NAMES = [
    "Frostgard", "Nevasca", "Glacinor", "Hibernal", "Borealia", "Geloforte", "Skarnheim", "Tundrava",
    "Alvorgelo", "Kryovar", "Norvind", "Brancavia", "Invernia", "Vintergard",
]


def hash3(ix, iy, iz, seed):
    n = (ix.astype(np.uint64) * np.uint64(374761393) + iy.astype(np.uint64) * np.uint64(668265263)
         + iz.astype(np.uint64) * np.uint64(2147483647) + np.uint64(seed * 144665 + 1013904223))
    n = (n ^ (n >> np.uint64(13))) * np.uint64(1274126177)
    n = n ^ (n >> np.uint64(16))
    return (n & np.uint64(0xFFFFFF)).astype(np.float32) / np.float32(0xFFFFFF)


def vnoise(p, seed):
    """Value noise in 0..1 at the points p (n, 3)."""
    q = p + 1000.0
    f = np.floor(q)
    t = (q - f).astype(np.float32)
    t = t * t * (3 - 2 * t)
    i = f.astype(np.int64)
    out = np.zeros(len(p), np.float32)
    for dx in (0, 1):
        wx = t[:, 0] if dx else 1 - t[:, 0]
        for dy in (0, 1):
            wy = t[:, 1] if dy else 1 - t[:, 1]
            for dz in (0, 1):
                wz = t[:, 2] if dz else 1 - t[:, 2]
                out += wx * wy * wz * hash3(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, seed, octaves, freq, gain=0.5):
    """Several octaves of vnoise, in about -1..1."""
    total = np.zeros(len(p), np.float32)
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        total += amp * (vnoise(p * freq, seed + o * 17) * 2 - 1)
        norm += amp
        amp *= gain
        freq *= 2.0
    return total / norm


def sphere(lon, lat):
    lo, la = np.radians(lon), np.radians(lat)
    return np.stack([np.cos(la) * np.cos(lo), np.cos(la) * np.sin(lo), np.sin(la)], -1)


def from_coast(mask):
    return ndimage.distance_transform_edt(np.pad(mask, ((0, 0), (W // 2, W // 2)), mode="wrap"))[:, W // 2:-(W // 2)]


def shape(seed, proj, legacy):
    """The world's tiles. legacy: the first Eldoria (land to the left, right and bottom edges).
    Returns (land mask, tile bytes, tile grid, distance from the coast, warped sphere points)."""
    xs, ys = np.meshgrid(np.arange(W) + 0.5, np.arange(H) + 0.5)
    lon, lat = proj.unproject(xs.ravel(), ys.ravel())
    p = sphere(lon, lat).astype(np.float32)

    # the points pushed around a little, so nothing follows a circle
    warp = np.stack([fbm(p, seed + 100 + k * 31, 5, 2.1, 0.55) for k in range(3)], -1)
    q = p + 0.36 * warp
    q /= np.linalg.norm(q, axis=1, keepdims=True)

    cont = np.full(len(p), -1.0, np.float32)
    for k, (clon, clat, radius, strength) in enumerate(CORES):
        if not legacy and k in MOVED_IN:
            clon, clat = MOVED_IN[k]
        c = sphere(clon, clat)
        d = np.degrees(np.arccos(np.clip(q @ c, -1, 1)))
        cont = np.maximum(cont, strength * (1 - d / radius))
    rough = fbm(q, seed + 200, 7, 3.6, 0.58)
    height = cont + 0.5 * rough
    # no land at the north pole's rows (a tile there is a sliver of the globe)
    height -= np.clip((lat - 74.0) / 8.0, 0, 1) * 1.5
    height[lat < -72.0] = -9
    # the first Eldoria's cap: its share of the tiles is left out of the land share
    cap_noise = fbm(p, seed + 300, 5, 4.0)
    cap = ((-lat - 79.0) / 8.0 + 0.45 * cap_noise) > 0
    isles = fbm(p, seed + 400, 5, 15.0, 0.55)
    far = fbm(p, seed + 500, 3, 2.4)
    out_at_sea = (far > 0.12) & (isles > 0.36) & (np.abs(lat) < 68)
    if legacy:
        level = np.quantile(height, 1 - (LAND_SHARE - cap.mean()) + 0.022)
        south = cap
    else:
        # (the sea level is the first Eldoria's, taken before its edge cores moved: the coasts away
        # from the edges stay where they were)
        level = LEVELS[seed]
        # the heights sink towards the left and right edges, along a line that wobbles
        wobble = EDGE_WOBBLE * fbm(p, seed + 900, 4, 9.0)
        from_side = np.minimum(xs.ravel(), W - xs.ravel()) + wobble
        fade = np.clip((EDGE_FADE - from_side) / (EDGE_FADE - EDGE), 0, 1)
        fade = fade * fade * (3 - 2 * fade)
        height = height - 1.6 * fade
        out_at_sea &= fade < 0.6
        # the cold islands of the south, with sea beneath them, drawn with the flat map's noise
        row = ys.ravel()
        flat = np.stack([xs.ravel() / RADIUS, row / RADIUS, np.full(len(row), 3.0)], -1).astype(np.float32)
        push_x = 40 * fbm(flat, seed + 320, 3, 2.2)
        push_y = 22 * fbm(flat, seed + 330, 3, 2.2)
        cold = np.full(len(row), -1.0, np.float32)
        for cx, cy, rx, ry in SOUTH:
            cold = np.maximum(cold, 1 - np.hypot((xs.ravel() + push_x - cx) / rx, (row + push_y - cy) / ry))
        cold = cold + 0.62 * fbm(flat, seed + 300, 6, 5.5, 0.6) - 1.6 * fade
        # (and islets off their coasts)
        south = (cold > 0.2) | ((cold > 0.04) & (fbm(flat, seed + 340, 5, 16.0, 0.55) > 0.24))
        south &= (H - row) + wobble > EDGE + EDGE_WOBBLE + 6
    land = height > level
    # islands: off the coasts, and archipelagos out in some parts of the ocean
    near_coast = (height > level - 0.2) & (isles > 0.2)
    if legacy:
        land = (land | near_coast | out_at_sea | south).reshape(H, W)
        south = south.reshape(H, W)
    else:
        land = ((land | near_coast | out_at_sea) & (from_side > EDGE + EDGE_WOBBLE)).reshape(H, W)
        # (a cold island stays clear of the other lands; its mountains and lakes come from the flat
        # map's noise too)
        south = south.reshape(H, W) & (ndimage.distance_transform_edt(~land) > SOUTH_GAP)
        south = ndimage.binary_opening(south, iterations=1)
        land |= south
        q = np.where(ndimage.binary_dilation(south, iterations=6).ravel()[:, None], flat, q)
    # inland seas: the deepest hollows well inside the land
    hollow = fbm(q, seed + 600, 4, 6.0).reshape(H, W)

    inside = from_coast(land)
    land &= ~((hollow < -0.5) & (inside > 9))
    M.tidy(land)

    # heights: the coast is low, the heart of a continent higher, mountain chains along ridged noise
    inside = from_coast(land)
    ridge = 1 - np.abs(fbm(q, seed + 700, 5, 3.0)).reshape(H, W)
    chains = np.clip((fbm(q, seed + 750, 2, 1.6).reshape(H, W) + 0.25) * 2.5, 0, 1)
    ridge = np.clip((ridge - 0.9) / 0.1, 0, 1) * chains
    hills = (fbm(q, seed + 800, 5, 7.0).reshape(H, W) + 1) / 2
    elev = np.clip(inside / 70.0, 0, 1) * 520 * (0.35 + hills) + ridge * 3600 * np.clip(inside / 6.0, 0, 1)
    elev += hills * 120
    mag = M.magnitude(elev)
    typed = np.where(land, M.LAND | mag, 0).astype(np.uint8)
    tiles = M.postprocess(typed.tobytes(), W, H)
    grid = np.frombuffer(tiles, np.uint8).reshape(H, W)
    return land, tiles, grid, inside, level, south


#: the first Eldoria's sea level for a seed (worked out by its own build, see build())
LEVELS = {}


def kingdoms_ok(land, inside, proj, south=None):
    """Where a kingdom may start: well inside land big enough for it (on a small island, at its
    heart), none on the rows next to a pole or on the southern land (it gets CAP_NATIONS of its own):
    `south`, or with none given everything south of CAP_LAT (the first Eldoria)."""
    lab, _ = ndimage.label(np.pad(land, ((0, 0), (0, W)), mode="wrap"), structure=M.FOUR)
    sizes = np.bincount(lab.ravel())
    big = (sizes[lab[:, :W]] >= MIN_HOME) | (sizes[lab[:, W:]] >= MIN_HOME)
    heart = ndimage.maximum_filter(inside, size=25, mode="wrap") * 0.75
    row = np.arange(H)[:, None]
    lat_row = proj.unproject(0, row + 0.5)[1]
    good = big & (inside >= np.minimum(14, heart)) & (inside >= 3) & (row > 30)
    return good & ((lat_row > CAP_LAT) if south is None else ~south)


def first_kingdoms(seed, proj, land, grid, inside):
    """The first Eldoria's kingdoms, in the order they were placed: [(name, x, y, on the cap)]."""
    ok = kingdoms_ok(land, inside, proj)
    cy, cx = np.nonzero(ok[::3, ::3])
    cy, cx = cy * 3, cx * 3
    rng = random.Random(seed)

    def dist2(x, y):
        dx = np.abs(cx - x)
        dx = np.minimum(dx, W - dx)
        return dx.astype(np.float64) ** 2 + (cy - y).astype(np.float64) ** 2

    spots = []
    cap_xs = []
    cap_row = H - 45
    for k in range(CAP_NATIONS):
        x = int((k + 0.5) * W / CAP_NATIONS + rng.randint(-60, 60)) % W
        at = M.nearest_inland(grid, x, cap_row)
        if at is not None:
            spots.append(at)
            cap_xs.append(x)
    caps = len(spots)
    best = np.full(len(cx), np.inf)
    for x, y in spots:
        best = np.minimum(best, dist2(x, y))
    while len(spots) < NATIONS:
        i = int(np.argmax(best))
        if best[i] < MIN_GAP ** 2:
            break
        spots.append((int(cx[i]), int(cy[i])))
        best = np.minimum(best, dist2(cx[i], cy[i]))
    lats = [float(proj.unproject(x, y)[1]) for x, y in spots]
    names, cold = NAMES[:], COLD_NAMES[:]
    rng.shuffle(names)
    rng.shuffle(cold)
    out = []
    for k, ((x, y), la) in enumerate(zip(spots, lats)):
        name = cold.pop() if (abs(la) > 56 and cold) else names.pop()
        out.append((name, int(x), int(y), k < caps))
    return out


def build(seed, preview):
    spec = dict(id="world", name=WORLD_NAME, module="World", world=True, width=W, height=H,
                lon0=M.WORLD_LON0, lat_top=M.WORLD_LAT_TOP, ppd=W / 360.0, lat_std=0.0,
                categories=["featured", "world"], frequency=30, modifiers=["isCrowded:50"],
                nations=NATIONS, min_gap=MIN_GAP)
    proj = M.Proj(spec)
    # the first Eldoria: its sea level and its kingdoms
    old_land, _, old_grid, old_inside, LEVELS[seed], _ = shape(seed, proj, True)
    first = first_kingdoms(seed, proj, old_land, old_grid, old_inside)
    land, tiles, grid, inside, _, south = shape(seed, proj, False)
    land_tiles = int(land.sum())

    # kingdoms: one of the first Eldoria's whose place is still good land stays; the others (the
    # cap's, on the southern land again, and those whose land went under the sea at the sides) are
    # placed again, each as far from every other kingdom as it can be
    ok = kingdoms_ok(land, inside, proj, south)
    cy, cx = np.nonzero(ok[::3, ::3])
    cy, cx = cy * 3, cx * 3

    def dist2(x, y):
        return (cx - x).astype(np.float64) ** 2 + (cy - y).astype(np.float64) ** 2

    placed = {}
    for k, (name, x, y, on_cap) in enumerate(first):
        if not on_cap and ok[y, x]:
            placed[k] = (x, y)
    kept = len(placed)
    # the cap's kingdoms: at the heart of the biggest cold islands, the westmost first
    caps = [k for k, f in enumerate(first) if f[3]]
    lab, n_isles = ndimage.label(south, structure=M.FOUR)
    isles = sorted(range(1, n_isles + 1), key=lambda i: -int((lab == i).sum()))[:len(caps)]
    hearts = []
    for i in isles:
        deep = np.where(lab == i, inside, 0)
        y, x = np.unravel_index(int(np.argmax(deep)), deep.shape)
        hearts.append((int(x), int(y)))
    for k, at in zip(caps, sorted(hearts)):
        placed[k] = at
    best = np.full(len(cx), np.inf)
    for x, y in placed.values():
        best = np.minimum(best, dist2(x, y))
    for k in range(len(first)):
        if k in placed:
            continue
        i = int(np.argmax(best))
        if best[i] < MIN_GAP ** 2:
            break
        placed[k] = (int(cx[i]), int(cy[i]))
        best = np.minimum(best, dist2(cx[i], cy[i]))
    nations = [dict(name=first[k][0], flag="", x=x, y=y) for k, (x, y) in placed.items()]
    moved = [first[k][0] for k in placed if placed[k] != (first[k][1], first[k][2])]
    nations.sort(key=lambda n: n["name"])
    gap = min(math.sqrt(min((min(abs(a["x"] - b["x"]), W - abs(a["x"] - b["x"])) ** 2 + (a["y"] - b["y"]) ** 2)
                            for b in nations if b is not a)) for a in nations)

    zbytes = M.write_module(spec, proj, tiles, land_tiles, nations)
    path = M.module_path(spec)
    s = open(path, encoding="utf-8").read()
    s = s.replace("-- GENERATED by tools/maps/make_maps.py from public-domain data (Natural Earth, NOAA ETOPO1). Do not edit.",
                  "-- GENERATED by tools/maps/make_fantasy_world.py (seed %d): an invented world. Do not edit." % seed)
    open(path, "w", encoding="utf-8").write(s)
    # (the registry keeps the other own maps' rows: tools/maps/own_maps.py)
    import own_maps  # noqa: E402,PLC0415

    own_maps.write_registry([(spec, proj, land_tiles, len(nations))])

    m = grid & 0x1F
    is_land = (grid & M.LAND) != 0
    lake = int((~is_land & ((grid & M.OCEAN) == 0)).sum())
    cls = [int((is_land & (m < 10)).sum()), int((is_land & (m >= 10) & (m < 20)).sum()), int((is_land & (m >= 20)).sum())]
    print("%s: %dx%d, %d land tiles (%.1f%%), plains/highland/mountain %s, %d lake tiles, %d kingdoms (closest two %.0f tiles apart), %d KB zstd"
          % (WORLD_NAME, W, H, land_tiles, 100.0 * land_tiles / (W * H), cls, lake, len(nations), gap, zbytes // 1024))
    print("the first Eldoria: %d land tiles; %d of its %d kingdoms kept their place; placed again: %s"
          % (int(old_land.sum()), kept, len(first), ", ".join(sorted(moved))))
    edge_land = int(is_land[:, 0].sum() + is_land[:, -1].sum() + is_land[0].sum() + is_land[-1].sum())
    edge_deep = int(((m[:, 0] >= 10) & ~is_land[:, 0]).sum() + ((m[:, -1] >= 10) & ~is_land[:, -1]).sum()
                    + ((m[0] >= 10) & ~is_land[0]).sum() + ((m[-1] >= 10) & ~is_land[-1]).sum())
    print("the cold islands: %d, %s tiles; the land's last row: %d (the map has %d)"
          % (n_isles, sorted((int((lab == i).sum()) for i in range(1, n_isles + 1)), reverse=True),
             int(np.nonzero(is_land.any(axis=1))[0][-1]), H))
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
        im.save(os.path.join(preview, "world.png"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    ap.add_argument("--seed", type=int, default=SEED)
    a = ap.parse_args()
    build(a.seed, a.preview)
