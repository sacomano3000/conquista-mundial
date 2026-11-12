"""Os ícones desenhados em código (traço próprio deste jogo). Cada função devolve uma máscara 'L'
(branco = tinta) de N x N. Coordenadas 0..100, y para baixo."""
import math
from PIL import Image, ImageDraw, ImageFont

SS = 8  # supersampling
N = 128
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


class G:
    def __init__(self, n=N):
        self.n = n
        self.k = n * SS / 100.0
        self.im = Image.new("L", (n * SS, n * SS), 0)
        self.d = ImageDraw.Draw(self.im)

    def _p(self, pts):
        return [(x * self.k, y * self.k) for x, y in pts]

    def P(self, pts, f=255):
        self.d.polygon(self._p(pts), fill=f)

    def C(self, x, y, r, f=255):
        k = self.k
        self.d.ellipse([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], fill=f)

    def E(self, x0, y0, x1, y1, f=255):
        k = self.k
        self.d.ellipse([x0 * k, y0 * k, x1 * k, y1 * k], fill=f)

    def R(self, x0, y0, x1, y1, r=0, f=255):
        k = self.k
        self.d.rounded_rectangle([x0 * k, y0 * k, x1 * k, y1 * k], radius=r * k, fill=f)

    def L(self, pts, w, f=255):
        k = self.k
        self.d.line(self._p(pts), fill=f, width=int(w * k), joint="curve")
        for x, y in pts:
            self.C(x, y, w / 2.0, f)

    def A(self, x, y, r, a0, a1, w, f=255):
        k = self.k
        self.d.arc([(x - r) * k, (y - r) * k, (x + r) * k, (y + r) * k], a0, a1, fill=f, width=int(w * k))

    def text(self, s, x, y, size, f=255):
        font = ImageFont.truetype(BOLD, int(size * self.k))
        self.d.text((x * self.k, y * self.k), s, font=font, fill=f, anchor="mm")

    def paste(self, mask, x, y, w, h, f=255):
        """Outra máscara ('L') encaixada na caixa (x, y, w, h), proporção mantida, centrada."""
        k = self.k
        bw, bh = w * k, h * k
        s = min(bw / mask.width, bh / mask.height)
        m = mask.resize((max(1, int(mask.width * s)), max(1, int(mask.height * s))), Image.LANCZOS)
        ox = int(x * k + (bw - m.width) / 2)
        oy = int(y * k + (bh - m.height) / 2)
        self.im.paste(f, (ox, oy), m)

    def out(self):
        return self.im.resize((self.n, self.n), Image.LANCZOS)


def shield_pts(cx, top, w, h, n=14):
    """Escudo: topo reto, lados que descem e fecham em ponta."""
    pts = [(cx - w / 2, top), (cx + w / 2, top)]
    for i in range(n + 1):
        t = i / n
        pts.append((cx + (w / 2) * math.cos(t * math.pi / 2) ** 0.8, top + h * 0.42 + h * 0.58 * math.sin(t * math.pi / 2)))
    for i in range(n, -1, -1):
        t = i / n
        pts.append((cx - (w / 2) * math.cos(t * math.pi / 2) ** 0.8, top + h * 0.42 + h * 0.58 * math.sin(t * math.pi / 2)))
    return pts


def star_pts(cx, cy, ro, ri, n, rot=-90.0):
    pts = []
    for i in range(n * 2):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def close():
    g = G(); g.L([(24, 24), (76, 76)], 14); g.L([(76, 24), (24, 76)], 14); return g.out()


def check():
    g = G(); g.L([(18, 54), (41, 75), (83, 27)], 14); return g.out()


def chevron():
    g = G(); g.L([(22, 36), (50, 64), (78, 36)], 13); return g.out()


def play():
    g = G(); g.P([(28, 14), (86, 50), (28, 86)]); return g.out()


def clock():  # ampulheta
    g = G()
    g.R(20, 10, 80, 21, 4); g.R(20, 79, 80, 90, 4)
    g.P([(27, 20), (73, 20), (55, 50), (73, 80), (27, 80), (45, 50)])
    g.P([(36, 27), (64, 27), (50, 45)], 0)
    return g.out()


def info():
    g = G(); g.C(50, 50, 41); g.C(50, 29, 7, 0); g.R(43, 42, 57, 74, 3, 0); return g.out()


def help_():
    g = G(); g.C(50, 50, 41); g.text("?", 50, 49, 62, 0); return g.out()


