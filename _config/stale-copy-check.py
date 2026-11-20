# -*- coding: utf-8 -*-
"""stale-copy-check.py — a VANILLA asset a mod ships whole, read against the game: is it stale, does the mod edit it, do the mod's and the patch's edits meet?
(kind 6 of KUMM researches/mod-reconciliation/GUIDE.md)

WHY (2026-11-13, KUMM plan 53, the move onto 3.1.0): `patch-rollback.py` names 11 vanilla assets the patch changed under mods' whole copies, from the GAMES'
pak listings only — it cannot say whether the MOD edits its copy (then the copy is the mod's work: merge) or ships it untouched (then it is a stale passenger:
the game's new copy should win). `rebuild-krinik-paks.py` proves a `vanilla:` / `vanilla+own:` rebuild changed only the recipe's chunk, not that the chunk now
holds the NEW game's table; `patch-mod-asset.py extract` reads Saved/ExtractedMods, which the game refreshes only at its next start. This reads the mod's
INSTALLED pak itself and the games' own containers.

    python -I -X utf8 stale-copy-check.py <Mod> <asset> [<pak>] [--old <old game dir>] [--keep]
    python -I -X utf8 stale-copy-check.py StorageReachExpanded /Content/Systems/Cheats/CustomConsoleCommandsDataTable.uasset
    python -I -X utf8 stale-copy-check.py EnhancedArmoryAndArsenal /Content/Systems/Building/Placeables/BP_PL_Crafting_Station.uasset --old "D:/Games/Conan Exiles 3.0.1"
<asset> — the path as `patch-rollback.py` prints it (`/Content/…/X.uasset`, `/Plugins/…/X.uasset`, `/Content/…/X.umap`) or Content-relative with no extension
(`Systems/Cheats/CustomConsoleCommandsDataTable`). <pak> — read this pak instead of the installed `Mods/<Mod>.pak` (the control case: an author's original).
--old — the game BEFORE the patch: a three-way comparison by export (mod · old game · new game).

A data table: the game's rows the copy LACKS · the copy's own rows · shared rows with other VALUES; exit 0 — every game row present with the game's values.
Any other asset (by export: name → hash of its serialized bytes; a name map reordered between builds also shows as a change — read the list, not the count):
  the mod's copy vs the new game — identical or not; with --old: the mod's edits (copy vs old game), the patch's edits (old vs new game), where they meet.
  Exit 0 — the copy equals the new game's (imports included — a table too); 1 — it differs; 2 — could not read, or the mod does not ship the path.
Read-only toward the games and the mods; writes only into _scratch/stale-copy-check/<Mod>-<n> (a new folder per run), removed file by file at the end
(`--keep` keeps it).
[TESTED: 2026-11-13 · table branch: StorageReachExpanded and LegitReligious_Enhanced on 3.1.0 — installed rebuilds exit 0 (26 + 3 own; 1725), the authors'
originals exit 1 (6 and 72 game rows missing); export branch: EAA BP_PL_Crafting_Station — the built pak IDENTICAL with imports 192 = 192, the original
«differs», a path the mod does not ship exit 2 — KUMM testcases/reports/2026-11-13_conan-310-stale-vanilla-copies.md]
"""
import hashlib
import importlib.util
import json
import os
import stat
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
try:
    from game_target import GAME_DIR, sandbox  # noqa: E402
except SystemExit as e:                                 # game_target exits 1 on a broken targets.json — that is «could not read» (2), not «differs»
    print(f"could not read: targets.json — {e}")
    sys.exit(2)

# the bytecode reader of the graft (statements «by meaning»: names, objects, property paths as strings — the three copies' indices differ)
sys.path.insert(0, os.path.join(HERE, "devkit"))
_kg = importlib.util.spec_from_file_location("kismet_graft", os.path.join(HERE, "devkit", "kismet-graft.py"))
kg = importlib.util.module_from_spec(_kg)
_kg.loader.exec_module(kg)


class Script(kg.Asset):
    """kismet-graft's Asset without the function's property list — only the statements are compared here."""

    def read_ffields(self):
        pass


def meaning(ua, fn):
    """The top-level statements of a function as their meaning signatures, or None when the export holds no bytecode / cannot be read."""
    try:
        a = Script(ua, fn)
    except (kg.Stop, kg.kismet.Bad, IndexError, KeyError, ValueError, struct.error):
        return None
    return [kg.sig(a, s) for s in a.w.stmts]

