import sys
# [TESTED: 2026-10-30 · W6 frames B1/P1/P1b/P1c/C1 gave 4.0/7.0/18.5/5.0/5.0 px, matching a by-eye read of the plate rows · KUMM testcases/reports/2026-10-30_conan-corpse-prompt-two-lines-quickloot-size.md]
# usage: /c/Python314/python.exe -X utf8 plate-measure.py <4K frame> <plate column x> <text x0,x1> <y0,y1>  (a threshold detector of the WHOLE icon caught grass and blood - 12.5 px of false shift)
# platemeasure.py <frame> <plate column x> <text x0,x1> <y0,y1>: the key plate's top/bottom edge = the jump of mean R across 8 columns
# (dark frame → beige plate > 150), text = rows with light ink; prints text-centre minus plate-centre (px, positive = plate above).
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
px = int(sys.argv[2]); tx0, tx1 = [int(v) for v in sys.argv[3].split(",")]; y0, y1 = [int(v) for v in sys.argv[4].split(",")]
R = [sum(im.getpixel((x, y))[0] for x in range(px, px + 8)) / 8 for y in range(y0, y1)]
inside = [y0 + i for i, r in enumerate(R) if r > 150]
# the longest run of plate rows
best, cur = [], []
for y in inside:
    cur = cur + [y] if cur and y == cur[-1] + 1 else [y]
    best = cur if len(cur) > len(best) else best
light = lambda p: p[0] > 200 and p[1] > 190 and p[2] > 170
ys = [y for y in range(y0, y1) if sum(light(im.getpixel((x, y))) for x in range(tx0, tx1)) >= 2]
pc = (best[0] + best[-1]) / 2; tc = (min(ys) + max(ys)) / 2
print("%s plate %d-%d text %d-%d  text-centre minus plate-centre %.2f px" % (sys.argv[1], best[0], best[-1], min(ys), max(ys), tc - pc))
