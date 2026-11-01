"""style-probe2.py -- read the old caption layout in detail, without eyes.

Prints a coarse map of the frame's lower area: for every sampled row, how far
the dark plate reaches and where the bright text pixels sit. That is enough to
tell a solid band from a gradient, a left block from a right one, and a
one-column layout from two.

    python style-probe2.py <image>
"""

import sys
from PIL import Image


def main(path):
    im = Image.open(path).convert("RGB")
    W, H = im.size
    g = im.convert("L")
    px = g.load()
    rgb = im.load()
    print("frame %dx%d" % (W, H))
    print()
    print("row map, bottom 40%%: '#' dark plate (<70), '|' bright text (>190), '.' picture")
    print("each cell is %d px wide, one line per %d px of height" % (W // 100, max(1, H // 60)))
    print()

    step_y = max(1, H // 60)
    step_x = max(1, W // 100)
    for y in range(int(H * 0.60), H, step_y):
        row = []
        for x in range(0, W, step_x):
            v = px[x, y]
            if v > 190:
                row.append("|")
            elif v < 70:
                row.append("#")
            else:
                row.append(".")
        print("%4d %s" % (y, "".join(row)))

    print()
    print("vertical darkness profile at x = 3%% of width (is the plate a gradient?)")
    xs = int(W * 0.03)
    for y in range(int(H * 0.72), H, max(1, H // 40)):
        print("  y=%4d  luminance=%3d" % (y, px[xs, y]))

    print()
    print("text colours sampled at the brightest pixel of each detected line:")
    for y in range(int(H * 0.60), H):
        best, bx = 0, None
        for x in range(0, W, 3):
            if px[x, y] > best:
                best, bx = px[x, y], x
        if best > 230 and (y % 7 == 0):
            print("  y=%4d  x=%4d  rgb=%s  lum=%d" % (y, bx, rgb[bx, y], best))


if __name__ == "__main__":
    main(sys.argv[1])
