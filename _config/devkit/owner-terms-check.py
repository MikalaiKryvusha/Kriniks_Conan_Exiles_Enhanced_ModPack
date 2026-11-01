# owner-terms-check.py — термины владельца в переводе: у каждой строки, где в английском есть термин, в русском обязано стоять его слово.
#
# Зачем (2026-10-26): «vanilla» было переведено шестью способами («исходно», «как в игре», «оригинальной», «родная» …), владелец:
# `[OWNER]` «vanilla нужно было перевести не как исходно, а как ваниль». Правило держит код, а не память переводчика.
#
#   python -I -X utf8 owner-terms-check.py <worklist.tsv> <ru.tsv> [asset-strings/*.tsv …]
# Код 0 — всё по терминам; 1 — нарушения (номер · английский · русский).
# [TESTED: 2026-10-26 · 41 строка dm-fish-ru.tsv с vanilla — 0 нарушений после правки; до правки та же опись дала 41 нарушение]
import re
import sys

TERMS = [
    # с мягким знаком всегда: «ваниль», «ванильный»; «к ванили» — нарушение (`[OWNER]` «ваниль !!!! с мягким знаком!» · 2026-10-26)
    (re.compile(r'\bvanilla\b', re.I), 'ваниль'),
]


def pairs(worklist, ru_path, extra):
    wl = {}
    for line in open(worklist, encoding='utf-8'):
        p = line.rstrip('\r\n').split('\t')
        if len(p) >= 4:
            wl[p[0]] = p[3]
    for line in open(ru_path, encoding='utf-8'):
        p = line.rstrip('\r\n').split('\t', 1)
        if len(p) == 2 and p[0] in wl:
            yield p[0], wl[p[0]], p[1]
    for path in extra:
        for i, line in enumerate(open(path, encoding='utf-8'), 1):
            p = line.rstrip('\r\n').split('\t', 1)
            if len(p) == 2 and not p[0].startswith('#'):
                yield f'{path.split("/")[-1].split(chr(92))[-1]}:{i}', p[0].removeprefix('lit:'), p[1]


def main():
    bad = 0
    for n, en, ru in pairs(sys.argv[1], sys.argv[2], sys.argv[3:]):
        for rx, word in TERMS:
            if rx.search(en) and word not in ru.lower():
                bad += 1
                print(f'{n}\t{en[:80]}\t{ru[:80]}')
    print(f'нарушений терминов владельца: {bad}', file=sys.stderr)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
