#!/usr/bin/env python3
"""Os efeitos deste jogo, desenhados por este arquivo (nada aqui vem de outra versão):

  fx()        os efeitos das prévias do Arsenal (bola de fogo, pilar de fogo, pedra em chamas,
              flecha, asas, fumaça, brilhos...), nos mesmos tamanhos que as telas esperam
  map_fx()    os efeitos do mapa em pixel art (um pixel = um bloco do mapa): explosões mágicas,
              a bandeira da conquista, fogo e fumaça, na mesma grade de Assets/MapFx
  roads()     os seis blocos da estrada de pedra (no lugar dos trilhos)
  chest()     as luzes do baú (raios, brilho, anel, feixe...)

Cada função devolve { nome: imagem PIL RGBA }. Quem as coloca no jogo é tools/arte/make_own_art.py.
"""
import math
import random

import numpy as np
from PIL import Image, ImageDraw

SS = 4  # desenha-se 4x maior e reduz-se: bordas lisas

# cores
WHITE = (255, 255, 255)
CORE = (255, 250, 222)
YELLOW = (255, 214, 90)
ORANGE = (246, 140, 40)
RED = (214, 62, 36)
DARK_RED = (150, 44, 34)
SOOT = (70, 66, 72)
GREY1 = (104, 100, 106)
GREY2 = (140, 136, 140)
GREY3 = (176, 172, 176)
INK = (36, 40, 62)


# ---------------------------------------------------------------------------------------------
# ferramentas
# ---------------------------------------------------------------------------------------------
def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def down(im):
    """Reduz SS vezes (com o alfa pré-multiplicado, para a borda não escurecer)."""
    w, h = im.width // SS, im.height // SS
    return im.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")


def grid(w, h):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    return (xs + 0.5) / w * 2 - 1, (ys + 0.5) / h * 2 - 1


def mask(alpha):
    """Campo de alfa (0..1) -> imagem branca."""
    a = np.clip(alpha, 0, 1)
    im = np.zeros(a.shape + (4,), np.uint8)
    im[..., 0:3] = 255
    im[..., 3] = np.round(a * 255).astype(np.uint8)
    return Image.fromarray(im, "RGBA")


def tinted(alpha, rgb):
    """Campo de alfa e campo de cor (h, w, 3 em 0..255) -> imagem."""
    a = np.clip(alpha, 0, 1)
    im = np.zeros(a.shape + (4,), np.uint8)
    im[..., 0:3] = np.clip(rgb, 0, 255).astype(np.uint8)
    im[..., 3] = np.round(a * 255).astype(np.uint8)
    return Image.fromarray(im, "RGBA")


def disc(d, x, y, r, col, a=255):
    if r <= 0:
        return
    d.ellipse([(x - r) * SS, (y - r) * SS, (x + r) * SS, (y + r) * SS], fill=col + (a,))


def poly(d, pts, col, a=255):
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=col + (a,))


def line(d, pts, col, w, a=255):
    d.line([(x * SS, y * SS) for x, y in pts], fill=col + (a,), width=max(1, round(w * SS)), joint="curve")


def teardrop(cx, base, h, w, lean=0.0, n=40):
    """Uma língua de fogo: base arredondada em (cx, base), ponta `h` acima, largura máxima `w`."""
    left, right = [], []
    for i in range(n + 1):
        u = i / n
        half = w * math.sqrt(max(0.0, 4 * u * (1 - u))) * (1 - u) ** 0.55 * 1.55
        x = cx + lean * h * u * u
        y = base - h * u
        left.append((x - half, y))
        right.append((x + half, y))
    return left + right[::-1]


def rot_ellipse(cx, cy, a, b, ang, n=36):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + a * math.cos(t) * c - b * math.sin(t) * s, cy + a * math.cos(t) * s + b * math.sin(t) * c)
            for t in (2 * math.pi * i / n for i in range(n))]


def over(base, top):
    out = base.copy()
    out.alpha_composite(top)
    return out


