# hitch-preempt.py — engine or system? For the N longest hitches of a light-probe trace: how long the game thread was ON-CPU, READY-but-not-running
# (preempted by someone else — the system's share) and WAITING (blocked) inside each hitch window, from CSWITCH events.
#
# Why (KUMM researches/conan-hitch-profiler, the owner 2026-11-09 22:01 «это точно движок? не что-то сторонее в системе или сама система?»): a hitch the
# engine makes keeps the game thread on the CPU; a hitch the system makes leaves it Ready (preempted) or Waiting (I/O, locks).
#   python -I -X utf8 hitch-preempt.py <trace.etl> <live.csv> <offset_us> <out dir> [--top 3]
# The game thread = the thread with the most samples in the window.
# [NOT-TESTED]
import collections
import csv
import os
import subprocess
import sys

XPERF = r"C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe"
GAME = "ConanSandbox-Win64-Shipping"


def main():
    etl, pcsv, off, outd = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 3
    os.makedirs(outd, exist_ok=True)
    rows = []
    for r in csv.DictReader(open(pcsv, encoding="utf-8", errors="replace")):
        try:
            rows.append((float(r["MsBetweenPresents"]), float(r["TimeInMs"])))
        except (KeyError, ValueError):
            pass
    for k, (ms, t) in enumerate(sorted(rows, reverse=True)[:top]):
        t1, t2 = int(off + (t - ms) * 1000), int(off + t * 1000)
        dump = os.path.join(outd, "p%d.csv" % k)
        if not os.path.exists(dump):
            subprocess.run([XPERF, "-tle", "-quiet", "-i", etl, "-o", dump, "-a", "dumper", "-range", str(t1), str(t2)], capture_output=True)
        samples, switches = collections.Counter(), []
        for ln in open(dump, encoding="utf-8", errors="replace"):
            p = [x.strip() for x in ln.split(",")]
            if len(p) > 8 and p[0] == "SampledProfile" and p[1].isdigit() and GAME in p[2]:
                samples[p[3]] += 1
            elif len(p) > 13 and p[0] == "CSwitch" and p[1].isdigit():
                switches.append((int(p[1]), p[3], p[9], p[12]))   # time, new TID, old TID, old state
        if not samples:
            print("hitch %d: no samples" % k)
            continue
        gt = samples.most_common(1)[0][0]
        state, since, acc = "run?", t1, collections.Counter()
        for ts, new, old, ostate in sorted(switches):
            if old == gt:
                acc["on-CPU"] += ts - since
                state, since = ("ready" if ostate in ("Ready", "Standby", "DeferredReady") else "waiting"), ts
            elif new == gt:
                acc[state if state != "run?" else "waiting"] += ts - since
                state, since = "on", ts
        acc["on-CPU" if state in ("on", "run?") else state] += t2 - since
        tot = sum(acc.values()) or 1
        print("hitch %d: %.1f ms · game thread %s · on-CPU %.0f ms (%.0f %%) · READY (preempted) %.1f ms · waiting %.1f ms"
              % (k, ms, gt, acc["on-CPU"] / 1000, 100 * acc["on-CPU"] / tot, acc["ready"] / 1000, acc["waiting"] / 1000))


if __name__ == "__main__":
    main()
