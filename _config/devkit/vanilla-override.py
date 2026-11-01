# -*- coding: utf-8 -*-
"""vanilla-override.py — put our Russian over a VANILLA game string: the entries of a table are added to (or replaced in) our Game.locres
with the namespace / key / source hashes copied from the game's own Russian locres of that string's target (our writer never computes a
key hash — `locres.py`). Run after every full rebuild of Game.locres (README of the localization folder, step 7), since the rebuild drops it.

Why (KUMM bugs/64 item 36, 2026-10-29): the owner — «было бы хорошо текст переносить на две строки в виджете подсказке о трупе со слова
"или" - на второй строке писать»; the corpse prompt is the game's own string (target Exiles_UI), not a mod's.

    python -I -X utf8 vanilla-override.py <Game.locres> <vanilla target .locres> <table.tsv> [--check]
table.tsv: `namespace<TAB>key<TAB>text`; in text `\\n` is a line break. --check prints what would change, writes nothing.
Exit 0 — written (or nothing to change); 1 — a key of the table is missing in the vanilla target.
[NOT-TESTED]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import locres  # noqa: E402


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    game_path, vanilla_path, table_path = argv[1], argv[2], argv[3]
    check = "--check" in argv
    version, ours = locres.read(game_path)
    _, vanilla = locres.read(vanilla_path)
    by_key = {(e.ns, e.key): e for e in vanilla}
    rows = []
    for line in open(table_path, encoding="utf-8"):
        line = line.rstrip("\r\n")
        if not line or line.startswith("#"):
            continue
        ns, key, text = line.split("\t", 2)
        rows.append((ns, key, text.replace("\\n", "\n")))
    missing = [k for ns, k, _ in rows if (ns, k) not in by_key]
    if missing:
        print("missing in the vanilla target:", ", ".join(missing))
        return 1
    index = {(e.ns, e.key): i for i, e in enumerate(ours)}
    changed = 0
    for ns, key, text in rows:
        v = by_key[(ns, key)]
        entry = locres.Entry(v.ns, v.ns_hash, v.key, v.key_hash, v.src_hash, text)
        i = index.get((ns, key))
        if i is None:
            ours.append(entry)
            changed += 1
            print("add  %s/%s -> %r" % (ns, key, text))
        elif ours[i].tr != text:
            ours[i] = entry
            changed += 1
            print("set  %s/%s -> %r" % (ns, key, text))
    if changed and not check:
        locres.write(game_path, ours, version)
    print("%d entries %s" % (changed, "would change" if check else "written"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
