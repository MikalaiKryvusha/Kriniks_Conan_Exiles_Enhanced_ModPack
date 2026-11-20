# hitch-threads.py — per-thread samples of the game in one `xperf -a dumper -range` window, and how many of each thread's samples sit in a code range of
# the exe given by its low 16 bits (ASLR moves the image by 64 KB steps, so `address mod 0x10000` survives a relaunch).
#
# Why (KUMM researches/conan-hitch-profiler, 2026-11-09): the navmesh gathering loop is exe RVA 0x26EEC30…0x26EEC67; with N1 (async gathering) the question is
# whether the loop left the game thread. Every launch has another image base and other thread ids — the low bits and «the busiest thread» are what carry over.
#   python -I -X utf8 hitch-threads.py <dump.csv> [lo16 hex] [hi16 hex]      (default 0xEC30 0xEC68)
# [NOT-TESTED]
import collections
import sys

GAME = "ConanSandbox-Win64-Shipping"


def main():
    path = sys.argv[1]
    lo = int(sys.argv[2], 16) if len(sys.argv) > 2 else 0xEC30
    hi = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0xEC68
    total, loop = collections.Counter(), collections.Counter()
    for ln in open(path, encoding="utf-8", errors="replace"):
        p = [x.strip() for x in ln.split(",")]
        if len(p) < 9 or p[0] != "SampledProfile" or not p[1].isdigit() or GAME not in p[2]:
            continue
        tid = p[3]
        total[tid] += 1
        img, _, addr = p[7].partition("!")
        if GAME in img and addr.startswith("0x"):
            if lo <= (int(addr, 16) & 0xFFFF) < hi:
                loop[tid] += 1
    for tid, n in total.most_common(8):
        print("thread %6s  samples %4d  in loop %4d" % (tid, n, loop[tid]))
    print("loop samples on all threads: %d" % sum(loop.values()))


if __name__ == "__main__":
    main()
