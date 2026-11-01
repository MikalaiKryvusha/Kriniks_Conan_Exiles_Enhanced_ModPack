# -*- coding: utf-8 -*-
"""bisect-zoom.py -- деление сборки пополам для бага 09 (зум камеры уезжает).

ЗАЧЕМ. Симптом появился 09.09.2026, когда в сборку встали 36 модов Мастерской;
до них, с одним нашим модом камеры, предел зума работал (слово владельца).
Виновника ищем делением пополам: это единственный метод, который не зависит
ни от каких догадок, а все догадки вечера 09.09 уже опровергнуты измерением
(bugs/09_conan_zoom_runaway.md).

ПОЧЕМУ ПРАВИМ modlist.txt, А НЕ modpack.json + раскатку. Игра монтирует ровно
то, что перечислено в modlist.txt (измерено 09.09: с одной убранной строкой
смонтировалось 43 из 43). Значит итерация перебора стоит правки текстового
файла, а не копирования 44 модов в игру. Полная раскатка возвращает modlist.txt
из манифеста, поэтому откат гарантирован в любом случае; плюс здесь свой
снимок (--restore).

ГРАНИЦА, КОТОРУЮ ПРИБОР НЕ ПЕРЕХОДИТ: он трогает РОВНО ОДИН файл, modlist.txt.
Ни один .pak не удаляется и не переименовывается — выключение мода это строка,
которую игра не прочитала (AGENT_GUIDE.md -> границы работы рядом с папкой игры,
оплачено багом 02).

КОМАНДЫ:
    python bisect-zoom.py list                 что сейчас включено и что подозревается
    python bisect-zoom.py off A                выключить половину A, оставить B
    python bisect-zoom.py off B                наоборот
    python bisect-zoom.py off <pak,pak,...>    выключить поимённо
    python bisect-zoom.py only <pak,pak,...>   оставить из подозреваемых только эти
    python bisect-zoom.py restore              вернуть полный modlist из снимка
    python bisect-zoom.py verdict              прочитать журнал и назвать число

ВЕРДИКТ СТАВИТСЯ ЧИСЛОМ, А НЕ ГЛАЗОМ. Мод камеры раз в секунду печатает в
UE4SS.log строку "ЗУМ: штанга=... | цель=...". Предел владельца — zoom_max в
config.lua (сейчас 1000). Если максимум цели за сессию не ушёл выше порога,
предел держится; если ушёл в тысячи — убежал. Порог с запасом, потому что игра
на переходах кратко ставит свои значения.
"""

import sys
import os
import re
import shutil
import io

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME = GAME_DIR
MODLIST = os.path.join(GAME, r"ConanSandbox\Mods\modlist.txt")
UE4SS_LOG = os.path.join(GAME, r"ConanSandbox\Binaries\Win64\ue4ss\UE4SS.log")

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOT = os.path.join(HERE, "backup", "modlist.full.txt")

# ПОДОЗРЕВАЕМЫЕ — только моды Мастерской. Семь паков с Nexus и
# MrS_LevelAndAttributeOverhaul стояли 08.09, когда зум работал, поэтому они
# вне круга и в делении не участвуют. Список берётся из СНИМКА полного
# modlist.txt, а не из манифеста: снимок — это то, что игра действительно
# монтировала в сломанном состоянии.
NOT_SUSPECT = [
    "MoreKatanas.pak",
    "ResourceStimulusPackage.pak",
    "CorpseStripper.pak",
    "BossesMyNewBesties.pak",
    "MyAUThrallArmy.pak",
    "IdeaPoet_EditAppearance.pak",
    "IMM_WAR.pak",
    "MrS_LevelAndAttributeOverhaul.pak",
]

# Порог «цель уехала». Предел владельца 1000; на переходах игра кратко ставит
# свои 230/280/430, поэтому порог берём с большим запасом — измеренные
# убегания были 4260, 5620, 5660, 6220, то есть разница не пограничная.
RUNAWAY = 1500.0


def out(s):
    # Печать не через argv: кириллица в аргументе портится консольной
    # кодировкой ещё до запуска (AGENT_GUIDE.md -> текст ходит файлами).
    sys.stdout.write(s + "\n")


def read_lines(path):
    with io.open(path, "r", encoding="utf-8-sig") as f:
        return [ln.strip() for ln in f if ln.strip()]


def write_lines(path, lines):
    with io.open(path, "w", encoding="utf-8", newline="\r\n") as f:
        for ln in lines:
            f.write(ln + "\n")


def ensure_snapshot():
    """Снимок полного modlist делается ОДИН раз и никогда не перезаписывается.

    Иначе первая же итерация перебора запишет в снимок урезанный список, и
    восстанавливать станет нечего — класс «сторож, затирающий эталон».
    """
    if os.path.exists(SNAPSHOT):
        return
    os.makedirs(os.path.dirname(SNAPSHOT), exist_ok=True)
    shutil.copyfile(MODLIST, SNAPSHOT)
    out("snapshot created: " + SNAPSHOT)