# ---------------------------------------------------------------------------------------------
# os efeitos das prévias do Arsenal
# ---------------------------------------------------------------------------------------------
def fx_beam():
    """Raio arcano (256 x 64): miolo branco, halo violeta; igual de ponta a ponta (a tela o estica)."""
    x, y = grid(256, 64)
    core = np.exp(-((y / 0.15) ** 2))
    halo = np.exp(-((y / 0.46) ** 2))
    a = np.clip(core + 0.6 * halo, 0, 1) * np.clip((1 - np.abs(y)) / 0.2, 0, 1)
    rgb = np.empty(a.shape + (3,))
    for i, (v, w) in enumerate(zip((170, 112, 255), WHITE)):
        rgb[..., i] = v + (w - v) * core
    return tinted(a, rgb)


def fx_glow():
    x, y = grid(128, 128)
    r = np.sqrt(x * x + y * y)
    return mask(np.clip(1 - r, 0, 1) ** 2.1)


def fx_ring():
    x, y = grid(256, 256)
    r = np.sqrt(x * x + y * y)
    return mask(np.exp(-(((r - 0.85) / 0.045) ** 2)) + 0.45 * np.exp(-(((r - 0.85) / 0.11) ** 2)))


def fx_reticle():
    """A mira: um círculo de runa (anel, quatro pontas de lança e um losango no centro)."""
    im = canvas(128, 128)
    d = ImageDraw.Draw(im)
    c = 64
    d.ellipse([(c - 40) * SS, (c - 40) * SS, (c + 40) * SS, (c + 40) * SS], outline=WHITE + (255,), width=5 * SS)
    for k in range(4):
        ang = k * math.pi / 2
        ux, uy = math.cos(ang), math.sin(ang)
        vx, vy = -uy, ux
        poly(d, [(c + ux * 24, c + uy * 24), (c + ux * 42 + vx * 5, c + uy * 42 + vy * 5),
                 (c + ux * 60, c + uy * 60), (c + ux * 42 - vx * 5, c + uy * 42 - vy * 5)], WHITE)
    poly(d, [(c, c - 8), (c + 8, c), (c, c + 8), (c - 8, c)], WHITE)
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        disc(d, c + math.cos(ang) * 40, c + math.sin(ang) * 40, 4.5, WHITE)
    return down(im)


def fx_scorch():
    """A marca que o fogo deixa: mancha irregular com respingos (branca: a tela dá a cor)."""
    x, y = grid(128, 128)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    edge = 0.5 + 0.09 * np.sin(5 * th + 1.0) + 0.06 * np.sin(9 * th + 2.3) + 0.04 * np.sin(17 * th + 0.7)
    blot = np.clip((edge - r) / 0.1, 0, 1) * 0.9
    spikes = np.clip(np.cos(6.5 * th + 0.4), 0, 1) ** 30 * np.clip((0.96 - r) / 0.35, 0, 1) * (r > 0.3)
    return mask(np.maximum(blot, spikes * 0.8))


def fx_smoke():
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    puffs = [(22, 38, 15), (41, 37, 17), (31, 24, 15), (33, 45, 13)]
    for x, y, r in puffs:
        disc(d, x, y, r, (178, 178, 190), 235)
    for x, y, r in puffs:
        disc(d, x - 1.5, y - 2, r - 2.5, (214, 214, 222), 240)
    for x, y, r in puffs:
        disc(d, x - 4, y - 5, r * 0.45, (240, 240, 245), 240)
    return down(im)


def star4(n, power, core=0.0):
    x, y = grid(n, n)
    a = np.clip(1 - (np.abs(x) ** power + np.abs(y) ** power) ** (1 / power), 0, 1) ** 0.75
    if core > 0:
        r = np.sqrt(x * x + y * y)
        a = np.maximum(a, np.clip(1 - r / core, 0, 1) ** 1.5)
    return mask(a * 1.6)


def fx_spark():
    return star4(64, 0.55, 0.3)


def fx_tracer():
    """Flecha em chamas (96 x 24), ponta à direita."""
    w, h = 96, 24
    x, y = grid(w * SS, h * SS)
    tail = np.clip((x + 1) / 1.7, 0, 1) ** 1.8 * np.exp(-((y / 0.34) ** 2)) * 0.85 * (x < 0.75)
    rgb = np.empty(tail.shape + (3,))
    heat = np.clip((x + 0.2) / 0.9, 0, 1) * np.exp(-((y / 0.18) ** 2))
    for i, (c0, c1) in enumerate(zip((236, 96, 40), (255, 224, 130))):
        rgb[..., i] = c0 + (c1 - c0) * heat
    im = tinted(tail, rgb)
    d = ImageDraw.Draw(im)
    line(d, [(34, 12), (82, 12)], (92, 62, 38), 2.2)
    for dy in (-1, 1):
        poly(d, [(34, 12), (30, 12 + dy * 5), (38, 12 + dy * 5), (43, 12)], (196, 52, 52))
    poly(d, [(80, 7.5), (94.5, 12), (80, 16.5), (83, 12)], (226, 230, 238))
    return down(im)


