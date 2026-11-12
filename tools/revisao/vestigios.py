#!/usr/bin/env python3
"""Revisão de vestígios do RoWorld no código que vai para o jogo (src/).

Separa código de comentário (os comentários vão no .rbxl, mas só quem abre os scripts no Studio lê;
o jogador não) e lista, no CÓDIGO:
  nomes   textos com RoWorld / Rofront / Snick / OpenFront / Airfront
  links   http(s)://, discord, github
  ids     números de 7+ dígitos (ids do Roblox: contas, grupos, lugares, produtos, imagens, sons)
  servicos chamadas a serviços que ligam o jogo a algo de fora (HTTP, teleporte, compras, grupos...)

Uso: python3 tools/revisao/vestigios.py [nomes|links|ids|servicos|comentarios]
"""
import os, re, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "src")
SKIP = ("OwnArtData.luau", "World.luau", "EarthWorld.luau")
SKIP_DIR = ("MapData",)


def split(src):
    """(code, comments): same length as src, the other part blanked (newlines kept)."""
    code, com = [], []
    i, n = 0, len(src)
    def put(ch, is_code):
        blank = ch if ch == "\n" else " "
        code.append(ch if is_code else blank)
        com.append(blank if is_code else ch)
    while i < n:
        c = src[i]
        if src.startswith("--", i):
            m = re.match(r"--\[(=*)\[", src[i:])
            if m:
                end = src.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
            else:
                end = src.find("\n", i)
                end = n if end < 0 else end
            for ch in src[i:end]:
                put(ch, False)
            i = end
        elif c in "\"'`":
            j = i + 1
            while j < n and src[j] != c and src[j] != "\n":
                j += 2 if src[j] == "\\" else 1
            j = min(j + 1, n)
            for ch in src[i:j]:
                put(ch, True)
            i = j
        else:
            m = re.match(r"\[(=*)\[", src[i:]) if c == "[" else None
            if m:
                end = src.find("]" + m.group(1) + "]", i)
                end = n if end < 0 else end + len(m.group(1)) + 2
                for ch in src[i:end]:
                    put(ch, True)
                i = end
            else:
                put(c, True)
                i += 1
    return "".join(code), "".join(com)


def files():
    for d, dirs, fs in os.walk(ROOT):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIR)
        for f in sorted(fs):
            if f.endswith(".luau") and f not in SKIP and not f.startswith("ArsenalIcon_"):
                yield os.path.join(d, f)


PAT = {
    "nomes": re.compile(r"roworld|rofront|snick|openfront|airfront", re.I),
    "links": re.compile(r"https?://|discord|github|\.com\b|\.gg\b|\.io\b", re.I),
    "ids": re.compile(r"(?<![\w.])\d{7,}(?![\w.])"),
    "servicos": re.compile(
        r"HttpService|RequestAsync|GetAsync\(\s*\"http|PostAsync|TeleportService|SocialService|GroupService|IsInGroup|GetRankInGroup|"
        r"BadgeService|AwardBadge|MessagingService|AnalyticsService|PromptGamePassPurchase|PromptPurchase\b|PromptBulkPurchase|"
        r"PromptSubscriptionPurchase|UserOwnsGamePassAsync|PromptPremiumPurchase|InsertService|LoadAsset|loadstring|"
        r"require\(\s*\d|CreatorId|PolicyService|PromptGameInvite|FollowAsync|AssetService|GetUserIdFromNameAsync|MarketplaceService"
    ),
}


def main():
    what = sys.argv[1] if len(sys.argv) > 1 else "nomes"
    total = 0
    for path in files():
        src = open(path, encoding="utf-8").read()
        code, com = split(src)
        part = com if what == "comentarios" else code
        pat = PAT["nomes"] if what == "comentarios" else PAT[what]
        lines = part.split("\n")
        full = src.split("\n")
        for k, line in enumerate(lines):
            if pat.search(line):
                total += 1
                print(f"{os.path.relpath(path, ROOT)}:{k + 1}: {full[k].strip()[:210]}")
    print(f"-- {what}: {total} linhas", file=sys.stderr)


main()
