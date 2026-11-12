#!/usr/bin/env python3
"""Confere que nenhuma imagem do RoWorld é mostrada pelo jogo.

Lê todo `rbxassetid://` de src/ e separa:
  - trocadas: têm desenho próprio (src/shared/Assets/OwnArtData.luau), posto no lugar ao rodar;
  - próprias: ids deste jogo (OwnArtIds.luau: imagens que o dono subiu na própria conta);
  - sons: ids de áudio (ficam fora desta conta: não são imagens);
  - sobra: qualquer outra imagem. Tem que ser zero.

  python3 tools/revisao/imagens.py        # lista; sai com erro se sobrar alguma
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "src")

# arquivos só de som, ou de desenvolvimento (não vão para o jogo publicado)
AUDIO_FILES = ("Sfx", "Music", "Sounds", "Audio", "Soundtrack")
SKIP_DIRS = ("Dev",)


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def scan():
    data = read(os.path.join(SRC, "shared", "Assets", "OwnArtData.luau"))
    swapped = set(re.findall(r'\["(rbxassetid://\d+)"\] = "', data))
    own = set()
    ids_path = os.path.join(SRC, "shared", "Assets", "OwnArtIds.luau")
    if os.path.exists(ids_path):
        own = set("rbxassetid://" + n for n in re.findall(r'= "rbxassetid://(\d+)"', read(ids_path)))
    found = {}  # id -> [(file, line, is_audio)]
    for base, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in sorted(files):
            if not name.endswith(".luau") or name in ("OwnArtData.luau", "OwnArtIds.luau"):
                continue
            path = os.path.join(base, name)
            rel = os.path.relpath(path, ROOT)
            audio_file = any(k.lower() in name.lower() for k in AUDIO_FILES)
            for n, line in enumerate(read(path).split("\n"), 1):
                code = line.split("--", 1)[0]
                for m in re.finditer(r"rbxassetid://(\d+)", code):
                    low = code.lower()
                    audio = audio_file or "soundid" in low or "sound" in low or "sfx" in low or "music" in low
                    found.setdefault("rbxassetid://" + m.group(1), []).append((rel, n, audio))
    out = {"trocadas": [], "proprias": [], "sons": [], "sobra": []}
    for i, where in sorted(found.items()):
        if i in swapped:
            out["trocadas"].append((i, where))
        elif i in own:
            out["proprias"].append((i, where))
        elif all(w[2] for w in where):
            out["sons"].append((i, where))
        else:
            out["sobra"].append((i, where))
    return out


def main():
    out = scan()
    print("imagens trocadas por desenho próprio: %d" % len(out["trocadas"]))
    print("imagens próprias (subidas pelo dono):  %d" % len(out["proprias"]))
    print("sons (fora desta conta):               %d" % len(out["sons"]))
    print("imagens do RoWorld ainda em uso:       %d" % len(out["sobra"]))
    for i, where in out["sobra"]:
        print("  %s  %s" % (i, ", ".join("%s:%d" % (w[0], w[1]) for w in where[:3])))
    if "-v" in sys.argv:
        for i, where in out["sons"]:
            print("  som %s  %s:%d" % (i, where[0][0], where[0][1]))
    sys.exit(1 if out["sobra"] else 0)


if __name__ == "__main__":
    main()
