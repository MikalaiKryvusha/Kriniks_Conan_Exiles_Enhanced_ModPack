# extend-worklist.py — дописать в рабочий список перевода новые строки нового мода (или нескольких) и их ключи в all-mods-ftext.csv.
#
# Зачем (2026-10-25, 13 модов Мастерской по выбору владельца: «нужна русификация» у каждого): рабочий список рыбалки и
# Damage Meter собирался разовым скриптом, а мод в сборку теперь приходит каждую неделю. Прибор делает одно и то же каждый
# раз: строки, которых в списке ещё нет, дописываются в конец с номерами по порядку (номер = ключ перевода в ru.tsv, старые
# номера не сдвигаются никогда), ключи — в общий csv для сшивателя hosav-ru-entries.py. Строка, уже переведённая для
# другого мода, нового номера не получает: сшиватель переводит по английскому тексту.
#
# Мусор разборщика ftext_extract.py отсеивается по ФОРМЕ (у 13 модов его 243 имени и сотни двоичных обрывков):
#   - символ управления или из Latin-1 (двоичные обрывки вида «×  #  Item_9877405_Long º»);
#   - служебное имя: одно слово с «_» или без строчных букв («XX_Spider_Bite», «FistPunch_Name», «600»).
#
#   python -I -X utf8 extend-worklist.py <worklist.tsv> <all-mods-ftext.csv> <glossary.tsv|-> <метка>=<mod.csv> [...]
#   glossary.tsv — выход game-glossary.py (EN <TAB> RU); подсказка ставится только при совпадении строки целиком.
# [NOT-TESTED]
import csv
import os
import re
import sys

GARBAGE = re.compile(r'[\x00-\x09\x0b-\x1f\x7f-\xff]')
IDENT = re.compile(r'[A-Za-z0-9_.:\-]+')


def junk(s):
    # Перевод строки Windows (\r\n) — не мусор: 2026-10-25 вечером сшиватель показал 49 строк волны 1 с \r\n (дневники
    # Emberlight, лор вещей), которых не было в рабочем списке вовсе — \r попадал под GARBAGE, и строка молча отсеивалась.
    s = s.replace('\r\n', '\n')
    if not re.search('[A-Za-z]', s) or GARBAGE.search(s):
        return True
    return bool(IDENT.fullmatch(s)) and ('_' in s or not re.search('[a-z]', s))


def main():
    worklist, ftext_csv, glossary = sys.argv[1:4]
    pairs = [a.split('=', 1) for a in sys.argv[4:]]
    rows = [l.rstrip('\r\n').split('\t') for l in open(worklist, encoding='utf-8') if l.strip()]
    known = {r[3] for r in rows}
    n = max(int(r[0]) for r in rows)
    gloss = {}
    if glossary != '-':
        for l in open(glossary, encoding='utf-8'):
            p = l.rstrip('\r\n').split('\t')
            if len(p) >= 2:
                gloss.setdefault(p[0], p[1])
    have = set()
    with open(ftext_csv, encoding='utf-8', newline='') as fh:
        for r in csv.DictReader(fh):
            have.add((r['file'], r['key']))
    added_rows, added_keys = [], []
    for label, path in pairs:
        with open(path, encoding='utf-8', newline='') as fh:
            for r in csv.DictReader(fh):
                if (r['file'], r['key']) not in have:
                    have.add((r['file'], r['key']))
                    added_keys.append(r)
                s = r['source'].replace('\r\n', '\n')   # сшиватель сравнивает так же (hosav-ru-entries.py, строка 58)
                if junk(s) or s.replace('\n', '\\n') in known:
                    continue
                en = s.replace('\n', '\\n')
                known.add(en)
                n += 1
                asset = os.path.splitext(os.path.basename(r['file']))[0]
                added_rows.append('%d\t%s\t%s\t%s\t%s' % (n, label, asset, en, gloss.get(s, '')))
    with open(worklist, 'a', encoding='utf-8', newline='') as fh:
        fh.write(''.join(r + '\r\n' for r in added_rows))   # список ведётся в CRLF — как его писал первый сборщик
    with open(ftext_csv, 'a', encoding='utf-8', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=['file', 'namespace', 'key', 'source'])
        for r in added_keys:
            w.writerow({k: r[k] for k in ('file', 'namespace', 'key', 'source')})
    print('строк в список: %d (номера до %d), ключей в csv: %d' % (len(added_rows), n, len(added_keys)))


if __name__ == '__main__':
    main()
