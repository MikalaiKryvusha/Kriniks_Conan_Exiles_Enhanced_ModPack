# -*- coding: utf-8 -*-
"""workshop-swap.py — положить в библиотеку сборки новые версии модов Мастерской, скачанные steamcmd в отдельную папку.

Зачем (2026-11-13, переезд на 3.1.0, KUMM план 53 шаг 3): на переезде 3.0.1 (план 33 шаг 4) перекладка шла руками — для каждого мода
три перемещения, и у правленого нами мода (KRINIK MODIFIED) новый пак автора идёт не в библиотеку, а в оригиналы сборщика
`devkit/patch-mod-asset.py`. Руками это легко перепутать: новый пак автора поверх нашего правленого — правка молча пропадает.

Что делает по каждому id (мод находится в modpack.json по `workshopId`):
  * мод `_workshop/<id>` — старая папка библиотеки → `OLD/_workshop-<метка>/<id>`, новая → `_workshop/<id>`;
  * мод `_krinik-modified/<id>` с рецептом `krinikBuild` — оригинал `_patch-originals/<Контейнер>.pak` → `<Контейнер>.<метка>.pak`, новый пак
    автора → `_patch-originals/<Контейнер>.pak`; собранный нами пак в библиотеке не трогается — его пересобирает
    `devkit/rebuild-krinik-paks.py --only <Контейнер> --against-original`.
Перемещение, а не копия: всё на одном томе D:, места не требует. Ничего не перезаписывает: занятое место назначения — остановка до любого шага.

    python -I -X utf8 workshop-swap.py <папка content/440900> <метка> <id> [<id> …]            # план: что куда, без действий
    python -I -X utf8 workshop-swap.py <папка content/440900> <метка> <id> [<id> …] --apply    # выполнить
Код 0 — сделано (или план чист), 1 — остановка.
[NOT-TESTED]
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.dirname(HERE)
ORIGINALS = r"D:\work\ai_sandbox\ConanExiles\_library\_patch-originals"   # тот же, что в devkit/patch-mod-asset.py


def library_root(manifest):
    lib = manifest.get("library", "")
    return os.path.normpath(lib if os.path.isabs(lib) else os.path.join(PACK, lib))


def plan(new_root, tag, ids):
    manifest = json.load(open(os.path.join(PACK, "modpack.json"), encoding="utf-8"))
    lib = library_root(manifest)
    by_id = {str(m.get("workshopId")): m for m in manifest["mods"] if m.get("workshopId")}
    moves, problems = [], []
    for wid in ids:
        mod = by_id.get(wid)
        new_dir = os.path.join(new_root, wid)
        if not mod:
            problems.append(f"{wid}: нет мода с таким workshopId в modpack.json")
            continue
        if not os.path.isdir(new_dir) or not os.listdir(new_dir):
            problems.append(f"{wid} ({mod['name']}): нет новой папки {new_dir}")
            continue
        folder = (mod.get("source") or {}).get("folder", "").replace("/", os.sep)
        if folder.startswith("_workshop" + os.sep):
            old = os.path.join(lib, folder)
            moves.append((mod["name"], old, os.path.join(lib, "OLD", "_workshop-" + tag, wid)))
            moves.append((mod["name"], new_dir, old))
        elif folder.startswith("_krinik-modified" + os.sep):
            recipe = (mod.get("krinikBuild") or {}).get("args") or []
            if not recipe:
                problems.append(f"{wid} ({mod['name']}): правленый нами мод без рецепта krinikBuild — правку не переложить")
                continue
            container = recipe[0]
            new_pak = os.path.join(new_dir, container + ".pak")
            if not os.path.isfile(new_pak):
                problems.append(f"{wid} ({mod['name']}): в новой папке нет {container}.pak ({os.listdir(new_dir)})")
                continue
            orig = os.path.join(ORIGINALS, container + ".pak")
            moves.append((mod["name"], orig, os.path.join(ORIGINALS, f"{container}.{tag}.pak")))
            moves.append((mod["name"], new_pak, orig))
        else:
            problems.append(f"{wid} ({mod['name']}): источник «{folder}» — не Мастерская")
    # место назначения свободно у каждого шага (второй шаг пары занимает место, которое освобождает первый)
    freed = set()
    for name, src, dst in moves:
        if not os.path.exists(src):
            problems.append(f"{name}: нет источника {src}")
        if os.path.exists(dst) and os.path.normcase(dst) not in freed:
            problems.append(f"{name}: место занято {dst}")
        freed.add(os.path.normcase(src))
    return moves, problems


def main():
    args = [a for a in sys.argv[1:] if a != "--apply"]
    if len(args) < 3:
        print(__doc__)
        return 1
    new_root, tag, ids = args[0], args[1], args[2:]
    # an id twice made a «clean» plan whose second pair overwrote the archived original (judge D, B1, 2026-11-13) — refused before planning
    dup = sorted({i for i in ids if ids.count(i) > 1})
    if dup:
        print("ОСТАНОВКА: id повторяется: " + ", ".join(dup))
        return 1
    moves, problems = plan(new_root, tag, ids)
    for name, src, dst in moves:
        print(f"{name}: {src}  ->  {dst}")
    if problems:
        print("ОСТАНОВКА:")
        for p in problems:
            print("  * " + p)
        return 1
    if "--apply" not in sys.argv:
        print(f"план чист: {len(moves)} перемещений; выполнить — тот же вызов с --apply")
        return 0
    done = 0
    for name, src, dst in moves:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        # os.rename, not shutil.move: on Windows it FAILS on a taken destination and across volumes, where shutil.move silently overwrites a file,
        # nests a folder into an existing one, or turns into copy-and-delete (judge D, B1 / B2)
        try:
            os.rename(src, dst)
        except OSError as e:
            print(f"ОСТАНОВКА на шаге {done + 1} из {len(moves)}: {name}: {src} -> {dst}: {e}")
            print("сделанные шаги выше этой строки не откатаны — разобрать руками по выводу плана")
            return 1
        done += 1
    print(f"сделано: {done} перемещений")
    return 0


if __name__ == "__main__":
    sys.exit(main())
