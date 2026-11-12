#!/usr/bin/env python3
"""Desenha as telas do jogo fora do Roblox, a partir do que os testes montam (tests/ui_harness.luau).

  lune run tests/telas.luau          # monta as telas e grava assets/telas/*.json
  python3 tools/arte/telas.py        # desenha cada .json em assets/previa-<tela>.png

Não é o Roblox: as letras, as sombras e o baú 3D são aproximados. Serve para conferir a posição e o
tamanho de cada peça (nada fora da janela, nada por cima de outra coisa) e para ter uma prévia de cada
tela sem abrir o Studio.
"""
import json
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ICONS = os.path.join(ROOT, "assets", "icones")
SS = 2  # supersampling

FONT_CANDIDATES = [
    os.path.join(HERE, "fontes", "Rubik.ttf"),
    os.path.expanduser("~/.cache/fonts/Rubik.ttf"),
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]
_fonts = {}


def font(px, weight):
    px = max(4, int(round(px)))
    w = int(round(max(300, min(900, weight)) / 100.0) * 100)
    k = (px, w)
    if k not in _fonts:
        f = None
        for path in FONT_CANDIDATES:
            if os.path.exists(path):
                try:
                    f = ImageFont.truetype(path, px)
                    try:
                        f.set_variation_by_axes([w])
                    except Exception:
                        pass
                    break
                except Exception:
                    f = None
        _fonts[k] = f or ImageFont.load_default()
    return _fonts[k]


def rgb(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


_images = {}
NOT_DRAWN = set()


def art(key):
    if key not in _images:
        path = os.path.join(ICONS, key.replace("/", "_") + ".png")
        _images[key] = Image.open(path).convert("RGBA") if os.path.exists(path) else None
    return _images[key]


def skin_tile(skin, size):
    """Um padrão de território (Data/Cosmetics) como a Coleção o mostra: sobre areia, na cor azul."""
    n = 48 if skin.get("colors") else 24
    rows = skin["mask"]
    mh, mw = len(rows), max(len(r) for r in rows)
    scale = skin.get("scale", 0)
    base = (64, 132, 230)
    sand = (221, 205, 160)

    def over(c, a):
        return tuple(int(sand[i] * (1 - a) + c[i] * a + 0.5) for i in range(3))

    if skin.get("accent") is not None:
        a = skin["accent"]
        sec = ((a >> 16) & 255, (a >> 8) & 255, a & 255)
    else:
        t = skin.get("tone", -0.2)
        sec = tuple(int(c + (255 - c) * t) for c in base) if t >= 0 else tuple(int(c * (1 + t)) for c in base)
    im = Image.new("RGBA", (n, n))
    px = im.load()
    for y in range(n):
        for x in range(n):
            if x in (0, n - 1) or y in (0, n - 1):
                px[x, y] = tuple(int(c * 0.875) for c in base) + (255,)
                continue
            row = rows[(y >> scale) % mh]
            ch = row[(x >> scale) % mw] if (x >> scale) % mw < len(row) else "."
            if skin.get("colors") and ch != ".":
                k = int(ch, 36) if ch.isalnum() else 0
                cols = skin["colors"]
                if 1 <= k <= len(cols):
                    c = cols[k - 1]
                    px[x, y] = over(((c >> 16) & 255, (c >> 8) & 255, c & 255), 190 / 255) + (255,)
                    continue
                px[x, y] = over(base, 150 / 255) + (255,)
            elif ch != "." and not skin.get("colors"):
                px[x, y] = over(sec, 190 / 255) + (255,)
            else:
                px[x, y] = over(base, 150 / 255) + (255,)
    return im.resize(size, Image.NEAREST)


def rounded_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=max(0, min(r, w / 2, h / 2)), fill=255)
    return m


def alpha_grad(w, h, keys, rot):
    """Transparência de um UIGradient: 0 e 180 graus = horizontal, 90 e 270 = vertical."""
    g = Image.new("L", (w, h))
    px = g.load()
    vertical = int(round(rot)) % 180 == 90
    flip = int(round(rot)) % 360 in (180, 270)
    n = h if vertical else w
    line = []
    for i in range(n):
        t = i / max(1, n - 1)
        if flip:
            t = 1 - t
        a = keys[-1][1]
        for j in range(len(keys) - 1):
            t0, a0 = keys[j]
            t1, a1 = keys[j + 1]
            if t0 <= t <= t1:
                a = a0 + (a1 - a0) * ((t - t0) / max(1e-6, t1 - t0))
                break
        line.append(int(max(0, min(1, a)) * 255))
    for y in range(h):
        for x in range(w):
            px[x, y] = line[y if vertical else x]
    return g


