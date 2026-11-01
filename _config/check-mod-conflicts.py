#!/usr/bin/env python3
"""
Находит конфликты модов по содержимому паков — не запуская игру.

[СОСТОЯНИЕ 2026-09-09: ПРИБОР НЕ ЗАКОНЧЕН, ЕГО ВЕРДИКТУ ВЕРИТЬ НЕЛЬЗЯ.]

Три редакции подряд дали три АРТЕФАКТА, а не находки, и это записано здесь, чтобы
следующая сессия не приняла их за результат:
  1) искал полные пути - нашёл 0 ассетов у всех 44 паков. Выглядело как
     «конфликтов нет», означало «не прочитал ничего»: полных путей в паке нет,
     точка монтирования и имена файлов лежат порознь;
  2) починил чтение, но нежадный шаблон обрезал монтирование на первом слэше -
     «в корень игры не монтируется никто»;
  3) сделал шаблон жадным - «в корень монтируется 41 мод из 44». А это значит,
     что монтирование в ConanSandbox/Content/ - НОРМА упаковки модов Конана, и
     сам критерий опасности выдуман неверно.

ЧТО ИЗ ПРОГОНА ВСЁ-ТАКИ ТВЁРДО: 202 совпадения имён между модами - это родовые
имена вроде preview.uasset, Normal.uasset, Button.uasset, BaseColor.uasset,
лежащие в СОБСТВЕННЫХ папках разных модов. Ни одной пары, делящей файл в одной
папке, не найдено.

ЧТО ОСТАЁТСЯ НЕИЗВЕСТНЫМ И ЯВЛЯЕТСЯ НАСТОЯЩИМ РИСКОМ: конфликт по диапазонам
ИДЕНТИФИКАТОРОВ предметов. В паке он не виден вовсе - ID лежат внутри сжатых
таблиц. Ловится только по журналу запуска игры. Значит проверка совместимости
этой сборки делается ЗАПУСКОМ, а не чтением файлов.

ЗАЧЕМ. «Совместимы ли моды» на глаз не проверяется, а авторы почти всегда пишут
«совместим со всем». Проверяемых признака конфликта два, и оба видны в паке:

  1. ТОЧКА МОНТИРОВАНИЯ. Аккуратный мод монтируется в свою папку:
         ../../../ConanSandbox/Content/Mods/<Имя>/
     Мод, смонтированный в ГОЛЫЙ ../../../ConanSandbox/Content/, кладёт файлы
     прямо в пространство имён игры и МОЖЕТ ПЕРЕКРЫВАТЬ ВАНИЛЬНЫЕ АССЕТЫ.
     Это не приговор (так делают правки таблиц), но это список тех, за кем
     следить в первую очередь.

  2. СОВПАДЕНИЕ ИМЁН ФАЙЛОВ у двух модов. Если оба смонтированы в свои папки -
     совпадение безобидно (разные каталоги). Если хотя бы один смонтирован в
     голый Content - совпадение означает, что один перекрывает другого, и
     побеждает тот, кто НИЖЕ в modlist.txt.

⚠️ ЧЕГО ПРИБОР НЕ ВИДИТ, И ЭТО ВАЖНЕЕ ТОГО, ЧТО ВИДИТ:
  * КОНФЛИКТ ПО ИДЕНТИФИКАТОРАМ ПРЕДМЕТОВ - когда два мода заняли один и тот же
    диапазон ID. Это самый частый конфликт в Конане, и в паке он не виден вовсе:
    ID лежат внутри сжатых таблиц. Ловится только по журналу запуска игры;
  * СЛИЯНИЕ ТАБЛИЦ. Два мода могут править одну ванильную таблицу штатным
    механизмом и мирно ужиться - имена файлов при этом совпадут, а беды не будет;
  * индекс пака сжат, читаются только имена и точки монтирования.

Запуск:
    python _config/check-mod-conflicts.py          - по модам, стоящим в игре
    python _config/check-mod-conflicts.py --lib    - по библиотеке пака
    python _config/check-mod-conflicts.py --all    - не сокращать списки
"""

import argparse
import os
import re
import sys
from collections import defaultdict

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME_MODS = sandbox('Mods')
LIB_WORKSHOP = r"D:\Games\Conan Exiles Mods\mods\_workshop"

