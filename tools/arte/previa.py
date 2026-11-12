#!/usr/bin/env python3
"""A prévia dos desenhos do jogo: assets/previa-do-visual.png. (As prévias das telas saem de
tools/arte/telas.py.)

Rodar da raiz do projeto, depois de make_own_art.py:  python3 tools/arte/previa.py
"""
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
A = lambda *p: os.path.join(ROOT, *p)  # noqa: E731
BG = (24, 25, 29)
PANEL = (38, 40, 46)
RED = (222, 41, 54)
TEXT = (236, 236, 240)
DIM = (150, 150, 158)
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def font(px, bold=False):
    try:
        return ImageFont.truetype(BOLD if bold else SANS, px)
    except OSError:
        return ImageFont.load_default()


def icon(key):
    return Image.open(A("assets", "icones", key.replace("/", "_") + ".png")).convert("RGBA")


def tint(im, rgb):
    out = Image.new("RGBA", im.size, rgb + (0,))
    out.putalpha(im.getchannel("A"))
    return out


def fit(im, w, h, nearest=False):
    k = min(w / im.width, h / im.height)
    return im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.NEAREST if nearest else Image.LANCZOS)


def visual():
    W = 1400
    im = Image.new("RGBA", (W, 2000), BG + (255,))
    d = ImageDraw.Draw(im)
    y = 28
    d.text((36, y), "Conquista Mundial: os desenhos do jogo", font=font(34, True), fill=TEXT)
    y += 64

    def title(t):
        nonlocal y
        d.text((36, y), t, font=font(20, True), fill=RED)
        y += 34

    title("AS OITO FIGURAS DO ARSENAL")
    names = [("mega", "Magia Suprema"), ("scatter", "Rajada Arcana"), ("reinforce", "Reforços"), ("artillery", "Catapulta"),
             ("airfield", "Ataque de Dragões"), ("railgun", "Balista Arcana"), ("stars2x", "2x Coroas"), ("reload2x", "Recarga Rápida")]
    for i, (k, name) in enumerate(names):
        x = 36 + i * 168
        d.rounded_rectangle([x, y, x + 156, y + 190], 14, fill=PANEL)
        p = fit(icon("render/" + k), 136, 136)
        im.alpha_composite(p, (x + 78 - p.width // 2, y + 10 + (136 - p.height) // 2))
        tw = d.textlength(name, font=font(14))
        d.text((x + 78 - tw / 2, y + 160), name, font=font(14), fill=TEXT)
    y += 214

    title("EFEITOS DAS PRÉVIAS DO ARSENAL (bola de fogo, pilar de fogo, pedra em chamas, flecha, asas)")
    d.rounded_rectangle([36, y, W - 36, y + 430], 14, fill=PANEL)
    ex = fit(icon("fx/explosion"), 680, 86)
    im.alpha_composite(ex, (52, y + 16))
    x = 760
    for k, sz in (("bomb", 76), ("warhead", 76), ("chute", 104), ("tracer", 116), ("smoke", 66), ("reticle", 84)):
        p = fit(icon("fx/" + k), sz, sz)
        im.alpha_composite(p, (x, y + 60 - p.height // 2))
        x += p.width + 12
    mu = fit(icon("fx/mushroom"), 620, 310)
    im.alpha_composite(mu, (52, y + 114))
    am = fit(icon("fx/arsenal_maps").crop((0, 0, 980, 276)), 620, 300)
    im.alpha_composite(am, (700, y + 130))
    d.text((700, y + 316), "o chão das prévias: pedaços de Eldoria", font=font(14), fill=DIM)
    y += 454

    title("EFEITOS DO MAPA (pixel art), ESTRADA DE PEDRA E LUZES DO BAÚ")
    d.rounded_rectangle([36, y, W - 36, y + 330], 14, fill=PANEL)
    mf = icon("fx/map")
    mf = mf.resize((mf.width * 2 - 440, int(mf.height * (mf.width * 2 - 440) / mf.width)), Image.NEAREST)
    im.alpha_composite(mf, (52, y + 14))
    x = 1070
    for k in ("h", "v", "bl", "tr"):
        p = tint(icon("map/road_" + k), (214, 196, 160)).resize((60, 60), Image.NEAREST)
        im.alpha_composite(p, (x, y + 20))
        x += 68
    x = 1070
    for k in ("rays", "glow", "ring", "sparkle"):
        p = fit(tint(icon("chest/" + k), (255, 214, 110)), 64, 64)
        im.alpha_composite(p, (x, y + 110))
        x += 68
    y += 354

    title("ÍCONES DA INTERFACE, DAS ESTRUTURAS E DO ARSENAL")
    keys = sorted(f[:-4] for f in os.listdir(A("assets", "icones")) if f.startswith(("icons_", "arsenal_", "map_", "crate_")) and "hud_" not in f and "road_" not in f)
    cols = 19
    rows = (len(keys) + cols - 1) // cols
    d.rounded_rectangle([36, y, W - 36, y + rows * 70 + 16], 14, fill=PANEL)
    for i, k in enumerate(keys):
        p = tint(Image.open(A("assets", "icones", k + ".png")).convert("RGBA"), TEXT).resize((56, 56), Image.LANCZOS)
        im.alpha_composite(p, (50 + (i % cols) * 69, y + 12 + (i // cols) * 70))
    y += rows * 70 + 40

    title("LOGO, PLACAS DO MAPA E O MUNDO")
    d.rounded_rectangle([36, y, W - 36, y + 300], 14, fill=PANEL)
    lg = fit(icon("logo"), 260, 260)
    im.alpha_composite(lg, (60, y + 20))
    pl = fit(icon("sheet/plates"), 520, 120)
    im.alpha_composite(pl, (350, y + 20))
    st = fit(icon("sheet/status"), 520, 130)
    im.alpha_composite(st, (350, y + 150))
    th = fit(icon("thumb/world"), 440, 260)
    im.alpha_composite(th, (910, y + 20))
    y += 324
    im.crop((0, 0, W, y + 10)).convert("RGB").save(A("assets", "previa-do-visual.png"))


if __name__ == "__main__":
    visual()
    print("assets/previa-do-visual.png")
