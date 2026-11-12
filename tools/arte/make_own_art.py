#!/usr/bin/env python3
"""Os ícones próprios do jogo, no lugar das imagens do RoWorld.

Uma imagem só pode ser enviada ao Roblox pela conta dona do jogo, então cada ícone fica guardado no
código (src/shared/Assets/OwnArtData.luau) e o jogo o desenha sozinho (client/UI/ArtSweep). Os mesmos
desenhos saem em PNG (assets/icones) para quem preferir enviá-los e usar os ids (Assets/OwnArtIds).

De onde vêm os desenhos:
  assets/gerados/g_<nome>.png   silhuetas feitas para este jogo (preto no branco)
  tools/arte/glifos.py          os demais, desenhados em código
Cada ícone novo ocupa a área que as telas esperam (tools/arte/caixas.json), e as folhas de sprites do
mapa e dos efeitos mantêm a mesma grade: o código do jogo não muda. Os efeitos vêm de efeitos.py, o
chão das prévias do Arsenal de mapas_do_arsenal.py, e as figuras do Arsenal de assets/arsenal-icons.

Rodar da raiz do projeto:  python3 tools/arte/make_own_art.py     (precisa de Pillow, numpy, zstandard)
"""
import base64, json, math, os, re, sys

import numpy as np
import zstandard
from PIL import Image, ImageChops, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import glifos  # noqa: E402
from glifos import G, shield_pts, star_pts  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
A = lambda *p: os.path.join(ROOT, *p)  # noqa: E731
OUT_PNG = A("assets", "icones")
GENERATED = ["attack", "defense", "city", "port", "factory", "sam", "silo", "artillery", "airfield", "railgun",
             # (2026-11-12, mais medievais: a bola de fogo, o drácar e a trompa de guerra dos Reforços)
             "atom", "warship", "reinforce"]

# ---------------------------------------------------------------------------------------------
# masks
# ---------------------------------------------------------------------------------------------
_cache = {}


def crop(mask):
    bb = mask.getbbox()
    return mask.crop(bb) if bb else mask


def gen_mask(key):
    im = Image.open(A("assets", "gerados", "g_%s.png" % key)).convert("L")
    a = 255.0 - np.asarray(im, dtype=np.float32)
    a = np.clip((a - 50.0) * 1.6, 0, 255).astype(np.uint8)
    return crop(Image.fromarray(a, "L"))


def airstrike():
    g = G()
    g.C(50, 50, 47); g.C(50, 50, 40, 0)
    g.paste(mask("airfield"), 20, 20, 60, 60)
    return g.out()


def arsenal():
    g = G()
    g.P(shield_pts(50, 6, 84, 90))
    g.paste(mask("attack"), 26, 20, 48, 48, 0)
    return g.out()


def mask(key):
    """A máscara do ícone `key`, recortada na sua tinta."""
    if key not in _cache:
        if key in GENERATED:
            m = gen_mask(key)
        elif key == "airstrike":
            m = crop(airstrike())
        elif key == "arsenal":
            m = crop(arsenal())
        elif key == "wall":  # a muralha (era o ícone dos Reforços; fica no estandarte "Guardiões da Muralha")
            m = crop(glifos.wall())
        else:
            m = crop(glifos.DRAWN[key]())
        _cache[key] = m
    return _cache[key]


def fit(m, box, size):
    """`m` encaixada na caixa (x0, y0, x1, y1) de uma imagem size x size (proporção mantida)."""
    x0, y0, x1, y1 = box
    bw, bh = max(1, x1 - x0), max(1, y1 - y0)
    s = min(bw / m.width, bh / m.height)
    w, h = max(1, round(m.width * s)), max(1, round(m.height * s))
    r = m.resize((w, h), Image.LANCZOS)
    out = Image.new("L", size if isinstance(size, tuple) else (size, size), 0)
    out.paste(r, (round(x0 + (bw - w) / 2), round(y0 + (bh - h) / 2)))
    return out


_boxes = None


def box_of(key, default):
    """A área que o desenho `key` ocupa na sua imagem (tools/arte/caixas.json: só números, medidos uma
    vez, para cada ícone ficar do tamanho que as telas esperam)."""
    global _boxes
    if _boxes is None:
        _boxes = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "caixas.json")))
    b = _boxes.get(key)
    return tuple(b) if b else default


