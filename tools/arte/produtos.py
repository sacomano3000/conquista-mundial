#!/usr/bin/env python3
"""As imagens dos produtos de Robux (Painel do Criador > Monetização > Produtos de desenvolvedor).

Uma imagem de 512 x 512 por linha de src/shared/Data/MyProducts.luau, em assets/produtos/. O Roblox mostra
o ícone dentro de um círculo, então o desenho fica todo dentro dele. As figuras são as do próprio jogo:
as do Arsenal (assets/arsenal-icons) e os glifos (glifos.py).

Rodar da raiz do projeto:  python3 tools/arte/produtos.py     (precisa de Pillow e numpy)
"""
import os, sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import glifos  # noqa: E402

S = 512
OUT = os.path.join(ROOT, "assets", "produtos")

# linha de MyProducts -> (figura do Arsenal, cor de cima, cor de baixo): as cores de Data/Arsenal.luau
ARSENAL = {
    "unlock_mega": ("mega", 0xE2483A, 0x7A1420),
    "unlock_scatter": ("scatter", 0xF08A24, 0x8A3A0C),
    "unlock_reinforce": ("reinforce", 0x35B86B, 0x0E5A34),
    "unlock_artillery": ("artillery", 0x4C8DF0, 0x1A3A8A),
    "unlock_airfield": ("airfield", 0x2FB7C9, 0x0D5670),
    "unlock_railgun": ("railgun", 0xA35BFF, 0x3D1A8A),
    "unlock_stars2x": ("stars2x", 0xFFC83D, 0x9A6200),
    "unlock_reload2x": ("reload2x", 0xE85BB0, 0x7A1A5A),
}
# raridade -> (cor de Data/Cosmetics.luau, quantas estrelas)
RARITY = {
    "shop_common": (0x9AA6B2, 1),
    "shop_rare": (0x3D8BFF, 2),
    "shop_epic": (0xA35BFF, 3),
    "shop_legendary": (0xFFB22E, 4),
}


def rgb(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ground(top, bottom):
    """O fundo: as duas cores de cima para baixo, um brilho atrás da figura e a borda escurecida."""
    y, x = np.mgrid[0:S, 0:S].astype(np.float32)
    t = (y / (S - 1))[..., None]
    a, b = np.array(top, np.float32), np.array(bottom, np.float32)
    img = a + (b - a) * t
    d = np.sqrt((x - S / 2) ** 2 + (y - S / 2) ** 2) / (S / 2)
    glow = np.clip(1.0 - d / 0.8, 0, 1)[..., None] ** 2
    img = img + (255 - img) * glow * 0.22
    edge = np.clip((d - 0.78) / 0.6, 0, 1)[..., None]
    img = img * (1 - 0.45 * edge)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def shadowed(base, layer, dy=8, blur=10, alpha=0.45):
    """`layer` (RGBA, do tamanho da imagem) sobre `base`, com uma sombra macia embaixo."""
    a = layer.split()[3]
    sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, int(255 * alpha)), (0, dy), a)
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    return Image.alpha_composite(Image.alpha_composite(base, sh), layer)


def place(fig, box, cx=S // 2, cy=S // 2):
    """A figura encaixada num quadrado de `box` px, centrada em (cx, cy), numa camada do tamanho da imagem."""
    bb = fig.split()[3].getbbox()
    fig = fig.crop(bb)
    k = min(box / fig.width, box / fig.height)
    fig = fig.resize((max(1, round(fig.width * k)), max(1, round(fig.height * k))), Image.LANCZOS)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    layer.paste(fig, (cx - fig.width // 2, cy - fig.height // 2), fig)
    return layer


def glyph(fn, color=(255, 255, 255)):
    """Um glifo de glifos.py desenhado grande (a máscara vira tinta da cor dada)."""
    old = glifos.N
    glifos.N = 512
    try:
        m = fn()
    finally:
        glifos.N = old
    im = Image.new("RGBA", m.size, color + (0,))
    im.putalpha(m)
    return im


def arsenal(line):
    fig, top, bottom = ARSENAL[line]
    base = ground(rgb(top), rgb(bottom))
    art = Image.open(os.path.join(ROOT, "assets", "arsenal-icons", fig + ".png")).convert("RGBA")
    return shadowed(base, place(art, 320))


def crate():
    # o baú da Coleção, em ouro sobre o grafite e o vermelho do jogo
    base = ground((0xC8, 0x2A, 0x36), (0x3A, 0x0C, 0x14))
    img = shadowed(base, place(glyph(glifos.crate, (0xFF, 0xD2, 0x66)), 290, cy=S // 2 + 6))
    return img


def passe():
    # o passe do mês: a coroa em ouro com o alvo das Missões embaixo, sobre o verde-água do passe
    # (Cosmetics.SEASON). Um produto só para todos os meses, por isso nada de uma temporada.
    c = rgb(0x4FD6C4)
    base = ground(mix(c, (0, 0, 0), 0.25), mix(c, (0, 0, 0), 0.78))
    layer = place(glyph(glifos.crown, (0xFF, 0xD2, 0x66)), 236, cy=S // 2 - 62)
    layer = Image.alpha_composite(layer, place(glyph(glifos.target, (255, 255, 255)), 108, cy=S // 2 + 118))
    return shadowed(base, layer)


def shop(line):
    color, stars = RARITY[line]
    c = rgb(color)
    base = ground(mix(c, (255, 255, 255), 0.12), mix(c, (0, 0, 0), 0.62))
    star = glyph(glifos.star, (255, 255, 255))
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # as estrelas em uma ou duas fileiras, todas dentro do círculo
    rows = {1: [1], 2: [2], 3: [1, 2], 4: [2, 2]}[stars]
    size = {1: 250, 2: 150, 3: 140, 4: 140}[stars]
    gap = size + 14
    y0 = S // 2 - (len(rows) - 1) * gap // 2
    for r, n in enumerate(rows):
        for i in range(n):
            cx = S // 2 + int((i - (n - 1) / 2) * gap)
            layer = Image.alpha_composite(layer, place(star, size, cx, y0 + r * gap))
    return shadowed(base, layer)


def main():
    os.makedirs(OUT, exist_ok=True)
    made = {}
    for line in ARSENAL:
        made[line] = arsenal(line)
    made["crate"] = crate()
    for line in RARITY:
        made[line] = shop(line)
    made["pass"] = passe()
    for line, im in made.items():
        im.convert("RGB").save(os.path.join(OUT, line + ".png"))
        print(f"  {line}.png")
    # folha de conferência: todos lado a lado, cada um com o círculo em que o Roblox mostra o ícone
    cols, cell = 5, 200
    names = list(made)
    sheet = Image.new("RGB", (cols * cell, ((len(names) + cols - 1) // cols) * cell), (24, 24, 28))
    for i, line in enumerate(names):
        t = made[line].convert("RGB").resize((cell - 16, cell - 16), Image.LANCZOS)
        mask = Image.new("L", t.size, 0)
        ImageDraw.Draw(mask).ellipse([0, 0, t.width - 1, t.height - 1], fill=255)
        dark = Image.eval(t, lambda v: v // 3)
        dark.paste(t, (0, 0), mask)
        sheet.paste(dark, ((i % cols) * cell + 8, (i // cols) * cell + 8))
    sheet.save(os.path.join(OUT, "_conferencia.png"))


if __name__ == "__main__":
    main()
