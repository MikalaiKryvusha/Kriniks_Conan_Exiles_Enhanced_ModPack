# -*- coding: utf-8 -*-
"""lua-hook-pairs.py — every UE4SS Lua mod of the installed build: the game functions it hooks (`RegisterHook`, `NotifyOnNewObject`) and the keys it binds
(`RegisterKeyBind`), and the targets two or more mods share.

WHY (2026-11-06, KUMM plan 45 step 9, reconciliation guide kind 2 «code»): two hooks on one function run in an order nobody chose; one key bound twice goes
to the last binder. A shared hook is fine when the mods touch different state — that is read in the code afterwards; this tool only lists the pairs.

    python -X utf8 lua-hook-pairs.py

Reads `<game>/ConanSandbox/Binaries/Win64/ue4ss/Mods/<Mod>/Scripts/**/*.lua` of the mods listed as enabled in `mods.txt` (a mod with `enabled.txt` counts too).
Prints «HOOK <target> — mod: file:line, …» and «KEY <key+mods> — …» for the shared ones, then the totals. Read-only. Exit 0.
[NOT-TESTED]
"""
import os
import re
import sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from game_target import GAME_DIR  # noqa: E402

MODS = os.path.join(GAME_DIR, "ConanSandbox", "Binaries", "Win64", "ue4ss", "Mods")
RE_HOOK = re.compile(r"""(RegisterHook|NotifyOnNewObject)\s*\(\s*["']([^"']+)["']""")
RE_KEY = re.compile(r"""RegisterKeyBind\s*\(\s*Key\.([A-Z0-9_]+)\s*(?:,\s*\{([^}]*)\})?""")


def enabled_mods():
    on = set()
    txt = os.path.join(MODS, "mods.txt")
    if os.path.exists(txt):
        for line in open(txt, encoding="utf-8", errors="replace"):
            m = re.match(r"\s*([^;:#\s][^:]*?)\s*:\s*1\s*$", line)
            if m:
                on.add(m.group(1))
    for d in os.listdir(MODS):
        if os.path.exists(os.path.join(MODS, d, "enabled.txt")):
            on.add(d)
    return sorted(d for d in on if os.path.isdir(os.path.join(MODS, d, "Scripts")))


def main():
    hooks, keys = defaultdict(list), defaultdict(list)
    mods = enabled_mods()
    for mod in mods:
        for dp, _, fs in os.walk(os.path.join(MODS, mod, "Scripts")):
            for fn in fs:
                if not fn.endswith(".lua"):
                    continue
                p = os.path.join(dp, fn)
                for i, line in enumerate(open(p, encoding="utf-8", errors="replace"), 1):
                    if line.lstrip().startswith("--"):
                        continue
                    for m in RE_HOOK.finditer(line):
                        hooks[m.group(2)].append((mod, f"{os.path.relpath(p, os.path.join(MODS, mod))}:{i}"))
                    for m in RE_KEY.finditer(line):
                        mk = "+".join(sorted(x.strip().replace("ModifierKey.", "") for x in (m.group(2) or "").split(",") if x.strip()))
                        keys[(m.group(1), mk)].append((mod, f"{os.path.relpath(p, os.path.join(MODS, mod))}:{i}"))
    print(f"enabled Lua mods: {len(mods)} — {', '.join(mods)}")
    nh = nk = 0
    for t, where in sorted(hooks.items()):
        if len({m for m, _ in where}) > 1:
            nh += 1
            print(f"HOOK {t} — " + ", ".join(f"{m}: {w}" for m, w in where))
    for (k, mk), where in sorted(keys.items()):
        if len({m for m, _ in where}) > 1:
            nk += 1
            print(f"KEY {k}{'+' + mk if mk else ''} — " + ", ".join(f"{m}: {w}" for m, w in where))
    print(f"hook targets {len(hooks)}, shared by 2+ mods {nh}; key binds {len(keys)}, shared {nk}")
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
