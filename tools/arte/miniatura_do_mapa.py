#!/usr/bin/env python3
"""A miniatura do mapa (a figura dos cartões de mapa), desenhada a partir do próprio mapa do jogo
(src/shared/Data/Maps/<módulo>.luau), nas cores do terreno da partida, com no máximo 512 px.

  read_terrain(módulo) -> (largura, altura, blocos)
  render(blocos)       -> imagem PIL

Quem usa: tools/arte/make_own_art.py ("thumb/world").
"""
import base64
import os
import re
import sys

import numpy as np
import zstandard
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAPLIST = os.path.join(ROOT, "src", "shared", "Data", "MapList.luau")
DATA_DIRS = [os.path.join(ROOT, "src", "server", "MapData"), os.path.join(ROOT, "src", "shared", "Data", "Maps")]
OUT = os.path.join(ROOT, "build", "map_thumbs")
MANIFEST = os.path.join(ROOT, "src", "shared", "Assets", "MapThumbs.luau")

MAX_PX = 512
IMPASSABLE = 0x9F
CORNER = 0.035  # corner radius as a fraction of the long side
DEEP_RAMP = 0.6  # extra darkening per water-distance step past the game's 10 (open water up to -22.6)

# Map/MapSurface.luau terrain colours
OCEAN = (0x47, 0x85, 0xB5)
SAND = (0xCC, 0xCB, 0x9E)
PLAINS = (0xBE, 0xDC, 0x8A)
HIGHLAND = (0xDC, 0xCB, 0x9E)
MOUNTAIN = (0xE6, 0xE6, 0xE6)
BACKGROUND = (0x3C, 0x3C, 0x3C)


def terrain_rgb(tb):
    """RGB of terrain byte `tb`, as MapSurface.terrain_pixel draws it."""
    land, shore, mag = tb >= 128, (tb & 64) != 0, tb & 31
    if land and mag == 31:
        c = BACKGROUND
    elif land and shore:
        c = SAND
    elif land:
        if mag < 10:
            c = (PLAINS[0], PLAINS[1] - 2 * mag, PLAINS[2])
        elif mag < 20:
            m = mag - 10
            c = (HIGHLAND[0] + 2 * m, HIGHLAND[1] + 2 * m, HIGHLAND[2] + 2 * m)
        else:
            m = mag // 2
            c = (MOUNTAIN[0] + m, MOUNTAIN[1] + m, MOUNTAIN[2] + m)
    elif shore:
        c = tuple(0.7 * v + 76.5 for v in OCEAN)
    else:
        # the game's ramp to 10, then DEEP_RAMP more per step: the shelf reads at card size
        m = min(mag, 10) + DEEP_RAMP * max(0, mag - 10)
        c = (OCEAN[0] - m, OCEAN[1] - m, OCEAN[2] - m)
    return tuple(min(255, max(0, int(v + 0.5))) for v in c)


LUT = np.array([terrain_rgb(b) for b in range(256)], dtype=np.uint8)


def read_terrain(module):
    """(width, height, uint8 array [h, w]) of a map data module."""
    for d in DATA_DIRS:
        p = os.path.join(d, module + ".luau")
        if os.path.exists(p):
            break
    else:
        raise FileNotFoundError("no data module for " + module)
    src = open(p, encoding="utf-8").read()
    w = int(re.search(r"^\twidth = (\d+),", src, re.M).group(1))
    h = int(re.search(r"^\theight = (\d+),", src, re.M).group(1))
    b64 = re.search(r'^\tterrain = "([^"]*)",', src, re.M).group(1)
    raw = zstandard.ZstdDecompressor().decompress(base64.b64decode(b64), max_output_size=w * h)
    if len(raw) != w * h:
        raise ValueError("%s: %d tile bytes, expected %d x %d" % (module, len(raw), w, h))
    return w, h, np.frombuffer(raw, dtype=np.uint8).reshape(h, w)


def _to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _to_srgb(c):
    c = np.clip(c, 0.0, 1.0)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055) * 255.0


def render(tiles):
    """RGBA thumbnail of a terrain grid: palette at full resolution, area-averaged in linear light
    to fit MAX_PX (impassable tiles transparent), rounded corners."""
    h, w = tiles.shape
    s = min(MAX_PX / w, MAX_PX / h)
    tw, th = max(1, round(w * s)), max(1, round(h * s))

    def shrink(a):
        return np.asarray(Image.fromarray(a, mode="F").resize((tw, th), Image.Resampling.BOX))

    cover = (tiles != IMPASSABLE).astype(np.float32)
    lin = _to_linear(LUT[tiles].astype(np.float32)) * cover[:, :, None]
    alpha = shrink(cover)
    rgb = np.stack([shrink(np.ascontiguousarray(lin[:, :, k])) for k in range(3)], axis=2)
    rgb = _to_srgb(rgb / np.maximum(alpha, 1e-6)[:, :, None])
    # rounded corners, antialiased (drawn 4x and averaged down)
    r = min(CORNER * max(tw, th), min(tw, th) * 0.3)
    corner = np.ones((th, tw), dtype=np.float32)
    if r >= 1:
        k = 4
        mask = Image.new("L", (tw * k, th * k), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, tw * k - 1, th * k - 1), radius=r * k, fill=255)
        corner = np.asarray(mask.resize((tw, th), Image.Resampling.BOX), dtype=np.float32) / 255.0
    a = np.clip(alpha, 0.0, 1.0) * corner * 255.0
    rgba = np.concatenate([np.round(rgb), np.round(a)[:, :, None]], axis=2)
    rgba[rgba[:, :, 3] == 0, :3] = 0
    return Image.fromarray(rgba.astype(np.uint8), "RGBA")