def white(m):
    """Máscara -> RGBA branco."""
    im = Image.new("RGBA", m.size, (255, 255, 255, 0))
    im.putalpha(m)
    return im


# ---------------------------------------------------------------------------------------------
# the map's sprite sheets (same grids as assets/map_sprites)
# ---------------------------------------------------------------------------------------------
KINDS = ["city", "port", "factory", "defense", "sam", "silo", "artillery", "airfield", "railgun"]


def plate(kind, k=1.0):
    """A placa (o fundo) de uma estrutura no mapa: uma forma por tipo. k < 1: a mesma, menor."""
    g = G(112)
    T = lambda pts: [(50 + (x - 50) * k, 50 + (y - 50) * k) for x, y in pts]  # noqa: E731
    if kind == "city":  # estandarte
        g.P(T([(7, 5), (93, 5), (93, 76), (50, 96), (7, 76)]))
    elif kind == "port":  # escudo
        g.P(T(shield_pts(50, 5, 88, 91)))
    elif kind == "factory":  # hexágono
        g.P(T([(27, 7), (73, 7), (97, 50), (73, 93), (27, 93), (3, 50)]))
    elif kind == "defense":  # muralha
        g.P(T([(7, 5), (29, 5), (29, 20), (39, 20), (39, 5), (61, 5), (61, 20), (71, 20), (71, 5), (93, 5), (93, 95), (7, 95)]))
    elif kind == "sam":  # escudo de ponta
        g.P(T([(50, 3), (91, 22), (85, 60), (50, 97), (15, 60), (9, 22)]))
    elif kind == "silo":  # obelisco
        g.P(T([(50, 2), (82, 26), (76, 97), (24, 97), (18, 26)]))
    elif kind == "artillery":  # disco
        g.P(T([(50 + 46 * math.cos(a / 32 * math.pi), 50 + 46 * math.sin(a / 32 * math.pi)) for a in range(64)]))
    elif kind == "airfield":  # cartucho largo
        g.P(T([(2, 50), (22, 17), (78, 17), (98, 50), (78, 83), (22, 83)]))
    else:  # railgun: estrela de oito pontas
        g.P(T(star_pts(50, 50, 49, 39, 8)))
    return g.out()


def vgrad(mask_im, top=255, bottom=214):
    h = mask_im.height
    col = np.linspace(top, bottom, h).astype(np.uint8)[:, None].repeat(mask_im.width, 1)
    im = Image.merge("RGBA", [Image.fromarray(col, "L")] * 3 + [mask_im])
    return im


def sheet_plates():
    two = Image.new("RGBA", (9 * 112, 224), (255, 255, 255, 0))
    one = Image.new("RGBA", (9 * 112, 112), (255, 255, 255, 0))
    for i, kind in enumerate(KINDS):
        full, inner = plate(kind), plate(kind, 0.85)
        two.paste(white(full), (i * 112, 0))
        two.paste(vgrad(inner), (i * 112, 112))
        rim = Image.new("RGBA", (112, 112), (62, 62, 62, 0))
        rim.putalpha(full)
        rim.alpha_composite(vgrad(inner))
        one.paste(rim, (i * 112, 0))
    return two, one


def sheet_glyphs():
    out = Image.new("L", (9 * 64, 64), 0)
    for i, kind in enumerate(KINDS):
        box = box_of("glyph/" + kind, (5, 5, 59, 59))
        out.paste(fit(mask(kind), box, 64), (i * 64, 0))
    return white(out)