def comet(d, hx, hy, r, tipx, col):
    poly(d, [(hx, hy - r), (tipx, hy), (hx, hy + r)], col)
    disc(d, hx, hy, r, col)


def fx_warhead():
    """Um raio de fogo (64 x 64), cabeça à direita."""
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    comet(d, 44, 32, 13, 3, RED)
    comet(d, 45, 32, 10, 14, ORANGE)
    comet(d, 46, 32, 7, 25, YELLOW)
    disc(d, 47, 32, 4.5, CORE)
    return down(im)


def fx_bomb():
    """A pedra em chamas da catapulta (64 x 64), a frente à direita."""
    im = canvas(64, 64)
    d = ImageDraw.Draw(im)
    for (cy, r, tip, col) in ((32, 15, 2, RED), (27, 9, 6, RED), (38, 9, 8, RED), (32, 11, 12, ORANGE), (32, 7, 22, YELLOW)):
        comet(d, 38, cy, r, tip, col)
    disc(d, 42, 32, 15, (44, 40, 44))
    disc(d, 42, 32, 12.5, (112, 104, 100))
    disc(d, 45, 28, 7.5, (150, 142, 136))
    disc(d, 47, 26, 3, (182, 174, 168))
    line(d, [(36, 30), (40, 34), (39, 39)], (64, 58, 60), 1.4)
    line(d, [(44, 36), (49, 38)], (64, 58, 60), 1.4)
    return down(im)


def fx_chute():
    """Asas (128 x 128): os reforços descem voando. O soldado fica embaixo, no centro."""
    im = canvas(128, 128)
    d = ImageDraw.Draw(im)
    root = (64, 100)
    feathers = []
    for s in (-1, 1):
        for i, (deg, length) in enumerate(((-10, 40), (5, 50), (20, 58), (35, 66), (49, 70), (62, 68))):
            ang = math.radians(deg)
            ux, uy = s * math.cos(ang), -math.sin(ang)
            cx, cy = root[0] + ux * length * 0.52, root[1] + uy * length * 0.52
            feathers.append((cx, cy, length * 0.5, 7.5 + i * 0.5, math.atan2(uy, ux), ux, uy, length))
    for cx, cy, a, b, ang, *_ in feathers:
        poly(d, rot_ellipse(cx, cy, a + 2.6, b + 2.6, ang), INK)
    disc(d, root[0], root[1] - 3, 13, INK)
    for cx, cy, a, b, ang, *_ in feathers:
        poly(d, rot_ellipse(cx, cy, a, b, ang), (246, 248, 253))
    for cx, cy, a, b, ang, ux, uy, length in feathers:
        poly(d, rot_ellipse(root[0] + ux * length * 0.3, root[1] + uy * length * 0.3, length * 0.26, b * 0.7, ang), (198, 214, 240))
    disc(d, root[0], root[1] - 3, 10.5, (198, 214, 240))
    return down(im)


def blobs(seed, n):
    rng = random.Random(seed)
    return [(2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / n, rng.uniform(0.25, 0.62), rng.uniform(0.3, 0.46)) for i in range(n)]


