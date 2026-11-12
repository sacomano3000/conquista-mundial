#!/usr/bin/env python3
"""As formas da interface: sombras dos painéis, o anel de "carregando", as fatias do menu circular,
os brilhos e escurecidos da tela inicial e do fim de partida, e a ponta da seta do tutorial.

Não são desenhos com época: são sombras, degradês e fatias de círculo. O RoWorld as fez por código
(tools/uikit/make_textures.py e tools/ui/make_shapes.py) e as enviou pela conta dele; aqui as mesmas
contas rodam de novo e o resultado vai para dentro do jogo (Assets/OwnArtData), então elas não dependem
mais da conta de ninguém. As medidas são as mesmas, ponto por ponto: nenhuma tela muda de aparência.
A única que mudou de desenho é a ponta da seta, que virou ponta de flecha.

Usado por make_own_art.py.   shapes() -> { chave: (imagem, é_máscara, id do RoWorld) }
"""
import importlib.util
import math
import os
import re

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
ASSETS = os.path.join(ROOT, "src", "shared", "Assets")

# --- as sombras e o anel (as contas de tools/uikit/make_textures.py) ---
FEATHER = 40
RAMP = 0.7


def _mask(a):
    img = np.zeros(a.shape + (4,), np.uint8)
    img[..., :3] = 255
    img[..., 3] = np.round(np.clip(a, 0, 1) * 255).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def shadow(radius, size):
    """A sombra macia de um painel de cantos `radius`, numa imagem de `size` px (9 fatias)."""
    ramp = RAMP * FEATHER
    ys, xs = np.mgrid[0:size, 0:size].astype(np.float64) + 0.5
    half = size / 2.0 - FEATHER
    qx = np.abs(xs - size / 2.0) - (half - radius)
    qy = np.abs(ys - size / 2.0) - (half - radius)
    d = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - radius
    a = np.where(d > 0, np.clip(1.0 - d / FEATHER, 0.0, 1.0), np.clip(1.0 + d / ramp, 0.0, 1.0))
    return _mask(a)


def spinner(arc):
    k = 8
    n = 18 * k
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    dx, dy = xs - n / 2.0, ys - n / 2.0
    rr = np.sqrt(dx * dx + dy * dy)
    r0, hw = 7.0 * k, 1.25 * k
    cov = np.clip(hw + 0.5 - np.abs(rr - r0), 0.0, 1.0)
    if arc:
        ang = np.mod(np.arctan2(dy, dx), 2 * math.pi)
        cov = cov * np.clip((1.9 - ang) * r0 + 0.5, 0, 1) * np.clip(ang * r0 + 0.5, 0, 1)
    return _mask(cov)


