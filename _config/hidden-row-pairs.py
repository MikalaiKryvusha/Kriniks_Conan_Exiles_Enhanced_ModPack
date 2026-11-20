# -*- coding: utf-8 -*-
"""hidden-row-pairs.py — rows of the game's tables the log shows ONE mod overwriting, though the game itself has no such row: some earlier mod ADDED it
silently (a merge of a new row prints nothing) — a pair of mods on one row that `who-overwrites-table.py --shared-rows` cannot see.

WHY (2026-11-06, KUMM plan 45 step 7): «Found existing table entry … overwriting» is printed only when the row already exists. A row new to the game,
added by mod A and re-declared by mod B, logs once — under B — and looks like a single writer. The vanilla table's row keys tell the two apart:
a logged single-writer row that is NOT a vanilla key was put there by another mod first.

    python -X utf8 hidden-row-pairs.py               # every table of the last world start's log
    python -X utf8 hidden-row-pairs.py ItemTable     # tables whose path contains the substring

Vanilla keys: `retoc to-legacy --filter <table path>` over the game view (`D:/work/ai_sandbox/_paksview-3.0.1`, hard links to the game's containers) →
`uaj rows` — cached in CACHE as one .txt per table (delete a file to refresh after a game patch). Read-only toward the game and the mods.
Prints per table: «<table> · single-writer rows N · not vanilla M», then the M rows with the logged writer. Exit 0.
[NOT-TESTED]
"""
import importlib.util
import os
import subprocess
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
_s = importlib.util.spec_from_file_location("w", os.path.join(HERE, "who-overwrites-table.py"))
w = importlib.util.module_from_spec(_s)
_s.loader.exec_module(w)

TOOLS = r"D:\work\ai_sandbox\_tools"
RETOC = os.path.join(TOOLS, "retoc-5.8", "retoc.exe")
UAJ = os.path.join(TOOLS, "src", "uaj", "bin", "Release", "net8.0", "uaj.exe")
GAME_PAKS = os.path.join(w.GAME_DIR, "ConanSandbox", "Content", "Paks")
# The GAME's containers only. `_paksview-3.0.1` also links every mod's container from Saved/ExtractedMods, and a mod that ships a vanilla table WHOLE
# (LegitReligious — Items/ItemStatModificationTable) would hand its own keys over as «vanilla» (first run 2026-11-06). Hard links, the same volume D:.
VIEW = os.environ.get("GAME_ONLY_VIEW", r"D:\work\ai_sandbox\ConanExiles\_scratch\game-only-view")
CACHE = os.environ.get("VANILLA_KEYS", r"D:\work\ai_sandbox\ConanExiles\_scratch\vanilla-table-keys-game-only")


def game_only_view():
    os.makedirs(VIEW, exist_ok=True)
    assert not os.path.abspath(VIEW).lower().startswith(os.path.abspath(w.GAME_DIR).lower()), "view inside the game"
    for fn in os.listdir(GAME_PAKS):
        if fn.endswith((".utoc", ".ucas")):
            dst = os.path.join(VIEW, fn)
            if os.path.exists(dst) and not os.path.samefile(os.path.join(GAME_PAKS, fn), dst):
                os.remove(dst)   # a game patch rewrote the container
            if not os.path.exists(dst):
                os.link(os.path.join(GAME_PAKS, fn), dst)


def vanilla_keys(table):
    """table = log path without /Game/ («Items/ItemTable») → set of row keys, or None when the game has no such table (a mod's own shared table)"""
    if table.startswith(("Mods/", "ModsShared/")):
        return None
    os.makedirs(CACHE, exist_ok=True)
    txt = os.path.join(CACHE, table.replace("/", "__") + ".txt")
    if os.path.exists(txt):
        lines = open(txt, encoding="utf-8").read().splitlines()
        return None if lines == ["<not a game table>"] else set(lines)
    n = 1
    while os.path.exists(os.path.join(CACHE, f"work-{n}")):
        n += 1
    work = os.path.join(CACHE, f"work-{n}")   # retoc writes only into a new folder
    subprocess.run([RETOC, "to-legacy", "--version", "UE5_7", "--no-shaders", "--no-script-objects", "--filter", table, VIEW, work],
                   capture_output=True, text=True, encoding="utf-8", errors="replace")
    want = os.path.join(work, "ConanSandbox", "Content", *table.split("/")) + ".uasset"
    if not os.path.exists(want):
        open(txt, "w", encoding="utf-8").write("<not a game table>\n")
        return None
    r = subprocess.run([UAJ, "rows", want, "VER_UE5_8"], capture_output=True, text=True, encoding="utf-8", errors="replace")
    keys = [k for k in r.stdout.splitlines() if k]
    open(txt, "w", encoding="utf-8").write("\n".join(keys) + "\n")
    return set(keys)


def main():
    # --index <mod-keys.tsv> (`mod-table-keys.py`): which mods' own tables hold each hidden key — the adder is one of the OTHERS; only the writer's own
    # tables → its second table re-declares its own row, no pair (2026-11-06). Parsed FIRST: the path is not a table substring (first run filtered all out)
    index = defaultdict(set)
    args = sys.argv[1:]
    if "--index" in args:
        ip = args[args.index("--index") + 1]
        args = [a for a in args if a not in ("--index", ip)]
        for line in open(ip, encoding="utf-8"):
            p = line.rstrip("\n").split("\t")
            if len(p) == 3:
                index[p[0]].add(p[1])
    sub = [a for a in args if not a.startswith("--")]
    by = defaultdict(list)
    for mod, table, row in w.scan(w.GAME_LOG):
        if not sub or any(s in table for s in sub):
            by[(table, row)].append(mod)
    tables = defaultdict(list)
    for (table, row), mods in by.items():
        if len(set(mods)) == 1:
            tables[table].append((row, mods[0]))
    pairs = defaultdict(list)
    total = 0
    game_only_view()
    for table in sorted(tables):
        keys = vanilla_keys(table)
        rows = tables[table]
        if keys is None:
            print(f"{table} · single-writer rows {len(rows)} · NOT A GAME TABLE (a mods' shared table — judge by the mods' own tables)")
            continue
        hidden = [(r, m) for r, m in rows if r not in keys]
        total += len(hidden)
        print(f"{table} · single-writer rows {len(rows)} · not vanilla {len(hidden)} · vanilla keys {len(keys)}")
        for r, m in sorted(hidden):
            # «earlier» may be the SAME mod's other table (EAA's own pets in two of its tables, first run 2026-11-06) — the prefix of the key hints whose
            if index:
                others = sorted(index.get(r, set()) - {m})
                if others:
                    adder = ", ".join(others)
                elif m in index.get(r, set()):
                    adder = f"{m} itself (its second table)"
                else:
                    adder = "? (no mod table holds the key)"
                pairs[(table, adder, m)].append(r)
            else:
                print(f"   {r}  ← logged writer {m}; added earlier by another table (another mod, or {m}'s own second table)")
    for (table, adder, writer), rows in sorted(pairs.items()):
        print(f"   {table} · {adder} → {writer} · {len(rows)} rows · e.g. {', '.join(rows[:4])}")
    print(f"total hidden pairs: {total}")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
