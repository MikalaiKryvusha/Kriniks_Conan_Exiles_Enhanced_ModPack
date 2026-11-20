# hosav-ru-entries.py - join the ACCEPTED translation table (interview 002 in KUMM) with the mod's
# FText keys (hosav-ftext.csv) and write a localization MANIFEST + ru ARCHIVE the engine can compile.
#
# Зачем: хэши ключей .locres считает только сам движок (см. locres.py), поэтому перевод отдаётся ему
# в его же входном формате (манифест + архив), а компилирует GatherText из кита.
# Правила соответствия: ключи мода → EN-строка (source) → строка таблицы по EN (сравнение после strip);
# строки таблицы, где RU = «—», пропускаются; строки, объединяющие несколько EN через « / »,
# раскладываются попарно; литерал «\n» в таблице = настоящий перевод строки в моде.
# [NOT-TESTED]
import csv, json, re, sys, os, collections

# TABLE принимает НЕСКОЛЬКО файлов через запятую: перевод копится интервью за интервью
# (002 — основная таблица и добавление №1, 003 — строки из байткода). Порядок важен:
# при совпадении EN побеждает ПОСЛЕДНЯЯ таблица, то есть более свежее решение владельца.
TABLES = [t for t in sys.argv[1].split(',') if t]
FTEXT = sys.argv[2]      # hosav-ftext.csv
OUT = sys.argv[3]        # output dir: <OUT>/<Target>.manifest + <OUT>/ru/<Target>.archive
TARGET = sys.argv[4] if len(sys.argv) > 4 else 'HosavRU'

rows = []
for t in TABLES:
    found = re.findall(r'^\| (\d+) \| (.*?) \| (.*?) \|', open(t, encoding='utf-8').read(), re.M)
    print('table %s: %d rows' % (os.path.basename(t), len(found)))
    rows += found
ru_by_en = {}
ru_by_key = {}   # строки таблицы «key:<КЛЮЧ>[,<КЛЮЧ>…]» — перевод ОДНОГО ключа, а не всех строк с тем же английским
skipped = []
for num, en, ru in rows:
    # «¦» → «|» (2026-11-07, KUMM translation notes «An entry lost by the build»): build-ru-table.py escapes the pipe of a cell as «¦» for the markdown
    # table; read back unescaped, the EN never matched the mod's source — Pickup+'s hint «If set to < 100 = off | Max. = 5000 …» stayed English
    # (join-report: NO-KEY with «¦»). The table's own text is ours: a genuine «¦» does not occur in it.
    en_c = en.replace('\\n', '\n').replace('¦', '|')
    ru_c = ru.replace('\\n', '\n').replace('¦', '|')
    # 2026-10-25: «Small/Medium/Large» — и размер шрифта Hosav (мужской род), и размер рыбы (женский); перевод по
    # английскому слову был один на все моды, и поздняя строка перебивала раннюю («Мелкий / Средняя / Крупный»).
    if en_c.startswith('key:'):
        for k in en_c[4:].split(','):
            ru_by_key[k.strip()] = ru_c.strip()
        continue
    # «—» alone (or «— (оставить)») marks "do not translate"; a translation that merely BEGINS with
    # an em dash (the tooltip rows: «— Вместо стандартного…») is a translation.
    if ru_c.strip() == '—' or ru_c.strip().startswith('— ('):
        skipped.append(en_c); continue
    # rows that bundle several one-word EN values: "Small / Medium / Large" -> three entries;
    # a multi-word EN containing " / " (e.g. "Centered UI Stats / Custom Position") is ONE string.
    en_parts = en_c.split(' / ')
    ru_parts = ru_c.split(' / ')
    if len(en_parts) > 1 and len(en_parts) == len(ru_parts) and all(' ' not in p.strip() for p in en_parts):
        for a, b in zip(en_parts, ru_parts):
            ru_by_en[a.strip()] = b.strip()
    else:
        ru_by_en[en_c.strip()] = ru_c.strip()

triples = list(csv.DictReader(open(FTEXT, encoding='utf-8', newline='')))
matched, unmatched_sources = [], collections.Counter()
seen_keys = set()
for t in triples:
    src = t['source']
    # \r\n в исходнике мода и \n в таблице - одна строка (2026-10-25: первая строка Damage Meter не нашлась только из-за \r)
    ru = (ru_by_key.get(t['key']) or ru_by_en.get(src.strip())
          or ru_by_en.get(src.replace('\r\n', '\n').strip()))
    # \r\n в исходнике и \n\n в таблице - тоже одна строка: сканер байткода записывал CRLF двумя LF, таблица переведена по той
    # записи; опись с 2026-10-26 несёт настоящие байты ассета (crlf-fix-inventory.py), и русская строка получает тот же \r\n -
    # один перевод строки, как в оригинале, а не пустую строку между абзацами (KUMM bugs/64 п. 7b, подсказки школ Era of Trials).
    if ru is None and '\r\n' in src:
        ru = ru_by_en.get(src.replace('\r\n', '\n\n').strip())
        if ru is not None:
            ru = ru.replace('\n\n', '\r\n')
    if ru is None:
        unmatched_sources[src] += 1; continue
    if (t['namespace'], t['key']) in seen_keys:
        continue
    seen_keys.add((t['namespace'], t['key']))
    matched.append((t['namespace'], t['key'], src, ru))