def fx_explosion():
    """A bola de fogo em 8 quadros de 128 (clarão, fogo, brasa, fumaça)."""
    out = Image.new("RGBA", (1024, 128), (0, 0, 0, 0))
    lay = blobs(7, 9) + [(0.0, 0.0, 0.5)]
    stages = [
        None,
        (ORANGE, YELLOW, CORE, 255, 30),
        (RED, ORANGE, YELLOW, 255, 36),
        (RED, ORANGE, YELLOW, 255, 44),
        (DARK_RED, (226, 104, 40), (248, 170, 72), 255, 50),
        ((120, 92, 88), (156, 120, 108), (214, 130, 70), 240, 54),
        (GREY1, GREY2, GREY3, 200, 56),
        (GREY2, GREY3, (200, 196, 200), 110, 58),
    ]
    for f, st in enumerate(stages):
        im = canvas(128, 128)
        d = ImageDraw.Draw(im)
        if st is None:
            arr = np.asarray(star4(72 * SS, 0.6, 0.0)).copy()
            arr[..., 0:3] = YELLOW
            arr[..., 3] = (arr[..., 3] * 0.9).astype(np.uint8)
            im.alpha_composite(Image.fromarray(arr, "RGBA"), (28 * SS, 28 * SS))
            d = ImageDraw.Draw(im)
            disc(d, 64, 64, 13, YELLOW)
            disc(d, 64, 64, 8.5, CORE)
        else:
            outer, mid, inner, alpha, R = st
            spread = 1.0 if f < 7 else 1.25
            for ang, dist, size in lay:
                disc(d, 64 + math.cos(ang) * dist * R * spread, 64 + math.sin(ang) * dist * R * spread, size * R, outer, alpha)
            for ang, dist, size in lay:
                disc(d, 64 + math.cos(ang) * dist * R * spread - 1.5, 64 + math.sin(ang) * dist * R * spread - 2, size * R * 0.7, mid, alpha)
            k = 0.42 if f < 5 else 0.3
            for ang, dist, size in lay:
                disc(d, 64 + math.cos(ang) * dist * R * spread * 0.8 - 3, 64 + math.sin(ang) * dist * R * spread * 0.8 - 4, size * R * k, inner, alpha)
            if f in (1, 2, 3):
                disc(d, 64, 64, R * 0.2, CORE)
        out.paste(down(im), (f * 128, 0))
    return out