TOOLS = r"D:\work\ai_sandbox\_tools"
RETOC = os.path.join(TOOLS, "retoc-5.8", "retoc.exe")
REPAK = os.path.join(TOOLS, "repak", "repak.exe")
UAJ = os.path.join(TOOLS, "src", "uaj", "bin", "Release", "net8.0", "uaj.exe")
RETOC_ENGINE = "UE5_7"              # retoc knows versions up to 5.7; the 5.8 container format is the same (patch-mod-asset.py)
UASSET_ENGINE = "VER_UE5_8"
OUTER_MOUNT = "../../../ConanSandbox/Mods/"
MODS = sandbox("Mods")
WORK_ROOT = os.path.join(os.path.dirname(HERE), "_scratch", "stale-copy-check")
SHOW = []                                               # functions to print statement by statement (--show)
STUB_MAX_STATEMENTS = 8                                 # an event-graph entry stub: a call with the entry offset, a return, the end (3–6 seen)


def imports_of(ua):
    """The import table as (package, class, object, outer) — the names the package resolved through its store entry; compared because a copy can match by
    export bytes and still bind other packages (judge 2026-11-13, findings 1 and 7: `pack-raw` keeps the OLD store entry of a replaced chunk)."""
    doc = json.load(open(os.path.splitext(ua)[0] + ".json", encoding="utf-8"))
    return [(i.get("ClassPackage"), i.get("ClassName"), i.get("ObjectName"), i.get("OuterIndex")) for i in doc.get("Imports", [])]


def paks(game):
    return os.path.join(game, "ConanSandbox", "Content", "Paks")


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        print(f"code {r.returncode}: {' '.join(args)}\n{r.stdout[-1500:]}\n{r.stderr[-1500:]}")
        sys.exit(2)
    return r.stdout


def link_all(src_dir, dst_dir, names):
    os.makedirs(dst_dir, exist_ok=True)
    for fn in names:
        os.link(os.path.join(src_dir, fn), os.path.join(dst_dir, fn))   # hard links: same volume D:, nothing copied, nothing inside a game written


def game_view(game, dst):
    """The game's containers only — `global.*` and `pakchunk*` (a `_paksview-<version>` folder holds mods' containers too, and the same path would come
    out of a mod). <game> — a game folder, or a folder of containers itself (`D:/work/ai_sandbox/_paksview-2.2.3`, the only 2.2.3 left on disk)."""
    src = game if any(f.endswith(".utoc") for f in os.listdir(game)) else paks(game)
    link_all(src, dst, [f for f in os.listdir(src) if f.endswith((".utoc", ".ucas")) and f.lower().startswith(("global.", "pakchunk"))])
    return dst


def resolve(asset):
    """→ (retoc filter = the bare name, the file under ConanSandbox/ of a to-legacy output)."""
    a = asset.replace("\\", "/")
    if "/Program Files/Git/" in a:                       # Git Bash rewrote a leading «/Content/…» into «C:/Program Files/Git/Content/…» (MSYS path conversion)
        a = "/" + a.split("/Program Files/Git/", 1)[1]
    if a.startswith("/Game/"):                           # the package spelling of the recipes and the .tsv headers
        a = "Content/" + a[len("/Game/"):]
    if a.lstrip("/").startswith(("Content/", "Plugins/")) and not os.path.splitext(a)[1]:
        a += ".uasset"
    if a.lstrip("/").startswith(("Content/", "Plugins/")) and os.path.splitext(a)[1] in (".uasset", ".umap"):
        rel = a.lstrip("/")
    else:
        rel = "Content/" + a.strip("/") + ".uasset"
    return os.path.splitext(os.path.basename(rel))[0], rel


