# hitch-hotspots.py — for the N longest hitches of a hitch-trace recording: dump each window (xperf dumper), take the busiest game thread, list its hottest
# exe code (256-byte blocks) and the strings the code around the hottest block references — the way the navmesh rebuild was named on 2026-11-09.
#   python -I -X utf8 hitch-hotspots.py <trace.etl> <live.csv> <offset_us> <exe> <image base hex> <out dir> [--top 5] [--skip-ms 300]
# The image base of the traced launch: from the live process while it runs, or (after it closed) any of its Stack rows' exe addresses rounded down is NOT
# enough — pass the base read at the run; blocks are also printed as `addr & 0xFFFF` so a later base can be matched.
# [NOT-TESTED]
import collections
import csv
import os
import subprocess
import sys

XPERF = r"C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe"
GAME = "ConanSandbox-Win64-Shipping"
HERE = os.path.dirname(os.path.abspath(__file__))


def hitches(path, n, skip_ms):
    rows = []
    for r in csv.DictReader(open(path, encoding="utf-8", errors="replace")):
        try:
            rows.append((float(r["MsBetweenPresents"]), float(r["TimeInMs"])))
        except (KeyError, ValueError):
            pass
    return [h for h in sorted(rows, reverse=True) if h[0] < skip_ms][:n]


def main():
    etl, pcsv, off, exe, base, outd = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4], int(sys.argv[5], 16), sys.argv[6]
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 5
    skip = float(sys.argv[sys.argv.index("--skip-ms") + 1]) if "--skip-ms" in sys.argv else 300.0
    os.makedirs(outd, exist_ok=True)
    for k, (ms, t) in enumerate(hitches(pcsv, top, skip)):
        dump = os.path.join(outd, "h%d.csv" % k)
        t1, t2 = int(off + (t - ms - 20) * 1000), int(off + (t + 20) * 1000)
        if not os.path.exists(dump):
            subprocess.run([XPERF, "-tle", "-quiet", "-i", etl, "-o", dump, "-a", "dumper", "-range", str(t1), str(t2)], capture_output=True)
        per, blocks = collections.Counter(), collections.defaultdict(collections.Counter)
        for ln in open(dump, encoding="utf-8", errors="replace"):
            p = [x.strip() for x in ln.split(",")]
            if len(p) < 9 or p[0] != "SampledProfile" or not p[1].isdigit() or GAME not in p[2]:
                continue
            per[p[3]] += 1
            img, _, a = p[7].partition("!")
            if GAME in img and a.startswith("0x"):
                blocks[p[3]][int(a, 16) & ~0xFF] += 1
        if not per:
            print("hitch %d: no samples" % k)
            continue
        tid, n = per.most_common(1)[0]
        print("\n== hitch %d: %.1f ms at flight %.1f s · busiest thread %s %d samples" % (k, ms, t / 1000, tid, n))
        for b, c in blocks[tid].most_common(4):
            res = subprocess.run([sys.executable, "-X", "utf8", os.path.join(HERE, "disasm-rva.py"), exe, "%X" % base, "%X" % (b + 0x80),
                                  "--before", "0x800", "--after", "0x400"], capture_output=True, text=True, errors="replace")
            strs = sorted({ln.split('; "', 1)[1].rstrip('"') for ln in res.stdout.splitlines() if '; "' in ln})[:5]
            print("  block RVA 0x%X (low16 0x%04X): %d samples · %s" % (b - base, b & 0xFFFF, c, " | ".join(strs) or "-"))


if __name__ == "__main__":
    main()
