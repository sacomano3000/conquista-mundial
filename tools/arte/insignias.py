#!/usr/bin/env python3
"""As insígnias do Rank Semanal (src/shared/Data/RankPrizes): um escudo de ouro, prata ou bronze com
o lugar em algarismo romano (I, II, III) e uma coroa em cima. O jogo as mostra bem pequenas (16 px, ao
lado do nome), então o desenho é de formas cheias, sem detalhe fino.

Usado por make_own_art.py (as imagens ficam em Assets/OwnArtData e em assets/icones/badge_<n>.png).
Para ver sozinho:  python3 tools/arte/insignias.py   (grava assets/previa-insignias.png)
"""
import math, os

from PIL import Image, ImageDraw

SIZE = 96
K = 4  # desenha 4x maior e reduz
INK = (30, 24, 26, 255)
# (claro, base, escuro) de cada metal
METALS = {
    1: ((255, 226, 140), (236, 190, 92), (176, 126, 44)),
    2: ((240, 244, 250), (202, 208, 218), (132, 140, 156)),
    3: ((240, 180, 128), (208, 142, 92), (142, 88, 52)),
}


def shield(cx, top, w, h, n=18):
    pts = [(cx - w / 2, top), (cx + w / 2, top)]
    for i in range(n + 1):
        t = i / n
        pts.append((cx + (w / 2) * math.cos(t * math.pi / 2) ** 0.8, top + h * 0.40 + h * 0.60 * math.sin(t * math.pi / 2)))
    for i in range(n, -1, -1):
        t = i / n
        pts.append((cx - (w / 2) * math.cos(t * math.pi / 2) ** 0.8, top + h * 0.40 + h * 0.60 * math.sin(t * math.pi / 2)))
    return pts


def vgrad(size, top, bottom):
    im = Image.new("RGBA", (1, size))
    for y in range(size):
        t = y / (size - 1)
        im.putpixel((0, y), tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    return im.resize((size, size))


def badge(place):
    light, base, dark = METALS[place]
    s = SIZE * K
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    def poly(points, fill):
        layer = Image.new("L", (s, s), 0)
        ImageDraw.Draw(layer).polygon([(x * K, y * K) for x, y in points], fill=255)
        if isinstance(fill, Image.Image):
            im.paste(fill, (0, 0), layer)
        else:
            im.paste(Image.new("RGBA", (s, s), fill), (0, 0), layer)

    cx = SIZE / 2
    # a coroa: três pontas sobre uma faixa
    crown_top, crown_base = 5, 25
    cw = 46
    crown = [
        (cx - cw / 2, crown_base),
        (cx - cw / 2 - 3, crown_top + 4),
        (cx - cw / 4, crown_top + 12),
        (cx, crown_top),
        (cx + cw / 4, crown_top + 12),
        (cx + cw / 2 + 3, crown_top + 4),
        (cx + cw / 2, crown_base),
    ]
    grow = lambda pts, d: [(x + d * (1 if x > cx else -1 if x < cx else 0), y + (d if y >= crown_base else -d)) for x, y in pts]  # noqa: E731
    poly(grow(crown, 3.5), INK)
    poly(crown, light + (255,))
    # o escudo: contorno, aro escuro, face em degradê
    top, w, h = 24, 76, 68
    poly(shield(cx, top - 3.5, w + 7, h + 7), INK)
    poly(shield(cx, top, w, h), dark + (255,))
    poly(shield(cx, top + 5, w - 12, h - 11), vgrad(s, light, base))
    # o lugar em romano: barras com serifa
    bars = place
    bw, gap, bh = 8, 6, 30
    total = bars * bw + (bars - 1) * gap
    x0 = cx - total / 2
    y0 = top + 12
    serif = 3
    poly([(x0 - serif, y0), (x0 + total + serif, y0), (x0 + total + serif, y0 + 5), (x0 - serif, y0 + 5)], INK)
    poly([(x0 - serif, y0 + bh - 5), (x0 + total + serif, y0 + bh - 5), (x0 + total + serif, y0 + bh), (x0 - serif, y0 + bh)], INK)
    for i in range(bars):
        x = x0 + i * (bw + gap)
        poly([(x, y0), (x + bw, y0), (x + bw, y0 + bh), (x, y0 + bh)], INK)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def badges():
    return {n: badge(n) for n in (1, 2, 3)}


if __name__ == "__main__":
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    sheet = Image.new("RGBA", (3 * 200 + 40, 260), (38, 32, 36, 255))
    for i, (n, im) in enumerate(sorted(badges().items())):
        sheet.alpha_composite(im.resize((192, 192), Image.LANCZOS), (20 + i * 200, 10))
        for j, px in enumerate((32, 18, 16)):
            sheet.alpha_composite(im.resize((px, px), Image.LANCZOS), (40 + i * 200 + j * 44, 214))
    out = os.path.join(root, "assets", "previa-insignias.png")
    sheet.save(out)
    print(out)