# --- as fatias, os degradês e a seta (tools/ui/make_shapes.py) ---
def _make_shapes():
    spec = importlib.util.spec_from_file_location("make_shapes", os.path.join(ROOT, "tools", "ui", "make_shapes.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def radial_pages():
    """As páginas das fatias do menu circular e onde cada fatia ficou: (páginas, { nome: retângulo })."""
    S = _make_shapes()
    packer = S.Packer()
    segs = {}
    for name, ri, ro in S.VARIANTS:
        for n in range(2, 9):
            fill, outline, (cx, cy) = S.seg_masks(n, ri, ro)
            for layer, cov in (("fill", fill), ("line", outline)):
                img = S.to_img(cov)
                pi, x, y = packer.add(img)
                segs["%s_%d_%s" % (name, n, layer)] = (pi, x, y, img.size[0], img.size[1], cx, cy)
    return packer.pages, segs


def gradient(size, frm, to, offsets, colors):
    """Degradê em círculo (as mesmas contas do original), em no máximo 256 tons: o jogo guarda a
    imagem com uma paleta, e assim nenhum tom é aproximado."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u, v = (xx + 0.5) / w, (yy + 0.5) / h
    t = np.clip(np.hypot(u - frm[0], v - frm[1]) / math.hypot(to[0] - frm[0], to[1] - frm[1]), 0, 1)
    t = np.round(t * 255) / 255
    out = np.zeros((h, w, 4))
    cols = np.array(colors, np.float64)
    for c in range(4):
        out[..., c] = np.interp(t, offsets, cols[:, c])
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def arrow_head(size=64):
    """A ponta da seta do tutorial: uma ponta de flecha (a do RoWorld era um triângulo). A mesma caixa:
    ponta em (10, 0), farpas em (-4, +-7), em px lógicos numa caixa de 14 x 14; aponta para +x."""
    ss = 8
    s = size * ss / 14.0
    pts = [(10.0, 0.0), (-4.0, 7.0), (-1.2, 0.0), (-4.0, -7.0)]
    im = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(im).polygon([((x + 4.0) * s, (y + 7.0) * s) for x, y in pts], fill=255)
    a = np.asarray(im.resize((size, size), Image.LANCZOS), np.float64) / 255.0
    return _mask(a)


def shapes():
    out = {}
    kit = open(os.path.join(ASSETS, "UIKit.luau")).read()
    for old, radius, size in re.findall(r'id = "(rbxassetid://\d+)", feather = 40, radius = (\d+), size = (\d+)', kit):
        out["shadow/r%03d" % int(radius)] = (shadow(int(radius), int(size)), True, old)
    for key, arc in (("spinner_arc", True), ("spinner_ring", False)):
        old = re.search(r'%s = "(rbxassetid://\d+)"' % key, kit).group(1)
        out["shape/" + key] = (spinner(arc), True, old)

    sh = open(os.path.join(ASSETS, "UiShapes.luau")).read()
    pages, segs = radial_pages()
    ids = dict(re.findall(r'\[(\d+)\] = "(rbxassetid://\d+)"', sh))
    if len(ids) != len(pages):
        raise SystemExit("UiShapes.luau tem %d páginas, as contas deram %d" % (len(ids), len(pages)))
    # (as fatias têm de cair onde Assets/UiShapes diz: o jogo recorta por essas medidas)
    for name, (pi, x, y, w, h, cx, cy) in segs.items():
        want = "%s = { page = %d, x = %d, y = %d, w = %d, h = %d, cx = %d, cy = %d }" % (name, pi, x, y, w, h, cx, cy)
        if want not in sh:
            raise SystemExit("a fatia %s não caiu onde Assets/UiShapes.luau diz" % name)
    for i, pg in enumerate(pages):
        # (só a parte usada da página: as fatias são medidas a partir do canto de cima, à esquerda, e
        # uma imagem menor pesa menos na memória do aparelho)
        w = max(x + ww for (pi, x, y, ww, hh, cx, cy) in segs.values() if pi == i)
        h = max(y + hh for (pi, x, y, ww, hh, cx, cy) in segs.values() if pi == i)
        out["shape/radial_%d" % i] = (pg.crop((0, 0, w, h)), True, ids[str(i)])

    def one(key):
        return re.search(r'%s = "(rbxassetid://\d+)"' % key, sh).group(1)

    out["shape/title_vignette"] = (
        gradient((256, 256), (0.5, 0.45), (1.05, 1.05), [0.0, 0.55, 1.0], [(1, 1, 1, 0.0), (1, 1, 1, 0.25), (1, 1, 1, 0.85)]),
        True,
        one("title_vignette"),
    )
    out["shape/title_glow"] = (
        gradient((256, 128), (0.5, 0.5), (1.0, 0.5), [0.0, 1.0], [(1.0, 0.72, 0.35, 0.28), (1.0, 0.6, 0.2, 0.0)]),
        False,
        one("title_glow"),
    )
    out["shape/over_dim"] = (
        gradient((256, 256), (0.5, 0.45), (1.1, 1.1), [0.0, 1.0], [(0.01, 0.015, 0.05, 0.55), (0.0, 0.005, 0.02, 0.92)]),
        False,
        one("over_dim"),
    )
    S = _make_shapes()
    out["shape/disc_glow"] = (S.disc_glow(), True, one("disc_glow"))
    out["shape/arrow_head"] = (arrow_head(), True, one("arrow_head"))
    return out


if __name__ == "__main__":
    got = shapes()
    for k, (im, is_mask, old) in sorted(got.items()):
        print("%-24s %4dx%-4d %s %s" % (k, im.width, im.height, "máscara" if is_mask else "cores  ", old))
    print(len(got), "formas")
