# game-glossary.py — словарь «английский → русский» самой игры Conan Exiles из файлов локализации кита.
#
# Зачем (2026-10-25, русификация The Damage Meter и Exiles Fishing по слову владельца «3 делаем»): переводить
# строки модов теми же словами, что и игра. «Small», «Night», «Fillet», названия знаний и станций у Funcom уже
# переведены — сочинять свои значит получить два слова на одну вещь в одном окне.
# Источник: <кит>/UE4/Content/Localization/<Цель>/<Цель>.manifest (JSON: исходник и его ключи) + ru/<Цель>.locres
# (перевод по ключу). Для каждой английской строки берётся самый частый русский вариант.
#
#   python -I -X utf8 game-glossary.py <выход.tsv>
# [NOT-TESTED]
import collections
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres

KIT_LOC = r'F:\CEUE5Devkit\UE4\Content\Localization'   # новый кит 2026-10-25; старый F:\CEDevKit удалён


def walk(node, ns, out):
    """Пары (namespace, key, source) из узла манифеста и его подпространств."""
    ns = node.get('Namespace', ns) or ''
    for ch in node.get('Children', []):
        src = ch.get('Source', {}).get('Text', '')
        for k in ch.get('Keys', []):
            out.append((ns, k.get('Key', ''), src))
    for sub in node.get('Subnamespaces', []):
        walk(sub, sub.get('Namespace', ''), out)


def main():
    votes = collections.defaultdict(collections.Counter)
    targets = 0
    for man in glob.glob(os.path.join(KIT_LOC, '*', '*.manifest')):
        target = os.path.splitext(os.path.basename(man))[0]
        ru = os.path.join(os.path.dirname(man), 'ru', target + '.locres')
        if not os.path.exists(ru):
            continue
        triples = []
        raw = open(man, 'rb').read()
        text = raw.decode('utf-16') if raw[:2] in (b'\xff\xfe', b'\xfe\xff') else raw.decode('utf-8-sig')
        walk(json.loads(text), '', triples)
        _, entries = locres.read(ru)
        by_key = {(e.ns, e.key): e.tr for e in entries}
        for ns, key, src in triples:
            t = by_key.get((ns, key))
            if t and src.strip():
                votes[src][t] += 1
        targets += 1
    with open(sys.argv[1], 'w', encoding='utf-8') as fh:
        for src in sorted(votes):
            ru_text, _ = votes[src].most_common(1)[0]
            fh.write(src.replace('\t', ' ').replace('\r', '').replace('\n', '\\n') + '\t' +
                     ru_text.replace('\t', ' ').replace('\r', '').replace('\n', '\\n') + '\n')
    print('целей %d, строк в словаре %d' % (targets, len(votes)))


if __name__ == '__main__':
    main()
