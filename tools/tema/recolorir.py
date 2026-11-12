#!/usr/bin/env python3
"""Tema grafite/preto + vermelho: tira o azul-marinho e o âmbar do RoWorld da interface.

1. Os tokens de cor de src/client/UI/UITheme.luau (TOKENS abaixo).
2. As cores escritas à mão nas telas (src/client/UI/*.luau): todo tom azul-marinho/azul-acinzentado
   vira o cinza grafite de mesmo brilho. Cores vivas (verde, ouro, ciano...) ficam.
Rodar da raiz do projeto: python3 tools/tema/recolorir.py   (pode rodar mais de uma vez)
"""
import re, glob, sys

TOKENS = {
    "GLASS": "UITheme.rgba(0.066, 0.066, 0.074, 0.86)",
    "GLASS_SOLID": "UITheme.rgba(0.047, 0.047, 0.053, 0.96)",
    "GLASS_RAISED": "UITheme.rgba(0.135, 0.135, 0.148, 0.94)",
    "TEXT": "Color3.new(0.965, 0.955, 0.945)",
    "TEXT_2": "Color3.new(0.74, 0.73, 0.735)",
    "TEXT_3": "Color3.new(0.53, 0.52, 0.53)",
    "AMBER": "Color3.new(0.87, 0.16, 0.21)",
    "AMBER_HI": "Color3.new(0.97, 0.34, 0.38)",
    "AMBER_LO": "Color3.new(0.52, 0.06, 0.11)",
    "CYAN": "Color3.new(0.66, 0.80, 0.92)",
    "INK": "Color3.new(1.0, 0.965, 0.955)",
}
SKIP = ("ArsenalDemo.luau", "LangSweep.luau")  # the demo draws a piece of map: its colours are the map's


def degrey(r, g, b):
    """(r, g, b) 0..255 -> the graphite of the same brightness when it is a navy / slate blue, else None."""
    mx, mn = max(r, g, b), min(r, g, b)
    if not (b >= g >= r and b - r >= 10):
        return None
    if mx - mn > 0.42 * mx + 14 and mx > 120:
        return None  # a vivid blue: an accent, not a surface
    l = 0.30 * r + 0.55 * g + 0.15 * b
    if mx <= 120:
        l *= 0.92  # dark surfaces a touch darker: black rather than slate
    return (min(255, round(l + 2)), round(l), min(255, round(l + 3)))


def fix_rgb(m):
    r, g, b = int(m.group(1)), int(m.group(2)), int(m.group(3))
    n = degrey(r, g, b)
    return m.group(0) if n is None else "Color3.fromRGB(%d, %d, %d)" % n


def fix_new(m):
    v = [float(m.group(i)) for i in (1, 2, 3)]
    if max(v) > 1.0:
        return m.group(0)
    n = degrey(*[round(x * 255) for x in v])
    return m.group(0) if n is None else "Color3.new(%.3g, %.3g, %.3g)" % tuple(x / 255 for x in n)


def fix_rgba(m):
    v = [float(m.group(i)) for i in (1, 2, 3)]
    if max(v) > 1.0:
        return m.group(0)
    n = degrey(*[round(x * 255) for x in v])
    return m.group(0) if n is None else "rgba(%.3g, %.3g, %.3g, %s)" % (n[0] / 255, n[1] / 255, n[2] / 255, m.group(4))


# the title's wordmark: white running into amber -> white running into red
LITERAL = {"Color3.new(1.0, 0.8, 0.52)": "Color3.new(1.0, 0.5, 0.48)"}


def main():
    p = "src/client/UI/UITheme.luau"
    s = open(p).read()
    for k, v in TOKENS.items():
        s, n = re.subn(r"(?m)^(UITheme\.%s = )[^\n]*?( --[^\n]*)?$" % k, lambda m: m.group(1) + v, s, count=1)
        assert n == 1, k
    open(p, "w").write(s)
    total = 0
    for f in sorted(glob.glob("src/client/UI/*.luau")):
        if f.endswith(SKIP):
            continue
        s = open(f).read()
        t = re.sub(r"Color3\.fromRGB\((\d+), ?(\d+), ?(\d+)\)", fix_rgb, s)
        t = re.sub(r"Color3\.new\(([\d.]+), ?([\d.]+), ?([\d.]+)\)", fix_new, t)
        t = re.sub(r"rgba\(([\d.]+), ?([\d.]+), ?([\d.]+), ?([\d.]+)\)", fix_rgba, t)
        for a, b in LITERAL.items():
            t = t.replace(a, b)
        if f.endswith("UITheme.luau"):
            # keep the tokens exactly as written above
            for k, v in TOKENS.items():
                t = re.sub(r"(?m)^(UITheme\.%s = )[^\n]*$" % k, lambda m: m.group(1) + v, t, count=1)
        if t != s:
            n = sum(1 for a, b in zip(s.split("\n"), t.split("\n")) if a != b)
            total += n
            print("%-44s %d linhas" % (f, n))
            open(f, "w").write(t)
    print("total", total)


if __name__ == "__main__":
    main()
