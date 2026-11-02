# check-lua-shadow.py <folder|file>... — top-level Lua names declared twice in one file (`local function X` / `local X =` at column 0).
#
# WHY (KUMM EXP-0436, 2026-11-01 23:1x): krinik_mod_settings.lua got a helper `local function shown(p)` above an older `local shown = {}`; every
# function defined below the table saw the TABLE, and the window fill would have died on «attempt to call a table value». `loadfile` and luac accept it.
# Exit 0 — none; 1 — duplicates listed «file:line name (first at line N)»; 2 — nothing to read.
#
# @guard check-lua-shadow
# THREAT:         a top-level local declared twice in a section — the later one silently replaces the earlier for all code below it
# PROVED-AGAINST: a copy of krinik_mod_settings.lua with `local function shown(p)` restored above `local shown = {}` (red), the fixed file (green)
# GAP:            locals inside functions and names reused across files are not looked at
# ON-REAL-PATH:   NOT YET
import re
import sys
from pathlib import Path

DECL = re.compile(r"^local\s+(?:function\s+)?([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)")


def files(args):
    for a in args:
        p = Path(a)
        if p.is_dir():
            yield from sorted(p.rglob("*.lua"))
        elif p.suffix == ".lua":
            yield p


def main():
    seen_any, bad = False, 0
    for f in files(sys.argv[1:]):
        seen_any = True
        first = {}
        for n, line in enumerate(f.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            m = DECL.match(line)
            if not m:
                continue
            for name in (x.strip() for x in m.group(1).split(",")):
                if name in first:
                    print(f"{f}:{n} {name} (first at line {first[name]})")
                    bad += 1
                else:
                    first[name] = n
    if not seen_any:
        print("nothing to read")
        return 2
    print(f"повторных имён верхнего уровня: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
