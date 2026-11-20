# -*- coding: utf-8 -*-
"""mod-table-keys.py — an index «row key → mod · its table» over the OWN data tables of every mod of the build.

WHY (2026-11-06, KUMM plan 45 step 7): `hidden-row-pairs.py` finds rows the log shows one mod overwriting though the game has no such row — another table added
it first, silently. Which one? Only the mods' own tables say: the key sits in the tables of every mod that writes it.

    python -X utf8 mod-table-keys.py <overrides.tsv> <out.tsv>

<overrides.tsv> — the output of `mod-overrides.py` (rows `<mod>\towntable\t<asset name>`). For each mod: a view of the game's global + that mod's container
from Saved/ExtractedMods (hard links, CACHE), `retoc to-legacy --filter <asset>` per own table, `uaj rows` per data table found. <out.tsv>: `key\tmod\tasset`.
Read-only toward the game and the mods; writes only into CACHE and <out.tsv>. Exit 0.
[NOT-TESTED]
"""
import os
import shutil
import subprocess
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from game_target import GAME_DIR, sandbox  # noqa: E402

TOOLS = r"D:\work\ai_sandbox\_tools"
RETOC = os.path.join(TOOLS, "retoc-5.8", "retoc.exe")
UAJ = os.path.join(TOOLS, "src", "uaj", "bin", "Release", "net8.0", "uaj.exe")
EXTRACTED = sandbox("Saved", "ExtractedMods")
GAME_PAKS = os.path.join(GAME_DIR, "ConanSandbox", "Content", "Paks")
CACHE = os.environ.get("MOD_TABLE_KEYS_CACHE", r"D:\work\ai_sandbox\ConanExiles\_scratch\mod-table-keys")


def view_of(mod):
    v = os.path.join(CACHE, "view-" + mod)
    os.makedirs(v, exist_ok=True)
    for ext in (".utoc", ".ucas"):
        g = os.path.join(v, "global" + ext)
        if not os.path.exists(g):
            shutil.copyfile(os.path.join(GAME_PAKS, "global" + ext), g)
        src, dst = os.path.join(EXTRACTED, f"{mod}-Windows{ext}"), os.path.join(v, f"{mod}-Windows{ext}")
        if not os.path.exists(src):
            return None
        if os.path.exists(dst) and not os.path.samefile(src, dst):
            os.remove(dst)
        if not os.path.exists(dst):
            os.link(src, dst)
    return v


def main():
    ovr, out = sys.argv[1], sys.argv[2]
    tables = defaultdict(list)
    for line in open(ovr, encoding="utf-8"):
        p = line.rstrip("\n").split("\t")
        if len(p) == 3 and p[1] == "owntable":
            tables[p[0]].append(p[2])
    rows = []
    for mod in sorted(tables):
        v = view_of(mod)
        if v is None:
            print(f"{mod}: no extracted container — skipped")
            continue
        n = 0
        for asset in sorted(set(tables[mod])):
            leg = os.path.join(CACHE, "legacy-" + mod + "-" + asset)
            if not os.path.exists(leg):
                subprocess.run([RETOC, "to-legacy", "--version", "UE5_7", "--no-shaders", "--no-script-objects", "--filter", asset, v, leg],
                               capture_output=True, text=True, encoding="utf-8", errors="replace")
            for dp, _, fs in os.walk(leg):
                for fn in fs:
                    if fn == asset + ".uasset":
                        r = subprocess.run([UAJ, "rows", os.path.join(dp, fn), "VER_UE5_8"], capture_output=True, text=True, encoding="utf-8",
                                           errors="replace")
                        for k in r.stdout.splitlines():
                            if k:
                                rows.append((k, mod, asset))
                                n += 1
        print(f"{mod}: {len(set(tables[mod]))} own tables, {n} row keys", flush=True)
    with open(out, "w", encoding="utf-8") as f:
        for k, m, a in rows:
            f.write(f"{k}\t{m}\t{a}\n")
    print(f"-> {out}: {len(rows)} keys")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