CHUNK = 8 << 20
TAIL = 512
MOUNT_RE = re.compile(rb"\.\./\.\./\.\./[A-Za-z0-9_\-./]{2,160}/")
NAME_RE = re.compile(rb"[A-Za-z0-9_\-.]{3,120}\.(uasset|umap)")
VANILLA_MOUNT = "ConanSandbox/Content/"


def scan(pak: str):
    mounts, names = set(), set()
    with open(pak, "rb") as f:
        prev = b""
        while True:
            chunk = f.read(CHUNK)
            if not chunk:
                break
            buf = prev + chunk
            for m in MOUNT_RE.finditer(buf):
                mounts.add(m.group(0).decode("ascii", "ignore")[len("../../../"):])
            for m in NAME_RE.finditer(buf):
                names.add(m.group(0).decode("ascii", "ignore"))
            prev = chunk[-TAIL:]
    return mounts, names


def load_order(root: str):
    ml = os.path.join(root, "modlist.txt")
    if not os.path.isfile(ml):
        return {}
    with open(ml, encoding="utf-8-sig") as f:
        return {l.strip(): i + 1 for i, l in enumerate(f) if l.strip()}


def main() -> int:
    ap = argparse.ArgumentParser(description="Конфликты модов по содержимому паков")
    ap.add_argument("--lib", action="store_true")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    root = LIB_WORKSHOP if args.lib else GAME_MODS
    paks = []
    for dirpath, _, ns in os.walk(root):
        paks += [os.path.join(dirpath, n) for n in ns if n.lower().endswith(".pak")]
    if not paks:
        sys.exit(f"паков не найдено в {root}")

    order = load_order(root)
    print(f"Читаю {len(paks)} паков…{chr(10)}")

    info, owners = {}, defaultdict(list)
    risky = []
    for p in sorted(paks):
        name = os.path.basename(p)
        try:
            mounts, names = scan(p)
        except Exception as e:
            print(f"  [ошибка] {name}: {e}")
            continue
        info[name] = (mounts, names)
        bare = [m for m in mounts if m.rstrip("/") == VANILLA_MOUNT.rstrip("/")]
        if bare:
            risky.append(name)
        for n in names:
            owners[n].append(name)
        own = sorted(m for m in mounts if m.rstrip("/") != VANILLA_MOUNT.rstrip("/"))
        print(f"  {name[:42]:42} файлов: {len(names):>5} · загрузка #{order.get(name, '?'):>2}"
              f"{'  🔴 монтируется в КОРЕНЬ игры' if bare else ''}")
        if args.all and own:
            for m in own:
                print(f"        {m}")

    print()
    print("=" * 78)
    print(f"🔴 МОНТИРУЮТСЯ В КОРЕНЬ ИГРЫ (могут перекрывать ванильное): {len(risky)}")
    for n in risky:
        print(f"   {n}  · загрузка #{order.get(n, '?')}")
    if not risky:
        print("   Ни одного - все моды держат файлы в своих папках.")

    clashes = {n: sorted(set(m)) for n, m in owners.items() if len(set(m)) > 1}
    print()
    print("=" * 78)
    print(f"СОВПАДЕНИЯ ИМЁН ФАЙЛОВ МЕЖДУ МОДАМИ: {len(clashes)}")
    if clashes:
        by_pair = defaultdict(list)
        for n, mods in clashes.items():
            by_pair[tuple(mods)].append(n)
        for pair, files in sorted(by_pair.items(), key=lambda kv: -len(kv[1])):
            dangerous = any(m in risky for m in pair)
            mark = "🔴 ОПАСНО" if dangerous else "·  безобидно (разные папки)"
            print()
            print(f"  {mark}: {' + '.join(pair)}   ({len(files)} имён)")
            if dangerous and order:
                winner = max(pair, key=lambda m: order.get(m, 0))
                print(f"     победит: {winner} (ниже в modlist.txt)")
            for n in sorted(files)[: (999 if args.all else 6)]:
                print(f"       {n}")
            if not args.all and len(files) > 6:
                print(f"       … ещё {len(files) - 6}")
    else:
        print("  Ни одного.")

    print()
    print("⚠️ Конфликт по ИДЕНТИФИКАТОРАМ предметов этим прибором не ловится —")
    print("   он виден только в журнале запуска игры (это самый частый конфликт Конана).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