def settings():
    g = G()
    for i in range(8):
        a = math.radians(i * 45)
        c, s = math.cos(a), math.sin(a)
        pts = [(-9, -43), (9, -43), (11, -24), (-11, -24)]
        g.P([(50 + x * c - y * s, 50 + x * s + y * c) for x, y in pts])
    g.C(50, 50, 31); g.C(50, 50, 13, 0)
    return g.out()


def exit_():
    g = G()
    g.R(14, 12, 54, 88, 6); g.R(25, 23, 60, 77, 0, 0)
    g.L([(42, 50), (78, 50)], 11); g.P([(68, 30), (92, 50), (68, 70)])
    return g.out()


def eye():
    g = G()
    top = [(8 + 84 * t, 50 - 27 * math.sin(math.pi * t)) for t in [i / 24 for i in range(25)]]
    bot = [(92 - 84 * t, 50 + 27 * math.sin(math.pi * t)) for t in [i / 24 for i in range(25)]]
    g.P(top + bot); g.C(50, 50, 16, 0); g.C(50, 50, 8)
    return g.out()


def layers():
    g = G()
    g.P([(50, 12), (90, 33), (50, 54), (10, 33)])
    g.L([(12, 52), (50, 72), (88, 52)], 8); g.L([(12, 69), (50, 89), (88, 69)], 8)
    return g.out()


def _note(g):
    g.C(30, 76, 13); g.C(72, 68, 13)
    g.L([(39, 74), (39, 26)], 8); g.L([(81, 66), (81, 18)], 8)
    g.P([(35, 20), (85, 11), (85, 27), (35, 36)])


def music_on():
    g = G(); _note(g); return g.out()


def music_off():
    g = G(); _note(g); g.L([(12, 12), (90, 90)], 17, 0); g.L([(14, 14), (88, 88)], 8); return g.out()


def users():
    g = G()
    g.C(66, 38, 13); g.E(44, 56, 96, 112)
    g.C(36, 32, 20, 0); g.E(5, 49, 67, 116, 0)
    g.C(36, 32, 16); g.E(9, 53, 63, 112)
    g.R(0, 86, 100, 130, 0, 0)
    return g.out()


def pops():  # alto-falante com duas ondas: os sons (Efeitos e Som de fronteira, nas Configurações)
    g = G()
    g.R(8, 37, 30, 63, 3)
    g.P([(24, 37), (50, 15), (50, 85), (24, 63)])
    g.A(50, 50, 22, -48, 48, 9)
    g.A(50, 50, 40, -48, 48, 9)
    return g.out()


def target():
    g = G()
    g.C(50, 50, 33); g.C(50, 50, 24, 0)
    for a, b in (((50, 6), (50, 28)), ((50, 72), (50, 94)), ((6, 50), (28, 50)), ((72, 50), (94, 50))):
        g.L([a, b], 8)
    g.P([(50, 40), (60, 50), (50, 60), (40, 50)])
    return g.out()


def lock():
    g = G()
    g.C(50, 40, 24); g.C(50, 40, 14, 0); g.R(0, 46, 100, 100, 0, 0)
    g.R(26, 30, 36, 50); g.R(64, 30, 74, 50)
    g.R(20, 44, 80, 90, 8)
    g.C(50, 62, 7, 0); g.P([(46, 64), (54, 64), (57, 79), (43, 79)], 0)
    return g.out()


def reload():
    g = G()
    g.A(50, 54, 33, 335, 268, 11)
    g.P([(46, 6), (72, 22), (46, 40)])
    return g.out()


def retreat():  # bandeira
    g = G()
    g.L([(24, 10), (24, 90)], 9)
    g.P([(30, 14), (62, 20), (88, 14), (76, 32), (88, 50), (62, 54), (30, 48)])
    return g.out()


def star():
    g = G(); g.P(star_pts(50, 53, 45, 19, 5)); return g.out()


def crown():
    g = G()
    g.P([(12, 34), (32, 56), (50, 22), (68, 56), (88, 34), (80, 76), (20, 76)])
    g.R(20, 80, 80, 91, 3)
    for x, y in ((12, 32), (50, 19), (88, 32)):
        g.C(x, y, 7)
    g.P([(50, 54), (57, 63), (50, 72), (43, 63)], 0)
    return g.out()


