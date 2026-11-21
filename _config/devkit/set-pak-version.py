# set-pak-version.py -- set the version a Conan mod pak shows (modinfo.json versionMajor/Minor/Build) inside its outer wrapper pak, without a kit rebuild.
#
#   python -I -X utf8 set-pak-version.py <wrapper.pak> <major.minor.build> [--work <dir>] [--dry-run]
#
# WHY. The owner's word 2026-10-28 (KUMM PROJECT_HISTORY.md, the evening's queue, item 4): «все моды Krinik... получают версию 3.0.1» — the
# manifest, the kit paks' modinfo.json, the Lua mods' headers. A kit pak's outer wrapper (kit-buildmod.py step 4) holds modinfo.json +
# manifest.json (MD5 of every file and, in the «<xxh128>» block, their XXH128) + the platform pak/utoc/ucas; the version is three integers of
# modinfo.json. A kit rebuild costs ~5 min per mod and re-cooks assets that did not change; this edits only modinfo.json, recomputes BOTH its manifest
# hashes (kit_manifest.py, since 2026-11-14 — the MD5 alone left the loader on the old extracted file) and repacks the wrapper the way kit-buildmod.py
# does (repak V11, mount point ../../../ConanSandbox/Mods/). At the target version with stale modinfo hashes it rewrites the manifest only.
# Checks: every other file of the wrapper byte-equal before/after (MD5), the repacked list equal to the original list, the read-back version.
# Exit: 0 written (or already at that version) · 2 bad arguments · 3 the wrapper is not a kit wrapper · 4 the result failed a check.
# [TESTED: 2026-11-14 · copies of an <xxh128> wrapper: a new version 10/10; the stale-hash repair at the same version (made stale by the old script) 10/10 · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
import json, os, shutil, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit_manifest  # noqa: E402 — both manifest hashes of modinfo.json (MD5 + «<xxh128>»), 2026-11-14: only the MD5 was updated before
import repak_tool  # noqa: E402 — repak on one thread: the same folder packs into the same bytes (2026-11-21, the launcher's delta update, step 0)

REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
MOUNT = "../../../ConanSandbox/Mods/"
INNER = "ConanSandbox/Mods"
md5 = kit_manifest.md5


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", env=repak_tool.env_for(args))
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
    man_now = json.loads(open(os.path.join(d, "manifest.json"), encoding="utf-8-sig").read())
    # a manifest with no modinfo.json entry at the target version keeps the old answer «nothing written» (round 3, 5): only a STALE entry is repaired
    if old == ver and ("modinfo.json" not in man_now or kit_manifest.entry_ok(man_now, "modinfo.json", mi_path)):
        shutil.rmtree(work, ignore_errors=True)
        print("already at that version — nothing written")
        return 0
    if old == ver:   # judge 2026-11-14, finding 3: a pre-2026-11-14 edit left the <xxh128> of modinfo.json stale — rewrite the manifest only
        print("already at that version, but the manifest's modinfo.json hashes are stale — rewriting them")
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
    kit_manifest.set_entry(man, "modinfo.json", mi_path)
    with open(man_path, "w", encoding="utf-8") as fh:        # closed before repak reads it (judge round 2, Q4)
        json.dump(man, fh, indent=2)
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
    man_ok = kit_manifest.entry_ok(man2, "modinfo.json", os.path.join(c, "modinfo.json"))
    ok = after == before and not bad and got == ver and man_ok
    print("list equal: %s · other files byte-equal: %s · version read back: %s · manifest hashes of modinfo (md5%s): %s" % (
        after == before, not bad, ".".join(map(str, got)), " + xxh128" if kit_manifest.XXH in man2 else "", man_ok))
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
