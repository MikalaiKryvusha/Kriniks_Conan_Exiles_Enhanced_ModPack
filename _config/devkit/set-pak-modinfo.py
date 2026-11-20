# set-pak-modinfo.py -- write the fields the GAME'S OWN mod list shows (modinfo.json: description, changeNote, author, authorUrl) into every mod pak
# under a folder, from the pack's README table, without a re-cook. Run on the release export (before the volumes) and on the working game's Mods.
#
#   python -I -X utf8 set-pak-modinfo.py <folder with *.pak> [--only <pak file name>] [--dry-run] [--work <dir>]
#   python -I -X utf8 set-pak-modinfo.py <folder with *.pak> --check-krinik
#     the guard of KUMM HOUSE_RULES rule 40 (the release export, the working game's Mods): reads every pak, writes nothing; each Krinik pak mod of the
#     manifest must be found once and carry the author, the author URL and THIS release's change note of krinik_modinfo.py. Exit 0 all right, 1 a pak
#     with an empty or stale field, or a Krinik pak mod not found, 2 bad arguments. [NOT-TESTED]
#
# WHY. The owner 2026-11-03 12:58–12:59 (KUMM plan 44, verbatim there): «и ещё нужно все моды KRINIK описать, авторство, и остальные поля» · «которые
# встроенный мод менеджер игры принимает и отображает» · «и всем модам переписать описания правильно, без лишних символов, которые не рендерятся»
# (his frame: a Workshop description drawn raw — «[h1][b]CONTENT[/b][/h1]», URLs; the Krinik paks: «Автор --», «URL автора --», «Список изменений --»).
# The texts: the README's Russian table «Моды сборки» (`_config/public_release/README.draft.md`, built from the manifest and the guide) — one line of
# plain Russian per mod, the same the Nexus page and the guide carry. A pak is matched to its row by the Workshop id in its modinfo (the row links the
# Workshop page), else by the mod's name. Krinik mods: author, author URL and change note from krinik_modinfo.py — the one source the pak builders
# read too (KUMM HOUSE_RULES 40; until 2026-11-20 the constants here and a change note naming only the build version).
# Other mods: the author kept (README's when empty), the author URL kept (the mod page when empty), the change note cleaned of BBCode and links.
# The pak rebuild is set-pak-version.py's: only modinfo.json changes (its MD5 and, when the manifest has the block, its XXH128 — kit_manifest.py), repak V11,
# the same mount point; checks — the file list equal, every other file byte-equal, the fields read back. A wrapper whose fields are already right but whose
# modinfo hashes are stale (an edit by a pre-2026-11-14 version) is rewritten too. A pak without the kit wrapper (no manifest.json) is reported and left as it is.
# Exit: 0 all matched paks written or already equal · 1 some pak failed a check or had no README row · 2 bad arguments.
# [TESTED: 2026-11-14 · --only on a copy of Frequent_meteors.pak (an <xxh128> pak): the Russian description written, manifest MD5 + XXH128 10/10 · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
import json, os, re, shutil, subprocess, sys

REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
MOUNT = "../../../ConanSandbox/Mods/"
INNER = "ConanSandbox/Mods"
PACK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
README = os.path.join(PACK, "_config", "public_release", "README.draft.md")
# The game lists only cooked paks: a wrapper without AssetRegistry.bin is refused («Missing platform-specific pak», then «Missing AssetRegistry.bin
# in mod folder», probes 2026-11-03 13:19–13:21). Until our pak-less mods get kit-built info paks (plan 44 step 4, moved to 1.0.0), the Krinik paks name them.
# Since 2026-11-14 the list is DERIVED from modpack.json (Krinik mods that ship, `export` not false, of a kind other than «pak»): the hard-coded note of
# 2026-11-03 named KrinikConanGraphics as unseen while its own pak headed the list (since 2026-11-07) and missed Locomotion and EngineTweaks — and called
# them all UE4SS mods, while the translation ships files and the engine tweaks a config (KUMM plan 53 step 13).
COUNT_WORDS = {1: "один", 2: "два", 3: "три", 4: "четыре", 5: "пять", 6: "шесть", 7: "семь", 8: "восемь", 9: "девять"}
MODIFIED_NOTE = "Доработано для сборки Krinik Mod Pack (KRINIK MODIFIED): перевод на русский язык, исправления интерфейса и ошибок."
ROW = re.compile(r"^\| (\d+) \| \[(.+?)\]\((.+?)\)(<br><sub>KRINIK MODIFIED</sub>)? \| (.+?) \| (.+?) \|$")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_manifest  # noqa: E402 — both manifest hashes of modinfo.json (MD5 + «<xxh128>»)
import krinik_modinfo  # noqa: E402 — author, author URL, change note of the Krinik paks (KUMM HOUSE_RULES 40)
md5 = kit_manifest.md5