# manifest: one namespace "" (all mod texts have an empty namespace), keyed entries
children = []
by_src = collections.OrderedDict()
for ns, key, src, ru in matched:
    by_src.setdefault(src, []).append(key)
for src, keys in by_src.items():
    children.append({'Source': {'Text': src}, 'Keys': [{'Key': k, 'Path': ''} for k in keys]})
manifest = {'FormatVersion': 1, 'Namespace': '', 'Children': children, 'Subnamespaces': []}
archive_children = [{'Source': {'Text': src}, 'Translation': {'Text': ru}, 'Key': key} for ns, key, src, ru in matched]
archive = {'FormatVersion': 2, 'Namespace': '', 'Children': archive_children, 'Subnamespaces': []}

os.makedirs(os.path.join(OUT, 'ru'), exist_ok=True)
os.makedirs(os.path.join(OUT, 'en'), exist_ok=True)
with open(os.path.join(OUT, TARGET + '.manifest'), 'w', encoding='utf-8') as f:
    json.dump(manifest, f, ensure_ascii=False, indent=1)
with open(os.path.join(OUT, 'ru', TARGET + '.archive'), 'w', encoding='utf-8') as f:
    json.dump(archive, f, ensure_ascii=False, indent=1)
# native-culture archive: translation = source (the compiler expects one per culture it generates)
archive_en = {'FormatVersion': 2, 'Namespace': '', 'Subnamespaces': [],
              'Children': [{'Source': {'Text': src}, 'Translation': {'Text': src}, 'Key': key} for ns, key, src, ru in matched]}
with open(os.path.join(OUT, 'en', TARGET + '.archive'), 'w', encoding='utf-8') as f:
    json.dump(archive_en, f, ensure_ascii=False, indent=1)
with open(os.path.join(OUT, 'join-report.txt'), 'w', encoding='utf-8') as f:
    f.write('table rows: %d (skipped as "-": %d)\nmod triples: %d\nmatched keys: %d, distinct sources: %d\n' % (len(rows), len(skipped), len(triples), len(matched), len(by_src)))
    # Множество исходников — один раз: прежде оно строилось заново на каждую строку таблицы, и при 23 тыс. строк × 100 тыс. ключей
    # отчёт считался больше 10 минут при уже записанных манифесте и архиве (2026-10-26 11:50–12:00).
    mod_sources = {t['source'].strip() for t in triples}
    mod_sources |= {t['source'].replace('\r\n', '\n\n').strip() for t in triples if '\r\n' in t['source']}   # запасной путь выше
    no_key = [en for en in ru_by_en if en not in mod_sources]
    f.write('table EN strings with no key in the mod: %d\n' % len(no_key))
    for en in no_key:
        f.write('  NO-KEY  %r\n' % en)
    f.write('mod sources not in the table (untranslated): %d\n' % len(unmatched_sources))
    for s, n in unmatched_sources.most_common():
        f.write('  UNTRANSLATED x%d %r\n' % (n, s))
# Lua map for the UE4SS runtime route: exact source string -> translation (long-bracket quoting,
# so apostrophes, quotes and newlines survive). One entry per distinct source.
lua_path = os.path.join(OUT, 'ru_table.lua')
def lb(s):
    lvl = 1
    while (']' + '=' * lvl + ']') in s:
        lvl += 1
    eq = '=' * lvl
    return '[' + eq + '[' + s + ']' + eq + ']'
with open(lua_path, 'w', encoding='utf-8', newline='\n') as f:
    f.write('-- generated by hosav-ru-entries.py from the accepted table; do not edit by hand\n')
    f.write('-- %d distinct English strings -> Russian\n' % len(by_src))
    f.write('return {\n')
    ru_of_src = {}
    for ns, k, s, r in matched:
        ru_of_src.setdefault(s, r)   # первый перевод исходника — как прежний next() по matched, но без прохода на каждую строку
    for src, keys in by_src.items():
        ru = ru_of_src[src]
        # a space after '[' - otherwise Lua reads '[[' as the start of a long string, not a table key
        f.write('  [ %s ] = %s,\n' % (lb(src), lb(ru)))
    f.write('}\n')
print('lua map:', lua_path)
print(open(os.path.join(OUT, 'join-report.txt'), encoding='utf-8').read())
