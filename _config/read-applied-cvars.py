#!/usr/bin/env python3
"""
Снимает ШТАТНЫЕ значения cvar-ов прямо из журнала игры.

[TESTED: 2026-09-08 · прогон на ConanSandbox.log от 07.09 дал 58 значений dw.*
из секции /Script/ConanSandbox.SystemSettings, плюс движковые секции.]

ПОЧЕМУ ЭТО ГЛАВНЫЙ ПРИБОР СБОРКИ. Игра при запуске печатает в свой журнал, из КАКОЙ
СЕКЦИИ какого файла она применила настройки и КАКИЕ ИМЕННО значения выставила:

    LogConfig: Applying CVar settings from Section [/Script/ConanSandbox.SystemSettings] File [Engine]
    LogConfig: Set CVar [[dw.AILOD1Distance:3000]]
    ...

Отсюда сразу три вещи, которые иначе пришлось бы добывать догадками:

1. АДРЕС СЕКЦИИ доказан самой игрой, а не чужими рецептами: собственные переменные
   Конана читаются из [/Script/ConanSandbox.SystemSettings], и читаются ИЗ Engine.ini
   ("File [Engine]"). Значит наши правки туда доедут.
2. ШТАТНЫЕ ЗНАЧЕНИЯ - настоящие, а не выдуманные. Без них любая правка это шаг из
   неизвестной точки: непонятно, подняли мы значение или опустили.
3. ПОДТВЕРЖДЕНИЕ ПРАВКИ. Прогнать скрипт ДО и ПОСЛЕ правки и сравнить - самый дешёвый
   способ доказать, что строка доехала, и он не требует консоли.

ОГОВОРКА, БЕЗ КОТОРОЙ ПРИБОР ВРЁТ. Журнал показывает, что применено ПРИ СТАРТЕ. Значение,
которое игра переставит позже (командой из консоли при входе в мир или применением настроек
графики), здесь не видно. Для таких имён журнал говорит "что было", а не "что есть", и
последнее слово остаётся за консолью.

Запуск:
    python _config/read-applied-cvars.py              - все dw.*
    python _config/read-applied-cvars.py --all        - вообще все секции и значения
    python _config/read-applied-cvars.py --prefix r.  - по префиксу
Пишет также _config/cvars-applied.txt для сравнения между прогонами.
"""
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PACK = Path(__file__).resolve().parent.parent
OUT = PACK / "_config" / "cvars-applied.txt"
LOG_REL = "ConanSandbox/Saved/Logs/ConanSandbox.log"

SECTION = re.compile(r"Applying CVar settings from Section \[([^\]]+)\] File \[([^\]]+)\]")
SETCVAR = re.compile(r"Set CVar \[\[([A-Za-z0-9_.]+):([^\]]*)\]\]")


def game_log():
    data = json.loads((PACK / "targets.json").read_text(encoding="utf-8"))
    for t in data.get("targets", []):
        if t.get("enabled", True):
            return Path(t["path"]) / LOG_REL
    raise SystemExit("В targets.json нет включённых целей")


def main():
    show_all = "--all" in sys.argv
    prefix = "dw."
    if "--prefix" in sys.argv:
        prefix = sys.argv[sys.argv.index("--prefix") + 1]

    log = game_log()
    if not log.exists():
        raise SystemExit(f"Журнал не найден: {log}\nЗапусти игру хотя бы раз.")

    section, order = None, []
    by_section = {}
    for line in log.read_text(encoding="utf-8", errors="ignore").splitlines():
        m = SECTION.search(line)
        if m:
            section = f"[{m.group(1)}] из файла {m.group(2)}"
            if section not in by_section:
                by_section[section] = []
                order.append(section)
            continue
        m = SETCVAR.search(line)
        if m and section:
            by_section[section].append((m.group(1), m.group(2)))

    lines, shown = [], 0
    for sec in order:
        pairs = by_section[sec]
        if not show_all:
            pairs = [p for p in pairs if p[0].startswith(prefix)]
        if not pairs:
            continue
        lines.append(f"\n=== {sec} — {len(pairs)} значений")
        for name, val in pairs:
            lines.append(f"    {name} = {val}")
            shown += 1

    text = (f"Штатные значения, применённые игрой при старте.\n"
            f"Журнал: {log}\n"
            f"Фильтр: {'все' if show_all else prefix}\n"
            + "\n".join(lines) + "\n")
    OUT.write_text(text, encoding="utf-8")
    print(text)
    print(f"значений: {shown}; записано в {OUT.name}")
    if not shown:
        print("НИЧЕГО НЕ НАЙДЕНО — проверь фильтр или свежесть журнала")


if __name__ == "__main__":
    main()