def plural_form(n):
    """Russian agreement by the number's last digits: 0 — «один мод», 1 — «два мода», 2 — «пять модов» (21 мод, 22 мода, 11–14 модов)."""
    if n % 10 == 1 and n % 100 != 11:
        return 0
    return 1 if 2 <= n % 10 <= 4 and not 12 <= n % 100 <= 14 else 2


def unlisted_krinik_note(pack=None):
    """«Ещё N модов сборки Krinik Mod Pack ставятся без пака, и в этом списке их нет: A, B и C.» from the manifest (sorted by name)."""
    with open(os.path.join(pack or PACK, "modpack.json"), encoding="utf-8") as fh:
        m = json.load(fh)
    names = sorted(x["name"] for x in m["mods"] if x["name"].startswith("Krinik") and x.get("export", True) is not False and x.get("kind") != "pak")
    n = len(names)
    if not n:
        return ""
    lst = names[0] if n == 1 else ", ".join(names[:-1]) + " и " + names[-1]
    form = plural_form(n)
    noun = ("мод", "мода", "модов")[form]
    one = form == 0                                          # «21 мод … ставится без пака, и в этом списке его нет»
    # A whole sentence from the cause: the dash stood where a verb of reason belongs (KUMM HOUSE_RULES 33; the writer's read 2026-11-20). [NOT-TESTED]
    return "Ещё %s %s сборки Krinik Mod Pack %s без пака, и в этом списке %s нет: %s." % (
        COUNT_WORDS.get(n, str(n)), noun, "ставится" if one else "ставятся", "его" if one else "их", lst)


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode:
        raise RuntimeError("repak failed: %s\n%s" % (" ".join(args), r.stderr[-800:]))
    return r.stdout


def norm(s):
    return re.sub(r"[^0-9a-zа-яё]+", "", s.lower())


def readme_rows():
    text = open(README, encoding="utf-8").read()
    part = text[text.index("## 2. Состав сборки"):text.index("## 3. Установка")]
    rows = []
    for line in part.splitlines():
        m = ROW.match(line)
        if m:
            _, name, link, mod, author, what = m.groups()
            wid = re.search(r"[?&]id=(\d+)", link)
            rows.append({"name": name, "link": link if link.startswith("http") else "", "modified": bool(mod),
                         "author": author.replace("\\$", "$"), "desc": what.replace("\\$", "$").strip(), "wid": wid.group(1) if wid else None})
    return rows


def clean(s):
    s = re.sub(r"\[/?[a-zA-Z0-9]+(=[^\]]*)?\]", "", s or "")
    s = re.sub(r"https?://\S+", "", s)
    s = s.replace("\r", "")
    s = re.sub(r"[ \t]+", " ", s)
    s = re.sub(r"\n\s*\n+", "\n", s).strip()
    return s


