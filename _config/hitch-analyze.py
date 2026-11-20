# hitch-analyze.py — per-hitch breakdown of one hitch-trace.ps1 recording: which modules of the game held each frame >= 50 ms.
#
# Why (KUMM researches/conan-hitch-profiler, the owner's question 2026-11-09 19:39 «что делает движок в моменты фризных кадров»): the frames come
# from the LIVE PresentMon CSV of the same flight (bench-flight.sh); its clock starts with the PresentMon process, whose start is on the trace
# clock (`xperf -a process` → «Start Time» of PresentMon-*.exe, µs). A hitch = [TimeInMs − MsBetweenPresents, TimeInMs] + offset, padded by
# PAD_MS for the session-start latency. ONE xperf pass does every hitch (several `-a profile -detail -range` actions with their own `-ao`):
# a pass over an 8.5 GB trace is minutes, not seconds.
#   python -I -X utf8 hitch-analyze.py <trace.etl> <live.csv> <offset_us> <out.md> [--min-ms 50] [--top 30]
# [NOT-TESTED]
import csv
import os
import re
import subprocess
import sys
import tempfile

XPERF = r"C:\Program Files (x86)\Windows Kits\10\Windows Performance Toolkit\xperf.exe"
GAME = "ConanSandbox-Win64-Shipping"
PAD_MS = 20.0


def hitches(path, min_ms):
    out = []
    for r in csv.DictReader(open(path, encoding="utf-8", errors="replace")):
        try:
            t, ms = float(r["TimeInMs"]), float(r["MsBetweenPresents"])
        except (KeyError, ValueError):
            continue
        if ms >= min_ms:
            out.append((t, ms))
    return out


def game_block(text):
    # xperf -detail prints flat rows «Process Name ( PID), Weight, Usage %, Module Name»; Weight is µs of CPU (1000 = one 1 ms sample).
    # Read 2026-11-09 20:3x from the raw output — the first parser expected a process header with indented modules and found nothing.
    res = {}
    for ln in text.splitlines():
        parts = [p.strip() for p in ln.rsplit(",", 3)]
        if len(parts) != 4 or not parts[0].startswith(GAME):
            continue
        try:
            res[parts[3]] = res.get(parts[3], 0) + int(float(parts[1]) / 1000)
        except ValueError:
            continue
    return sorted(res.items(), key=lambda kv: -kv[1])


def main():
    etl, pcsv, off_us, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]
    min_ms = float(sys.argv[sys.argv.index("--min-ms") + 1]) if "--min-ms" in sys.argv else 50.0
    top = int(sys.argv[sys.argv.index("--top") + 1]) if "--top" in sys.argv else 30
    hs = sorted(hitches(pcsv, min_ms), key=lambda h: -h[1])[:top]
    hs.sort()
    tmp = tempfile.mkdtemp(prefix="hitch_")
    cmd = [XPERF, "-tle", "-quiet", "-i", etl]
    for i, (t, ms) in enumerate(hs):
        t1 = off_us + (t - ms - PAD_MS) * 1000.0
        t2 = off_us + (t + PAD_MS) * 1000.0
        cmd += ["-a", "profile", "-detail", "-range", str(int(t1)), str(int(t2)), "-ao", os.path.join(tmp, "h%02d.txt" % i)]
    if "--reuse" in sys.argv:
        tmp = sys.argv[sys.argv.index("--reuse") + 1]   # the raw per-hitch files of an earlier pass — re-parse without another 8 GB pass
    else:
        subprocess.run(cmd, capture_output=True, text=True, errors="replace")
    md = ["# Hitch breakdown", "", "trace `%s` · live CSV `%s` · offset %.0f µs · pad ±%g ms" % (etl, pcsv, off_us, PAD_MS), "",
          "| # | flight s | frame ms | game samples by module (1 ms each) |", "|---|---|---|---|"]
    for i, (t, ms) in enumerate(hs):
        p = os.path.join(tmp, "h%02d.txt" % i)
        text = open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else ""
        mods = game_block(text)
        total = sum(s for _, s in mods)
        md.append("| %d | %.1f | %.1f | %s |" % (i + 1, t / 1000.0, ms, " · ".join("%s %d" % (m, s) for m, s in mods[:6]) + (" (Σ %d)" % total if mods else "no game samples")))
    open(out, "w", encoding="utf-8").write("\n".join(md) + "\n")
    print("\n".join(md))
    print("raw per-hitch xperf output:", tmp)


if __name__ == "__main__":
    main()