def paste(canvas, layer, x, y, clip):
    """Cola `layer` (RGBA) em (x, y), cortada por `clip` (x0, y0, x1, y1)."""
    x, y = int(round(x)), int(round(y))
    if clip is not None:
        cx0, cy0, cx1, cy1 = [int(round(v * SS)) for v in clip]
        lx0, ly0 = max(0, cx0 - x), max(0, cy0 - y)
        lx1, ly1 = min(layer.width, cx1 - x), min(layer.height, cy1 - y)
        if lx1 <= lx0 or ly1 <= ly0:
            return
        layer = layer.crop((lx0, ly0, lx1, ly1))
        x, y = x + lx0, y + ly0
    canvas.alpha_composite(layer, (x, y)) if 0 <= x and 0 <= y and x + layer.width <= canvas.width and y + layer.height <= canvas.height else _composite_partial(canvas, layer, x, y)


def _composite_partial(canvas, layer, x, y):
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(canvas.width, x + layer.width), min(canvas.height, y + layer.height)
    if x1 <= x0 or y1 <= y0:
        return
    canvas.alpha_composite(layer.crop((x0 - x, y0 - y, x1 - x, y1 - y)), (x0, y0))


def draw_item(canvas, e, extra):
    x, y, w, h = e["x"] * SS, e["y"] * SS, e["w"] * SS, e["h"] * SS
    wi, hi = int(round(w)), int(round(h))
    if wi <= 0 or hi <= 0 or wi > 20000 or hi > 20000:
        return
    clip = e.get("clip")
    radius = e.get("radius", 0) * SS
    mask = rounded_mask(wi, hi, radius)
    grad = e.get("grad")
    # background
    if e["bga"] > 0.004 and e["class"] != "ViewportFrame":
        col = rgb(e["bg"])
        layer = Image.new("RGBA", (wi, hi), col + (0,))
        a = mask.point(lambda v: int(v * e["bga"]))
        if grad and grad.get("alphas") and len(grad["alphas"]) > 1:
            g = alpha_grad(wi, hi, grad["alphas"], grad.get("rot", 0))
            a = Image.fromarray((np.asarray(a, dtype="float32") * np.asarray(g, dtype="float32") / 255.0).astype("uint8"))
        # (as cores de um UIGradient multiplicam a cor do fundo, como no Roblox)
        if grad and grad.get("colors") and len(grad["colors"]) > 1:
            keys = [(k[0], rgb(k[1])) for k in grad["colors"]]
            rot = int(round(grad.get("rot", 0)))
            vertical = rot % 180 == 90
            n = hi if vertical else wi
            t = np.linspace(0.0, 1.0, max(2, n))[:n]
            if rot % 360 in (180, 270):
                t = 1.0 - t
            line = np.stack(
                [np.interp(t, [k[0] for k in keys], [k[1][c] for k in keys]) * col[c] / 255.0 for c in range(3)], axis=1
            )
            arr = np.zeros((hi, wi, 4), dtype="uint8")
            arr[..., :3] = (line[:, None, :] if vertical else line[None, :, :]).astype("uint8")
            layer = Image.fromarray(arr, "RGBA")
        layer.putalpha(a)
        paste(canvas, layer, x, y, clip)
    # stroke
    st = e.get("stroke")
    if st and st[1] > 0.004 and st[2] > 0 and not e.get("text_stroke"):
        t = max(1, int(round(st[2] * SS)))
        layer = Image.new("RGBA", (wi + 2 * t, hi + 2 * t), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        d.rounded_rectangle(
            [t // 2, t // 2, wi + 2 * t - 1 - t // 2, hi + 2 * t - 1 - t // 2],
            radius=max(0, min(radius + t / 2, (wi + t) / 2, (hi + t) / 2)),
            outline=rgb(st[0]) + (int(st[1] * 255),),
            width=t,
        )
        paste(canvas, layer, x - t, y - t, clip)
    cls = e["class"]
    # image
    if cls in ("ImageLabel", "ImageButton", "ViewportFrame"):
        src = None
        if cls == "ViewportFrame":
            src = art("crate/icon") or art("crate_icon")
        elif e.get("skin") and extra.get("skins", {}).get(e["skin"]):
            side = max(2, min(wi, hi))
            src = skin_tile(extra["skins"][e["skin"]], (side, side))
        elif e.get("key"):
            src = art(e["key"])
        ia = e.get("ia", 1) if cls != "ViewportFrame" else 1
        if src is not None and ia > 0.004:
            if e.get("rw", 0) > 0 and e.get("rh", 0) > 0:
                src = src.crop((int(e["rx"]), int(e["ry"]), int(e["rx"] + e["rw"]), int(e["ry"] + e["rh"])))
            fit = e.get("fit", "Stretch") if cls != "ViewportFrame" else "Fit"
            sw, sh = src.size
            if fit == "Fit":
                k = min(wi / sw, hi / sh)
                tw, th = max(1, int(sw * k)), max(1, int(sh * k))
                img = src.resize((tw, th), Image.LANCZOS if k < 1 else Image.BICUBIC)
                ox, oy = (wi - tw) // 2, (hi - th) // 2
            elif fit == "Crop":
                k = max(wi / sw, hi / sh)
                tw, th = max(1, int(sw * k + 0.5)), max(1, int(sh * k + 0.5))
                img = src.resize((tw, th), Image.BICUBIC)
                cx, cy = (tw - wi) // 2, (th - hi) // 2
                img = img.crop((cx, cy, cx + wi, cy + hi))
                ox, oy = 0, 0
            else:
                img = src.resize((wi, hi), Image.BICUBIC)
                ox, oy = 0, 0
            if cls != "ViewportFrame":
                ic = rgb(e.get("ic", "ffffff"))
                if ic != (255, 255, 255) or ia < 0.996:
                    r, g, b, a = img.split()
                    r = r.point(lambda v: v * ic[0] // 255)
                    g = g.point(lambda v: v * ic[1] // 255)
                    b = b.point(lambda v: v * ic[2] // 255)
                    a = a.point(lambda v: int(v * ia))
                    img = Image.merge("RGBA", (r, g, b, a))
            if radius > 0 and fit != "Fit":
                img.putalpha(Image.composite(img.getchannel("A"), Image.new("L", img.size, 0), rounded_mask(img.width, img.height, radius)))
            paste(canvas, img, x + ox, y + oy, clip)
        elif cls != "ViewportFrame" and "robux" in str(e.get("image")) and ia > 0.05:
            # o símbolo do Robux é do próprio Roblox: aqui, um hexágono
            side = min(wi, hi)
            layer = Image.new("RGBA", (wi, hi), (0, 0, 0, 0))
            d = ImageDraw.Draw(layer)
            cx, cy, r = wi / 2, hi / 2, side * 0.46
            import math

            pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(30, 390, 60)]
            col = rgb(e.get("ic", "ffffff")) + (int(ia * 255),)
            d.polygon(pts, outline=col, width=max(2, int(side * 0.14)))
            d.rectangle([cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2], fill=col)
            paste(canvas, layer, x, y, clip)
        elif cls != "ViewportFrame" and str(e.get("image")).startswith("rbxthumb://") and ia > 0.05:
            # o rosto de um jogador é o Roblox que desenha (rbxthumb): aqui, uma silhueta, com uma
            # cor por jogador para as linhas não parecerem todas iguais
            import colorsys, re

            m = re.search(r"id=(\d+)", str(e.get("image")))
            uid = int(m.group(1)) if m else 0
            hue = (uid * 0.61803398875) % 1.0
            r1, g1, b1 = colorsys.hsv_to_rgb(hue, 0.42, 0.78)
            r2, g2, b2 = colorsys.hsv_to_rgb(hue, 0.5, 0.34)
            layer = Image.new("RGBA", (wi, hi), (int(r2 * 255), int(g2 * 255), int(b2 * 255), 255))
            d = ImageDraw.Draw(layer)
            col = (int(r1 * 255), int(g1 * 255), int(b1 * 255), 255)
            d.ellipse([wi * 0.31, hi * 0.17, wi * 0.69, hi * 0.55], fill=col)
            d.ellipse([wi * 0.12, hi * 0.62, wi * 0.88, hi * 1.5], fill=col)
            if radius > 0:
                layer.putalpha(rounded_mask(wi, hi, radius))
            paste(canvas, layer, x, y, clip)
        elif cls != "ViewportFrame" and e.get("image") and e.get("image") != "content" and ia > 0.05 and not e.get("key"):
            # uma imagem guardada no Roblox (não é desenhada pelo jogo): fica de fora da prévia, e é
            # listada ao final para não passar despercebida
            NOT_DRAWN.add(str(e.get("image")))
    # text
    if cls in ("TextLabel", "TextButton", "TextBox") and e.get("text") and e.get("ta", 1) > 0.02:
        text = e["text"]
        size = e["ts"] * SS
        f = font(size * 0.86, e.get("weight", 400))
        layer = Image.new("RGBA", (wi + int(size * 4), hi + int(size * 2)), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        lines = text.split("\n")
        if e.get("scaled"):
            # TextScaled: the text shrinks until its line fits
            while size > 6 * SS and max(d.textlength(ln, font=f) for ln in lines) > wi:
                size -= 1
                f = font(size * 0.86, e.get("weight", 400))
        if e.get("wrap") and wi > 8:
            out = []
            for ln in lines:
                cur = ""
                for word in ln.split(" "):
                    trial = (cur + " " + word).strip()
                    if d.textlength(trial, font=f) <= wi or not cur:
                        cur = trial
                    else:
                        out.append(cur)
                        cur = word
                out.append(cur)
            lines = out
        lh = size * 1.18
        total = lh * len(lines)
        ty = e.get("ty", "Center")
        y0 = size + (0 if ty == "Top" else (hi - total) if ty == "Bottom" else (hi - total) / 2)
        col = rgb(e["tc"]) + (int(e.get("ta", 1) * 255),)
        tx = e.get("tx", "Center")
        for i, ln in enumerate(lines):
            tw = d.textlength(ln, font=f)
            x0 = size * 2 + (0 if tx == "Left" else (wi - tw) if tx == "Right" else (wi - tw) / 2)
            if e.get("text_stroke") and st and st[1] > 0.004:
                d.text((x0, y0 + i * lh + size * 0.08), ln, font=f, fill=rgb(st[0]) + (int(st[1] * e.get("ta", 1) * 255),),
                       stroke_width=max(1, int(round(st[2] * SS))), stroke_fill=rgb(st[0]) + (int(st[1] * e.get("ta", 1) * 255),))
            d.text((x0, y0 + i * lh + size * 0.08), ln, font=f, fill=col)
        paste(canvas, layer, x - size * 2, y - size, clip)


def render(path, out, background=None):
    data = json.load(open(path, encoding="utf-8"))
    vw, vh = data["view"]
    canvas = Image.new("RGBA", (int(vw * SS), int(vh * SS)), (24, 20, 26, 255))
    if background and os.path.exists(background):
        bg = Image.open(background).convert("RGBA")
        k = max(canvas.width / bg.width, canvas.height / bg.height)
        bg = bg.resize((int(bg.width * k + 1), int(bg.height * k + 1)), Image.BICUBIC)
        canvas.alpha_composite(bg.crop((0, 0, canvas.width, canvas.height)))
    extra = data.get("extra") or {}
    for e in data["items"]:
        try:
            draw_item(canvas, e, extra)
        except Exception as err:  # uma peça que não se desenha não derruba a prévia
            print("  (peça ignorada: %s %s: %s)" % (e.get("class"), e.get("name"), err))
    canvas.convert("RGB").resize((int(vw), int(vh)), Image.LANCZOS).save(out)
    note = ""
    if NOT_DRAWN:
        note = "   (fora da prévia, imagens do Roblox: %d)" % len(NOT_DRAWN)
        NOT_DRAWN.clear()
    print("  %s -> %s%s" % (os.path.basename(path), os.path.relpath(out, ROOT), note))


def main():
    src = os.path.join(ROOT, "assets", "telas")
    names = sys.argv[1:] or sorted(f[:-5] for f in os.listdir(src) if f.endswith(".json"))
    for name in names:
        bg = os.path.join(ROOT, "assets", "gerados", "fundo_lobby.png") if name.startswith("lobby") else None
        render(os.path.join(src, name + ".json"), os.path.join(ROOT, "assets", "previa-" + name + ".png"), bg)


if __name__ == "__main__":
    main()