# 13 x 13, '#' contorno (cor da borda), 'o' miolo (cor do território)
UNITS = [
    ("transport", ["", "", ".....#", ".....##", ".....#o#", ".....#oo#", ".....####", ".....#", "..#########", "..#ooooooo#", "...#ooooo#", "....#####"]),
    ("trade", ["", "", "...#....#", "...##...##", "...#o#..#o#", "...###..###", "...#....#", ".###########", ".#ooooooooo#", "..#ooooooo#", "...#######"]),
    # (o drácar: um mastro, uma vela quadrada, proa e popa erguidas)
    ("warship", ["......#", "..#########", "..#ooooooo#", "..#ooooooo#", "..#########", "......#", "#.....#.....#", "#############", ".#ooooooooo#", "..#########"]),
    ("atom", ["", "", ".........#", ".......##", ".....###", "....#ooo#", "...#ooooo#", "...#ooooo#", "...#ooooo#", "....#ooo#", ".....###"]),
    ("hydrogen", ["", "..........#", ".....#..##", "......###", "....#####", "...#ooooo#", "..#ooooooo#", "..#ooooooo#", "..#ooooooo#", "...#ooooo#", "....#####"]),
    ("mirv", ["", "......#", "......#", "..#..#o#..#", "...##ooo##", "...#ooooo#", ".##ooooooo##", "...#ooooo#", "...##ooo##", "..#..#o#..#", "......#", "......#"]),
    ("sam", ["", "", "", "", "......#", ".....#o#", "....#ooo#", ".....#o#", "......#"]),
    ("shell", ["", "", "", "", "", "......#", ".....#o#", "......#"]),
    ("warhead", ["", "", "", "", "", ".....###", ".....#o#", ".....###"]),
    ("train", ["", "", "", "....#####", "...#ooooo#", "...#o###o#", "...#o#.#o#", "...#o###o#", "...#ooooo#", "....#####"]),
    ("carriage", ["", "", "", "", "....#####", "....#...#", "....#...#", "....#...#", "....#####"]),
    ("carriage_loaded", ["", "", "", "", "....#####", "....#ooo#", "....#ooo#", "....#ooo#", "....#####"]),
]


def sheet_units():
    two = Image.new("RGBA", (12 * 13, 26), (255, 255, 255, 0))
    one = Image.new("RGBA", (12 * 13, 13), (255, 255, 255, 0))
    for i, (_name, rows) in enumerate(UNITS):
        assert len(rows) <= 13
        for y, row in enumerate(rows):
            assert len(row) <= 13, (_name, row)
            for x, ch in enumerate(row):
                if ch == "o":
                    two.putpixel((i * 13 + x, y), (255, 255, 255, 255))
                    one.putpixel((i * 13 + x, y), (255, 255, 255, 255))
                elif ch == "#":
                    two.putpixel((i * 13 + x, 13 + y), (255, 255, 255, 255))
                    one.putpixel((i * 13 + x, y), (204, 204, 204, 255))
    return two, one


DARK = (22, 22, 26)
RED, GOLD, GREEN = (214, 48, 54), (230, 180, 60), (66, 172, 92)


def badge(layers, ow=7):
    """Uma célula de 256 da folha de estados: camadas (máscara 224 x 224, cor) com contorno escuro."""
    cell = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    union = Image.new("L", (224, 224), 0)
    for m, _c in layers:
        union = ImageChops.lighter(union, m)
    big = Image.new("L", (256, 256), 0)
    big.paste(union, (16, 16))
    edge = big.filter(ImageFilter.MaxFilter(2 * ow + 1)).filter(ImageFilter.GaussianBlur(1.0))
    cell.paste(DARK + (255,), (0, 0), edge)
    for m, c in layers:
        cell.paste(c + (255,), (16, 16), m)
    return cell


def big(key, pad=10):
    return fit(mask(key), (pad, pad, 224 - pad, 224 - pad), 224)


