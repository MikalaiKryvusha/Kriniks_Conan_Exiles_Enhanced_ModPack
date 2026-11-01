# -*- coding: utf-8 -*-
"""smoke-loader.py — дымовая проверка загрузчика модов по журналу игры: каждый пак из modlist.txt смонтирован, контроллеры модов
активны, слияния таблиц без ошибок «… is null» — с названием мода.

Зачем (2026-10-26, слово владельца «моды, которые мы поставили, нужно бы протестировать в игре, хотя бы smoke»): «меню живое» и
«СБОРКА: моды 64/64» говорят, что паки ЛЕГЛИ, но не что каждый мод ЗАПУСТИЛСЯ. Игра пишет на каждый мод `AddActiveModControllerClass`
(контроллер мода поднят) и после него — его слияния таблиц; ошибка слияния идёт сразу за контроллером своего мода.

    python -I -X utf8 smoke-loader.py [журнал]          # по умолчанию — ConanSandbox.log установки из targets.json
Код 0 — все паки смонтированы; 1 — есть несмонтированные.
[NOT-TESTED]
"""
import collections, os, re, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from game_target import sandbox  # noqa: E402  путь игры — одно место, targets.json (EXP-0329)


def main():
    log = sys.argv[1] if len(sys.argv) > 1 else sandbox("Saved", "Logs", "ConanSandbox.log")
    modlist = [l.strip() for l in open(sandbox("Mods", "modlist.txt"), encoding="utf-8-sig") if l.strip()]
    paks = [os.path.splitext(os.path.basename(l.replace("*", "")))[0] for l in modlist]
    text = open(log, encoding="utf-8", errors="replace").read().replace("\r", "")
    mounted = set(re.findall(r"ExtractedMods/([^/\s]+?)-Windows\.pak", text))
    controllers = collections.OrderedDict()
    merge_err = collections.Counter()
    last = None
    for line in text.split("\n"):
        m = re.search(r"AddActiveModControllerClass: /Game/(?:Mods|ModsShared)/([^/]+)/", line)
        if m:
            last = m.group(1)
            controllers[last] = controllers.get(last, 0) + 1
        elif "MergeDataTables - " in line and "is null" in line:
            merge_err[last] += 1
    miss = [p for p in paks if p not in mounted]
    print("паков в modlist: %d · смонтировано: %d · не смонтированы: %s" % (len(paks), len(paks) - len(miss), ", ".join(miss) or "нет"))
    print("контроллеров модов поднято: %d" % len(controllers))
    for c, n in controllers.items():
        flag = ("  ОШИБКА СЛИЯНИЯ ×%d" % merge_err[c]) if merge_err[c] else ""
        dup = (" (поднят %d раз)" % n) if n > 1 else ""
        print("  %s%s%s" % (c, dup, flag))
    return 1 if miss else 0


if __name__ == "__main__":
    sys.exit(main())
