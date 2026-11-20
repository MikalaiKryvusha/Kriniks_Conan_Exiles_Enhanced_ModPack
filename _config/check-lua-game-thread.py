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
THREAT:         падение UE4SS при наложении Lua из чужого потока (задержки рабочего потока, обработчики клавиш) и игрового потока одного мода
PROVED-AGAINST: моды игры до раскатки 2026-10-28 (KrinikArrowAim 7 вызовов, мод камеры 12 и др.) — код 1, 31 вызов; 2026-11-07 — моды игры
                до правки bugs/85 (KrinikConanArchery E/Q/ЛКМ, KrinikConanUI, KrinikConanCamera) — код 1, вызовы RegisterKeyBind перечислены;
                2026-11-18 21:1x — KrinikConanUI коммита bddc495 (до правки bugs/85): код 1, все 5 привязок, вместе с `pcall(RegisterKeyBind, …)`,
                которую прежний шаблон «имя(» пропускал
GAP:            видит только имена вызовов; Lua, собранный строкой (load), и чужие DLL-моды не видит; NotifyOnNewObject, рождённый в потоке
                загрузки, не видит
ON-REAL-PATH:   2026-11-18 21:1x — установленная сборка D:\Games\Conan Exiles 3.1.1 (моды с enabled.txt): код 0
[TESTED: 2026-11-18 · старое дерево bddc495 — 5 находок, установка — 0, _unpacked — 15 находок только в выключенных зондах и папке HosavRU вне манифеста]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from game_target import GAME_DIR  # noqa: E402

# 2026-11-07 (KUMM bugs/85, падение в руках владельца при убийстве беса стрелой): обработчик RegisterKeyBind / RegisterKeyBindAsync — тоже Lua
# в чужом потоке. UE4SS зовёт его из своего цикла событий (UE4SSProgram::update → Input::Handler::process_event), а перехваты RegisterHook и
# пачка отложенных действий игрового потока идут БЕЗ общего замка (LuaMod.cpp сборки 8333063, строки 4017–4029; все потоки мода — lua_newthread
# одного состояния). Левая кнопка на каждом выстреле совпала с переносом стрел на труп — куча Lua испорчена. Клавиши — событиями игрового
# потока (InpActEvt_AnyKey героя-блюпринта, события своих окон).
# Имя ловится как идентификатор, а не как «имя(»: `pcall(RegisterKeyBind, Key.TAB, …)` хаб-контроллера до правки bugs/85 страж пропускал
# (судья 2026-11-18, круг 2, находка 2: копия того файла — «вызовов 0»). Комментарии (строчные и блочные --[[ ]]) и строковые литералы вырезаются
# до поиска, иначе упоминания в шапках модулей становятся ложными находками.
BAD = re.compile(r"\b(ExecuteWithDelay|LoopAsync|ExecuteAsync|RegisterKeyBind|RegisterKeyBindAsync)\b")
BLOCK_COMMENT = re.compile(r"--\[(=*)\[.*?\]\1\]", re.S)
STRING = re.compile(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')


def code_lines(path):
    """Строки файла без комментариев и строк; блочный комментарий заменён переводами строк, номера строк те же."""
    text = open(path, encoding="utf-8", errors="replace").read()
    text = BLOCK_COMMENT.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    for line in text.split("\n"):
        yield STRING.sub('""', line).split("--", 1)[0], line


def script_dirs(d):
    """Папка скриптов мода: <мод>\\Scripts у мода игры, <мод>\\ue4ss\\Scripts у исходника _unpacked (судья 2026-11-18, находка 7: такие моды
    при запуске на _unpacked пропускались молча)."""
    return [p for p in (os.path.join(d, "Scripts"), os.path.join(d, "ue4ss", "Scripts")) if os.path.isdir(p)]


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
        if only_enabled and not os.path.exists(os.path.join(d, "enabled.txt")):
            continue
        for scripts in script_dirs(d):
            for base, _, files in os.walk(scripts):
                for f in files:
                    if not f.endswith(".lua"):
                        continue
                    p = os.path.join(base, f)
                    for n, (code, line) in enumerate(code_lines(p), 1):
                        if BAD.search(code):
                            hits += 1
                            print("%s:%d: %s" % (os.path.relpath(p, root), n, line.strip()[:120]))
    print("вызовов рабочего потока: %d" % hits)
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main())
