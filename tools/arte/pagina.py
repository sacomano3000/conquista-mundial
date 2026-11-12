#!/usr/bin/env python3
"""Imagens da página do jogo no Roblox, a partir das duas pinturas em assets/pagina/.

  python3 tools/arte/pagina.py

  icone-arte.png      -> icone.png                 512 x 512   (ícone do jogo)
  miniatura-arte.png  -> miniatura-sem-titulo.png  1920 x 1080 (só a pintura, cortada em 16:9)
                      -> miniatura.png             1920 x 1080 (com o nome do jogo)

As duas pinturas foram geradas por IA (11/11/2026) e não são refeitas aqui. O nome é escrito com a
fonte do jogo (Rubik): tools/arte/fontes/Rubik.ttf ou ~/.cache/fonts/Rubik.ttf.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DIR = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "pagina"))
FONTS = [os.path.join(HERE, "fontes", "Rubik.ttf"), os.path.expanduser("~/.cache/fonts/Rubik.ttf")]
W, H = 1920, 1080


def font(size, weight):
    for path in FONTS:
        if os.path.exists(path):
            f = ImageFont.truetype(path, size)
            try:
                f.set_variation_by_axes([weight])
            except Exception:
                pass
            return f
    sys.exit("falta a fonte Rubik (veja o cabeçalho)")


def spaced(draw, xy, text, f, gap, **kw):
    """Escreve `text` com `gap` px a mais entre as letras; devolve a largura."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=f, **kw)
        x += draw.textlength(ch, font=f) + gap
    return x - xy[0] - gap


def icon():
    im = Image.open(os.path.join(DIR, "icone-arte.png")).convert("RGB")
    side = min(im.size)
    left, top = (im.width - side) // 2, (im.height - side) // 2
    im = im.crop((left, top, left + side, top + side)).resize((512, 512), Image.LANCZOS)
    im.save(os.path.join(DIR, "icone.png"), optimize=True)


def thumb():
    im = Image.open(os.path.join(DIR, "miniatura-arte.png")).convert("RGB")
    # 16:9, tirando a sobra da esquerda (o escudo fica à direita)
    want = round(im.height * 16 / 9)
    if want <= im.width:
        left = im.width - want - min(4, im.width - want)
        im = im.crop((left, 0, left + want, im.height))
    else:
        tall = round(im.width * 9 / 16)
        top = (im.height - tall) // 2
        im = im.crop((0, top, im.width, top + tall))
    im = im.resize((W, H), Image.LANCZOS)
    im.save(os.path.join(DIR, "miniatura-sem-titulo.png"), optimize=True)

    # o nome, no canto escuro de cima à esquerda
    base = im.convert("RGBA")
    shade = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(shade)
    d.ellipse((-520, -420, 1180, 520), fill=150)
    shade = shade.filter(ImageFilter.GaussianBlur(120))
    base = Image.composite(Image.new("RGBA", (W, H), (6, 8, 16, 255)), base, shade)

    big, small = font(150, 900), font(104, 800)
    x, y = 84, 62
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # sombra
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.text((x + 6, y + 10), "CONQUISTA", font=big, fill=(0, 0, 0, 220), stroke_width=10, stroke_fill=(0, 0, 0, 220))
    sh = sh.filter(ImageFilter.GaussianBlur(9))
    # "CONQUISTA" em ouro, de cima (claro) para baixo (escuro)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).text((x, y), "CONQUISTA", font=big, fill=255)
    box = mask.getbbox()
    grad = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dg = ImageDraw.Draw(grad)
    top_c, bot_c = (255, 226, 122), (232, 150, 28)
    for yy in range(box[1], box[3] + 1):
        t = (yy - box[1]) / max(1, box[3] - box[1])
        dg.line([(box[0], yy), (box[2], yy)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top_c, bot_c)) + (255,))
    d.text((x, y), "CONQUISTA", font=big, fill=(60, 26, 6, 255), stroke_width=8, stroke_fill=(60, 26, 6, 255))
    layer = Image.alpha_composite(layer, Image.composite(grad, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask))
    d = ImageDraw.Draw(layer)
    wide = box[2] - box[0]
    # "MUNDIAL" em branco, espaçado para ter a largura de "CONQUISTA"
    letters = "MUNDIAL"
    natural = sum(d.textlength(ch, font=small) for ch in letters)
    gap = (wide - natural) / (len(letters) - 1)
    low = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    spaced(ImageDraw.Draw(low), (box[0] + 4, y + 172 + 7), letters, small, gap, fill=(0, 0, 0, 200), stroke_width=7, stroke_fill=(0, 0, 0, 200))
    sh = Image.alpha_composite(sh, low.filter(ImageFilter.GaussianBlur(7)))
    spaced(d, (box[0], y + 172), letters, small, gap, fill=(245, 240, 228, 255), stroke_width=7, stroke_fill=(40, 18, 8, 255))
    out = Image.alpha_composite(Image.alpha_composite(base, sh), layer).convert("RGB")
    out.save(os.path.join(DIR, "miniatura.png"), optimize=True)


if __name__ == "__main__":
    icon()
    thumb()
    for name in ("icone.png", "miniatura.png", "miniatura-sem-titulo.png"):
        p = os.path.join(DIR, name)
        print(f"  {name}: {Image.open(p).size}, {os.path.getsize(p):,} bytes")
