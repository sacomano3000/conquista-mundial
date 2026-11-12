#!/usr/bin/env python3
"""Os cosméticos próprios do jogo: os estandartes (bandeiras), os pets e o fundo do lobby.

  estandartes  desenhados aqui em código (heráldica: campo, divisão, figura), 114 x 76 cada, numa
               folha só. As quatro raridades têm um jeito: comum = só o campo; raro = uma figura;
               épico = borda, figura contornada e estrelas; lendário = campo escuro, raios, borda dupla
               e a cabeça colorida de uma criatura.
  pets         as cabeças de assets/gerados/pet_<nome>.png, recortadas do fundo; algumas ganham uma
               segunda pelagem (recolorida aqui).
  fundo        assets/gerados/fundo_lobby.png, reduzido.
  temporadas   os itens do PASSE (Data/Missions): para cada mês do ano uma skin, um estandarte e um pet
               que só o passe daquele mês dá (SEASONS, mais abaixo). Os pets e os estandartes entram
               nas mesmas folhas, depois dos da Coleção; a lista sai em Assets/Seasons.luau.

make_own_art.py chama este arquivo: as imagens entram em Assets/OwnArtData (o jogo as desenha sozinho)
e as listas saem em src/shared/Assets/Flags.luau e Pets.luau. Para mudar um nome ou uma raridade, mude
aqui e rode  python3 tools/arte/make_own_art.py.
"""
import colorsys, os
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
A = lambda *p: os.path.join(ROOT, *p)  # noqa: E731

# Os "endereços" destas imagens no jogo. Não são imagens do Roblox: são só nomes, que client/UI/ArtSweep
# troca pelo desenho guardado no código (ou pelo id que o dono puser em Assets/OwnArtIds).
FLAGS_ID = "rbxasset://own/flags"
PETS_ID = "rbxasset://own/pets"
LOBBY_ID = "rbxasset://own/lobby"

# ---------------------------------------------------------------------------------------------
# pets
# ---------------------------------------------------------------------------------------------
PET = 96  # lado de cada pet na folha
PET_COLS = 5

# (id, nome, raridade, arquivo, recolorir)
#   recolorir: None | ("hue", graus) | ("mono", brilho, contraste, (r, g, b) da tinta)
PETS = [
    ("gato", "Gato Malhado", "common", "gato", None),
    ("gato_preto", "Gato Preto", "common", "gato", ("mono", 0.5, 1.1, (0.82, 0.84, 1.0), True)),
    ("coruja", "Coruja Parda", "common", "coruja", None),
    ("corvo", "Corvo", "common", "corvo", None),
    ("raposa", "Raposa Ruiva", "common", "raposa", None),
    ("lobo", "Lobo Cinzento", "rare", "lobo", None),
    ("lobo_negro", "Lobo Negro", "rare", "lobo", ("mono", 0.72, 1.2, (0.86, 0.84, 1.0), True)),
    ("falcao", "Falcão Peregrino", "rare", "falcao", None),
    ("coruja_neves", "Coruja das Neves", "rare", "coruja", ("mono", 1.5, 0.8, (0.95, 0.98, 1.0))),
    ("raposa_artica", "Raposa do Ártico", "rare", "raposa", ("mono", 1.55, 0.8, (0.92, 0.97, 1.0))),
    ("grifo", "Grifo Dourado", "epic", "grifo", None),
    ("unicornio", "Unicórnio", "epic", "unicornio", None),
    ("grifo_sombrio", "Grifo Sombrio", "epic", "grifo", ("hue", 205)),
    ("dragao", "Dragão Rubro", "legendary", "dragao", None),
    ("dragao_gelo", "Dragão de Gelo", "legendary", "dragao", ("hue", 200)),
    # --- 12/11/2026: mais nove, outras pelagens das mesmas cabeças. SEMPRE no fim da lista: o id é o
    # que fica salvo no jogador, e a ordem só decide o lugar na folha.
    ("gato_branco", "Gato Branco", "common", "gato", ("mono", 1.5, 0.85, (1.0, 0.98, 0.94))),
    ("raposa_cinzenta", "Raposa Cinzenta", "common", "raposa", ("mono", 0.95, 1.05, (0.84, 0.87, 0.94))),
    ("coruja_cinzenta", "Coruja Cinzenta", "common", "coruja", ("mono", 0.98, 1.05, (0.82, 0.86, 0.92))),
    ("lobo_branco", "Lobo Branco", "rare", "lobo", ("mono", 1.6, 0.8, (0.96, 0.98, 1.0))),
    ("falcao_dourado", "Falcão Dourado", "rare", "falcao", ("mono", 1.3, 1.0, (1.0, 0.82, 0.42))),
    ("corvo_branco", "Corvo Branco", "rare", "corvo", ("mono", 2.3, 0.75, (0.97, 0.97, 1.0))),
    ("unicornio_sombrio", "Unicórnio Sombrio", "epic", "unicornio", ("mono", 0.5, 1.15, (0.78, 0.74, 1.0), True)),
    ("grifo_esmeralda", "Grifo Esmeralda", "epic", "grifo", ("hue", 140)),
    ("dragao_esmeralda", "Dragão Esmeralda", "legendary", "dragao", ("hue", 128)),
]

_cut = {}


