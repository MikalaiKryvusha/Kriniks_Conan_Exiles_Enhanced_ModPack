"""style-probe.py -- read a caption's STYLE out of an existing frame.

The script that made the old captions died with its session; the frames it
made did not. The owner likes that style, so it gets measured off the picture
instead of remembered: where the plate sits, how dark it is, how tall the text
lines are, what colour they are.

    python style-probe.py <image>
"""

import sys
from PIL import Image
import statistics


def main(path):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    g = im.convert("L")
    px = g.load()
    print("frame %dx%d" % (W, H))

    # 1. Row profile of the bottom 35%: a caption plate shows up as a run of
    #    rows much darker than the rows above it.
    y0 = int(H * 0.65)
    rows = []
    for y in range(y0, H):
        s = sum(px[x, y] for x in range(0, W, 7))
        rows.append((y, s / len(range(0, W, 7))))
    base = statistics.median(v for _, v in rows)
    dark = [y for y, v in rows if v < base * 0.62]
    if not dark:
        print("no obvious dark band in the bottom third (median %.0f)" % base)
    else:
        print("dark band rows: y %d..%d  (height %d, %.1f%% of frame)"
              % (dark[0], dark[-1], dark[-1] - dark[0] + 1,
                 (dark[-1] - dark[0] + 1) / H * 100))
        band_y = (dark[0] + dark[-1]) // 2
        cols = [(x, sum(px[x, y] for y in range(dark[0], dark[-1], 3)) /
                 len(range(dark[0], dark[-1], 3))) for x in range(0, W, 5)]
        cbase = statistics.median(v for _, v in cols)
        dcols = [x for x, v in cols if v < cbase * 0.75]
        if dcols:
            print("dark band columns: x %d..%d  (width %d, %.1f%% of frame)"
                  % (dcols[0], dcols[-1], dcols[-1] - dcols[0] + 1,
                     (dcols[-1] - dcols[0] + 1) / W * 100))
        # plate colour = the darkest decile inside the band
        vals = sorted(px[x, band_y] for x in range(0, W, 3))
        print("plate luminance: darkest %d, median in band %d" % (vals[0], vals[len(vals)//2]))

    # 2. Where are the bright text pixels? Their vertical clusters are the lines.
    thr = 200
    bright_rows = []
    for y in range(y0, H):
        n = sum(1 for x in range(0, W, 3) if px[x, y] > thr)
        bright_rows.append((y, n))
    runs, cur = [], None
    for y, n in bright_rows:
        if n >= 3:
            cur = [y, y] if cur is None else [cur[0], y]
        elif cur:
            runs.append(tuple(cur)); cur = None
    if cur:
        runs.append(tuple(cur))
    runs = [r for r in runs if r[1] - r[0] >= 4]
    print("text lines found in the bottom third: %d" % len(runs))
    for a, b in runs:
        xs = [x for x in range(0, W, 3) if px[x, (a + b) // 2] > thr]
        span = "x %d..%d" % (min(xs), max(xs)) if xs else "-"
        print("  line y %d..%d  height %d px (%.2f%% of frame)  %s"
              % (a, b, b - a + 1, (b - a + 1) / H * 100, span))


if __name__ == "__main__":
    main(sys.argv[1])
