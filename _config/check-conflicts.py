#!/usr/bin/env python3
"""
Сталкивается ли наш Engine.ini с тем, что игра применяет САМА.

[NOT-TESTED]

ЗАЧЕМ. Наши настройки лежат в секции [SystemSettings]. Игра применяет свои из
ЧЕТЫРЁХ других секций, и та, где живёт её собственное добро
([/Script/ConanSandbox.SystemSettings]), в журнале идёт ПОСЛЕДНЕЙ. При равном
приоритете побеждает тот, кто применился позже. Значит любое имя, которое
встречается и у нас, и у игры, у нас НЕ РАБОТАЕТ - молча, без ошибки и без
следа. Симптом «правка не сработала» без всякой видимой причины.

Прибор отвечает на один вопрос: какие наши строки игра перебивает.

Что читает (ничего не меняет):
    _config/Engine.ini        - наш файл
    _config/cvars-applied.txt - что игра применила и из какой секции
                                (снимок журнала, обновляется read-applied-cvars.py)

Запуск:
    python _config/check-conflicts.py        - код 0, если столкновений нет
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OURS = os.path.join(HERE, "..", "_unpacked", "KrinikConanGraphics", "Engine.ini")  # мод графики, с 2026-10-30
APPLIED = os.path.join(HERE, "cvars-applied.txt")

# Секция, в которой лежат НАШИ строки.
OUR_SECTION = "[SystemSettings]"


def read_ours():
    """Имена cvar-ов из нашей секции, в порядке файла."""
    out, inside = [], False
    for line in open(OURS, encoding="utf-8", errors="replace"):
        s = line.strip()
        if s.startswith("["):
            inside = (s == OUR_SECTION)
            continue
        if not inside or not s or s.startswith(";") or "=" not in s:
            continue
        name, _, value = s.partition("=")
        out.append((name.strip(), value.strip()))
    return out


def read_applied():
    """{имя: (значение, секция, порядковый номер секции)} - что применила игра."""
    out, sec, order = {}, None, -1
    for line in open(APPLIED, encoding="utf-8", errors="replace"):
        m = re.match(r"=== (\[.*?\]) из файла (\w+)", line)
        if m:
            sec = m.group(1)
            order += 1
            continue
        m2 = re.match(r"\s+(\S+)\s*=\s*(.*)", line)
        if m2 and sec:
            out[m2.group(1).lower()] = (m2.group(2).strip(), sec, order)
    return out


def main():
    ours = read_ours()
    applied = read_applied()
    if not applied:
        print("cvars-applied.txt пуст — сперва python _config/read-applied-cvars.py")
        return 2

    # Порядковый номер НАШЕЙ секции в журнале. Её там нет (файла ещё не было,
    # когда снимался журнал), поэтому считаем по правилу UE: [SystemSettings]
    # применяется РАНО, до игровых [/Script/*.SystemSettings]. То есть все
    # столкновения игра выигрывает. Это ГИПОТЕЗА - проверяется первым запуском.
    print(f"наш файл:   {OURS}")
    print(f"наша секция: {OUR_SECTION}  (в журнале её ещё нет — файл написан после снимка)")
    print(f"журнал игры: {len(applied)} применённых имён\n")

    clash, clean = [], []
    for name, value in ours:
        hit = applied.get(name.lower())
        if hit:
            clash.append((name, value, hit))
        else:
            clean.append((name, value))

    if clash:
        print("!!! СТОЛКНОВЕНИЯ — игра ставит эти имена САМА, и её секция применяется ПОЗЖЕ:")
        for name, ourv, (gamev, sec, _) in clash:
            verdict = "то же значение" if ourv.lower() == gamev.lower() else "НАШЕ ЗНАЧЕНИЕ ПРОИГРЫВАЕТ"
            print(f"  {name}")
            print(f"      наше {ourv!r}  |  игра {gamev!r}  из {sec}")
            print(f"      -> {verdict}")
        print()
    else:
        print("Столкновений нет: ни одно наше имя игра не ставит сама.\n")

    print(f"Не трогается игрой ({len(clean)}) — эти строки должны примениться:")
    for name, value in clean:
        print(f"  {name} = {value}")

    print(f"\nИТОГО: наших строк {len(ours)}, столкновений {len(clash)}, чистых {len(clean)}")
    if clash:
        print("\nЧТО ДЕЛАТЬ: перенести столкнувшиеся строки в секцию")
        print("[/Script/ConanSandbox.SystemSettings] — она применяется последней,")
        print("и тогда побеждаем мы. Проверяется журналом после первого запуска.")
    return 1 if clash else 0


if __name__ == "__main__":
    sys.exit(main())