def cutout(name):
    """A cabeça de assets/gerados/pet_<name>.png sem o fundo: tudo o que se alcança a partir das bordas
    andando por pixels da cor do fundo (o contorno escuro do desenho segura a tinta)."""
    if name in _cut:
        return _cut[name]
    im = Image.open(A("assets", "gerados", "pet_%s.png" % name)).convert("RGB").resize((384, 384), Image.LANCZOS)
    a = np.asarray(im, dtype=np.int32)
    h, w, _ = a.shape
    seen = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        q.append((0, x)); q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0)); q.append((y, w - 1))
    for y, x in q:
        seen[y, x] = True
    tol = 34
    while q:
        y, x = q.popleft()
        c = a[y, x]
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and not seen[ny, nx]:
                d = a[ny, nx] - c
                # (vizinho parecido com este e ainda "azulado" como o fundo)
                n = a[ny, nx]
                if abs(d).sum() < tol and n[2] >= n[0] - 6 and max(n) - min(n) < 70 and 40 < n.sum() < 480:
                    seen[ny, nx] = True
                    q.append((ny, nx))
    alpha = Image.fromarray(np.where(seen, 0, 255).astype(np.uint8), "L")
    # (some o serrilhado e um fio do fundo)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    bb = alpha.point(lambda v: 255 if v > 40 else 0).getbbox()
    out = out.crop(bb)
    _cut[name] = out
    return out


def recolor(im, how):
    if how is None:
        return im
    a = np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0
    rgb, al = a[..., :3], a[..., 3:]
    if how[0] == "hue":
        hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("HSV"), dtype=np.float32)
        # só a pelagem / as escamas (o que é bem colorido e não é amarelo: bico, chifres e olhos ficam)
        hue = hsv[..., 0] * 360.0 / 255.0
        sat = hsv[..., 1] / 255.0
        keep = (sat < 0.25) | ((hue > 38) & (hue < 70))
        target = how[1]
        base = float(np.median(hue[(~keep) & (al[..., 0] > 0.5)])) if ((~keep) & (al[..., 0] > 0.5)).any() else 0.0
        nh = (hue + (target - base)) % 360.0
        hsv[..., 0] = np.where(keep, hsv[..., 0], nh * 255.0 / 360.0)
        rgb = np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB"), dtype=np.float32) / 255.0
    else:
        gain, contrast, tint = how[1], how[2], how[3]
        hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("HSV"), dtype=np.float32)
        hue = hsv[..., 0] * 360.0 / 255.0
        sat = hsv[..., 1] / 255.0
        lum = rgb.mean(axis=2, keepdims=True)
        lum = np.clip((lum - 0.5) * contrast + 0.5, 0, 1)
        mono = np.clip(lum * gain, 0, 1) * np.array(tint, dtype=np.float32)
        # os olhos (verde / âmbar bem saturado) e o focinho rosado ficam como são
        eyes = ((sat > 0.62) & (((hue > 70) & (hue < 170)) | ((hue > 36) & (hue < 56)))) & (rgb.max(axis=2) > 0.55)
        dark = lum[..., 0] < 0.16  # o contorno continua escuro
        rgb = np.where(eyes[..., None] | dark[..., None], rgb, mono)
    out = Image.fromarray((np.concatenate([rgb, al], axis=2) * 255).astype(np.uint8), "RGBA")
    if how[0] == "mono" and len(how) > 4 and how[4]:
        # pelagem escura: um fio claro em volta, para não sumir num fundo escuro
        a8 = out.getchannel("A")
        rim = a8.filter(ImageFilter.MaxFilter(7))
        back = Image.new("RGBA", out.size, (176, 180, 204, 0))
        back.putalpha(rim)
        back.alpha_composite(out)
        out = back
    return out


