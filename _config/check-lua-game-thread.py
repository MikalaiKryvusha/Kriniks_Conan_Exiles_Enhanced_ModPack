# -*- coding: utf-8 -*-
"""check-lua-game-thread.py — страж: включённые Lua-моды UE4SS не трогают рабочий поток задержек.

Зачем (2026-10-28, KUMM bugs/64 соседний пункт — падение в руках владельца): `ExecuteWithDelay` / `LoopAsync` / `ExecuteAsync` зовут
функцию мода в рабочем потоке UE4SS, а оттуда — `ExecuteInGameThread`; два потока делят одно состояние Lua, и при частых событиях
(быстрая стрельба из лука) игра падает: «Error: [Lua::Registry::get_function_ref] Ref was not function», затем EXCEPTION_ACCESS_VIOLATION
со стеком из одних кадров UE4SS (28.10 20:06:55; тот же класс — 08.09, баг UE4SS #1180, EXP-0062). Урок был записан в моде камеры, но
KrinikArrowAim (ныне KrinikConanArchery) этой недели схему вернул: правило без стража не держит. Замена — отложенные действия игрового потока:
`ExecuteInGameThreadWithDelay`, `LoopInGameThreadWithDelay` (docs.ue4ss.com, Delayed Actions).

    python -I -X utf8 check-lua-game-thread.py            # моды игры с enabled.txt
    python -I -X utf8 check-lua-game-thread.py <папка>    # любая папка модов (исходники _unpacked)
Код 0 — чисто; 1 — найдены вызовы (файл:строка); 2 — нет папки.

@guard lua-game-thread
THREAD:         падение UE4SS при наложении рабочего потока задержек и игрового потока (быстрые повторяющиеся события)
PROVED-AGAINST: моды игры до раскатки 2026-10-28 (KrinikArrowAim 7 вызовов, мод камеры 12 и др.) — код 1, 31 вызов
GAP:            видит только имена вызовов; Lua, собранный строкой (load), и чужие DLL-моды не видит
ON-REAL-PATH:   NOT YET
[NOT-TESTED]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from game_target import GAME_DIR  # noqa: E402

BAD = re.compile(r"\b(ExecuteWithDelay|LoopAsync|ExecuteAsync)\s*\(")


def mods_dir():
    if len(sys.argv) > 1:
        return sys.argv[1], False
    return os.path.join(GAME_DIR, r"ConanSandbox\Binaries\Win64\ue4ss\Mods"), True


def main():
    root, only_enabled = mods_dir()
    if not os.path.isdir(root):
        print("нет папки", root)
        return 2
    hits = 0
    for mod in sorted(os.listdir(root)):
        d = os.path.join(root, mod)
        if not os.path.isdir(os.path.join(d, "Scripts")):
            continue
        if only_enabled and not os.path.exists(os.path.join(d, "enabled.txt")):
            continue
        for base, _, files in os.walk(os.path.join(d, "Scripts")):
            for f in files:
                if not f.endswith(".lua"):
                    continue
                p = os.path.join(base, f)
                for n, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                    code = line.split("--", 1)[0]
                    if BAD.search(code):
                        hits += 1
                        print("%s:%d: %s" % (os.path.relpath(p, root), n, line.strip()[:120]))
    print("вызовов рабочего потока: %d" % hits)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