def gold():
    g = G()
    for y in (76, 60, 44):
        g.E(8, y - 15, 66, y + 15, 0); g.E(11, y - 11, 63, y + 11)
    g.C(76, 68, 20, 0); g.C(76, 68, 17); g.C(76, 68, 11, 0); g.P([(76, 61), (82, 68), (76, 75), (70, 68)])
    return g.out()


def donate():  # bolsa de moedas
    g = G()
    g.E(18, 34, 82, 94)
    g.P([(36, 40), (64, 40), (74, 12), (58, 20), (50, 10), (42, 20), (26, 12)])
    g.L([(30, 38), (70, 38)], 5, 0)
    g.C(50, 66, 13, 0); g.P([(50, 57), (58, 66), (50, 75), (42, 66)])
    return g.out()


def skull():
    g = G()
    g.C(50, 42, 32); g.R(33, 58, 67, 88, 6)
    g.C(37, 44, 10, 0); g.C(63, 44, 10, 0); g.P([(50, 54), (44, 66), (56, 66)], 0)
    for x in (43, 50, 57):
        g.L([(x, 78), (x, 90)], 3, 0)
    return g.out()


def troops():  # elmo
    g = G()
    g.E(20, 14, 80, 86); g.R(0, 52, 100, 100, 0, 0)
    g.P([(20, 50), (20, 86), (42, 86), (50, 72), (58, 86), (80, 86), (80, 50)])
    g.R(27, 45, 73, 53, 0, 0); g.L([(50, 53), (50, 68)], 4, 0)
    g.P([(46, 16), (54, 2), (78, 6), (62, 20)])
    return g.out()


def alliance():  # dois escudos
    g = G()
    g.P(shield_pts(35, 20, 46, 64))
    g.P(shield_pts(65, 16, 58, 76), 0)
    g.P(shield_pts(65, 20, 46, 64))
    g.L([(35, 34), (35, 62)], 5, 0); g.L([(24, 46), (40, 46)], 5, 0)
    g.P(star_pts(65, 48, 11, 5, 4), 0)
    return g.out()


def betray():  # adaga
    g = G()
    g.P([(50, 97), (41, 44), (59, 44)]); g.R(28, 35, 72, 45, 4); g.R(44, 14, 56, 37, 2); g.C(50, 11, 8)
    g.L([(50, 50), (50, 82)], 2.5, 0)
    return g.out()


def atom():  # (não usado desde 2026-11-12: a bola de fogo vem de assets/gerados/g_atom.png)
    g = G()
    g.P([(44, 46), (6, 8), (32, 74)]); g.P([(60, 38), (38, 4), (40, 52)]); g.P([(36, 62), (2, 44), (40, 84)])
    g.C(60, 62, 27); g.C(62, 64, 13, 0); g.C(62, 64, 6)
    return g.out()


def hydrogen():  # tempestade de fogo
    g = G()
    g.P([(50, 4), (66, 28), (61, 40), (77, 30), (86, 60), (74, 84), (50, 95), (26, 84), (14, 60), (24, 34), (37, 46), (38, 24)])
    g.P([(50, 48), (61, 66), (57, 82), (50, 87), (43, 82), (39, 66)], 0)
    return g.out()


def mirv():  # chuva de meteoros
    g = G()
    for x, y, r in ((22, 66, 10), (50, 84, 10), (76, 62, 10)):
        g.P([(x - r * 0.9, y - r * 0.4), (x + r * 0.9, y + r * 0.4), (x + 14, y - 46)])
        g.C(x, y, r)
    return g.out()


def mega():  # magia suprema
    g = G()
    g.P(star_pts(50, 50, 47, 20, 8)); g.C(50, 50, 12, 0); g.P(star_pts(50, 50, 8, 3.5, 4))
    return g.out()


def scatter():  # rajada arcana
    g = G()
    for a in (-150, -120, -90, -60, -30):
        x = 50 + 40 * math.cos(math.radians(a)); y = 88 + 62 * math.sin(math.radians(a))
        g.L([(50, 88), (x, y)], 4.5)
        g.P([(x, y - 11), (x + 9, y), (x, y + 11), (x - 9, y)])
    g.C(50, 88, 8)
    return g.out()


def wall():  # muralha (os Reforços agora são a trompa de guerra: assets/gerados/g_reinforce.png)
    g = G()
    g.R(12, 42, 88, 88, 2)
    for x in (12, 43, 74):
        g.R(x, 26, x + 14, 44, 1)
    g.R(44, 52, 56, 80, 1, 0); g.R(36, 60, 64, 72, 1, 0)
    return g.out()


