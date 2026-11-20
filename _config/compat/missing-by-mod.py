"""Per mod: which missing vanilla packages its packages reference (from LoadErrors lines), names from names.tsv."""
import collections, glob, os, re, sys

names = dict(l.rstrip("\n").split("\t") for l in open(sys.argv[1], encoding="utf-8"))
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from game_target import sandbox  # noqa: E402  the game folder from targets.json (2026-11-13, KUMM plan 53)
logs = glob.glob(os.path.join(sandbox("Saved", "Logs"), "*.log"))
rx = re.compile(r"While trying to load package (/Game/Mods/([^/]+)/\S+), a dependent package None \(([0-9A-F]{16})\)")
mod_missing = collections.defaultdict(set)
mod_pk = collections.defaultdict(set)
for lg in logs:
    for line in open(lg, encoding="utf-8", errors="replace"):
        m = rx.search(line)
        if m:
            mod_missing[m.group(2)].add(m.group(3))
            mod_pk[m.group(2)].add(m.group(1))
def kind(n):
    if n == "?": return "unknown"
    b = n.rsplit("/", 1)[-1]
    if re.match(r"(MI?_|Ml_|MF_|T_|M_)", b) or "/Materials/" in n or "/Functions/" in n: return "visual"
    if re.match(r"(SM_|P_)", b) or "/Particles/" in n or "/Meshes/" in n: return "visual"
    if "/Sound/" in n: return "sound"
    return "GAMEPLAY"
for mod in sorted(mod_missing, key=lambda k: -len(mod_missing[k])):
    ids = mod_missing[mod]
    c = collections.Counter(kind(names.get(i, "?")) for i in ids)
    print("## %s — missing %d (%s), referencing packages %d" % (mod, len(ids), ", ".join("%s %d" % kv for kv in c.most_common()), len(mod_pk[mod])))
    for i in sorted(ids, key=lambda i: kind(names.get(i, "?"))):
        k = kind(names.get(i, "?"))
        if k in ("GAMEPLAY", "unknown", "sound"):
            refs = [p for p in mod_pk[mod]]
            print("   %-8s %s  %s" % (k, i, names.get(i, "?")))
