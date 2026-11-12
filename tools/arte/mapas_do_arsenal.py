#!/usr/bin/env python3
"""O chão das prévias do Arsenal: pedaços do mapa DESTE jogo (src/shared/Data/Maps/World.luau), desenhados
como uma partida os desenha (Map/MapSurface): as cores do terreno, um pixel por bloco, o território do
jogador à esquerda de uma fronteira e o de um reino à direita.

As cenas ficam numa folha só, na mesma grade que Assets/ArsenalMaps descreve (células de CELL_W x CELL_H
blocos com 2 px de margem), por isso esse módulo não muda. Cada cena escolhe sozinha a sua janela do
mapa: um lugar com bastante terra e com terra embaixo de tudo que a prévia desenha (`marks`). Se o mapa
mudar, as janelas mudam junto.

Quem usa: tools/arte/make_own_art.py (atlas()).
"""

import base64
import math
import os
import random
import re
import sys

import numpy as np
import zstandard
from PIL import Image, ImageDraw

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = os.path.join(REPO, "src", "shared", "Assets", "ArsenalMaps.luau")

CELL_W, CELL_H = 192, 88
GUTTER = 2

# the player's colour and the nations' (owner colours, before the blend)
PLAYER = (150, 92, 226)
RED = (220, 68, 60)
ORANGE = (238, 132, 44)
TEAL = (40, 170, 170)

# key: map module, window (x, y), mirrored, the border's split of the scene, the nation's colour, where its
# land ends (`far`, of the cell; past it nobody's land or a `third` nation's), and the points of the
# scene the demo draws on (only for the sheet's marks: land under them, not water)
SCENES = {
    "mega": dict(map="World", at=None, flip=False, split=0.40, enemy=RED, far=0.84,
                 marks=[(0.15, 0.7), (0.72, 0.74), (0.72, 0.2)]),
    "scatter": dict(map="World", at=None, flip=False, split=0.38, enemy=ORANGE, far=0.86,
                    third=TEAL,
                    marks=[(0.14, 0.7), (0.7, 0.62), (0.7, 0.2)]),
    "reinforce": dict(map="World", at=None, flip=False, split=0.44, enemy=RED, advance=22, frames=9,
                      marks=[(0.13, 0.8), (0.25, 0.8), (0.37, 0.8), (0.82, 0.66), (0.78, 0.2)]),
    "artillery": dict(map="World", at=None, flip=False, split=0.44, enemy=ORANGE, far=0.93, third=TEAL,
                      marks=[(0.3, 0.55), (0.86, 0.66), (0.6, 0.52), (0.7, 0.78), (0.74, 0.2)]),
    "airfield": dict(map="World", at=None, flip=False, split=0.40, enemy=RED, far=0.94,
                     marks=[(0.12, 0.72), (0.88, 0.7), (0.78, 0.2)]),
    "railgun": dict(map="World", at=None, flip=False, split=0.30, enemy=TEAL,
                    marks=[(0.11, 0.6), (0.66, 0.64), (0.62, 0.2)]),
    "reload2x": dict(map="World", at=None, flip=False, split=0.68, enemy=RED,
                     marks=[(0.3, 0.35), (0.3, 0.7), (0.86, 0.35), (0.86, 0.7)]),
    "stars2x": dict(map="World", at=None, flip=False, split=None, enemy=None, marks=[]),
}

# Map/MapSurface terrain colours
OCEAN = (0x47, 0x85, 0xB5)
SAND = (0xCC, 0xCB, 0x9E)
PLAINS = (0xBE, 0xDC, 0x8A)
HIGHLAND = (0xDC, 0xCB, 0x9E)
MOUNTAIN = (0xE6, 0xE6, 0xE6)
BACKGROUND = (0x3C, 0x3C, 0x3C)
ALPHA = 150 / 255
SATURATION = 0.85
BORDER_DARKEN = 0.125

_maps = {}


def load(mod):
    if mod in _maps:
        return _maps[mod]
    for d in ("src/shared/Data/Maps",):
        p = os.path.join(REPO, d, mod + ".luau")
        if os.path.exists(p):
            s = open(p).read()
            w = int(re.search(r"\bwidth = (\d+)", s).group(1))
            h = int(re.search(r"\bheight = (\d+)", s).group(1))
            raw = zstandard.ZstdDecompressor().decompress(base64.b64decode(re.search(r'terrain = "([^"]+)"', s).group(1)))
            _maps[mod] = np.frombuffer(raw, np.uint8).reshape(h, w)
            return _maps[mod]
    sys.exit("no map " + mod)