def slug():  # virote da balista: haste, ponta e penas, com riscos de velocidade
    g = G()
    g.L([(28, 50), (78, 50)], 6)
    g.P([(72, 37), (98, 50), (72, 63)])
    for sy in (-1, 1):
        for x in (30, 40):
            g.L([(x, 50), (x - 9, 50 + sy * 12)], 5)
    for y, x0, x1 in ((26, 30, 52), (74, 30, 52)):
        g.L([(x0, y), (x1, y)], 4)
    g.L([(2, 50), (12, 50)], 4)
    return g.out()


def crate():  # baú
    g = G()
    g.R(12, 20, 88, 52, 14); g.R(12, 40, 88, 88, 4)
    g.L([(12, 47), (88, 47)], 4, 0)
    for x in (28, 72):
        g.L([(x, 20), (x, 88)], 3, 0)
    g.R(40, 38, 60, 62, 3, 0); g.R(43, 41, 57, 59, 2); g.C(50, 50, 3.5, 0)
    return g.out()


def globe():  # rosa dos ventos
    g = G()
    g.C(50, 50, 36); g.C(50, 50, 29, 0)
    g.P(star_pts(50, 50, 30, 9, 4, rot=-45.0))
    g.P(star_pts(50, 50, 52, 10, 4), 0)
    g.P(star_pts(50, 50, 47, 8, 4)); g.C(50, 50, 5, 0)
    return g.out()


def leaderboard():  # taça
    g = G()
    for x in (26, 74):
        g.C(x, 30, 14); g.C(x, 30, 8, 0)
    g.P([(24, 10), (76, 10), (76, 22), (70, 46), (58, 60), (42, 60), (30, 46), (24, 22)], 0)
    g.P([(27, 12), (73, 12), (68, 44), (57, 58), (43, 58), (32, 44)])
    g.R(45, 56, 55, 76); g.R(28, 76, 72, 90, 4)
    g.P(star_pts(50, 32, 10, 4.5, 5), 0)
    return g.out()


def github():  # código: </>
    g = G()
    g.L([(34, 26), (12, 50), (34, 74)], 10); g.L([(66, 26), (88, 50), (66, 74)], 10); g.L([(57, 18), (43, 82)], 9)
    return g.out()


def boat():  # barco
    g = G()
    g.P([(6, 60), (94, 60), (82, 84), (20, 84)]); g.C(9, 52, 8); g.C(9, 52, 3.5, 0)
    g.L([(50, 60), (50, 10)], 5)
    g.P([(24, 18), (76, 18), (72, 52), (28, 52)])
    for x in (41, 59):
        g.L([(x, 18), (x, 52)], 3.5, 0)
    g.L([(0, 56), (100, 56)], 3, 0)
    return g.out()


def warship():  # (não usado desde 2026-11-12: o drácar vem de assets/gerados/g_warship.png)
    g = G()
    g.P([(4, 62), (30, 66), (96, 56), (86, 86), (16, 86)])
    for x, top in ((26, 22), (50, 8), (74, 20)):
        g.L([(x, 62), (x, top)], 4)
        g.P([(x - 11, top + 6), (x + 11, top + 6), (x + 13, top + 26), (x - 13, top + 26)])
        if top + 30 < 50:
            g.P([(x - 13, top + 30), (x + 13, top + 30), (x + 14, 52), (x - 14, 52)])
    g.P([(52, 8), (66, 12), (52, 16)])
    for x in (30, 46, 62, 78):
        g.C(x, 74, 3.2, 0)
    return g.out()


DRAWN = {
    "close": close, "check": check, "chevron": chevron, "play": play, "clock": clock, "info": info,
    "help": help_, "settings": settings, "exit": exit_, "eye": eye, "layers": layers,
    "music_on": music_on, "music_off": music_off, "users": users, "pops": pops, "target": target,
    "lock": lock, "reload": reload, "retreat": retreat, "star": star, "crown": crown, "gold": gold,
    "donate": donate, "skull": skull, "troops": troops, "alliance": alliance, "betray": betray,
    "atom": atom, "hydrogen": hydrogen, "mirv": mirv, "mega": mega, "scatter": scatter,
    "wall": wall, "slug": slug, "crate": crate, "globe": globe, "leaderboard": leaderboard,
    "github": github, "boat": boat, "warship": warship,
}