def fields_for(mi, rows):
    wid = (mi.get("steamWorkshopFileIds") or {}).get("mainClient") or ""
    row = next((r for r in rows if r["wid"] and r["wid"] == wid), None)
    if not row:
        keys = {norm(mi.get("name", "")), norm(mi.get("folderName", ""))}
        row = next((r for r in rows if norm(r["name"]) in keys), None)
        if not row:
            row = next((r for r in rows if any(k and (norm(r["name"]) in k or k in norm(r["name"])) for k in keys)), None)
    if not row:
        return None, None
    krinik = row["name"].startswith("Krinik")
    if krinik:
        note = unlisted_krinik_note()
        f = {"description": row["desc"] + ("\n\n" + note if note else ""), **krinik_modinfo.expected(mi.get("folderName") or row["name"])}
    else:
        desc = row["desc"] + ("\n\n" + MODIFIED_NOTE if row["modified"] else "")
        author = (mi.get("author") or "").strip()
        url = (mi.get("authorUrl") or "").strip()
        if re.match(r"https?://", author):          # Corpse Stripper: the author field holds the profile link
            author, url = row["author"], url or author
        if not re.match(r"(https?://)?[\w.-]+\.[a-z]{2,}(/|$)", url):   # ModControlPanel: «hades aka EZee_AP» in the URL field
            url = row["link"]
        f = {"description": desc, "changeNote": clean(mi.get("changeNote", "")), "author": author or row["author"], "authorUrl": url}
    # The list shows the author's raw title («Edit Appearance 1.2.8 (Update for game item ch…», «IMMERSIVE WARRIORS ENHANCED - WORK IN…»,
    # «ResourceStimulusPackage», 2026-11-03 frame): the README's name instead. Our pack manager counts mods by modlist.txt file names, not titles.
    f["name"] = row["name"]
    return f, row["name"]


def listing(pak):
    return sorted(l.strip() for l in run([REPAK, "list", pak]).splitlines() if l.strip())


