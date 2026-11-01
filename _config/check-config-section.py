#!/usr/bin/env python3
"""[TESTED: 2026-09-08 · прогон на восстановленном экзешнике: строка найдена в UTF-16,
и среди /Script/ConanSandbox.* она единственный класс настроек - остальные 12 это
перечисления. Утверждение подагента подтверждено самой игрой.]

Проверка ОДНОГО утверждения: существует ли в игре секция конфига
/Script/ConanSandbox.SystemSettings. Утверждение пришло от подагента со ссылкой на
три внешних источника; здесь оно проверяется по самой игре.

ТОЛЬКО ЧТЕНИЕ. Файл открывается 'rb' и не пишется никуда."""
import re
from pathlib import Path

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
EXE = Path(sandbox('Binaries', 'Win64', 'ConanSandbox-Win64-Shipping.exe'))

NEEDLES = [
    "/Script/ConanSandbox.SystemSettings",
    "ConanSandbox.SystemSettings",
    "/Script/Engine.RendererSettings",
    "SystemSettings",
]

def main():
    raw = EXE.read_bytes()
    print(f"файл: {EXE.name}, {len(raw):,} байт\n")
    for n in NEEDLES:
        a = raw.count(n.encode("ascii"))
        w = raw.count(n.encode("utf-16-le"))
        mark = "НАЙДЕНО" if (a or w) else "нет"
        print(f"{mark:>8}  {n:<40} ascii:{a}  utf16:{w}")

    # Все строки вида /Script/ConanSandbox.<Что-то> - чтобы увидеть весь набор
    # конфигурационных классов игры, а не только искомый.
    print("\nвсе классы /Script/ConanSandbox.*:")
    pat = re.compile(rb"/Script/ConanSandbox\.[A-Za-z0-9_]{2,60}")
    found = set()
    for m in pat.finditer(raw):
        found.add(m.group().decode("ascii"))
    for m in pat.finditer(raw.decode("utf-16-le", "ignore").encode("latin-1", "ignore")):
        found.add(m.group().decode("ascii", "ignore"))
    for s in sorted(found):
        print("   ", s)
    if not found:
        print("    (ни одного)")

if __name__ == "__main__":
    main()
