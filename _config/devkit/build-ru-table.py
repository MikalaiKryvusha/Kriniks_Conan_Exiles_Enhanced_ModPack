# build-ru-table.py — собрать таблицу перевода `| N | EN | RU |` для hosav-ru-entries.py из рабочего списка и переводов.
#
# Зачем (2026-10-25, русификация The Damage Meter и Exiles Fishing): сшиватель находит ключи мода по АНГЛИЙСКОЙ строке
# точь-в-точь. Переписывать сотни длинных описаний рыб руками — верный путь к опечатке и к строке, которая молча не
# переведётся. Поэтому английский берётся из рабочего списка (его снял ftext_extract.py), а переводчик пишет только
# «номер <TAB> русский». Плюс проверка: плейсхолдеры {…} и <…> в переводе те же, что в оригинале.
#
#   python -I -X utf8 build-ru-table.py <worklist.tsv> <ru.tsv> <выход.md>
#   worklist.tsv: N <TAB> мод <TAB> ассет <TAB> EN (\n как два символа) <TAB> подсказка словаря
#   ru.tsv:       N <TAB> RU (\n как два символа; «—» = не переводить)
# [NOT-TESTED]
import re
import sys

worklist, ru_path, out = sys.argv[1:4]
en = {}
for line in open(worklist, encoding='utf-8'):
    parts = line.rstrip('\n').split('\t')
    en[parts[0]] = parts[3]
ru = {}
by_key = []   # строки «key:<КЛЮЧ>[,<КЛЮЧ>…] <TAB> RU» — перевод одного ключа, а не всех строк с тем же английским
for line in open(ru_path, encoding='utf-8'):
    if not line.strip() or line.startswith('#'):
        continue
    n, _, text = line.rstrip('\n').partition('\t')
    if n.startswith('key:'):
        by_key.append((n.strip(), text.strip()))
        continue
    ru[n.strip()] = text.strip()

# Тег разметки UE — «<имя…>» или «</>» без пробела сразу после «<». Стрелки кнопок EAA «<< Exit >>» (строки 20179–20180,
# 2026-10-25) — текст, а не тег: с пробелом у края они в плейсхолдеры не идут, иначе перевод кнопки считался бы сломанным.
PH = re.compile(r'\{[^{}]*\}|<(?! )[^<>]*(?<! )>')
bad, missing = [], [n for n in en if n not in ru]
rows = []
for n in sorted(ru, key=int):
    if n not in en:
        bad.append('%s: номера нет в списке' % n)
        continue
    r = ru[n]
    # Сравниваются МНОЖЕСТВА, не счёт копий: опасен пропавший или чужой плейсхолдер — движок покажет его скобками или
    # потеряет число. Лишняя копия того же самого безвредна, а нужна она там, где автор сломал свой: Ambush, строка 1826,
    # «LineBreak}» без открывающей скобки — перевод чинит её в «{LineBreak}», и счёт выходит 46 против 45 (2026-10-25).
    if r != '—' and set(PH.findall(en[n])) != set(PH.findall(r)):
        bad.append('%s: плейсхолдеры %s -> %s' % (n, PH.findall(en[n]), PH.findall(r)))
    rows.append('| %s | %s | %s |' % (n, en[n].replace('|', '¦'), r.replace('|', '¦')))
# Номера 90000+ — строки по ключу: «Small» у рыбы и у шрифта Hosav одно английское слово, но разный русский род.
for i, (k, r) in enumerate(by_key):
    rows.append('| %d | %s | %s |' % (90000 + i, k, r))
with open(out, 'w', encoding='utf-8') as fh:
    fh.write('| N | EN | RU |\n|---|---|---|\n' + '\n'.join(rows) + '\n')
print('строк в таблице %d, без перевода %d' % (len(rows), len(missing)))
for b in bad:
    print('  ОШИБКА', b)
sys.exit(1 if bad else 0)