def write_one(pak, rows, work_root, dry):
    try:
        before = listing(pak)
    except RuntimeError as e:
        return "skip", "not readable by repak: " + str(e).splitlines()[0][:100]
    if INNER + "/modinfo.json" not in before or INNER + "/manifest.json" not in before:
        return "skip", "no kit wrapper"
    mi = json.loads(run([REPAK, "get", pak, INNER + "/modinfo.json"]).lstrip("\ufeff"))
    f, rname = fields_for(mi, rows)
    if not f:
        return "fail", "no README row for «%s» (folder %s)" % (mi.get("name"), mi.get("folderName"))
    if all((mi.get(k) or "") == v for k, v in f.items()):
        # the fields are right — but a wrapper edited by the pre-2026-11-14 script may still carry a STALE <xxh128> of modinfo.json (judge 2026-11-14,
        # finding 3): «already equal» only when both manifest hashes match the bytes; otherwise rewrite, which re-hashes
        got = [subprocess.run([REPAK, "get", pak, INNER + "/" + n], capture_output=True) for n in ("manifest.json", "modinfo.json")]
        if all(r.returncode == 0 and r.stdout for r in got):     # a failed read (rc 1, empty) is not «equal» — the rewrite path reports it (judge round 2, D3)
            try:
                man_now = json.loads(got[0].stdout.decode("utf-8-sig"))
                # no modinfo entry at all → «already equal», as set-pak-version.py answers (judge round 4, 1); only a STALE entry is rewritten
                if "modinfo.json" not in man_now or kit_manifest.data_ok(man_now, "modinfo.json", got[1].stdout):
                    return "ok", "%s — already equal" % rname
            except ValueError:
                pass
    if dry:
        return "ok", "%s — would write (author «%s», url %s, desc %d chars)" % (rname, f["author"], f["authorUrl"] or "--", len(f["description"]))
    work = os.path.join(work_root, "spm-" + os.path.basename(pak))
    shutil.rmtree(work, ignore_errors=True)
    run([REPAK, "unpack", "-q", "-o", work, pak])
    d = os.path.join(work, *INNER.split("/"))
    sums = {n: md5(os.path.join(d, n)) for n in os.listdir(d)}
    mi_path = os.path.join(d, "modinfo.json")
    raw = open(mi_path, "rb").read()
    mi_full = json.loads(raw.decode("utf-8-sig"))
    mi_full.update(f)
    text = json.dumps(mi_full, ensure_ascii=False, indent="\t").replace("\n", "\r\n")
    open(mi_path, "wb").write((b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8"))
    man_path = os.path.join(d, "manifest.json")
    man = json.loads(open(man_path, encoding="utf-8-sig").read())
    if "modinfo.json" not in man:
        shutil.rmtree(work, ignore_errors=True)
        return "fail", "manifest.json has no modinfo.json entry"
    kit_manifest.set_entry(man, "modinfo.json", mi_path)     # MD5 and, when present, the «<xxh128>» entry (2026-11-14: only the MD5 before)
    with open(man_path, "w", encoding="utf-8") as fh:        # closed before repak reads it (judge round 2, Q4)
        json.dump(man, fh, indent=2)
    out = work + ".new.pak"
    if os.path.exists(out):
        os.remove(out)
    run([REPAK, "pack", "--version", "V11", "--mount-point", MOUNT, d, out])
    after = listing(out)
    chk = work + ".check"
    shutil.rmtree(chk, ignore_errors=True)
    run([REPAK, "unpack", "-q", "-o", chk, out])
    c = os.path.join(chk, *INNER.split("/"))
    bad = [n for n, s in sums.items() if n not in ("modinfo.json", "manifest.json") and md5(os.path.join(c, n)) != s]
    mi2 = json.loads(open(os.path.join(c, "modinfo.json"), encoding="utf-8-sig").read())
    man2 = json.loads(open(os.path.join(c, "manifest.json"), encoding="utf-8-sig").read())
    ok = (after == before and not bad and all(mi2.get(k) == v for k, v in f.items())
          and kit_manifest.entry_ok(man2, "modinfo.json", os.path.join(c, "modinfo.json")))
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(chk, ignore_errors=True)
    if not ok:
        os.remove(out)
        return "fail", "%s — check failed (list %s, other files %s) — the pak is untouched" % (rname, after == before, not bad)
    os.replace(out, pak)
    return "ok", "%s — written (author «%s», desc %d chars)" % (rname, f["author"], len(f["description"]))


def check_krinik(folder):
    """KUMM HOUSE_RULES 40.3: every Krinik pak mod of the manifest is found once under the folder (by its pak file name) and its modinfo carries the
    author, the author URL and this release's change note of krinik_modinfo.py. Reads only; a missing table line, an unreadable pak, an empty or stale
    field, a pak found twice or not at all — each is a [fail]. [NOT-TESTED]"""
    want = krinik_modinfo.pak_mods()
    rel = krinik_modinfo.release()
    try:
        notes = {m: krinik_modinfo.change_note(m, rel) for m in want}
    except SystemExit as e:
        print("[fail] %s" % e)
        return 1
    seen, fails = {}, 0
    for root, _, files in os.walk(folder):
        for n in sorted(files):
            stem = os.path.splitext(n)[0]
            if not n.lower().endswith(".pak") or stem not in want:
                continue
            p = os.path.join(root, n)
            if stem in seen:
                print("[fail] %s: found twice — %s and %s" % (stem, seen[stem], p))
                fails += 1
                continue
            seen[stem] = p
            try:
                mi = json.loads(run([REPAK, "get", p, INNER + "/modinfo.json"]).lstrip("﻿"))
            except (RuntimeError, ValueError) as e:
                print("[fail] %s: modinfo.json not readable — %s" % (stem, str(e).splitlines()[0][:120]))
                fails += 1
                continue
            bad = krinik_modinfo.problems(mi, stem, rel) + ([] if mi.get("folderName") == stem else ["folderName"])
            # The manifest's MD5 and «<xxh128>» of modinfo.json must match its bytes, as the write path checks (the judge 2026-11-20, round 3, finding 5):
            # a pak whose fields are right but whose hashes are stale passed the guard. [NOT-TESTED]
            # A Krinik pak WITHOUT the modinfo entry is malformed (build-level-mod.py always writes it) and fails by its own name; the write path's «no entry →
            # already equal» stays for other authors' paks, as set-pak-version.py answers (the judge 2026-11-20, round 4, finding 6). [TESTED: 2026-11-20 · a control copy without the entry fails by name, the working game 4 / 4 ok · KUMM testcases/reports/2026-11-20_conan-launcher-judge4-fixes.md]
            got = [subprocess.run([REPAK, "get", p, INNER + "/" + n], capture_output=True) for n in ("manifest.json", "modinfo.json")]
            try:
                if not all(r.returncode == 0 and r.stdout for r in got):
                    bad.append("manifest.json or modinfo.json not readable")
                else:
                    man_now = json.loads(got[0].stdout.decode("utf-8-sig"))
                    if "modinfo.json" not in man_now:
                        bad.append("no modinfo.json entry in manifest.json")
                    elif not kit_manifest.data_ok(man_now, "modinfo.json", got[1].stdout):
                        bad.append("manifest hash of modinfo.json")
            except ValueError:
                bad.append("manifest.json not readable")
            if bad:
                fails += 1
                shown = [k for k in bad if k in krinik_modinfo.FIELDS or k == "folderName"]   # the field values; the manifest lines have none to show
                print("[fail] %s: %s%s" % (stem, ", ".join(bad), (" — " + "; ".join("%s «%s»" % (k, (mi.get(k) or "")[:60]) for k in shown)) if shown else ""))
            else:
                print("[ok] %s: author «%s», url %s, change note %d chars" % (stem, mi["author"], mi["authorUrl"], len(notes[stem])))
    for m in want:
        if m not in seen:
            print("[fail] %s: no %s.pak under %s" % (m, m, folder))
            fails += 1
    print("release %s · Krinik pak mods %d · found %d · failed %d" % (rel, len(want), len(seen), fails))
    return 1 if fails else 0


def main():
    a = sys.argv[1:]
    if "--check-krinik" in a:
        pos = [x for x in a if not x.startswith("--")]
        if len(pos) != 1 or not os.path.isdir(pos[0]):
            print("usage: set-pak-modinfo.py <folder with *.pak> --check-krinik")
            return 2
        return check_krinik(pos[0])
    dry = "--dry-run" in a
    only = a[a.index("--only") + 1] if "--only" in a else None
    work_root = os.path.abspath(a[a.index("--work") + 1]) if "--work" in a else os.path.join(os.environ.get("TEMP", "."), "set-pak-modinfo")
    pos = [x for i, x in enumerate(a) if not x.startswith("--") and (i == 0 or a[i - 1] not in ("--only", "--work"))]
    if len(pos) != 1 or not os.path.isdir(pos[0]):
        print("usage: set-pak-modinfo.py <folder with *.pak> [--only <pak file name>] [--dry-run] [--work <dir>]")
        return 2
    os.makedirs(work_root, exist_ok=True)
    rows = readme_rows()
    paks = []
    for root, _, files in os.walk(pos[0]):
        for n in files:
            if n.lower().endswith(".pak") and (not only or n.lower() == only.lower()):
                paks.append(os.path.join(root, n))
    counts = {"ok": 0, "skip": 0, "fail": 0}
    for p in sorted(paks):
        try:
            st, msg = write_one(p, rows, work_root, dry)
        except (RuntimeError, ValueError, OSError) as e:   # one pak's failure (repak, a broken manifest) is that pak's [fail], the folder run goes on (round 3, 4)
            st, msg = "fail", "%s — %s" % (type(e).__name__, str(e).splitlines()[0][:160] if str(e) else "")
        counts[st] += 1
        print("[%s] %s: %s" % (st, os.path.basename(p), msg))
    print("README rows %d · paks %d · ok %d · skipped %d · failed %d%s" % (len(rows), len(paks), counts["ok"], counts["skip"], counts["fail"], " (dry run)" if dry else ""))
    return 1 if counts["fail"] else 0


if __name__ == "__main__":
    sys.exit(main())