def fx_mushroom():
    """O pilar de fogo da Magia Suprema: 8 quadros de 256 em 4 x 2 (cresce, arde, vira fumaça)."""
    out = Image.new("RGBA", (1024, 512), (0, 0, 0, 0))
    H = [64, 108, 152, 192, 206, 210, 212, 212]
    Wd = [26, 36, 46, 54, 58, 60, 62, 62]
    rng = random.Random(11)
    col = [(rng.uniform(-0.5, 0.5), rng.uniform(0.6, 1.0)) for _ in range(14)]
    for f in range(8):
        im = canvas(256, 256)
        d = ImageDraw.Draw(im)
        cx, base, h, w = 128, 232, H[f], Wd[f]
        # o círculo de runa no chão
        ra = 255 if f < 5 else (200, 130, 70)[f - 5]
        rx = w * 1.55
        d.ellipse([(cx - rx) * SS, (base - 11) * SS, (cx + rx) * SS, (base + 11) * SS], outline=(255, 196, 110, ra), width=3 * SS)
        d.ellipse([(cx - rx * 0.72) * SS, (base - 7) * SS, (cx + rx * 0.72) * SS, (base + 7) * SS], outline=(255, 226, 160, ra), width=2 * SS)
        if f < 6:
            fire = [(RED, 1.0, 1.0), (ORANGE, 0.8, 0.72), (YELLOW, 0.58, 0.46), (CORE, 0.34, 0.24)]
            if f == 4:
                fire = [(DARK_RED, 1.0, 1.0), (RED, 0.8, 0.72), (ORANGE, 0.58, 0.46), (YELLOW, 0.3, 0.22)]
            if f == 5:
                fire = [(DARK_RED, 0.62, 0.8), (RED, 0.46, 0.56), (ORANGE, 0.3, 0.32)]
            for c, kh, kw in fire:
                poly(d, teardrop(cx - w * 0.62, base, h * 0.6 * kh, w * 0.5 * kw, -0.12), c)
                poly(d, teardrop(cx + w * 0.66, base, h * 0.68 * kh, w * 0.52 * kw, 0.1), c)
                poly(d, teardrop(cx, base, h * kh, w * kw, 0.03), c)
        if f >= 4:
            # a fumaça toma o pilar de cima para baixo
            lo = (0.55, 0.3, 0.12, 0.05)[f - 4]
            shade = ((112, 96, 96), GREY1, GREY2, GREY3)[f - 4]
            light = ((150, 128, 122), GREY2, GREY3, (204, 200, 204))[f - 4]
            alpha = (250, 240, 215, 150)[f - 4]
            n = len(col)
            for layer in (0, 1):
                for i, (dx, sz) in enumerate(col):
                    u = lo + (1 - lo) * (i + 0.5) / n
                    wid = w * (0.55 + 0.75 * math.sin(math.pi * min(1.0, u * 0.9 + 0.1)) ** 0.8)
                    x = cx + dx * wid * 0.8
                    y = base - h * u
                    r = wid * 0.42 * sz
                    if layer == 0:
                        disc(d, x, y, r, shade, alpha)
                    else:
                        disc(d, x - r * 0.18, y - r * 0.22, r * 0.68, light, alpha)
        out.paste(down(im), ((f % 4) * 256, (f // 4) * 256))
    return out


def fx():
    return {
        "beam": fx_beam(), "bomb": fx_bomb(), "chute": fx_chute(), "explosion": fx_explosion(),
        "glow": fx_glow(), "mushroom": fx_mushroom(), "reticle": fx_reticle(), "ring": fx_ring(),
        "scorch": fx_scorch(), "smoke": fx_smoke(), "spark": fx_spark(), "tracer": fx_tracer(),
        "warhead": fx_warhead(),
    }


FX_MASKS = {"glow", "reticle", "ring", "scorch", "spark"}

# ---------------------------------------------------------------------------------------------
# os efeitos do mapa, em pixel art (a grade de Assets/MapFx)
# ---------------------------------------------------------------------------------------------
MAP_FX_SIZE = (720, 218)
MAP_FX_ROWS = {
    "nuke": (0, 60, 60, 12), "flag": (60, 24, 24, 10), "banner": (84, 24, 24, 10), "sam": (108, 48, 38, 9),
    "building": (146, 17, 15, 10), "fire": (161, 7, 13, 6), "smoke": (174, 11, 12, 4),
    "big_smoke": (186, 24, 16, 5), "smoke_fire": (202, 24, 16, 5),
}


class Px:
    def __init__(self, w, h):
        self.a = np.zeros((h, w, 4), np.uint8)
        self.w, self.h = w, h

    def put(self, x, y, col, alpha=255):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = (col[0], col[1], col[2], alpha)

    def disc(self, cx, cy, r, col, alpha=255):
        for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
            for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + 0.3:
                    self.put(x, y, col, alpha)

    def image(self):
        return Image.fromarray(self.a, "RGBA")


def burst(p, cx, cy, R, stage, seed=3, sparks=True):
    """Um quadro de explosão mágica em pixel art."""
    rng = random.Random(seed)
    lay = [(2 * math.pi * (i + rng.uniform(-0.25, 0.25)) / 8, rng.uniform(0.35, 0.6), rng.uniform(0.38, 0.52)) for i in range(8)]
    lay.append((0.0, 0.0, 0.6))

    def cluster(k, col, alpha=255, dx=0.0, dy=0.0):
        for ang, dist, size in lay:
            p.disc(cx + math.cos(ang) * dist * R + dx, cy + math.sin(ang) * dist * R + dy, max(0.6, size * R * k), col, alpha)

    if stage == "flash":
        p.disc(cx, cy, R, YELLOW)
        p.disc(cx, cy, R * 0.65, CORE)
    elif stage in ("fire", "fire2"):
        hot = stage == "fire"
        cluster(1.0, RED if hot else DARK_RED)
        cluster(0.72, ORANGE if hot else RED)
        cluster(0.42, YELLOW if hot else ORANGE)
        p.disc(cx, cy, R * 0.28, CORE if hot else YELLOW)
        if sparks:
            for i in range(8):
                ang = 2 * math.pi * (i + 0.5) / 8
                for rr in (1.12, 1.22):
                    p.put(cx + math.cos(ang) * R * rr, cy + math.sin(ang) * R * rr, YELLOW)
    elif stage in ("ember", "ember2"):
        cluster(1.0, SOOT)
        cluster(0.66, GREY1, dx=-0.6, dy=-0.8)
        p.disc(cx, cy, R * (0.24 if stage == "ember" else 0.12), RED)
        p.disc(cx, cy, R * (0.13 if stage == "ember" else 0.05), ORANGE)
    elif stage == "smoke":
        cluster(1.0, GREY1)
        cluster(0.62, GREY2, dx=-0.6, dy=-0.8)
    else:  # puffs: 0 denso .. 2 ralo
        level = int(stage[-1])
        k = R / 23.0
        for ring, n in ((1.0, 11), (0.55, 6), (0.12, 1)):
            for i in range(n):
                ang = 2 * math.pi * (i + rng.uniform(-0.3, 0.3)) / n
                dist = ring * R * rng.uniform(0.85, 1.08) * (1.0 + 0.06 * level)
                rad = max(0.5, (3.0, 2.0, 1.1)[level] * k * rng.uniform(0.8, 1.15))
                p.disc(cx + math.cos(ang) * dist, cy + math.sin(ang) * dist, rad, (GREY2, GREY3, GREY3)[level], (240, 215, 170)[level])


def flame(p, cx, base, height, f, frames):
    prof_n = height
    for i in range(prof_n):
        u = i / max(1, prof_n - 1)  # 0 base .. 1 ponta
        half = (height * 0.27) * math.sqrt(max(0.0, 1 - u)) * (0.75 + 0.25 * math.sin(math.pi * min(1, u * 2)))
        sway = math.sin(2 * math.pi * f / frames + u * 3.0) * u * (height * 0.12)
        y = base - i
        for x in range(int(round(cx + sway - half)), int(round(cx + sway + half)) + 1):
            p.put(x, y, RED)
        for x in range(int(round(cx + sway - half + 1)), int(round(cx + sway + half - 1)) + 1):
            if u < 0.8:
                p.put(x, y, ORANGE)
        for x in range(int(round(cx + sway * 0.5 - half + 2)), int(round(cx + sway * 0.5 + half - 2)) + 1):
            if u < 0.5:
                p.put(x, y, YELLOW)


def plume(p, x0, y0, dx, dy, f, frames, n=6, r0=1.2, r1=3.6):
    order = sorted(range(n), key=lambda k: -((k / n + f / frames) % 1))
    for k in order:
        ph = (k / n + f / frames) % 1
        col = SOOT if ph < 0.25 else (GREY1 if ph < 0.55 else GREY2)
        r = r0 + (r1 - r0) * ph
        x, y = x0 + dx * ph + math.sin(k * 2.1) * 1.0, y0 + dy * ph
        p.disc(x, y, r, col, int(255 * (1 - 0.55 * ph * ph)))
        if r > 2:
            p.disc(x - 0.8, y - 0.8, r * 0.5, GREY2 if ph < 0.55 else GREY3, int(255 * (1 - 0.55 * ph * ph)))


POLE = (126, 84, 50)
POLE_DARK = (62, 42, 30)
CLOTH_INK = (48, 42, 52)


def cloth_cells(f):
    """Os pixels do pano no quadro f: {(x, y): tom 0..2}. Flâmula de duas pontas, ondulando."""
    if f == 0:
        return {}
    drop = -4 if f == 1 else 0
    cells = {}
    for x in range(10, 21):
        wave = int(round(math.sin((x - 10) * 0.75 - f * 0.9) * 1.0 * min(1.0, (x - 10) / 4)))
        for y in range(5, 12):
            if x >= 19 and y == 8:
                continue  # o corte entre as duas pontas
            if x == 20 and y in (7, 9):
                continue
            yy = y + wave + drop
            if f == 1 and yy < 0:
                continue
            shade = 0 if wave < 0 else (1 if wave == 0 else 2)
            cells[(x, yy)] = shade
    return cells


def flag_frame(f, banner):
    p = Px(24, 24)
    cells = cloth_cells(f)
    if banner:
        tones = (WHITE, (232, 232, 238), (198, 198, 208))
        for (x, y), s in cells.items():
            p.put(x, y, tones[s])
        return p
    top, bottom = (0, 11) if f == 0 else ((0, 17) if f == 1 else (1, 22))
    for y in range(top, bottom + 1):
        p.put(6, y, POLE_DARK)
        p.put(9, y, POLE_DARK)
        p.put(7, y, POLE)
        p.put(8, y, (156, 108, 66))
    if f >= 2:
        for x in range(6, 10):
            p.put(x, 0, POLE_DARK)
        p.put(7, 1, YELLOW)
        p.put(8, 1, YELLOW)
        for x in range(4, 12):
            p.put(x, 23, POLE_DARK)
        for x in range(5, 11):
            p.put(x, 22, POLE if 6 < x < 9 else POLE_DARK)
        for x in range(5, 11):
            p.put(x, 21, POLE_DARK if x in (5, 10) else POLE)
    # o contorno do pano (o pano em si vem da linha `banner`, na cor do conquistador)
    for (x, y) in cells:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in cells and nx > 9:
                p.put(nx, ny, CLOTH_INK)
    if 3 <= f <= 6:
        for i in range(3):
            p.put(3 - i - (f - 3) % 2, 22 - (i % 2) - (f - 3) // 2, (206, 196, 176), 220 - (f - 3) * 40)
    return p


def map_fx():
    sheet = Image.new("RGBA", MAP_FX_SIZE, (0, 0, 0, 0))

    def put(row, f, p):
        y, w, _h, _n = MAP_FX_ROWS[row]
        sheet.paste(p.image(), (f * w, y))

    seq = [("flash", 7), ("fire", 12), ("fire", 18), ("fire", 22), ("fire2", 24), ("ember", 22), ("ember", 23),
           ("ember2", 24), ("smoke", 23), ("puffs0", 23), ("puffs1", 23), ("puffs2", 23)]
    for f, (st, r) in enumerate(seq):
        p = Px(60, 60)
        burst(p, 29.5, 29.5, r, st, seed=5 + (f if st.startswith("puffs") else 0))
        put("nuke", f, p)
    for f in range(10):
        put("flag", f, flag_frame(f, False))
        put("banner", f, flag_frame(f, True))
    seq = [("cross", 5), ("fire", 5), ("fire", 7), ("fire2", 9), ("ember", 10), ("ember2", 11), ("smoke", 11),
           ("puffs1", 12), ("puffs2", 13)]
    for f, (st, r) in enumerate(seq):
        p = Px(48, 38)
        cx, cy = 24, 15 + (f // 3)
        if st == "cross":
            for i in range(-8, 9):
                p.put(cx + i, cy, YELLOW if abs(i) > 3 else CORE)
                p.put(cx, cy + i, YELLOW if abs(i) > 3 else CORE)
            p.disc(cx, cy, 2, CORE)
        else:
            burst(p, cx, cy, r, st, seed=9 + f)
        put("sam", f, p)
    seq = [("flash", 2, 0), ("fire", 3, 0), ("fire", 4.5, 0), ("fire2", 5.5, 0), ("ember", 5.5, 0), ("ember2", 5, 1),
           ("smoke", 4.5, 2), ("smoke", 4, 3), ("puffs1", 4, 3), ("puffs2", 3, 5)]
    for f, (st, r, up) in enumerate(seq):
        p = Px(17, 15)
        burst(p, 8, 9 - up, r, st, seed=21 + f, sparks=False)
        put("building", f, p)
    for f in range(6):
        p = Px(7, 13)
        flame(p, 3, 12, 12 - (1 if f in (4, 5) else 0), f, 6)
        put("fire", f, p)
    for f in range(4):
        p = Px(11, 12)
        plume(p, 5, 10, 0.5, -7, f, 4, n=3, r0=1.0, r1=2.4)
        put("smoke", f, p)
    for f in range(5):
        p = Px(24, 16)
        plume(p, 7, 13, 10, -10, f, 5)
        put("big_smoke", f, p)
        p = Px(24, 16)
        plume(p, 8, 9, 11, -7, f, 5)
        flame(p, 6, 15, 8, f, 5)
        put("smoke_fire", f, p)
    return sheet


# ---------------------------------------------------------------------------------------------
# a estrada de pedra (no lugar dos trilhos): blocos de 24 px que se repetem, brancos
# ---------------------------------------------------------------------------------------------
def road_tile(up, down, left, right):
    """Um bloco da estrada: a faixa de pedra liga os lados dados; pedras soltas na beira de fora."""
    g = [[0] * 6 for _ in range(6)]
    for y in (2, 3):
        for x in (2, 3):
            g[y][x] = 1
    for on, cells in ((up, [(x, y) for x in (2, 3) for y in (0, 1)]), (down, [(x, y) for x in (2, 3) for y in (4, 5)]),
                      (left, [(x, y) for x in (0, 1) for y in (2, 3)]), (right, [(x, y) for x in (4, 5) for y in (2, 3)])):
        if on:
            for x, y in cells:
                g[y][x] = 1
    # a beira: no lado sem ligação, pedras alternadas
    if not up:
        for x in (0, 2, 4):
            g[0][x] = 1
    if not down:
        for x in (1, 3, 5):
            g[5][x] = 1
    if not left:
        for y in (1, 3, 5) if not down else (0, 2, 4):
            g[y][0] = 1
    if not right:
        for y in (0, 2, 4) if not up else (1, 3, 5):
            g[y][5] = 1
    a = np.zeros((24, 24), np.float64)
    for j in range(6):
        for i in range(6):
            if g[j][i]:
                a[j * 4 : j * 4 + 4, i * 4 : i * 4 + 4] = 1
    return mask(a)


def roads():
    # (nomes de Assets/RailArt: a curva "bl" tem o canto de fora embaixo à esquerda: liga cima e direita)
    return {
        "h": road_tile(False, False, True, True), "v": road_tile(True, True, False, False),
        "bl": road_tile(True, False, False, True), "br": road_tile(True, False, True, False),
        "tl": road_tile(False, True, False, True), "tr": road_tile(False, True, True, False),
    }


# ---------------------------------------------------------------------------------------------
# as luzes do baú (máscaras brancas)
# ---------------------------------------------------------------------------------------------
def chest():
    out = {}
    x, y = grid(512, 512)
    r = np.sqrt(x * x + y * y)
    th = np.arctan2(y, x)
    rays = np.clip(np.cos(7 * th), 0, 1) ** 3 * 0.9 + np.clip(np.cos(7 * th + math.pi), 0, 1) ** 8 * 0.5
    out["rays"] = mask(rays * np.clip(1 - r, 0, 1) ** 1.1 * np.clip(r / 0.08, 0, 1))
    x, y = grid(256, 256)
    r = np.sqrt(x * x + y * y)
    out["glow"] = mask(np.clip(1 - r, 0, 1) ** 1.8)
    out["ring"] = mask(np.exp(-(((r - 0.8) / 0.07) ** 2)) + 0.1 * np.clip(1 - r / 0.8, 0, 1) * (r < 0.8))
    out["sparkle"] = star4(64, 0.5, 0.22)
    x, y = grid(128, 512)
    v = (y + 1) / 2  # 0 em cima .. 1 embaixo (a luz sai do baú, embaixo)
    out["beam"] = mask(np.exp(-((x / (0.3 + 0.22 * (1 - v))) ** 2)) * v ** 1.5 * np.clip((1 - v) / 0.05, 0, 1) ** 0.5)
    x, y = grid(512, 64)
    out["flare"] = mask(np.exp(-((y / 0.2) ** 2)) * np.clip(1 - np.abs(x), 0, 1) ** 1.5)
    x, y = grid(32, 256)
    out["streak"] = mask(np.exp(-((x / 0.32) ** 2)) * np.clip(1 - np.abs(y), 0, 1) ** 1.3)
    return out


def contact_sheet(path):
    """Uma folha com tudo, para conferir a olho."""
    items = [("fx/" + k, v) for k, v in fx().items()] + [("map_fx", map_fx().resize((1440, 436), Image.NEAREST))]
    items += [("road/" + k, v.resize((96, 96), Image.NEAREST)) for k, v in roads().items()]
    items += [("chest/" + k, v.resize((max(24, v.width // 3), max(24, v.height // 3)))) for k, v in chest().items()]
    W = 1500
    sheet = Image.new("RGBA", (W, 2400), (70, 80, 95, 255))
    x = y = 6
    rowh = 0
    for _name, im in items:
        if im.width > W - 12:
            im = im.resize((W - 12, im.height * (W - 12) // im.width))
        if x + im.width > W - 6:
            x, y, rowh = 6, y + rowh + 8, 0
        sheet.alpha_composite(im, (x, y))
        x += im.width + 8
        rowh = max(rowh, im.height)
    sheet.crop((0, 0, W, y + rowh + 6)).convert("RGB").save(path)


if __name__ == "__main__":
    import sys

    contact_sheet(sys.argv[1] if len(sys.argv) > 1 else "efeitos.png")