def sheet_status():
    def g224():
        return G(224)

    g = g224()  # sem conexão: ondas cortadas
    for r in (78, 52, 26):
        g.A(50, 84, r, 225, 315, 11)
    g.C(50, 84, 8); g.L([(14, 14), (86, 92)], 20, 0)
    disc = g.out()
    g = g224(); g.L([(16, 16), (84, 90)], 9)
    slash = g.out()
    g = g224()  # carta
    g.R(6, 22, 94, 80, 6); g.L([(8, 26), (50, 56), (92, 26)], 4, 0)
    letter = g.out()
    g = g224(); g.C(74, 70, 21)
    seal = g.out()
    g = g224(); g.R(70, 58, 78, 82, 2); g.R(62, 66, 86, 74, 2)
    plus = g.out()
    g = g224(); g.P(shield_pts(50, 6, 84, 90))
    shield = g.out()
    g = g224(); g.L([(30, 50), (45, 66), (72, 32)], 12)
    tick = g.out()
    g = g224(); g.L([(12, 14), (88, 90)], 12)
    bar = g.out()
    cells = [
        badge([(big("crown"), GOLD)]),
        badge([(big("betray"), RED)]),
        badge([(disc, (150, 152, 162)), (slash, (150, 152, 162))]),
        badge([(big("alliance"), GREEN)]),
        badge([(letter, (240, 236, 226)), (seal, GREEN), (plus, (255, 255, 255))]),
        badge([(big("target"), RED)]),
        badge([(big("gold", 22), (206, 156, 62)), (bar, RED)]),
        badge([(big("atom"), RED)]),
        badge([(big("atom"), (246, 244, 240))]),
        badge([(big("alliance"), (150, 178, 158))]),
        badge([(big("clock"), RED)]),
        badge([(shield, (58, 118, 214)), (tick, (255, 255, 255))]),
    ]
    out = Image.new("RGBA", (768, 1024), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        out.paste(c, ((i % 3) * 256, (i // 3) * 256))
    return out


def logo():
    """O emblema do jogo (512 x 512, colorido): escudo vermelho, espadas, coroa, em grafite."""
    n = 512
    g = G(n); g.R(0, 0, 100, 100, 20)
    card = g.out()
    yy = np.linspace(0, 1, n)[:, None].repeat(n, 1)
    xx = np.linspace(0, 1, n)[None, :].repeat(n, 0)
    r = np.sqrt((xx - 0.5) ** 2 + (yy - 0.42) ** 2)
    v = np.clip(52 - 46 * r / 0.7, 10, 60)
    rgb = np.stack([v + 2, v, v + 4], -1).astype(np.uint8)
    im = Image.fromarray(rgb, "RGB").convert("RGBA")
    g = G(n); g.P(shield_pts(50, 24, 62, 68))
    rim = g.out()
    g = G(n); g.P(shield_pts(50, 27, 55, 62))
    face = g.out()
    red = np.zeros((n, n, 3), np.uint8)
    t = np.clip((yy - 0.27) / 0.6, 0, 1)
    red[..., 0] = (226 - 96 * t).astype(np.uint8); red[..., 1] = (44 - 26 * t).astype(np.uint8); red[..., 2] = (52 - 26 * t).astype(np.uint8)
    im.paste((236, 232, 226, 255), (0, 0), rim)
    im.paste(Image.fromarray(red, "RGB"), (0, 0), face)
    sw = fit(mask("attack"), (int(n * 0.31), int(n * 0.33), int(n * 0.69), int(n * 0.71)), n)
    im.paste((246, 244, 240, 255), (0, 0), sw)
    cr = fit(mask("crown"), (int(n * 0.36), int(n * 0.045), int(n * 0.64), int(n * 0.235)), n)
    edge = cr.filter(ImageFilter.MaxFilter(9))
    im.paste((20, 20, 24, 255), (0, 0), edge)
    im.paste((236, 186, 66, 255), (0, 0), cr)
    im.putalpha(card)
    return im


# ---------------------------------------------------------------------------------------------
# what replaces what
# ---------------------------------------------------------------------------------------------
def ids_of(path, block=None):
    s = open(path).read()
    if block is not None:
        a = s.index(block)
        s = s[a : s.index("}", a)]
    return {k: "rbxassetid://" + v for k, v in re.findall(r'(\w+) = "rbxassetid://(\d+)"', s) if k != "id"}


def sheet_ids(path):
    s = open(path).read()
    return {k: "rbxassetid://" + v for k, v in re.findall(r'(\w+) = \{ id = "rbxassetid://(\d+)"', s)}


def sheet_ids_in(path, block):
    """Os ids `chave = { id = "rbxassetid://..."` dentro do bloco que começa em `block` (até a chave
    que o fecha)."""
    s = open(path).read()
    a = s.index(block)
    depth, i = 0, a + len(block) - 1
    while True:
        if s[i] == "{":
            depth += 1
        elif s[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return {k: "rbxassetid://" + v for k, v in re.findall(r'(\w+) = \{ id = "rbxassetid://(\d+)"', s[a:i])}


# As figuras do ataque (assets/ataque/<item>.png): vistas de cima, com a CABEÇA PARA A ESQUERDA e fundo
# transparente. O jogo gira a figura na direção do voo. Qualquer tamanho serve: aqui ela é recortada
# no contorno e reduzida para ATTACK_H de altura.
ATTACKS = ("airfield",)
ATTACK_ID = "rbxasset://own/attack_%s"
ATTACK_H = 288


def attack_image(k):
    im = Image.open(A("assets", "ataque", k + ".png")).convert("RGBA")
    box = im.split()[3].point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        raise SystemExit("assets/ataque/%s.png está vazia (sem nada opaco)" % k)
    im = im.crop(box)
    if im.height > ATTACK_H:
        w = max(1, round(im.width * ATTACK_H / im.height))
        # (cores multiplicadas pelo alfa na redução: sem borda escura no contorno)
        im = im.convert("RGBa").resize((w, ATTACK_H), Image.LANCZOS).convert("RGBA")
    return im


def write_attack_size(path, k, im):
    """Assets/ArsenalArt.attack.<k>: a largura e a altura da figura, que as telas usam."""
    s = open(path).read()
    pat = r'(%s = \{ id = "%s", w = )\d+(, h = )\d+( \})' % (k, re.escape(ATTACK_ID % k))
    out, n = re.subn(pat, lambda m: "%s%d%s%d%s" % (m.group(1), im.width, m.group(2), im.height, m.group(3)), s)
    if n != 1:
        raise SystemExit("Assets/ArsenalArt.luau: não achei attack.%s" % k)
    if out != s:
        open(path, "w").write(out)


def build():
    images = {}  # key -> PIL RGBA
    masks = set()  # keys whose image is a white mask (alpha only)
    replaces = {}  # RoWorld's asset id -> key

    def add(key, im, old, is_mask):
        images[key] = im
        if is_mask:
            masks.add(key)
        if old in replaces and replaces[old] != key:
            raise SystemExit("two images for %s: %s, %s" % (old, replaces[old], key))
        replaces[old] = key

    assets = A("src", "shared", "Assets")
    # interface icons
    for k, old in sorted(ids_of(os.path.join(assets, "UiIcons.luau")).items()):
        if k == "app_icon":
            add("logo", logo(), old, False)
            continue
        base = k[4:] if k.startswith("hud_") else k
        box = box_of("icons/" + k, (12, 12, 116, 116))
        add("icons/" + k, white(fit(mask(base), box, 128)), old, True)
    for k, old in sorted(ids_of(os.path.join(assets, "ArsenalArt.luau"), "ui = {").items()):
        box = box_of("arsenal/" + k, (12, 12, 116, 116))
        add("arsenal/" + k, white(fit(mask(k), box, 128)), old, True)
    for k, old in sorted(ids_of(os.path.join(assets, "MapSprites.luau"), "ui = {").items()):
        box = box_of("map/" + k, (12, 12, 116, 116))
        add("map/" + k, white(fit(mask(k), box, 128)), old, True)
    crate = ids_of(os.path.join(assets, "CrateArt.luau"))
    add("crate/icon", white(fit(mask("crate"), (10, 10, 118, 118), 128)), crate["icon"], True)
    # the map's sheets
    sh = sheet_ids(os.path.join(assets, "MapSprites.luau"))
    two, one = sheet_plates()
    add("sheet/glyphs", sheet_glyphs(), sh["icons"], True)
    add("sheet/plates", two, sh["shapes"], False)
    add("sheet/plates_one", one, sh["shapes_one"], False)
    u2, u1 = sheet_units()
    add("sheet/units", u2, sh["units"], True)
    add("sheet/units_one", u1, sh["units_one"], False)
    add("sheet/status", sheet_status(), sh["status"], False)
    # the logo (Assets/Branding is the same image as UiIcons.app_icon) and the world's picture
    for _k, old in ids_of(os.path.join(assets, "Branding.luau")).items():
        replaces.setdefault(old, "logo")
    thumbs = ids_of(os.path.join(assets, "MapThumbs.luau"))
    if "world" in thumbs:
        # the world's picture for the map cards, drawn from the map itself (tools/arte/miniatura_do_mapa)
        import miniatura_do_mapa as T  # noqa: E402,PLC0415

        _w, _h, tiles = T.read_terrain("World")
        add("thumb/world", T.render(tiles).convert("RGBA"), thumbs["world"], False)
        # the other own maps (tools/maps/own_maps.py): their pictures' "ids" are only names
        # (Assets/MapThumbs: rbxasset://own/thumb/<id>), half the size (the cards show them small)
        own = re.findall(r'(\w+) = "rbxasset://own/thumb/\w+"', open(os.path.join(assets, "MapThumbs.luau")).read())
        for mid in own:
            module = mid.capitalize()
            _w, _h, t2 = T.read_terrain(module)
            im2 = T.render(t2).convert("RGBA")
            add("thumb/" + mid, im2.resize((im2.width // 2, im2.height // 2), Image.LANCZOS), "rbxasset://own/thumb/" + mid, False)

    # --- os efeitos (tools/arte/efeitos.py): prévias do Arsenal, mapa, estrada, luzes do baú ---
    import efeitos as E  # noqa: E402,PLC0415

    fx_ids = sheet_ids(os.path.join(assets, "ArsenalFx.luau"))
    for k, im in sorted(E.fx().items()):
        add("fx/" + k, im, fx_ids[k], k in E.FX_MASKS)
    map_fx = re.search(r'id = "(rbxassetid://\d+)"', open(os.path.join(assets, "MapFx.luau")).read()).group(1)
    add("fx/map", E.map_fx(), map_fx, False)
    rails = ids_of(os.path.join(assets, "RailArt.luau"))
    for k, im in sorted(E.roads().items()):
        add("map/road_" + k, im, rails[k], True)
    for k, im in sorted(E.chest().items()):
        add("chest/" + k, im, crate[k], True)
    # --- as figuras do Arsenal (assets/arsenal-icons) onde as telas pedem os "renders" ---
    renders = sheet_ids_in(os.path.join(assets, "ArsenalArt.luau"), "renders = {")
    for k, old in sorted(renders.items()):
        add("render/" + k, Image.open(A("assets", "arsenal-icons", k + ".png")).convert("RGBA"), old, False)
    # --- as figuras que voam no ataque (assets/ataque): o Ataque de Dragões visto de cima, na prévia
    # do Arsenal e na partida. Não tomam o lugar de imagem nenhuma do RoWorld: o "id" é só um nome ---
    for k in sorted(ATTACKS):
        im = attack_image(k)
        add("attack/" + k, im, ATTACK_ID % k, False)
        write_attack_size(os.path.join(assets, "ArsenalArt.luau"), k, im)
    # --- o chão das prévias do Arsenal: pedaços do mapa deste jogo ---
    import mapas_do_arsenal as AM  # noqa: E402,PLC0415

    amap = re.search(r'id = "(rbxassetid://\d+)"', open(os.path.join(assets, "ArsenalMaps.luau")).read()).group(1)
    add("fx/arsenal_maps", AM.atlas().convert("RGBA"), amap, False)
    # --- os cosméticos próprios: estandartes, pets e o fundo do lobby (cosmeticos.py). Não tomam o
    # lugar de imagem nenhuma do RoWorld: o "id" de cada um é só um nome (rbxasset://own/...) ---
    import cosmeticos as CO  # noqa: E402,PLC0415

    flags, flag_cells = CO.flags_atlas()
    pets, pet_cells = CO.pets_atlas()
    add("flags/atlas", flags, CO.FLAGS_ID, False)
    add("pets/atlas", pets, CO.PETS_ID, False)
    add("lobby/bg", CO.lobby_bg(), CO.LOBBY_ID, False)
    CO.write_lists(flag_cells, pet_cells)
    # --- as formas da interface (formas.py): sombras, anel de carregando, fatias do menu circular,
    # brilhos e a ponta da seta. As mesmas medidas das do RoWorld, feitas aqui ---
    import formas as FO  # noqa: E402,PLC0415

    for k, (im, is_mask, old) in sorted(FO.shapes().items()):
        add(k, im, old, is_mask)
    # --- as insígnias do Rank Semanal (insignias.py). Não tomam o lugar de imagem nenhuma: o "id"
    # de cada uma é só um nome (Data/RankPrizes.BADGE_IMAGES) ---
    import insignias as IN  # noqa: E402,PLC0415

    for n, im in sorted(IN.badges().items()):
        add("badge/%d" % n, im, "rbxasset://own/badge/%d" % n, False)
    return images, masks, replaces


COLORS = 96
# (as folhas com muitas cores diferentes pedem a paleta inteira)
MORE_COLORS = {"flags/atlas": 255, "pets/atlas": 255, "attack/airfield": 255, "badge/1": 255, "badge/2": 255, "badge/3": 255}


def encode(im, is_mask, colors=COLORS):
    """-> (mode, colours, base64). Masks: their alpha. Colour images: a palette of up to COLORS
    colours (4 bytes each) and then one byte a pixel."""
    im = im.convert("RGBA")
    if is_mask:
        raw, mode, n = np.asarray(im)[..., 3].tobytes(), "a", 0
    else:
        arr = np.asarray(im)
        uniq, inv = np.unique(arr.reshape(-1, 4), axis=0, return_inverse=True)
        if len(uniq) <= 256:
            # poucas cores (pixel art): a paleta exata, sem aproximar nada
            n = len(uniq)
            raw, mode = uniq.astype(np.uint8).tobytes() + inv.astype(np.uint8).tobytes(), "pal"
        else:
            q = im.quantize(colors=colors, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
            pal = q.getpalette("RGBA")
            idx = np.asarray(q, dtype=np.uint8)
            n = int(idx.max()) + 1
            raw, mode = bytes(pal[: n * 4]) + idx.tobytes(), "pal"
    return mode, n, base64.b64encode(zstandard.ZstdCompressor(level=19).compress(raw)).decode()


def main():
    images, masks, replaces = build()
    os.makedirs(OUT_PNG, exist_ok=True)
    lines = [
        "-- GENERATED by tools/arte/make_own_art.py. Do not edit.",
        "-- This game's own icons, kept in the code (see Assets/OwnArt).",
        "-- replaces: RoWorld's asset id -> the key of the image drawn in its place.",
        '-- images: key -> { w, h, mode, colors, data }; data = base64(zstd(bytes)), rows from the top.',
        '-- mode "a": one byte a pixel, the alpha of a white image. mode "pal": `colors` x 4 bytes of palette',
        "-- (R, G, B, A), then one byte a pixel (its colour's index).",
        "return {",
        "\treplaces = {",
    ]
    for old, key in sorted(replaces.items(), key=lambda kv: (kv[1], kv[0])):
        lines.append('\t\t["%s"] = "%s",' % (old, key))
    lines += ["\t},", "\timages = {"]
    total = 0
    for key in sorted(images):
        im = images[key]
        im.save(os.path.join(OUT_PNG, key.replace("/", "_") + ".png"))
        mode, n, data = encode(im, key in masks, MORE_COLORS.get(key, COLORS))
        total += len(data)
        lines.append('\t\t["%s"] = { w = %d, h = %d, mode = "%s", colors = %d, data = "%s" },' % (key, im.width, im.height, mode, n, data))
    lines += ["\t},", "}", ""]
    open(A("src", "shared", "Assets", "OwnArtData.luau"), "w").write("\n".join(lines))
    ids = A("src", "shared", "Assets", "OwnArtIds.luau")
    # (os ids que o dono já colocou ficam; as imagens novas entram com "")
    have = dict(re.findall(r'\["([^"]+)"\] = "([^"]*)"', open(ids).read())) if os.path.isfile(ids) else {}
    out = [
        "-- OPCIONAL: os ícones deste jogo enviados para a SUA conta do Roblox.",
        "--",
        "-- O jogo já desenha os próprios ícones sozinho (Assets/OwnArt), sem nada enviado. Se preferir usar",
        "-- imagens do Roblox (carregam como qualquer outra imagem), envie os PNG de assets/icones pelo",
        "-- Studio (Gerenciador de recursos > Importar em massa) e coloque aqui o id de cada um, por exemplo:",
        '--     ["icons/attack"] = "rbxassetid://1234567890",      (arquivo assets/icones/icons_attack.png)',
        "-- Uma linha vazia (\"\") continua desenhada pelo jogo.",
        "return {",
    ]
    out += ['\t["%s"] = "%s",' % (k, have.get(k, "")) for k in sorted(images)]
    out += ["}", ""]
    open(ids, "w").write("\n".join(out))
    print("%d imagens, %d ids substituídos, %d KB de dados" % (len(images), len(replaces), total // 1024))
    return images


if __name__ == "__main__":
    main()
