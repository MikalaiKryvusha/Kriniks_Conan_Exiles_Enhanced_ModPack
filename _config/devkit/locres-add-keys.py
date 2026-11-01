# locres-add-keys.py <Game.locres> <engine-built.locres> <keys.csv> [--check] — дописать в раскатанный .locres ТОЛЬКО записи с ключами
# из keys.csv (колонка key), взяв их из .locres, который собрал движок кита (хэши ключей и исходников — как есть: locres.py хэш
# ключа не считает). Остальные записи раскатанного файла не трогаются.
# Зачем (2026-10-31 23:17, KUMM plan 36 W18): полная пересборка (README папки локализации, шаги 1–7) откатила бы правки, внесённые
# прямо в Game.locres прибором locres-set-tr.py («шкала» владельца 19:08 и др. — locres-regress: 4 изменено, 2 пропало), пока их
# источники не исправлены. Новые ключи (карточка артефактов EAA, меню Beyond Decor) нужны сейчас — их и только их переносим.
# Ключ, которого нет в сборке движка, — остановка (код 2), файл не пишется. --check: только печать.
# [NOT-TESTED]
import csv
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres  # noqa: E402


def main():
    live, built, keys_csv = sys.argv[1], sys.argv[2], sys.argv[3]
    check = "--check" in sys.argv[4:]
    want = {r["key"] for r in csv.DictReader(open(keys_csv, encoding="utf-8"))}
    ver, entries = locres.read(live)
    _, new = locres.read(built)
    have = {(e.ns, e.key) for e in entries}
    picked = [e for e in new if e.key in want]
    missing = want - {e.key for e in picked}
    if missing:
        print("в сборке движка нет ключей: %s" % ", ".join(sorted(missing)))
        return 2
    added = [e for e in picked if (e.ns, e.key) not in have]
    for e in added:
        print("добавляю %s/%s: %s" % (e.ns, e.key, e.tr[:60].replace("\n", " ")))
    print("записей было %d, добавлено %d" % (len(entries), len(added)))
    if not check and added:
        locres.write(live, entries + added, ver)
        _, back = locres.read(live)
        print("перечитано записей %d" % len(back))
    return 0


if __name__ == "__main__":
    sys.exit(main())
