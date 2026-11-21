# t_make_manifest.py -- the self-test of make_manifest.py on small synthetic exports (SMALL = 1 KiB, PART = 4 KiB), no network, no game.
#
#   python -I -X utf8 _config/release/t_make_manifest.py        # exit 0 — every case passes; 1 — a case failed (named)
#
# The cases are the judge's findings of 2026-11-21 (round 1 on make_manifest.py) turned into checks, plus the determinism and the parts boundaries.
# [NOT-TESTED]
import contextlib, hashlib, importlib.util, io, json, os, shutil, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("mm", os.path.join(HERE, "make_manifest.py"))
mm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mm)
mm.SMALL, mm.PART = 1024, 4096
results = []


def run(*args):
    out = io.StringIO()
    sys.argv = ["make_manifest.py"] + [str(a) for a in args]
    with contextlib.redirect_stdout(out):
        code = mm.main()
    return code, out.getvalue()


def put(root, rel, data):
    p = os.path.join(root, *rel.split("/"))
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as fh:
        fh.write(data)


def check(name, ok, detail=""):
    results.append((name, bool(ok)))
    print("%-4s %s%s" % ("ok" if ok else "FAIL", name, (" — " + str(detail)) if detail and not ok else ""))


def sha(b):
    return hashlib.sha256(b).hexdigest()


def export(root, variant=0):
    put(root, "README.txt", b"readme %d" % variant)                         # small → the group
    put(root, "pack/modpack.json", b"{}")                                   # small
    put(root, "pack/src/Foo/Foo.pak", b"F" * 2000)                          # 1–4 KiB → one asset
    put(root, "pack/src/KrinikConanUI/KrinikConanUI.pak", b"K%d" % variant * 1500)
    put(root, "pack/src/Big/Big.pak", b"B" * 4096)                          # exactly PART → one part
    put(root, "pack/src/Huge/Huge.pak", bytes(range(256)) * 32 + b"x")      # PART*2 + 1 → three parts


