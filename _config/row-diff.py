# -*- coding: utf-8 -*-
"""row-diff.py — one data-table row: the game's original against two or more mods, field by field, and the outcome A / B / C of KUMM
researches/mod-reconciliation/GUIDE.md.

WHY. `[OWNER]` 2026-11-06 «ЭТО МОЖНО РАЗВЕСТИ? ЧТО БЫ КАЖДЫЙ МОД ПРИНОСИЛ СВОЕ … и не конфликтовал с другими?» · «Ты понимаешь что нужно будет
разобраться и поршать ВСЕ конфликты?» (KUMM plan 45). The game's log names WHO overwrote a row (who-overwrites-table.py --shared-rows), not WHAT
each mod changed; the outcome needs the fields.

    python -X utf8 row-diff.py <original.json> <row>[,<row>…] <modA.json> <modB.json> [<modC.json> …]

<*.json> — UAssetGUI / uaj JSON of a DataTable (`Exports[0].Table.Data[]`): the original by `retoc to-legacy` + `uaj tojson`, a mod's by
`patch-mod-asset.py extract`. Mods in LOAD ORDER (the last one wins in the game). A side without the row is reported «absent».

Per row: every field where some side differs from the original — original · side values — then the outcome:
  A  every side that has the row equals the others (nothing lost)
  B  the sides change DISJOINT fields — a winner merging by field keeps both, a winner replacing whole rows keeps its own row only; decide by live-rows.lua
  C  two sides change one field to different values (the owner chooses)
  =  no side changes anything against the original
D (one key, two different things) is not decided by fields: a key absent from the original with very different rows — printed as «D?».
Exit 0. [TESTED: 2026-11-06 · row 51420 of three tables, read against the raw JSON · KUMM testcases/reports/2026-11-06_conan-row-diff-51420.md]
"""
import json
import sys


def rows_of(path):
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    imports = d.get("Imports", [])

    def path_of(i):
        """an object reference index → «/Package.Object» (negative = import; 2026-11-06: LootTable −67 vs −14 compared as numbers made a false C on
        17 boss rows — the index is per file, the path is the identity)"""
        parts = []
        while isinstance(i, int) and i < 0 and -i - 1 < len(imports):
            imp = imports[-i - 1]
            parts.append(str(imp.get("ObjectName")))
            i = imp.get("OuterIndex", 0)
        return ".".join(reversed(parts)) if parts else i

    for ex in d.get("Exports", []):
        data = (ex.get("Table") or {}).get("Data")
        if data is not None:
            rows = {r["Name"]: r for r in data}
            for r in rows.values():
                resolve(r, path_of)
            return rows
    return {}


def resolve(v, path_of):
    """replace the integer Value of every ObjectProperty (at any depth) with the referenced object's path, in place"""
    if isinstance(v, dict):
        if "ObjectPropertyData" in str(v.get("$type", "")) and isinstance(v.get("Value"), int):
            v["Value"] = path_of(v["Value"])
        for x in v.values():
            resolve(x, path_of)
    elif isinstance(v, list):
        for x in v:
            resolve(x, path_of)


VOLATILE = ("$type", "PropertyGuid", "IsZero", "PropertyTagFlags", "PropertyTypeName", "PropertyTagExtensions", "ArrayIndex")


def clean(v):
    """drop the serializer's bookkeeping keys at every depth — only the data stays"""
    if isinstance(v, dict):
        return {k: clean(x) for k, x in v.items() if k not in VOLATILE}
    if isinstance(v, list):
        return [clean(x) for x in v]
    return v


def fields(row):
    """field name → a comparable string of its value. A TEXT field compares by its source text (`CultureInvariantString`), never by its
    localization key: every table keys its texts by its own name (ItemTable_51420_Name vs LFS_ItemTable_51420_Name) — the first run of
    2026-11-06 called every name «changed» that way."""
    out = {}
    for p in row.get("Value", []):
        if "CultureInvariantString" in p:
            out[p["Name"]] = json.dumps({"text": p.get("CultureInvariantString")}, ensure_ascii=False)
        else:
            out[p["Name"]] = json.dumps(clean(p.get("Value")), sort_keys=True, ensure_ascii=False)
    return out


