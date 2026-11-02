# edge-band.py — how red the screen EDGE is compared with its centre: the measure of the full-screen vignettes (hunger, thirst, low health).
#
# Why (plan 40 phase 1, 2026-11-01): a vignette is judged by a LOOK, and a log line proves only the call (EXP-0422) — so each case measures pixels.
# Redness of a pixel = R - (G + B) / 2. The number = mean redness over a band of BAND_SHARE of the frame height along all four edges, minus the
# mean over the centre third (the scene's own colour cancels out). With --control <frame> (the same spot, all stats full) the control's number is
# subtracted too: what is left is what the vignette added.
#
#   python -X utf8 _config/edge-band.py shot.jpg
#   python -X utf8 _config/edge-band.py shot.jpg --control ctrl.jpg
#   python -X utf8 _config/edge-band.py --selftest
#
# Prints one number (0–255 scale), two decimals. Exit 0; 2 — cannot read a frame.
# [NOT-TESTED]
import sys

from PIL import Image

BAND_SHARE = 0.06      # band width as a share of the frame height (plan 40.1 I6)
CENTRE_SHARE = 1 / 3   # centre box: the middle third in both axes
WORK_WIDTH = 480       # frames are shrunk to this width first — the measure is a mean, 480 px are plenty and fast


def redness_means(img):
    img = img.convert("RGB")
    if img.width > WORK_WIDTH:
        img = img.resize((WORK_WIDTH, max(1, round(img.height * WORK_WIDTH / img.width))))
    w, h = img.size
    band = max(1, round(h * BAND_SHARE))
    cx0, cx1 = round(w * (1 - CENTRE_SHARE) / 2), round(w * (1 + CENTRE_SHARE) / 2)
    cy0, cy1 = round(h * (1 - CENTRE_SHARE) / 2), round(h * (1 + CENTRE_SHARE) / 2)
    px = img.load()
    edge_sum = edge_n = centre_sum = centre_n = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            red = r - (g + b) / 2
            if x < band or x >= w - band or y < band or y >= h - band:
                edge_sum += red
                edge_n += 1
            elif cx0 <= x < cx1 and cy0 <= y < cy1:
                centre_sum += red
                centre_n += 1
    return edge_sum / edge_n, centre_sum / centre_n


def excess(path):
    edge, centre = redness_means(Image.open(path))
    return edge - centre


def selftest():
    # a grey frame scores 0; the same frame with a red band of the band's width scores clearly above 0; a red centre alone scores below 0
    grey = Image.new("RGB", (960, 540), (90, 90, 90))
    framed = grey.copy()
    band = round(540 * BAND_SHARE)
    for y in range(540):
        for x in range(960):
            if x < band or x >= 960 - band or y < band or y >= 540 - band:
                framed.putpixel((x, y), (200, 40, 40))
    e0, c0 = redness_means(grey)
    e1, c1 = redness_means(framed)
    ok = abs(e0 - c0) < 0.01 and (e1 - c1) > 100
    print(f"selftest grey {e0 - c0:.2f} framed {e1 - c1:.2f} -> {'ok' if ok else 'FAIL'}")
    return 0 if ok else 1


def main(argv):
    if argv and argv[0] == "--selftest":
        return selftest()
    if not argv:
        print(__doc__ or "usage: edge-band.py <frame> [--control <frame>]")
        return 2
    try:
        value = excess(argv[0])
        if "--control" in argv:
            value -= excess(argv[argv.index("--control") + 1])
    except (OSError, IndexError) as err:
        print(f"cannot read: {err}")
        return 2
    print(f"{value:.2f}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
