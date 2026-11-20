# -*- coding: utf-8 -*-
"""patch-rollback.py — какие ванильные ассеты, которые моды сборки везут целиком, изменил патч игры (мод молча откатывает правку патча).

Зачем (2026-11-13, переезд на 3.1.0, KUMM план 53 шаг 5): способ был описан словами в docs/02 §2.1 п. 3 («UnrealPak <pakchunk*-Windows.utoc>
-List в обеих версиях игры, сверить hash: у путей, которые везут моды»), прибора не было — на переезде 3.0.1 сверку делали руками для трёх таблиц.
Мод, сваренный до патча, везёт ванильный ассет в старой версии: если Funcom его менял, в сборке живёт старый, и ни журнал, ни игра этого не скажут.

    python -I -X utf8 patch-rollback.py <overrides.tsv> <старая игра> <новая игра> [<выход.tsv>] [--fresh]
<overrides.tsv> — выход mod-overrides.py (строки «мод · override · путь»). Списки паков каждой игры снимаются китовым UnrealPak -List по всем
pakchunk*-Windows.utoc и кэшируются в _scratch/paklist-<папка игры>.tsv (--fresh — снять заново; кэш сам устаревает, если у .utoc сменились
размер или время). Пишет только в _scratch и в <выход.tsv>; игры — только чтение.
Вердикт на строку: ТОТ ЖЕ (патч не трогал) · ИЗМЕНЁН ПАТЧЕМ (мод откатывает правку — разбирать по researches/mod-reconciliation/GUIDE.md, вид 6) ·
НЕТ В НОВОЙ (ассет убран из игры) · НЕТ В СТАРОЙ · НЕТ В ОБЕИХ (свой путь мода вне паков игры).
Код 0 — откатов нет; 1 — есть ИЗМЕНЁН ПАТЧЕМ или НЕТ В НОВОЙ; 2 — не удалось снять список.
[NOT-TESTED]
"""
import glob
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.dirname(HERE)
SCRATCH = os.path.join(PACK, "_scratch")
UNREALPAK = r"F:\CEUE5Devkit\Engine\Binaries\Win64\UnrealPak.exe"   # китовый: читает паки игры с Oodle (EXP-0321)
LINE = re.compile(r'"\.\./\.\./\.\./(?:ConanSandbox)?(/?[^"]+)" offset: \d+, size: (\d+) bytes, hash: ([0-9a-f]+)')


def norm(path):
    p = path.replace("\\", "/")
    return p if p.startswith("/") else "/" + p


def utoc_files(game):
    return sorted(glob.glob(os.path.join(game, "ConanSandbox", "Content", "Paks", "pakchunk*-Windows.utoc")))


def listing(game, fresh):
    """{путь: (размер, хеш)} по всем .utoc игры, с кэшем; ключ кэша — имя, размер и время каждого .utoc."""
    os.makedirs(SCRATCH, exist_ok=True)
    cache = os.path.join(SCRATCH, "paklist-" + re.sub(r"[^A-Za-z0-9._-]+", "_", os.path.basename(os.path.normpath(game))) + ".json")
    stamp = [[os.path.basename(u), os.path.getsize(u), int(os.path.getmtime(u))] for u in utoc_files(game)]
    if not stamp:
        sys.exit(f"в {game} нет pakchunk*-Windows.utoc")
    if not fresh and os.path.isfile(cache):
        data = json.load(open(cache, encoding="utf-8"))
        if data.get("stamp") == stamp:
            return {k: tuple(v) for k, v in data["files"].items()}
    files = {}
    for u in utoc_files(game):
        r = subprocess.run([UNREALPAK, u, "-List"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        found = 0
        for m in LINE.finditer(r.stdout):
            files[norm(m.group(1))] = (int(m.group(2)), m.group(3))
            found += 1
        if r.returncode != 0 or not found:
            print(f"СПИСОК НЕ СНЯТ: {u} (код {r.returncode}, строк {found})")
            sys.exit(2)
        print(f"  {os.path.basename(u)}: {found}", flush=True)
    json.dump({"stamp": stamp, "files": files}, open(cache, "w", encoding="utf-8"))
    return files


def main():
    args = [a for a in sys.argv[1:] if a != "--fresh"]
    if len(args) < 3:
        print(__doc__)
        return 2
    overrides, old_game, new_game = args[0], args[1], args[2]
    out = args[3] if len(args) > 3 else None
    fresh = "--fresh" in sys.argv
    rows = []
    for line in open(overrides, encoding="utf-8"):
        parts = line.rstrip("\n").split("\t")
        if len(parts) >= 3 and parts[1] == "override":
            rows.append((parts[0], norm(parts[2])))
    print(f"перекрытий в {overrides}: {len(rows)}")
    print(f"старая игра: {old_game}")
    old = listing(old_game, fresh)
    print(f"новая игра: {new_game}")
    new = listing(new_game, fresh)
    verdicts = []
    for mod, path in rows:
        o, n = old.get(path), new.get(path)
        if o and n:
            v = "ТОТ ЖЕ" if o[1] == n[1] else "ИЗМЕНЁН ПАТЧЕМ"
        elif o:
            v = "НЕТ В НОВОЙ"
        elif n:
            v = "НЕТ В СТАРОЙ"
        else:
            v = "НЕТ В ОБЕИХ"
        verdicts.append((v, mod, path, o, n))
    order = {"ИЗМЕНЁН ПАТЧЕМ": 0, "НЕТ В НОВОЙ": 1, "НЕТ В СТАРОЙ": 2, "НЕТ В ОБЕИХ": 3, "ТОТ ЖЕ": 4}
    verdicts.sort(key=lambda r: (order[r[0]], r[1], r[2]))
    counts = {}
    for v, mod, path, o, n in verdicts:
        counts[v] = counts.get(v, 0) + 1
        if v != "ТОТ ЖЕ":
            size = lambda x: str(x[0]) if x else "-"
            print(f"{v:15s} {mod:34s} {path}  ({size(o)} -> {size(n)} байт)")
    print("итог: " + ", ".join(f"{k} {counts[k]}" for k in sorted(counts, key=lambda k: order[k])))
    if out:
        with open(out, "w", encoding="utf-8") as fh:
            for v, mod, path, o, n in verdicts:
                fh.write("\t".join([v, mod, path, o[1] if o else "", n[1] if n else ""]) + "\n")
        print(f"-> {out}")
    return 1 if counts.get("ИЗМЕНЁН ПАТЧЕМ") or counts.get("НЕТ В НОВОЙ") else 0


if __name__ == "__main__":
    sys.exit(main())
