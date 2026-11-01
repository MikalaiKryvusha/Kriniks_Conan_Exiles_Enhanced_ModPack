# -*- coding: utf-8 -*-
"""who-overwrites-table.py -- кто из модов переписывает строки таблиц игры.

ЗАЧЕМ. Вопрос владельца 2026-09-10: «кто вызывает Placeholder Perk?» Раньше на
такие вопросы отвечали сырым поиском строк по пакам - и это ВСЕГДА
ложноотрицательно: содержимое паков сжато Oodle. Офлайн-каталог имён отвечает,
КТО ВЕЗЁТ таблицу, но не отвечает, КТО ПОБЕДИЛ в конкретной строке. Победителя
называет только игра, и она это печатает сама:

    AModController::MergeDataTables - Found existing table entry for
        /Game/Systems/Progression/DT_AttributeSystem.DT_AttributeSystem
        with RowName: 7, overwriting.

КАК ПРИПИСЫВАЕТСЯ МОД. Имени мода в строке слияния НЕТ. Но игра регистрирует
контроллеры модов по очереди:

    AddActiveModControllerClass: /Game/Mods/<Мод>/<...>_ModController_C

и все слияния до следующей регистрации сделаны ТЕМ мод-контроллером. То есть
приписывание идёт по ПОРЯДКУ СТРОК в журнале, а не по догадке.

⚠️ ГРАНИЦА, КОТОРУЮ ПРИБОР НЕ ПЕРЕХОДИТ. Это приписывание по соседству в
журнале, а не подпись автора у каждой строки. Оно верно, пока игра
регистрирует контроллер ПЕРЕД тем, как тот сливает свои таблицы. Признак, что
допущение сломалось: слияния, случившиеся ДО первой регистрации мода, - они
показываются отдельной группой «до первого мода (ванильные DLC)», и если туда
попадает что-то модовское, выводу верить нельзя.

КОМАНДЫ:
    python who-overwrites-table.py                  сводка по всем таблицам
    python who-overwrites-table.py Attribute        только таблицы по подстроке
    python who-overwrites-table.py Perk --rows      ещё и имена строк
"""

import io
import os
import re
import sys
from collections import OrderedDict, defaultdict

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME_LOG = sandbox('Saved', 'Logs', 'ConanSandbox.log')

RE_CTRL = re.compile(r"AddActiveModControllerClass: /Game/(?:Mods|DLC)/([^/]+)/")
RE_MERGE = re.compile(
    r"MergeDataTables - Found existing table entry for /Game/([^\s.]+)"
    r"[^\s]*\s+with RowName:\s*(.+?),\s*overwriting\.")


def out(s):
    sys.stdout.write(s + "\n")


def scan(path):
    """Возвращает [(мод, таблица, строка)] в порядке журнала."""
    current = "<до первого мода (ванильные DLC)>"
    hits = []
    with io.open(path, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_CTRL.search(line)
            if m:
                current = m.group(1)
                continue
            m = RE_MERGE.search(line)
            if m:
                hits.append((current, m.group(1), m.group(2)))
    return hits


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    show_rows = "--rows" in sys.argv
    needle = args[0].lower() if args else None

    if not os.path.exists(GAME_LOG):
        out("журнала игры нет: " + GAME_LOG)
        return 2

    hits = scan(GAME_LOG)
    if not hits:
        # Пустота тут ЗНАЧИМА: журнал есть, а слияний ноль - значит либо игра не
        # доходила до мира, либо формат строки сменился с патчем. И то и другое
        # надо увидеть, а не принять за «конфликтов нет».
        out("НИ ОДНОГО слияния таблиц в журнале. Игра не доходила до мира,")
        out("или формат строки сменился - вывод не делать.")
        return 2

    if needle:
        hits = [h for h in hits if needle in h[1].lower()]
        if not hits:
            out("по подстроке '%s' слияний нет" % needle)
            return 1

    # таблица -> мод -> список строк
    by_table = OrderedDict()
    for mod, table, row in hits:
        by_table.setdefault(table, defaultdict(list))[mod].append(row)

    out("слияний всего: %d, таблиц: %d" % (len(hits), len(by_table)))
    out("")
    for table, mods in sorted(by_table.items(), key=lambda kv: -sum(len(v) for v in kv[1].values())):
        total = sum(len(v) for v in mods.values())
        # СПОРНАЯ таблица - та, за которую взялись ДВОЕ и больше. Именно там
        # рождаются пустые слоты: побеждает тот, кто позже, а проигравший
        # оставляет дыру в чужой раскладке.
        mark = "  ⚠ СПОРНАЯ" if len(mods) > 1 else ""
        out("== %s  (%d перезаписей, модов %d)%s" % (table, total, len(mods), mark))
        for mod, rows in sorted(mods.items(), key=lambda kv: -len(kv[1])):
            out("    %-45s %d" % (mod, len(rows)))
            if show_rows:
                for r in rows[:40]:
                    out("        " + r)
                if len(rows) > 40:
                    out("        ... ещё %d" % (len(rows) - 40))
        out("")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