def extract(view, filt, rel, out):
    legacy = os.path.join(out, "legacy")
    run([RETOC, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", filt, view, legacy])
    ua = os.path.join(legacy, "ConanSandbox", *rel.split("/"))
    if not os.path.isfile(ua):
        print(f"retoc gave no {rel} from {view}")
        sys.exit(2)
    return ua


def exports(ua):
    """[(type, name)] in table order and {name#k: sha1 of its serialized bytes}; the bytes live in the .uexp (offsets from the smallest SerialOffset)."""
    stem = os.path.splitext(ua)[0]
    uexp = open(stem + ".uexp", "rb").read()
    order, out, seen = [], {}, {}
    listing = run([UAJ, "exports", ua, UASSET_ENGINE])
    open(stem + ".exports.tsv", "w", encoding="utf-8").write(listing)        # kismet-graft's Asset reads <stem>.exports.tsv and <stem>.json
    run([UAJ, "tojson", ua, stem + ".json", UASSET_ENGINE])
    for line in listing.splitlines():
        if not line.strip():
            continue
        off, size, typ, name = line.split("\t", 3)
        seen[name] = seen.get(name, 0) + 1
        key = name if seen[name] == 1 else f"{name}#{seen[name]}"
        order.append((typ, key))
        out[key] = hashlib.sha1(uexp[int(off):int(off) + int(size)]).hexdigest()
    return order, out


def table(ua, out):
    """A data table → {row name: its fields as canonical JSON} via uaj tojson."""
    jp = os.path.join(out, "table.json")
    run([UAJ, "tojson", ua, jp, UASSET_ENGINE])
    doc = json.load(open(jp, encoding="utf-8"))
    data = doc["Exports"][0]["Table"]["Data"]
    return {r["Name"]: json.dumps(r.get("Value"), sort_keys=True, ensure_ascii=False) for r in data}


def changed(a, b):
    """Export keys whose bytes differ, and those present on one side only."""
    return (sorted(k for k in set(a) & set(b) if a[k] != b[k]), sorted(set(b) - set(a)), sorted(set(a) - set(b)))


def stmt_delta(a, b, fn=""):
    """«+i −d ~r of n»: statements inserted, deleted, replaced in b against a (difflib over the meaning signatures); «entry shift only» when every
    differing statement is a call into the event graph — a stub whose only change is the graph's entry offset (an int constant), i.e. the event graph moved,
    not this function (first read 2026-11-13: 17 such stubs in BP_PL_Crafting_Station)."""
    import difflib
    ins = dele = rep = 0
    touched = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        touched += a[i1:i2] + b[j1:j2]
        if tag == "insert":
            ins += j2 - j1
        elif tag == "delete":
            dele += i2 - i1
        else:
            rep += max(i2 - i1, j2 - j1)
    # only a short function can be a stub: a latent call inside the event graph also names `ExecuteUbergraph_<BP>` (its FLatentActionInfo), and a real Delay
    # change there must never read as a shift (judge 2026-11-13, finding 6); the stubs read so far have 3–6 statements
    stub = (touched and len(a) <= STUB_MAX_STATEMENTS and not fn.startswith("ExecuteUbergraph_")
            and all(b"ExecuteUbergraph" in s for s in touched))
    return ("entry shift only, " if stub else "") + f"+{ins} -{dele} ~{rep} of {len(a)}"


def readable(sig, width=160):
    """A statement signature as text: the strings it names (functions, properties, objects), the bytes in between as dots."""
    s = sig.decode("latin-1")
    return "".join(c if 32 <= ord(c) < 127 else "." for c in s)[:width]


def show_function(ua_old, ua_mod, ua_new, fn):
    """The statements of one function where the mod or the patch differ from the old game — old · mod · new side by side, by meaning."""
    import difflib
    so, sm, sn = meaning(ua_old, fn), meaning(ua_mod, fn), meaning(ua_new, fn)
    for label, other in (("MOD", sm), ("PATCH", sn)):
        print(f"  -- {fn}: the {label}'s edits against the old game --")
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, so, other, autojunk=False).get_opcodes():
            if tag == "equal":
                continue
            for i in range(i1, i2):
                print(f"    old[{i}] {readable(so[i])}")
            for j in range(j1, j2):
                print(f"    {label.lower()}[{j}] {readable(other[j])}")


def show(label, keys):
    print(f"  {label}: {len(keys)} {keys[:24]}{' …' if len(keys) > 24 else ''}")


def clean(work):
    """The run's folder, file by file (the house forbids a recursive delete); a hard link removed drops only its name — the game's pak stays."""
    n = 0
    for dp, dns, fns in os.walk(work, topdown=False):
        for fn in fns:
            os.chmod(os.path.join(dp, fn), stat.S_IWRITE)   # retoc / repak sometimes leave files read-only (rebuild-krinik-paks.py)
            os.remove(os.path.join(dp, fn))
            n += 1
        os.rmdir(dp)
    return n


def main():
    argv = sys.argv[1:]
    keep = "--keep" in argv
    old = None
    if "--old" in argv:
        i = argv.index("--old")
        old = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    while "--show" in argv:                              # --show <function>: its differing statements, old · mod · new (with --old)
        i = argv.index("--show")
        SHOW.append(argv[i + 1])
        argv = argv[:i] + argv[i + 2:]
    args = [a for a in argv if a != "--keep"]
    if len(args) not in (2, 3):
        print(__doc__)
        sys.exit(2)
    mod, (filt, rel) = args[0], resolve(args[1])
    pak = args[2] if len(args) == 3 else os.path.join(MODS, mod + ".pak")
    if not os.path.isfile(pak):
        print(f"no {pak}")
        sys.exit(2)
    n = 1
    while os.path.exists(os.path.join(WORK_ROOT, f"{mod}-{n}")):
        n += 1
    work = os.path.join(WORK_ROOT, f"{mod}-{n}")
    os.makedirs(work)                                   # repak does not create the parent of -o (os error 3, first run 2026-11-13)
    try:
        bad = compare(mod, rel, filt, pak, old, work)
    finally:                                            # a failed run (exit 2) is cleaned too — its folder is never read again
        if keep:
            print(f"  work kept: {work}")
        else:
            print(f"  work removed: {clean(work)} files")
    sys.exit(1 if bad else 0)


def compare(mod, rel, filt, pak, old, work):
    outer = os.path.join(work, "outer")
    run([REPAK, "unpack", "-q", "-s", OUTER_MOUNT, "-o", outer, pak])
    box = outer if os.path.exists(os.path.join(outer, f"{mod}-Windows.utoc")) else os.path.join(outer, "ConanSandbox", "Mods")
    # the mod must ship the path: otherwise the `_P` view hands out the GAME's copy and every check reads «identical» (judge 2026-11-13, finding 5).
    # `retoc manifest <utoc>` writes pakstore.json into the CURRENT folder (package → its files); `retoc list` prints chunk ids only, no paths.
    r = subprocess.run([RETOC, "manifest", os.path.abspath(os.path.join(box, f"{mod}-Windows.utoc"))], cwd=work,
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    store = os.path.join(work, "pakstore.json")
    if r.returncode != 0 or not os.path.isfile(store):
        print(f"retoc manifest failed for {mod}: {r.stdout[-500:]} {r.stderr[-500:]}")
        sys.exit(2)
    files = [d.get("filename", "").replace("\\", "/") for e in json.load(open(store, encoding="utf-8"))["oplog"]["entries"] for d in e.get("packagedata", [])]
    if not any(f.endswith("/" + rel) for f in files):
        print(f"{mod} does not ship /{rel} ({len(files)} packages in its container) — nothing to compare")
        sys.exit(2)
    # the mod's view (the priority_view of patch-mod-asset.py): every container of the new game + the mod's as `<Mod>_P` — retoc ranks `_P` above all, so
    # the copy that comes out is the MOD's, and its references to the game resolve (a view of global + the mod alone printed /Engine/UnknownPackage
    # in place of BP_PlaceableItemContainer, 2026-11-13 — a false «edit» of the mod)
    vm = game_view(GAME_DIR, os.path.join(work, "view-mod"))
    for ext in (".utoc", ".ucas"):
        os.link(os.path.join(box, f"{mod}-Windows{ext}"), os.path.join(vm, f"{mod}_P{ext}"))
    ua_new = extract(game_view(GAME_DIR, os.path.join(work, "view-game")), filt, rel, os.path.join(work, "game"))
    ua_mod = extract(os.path.join(work, "view-mod"), filt, rel, os.path.join(work, "mod"))
    order, new = exports(ua_new)
    _, cp = exports(ua_mod)
    print(f"{mod} · /{rel} (game {os.path.basename(os.path.normpath(GAME_DIR))})")
    im_new, im_mod = imports_of(ua_new), imports_of(ua_mod)
    unknown = sum(1 for x in im_mod if "UnknownPackage" in str(x) or "UnknownExport" in str(x))
    im_diff = sum(1 for a, b in zip(im_new, im_mod) if a != b) + abs(len(im_new) - len(im_mod))
    print(f"  imports: game {len(im_new)} · mod's copy {len(im_mod)} · "
          f"{'equal' if not im_diff else f'differ in {im_diff}'}{f' · UNRESOLVED in the copy: {unknown}' if unknown else ''}")
    bad = bool(im_diff or unknown)
    if order and order[0][0] == "DataTableExport":
        game, copy = table(ua_new, os.path.join(work, "game")), table(ua_mod, os.path.join(work, "mod"))
        lacks, own = sorted(set(game) - set(copy)), sorted(set(copy) - set(game))
        differ = sorted(k for k in set(game) & set(copy) if game[k] != copy[k])
        print(f"  rows: game {len(game)} · mod's copy {len(copy)}")
        show("game rows the copy LACKS", lacks)
        show("rows only in the copy (the mod's own)", own)
        show("shared rows with other VALUES", differ)
        bad = bad or bool(lacks or differ)
    else:
        print(f"  exports: game {len(new)} · mod's copy {len(cp)} · first export {order[0][0] if order else '-'}")
        d, only_cp, only_new = changed(new, cp)
        same = not (d or only_cp or only_new or bad)
        print(f"  the mod's copy vs the NEW game: {'IDENTICAL' if same else 'differs'}")
        bad = not same
        if old:
            ua_old = extract(game_view(old, os.path.join(work, "view-old")), filt, rel, os.path.join(work, "old"))
            _, ov = exports(ua_old)
            m_d, m_add, m_del = changed(ov, cp)
            p_d, p_add, p_del = changed(ov, new)
            mod_keys, patch_keys = set(m_d + m_add + m_del), set(p_d + p_add + p_del)
            if imports_of(ua_old) != im_mod:              # «untouched» needs the OLD game's imports too, not only its export bytes (judge round 2)
                mod_keys.add("<the import table>")
            print(f"  the mod's copy vs the OLD game ({os.path.basename(os.path.normpath(old))}): "
                  f"{'IDENTICAL — the mod ships the old game copy untouched' if not mod_keys else 'the mod EDITS it'}")
            show("the mod's edits — exports changed", m_d)
            show("the mod's edits — exports added", m_add)
            show("the mod's edits — exports removed", m_del)
            show("the patch's edits — exports changed", p_d)
            show("the patch's edits — exports added", p_add)
            show("the patch's edits — exports removed", p_del)
            show("exports BOTH changed by bytes", sorted(mod_keys & patch_keys))
            # By MEANING (the bytes shift whenever the patch adds a name to the name map): every export that holds bytecode, its statements with
            # names / objects / property paths as strings — the same signature kismet-graft aligns by.
            fns = [k for k in sorted(set(ov) | set(cp) | set(new)) if "#" not in k]
            m_fn, p_fn, unread = [], [], []
            for k in fns:
                so, sm, sn = meaning(ua_old, k), meaning(ua_mod, k), meaning(ua_new, k)
                if so is None and sm is None and sn is None:
                    continue                                   # not a function (a component, the class, defaults) — bytes only, above
                if None in (so, sm, sn):
                    unread.append(k)
                    continue
                if sm != so:
                    m_fn.append(f"{k} ({stmt_delta(so, sm, k)})")
                if sn != so:
                    p_fn.append(f"{k} ({stmt_delta(so, sn, k)})")
            print("  BY MEANING (bytecode statements):")
            show("functions the MOD changed", m_fn)
            show("functions the PATCH changed", p_fn)
            show("functions BOTH changed — the graft must stop or be read", sorted({x.split(' (')[0] for x in m_fn} & {x.split(' (')[0] for x in p_fn}))
            show("functions not readable in one of the copies", unread)
            for fn in SHOW:
                show_function(ua_old, ua_mod, ua_new, fn)
        else:
            show("exports that differ", d)
            show("exports only in the copy", only_cp)
            show("exports only in the game", only_new)
    return bad


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as e:                               # any failure is «could not read» (2), never «differs» (1) — judge 2026-11-13, finding 8
        print(f"could not read: {type(e).__name__}: {e}")
        sys.exit(2)