def fit_square(im, side, pad=3):
    s = min((side - 2 * pad) / im.width, (side - 2 * pad) / im.height)
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    out = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    out.alpha_composite(im.resize((w, h), Image.LANCZOS), ((side - w) // 2, (side - h) // 2))
    return out


def pet_image(pid, side=PET):
    for p in PETS:
        if p[0] == pid:
            return fit_square(recolor(cutout(p[3]), p[4]), side)
    raise KeyError(pid)


def pets_atlas():
    rows = (len(PETS) + PET_COLS - 1) // PET_COLS
    more = (len(SEASONS) + PET_COLS - 1) // PET_COLS
    sheet = Image.new("RGBA", (PET_COLS * PET, (rows + more) * PET), (0, 0, 0, 0))
    cells = []
    for i, p in enumerate(PETS):
        x, y = (i % PET_COLS) * PET, (i // PET_COLS) * PET
        sheet.alpha_composite(pet_image(p[0]), (x, y))
        cells.append((p[0], p[1], p[2], x, y, PET, PET))
    # (os pets das temporadas: em linhas próprias, depois dos da Coleção; não entram na lista dela)
    for i, se in enumerate(SEASONS):
        x, y = (i % PET_COLS) * PET, (rows + i // PET_COLS) * PET
        sheet.alpha_composite(season_pet(se), (x, y))
        _season_cells["pet"][se[1]] = (x, y)
    return sheet, cells


# ---------------------------------------------------------------------------------------------
# estandartes
# ---------------------------------------------------------------------------------------------
FW, FH = 114, 76
CELL_W, CELL_H = 120, 80
FLAG_COLS = 8
SS = 4  # desenhado 4x maior e reduzido (bordas lisas)

T = {
    "rubro": (176, 32, 38),
    "azul": (30, 72, 150),
    "verde": (36, 112, 62),
    "negro": (28, 28, 34),
    "roxo": (104, 48, 140),
    "ouro": (226, 178, 52),
    "prata": (228, 228, 232),
    "laranja": (204, 104, 34),
    "vinho": (112, 26, 52),
    "ceu": (96, 160, 214),
}
NOME = {
    "rubro": ("Rubro", "Rubra"), "azul": ("Azul", "Azul"), "verde": ("Verde", "Verde"),
    "negro": ("Negro", "Negra"), "roxo": ("Roxo", "Roxa"), "ouro": ("de Ouro", "de Ouro"),
    "prata": ("de Prata", "de Prata"), "laranja": ("Laranja", "Laranja"), "vinho": ("Vinho", "Vinho"),
    "ceu": ("Celeste", "Celeste"),
}


def _canvas(c):
    return Image.new("RGB", (FW * SS, FH * SS), T[c])


def field(kind, a, b):
    """O campo: a divisão `kind` nas cores a (fundo) e b."""
    im = _canvas(a)
    d = ImageDraw.Draw(im)
    W, H = im.size
    cb = T[b]
    if kind == "liso":
        pass
    elif kind == "partido":  # metades lado a lado
        d.rectangle([W // 2, 0, W, H], fill=cb)
    elif kind == "cortado":  # metades em cima e embaixo
        d.rectangle([0, H // 2, W, H], fill=cb)
    elif kind == "fendido":  # diagonal
        d.polygon([(0, 0), (W, 0), (0, H)], fill=cb)
    elif kind == "esquartelado":
        d.rectangle([W // 2, 0, W, H // 2], fill=cb)
        d.rectangle([0, H // 2, W // 2, H], fill=cb)
    elif kind == "faixa":  # uma faixa deitada
        d.rectangle([0, H * 0.34, W, H * 0.66], fill=cb)
    elif kind == "pala":  # uma faixa em pé
        d.rectangle([W * 0.38, 0, W * 0.62, H], fill=cb)
    elif kind == "cruz":
        d.rectangle([W * 0.42, 0, W * 0.58, H], fill=cb)
        d.rectangle([0, H * 0.38, W, H * 0.62], fill=cb)
    elif kind == "aspa":  # cruz em X
        t = H * 0.16
        d.polygon([(0, 0), (t * 1.4, 0), (W, H - t), (W, H), (W - t * 1.4, H), (0, t)], fill=cb)
        d.polygon([(W, 0), (W, t), (t * 1.4, H), (0, H), (0, H - t), (W - t * 1.4, 0)], fill=cb)
    elif kind == "banda":  # uma faixa na diagonal
        t = H * 0.24
        d.polygon([(0, 0), (t * 1.5, 0), (W, H - t), (W, H), (W - t * 1.5, H), (0, t)], fill=cb)
    elif kind == "asna":  # um V invertido
        t = H * 0.26
        d.polygon([(0, H), (W / 2, H * 0.18), (W, H), (W, H - 0), (W - t * 1.5, H), (W / 2, H * 0.18 + t), (t * 1.5, H)], fill=cb)
    elif kind == "barras":  # listras deitadas
        n = 6
        for i in range(1, n, 2):
            d.rectangle([0, H * i / n, W, H * (i + 1) / n], fill=cb)
    elif kind == "palas":  # listras em pé
        n = 6
        for i in range(1, n, 2):
            d.rectangle([W * i / n, 0, W * (i + 1) / n, H], fill=cb)
    elif kind == "xadrez":
        nx, ny = 6, 4
        for i in range(nx):
            for j in range(ny):
                if (i + j) % 2:
                    d.rectangle([W * i / nx, H * j / ny, W * (i + 1) / nx, H * (j + 1) / ny], fill=cb)
    elif kind == "chefe":  # uma faixa no alto
        d.rectangle([0, 0, W, H * 0.3], fill=cb)
    elif kind == "bordadura":
        t = H * 0.13
        d.rectangle([0, 0, W, H], fill=cb)
        d.rectangle([t, t, W - t, H - t], fill=T[a])
    elif kind == "losango":
        d.polygon([(W / 2, H * 0.08), (W * 0.9, H / 2), (W / 2, H * 0.92), (W * 0.1, H / 2)], fill=cb)
    elif kind == "terciado":  # três partes em pé; a do meio em b
        d.rectangle([W / 3, 0, W * 2 / 3, H], fill=cb)
    elif kind == "raios":
        import math
        cx, cy = W * 0.45, H / 2
        n = 16
        for i in range(0, n, 2):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            d.polygon([(cx, cy), (cx + W * math.cos(a0), cy + W * math.sin(a0)), (cx + W * math.cos(a1), cy + W * math.sin(a1))], fill=cb)
    else:
        raise KeyError(kind)
    return im


_masks = {}


def charge_mask(name):
    """A silhueta de uma figura: um ícone do jogo (make_own_art.mask) ou a cabeça de um pet."""
    if name not in _masks:
        if name.startswith("pet:"):
            m = cutout(name[4:]).getchannel("A")
        else:
            import make_own_art as M  # noqa: PLC0415

            m = M.mask(name)
        _masks[name] = m.crop(m.getbbox())
    return _masks[name]


def put_mask(im, m, color, box, outline=None, ow=0):
    """Pinta a máscara `m` em `color` dentro de box = (cx, cy, w, h), em frações do estandarte."""
    W, H = im.size
    cx, cy, bw, bh = box[0] * W, box[1] * H, box[2] * W, box[3] * H
    s = min(bw / m.width, bh / m.height)
    w, h = max(1, round(m.width * s)), max(1, round(m.height * s))
    r = m.resize((w, h), Image.LANCZOS)
    x, y = round(cx - w / 2), round(cy - h / 2)
    if outline is not None and ow > 0:
        big = Image.new("L", im.size, 0)
        big.paste(r, (x, y))
        big = big.filter(ImageFilter.MaxFilter(ow * 2 + 1))
        im.paste(Image.new("RGB", im.size, outline), (0, 0), big)
    im.paste(Image.new("RGB", (w, h), color), (x, y), r)


TAIL = 0.13  # o corte em V na ponta (a "cauda de andorinha" dos estandartes)


def finish(im, frame=(18, 18, 22)):
    """Corta a ponta em V, põe um fio escuro em volta, reduz e dá um leve sombreado de pano."""
    W, H = im.size
    d = ImageDraw.Draw(im)
    t = SS
    shape = [(0, 0), (W - 1, 0), (W - 1 - W * TAIL, H / 2), (W - 1, H - 1), (0, H - 1)]
    d.line(shape + [shape[0]], fill=frame, width=t * 2, joint="curve")
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).polygon(shape, fill=255)
    im = im.convert("RGBA")
    im.putalpha(m)
    small = im.resize((FW, FH), Image.LANCZOS)
    # pano: um pouco mais claro no alto, mais escuro embaixo
    sh = np.linspace(1.06, 0.9, FH, dtype=np.float32)[:, None, None]
    a = np.asarray(small, dtype=np.float32)
    a[..., :3] = np.clip(a[..., :3] * sh, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def star_row(im, color, y=0.16, n=3, size=0.11):
    m = charge_mask("star")
    for i in range(n):
        put_mask(im, m, color, (0.45 + (i - (n - 1) / 2) * 0.2, y, size, size * 1.5))


def common(kind, a, b):
    return finish(field(kind, a, b))


def rare(kind, a, b, charge, cc, box=(0.45, 0.5, 0.5, 0.66)):
    im = field(kind, a, b)
    put_mask(im, charge_mask(charge), T[cc], box, outline=(18, 18, 22), ow=2)
    return finish(im)


def epic(kind, a, b, charge, cc, trim="ouro"):
    im = field(kind, a, b)
    W, H = im.size
    d = ImageDraw.Draw(im)
    t = int(H * 0.075)
    shape = [(0, 0), (W - 1, 0), (W - 1 - W * TAIL, H / 2), (W - 1, H - 1), (0, H - 1)]
    d.line(shape + [shape[0]], fill=T[trim], width=t * 2, joint="curve")
    put_mask(im, charge_mask(charge), T[cc], (0.45, 0.57, 0.44, 0.54), outline=(18, 18, 22), ow=3)
    star_row(im, T[trim], y=0.2)
    return finish(im)


def legendary(a, b, pet, how=None, trim="ouro"):
    im = field("raios", a, b)
    W, H = im.size
    d = ImageDraw.Draw(im)
    t = int(H * 0.07)
    shape = [(0, 0), (W - 1, 0), (W - 1 - W * TAIL, H / 2), (W - 1, H - 1), (0, H - 1)]
    d.line(shape + [shape[0]], fill=T[trim], width=t * 2, joint="curve")
    # um disco escuro atrás da cabeça, com aro
    r = H * 0.37
    W = W * 0.9  # (o centro do que se vê: a ponta cortada come a direita)
    d.ellipse([W / 2 - r, H / 2 - r, W / 2 + r, H / 2 + r], fill=(20, 18, 24), outline=T[trim], width=SS * 2)
    head = recolor(cutout(pet), how)
    s = min(r * 1.7 / head.width, r * 1.7 / head.height)
    hw, hh = round(head.width * s), round(head.height * s)
    head = head.resize((hw, hh), Image.LANCZOS)
    im = im.convert("RGBA")
    im.alpha_composite(head, (round(W / 2 - hw / 2), round(H / 2 - hh / 2)))
    return finish(im.convert("RGB"), frame=(92, 66, 14))


def _n(kind_name, a, fem=False):
    return "%s %s" % (kind_name, NOME[a][1 if fem else 0])


def banners():
    """-> [(code, nome, raridade, imagem)]"""
    out = []

    def add(code, name, rarity, im):
        out.append((code, name, rarity, im))

    # --- comuns: só o campo (24) ---
    C = [
        ("partido", "rubro", "ouro", "Partido Rubro e Ouro"),
        ("partido", "azul", "prata", "Partido Azul e Prata"),
        ("partido", "negro", "prata", "Partido Negro e Prata"),
        ("cortado", "negro", "ouro", "Cortado Negro e Ouro"),
        ("cortado", "verde", "ouro", "Cortado Verde e Ouro"),
        ("cortado", "roxo", "prata", "Cortado Roxo e Prata"),
        ("fendido", "roxo", "prata", "Fendido Roxo e Prata"),
        ("fendido", "vinho", "ouro", "Fendido Vinho e Ouro"),
        ("esquartelado", "rubro", "prata", "Esquartelado Rubro"),
        ("esquartelado", "azul", "ouro", "Esquartelado Azul"),
        ("faixa", "azul", "ouro", "Faixa de Ouro"),
        ("faixa", "negro", "rubro", "Faixa Rubra"),
        ("pala", "azul", "prata", "Pala de Prata"),
        ("pala", "verde", "ouro", "Pala de Ouro"),
        ("cruz", "ouro", "rubro", "Cruz Rubra"),
        ("cruz", "verde", "prata", "Cruz de Prata"),
        ("aspa", "rubro", "prata", "Aspa de Prata"),
        ("aspa", "negro", "ouro", "Aspa de Ouro"),
        ("banda", "verde", "prata", "Banda de Prata"),
        ("banda", "vinho", "ouro", "Banda de Ouro"),
        ("barras", "rubro", "ouro", "Barras Rubras"),
        ("palas", "azul", "prata", "Palas Azuis"),
        ("asna", "roxo", "ouro", "Asna de Ouro"),
        ("chefe", "laranja", "negro", "Chefe Negro"),
        # --- 12/11/2026: mais 14. SEMPRE no fim de cada lista: o número (c25, c26...) é o que fica
        # salvo no jogador.
        ("losango", "azul", "ouro", "Losango de Ouro"),
        ("losango", "rubro", "prata", "Losango de Prata"),
        ("terciado", "verde", "prata", "Terciado Verde"),
        ("terciado", "rubro", "ouro", "Terciado Rubro"),
        ("xadrez", "negro", "ouro", "Xadrez Negro e Ouro"),
        ("xadrez", "azul", "prata", "Xadrez Azul e Prata"),
        ("bordadura", "verde", "ouro", "Bordadura de Ouro"),
        ("bordadura", "azul", "prata", "Bordadura de Prata"),
        ("chefe", "azul", "ouro", "Chefe de Ouro"),
        ("asna", "rubro", "prata", "Asna de Prata"),
        ("barras", "verde", "prata", "Barras Verdes"),
        ("palas", "vinho", "ouro", "Palas Vinho"),
        ("fendido", "ceu", "prata", "Fendido Celeste"),
        ("esquartelado", "laranja", "negro", "Esquartelado Laranja"),
    ]
    for i, (k, a, b, name) in enumerate(C):
        add("c%02d" % (i + 1), name, "common", common(k, a, b))
    # --- raros: uma figura (14) ---
    R = [
        ("liso", "rubro", "rubro", "crown", "ouro", "Coroa de Ouro"),
        ("liso", "azul", "azul", "attack", "prata", "Espadas de Prata"),
        ("liso", "verde", "verde", "city", "prata", "Castelo de Prata"),
        ("liso", "negro", "negro", "pet:lobo", "prata", "Lobo de Prata"),
        ("liso", "ouro", "ouro", "pet:corvo", "negro", "Corvo Negro"),
        ("cortado", "azul", "ceu", "warship", "prata", "Drácar de Prata"),
        ("partido", "rubro", "vinho", "defense", "ouro", "Escudo de Ouro"),
        ("liso", "roxo", "roxo", "star", "ouro", "Estrela de Ouro"),
        ("liso", "prata", "prata", "pet:raposa", "laranja", "Raposa Ruiva"),
        ("liso", "vinho", "vinho", "pet:coruja", "ouro", "Coruja de Ouro"),
        ("chefe", "verde", "ouro", "pet:gato", "negro", "Gato Negro"),
        ("liso", "ceu", "ceu", "pet:falcao", "negro", "Falcão Negro"),
        ("bordadura", "negro", "rubro", "skull", "prata", "Caveira de Prata"),
        ("liso", "laranja", "laranja", "artillery", "negro", "Catapulta Negra"),
        # --- 12/11/2026: mais 10
        ("liso", "azul", "azul", "port", "ouro", "Âncora de Ouro"),
        ("liso", "negro", "negro", "factory", "laranja", "Forja do Ferreiro"),
        ("liso", "vinho", "vinho", "silo", "prata", "Torre de Prata"),
        ("cortado", "verde", "negro", "railgun", "ouro", "Balista de Ouro"),
        ("liso", "rubro", "rubro", "airfield", "ouro", "Dragão de Ouro"),
        ("liso", "ceu", "ceu", "boat", "negro", "Barco Negro"),
        ("partido", "azul", "roxo", "troops", "prata", "Elmo de Prata"),
        ("liso", "verde", "verde", "gold", "ouro", "Tesouro de Ouro"),
        ("bordadura", "roxo", "ouro", "hydrogen", "laranja", "Chama Viva"),
        ("liso", "prata", "prata", "betray", "rubro", "Adaga Rubra"),
    ]
    for i, (k, a, b, ch, cc, name) in enumerate(R):
        box = (0.45, 0.62, 0.42, 0.5) if k == "chefe" else (0.45, 0.5, 0.5, 0.66)
        add("r%02d" % (i + 1), name, "rare", rare(k, a, b, ch, cc, box))
    # --- épicos: borda de ouro, figura contornada, três estrelas (7) ---
    E = [
        ("partido", "rubro", "vinho", "pet:grifo", "ouro", "ouro", "Guarda do Grifo"),
        ("cortado", "azul", "negro", "pet:lobo", "prata", "prata", "Matilha da Lua"),
        ("liso", "negro", "negro", "pet:dragao", "rubro", "ouro", "Ordem do Dragão"),
        ("esquartelado", "roxo", "negro", "crown", "ouro", "ouro", "Casa Real"),
        ("fendido", "verde", "negro", "pet:unicornio", "prata", "prata", "Bosque Encantado"),
        ("liso", "azul", "azul", "pet:falcao", "ouro", "ouro", "Falcoeiros do Rei"),
        ("xadrez", "negro", "vinho", "attack", "prata", "prata", "Lâminas Juradas"),
        # --- 12/11/2026: mais 6
        ("partido", "azul", "ceu", "port", "prata", "prata", "Armada Real"),
        ("cortado", "rubro", "negro", "airfield", "ouro", "ouro", "Covil do Dragão"),
        ("liso", "verde", "verde", "wall", "ouro", "ouro", "Guardiões da Muralha"),
        ("fendido", "vinho", "negro", "troops", "prata", "prata", "Legião de Ferro"),
        ("esquartelado", "azul", "negro", "globe", "ouro", "ouro", "Navegantes do Norte"),
        ("liso", "roxo", "roxo", "pet:coruja", "prata", "prata", "Conselho das Corujas"),
    ]
    for i, (k, a, b, ch, cc, trim, name) in enumerate(E):
        add("e%02d" % (i + 1), name, "epic", epic(k, a, b, ch, cc, trim))
    # --- lendários: raios, borda dupla, a cabeça colorida (3) ---
    L = [
        ("negro", "vinho", "dragao", None, "Estandarte do Dragão"),
        ("azul", "negro", "grifo", None, "Estandarte do Grifo"),
        ("roxo", "negro", "unicornio", None, "Estandarte do Unicórnio"),
        # --- 12/11/2026: mais 2
        ("verde", "negro", "lobo", None, "Estandarte do Lobo"),
        ("rubro", "negro", "falcao", None, "Estandarte do Falcão"),
    ]
    for i, (a, b, pet, how, name) in enumerate(L):
        add("l%02d" % (i + 1), name, "legendary", legendary(a, b, pet, how))
    return out


def flags_atlas():
    bs = banners()
    rows = (len(bs) + FLAG_COLS - 1) // FLAG_COLS
    more = (len(SEASONS) + FLAG_COLS - 1) // FLAG_COLS
    sheet = Image.new("RGBA", (FLAG_COLS * CELL_W, (rows + more) * CELL_H), (0, 0, 0, 0))
    cells = []
    for i, (code, name, rarity, im) in enumerate(bs):
        x = (i % FLAG_COLS) * CELL_W + (CELL_W - FW) // 2
        y = (i // FLAG_COLS) * CELL_H + (CELL_H - FH) // 2
        sheet.alpha_composite(im, (x, y))
        cells.append((code, name, rarity, x, y, FW, FH))
    # (os estandartes das temporadas: em linhas próprias, depois dos da Coleção)
    for i, se in enumerate(SEASONS):
        x = (i % FLAG_COLS) * CELL_W + (CELL_W - FW) // 2
        y = (rows + i // FLAG_COLS) * CELL_H + (CELL_H - FH) // 2
        sheet.alpha_composite(season_banner(se), (x, y))
        _season_cells["flag"][se[1]] = (x, y)
    return sheet, cells


# ---------------------------------------------------------------------------------------------
# o fundo do lobby
# ---------------------------------------------------------------------------------------------
LOBBY = (512, 288)


def lobby_bg():
    im = Image.open(A("assets", "gerados", "fundo_lobby.png")).convert("RGB")
    w, h = im.size
    # 16:9 do meio
    th = round(w * 9 / 16)
    if th <= h:
        im = im.crop((0, (h - th) // 2, w, (h - th) // 2 + th))
    else:
        tw = round(h * 16 / 9)
        im = im.crop(((w - tw) // 2, 0, (w - tw) // 2 + tw, h))
    im = im.resize(LOBBY, Image.LANCZOS)
    q = im.quantize(colors=255, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)
    return q.convert("RGBA")


# ---------------------------------------------------------------------------------------------
# as temporadas do PASSE (uma por mês do ano; no ano seguinte o mês repete a sua)
# ---------------------------------------------------------------------------------------------
# mês, chave, nome da temporada, cor (da tela de Missões),
#   pet = (nome, arquivo em assets/gerados/pet_<arquivo>.png, recolorir),
#   estandarte = (nome, cor do campo, cor dos raios, cor da borda),
#   skin = (nome, [cores], [linhas do desenho: '.' = a cor do jogador, '1', '2' = as cores])
SEASONS = [
    (1, "leao", "Sol Dourado", 0xE8B63A,
     ("Leão Solar", "leao", None),
     ("Estandarte do Sol", (150, 84, 20), (226, 178, 52), (250, 222, 120)),
     ("Raios de Sol", [0xF6D25A, 0xE08A1E],
      ["...1....", ".1...1..", "..222...", "1.222.1.", "..222...", ".1...1..", "...1....", "........"])),
    (2, "serpente", "Mares Bravios", 0x2CB8AC,
     ("Serpente Marinha", "serpente", None),
     ("Estandarte das Marés", (18, 50, 92), (26, 120, 128), (140, 226, 214)),
     ("Ondas", [0x2CB8AC, 0x9BE8DE],
      ["........", ".11...11", "1..1.1..", "....1...", "........", ".22...22", "2..2.2..", "....2..."])),
    (3, "cervo", "Floresta Antiga", 0x58A84E,
     ("Cervo Ancestral", "cervo", None),
     ("Estandarte da Floresta", (30, 70, 38), (70, 124, 56), (196, 168, 96)),
     ("Folhagem", [0x3E8E4A, 0x9CD460],
      ["........", "..11....", ".1121...", ".1211...", "..11..2.", ".....22.", "....22..", "........"])),
    (4, "tempestade", "Tempestade", 0x8C7CF0,
     ("Falcão da Tempestade", "falcao", ("mono", 1.05, 1.15, (0.66, 0.74, 1.0))),
     ("Estandarte do Trovão", (36, 30, 84), (84, 70, 170), (242, 217, 74)),
     ("Relâmpagos", [0xF2D94A, 0x8C7CF0],
      ["....11..", "...11...", "..1111..", "....11..", "...11...", "..11..2.", "..1..2..", "........"])),
    (5, "rosas", "Reino das Rosas", 0xE0649A,
     ("Unicórnio Rosado", "unicornio", ("hue", 330)),
     ("Estandarte da Rosa", (104, 24, 56), (176, 48, 100), (246, 184, 208)),
     ("Roseiral", [0xD8588C, 0xF6B8D0],
      ["........", "..11.11.", ".1211111", ".1111111", "..11111.", "...111..", "....1...", "........"])),
    (6, "fogueira", "Noites de Fogueira", 0xE8742A,
     ("Coruja de Fogo", "coruja", ("hue", 12)),
     ("Estandarte da Fogueira", (96, 22, 22), (190, 78, 24), (246, 200, 60)),
     ("Brasas", [0xE0661E, 0xF6C83C],
      ["1.......", "....2...", "..1.....", "......1.", ".2......", "....1...", "1.....2.", "...1...."])),
    (7, "morcego", "Reino das Sombras", 0x8E5CE0,
     ("Morcego Vampiro", "morcego", None),
     ("Estandarte das Sombras", (20, 14, 30), (70, 40, 120), (190, 150, 250)),
     ("Asas da Noite", [0x7C4AD0, 0xE04060],
      ["........", "1......1", "11.11.11", "11111111", ".121121.", "..1..1..", "........", "........"])),
    (8, "areias", "Areias do Deserto", 0xDCB466,
     ("Grifo das Areias", "grifo", ("mono", 1.3, 1.0, (1.0, 0.86, 0.62))),
     ("Estandarte do Deserto", (150, 110, 50), (214, 176, 100), (42, 166, 160)),
     ("Dunas", [0xD8B46A, 0x2AA6A0],
      ["........", "...11...", ".11..11.", "1......1", "........", "...22...", ".22..22.", "2......2"])),
    (9, "cristais", "Cavernas de Cristal", 0xB060E8,
     ("Dragão de Ametista", "dragao", ("hue", 285)),
     ("Estandarte de Cristal", (44, 22, 78), (120, 60, 170), (110, 220, 236)),
     ("Cristais", [0xA050D8, 0x60D8E8],
      ["...1....", "..121...", ".12221..", "..121...", "...1..2.", ".....222", "......2.", "........"])),
    (10, "bruxas", "Noite das Bruxas", 0xF0842A,
     ("Gato Fantasma", "gato", ("mono", 1.25, 1.1, (0.62, 1.0, 0.72))),
     ("Estandarte da Abóbora", (30, 16, 44), (84, 38, 124), (240, 132, 42)),
     ("Teias", [0xE87A1E, 0x7A48B0],
      ["1..1..1.", ".1.1.1..", "..121...", "1121211.", "..121...", ".1.1.1..", "1..1..1.", "........"])),
    (11, "fenix", "Cinzas da Fênix", 0xF07A2A,
     ("Fênix", "fenix", None),
     ("Estandarte da Fênix", (58, 16, 16), (160, 40, 24), (246, 190, 60)),
     ("Chamas", [0xF06A1E, 0xF6C83C],
      ["...1....", "..11....", "..121...", ".1221.1.", ".12221..", ".12221..", "..121...", "........"])),
    (12, "urso", "Noite de Gelo", 0x9CD4F0,
     ("Urso Polar", "urso", None),
     ("Estandarte do Gelo", (20, 40, 84), (48, 96, 160), (214, 238, 250)),
     ("Flocos de Neve", [0xFFFFFF, 0x9CD4F0],
      ["...1....", ".1.1.1..", "..121...", "1122211.", "..121...", ".1.1.1..", "...1....", "........"])),
]
SEASON_ALPHA = 205  # o quanto as cores de uma skin de temporada cobrem a cor do jogador (0..255)


def season_pet(se, side=PET):
    _name, arquivo, how = se[4]
    return fit_square(recolor(cutout(arquivo), how), side)


def season_banner(se):
    """O estandarte da temporada: campo de raios nas cores dela, borda dupla e a cabeça do pet dela."""
    _name, a, b, trim = se[5]
    ka, kb, kt = "_t%02d_a" % se[0], "_t%02d_b" % se[0], "_t%02d_t" % se[0]
    T[ka], T[kb], T[kt] = a, b, trim
    im = field("raios", ka, kb)
    W, H = im.size
    d = ImageDraw.Draw(im)
    shape = [(0, 0), (W - 1, 0), (W - 1 - W * TAIL, H / 2), (W - 1, H - 1), (0, H - 1)]
    d.line(shape + [shape[0]], fill=trim, width=int(H * 0.07) * 2, joint="curve")
    d.line(shape + [shape[0]], fill=tuple(int(c * 0.45) for c in trim), width=int(H * 0.022) * 2, joint="curve")
    r = H * 0.38
    cw = W * 0.9
    d.ellipse([cw / 2 - r, H / 2 - r, cw / 2 + r, H / 2 + r], fill=tuple(int(c * 0.35) for c in a), outline=trim, width=SS * 2)
    head = recolor(cutout(se[4][1]), se[4][2])
    k = min(r * 1.72 / head.width, r * 1.72 / head.height)
    hw, hh = round(head.width * k), round(head.height * k)
    head = head.resize((hw, hh), Image.LANCZOS)
    im = im.convert("RGBA")
    im.alpha_composite(head, (round(cw / 2 - hw / 2), round(H / 2 - hh / 2)))
    return finish(im.convert("RGB"), frame=tuple(int(c * 0.4) for c in trim))


_season_cells = {"flag": {}, "pet": {}}


def write_seasons():
    """Assets/Seasons.luau: os itens de cada temporada (flags_atlas e pets_atlas já rodaram)."""
    q = lambda t: t.replace("\\", "\\\\").replace('"', '\\"')  # noqa: E731
    lines = [
        "-- GENERATED by tools/arte/cosmeticos.py (run tools/arte/make_own_art.py). Do not edit by hand.",
        "-- The PASS's seasons (Data/Missions): one for each month of the year, each with a skin, a flag and",
        "-- a pet only that month's pass gives (Data/Cosmetics makes the items: \"skin_passe_<key>\",",
        "-- \"flag_passe_<key>\", \"pet_passe_<key>\"). The flag and the pet are rects of the game's own flag and",
        "-- pet atlases (Assets/OwnArt); the skin is a pattern in its own colours ('.' = the player's colour).",
        "return {",
        '\tflags = "%s",' % FLAGS_ID,
        '\tpets = "%s",' % PETS_ID,
        "\tseasons = {",
    ]
    for se in SEASONS:
        month, key, name, color = se[0], se[1], se[2], se[3]
        fx, fy = _season_cells["flag"][key]
        px, py = _season_cells["pet"][key]
        sk = se[6]
        lines += [
            "\t\t{",
            '\t\t\tmonth = %d,' % month,
            '\t\t\tkey = "%s",' % key,
            '\t\t\tname = "%s",' % q(name),
            "\t\t\tcolor = 0x%06X," % color,
            '\t\t\tskin = { name = "%s", scale = 1, alpha = %d, colors = { %s }, mask = { %s } },'
            % (q(sk[0]), SEASON_ALPHA, ", ".join("0x%06X" % c for c in sk[1]), ", ".join('"%s"' % r for r in sk[2])),
            '\t\t\tflag = { name = "%s", x = %d, y = %d, w = %d, h = %d },' % (q(se[5][0]), fx, fy, FW, FH),
            '\t\t\tpet = { name = "%s", x = %d, y = %d, w = %d, h = %d },' % (q(se[4][0]), px, py, PET, PET),
            "\t\t},",
        ]
    lines += ["\t},", "}", ""]
    open(A("src", "shared", "Assets", "Seasons.luau"), "w").write("\n".join(lines))


# ---------------------------------------------------------------------------------------------
# as listas em Luau
# ---------------------------------------------------------------------------------------------
def write_lists(flag_cells, pet_cells):
    lines = [
        "-- GENERATED by tools/arte/cosmeticos.py (run tools/arte/make_own_art.py). Do not edit by hand.",
        "-- This game's own flags: medieval banners drawn by the game itself (Assets/OwnArt: the atlas is",
        "-- not a Roblox image; client/UI/ArtSweep draws it). Each flag's pixel rect in the atlas",
        "-- (ImageRectOffset = x, y; ImageRectSize = w, h) and its rarity. Data/MyFlags adds the owner's.",
        "return {",
        '\tatlases = { "%s" },' % FLAGS_ID,
        "\tflags = {",
    ]
    for code, name, rarity, x, y, w, h in flag_cells:
        lines.append('\t\t{ code = "%s", name = "%s", rarity = "%s", atlas = 1, x = %d, y = %d, w = %d, h = %d },' % (code, name, rarity, x, y, w, h))
    lines += ["\t},", "}", ""]
    open(A("src", "shared", "Assets", "Flags.luau"), "w").write("\n".join(lines))
    lines = [
        "-- GENERATED by tools/arte/cosmeticos.py (run tools/arte/make_own_art.py). Do not edit by hand.",
        "-- The pets (Data/Cosmetics, kind \"pet\"): a creature's head shown to the right of the player's name.",
        "-- One atlas drawn by the game itself (Assets/OwnArt); each pet's pixel rect in it and its rarity.",
        "return {",
        '\timage = "%s",' % PETS_ID,
        "\tpets = {",
    ]
    for pid, name, rarity, x, y, w, h in pet_cells:
        lines.append('\t\t{ id = "%s", name = "%s", rarity = "%s", x = %d, y = %d, w = %d, h = %d },' % (pid, name, rarity, x, y, w, h))
    lines += ["\t},", "}", ""]
    open(A("src", "shared", "Assets", "Pets.luau"), "w").write("\n".join(lines))
    write_seasons()


if __name__ == "__main__":
    import sys

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    f, fc = flags_atlas()
    p, pc = pets_atlas()
    f.save("/tmp/flags.png"); p.save("/tmp/pets.png"); lobby_bg().save("/tmp/lobby.png")
    print(len(fc), "estandartes", f.size, len(pc), "pets", p.size)