def full_list():
    ensure_snapshot()
    return read_lines(SNAPSHOT)


def suspects():
    return [p for p in full_list() if p not in NOT_SUSPECT]


def halves():
    s = suspects()
    mid = (len(s) + 1) // 2
    return s[:mid], s[mid:]


def apply(disabled):
    """Записать modlist без указанных паков, сохранив ПОРЯДОК полного списка.

    Порядок загрузки решает, кто побеждает в спорных строках (46 таких в
    сборке, замер 09.09). Перебор не должен менять порядок — иначе он вносит
    вторую переменную и перестаёт быть делением пополам.
    """
    dis = set(disabled)
    keep = [p for p in full_list() if p not in dis]
    write_lines(MODLIST, keep)
    return keep, sorted(dis)


def cmd_list():
    cur = set(read_lines(MODLIST))
    a, b = halves()
    out("modlist сейчас: %d строк" % len(cur))
    out("подозреваемых всего: %d" % len(suspects()))
    out("  половина A (%d): %s" % (len(a), ", ".join(a)))
    out("  половина B (%d): %s" % (len(b), ", ".join(b)))
    off = [p for p in full_list() if p not in cur]
    out("выключено сейчас (%d): %s" % (len(off), ", ".join(off) if off else "-"))


def cmd_off(arg):
    a, b = halves()
    if arg == "A":
        target = a
    elif arg == "B":
        target = b
    else:
        target = [x.strip() for x in arg.split(",") if x.strip()]
    keep, dis = apply(target)
    out("выключено %d, монтируется %d" % (len(dis), len(keep)))
    for p in dis:
        out("  off  " + p)


def cmd_only(arg):
    """Оставить из подозреваемых только перечисленные — выключить всех прочих."""
    live = set(x.strip() for x in arg.split(",") if x.strip())
    target = [p for p in suspects() if p not in live]
    keep, dis = apply(target)
    out("из подозреваемых оставлено %d, выключено %d, монтируется %d"
        % (len(live), len(dis), len(keep)))


def cmd_restore():
    keep = full_list()
    write_lines(MODLIST, keep)
    out("modlist восстановлен из снимка: %d строк" % len(keep))


ZOOM_RE = re.compile(r"ЗУМ: штанга=([\d.eE+-]+|nil) \| цель=([\d.eE+-]+|nil)")


def cmd_verdict(path=None):
    """Прочитать журнал и назвать МАКСИМУМ цели зума за сессию.

    Читаем именно ЦЕЛЬ, а не длину штанги: штанга догоняет цель и на коротком
    замере может не успеть, а цель — то самое число, которое игра обязана
    держать в пределах ThirdPersonCameraMaxArmLength и не держит.
    """
    p = path or UE4SS_LOG
    if not os.path.exists(p):
        out("журнала нет: " + p)
        return 2
    hits = []
    with io.open(p, "r", encoding="utf-8", errors="replace") as f:
        for ln in f:
            m = ZOOM_RE.search(ln)
            if not m:
                continue
            v = m.group(2)
            if v == "nil":
                continue
            try:
                hits.append(float(v))
            except ValueError:
                pass
    if not hits:
        # Тишина тут ЗНАЧИМА и её нельзя принять за «предел держится»:
        # ноль строк означает, что мод камеры не встал или не нашёл штангу,
        # то есть опыт не состоялся (EXP-0072 — тишина как признак).
        out("НЕТ ЗАМЕРОВ: строк 'ЗУМ:' в журнале ноль. Опыт НЕ состоялся -")
        out("мод камеры не поднялся или не взял штангу. Вердикт не ставить.")
        return 2
    mx = max(hits)
    out("замеров цели: %d | максимум цели: %.0f | порог: %.0f" % (len(hits), mx, RUNAWAY))
    if mx > RUNAWAY:
        out("ВЕРДИКТ: УЕХАЛ (виновник в этой половине)")
        return 1
    out("ВЕРДИКТ: предел держится (виновника в этой половине нет)")
    return 0


def main():
    if len(sys.argv) < 2:
        out(__doc__.split("КОМАНДЫ:")[1])
        return 2
    cmd = sys.argv[1]
    if cmd == "list":
        cmd_list()
    elif cmd == "off":
        cmd_off(sys.argv[2])
    elif cmd == "only":
        cmd_only(sys.argv[2])
    elif cmd == "restore":
        cmd_restore()
    elif cmd == "verdict":
        return cmd_verdict(sys.argv[2] if len(sys.argv) > 2 else None)
    else:
        out("unknown command: " + cmd)
        return 2
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
