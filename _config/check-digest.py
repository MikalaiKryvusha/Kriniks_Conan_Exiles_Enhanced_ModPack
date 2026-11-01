#!/usr/bin/env python3
"""
Проверка полноты конспекта dw.*: каждое имя из семьи обязано встречаться в её файле.

[TESTED: 2026-09-08 · прогон на шести готовых разделах дал 204 из 204 имён;
недописанные разделы честно показаны как "ещё пишется", а не как ноль.]

ЗАЧЕМ. Разделы конспекта пишут отдельные агенты, и каждый докладывает о себе сам.
Самоотчёт - это заявление, а не проверка: раздел, где пропущено пять имён из
шестидесяти трёх, выглядит совершенно целым при чтении, и ровно так знание тихо
теряется. Скрипт сверяет ФАЙЛ со списком имён, а не с обещанием.

Отдельно печатается число строк с пометкой [ИСТОЧНИК]. Это не оценка качества:
у dw.* открытых источников почти нет, и низкое число может быть честным. Но
РЕЗКИЙ разброс между семьями - повод посмотреть, не выдаёт ли автор догадки за
находки.

Запуск:
    python _config/check-digest.py
Код возврата 1, если хоть в одном ГОТОВОМ разделе не хватает имени.
"""
import json
import re
import sys
from pathlib import Path

# Консоль Windows отдаёт вывод в кодовой странице 1251, и кириллица в отчёте
# превращается в кашу. Переключаем поток сами, а не полагаемся на переменную
# окружения: следующая сессия её не поставит и решит, что сломан скрипт.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PACK = Path(__file__).resolve().parent.parent
FAMILIES = PACK / "_config" / "dw-families.json"
DIGEST = PACK / "docs" / "dw-cvars"


def main():
    data = json.loads(FAMILIES.read_text(encoding="utf-8"))
    fam, titles = data["families"], data["titles"]

    rows, missing_total, expected_total, found_total = [], 0, 0, 0
    pending = []

    for key, names in fam.items():
        if not names:
            continue
        expected_total += len(names)
        f = DIGEST / f"{key}.md"
        if not f.exists():
            pending.append(key)
            rows.append((key, len(names), None, None, "нет файла"))
            continue
        txt = f.read_text(encoding="utf-8")
        # Граница слова по краям: dw.Build не должен засчитываться за dw.BuildGhostAngle...
        found = [n for n in names
                 if re.search(r"(?<![A-Za-z0-9_.])" + re.escape(n) + r"(?![A-Za-z0-9_.])", txt)]
        gone = [n for n in names if n not in found]
        src = txt.count("[ИСТОЧНИК]")
        found_total += len(found)
        missing_total += len(gone)
        verdict = "ПОЛНО" if not gone else f"НЕ ХВАТАЕТ {len(gone)}"
        rows.append((key, len(names), len(found), src, verdict))
        if gone:
            rows.append(("", None, None, None, "   " + ", ".join(gone[:8])))

    print(f"{'семья':12} {'ждём':>5} {'в файле':>8} {'источников':>11}  вердикт")
    print("-" * 62)
    for key, exp, got, src, verdict in rows:
        if exp is None:
            print(verdict)
            continue
        g = "—" if got is None else str(got)
        s = "—" if src is None else str(src)
        print(f"{key:12} {exp:>5} {g:>8} {s:>11}  {verdict}")
    print("-" * 62)
    print(f"{'ИТОГО':12} {expected_total:>5} {found_total:>8}")
    if pending:
        print(f"\nещё не написаны: {', '.join(pending)}")
    if missing_total:
        print(f"\nПРОПУЩЕНО ИМЁН: {missing_total} — конспект неполон")
        return 1
    if pending:
        print("\nв готовых разделах пропусков нет")
        return 0
    print("\nконспект полон: все имена на месте")
    return 0


if __name__ == "__main__":
    sys.exit(main())
