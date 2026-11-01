# -*- coding: utf-8 -*-
"""build-mods-catalog.py -- каталог ИМЁН всех ассетов всех модов сборки.

ЗАЧЕМ. Сырой поиск строк по пакам в этой игре ВСЕГДА ложноотрицателен:
содержимое сжато Oodle, а библиотеки oo2core*.dll в поставке нет. Два вывода
проекта на этом уже погорели («камеру не трогает ни один мод», «Placeholder
Perk из самой игры»). Индекс каталога в .utoc при этом лежит ОТКРЫТЫМ ТЕКСТОМ,
поэтому ИМЕНА достаются с диска за минуту, без запуска игры.

Чем каталог окупился 2026-09-10:
  * назвал класс HUD Hosav поимённо (заказ владельца закрыт за один заход);
  * отсортировал подозреваемых перед делением сборки пополам, и перебор
    схлопнулся с шести запусков игры до двух (EXP-0076);
  * показал, что перковое окно подменяет ровно один мод из 44 - тот, что
    монтируется в ВАНИЛЬНЫЙ путь, а не в свою папку.

⚠️ ГРАНИЦА. Каталог отвечает, кто ЧТО ВЕЗЁТ. Он НЕ отвечает, кто ПОБЕДИЛ в
конкретной строке или на конкретном экране - это разные вопросы, и второй
решается журналом игры (who-overwrites-table.py) и выключением мода. Принять
первый ответ за второй - оплаченная ошибка, EXP-0077.

ПОЧЕМУ СКРИПТ, А НЕ ФАЙЛ В РЕПОЗИТОРИИ. Готовый каталог - это 15 МБ
производных данных, которые устаревают при первом же изменении сборки. В git
идёт команда, которая его пересоберёт, а сам файл живёт в _config/backup/
(эта папка в .gitignore). Один факт в одном месте: истина - паки, каталог -
её отпечаток.

    python build-mods-catalog.py
    grep -v "/Mods/" backup/mods-asset-catalog.txt    # кто лезет в ванильные пути
"""

import glob
import io
import os
import subprocess
import sys

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME_MODS = sandbox('Mods')
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "backup", "mods-asset-catalog.txt")

# Прибор живёт в движке KUMM, а не в паке: он про устройство контейнеров UE5 и
# переносим на любую игру. Разбор - researches/ue5-iostore-index/README.md.
INDEXER = r"D:\work\ai_sandbox\KUMM\researches\ue5-iostore-index\utoc-index.py"


def out(s):
    sys.stdout.write(s + "\n")


def main():
    for path, what in ((GAME_MODS, "папка модов"), (INDEXER, "индексатор")):
        if not os.path.exists(path):
            out("нет: %s (%s)" % (path, what))
            return 2

    paks = sorted(glob.glob(os.path.join(GAME_MODS, "*.pak")))
    if not paks:
        out("в папке модов нет ни одного .pak - каталог не собран")
        return 2

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    total = 0
    empty = []
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as dst:
        for p in paks:
            name = os.path.splitext(os.path.basename(p))[0]
            r = subprocess.run([sys.executable, INDEXER, p],
                               capture_output=True)
            lines = r.stdout.decode("utf-8", "replace").splitlines()
            # ⚠️ ИМЯ ПАКА ПРИПИСЫВАЕТСЯ К КАЖДОЙ СТРОКЕ, и в этом весь смысл.
            # Индексатор печатает голые пути; без приписывания каталог отвечает
            # «такой ассет в сборке есть» и НЕ отвечает «у кого он», а нужен
            # всегда второй ответ.
            n = 0
            for ln in lines:
                if not ln.strip():
                    continue
                dst.write("%s :: %s\n" % (name, ln))
                n += 1
            if n == 0:
                empty.append(name)
            total += n
            out("%-45s %6d" % (name, n))

    out("")
    out("паков: %d, строк: %d -> %s" % (len(paks), total, OUT))
    if empty:
        # Пустой пак - не обязательно поломка (бывают паки-заглушки), но и не
        # норма: молча пропущенный контейнер один раз уже превратил каталог из
        # 44 паков в каталог из одного.
        out("⚠ БЕЗ ЕДИНОГО ПУТИ (%d): %s" % (len(empty), ", ".join(empty)))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
