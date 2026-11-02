# locres-set-tr.py <Game.locres> <replacements.tsv> [--check] — заменить ПЕРЕВОД записей .locres по точному старому тексту («старый\tновый»),
# ключи, хэши ключей и хэши исходников — как были (locres.py пишет их как прочитал).
# Зачем (2026-10-29, KUMM bugs/64 п. 33 a «XP и двоеточие слиплись»): правка буквы в готовом переводе не стоит полной пересборки движком кита
# (README папки локализации, шаги 1–7). Источник правды остаётся прежним — строки интервью #003 / dm-fish-ru.tsv правятся тем же ходом, иначе
# следующая пересборка откатит правку. Старый текст, которого нет в файле, — остановка (код 2), файл не пишется.
# --check: только печать «найдено N записей», без записи.
# [TESTED: 2026-10-29 15:3x · on the pack's Game.locres: --check stopped with code 2 on an absent old text (row 300); the real write changed 1 entry,
#  locres-regress «прежних 54441, новых 54441; пропало 0, изменилось 1»; the new text seen in game — KUMM testcases/reports/2026-10-29_conan-quick-batch-xp-locomotion-fps.md]
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres

path, repl_path = sys.argv[1], sys.argv[2]
check = '--check' in sys.argv[3:]
repl = {}
by_key = {}   # строки «key:<КЛЮЧ>[,<КЛЮЧ>…]\t<новый>» — перевод ОДНОЙ записи по ключу, как в dm-fish-ru.tsv; старый текст не нужен
key_rows = []
for line in open(repl_path, encoding='utf-8').read().splitlines():
    if line.strip() and not line.startswith('#'):
        old, new = line.split('\t', 1)
        # 2026-11-02 (KUMM bugs/78): «None» Arrow Quick Swap — служебная строка; по старому тексту «Нет» правка задела бы и подпись EoT. [TESTED: 2026-11-02 · строка ключа не из источника — код 3; запись — 1 запись, regress «пропало 0, изменилось 1» · KUMM testcases/reports/2026-11-02_conan-wheel-in-bow-aim.md]
        if old.startswith('key:'):
            for k in old[4:].split(','):
                by_key[k.strip()] = new.replace('\\n', '\n')
            key_rows.append(line)
            continue
        # Две литеры «\n» = перевод строки, как в dm-fish-ru.tsv: иначе подсказку в несколько строк не заменить (2026-11-01, «Частота обновления полос»).
        # [TESTED: 2026-11-01 · the three-line tooltip of «Bar refresh rate» replaced, regress 0 lost · KUMM testcases/reports/2026-11-01_conan-cursor-key-name.md]
        repl[old.replace('\\n', '\n')] = new.replace('\\n', '\n')
# Страж источника (2026-10-31 23:2x, KUMM EXP-0418): правка только собранного файла живёт до первой полной пересборки — «шкала» владельца
# (19:08) вернулась «ползунком», потому что строки в dm-fish-ru.tsv остались старыми. Старый текст, который ещё стоит целой ячейкой в
# источнике перевода, — остановка (код 3): сначала исправить источник, потом этот файл. [TESTED: 2026-10-31 · «Сила» (стоит в dm-fish-ru.tsv) — код 3;
# «Текущий ползунок:» (источник исправлен) — страж пропустил, дальше код 2 · KUMM EXP-0418]
LOC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'localization')
SOURCES = [os.path.join(LOC, 'dm-fish-ru.tsv'), os.path.join(LOC, 'vanilla-overrides-ru.tsv'),
           os.path.join(LOC, '..', '..', '..', 'KUMM', 'interviews', 'interview_002_hosav_ru_perevod.md'),
           os.path.join(LOC, '..', '..', '..', 'KUMM', 'interviews', 'interview_003_hosav_hud_bytecode.md')]


def in_sources(text):
    cell = text.replace('\n', '\\n')
    found = []
    for src in SOURCES:
        if not os.path.exists(src):
            continue
        body = open(src, encoding='utf-8', errors='replace').read()
        if src.endswith('.tsv'):
            if any(line.split('\t')[-1] == cell for line in body.splitlines() if '\t' in line):
                found.append(os.path.basename(src))
        elif ('| ' + cell + ' |') in body:
            found.append(os.path.basename(src))
    return found


stale = {old: in_sources(old) for old in repl}
stale = {k: v for k, v in stale.items() if v}
# Строка по ключу — тот же страж наоборот: в источнике обязана стоять ТА ЖЕ строка «key:…\t<новый>», иначе пересборка вернёт старое.
src_rows = set(open(SOURCES[0], encoding='utf-8').read().splitlines())
for row in key_rows:
    if row not in src_rows:
        stale[row] = ['нет такой строки в dm-fish-ru.tsv']
if stale:
    for old, where in stale.items():
        print('СТОП: %r ещё стоит в источнике (%s) — исправь его первым, иначе пересборка вернёт старое' % (old, ', '.join(where)))
    sys.exit(3)
version, entries = locres.read(path)
hits = {old: 0 for old in repl}
key_hits = {k: 0 for k in by_key}
for e in entries:
    if e.key in by_key:
        key_hits[e.key] += 1
        if not check:
            e.tr = by_key[e.key]
    elif e.tr in repl:
        hits[e.tr] += 1
        if not check:
            e.tr = repl[e.tr]
for old, n in hits.items():
    print(f'{n} записей: {old!r} -> {repl[old]!r}')
for k, n in key_hits.items():
    print(f'{n} записей: ключ {k} -> {by_key[k]!r}')
if any(n == 0 for n in hits.values()) or any(n == 0 for n in key_hits.values()):
    print('СТОП: старого текста или ключа нет в файле — ничего не записано')
    sys.exit(2)
if not check:
    locres.write(path, entries, version)
    v2, e2 = locres.read(path)
    left = sum(1 for e in e2 if e.tr in repl and e.key not in by_key)
    wrong = sum(1 for e in e2 if e.key in by_key and e.tr != by_key[e.key])
    print(f'записано: {path} · записей {len(e2)} (было {len(entries)}) · старого текста осталось {left} · ключей не тем текстом {wrong}')
    sys.exit(0 if left == 0 and wrong == 0 and len(e2) == len(entries) else 1)
