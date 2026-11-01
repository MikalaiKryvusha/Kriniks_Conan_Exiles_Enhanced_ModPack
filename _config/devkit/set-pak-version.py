# set-pak-version.py -- set the version a Conan mod pak shows (modinfo.json versionMajor/Minor/Build) inside its outer wrapper pak, without a kit rebuild.
#
#   python -I -X utf8 set-pak-version.py <wrapper.pak> <major.minor.build> [--work <dir>] [--dry-run]
#
# WHY. The owner's word 2026-10-28 (KUMM PROJECT_HISTORY.md, the evening's queue, item 4): «все моды Krinik... получают версию 3.0.1» — the
# manifest, the kit paks' modinfo.json, the Lua mods' headers. A kit pak's outer wrapper (kit-buildmod.py step 4) holds modinfo.json +
# manifest.json (MD5 of every file) + the platform pak/utoc/ucas; the version is three integers of modinfo.json. A kit rebuild costs ~5 min per
# mod and re-cooks assets that did not change; this edits only modinfo.json, recomputes its MD5 in manifest.json and repacks the wrapper the way
# kit-buildmod.py does (repak V11, mount point ../../../ConanSandbox/Mods/).
# Checks: every other file of the wrapper byte-equal before/after (MD5), the repacked list equal to the original list, the read-back version.
# Exit: 0 written (or already at that version) · 2 bad arguments · 3 the wrapper is not a kit wrapper · 4 the result failed a check.
# [TESTED: 2026-10-30 · three real wrappers set to 3.0.1, deployed, the game list shows v3.0.1 · KUMM testcases/reports/2026-10-30_conan-krinik-versions-3.0.1.md]
import hashlib, json, os, shutil, subprocess, sys

REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
MOUNT = "../../../ConanSandbox/Mods/"
INNER = "ConanSandbox/Mods"


def md5(p):
    h = hashlib.md5()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode:
        raise SystemExit("repak failed: %s\n%s" % (" ".join(args), r.stderr[-800:]))
    return r.stdout


def listing(pak):
    return sorted(l.strip() for l in run([REPAK, "list", pak]).splitlines() if l.strip())


def main():
    a = sys.argv[1:]
    dry = "--dry-run" in a
    work = None
    if "--work" in a:
        work = a[a.index("--work") + 1]
    pos = [x for x in a if not x.startswith("--") and x != work]
    if len(pos) != 2 or len(pos[1].split(".")) != 3 or not all(p.isdigit() for p in pos[1].split(".")):
        print(__doc__ if __doc__ else "usage: set-pak-version.py <wrapper.pak> <major.minor.build> [--work <dir>] [--dry-run]")
        return 2
    pak, ver = os.path.abspath(pos[0]), [int(p) for p in pos[1].split(".")]
    # The work folder lives in the OS temp, never beside the pak: the pak may sit in a game or an unpack tree (AGENT_GUIDE, boundaries S1).
    work = os.path.abspath(work or os.path.join(os.environ.get("TEMP", "."), "set-pak-version-" + os.path.basename(pak)))
    try:
        before = listing(pak)
    except SystemExit as e:
        print("not a pak repak can read:", str(e).splitlines()[0][:160])
        return 3
    if INNER + "/modinfo.json" not in before or INNER + "/manifest.json" not in before:
        print("not a kit wrapper (no modinfo.json / manifest.json):", before[:6])
        return 3
    shutil.rmtree(work, ignore_errors=True)
    run([REPAK, "unpack", "-q", "-o", work, pak])
    d = os.path.join(work, *INNER.split("/"))
    sums = {n: md5(os.path.join(d, n)) for n in os.listdir(d)}
    mi_path = os.path.join(d, "modinfo.json")
    raw = open(mi_path, "rb").read()
    text = raw.decode("utf-8-sig")
    mi = json.loads(text)
    old = [mi.get("versionMajor"), mi.get("versionMinor"), mi.get("versionBuild")]
    print("%s: version %s -> %s" % (mi.get("name"), ".".join(map(str, old)), ".".join(map(str, ver))))
    if old == ver:
        shutil.rmtree(work, ignore_errors=True)
        print("already at that version — nothing written")
        return 0
    # Keep the file's own layout (tabs, key order, line ends): replace only the three numbers.
    for key, val in zip(("versionMajor", "versionMinor", "versionBuild"), ver):
        needle = '"%s": %d' % (key, mi[key])
        if text.count(needle) != 1:
            print("cannot find exactly one %s in modinfo.json" % needle)
            return 4
        text = text.replace(needle, '"%s": %d' % (key, val))
    if dry:
        shutil.rmtree(work, ignore_errors=True)
        print("dry run — nothing written")
        return 0
    open(mi_path, "wb").write((b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8"))
    man_path = os.path.join(d, "manifest.json")
    man = json.loads(open(man_path, encoding="utf-8-sig").read())
    if "modinfo.json" not in man:
        print("manifest.json has no modinfo.json entry")
        return 4
    man["modinfo.json"] = md5(mi_path)
    json.dump(man, open(man_path, "w", encoding="utf-8"), indent=2)
    out = work + ".new.pak"
    if os.path.exists(out):
        os.remove(out)
    run([REPAK, "pack", "--version", "V11", "--mount-point", MOUNT, d, out])
    # Checks on the NEW pak, read back from disk.
    after = listing(out)
    chk = os.path.abspath(work + ".check")
    shutil.rmtree(chk, ignore_errors=True)
    run([REPAK, "unpack", "-q", "-o", chk, out])
    c = os.path.join(chk, *INNER.split("/"))
    bad = [n for n, s in sums.items() if n not in ("modinfo.json", "manifest.json") and md5(os.path.join(c, n)) != s]
    mi2 = json.loads(open(os.path.join(c, "modinfo.json"), encoding="utf-8-sig").read())
    man2 = json.loads(open(os.path.join(c, "manifest.json"), encoding="utf-8-sig").read())
    got = [mi2["versionMajor"], mi2["versionMinor"], mi2["versionBuild"]]
    ok = after == before and not bad and got == ver and man2.get("modinfo.json") == md5(os.path.join(c, "modinfo.json"))
    print("list equal: %s · other files byte-equal: %s · version read back: %s · manifest md5 of modinfo: %s" % (
        after == before, not bad, ".".join(map(str, got)), man2.get("modinfo.json") == md5(os.path.join(c, "modinfo.json"))))
    shutil.rmtree(work, ignore_errors=True)
    shutil.rmtree(chk, ignore_errors=True)
    if not ok:
        os.remove(out)
        print("FAILED — the original pak is untouched")
        return 4
    os.replace(out, pak)
    print("written:", pak, os.path.getsize(pak))
    return 0


if __name__ == "__main__":
    sys.exit(main())
