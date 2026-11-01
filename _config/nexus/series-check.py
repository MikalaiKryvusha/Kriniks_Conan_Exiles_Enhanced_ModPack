"""frame-diff.py -- a machine eye for a screenshot series.

WHY THIS EXISTS. The agent's ability to LOOK at images inside one chat is
finite: past some number of frames the API stops accepting them. The previous
attempt at this series died exactly there - nine frames were shot, two were
looked at, and three of the unseen ones turned out identical while their
captions claimed three different camera angles.

A script cannot judge beauty. It CAN refute the one failure that actually
happened: frames that are supposed to differ and do not. That is the whole
job here - not to replace the owner's eye, but to make a lying caption
impossible.

Usage:
    python frame-diff.py matrix <dir>          pairwise difference table
    python frame-diff.py region <img> <img>    compare the top-right corner
"""

import sys
import os
from PIL import Image, ImageChops, ImageStat


def load(path, size=(320, 180)):
    return Image.open(path).convert("RGB").resize(size)


def diff_pct(a, b):
    """Mean absolute per-channel difference, as a percent of full scale."""
    d = ImageChops.difference(a, b)
    return sum(ImageStat.Stat(d).mean) / 3.0 / 255.0 * 100.0


def matrix(folder):
    names = sorted(f for f in os.listdir(folder) if f.lower().endswith((".png", ".jpg")))
    if not names:
        print("no png files in", folder)
        return 1
    imgs = {n: load(os.path.join(folder, n)) for n in names}

    print("pairwise difference, %% of full scale (0.0 = identical frames)")
    print()
    worst = []
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            worst.append((diff_pct(imgs[a], imgs[b]), a, b))
    worst.sort()

    print("the FIVE most similar pairs - these are the ones that lie if")
    print("their captions claim different camera settings:")
    for d, a, b in worst[:5]:
        flag = "  <-- SUSPECT" if d < 1.0 else ""
        print("  %6.2f%%  %s  vs  %s%s" % (d, a, b, flag))
    print()
    print("most different pair: %6.2f%%  %s  vs  %s" % (worst[-1][0], worst[-1][1], worst[-1][2]))
    return 0


def region(p1, p2):
    """Top-right corner only: the minimap lives there in the world, the game
    logo lives there in the pause menu, so this tells the two states apart."""
    a = Image.open(p1).convert("RGB")
    b = Image.open(p2).convert("RGB")
    box = lambda im: im.crop((int(im.width * 0.78), 0, im.width, int(im.height * 0.22))).resize((160, 90))
    print("top-right corner difference: %.2f%%" % diff_pct(box(a), box(b)))


def sky(paths):
    """Mean colour of the top-centre band - the sky. Two frames shot in the
    same weather sit close; rain versus clear sun is not subtle. This is the
    check that lets a caption say 'one session, one weather' honestly when
    nobody looked at the frames."""
    print("sky band (top centre), mean RGB:")
    for p in paths:
        im = Image.open(p).convert("RGB")
        band = im.crop((int(im.width * 0.30), int(im.height * 0.02),
                        int(im.width * 0.70), int(im.height * 0.12)))
        r, g, b = [round(v) for v in ImageStat.Stat(band).mean]
        print("  %-26s R=%3d G=%3d B=%3d" % (os.path.basename(p), r, g, b))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "sky":
        sky(sys.argv[2:])
        sys.exit(0)
    if len(sys.argv) >= 3 and sys.argv[1] == "matrix":
        sys.exit(matrix(sys.argv[2]))
    if len(sys.argv) >= 4 and sys.argv[1] == "region":
        region(sys.argv[2], sys.argv[3])
        sys.exit(0)
    print(__doc__)
    sys.exit(2)