def terrain(tb):
    """MapSurface.terrain_pixel for every tile: (h, w, 3) floats."""
    tb = tb.astype(np.int32)
    land, shore, mag = tb >= 128, (tb & 64) != 0, tb & 31
    out = np.zeros(tb.shape + (3,))
    m = np.minimum(mag, 10)
    for c in range(3):
        v = OCEAN[c] - m
        v = np.where(~land & shore, 0.7 * OCEAN[c] + 76.5, v)
        v = np.where(land & (mag < 10), PLAINS[c] - (2 * mag if c == 1 else 0), v)
        v = np.where(land & (mag >= 10) & (mag < 20), HIGHLAND[c] + 2 * (mag - 10), v)
        v = np.where(land & (mag >= 20) & (mag < 31), MOUNTAIN[c] + mag // 2, v)
        v = np.where(land & shore & (mag < 31), SAND[c], v)
        v = np.where(land & (mag == 31), BACKGROUND[c], v)
        out[..., c] = v
    return np.clip(np.floor(out + 0.5), 0, 255)


def hsl_darken(rgb, amount):
    import colorsys
    r, g, b = (x / 255 for x in rgb)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, l - amount), s)
    return (r * 255, g * 255, b * 255)


def fill_of(rgb):
    r, g, b = (x / 255 for x in rgb)
    luma = r * 0.299 + g * 0.587 + b * 0.114
    return tuple((luma + (x - luma) * SATURATION) * 255 for x in (r, g, b))


def border_cols(key, base_x, rows):
    """The border's column for each row: base_x plus smooth noise (a few tiles), the same shape for every
    frame of the scene."""
    rnd = random.Random(key)
    waves = [(rnd.uniform(0.035, 0.06), rnd.uniform(0, 6.28), rnd.uniform(5.0, 7.0)),
             (rnd.uniform(0.1, 0.16), rnd.uniform(0, 6.28), rnd.uniform(2.0, 3.0)),
             (rnd.uniform(0.3, 0.45), rnd.uniform(0, 6.28), rnd.uniform(0.8, 1.2))]
    # (and a walk of single tiles, the ragged edge a front leaves)
    walk, out = 0.0, []
    for y in range(rows):
        walk = max(-2.0, min(2.0, walk + rnd.choice((-1, 0, 0, 1))))
        v = sum(a * math.sin(f * y + p) for f, p, a in waves) + walk
        out.append(int(round(base_x + v)))
    return out


def owners(key, sc, land, base_x):
    """Owner per tile of the window (with its 1-tile margin): 1 the player, 2 the nation, 0 nobody."""
    h, w = land.shape
    own = np.zeros((h, w), np.int8)
    if sc["split"] is None:
        own[land] = 1
        return own
    xs = np.arange(w)[None, :]
    mine = xs < np.array(border_cols(key, base_x, h))[:, None]
    own[land & mine] = 1
    own[land & ~mine] = 2
    if sc.get("far") is not None:
        # the nation's land ends at a second border, the land past it nobody's or a third nation's
        far = xs >= np.array(border_cols(key + "far", sc["far"] * CELL_W + 1, h))[:, None]
        own[land & far] = 3 if sc.get("third") is not None else 0
    return own


def compose(ter, own, colours):
    """Territory over the terrain (MapSurface.tile_pixel / composite): fills blended, borders opaque. The
    window has a 1-tile margin for the neighbours; returns the image without it."""
    h, w = own.shape
    img = ter.copy()
    pad = np.pad(own, 1, mode="edge")
    nbr = [pad[1:-1, :-2], pad[1:-1, 2:], pad[:-2, 1:-1], pad[2:, 1:-1]]
    for o, rgb in colours.items():
        mask = own == o
        border = mask & np.logical_or.reduce([n != o for n in nbr])
        fill = fill_of(rgb)
        bc = hsl_darken(rgb, BORDER_DARKEN)
        for c in range(3):
            img[..., c] = np.where(mask & ~border, ter[..., c] * (1 - ALPHA) + fill[c] * ALPHA, img[..., c])
            img[..., c] = np.where(border, bc[c], img[..., c])
    return np.clip(np.floor(img[1:-1, 1:-1] + 0.5), 0, 255).astype(np.uint8)


def window(sc):
    tb = load(sc["map"])
    x, y = sc["at"]
    win = tb[y - 1:y + CELL_H + 1, x - 1:x + CELL_W + 1]
    if win.shape != (CELL_H + 2, CELL_W + 2):
        sys.exit(f"{sc['map']} window {sc['at']} off the map")
    if sc["flip"]:
        win = win[:, ::-1]
    return win