def short(s, n=70):
    s = s.replace("\n", " ")
    return s if len(s) <= n else s[: n - 1] + "…"


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    orig = rows_of(sys.argv[1])
    keys = sys.argv[2].split(",")
    sides = [(p.replace("\\", "/").rsplit("/", 1)[-1].rsplit(".", 1)[0], rows_of(p)) for p in sys.argv[3:]]
    for key in keys:
        base = fields(orig[key]) if key in orig else None
        have = [(name, fields(t[key])) for name, t in sides if key in t]
        absent = [name for name, t in sides if key not in t]
        print(f"== row {key}  (original: {'yes' if base is not None else 'NO — a new key'}; absent in: {', '.join(absent) or '—'})")
        if not have:
            # 2026-11-06: XCS_Panel лежит не в таблицах, что дали, — прежняя ветка печатала «A (identical new rows)» на пустом списке, ложный зелёный
            print("   outcome: ?? none of the given tables holds this row — find the asset that does")
            continue
        if base is None:
            same = all(h == have[0][1] for _, h in have[1:])
            print("   outcome: " + ("A (identical new rows)" if same else "D? (a new key, the sides differ — check they mean one thing)"))
            continue
        changed = {}   # field → {side: value}
        for name, f in have:
            for k, v in f.items():
                if base.get(k) != v:
                    changed.setdefault(k, {})[name] = v
        if not changed:
            print("   outcome: = (no side changes the original)")
            continue
        conflict = []
        for k, by in changed.items():
            vals = set(by.values())
            print(f"   {k}: original {short(base.get(k, '∅'))}")
            for name, v in by.items():
                print(f"      {name}: {short(v)}")
            if len(by) > 1 and len(vals) > 1:
                conflict.append(k)
        multi = [k for k, by in changed.items() if len(by) > 1 and len(set(by.values())) == 1]
        changers = {n for by in changed.values() for n in by}
        one_side = len(changers) == 1
        winner = have[-1][0]   # sides are given in LOAD ORDER — the last one holding the row wins it in the game
        # A loser's change under a winner that keeps the original value: its fate DEPENDS ON HOW THE WINNER MERGES, and only the live table shows it.
        # By field (Heritage over BMNB, 17 spawn rows; Era of Trials' *_Merge tables) — it survives. Whole row (Mines of Set over Severe Weather, item 51420;
        # EAA over BMNB, 7 spawn rows — the SAME spawn table) — it is lost. This branch said «LOST» for every pair on 2026-11-06 and a needless merge was built
        # for the Heritage bosses (KUMM EXP-0458); the files cannot decide, live-rows.lua does.
        kept = [k for k, by in changed.items() if winner not in by]
        if conflict:
            print(f"   outcome: C — same field, different values: {', '.join(conflict)}")
        elif kept:
            print(f"   outcome: B — disjoint: {', '.join(kept)} of {', '.join(sorted(changers - {winner}))} under the winner {winner}, which keeps the original — "
                  f"SURVIVES if the winner merges by field (Heritage, Era of Trials' *_Merge), LOST if it replaces whole rows (EAA, Mines of Set); decide live (_config/live-rows.lua)")
        elif one_side or (multi and len(multi) == len(changed)):
            print("   outcome: A — " + (f"only the winner {winner} changes the row" if one_side else "the sides change the same fields the same way"))
        else:
            print("   outcome: B — disjoint changes (kept if the winner merges by field; if it replaces whole rows only its own survive — decide live)"
                  + (f" (shared identical: {', '.join(multi)})" if multi else ""))
    return 0


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    sys.exit(main())
