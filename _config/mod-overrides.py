# -*- coding: utf-8 -*-
"""mod-overrides.py -- кто из модов трогает какие файлы и таблицы игры: матрица пересечений.

ЗАЧЕМ. Слово владельца 2026-10-25 про отчёт о модах Мастерской: «мне приходится тебя просить изучать конфликтность
и что меняет для нас в сборке - а ты это уже должен был сделать в этом md!». Совет «брать» без этой матрицы -- полдела.

ДВА ВИДА КОНФЛИКТА У МОДОВ CONAN ENHANCED:
  1. Перезапись файла игры: пак везёт ассет по ванильному пути (/Content/... вне /Content/Mods/ и /Content/ModsShared/).
     Кто ниже в modlist.txt -- тот побеждает, второй молча теряет свою версию.
  2. Вливание в таблицу игры на лету: свой bp_ModController при старте дописывает строки в ВАНИЛЬНУЮ таблицу
     (спавн, предметы, рецепты, уровни). Файлы не пересекаются, а таблица одна. Видно только по ссылкам на /Game/...
     внутри ассетов мода (Diverse Barkeeps: ни одного ванильного пути, а таблицу спавна меняет -- 2026-10-25).

КАК. Внешний пак -- обёртка; внутренний <Мод>-Windows.utoc достаётся repak'ом (маленький, без ucas) и
перечисляется китовым UnrealPak -List -> вид 1 (надёжно).
Вид 2 ЭТИМ ПРИБОРОМ НЕ ПРОВЕРЯЕТСЯ. Первая версия искала строки /Game/... в .uexp контроллеров и у Diverse Barkeeps,
который точно правит таблицу спавна, нашла ноль (2026-10-25). Пути ИСПОЛЬЗУЕМЫХ ванильных пакетов лежат текстом в .uheader
(docs/15), но цель вливания контроллера там видна не всегда — у Diverse Barkeeps её нет. Ноль значил «не видно», а не
«чисто» -- поэтому прибор выписывает только СВОИ таблицы мода (DT_*, MergeControl, ModController) как подсказку; правду о
виде 2 даёт журнал игры (_config/who-overwrites-table.py).

    python -I -X utf8 _config/mod-overrides.py <выход.tsv> <пак|папка> [<пак|папка> ...]
[NOT-TESTED]
"""

import glob
import os
import re
import subprocess
import sys
import tempfile

REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
UNREALPAK = r"F:\CEUE5Devkit\Engine\Binaries\Win64\UnrealPak.exe"   # кит переехал из F:\CEDevKit\ (2026-10-29: старый путь — FileNotFoundError)
OWN = re.compile(r"/Content/(Mods|ModsShared)/", re.I)


def run(cmd, out=None):
    if out:
        with open(out, "wb") as fh:
            return subprocess.run(cmd, stdout=fh, stderr=subprocess.DEVNULL).returncode
    return subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")


def inner(pak, suffix):
    names = run([REPAK, "list", pak]).stdout.split()
    hit = [n for n in names if n.endswith("-Windows" + suffix)]
    return hit[0] if hit else None


def assets(utoc):
    out = run([UNREALPAK, utoc, "-List"]).stdout
    return sorted(set(m.replace("../../../ConanSandbox", "") for m in re.findall(r'"(\.\./\.\./\.\./[^"]+\.(?:uasset|umap))"', out)))


def own_tables(asset_paths):
    """Свои таблицы и контроллеры мода — подсказка, куда он вливается на лету (вид 2 не проверка, см. шапку)."""
    return sorted(p.rsplit("/", 1)[-1].split(".")[0] for p in asset_paths
                  if OWN.search(p) and re.search(r"/(dt_|DT_|.*MergeControl|.*ModController|.*WeightedSpawn)", p))


def main():
    out, sources = sys.argv[1], sys.argv[2:]
    paks = []
    for s in sources:
        paks += sorted(glob.glob(os.path.join(s, "**", "*.pak"), recursive=True)) if os.path.isdir(s) else [s]
    rows = []
    for pak in paks:
        name = os.path.splitext(os.path.basename(pak))[0]
        u = inner(pak, ".utoc")
        if not u:
            rows.append((name, pak, "NO-UTOC", [], None))
            continue
        with tempfile.TemporaryDirectory() as tmp:
            utoc = os.path.join(tmp, os.path.basename(u))
            run([REPAK, "get", pak, u], out=utoc)
            a = assets(utoc)
            vanilla = [x for x in a if not OWN.search(x)]
            tables = own_tables(a)
        rows.append((name, pak, "ok", vanilla, tables))
        print("%-40s ассетов %5d, ванильных путей %3d, своих таблиц %d" % (
            name[:40], len(a), len(vanilla), len(tables)), flush=True)
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("mod\tkind\tpath\n")
        for name, pak, st, vanilla, tables in rows:
            for v in vanilla:
                fh.write("%s\toverride\t%s\n" % (name, v))
            for t in tables:
                fh.write("%s\towntable\t%s\n" % (name, t))
    print("->", out)


if __name__ == "__main__":
    main()