def scene_images(key, sc):
    """The scene's frames (one unless it advances): (h, w, 3) uint8 each."""
    win = window(sc)
    ter = terrain(win)
    land = win >= 128
    colours = {1: PLAYER} if sc["split"] is None else {1: PLAYER, 2: sc["enemy"]}
    if sc.get("third") is not None:
        colours[3] = sc["third"]
    base = (sc["split"] or 0.5) * CELL_W + 1
    n = sc.get("frames", 1)
    out = []
    for k in range(n):
        bx = base + (sc.get("advance", 0) * k / max(1, n - 1))
        out.append(compose(ter, owners(key, sc, land, bx), colours))
    return out


def rect(sc, aspect):
    """The client's rect of a cell for a scene of this aspect (w / h): (x, y, w, h) in tiles."""
    if aspect <= CELL_W / CELL_H:
        rh, rw = CELL_H, CELL_H * aspect
    else:
        rw, rh = CELL_W, CELL_W / aspect
    split = sc["split"] if sc["split"] is not None else 0.5
    return split * (CELL_W - rw), (CELL_H - rh) / 2, rw, rh


SHAPES = (486 / 244, 269 / 276)  # a prévia no computador e no celular


def choose_windows():
    """Uma janela do mapa para cada cena: terra firme embaixo das marcas (nos dois formatos da prévia),
    bastante terra, um pouco de costa, e nenhuma janela repetida."""
    tb = load("World")
    land = tb >= 128
    h, w = land.shape
    # terra com 2 blocos de folga em volta
    solid = land.copy()
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            solid &= np.roll(np.roll(land, dy, 0), dx, 1)
    integ = np.pad(np.cumsum(np.cumsum(land.astype(np.int64), 0), 1), ((1, 0), (1, 0)))
    taken = []
    for key, sc in SCENES.items():
        pts = []
        for aspect in SHAPES:
            rx, ry, rw, rh = rect(sc, aspect)
            pts += [(int(rx + fx * rw), int(ry + fy * rh)) for fx, fy in sc["marks"]]
        want = 0.97 if sc["split"] is None else 0.86
        best = None
        for y in range(3, h - CELL_H - 3, 4):
            for x in range(3, w - CELL_W - 3, 4):
                if any(abs(x - tx) < CELL_W * 0.7 and abs(y - ty) < CELL_H * 0.7 for tx, ty in taken):
                    continue
                if not all(solid[y + py, x + px] for px, py in pts):
                    continue
                frac = (integ[y + CELL_H, x + CELL_W] - integ[y, x + CELL_W] - integ[y + CELL_H, x] + integ[y, x]) / (CELL_W * CELL_H)
                score = -abs(frac - want)
                if best is None or score > best[0]:
                    best = (score, x, y)
        if best is None:
            sys.exit("no window of the map fits the scene " + key)
        sc["at"] = (best[1], best[2])
        taken.append(sc["at"])
    return {k: sc["at"] for k, sc in SCENES.items()}


def manifest_frames():
    """As células de cada cena segundo Assets/ArsenalMaps (o jogo corta a folha por elas)."""
    s = open(MANIFEST).read()
    out = {}
    for key in SCENES:
        a = s.index("\t" + key + " = {")
        b = s.index("split", a)
        out[key] = [(int(x), int(y)) for x, y in re.findall(r"Vector2\.new\((\d+), (\d+)\)", s[a:b])]
    size = tuple(int(v) for v in re.search(r"size = Vector2\.new\((\d+), (\d+)\)", s).groups())
    return out, size


def atlas():
    """A folha (imagem PIL RGB), na grade de Assets/ArsenalMaps."""
    choose_windows()
    cells = []  # (key, frame, image)
    for key, sc in SCENES.items():
        for k, im in enumerate(scene_images(key, sc)):
            cells.append((key, k, im))
    cols = max(1, (1024 - 2 * GUTTER) // (CELL_W + 2 * GUTTER))
    rows = math.ceil(len(cells) / cols)
    sw, sh = CELL_W + 2 * GUTTER, CELL_H + 2 * GUTTER
    out = np.zeros((rows * sh, cols * sw, 3), np.uint8)
    placed = {}
    for i, (key, k, im) in enumerate(cells):
        cx, cy = (i % cols) * sw, (i // cols) * sh
        out[cy:cy + sh, cx:cx + sw] = np.pad(im, ((GUTTER, GUTTER), (GUTTER, GUTTER), (0, 0)), mode="edge")
        placed.setdefault(key, []).append((cx + GUTTER, cy + GUTTER))
    want, size = manifest_frames()
    if placed != want or (out.shape[1], out.shape[0]) != size:
        sys.exit("the atlas no longer matches Assets/ArsenalMaps (cells or size changed)")
    return Image.fromarray(out)


if __name__ == "__main__":
    im = atlas()
    im.save(sys.argv[1] if len(sys.argv) > 1 else "mapas_do_arsenal.png")
    print({k: sc["at"] for k, sc in SCENES.items()})
