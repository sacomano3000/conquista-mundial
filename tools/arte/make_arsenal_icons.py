#!/usr/bin/env python3
"""As figuras do Arsenal (as oito figuras grandes da loja), dentro do código.

    python3 tools/arte/make_arsenal_icons.py                 # refaz os módulos a partir de assets/arsenal-icons
    python3 tools/arte/make_arsenal_icons.py --recortar DIR  # antes, recorta DIR/<item>.png (fundo branco)

Cada figura é um PNG recortado (fundo transparente) em assets/arsenal-icons/<item>.png. Este script a
reduz para 128 x 128, guarda como paleta + um byte por ponto em src/shared/Assets/ArsenalIcon_<item>.luau
(o jogo desenha com EditableImage: Assets/ArsenalIcons), e acerta as somas de tests/arsenal_icons.luau.

Para trocar uma figura: ponha o desenho novo (qualquer tamanho, fundo branco liso, contorno escuro) numa
pasta com o nome do item e rode com --recortar; ou ponha direto um PNG já transparente em
assets/arsenal-icons e rode sem nada. Precisa de Pillow e numpy.
"""
import base64
import re
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "arsenal-icons"
OUT = ROOT / "src" / "shared" / "Assets"
TEST = ROOT / "tests" / "arsenal_icons.luau"
KEYS = ["mega", "scatter", "reinforce", "artillery", "airfield", "railgun", "stars2x", "reload2x"]
SIZE = 128
KEEP = 256  # o tamanho do recorte guardado em assets/arsenal-icons
MARGIN = 3


def _flood(ok: np.ndarray, seeds: np.ndarray) -> np.ndarray:
    """Os pontos de `ok` ligados a algum ponto de `seeds`."""
    h, w = ok.shape
    got = seeds & ok
    q = deque(zip(*np.nonzero(got)))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and ok[ny, nx] and not got[ny, nx]:
                got[ny, nx] = True
                q.append((ny, nx))
    return got


def cut_out(path: Path) -> Image.Image:
    """Tira o fundo branco: de fora para dentro, e os vãos brancos grandes fechados pelo desenho."""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    h, w, _ = a.shape
    low = a.min(axis=2)
    edge = np.zeros((h, w), dtype=bool)
    edge[0, :] = edge[-1, :] = edge[:, 0] = edge[:, -1] = True
    bg = _flood(low >= 236, edge)
    # a moldura clara de "adesivo" e a franja da borda: o claro encostado no fundo também sai, até
    # o contorno escuro
    near = np.zeros((h, w), dtype=bool)
    near[1:, :] |= bg[:-1, :]
    near[:-1, :] |= bg[1:, :]
    near[:, 1:] |= bg[:, :-1]
    near[:, :-1] |= bg[:, 1:]
    bg |= _flood((low >= 176) & ~bg, near & ~bg)
    # vãos de branco puro, grandes, sem ligação com a borda (entre duas peças do desenho)
    rest = (low >= 247) & ~bg
    seen = np.zeros((h, w), dtype=bool)
    for y, x in zip(*np.nonzero(rest)):
        if seen[y, x]:
            continue
        one = np.zeros((h, w), dtype=bool)
        one[y, x] = True
        comp = _flood(rest, one)
        seen |= comp
        if comp.sum() >= h * w * 0.0025:
            bg |= comp
    alpha = Image.fromarray(np.where(bg, 0, 255).astype(np.uint8), "L")
    # um ponto para dentro (a franja clara da borda) e a borda amaciada
    alpha = alpha.filter(ImageFilter.MinFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    box = alpha.point(lambda v: 255 if v > 24 else 0).getbbox()
    return out.crop(box)


def fit(im: Image.Image, size: int, margin: int) -> Image.Image:
    """Centraliza num quadrado, sem misturar a cor do fundo na borda (alfa pré-multiplicado)."""
    room = size - 2 * margin
    k = min(room / im.width, room / im.height)
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    a = np.asarray(im).astype(np.float64)
    a[..., :3] *= a[..., 3:4] / 255.0
    pre = Image.fromarray(a.round().clip(0, 255).astype(np.uint8), "RGBA").resize((w, h), Image.LANCZOS)
    b = np.asarray(pre).astype(np.float64)
    al = b[..., 3:4]
    b[..., :3] = np.where(al > 0, b[..., :3] * 255.0 / np.maximum(al, 1), 0)
    small = Image.fromarray(b.round().clip(0, 255).astype(np.uint8), "RGBA")
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(small, ((size - w) // 2, (size - h) // 2))
    return out


def encode(im: Image.Image):
    """(cores, base64, soma): paleta RGBA de até 255 cores + um byte por ponto."""
    a = np.asarray(im).copy()
    a[a[..., 3] < 10] = (254, 0, 255, 0)  # tudo que é transparente vira uma cor só
    q = Image.fromarray(a, "RGBA").quantize(colors=254, method=Image.FASTOCTREE, dither=Image.NONE)
    pal = np.asarray(q.getpalette("RGBA"), dtype=np.uint8).reshape(-1, 4)
    idx = np.asarray(q, dtype=np.uint8)
    n = int(idx.max()) + 1
    pal = pal[:n].copy()
    pal[pal[:, 3] < 10] = (254, 0, 255, 0)
    pal[pal[:, 3] >= 236, 3] = 255  # o que é cheio fica cheio
    raw = pal.tobytes() + idx.tobytes()
    rgba = pal[idx]
    return n, base64.b64encode(raw).decode("ascii"), int(rgba.astype(np.int64).sum()), rgba


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "--recortar":
        src = Path(sys.argv[2])
        for key in KEYS:
            p = src / f"{key}.png"
            if p.exists():
                fit(cut_out(p), KEEP, MARGIN * 2).save(SRC / f"{key}.png")
                print("recortado", key)
    sums = {}
    tiles = []
    for key in KEYS:
        im = Image.open(SRC / f"{key}.png").convert("RGBA")
        box = im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
        small = fit(im.crop(box), SIZE, MARGIN)
        n, data, total, rgba = encode(small)
        sums[key] = total
        tiles.append(Image.fromarray(rgba, "RGBA"))
        (OUT / f"ArsenalIcon_{key}.luau").write_text(
            f"-- GENERATED from assets/arsenal-icons/{key}.png by tools/arte/make_arsenal_icons.py — do not edit by hand.\n"
            f'-- The Arsenal\'s own picture of "{key}" (Assets/ArsenalIcons reads it): `colors` RGBA palette entries, then\n'
            "-- one byte per pixel, in base64.\n"
            "return {\n"
            f"\tcolors = {n},\n"
            f'\tdata = "{data}",\n'
            "}\n"
        )
        print(f"{key}: {n} cores, soma {total}")
    t = TEST.read_text()
    for key, total in sums.items():
        t, k = re.subn(rf"(\n\t{key} = )\d+,", rf"\g<1>{total},", t)
        assert k == 1, key
    TEST.write_text(t)
    # a prévia: como ficam no jogo (128 px), sobre o grafite dos painéis
    sheet = Image.new("RGBA", (len(KEYS) * 168 + 24, 196), (24, 24, 28, 255))
    for i, tile in enumerate(tiles):
        sheet.alpha_composite(tile, (24 + i * 168 + 8, 34))
    sheet.convert("RGB").save(SRC / "previa.png")


if __name__ == "__main__":
    main()
