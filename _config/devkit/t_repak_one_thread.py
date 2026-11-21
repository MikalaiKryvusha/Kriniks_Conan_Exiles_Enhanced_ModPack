# t_repak_one_thread.py -- the guard of repak_tool.py: every build script that writes a pak with `repak pack` or `retoc to-zen` runs it through
# repak_tool.env_for (one rayon thread — the same folder packs into the same bytes; KUMM plan 57 phase 6 step 0).
#
#   python -I -X utf8 t_repak_one_thread.py [<folder>]      # default: the pack's _config; exit 0 clean, 1 a writer without env_for, 2 no file scanned
#   python -I -X utf8 t_repak_one_thread.py --selftest      # the guard must flag a writer without env_for and pass one with it
#
# @guard repak-one-thread
# THREAT:         a new or edited build script packs a pak on many threads, the release's paks change byte-wise with no change of content, and every
#                 player's update downloads the whole build again (RC1 -> RC2: 62 paks, 13.56 GB).
# PROVED-AGAINST: make-loc-mod.py as it stood before 2026-11-21 10:4x (`run([REPAK, 'pack', …])` with no env_for — the judge's finding 2), kept as the
#                 selftest's broken fixture; the live tree after the fix passes.
# GAP:            a writer that builds its command elsewhere (a list in a variable, a shell script) is not seen; the release-level line «changed vs the
#                 previous release» of make_release.sh step 4c catches the result.
# ON-REAL-PATH:   NOT YET (runs by hand; to be called by make_release.sh step 0b with the ritual)
# [NOT-TESTED]
import os, re, sys, tempfile

WRITER = re.compile(r"""REPAK\w*\s*,\s*["']pack["']|["']to-zen["']""")
SKIP = {"repak_tool.py", "t_repak_one_thread.py"}


def scan(root):
    bad, seen = [], 0
    for d, dirs, files in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in ("__pycache__", "_scratch"))
        for n in sorted(files):
            if not n.endswith(".py") or n in SKIP:
                continue
            p = os.path.join(d, n)
            seen += 1
            text = open(p, encoding="utf-8", errors="replace").read()
            # a line may declare its exception with the reason on the line: «# repak-one-thread-ok: <why>» (a call through another script's run())
            hits = [i + 1 for i, line in enumerate(text.splitlines())
                    if WRITER.search(line) and not line.lstrip().startswith("#") and "repak-one-thread-ok:" not in line]
            if hits and "env_for(" not in text:
                bad.append((p, hits))
    return bad, seen


def selftest():
    with tempfile.TemporaryDirectory() as t:
        broken = os.path.join(t, "broken.py")
        fixed = os.path.join(t, "fixed.py")
        open(broken, "w", encoding="utf-8").write("def run(cmd):\n    pass\nrun([REPAK, 'pack', '--version', 'V11', src, out])\n")
        open(fixed, "w", encoding="utf-8").write("import repak_tool\ndef run(cmd):\n    subprocess.run(cmd, env=repak_tool.env_for(cmd))\n"
                                                  "run([REPAK, 'pack', src, out])\nrun([RETOC, \"to-zen\", a, b])\n")
        bad, seen = scan(t)
        ok = seen == 2 and [os.path.basename(p) for p, _ in bad] == ["broken.py"]
        print("selftest: scanned %d, flagged %s — %s" % (seen, [os.path.basename(p) for p, _ in bad], "PASS" if ok else "FAIL"))
        return 0 if ok else 1


def main():
    if "--selftest" in sys.argv:
        return selftest()
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    bad, seen = scan(root)
    for p, hits in bad:
        print("[fail] %s: a pak writer on line %s without repak_tool.env_for" % (os.path.relpath(p, root), ", ".join(map(str, hits))))
    print("scanned %d scripts under %s · writers without env_for: %d" % (seen, root, len(bad)))
    return 2 if not seen else (1 if bad else 0)


if __name__ == "__main__":
    sys.exit(main())
