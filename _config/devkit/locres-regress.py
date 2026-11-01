# locres-regress.py — сверка нового .locres с раскатанным: ничего из прежнего перевода не пропало и не изменилось молча.
#
# Зачем (2026-10-25): один Game.locres переводит все моды сразу, а сшиватель переводит по английскому тексту. Когда новый мод
# приносит то же английское слово с другим смыслом, поздняя таблица перебивает раннюю — и старый перевод меняется без единой
# ошибки. Так «Средний» (шрифт Hosav) стал «Средняя» (утро 25.10), а вечером того же дня шапка HUD Hosav «Лёгкая / Тяжёлая» стала
# «Легкий / Тяжелое» после перевода 13 модов Мастерской. Обе поломки нашла только ручная сверка файлов — теперь это шаг конвейера.
# Лечение найденного — строка `key:<КЛЮЧ>` в dm-fish-ru.tsv (перевод одного ключа), а не правка общей строки.
#
#   python -I -X utf8 locres-regress.py <прежний.locres> <новый.locres> [--allow <КЛЮЧ>[,<КЛЮЧ>…]]
#   код 0 — прежние записи на месте и те же; 1 — пропали или изменились (список); 2 — не прочитать файл.
# @guard locres-regress
# THREAT:         пересборка общего .locres молча меняет или теряет перевод соседнего мода
# PROVED-AGAINST: файлы, переставленные местами (новый KrinikRU.locres на 4 516 записей как «прежний», Game.locres на 1 531 как
#                 «новый») — «пропало 2985», код 1 (2026-10-25 11:29); изменённые записи ловит та же сверка, что нашла 10 записей Hosav
#                 вручную в 11:21 (scratchpad cmp_locres.py)
# GAP:            видит только записи, которые были в прежнем файле; плохой перевод НОВОЙ строки — дело вычитки
# ON-REAL-PATH:   2026-10-25 11:29 — Game.locres пака против KrinikRU.locres после закрепления ключей Hosav: 0 пропало, 0 изменилось, код 0
# [TESTED: 2026-10-25 · красный (код 1) и зелёный (код 0) прогоны на настоящих файлах перевода сборки — KUMM plans/33, шаг 14]
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres  # noqa: E402


def main():
    args = sys.argv[1:]
    allow = set()
    if '--allow' in args:
        i = args.index('--allow')
        allow = set(args[i + 1].split(','))
        del args[i:i + 2]
    try:
        _, old = locres.read(args[0])
        _, new = locres.read(args[1])
    except Exception as e:  # noqa: BLE001 — любой сбой чтения = «не проверено», а не «чисто»
        print('не прочитать:', e)
        sys.exit(2)
    o = {(e.ns, e.key): e.tr for e in old}
    n = {(e.ns, e.key): e.tr for e in new}
    lost = [k for k in o if k not in n and k[1] not in allow]
    changed = [k for k in o if k in n and o[k] != n[k] and k[1] not in allow]
    print('прежних записей %d, новых %d; пропало %d, изменилось %d' % (len(o), len(n), len(lost), len(changed)))
    for k in lost:
        print('  ПРОПАЛО   %s | %s' % (k[1], o[k][:60]))
    for k in changed:
        print('  ИЗМЕНЕНО  %s | %s -> %s' % (k[1], o[k][:50], n[k][:50]))
    sys.exit(1 if lost or changed else 0)


if __name__ == '__main__':
    main()
