#!/usr/bin/env python3
"""assets/previa-zoom-afastado.png: the map at the farthest zoom of a 1280 x 720 window, before and now.

Now: src/shared/Data/Maps/World.luau drawn with the game's terrain colours (Map/MapSurface.terrain_pixel)
at MapCamera's farthest zoom (the whole map with FIT_MARGIN = 0.9), on the sea colour the view shows past
the map (MapSurface.OUTSIDE). Before: assets/mundo/zoom-afastado-eldoria-1.png, the same view of the first
Eldoria, kept as a picture (its map is gone from the game).

    python3 tools/arte/previa_zoom.py
"""
import base64
import os
import re

import numpy as np
import zstandard
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
VIEW = (1280, 720)
FIT_MARGIN = 0.9
OCEAN = np.array([0x47, 0x85, 0xB5], np.float32)
SAND = (0xCC, 0xCB, 0x9E)
PLAINS = (0xBE, 0xDC, 0x8A)
HIGHLAND = (0xDC, 0xCB, 0x9E)
MOUNTAIN = (0xE6, 0xE6, 0xE6)
OUTSIDE = tuple(int(v) - 10 for v in OCEAN)


def world():
    src = open(os.path.join(ROOT, "src/shared/Data/Maps/World.luau")).read()
    w = int(re.search(r"width = (\d+)", src).group(1))
    h = int(re.search(r"height = (\d+)", src).group(1))
    data = "".join(re.findall(r'"([A-Za-z0-9+/=]{100,})"', src))
    raw = zstandard.ZstdDecompressor().decompress(base64.b64decode(data), max_output_size=w * h)
    return np.frombuffer(raw, np.uint8).reshape(h, w)


def colours(tb):
    """MapSurface.terrain_pixel, a whole map at once."""
    land, shore, mag = tb >= 128, (tb & 64) != 0, (tb & 31).astype(np.float32)
    out = np.zeros(tb.shape + (3,), np.float32)
    m = np.minimum(mag, 10)
    out[:] = OCEAN - m[..., None]
    out[~land & shore] = 0.7 * OCEAN + 76.5
    plains = land & (mag < 10)
    out[plains] = np.stack([np.full(plains.sum(), PLAINS[0]), PLAINS[1] - 2 * mag[plains], np.full(plains.sum(), PLAINS[2])], -1)
    high = land & (mag >= 10) & (mag < 20)
    out[high] = np.array(HIGHLAND, np.float32) + 2 * (mag[high] - 10)[:, None]
    mount = land & (mag >= 20)
    out[mount] = np.array(MOUNTAIN, np.float32) + np.floor(mag[mount] / 2)[:, None]
    out[land & shore] = SAND
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGB")


def view(tb):
    h, w = tb.shape
    scale = min(VIEW[0] / w, VIEW[1] / h) * FIT_MARGIN
    size = (round(w * scale), round(h * scale))
    im = Image.new("RGB", VIEW, OUTSIDE)
    im.paste(colours(tb).resize(size, Image.LANCZOS), ((VIEW[0] - size[0]) // 2, (VIEW[1] - size[1]) // 2))
    return im


def label(im, text):
    try:
        font = ImageFont.truetype(os.path.expanduser("~/.cache/fonts/Rubik.ttf"), 26)
        font.set_variation_by_axes([600])
    except OSError:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 24)
    d = ImageDraw.Draw(im)
    box = d.textbbox((0, 0), text, font=font)
    d.rectangle((16, 14, 16 + box[2] + 24, 14 + 43), fill=(0, 0, 0))
    d.text((28, 20), text, font=font, fill=(255, 255, 255))


def main():
    before = Image.open(os.path.join(ROOT, "assets/mundo/zoom-afastado-eldoria-1.png")).convert("RGB")
    d = ImageDraw.Draw(before)
    d.rectangle((0, 0, 700, 62), fill=OUTSIDE)
    label(before, "ANTES: a terra cortada na borda do mapa")
    now = view(world())
    label(now, "AGORA: mar em toda a volta, nenhuma terra cortada")
    gap = 16
    out = Image.new("RGB", (VIEW[0], VIEW[1] * 2 + gap), (14, 14, 20))
    out.paste(before, (0, 0))
    out.paste(now, (0, VIEW[1] + gap))
    path = os.path.join(ROOT, "assets/previa-zoom-afastado.png")
    out.save(path)
    print("%s: %d x %d" % (os.path.relpath(path, ROOT), out.width, out.height))


if __name__ == "__main__":
    main()
