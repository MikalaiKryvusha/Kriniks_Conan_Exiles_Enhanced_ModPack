#!/usr/bin/env python3
"""
Считает, ЧЕМ ЗАНЯТ МИР, по собственному журналу событий игры в сохранении.

[TESTED: 2026-09-09 · прогон на Game_0.db дал 205 событий, из них не про живность - 0.]

ЗАЧЕМ. Владелец просит живой мир (идея 02 в KUMM, конспект docs/10-жизнь-мира.md).
Прежде чем что-то делать, нужна ТОЧКА ОТСЧЁТА, измеренная, а не почувствованная. Она
лежит открыто: сохранение Конана - это база SQLite, и в ней есть таблица game_events,
куда игра сама пишет свои мировые события с координатами и типом:

    CREATE TABLE game_events(worldTime, serverTime, x, y, z, eventType, objectId,
                             objectName, ownerId, ownerName, ...)

Первый же прогон ответил на вопрос, ради которого писался прибор: за всё сохранение
205 событий, и почти все - Wildlife_Vulture_Pecking, Wildlife_Vulture_Idling и птицы.
Ни одного события между фракциями, ни одного перемещения, ни одной причины и следствия.
Вся "жизнь" ванильного мира - это клюющие стервятники.

ЧЕМ ЭТО СТАНЕТ ПОТОМ. Тот же прогон - критерий приёмки идеи 02: "не меньше 20 событий,
НЕ связанных с живностью, за игровой день". Прибор считает ровно эту цифру, поэтому
"мир ожил" перестаёт быть ощущением и становится числом, сравнимым с базой.

ОГОВОРКИ, БЕЗ КОТОРЫХ ПРИБОР ВРЁТ:
  * журнал пишет то, что игра САМА считает событием. Наши будущие отряды в него не
    попадут, пока мод не начнёт писать туда же или в свой файл, - тогда сравнивать
    придётся два источника, и об этом надо помнить;
  * eventType - число без словаря. Расшифровки у нас нет, поэтому типы печатаются как
    есть. Имя объекта информативнее;
  * база читается ТОЛЬКО КОПИЕЙ. Живое сохранение не открывается никогда, даже на
    чтение: игра может держать его открытым, и блокировка стоит дороже любой цифры.

Запуск:
    python _config/read-world-events.py                 - сводка по сохранению по умолчанию
    python _config/read-world-events.py --db <файл>     - другая база (в т.ч. бэкап)
    python _config/read-world-events.py --top 20        - длиннее список имён
    python _config/read-world-events.py --list          - все события подряд, по времени
"""

import argparse
import datetime as dt
import os
import shutil
import sqlite3
import sys
import tempfile

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
DEFAULT_DB = sandbox('Saved', 'Game_0.db')

# Признак "это живность, а не событие мира". Умышленно грубый и явный: лучше
# недосчитать интересного, чем записать стервятника в жизнь мира.
WILDLIFE_PREFIXES = ("Wildlife_",)
WILDLIFE_HINTS = ("vulture", "bird", "skeleton", "imp", "kappa", "dog", "hyena",
                  "crocodile", "shalebeak", "rocknose", "spider", "wolf")


def is_wildlife(name: str) -> bool:
    """True = это НЕ событие мира (живность, пустое или служебная запись).

    ⚠️ Про служебные записи - урок первого же прогона. В журнале 92 строки с именем
    ровно "0" и типом 172, и их ровно столько же, сколько строк в actor_position.
    Это не событие, а внутренняя запись игры. Первая версия прибора посчитала их
    "жизнью мира" и показала 92 вместо нуля - то есть прибор врал в ту самую сторону,
    в которую нам хочется верить. Отсюда правило: имя из одних цифр событием не считаем.
    """
    if not name or not name.strip():
        return True                      # пустое имя - не событие мира
    if name.strip().isdigit():
        return True                      # служебная запись игры, см. выше
    if name.startswith(WILDLIFE_PREFIXES):
        return True
    low = name.lower()
    return any(h in low for h in WILDLIFE_HINTS)


def human_time(value) -> str:
    """worldTime похож на unix-время. Если не похоже - печатаем как есть."""
    try:
        n = int(value)
        if 1_000_000_000 < n < 4_000_000_000:
            return dt.datetime.fromtimestamp(n).strftime("%Y-%m-%d %H:%M")
    except (TypeError, ValueError):
        pass
    return str(value)


def open_copy(path: str) -> sqlite3.Connection:
    if not os.path.isfile(path):
        sys.exit(f"базы нет: {path}")
    tmp = os.path.join(tempfile.gettempdir(), "conan_world_events.db")
    shutil.copy(path, tmp)               # живое сохранение не трогаем никогда
    return sqlite3.connect(tmp)


def main() -> int:
    ap = argparse.ArgumentParser(description="Сводка мировых событий из сохранения Конана")
    ap.add_argument("--db", default=DEFAULT_DB)
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--list", action="store_true", help="все события подряд")
    args = ap.parse_args()

    con = open_copy(args.db)
    if not con.execute("select name from sqlite_master where name='game_events'").fetchone():
        sys.exit("в этой базе нет таблицы game_events - это сохранение другой игры?")

    rows = con.execute(
        "select worldTime, eventType, objectName, x, y, z from game_events order by worldTime"
    ).fetchall()

    print(f"База: {args.db}")
    print(f"Событий всего: {len(rows)}")
    if not rows:
        return 0

    print(f"Период: {human_time(rows[0][0])} -> {human_time(rows[-1][0])}")

    alive = [r for r in rows if not is_wildlife(r[2])]
    print()
    print(f"  живность и пустые:  {len(rows) - len(alive):>5}")
    print(f"  СОБЫТИЯ МИРА:       {len(alive):>5}   <- вот эта цифра и есть мера жизни")

    by_name = {}
    for _, _, name, *_ in rows:
        by_name[name or "(без имени)"] = by_name.get(name or "(без имени)", 0) + 1
    print()
    print("Чаще всего фигурируют:")
    for name, n in sorted(by_name.items(), key=lambda kv: -kv[1])[:args.top]:
        mark = " " if is_wildlife(name if name != "(без имени)" else "") else "*"
        print(f"  {mark} {name[:52]:52} {n:>5}")

    by_type = {}
    for _, et, *_ in rows:
        by_type[et] = by_type.get(et, 0) + 1
    print()
    print("По типам (расшифровки типов у нас нет, печатаем как есть):")
    for et, n in sorted(by_type.items(), key=lambda kv: -kv[1]):
        print(f"    тип {str(et):>5}: {n}")

    if args.list:
        print()
        print("Все события по времени:")
        for wt, et, name, x, y, z in rows:
            print(f"  {human_time(wt)}  тип {str(et):>4}  {(name or '')[:40]:40} "
                  f"({x:.0f}, {y:.0f}, {z:.0f})")

    print()
    print("Строки со звёздочкой - НЕ живность. Их число сравнивается с критерием идеи 02.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