with tempfile.TemporaryDirectory() as t:
    ex = os.path.join(t, "Krinik_Mod_Pack_9_9_9"); export(ex)
    a, b = os.path.join(t, "a"), os.path.join(t, "b")
    ca, oa = run(ex, "--tag", "v9.9.9", "--version", "9.9.9", "--out", a)
    cb, ob = run(ex, "--tag", "v9.9.9", "--version", "9.9.9", "--out", b)
    ma, mb = open(os.path.join(a, "manifest.json"), "rb").read(), open(os.path.join(b, "manifest.json"), "rb").read()
    files_a = {n: sha(open(os.path.join(a, n), "rb").read()) for n in os.listdir(a)}
    files_b = {n: sha(open(os.path.join(b, n), "rb").read()) for n in os.listdir(b)}
    check("S1 two runs: the same manifest and the same assets", ca == cb == 0 and ma == mb and files_a == files_b, oa + ob)
    # S1b: a re-export with other file times gives the same bytes (the fixed zip time; the judge's round 2: S1 alone ran within one second)
    ex1b = os.path.join(t, "v1b", "Krinik_Mod_Pack_9_9_9"); shutil.copytree(ex, ex1b)
    for d, _, fs in os.walk(ex1b):
        for n in fs:
            os.utime(os.path.join(d, n), (946684800, 946684800))          # 2000-01-01
    c1b, o1b = run(ex1b, "--tag", "v9.9.9", "--version", "9.9.9", "--out", os.path.join(t, "a1b"))
    check("S1b a re-export with other file times: the same manifest", c1b == 0 and open(os.path.join(t, "a1b", "manifest.json"), "rb").read() == ma, o1b)
    man = json.loads(ma)
    by = {f["path"]: f for f in man["files"]}
    big, huge = by["pack/src/Big/Big.pak"], by["pack/src/Huge/Huge.pak"]
    check("S2a a file of exactly PART bytes → one part", [p["size"] for p in big["parts"]] == [4096], big)
    check("S2b PART*2+1 bytes → parts 4096, 4096, 1", [p["size"] for p in huge["parts"]] == [4096, 4096, 1], huge)
    joined = b"".join(open(os.path.join(a, p["asset"]), "rb").read() for p in huge["parts"])
    check("S2c the parts join to the file's SHA-256", sha(joined) == huge["sha256"])
    check("S2d every asset, part and group named in the manifest exists", all(os.path.exists(os.path.join(a, n)) for f in man["files"]
          for n in ([f["asset"]] if "asset" in f else [p["asset"] for p in f["parts"]] if "parts" in f else [f["group"]])))
    check("S2e the group carries exactly the small files", man["groups"][0]["files"] == sum(1 for f in man["files"] if "group" in f) == 2)

    # S3: only a small file changed → check-only estimates the group, not 0 (the judge's defect 1)
    # S3: two small files changed → check-only counts the NEW group once (the judge's defect 1 of round 1; «once» — round 2)
    ex2 = os.path.join(t, "v2", "Krinik_Mod_Pack_9_9_9"); export(ex2); put(ex2, "README.txt", b"readme changed"); put(ex2, "pack/modpack.json", b"{ }")
    c3, o3 = run(ex2, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(a, "manifest.json"))
    g = [l for l in o3.splitlines() if l.startswith("changed vs")]
    # the NEW group is downloaded once: the old one + the longer README + the longer modpack.json
    gsize = json.loads(ma)["groups"][0]["size"] + len(b"readme changed") - len(b"readme 0") + len(b"{ }") - len(b"{}")
    check("S3 --check-only counts the new group once for two changed small files", c3 == 0 and g and "(%d B;" % gsize in g[0] and "2 files" in g[0], "%s · group %d B" % (o3, gsize))

    # S4: a case-only rename is not «add + remove» (the judge's risk 3)
    ex4 = os.path.join(t, "v4", "Krinik_Mod_Pack_9_9_9"); export(ex4)
    os.rename(os.path.join(ex4, "pack", "src", "Foo", "Foo.pak"), os.path.join(ex4, "pack", "src", "Foo", "foo.tmp"))
    os.rename(os.path.join(ex4, "pack", "src", "Foo", "foo.tmp"), os.path.join(ex4, "pack", "src", "Foo", "foo.pak"))
    c4, o4 = run(ex4, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(a, "manifest.json"))
    check("S4 a case-only rename: no file added or removed", c4 == 0 and "added 0, changed 0, removed 0)" in o4, o4)

    # S5: a rerun of another export into the same dir removes the assets the new manifest does not name (the judge's risk 4)
    ex5 = os.path.join(t, "v5", "Krinik_Mod_Pack_9_9_9"); export(ex5, 1)
    shutil.rmtree(os.path.join(ex5, "pack", "src", "Foo"))
    # the release dir also holds what make_release.sh puts there: the volume parts, the guide, the launcher, the checksums — they must survive (round 2, 3)
    keep = ["Krinik_Mod_Pack_9_9_9.zip.001", "Krinik_Mod_Pack_9_9_9.zip.002", "Krinik-Conan-3.1.1-guide.pdf", "KrinikConanLauncher.exe", "SHA256SUMS.txt"]
    for n in keep:
        put(a, n, b"keep")
    c5, o5 = run(ex5, "--tag", "v9.9.9", "--version", "9.9.9", "--out", a)
    names5 = set(os.listdir(a))
    man5 = json.loads(open(os.path.join(a, "manifest.json"), encoding="utf-8").read())
    want5 = {"manifest.json"} | set(keep) | {n for f in man5["files"] for n in ([f["asset"]] if "asset" in f else [p["asset"] for p in f["parts"]] if "parts" in f else [f["group"]])}
    check("S5 stale assets of the earlier run are removed", c5 == 0 and names5 == want5 and "removed stale asset" in o5, sorted(names5 ^ want5))

    # S6: a previous manifest with a UTF-8 BOM is read (the judge's risk 7)
    bom = os.path.join(t, "bom.json")
    open(bom, "wb").write(b"\xef\xbb\xbf" + mb)
    c6, o6 = run(ex, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", bom)
    check("S6 a BOM in the previous manifest is accepted", c6 == 0 and "changed vs 9.9.9: 0 files" in o6, o6)

    # S7: the previous release is picked by version in release order, never by the file's date (the judge's risk 2)
    pub = os.path.join(t, "pub")
    for v in ["0.9.1", "0.9.1-RC10", "0.9.0", "0.9.1-RC2"]:
        put(pub, "published_%s/manifest.json" % v.replace(".", "_"), json.dumps({"version": v, "files": [], "groups": []}).encode())
    picks = {v: mm.pick_previous(pub, v) for v in ["0.9.1-RC3", "0.9.1", "0.9.2", "0.9.0", "0.9.1-RC11"]}
    got = {v: (json.load(open(p))["version"] if p else None) for v, p in picks.items()}
    check("S7 previous by release order", got == {"0.9.1-RC3": "0.9.1-RC2", "0.9.1": "0.9.1-RC10", "0.9.2": "0.9.1", "0.9.0": None, "0.9.1-RC11": "0.9.1-RC10"}, got)

    # S8: the reproducibility guard stops on a third-party pak that changed, unless the allow file names it; a Krinik pak may change
    ex8 = os.path.join(t, "v8", "Krinik_Mod_Pack_9_9_9"); export(ex8, 1); put(ex8, "pack/src/Foo/Foo.pak", b"G" * 2000)
    c8, o8 = run(ex8, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(b, "manifest.json"))
    check("S8a a changed third-party pak without an allow line → exit 1", c8 == 1 and "NOT EXPECTED" in o8 and "[fail] 1 third-party" in o8, o8)
    allow = os.path.join(t, "allow.txt"); open(allow, "w", encoding="utf-8").write("pack/src/foo/*   # Foo 2.0 from its author\n")
    c8b, o8b = run(ex8, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(b, "manifest.json"), "--allow-changed", allow)
    check("S8b the same with the allow line → exit 0, the reason printed", c8b == 0 and "[allowed: Foo 2.0 from its author]" in o8b, o8b)
    check("S8c the Krinik pak changed and needs no line", "* pack/src/KrinikConanUI/KrinikConanUI.pak" in o8b and "KrinikConanUI.pak   [NOT" not in o8b, o8b)
    # S8d / S8e: an ADDED third-party pak is guarded, a REMOVED one is not (round 2, 4)
    ex8d = os.path.join(t, "v8d", "Krinik_Mod_Pack_9_9_9"); export(ex8d); put(ex8d, "pack/src/New/New.pak", b"N" * 2000)
    c8d, o8d = run(ex8d, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(b, "manifest.json"))
    check("S8d an added third-party pak without an allow line → exit 1", c8d == 1 and "+ pack/src/New/New.pak   [NOT EXPECTED]" in o8d, o8d)
    ex8e = os.path.join(t, "v8e", "Krinik_Mod_Pack_9_9_9"); export(ex8e); shutil.rmtree(os.path.join(ex8e, "pack", "src", "Foo"))
    c8e, o8e = run(ex8e, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(b, "manifest.json"))
    check("S8e a removed third-party pak needs no line → exit 0", c8e == 0 and "- pack/src/Foo/Foo.pak" in o8e and "NOT EXPECTED" not in o8e, o8e)
    open(allow, "w", encoding="utf-8").write("pack/src/foo/*\n")
    try:
        c8f, o8f = run(ex8, "--tag", "v9.9.10", "--version", "9.9.10", "--check-only", "--previous", os.path.join(b, "manifest.json"), "--allow-changed", allow)
    except SystemExit as e:
        c8f, o8f = e.code, ""
    check("S8f an allow line without its reason → exit 2", c8f == 2, (c8f, o8f))

    # S9: one file under two case-spellings of a name → ONE asset name in the manifest, the first spelling (round 2, 2)
    ex9 = os.path.join(t, "v9", "Krinik_Mod_Pack_9_9_9"); export(ex9); put(ex9, "pack/src/X/Same.pak", b"S" * 2000); put(ex9, "pack/src/Y/same.pak", b"S" * 2000)
    c9, o9 = run(ex9, "--tag", "v9.9.9", "--version", "9.9.9", "--out", os.path.join(t, "a9"))
    m9 = {f["path"]: f for f in json.loads(open(os.path.join(t, "a9", "manifest.json"), encoding="utf-8").read())["files"]}
    n9 = (m9["pack/src/X/Same.pak"]["asset"], m9["pack/src/Y/same.pak"]["asset"])
    check("S9 two case-spellings of one name share one asset", c9 == 0 and n9[0] == n9[1] and os.path.exists(os.path.join(t, "a9", n9[0])), n9)

    # S10: an unparsable version with --previous-from stops the run (round 2, 1)
    try:
        c10, o10 = run(ex, "--tag", "v9.9.10-beta1", "--version", "9.9.10-beta1", "--check-only", "--previous-from", pub)
    except SystemExit as e:
        c10, o10 = e.code, ""
    check("S10 an unparsable --version with --previous-from → exit 2", c10 == 2, (c10, o10))

bad = [n for n, ok in results if not ok]
print("t_make_manifest: %d of %d cases pass%s" % (len(results) - len(bad), len(results), "" if not bad else " — FAILED: " + ", ".join(bad)))
sys.exit(1 if bad else 0)
