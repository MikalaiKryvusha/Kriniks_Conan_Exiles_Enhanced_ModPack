# make-page-arrows.py — the attribute page arrows (KUMM plan 49 step 2, mockup V8 accepted by the owner 2026-11-10 10:27 «макет принят, делаем в игре,
# шикарно!») as UI textures for the kit: a diamond with a triangle, drawn by the SAME geometry and colours as `_config/mockups/attr_arrows_mockup.py` (v8),
# scaled for a 4K screen with headroom. Six TGAs (straight alpha): T_KrinikPageArrow{L,R}{,Hover,Dim}.
#   /c/Python314/python.exe -X utf8 make-page-arrows.py <out dir>
# Mockup units (4K-frame px): half-diagonal 26, rim 3, triangle height 2×9, width 9.9, centred w/3 toward its tip (the owner 10:27 «хватит трети»).
# [NOT-TESTED]
import os
import sys

from PIL import Image, ImageDraw

SIZE = 128                              # texture side; the diamond spans 2 × 26 + rim ≈ 55 mockup px → K = 2.2 texture px per mockup px
K = 2.2
SS = 4                                  # supersampling, then LANCZOS down
# the rim in Conan's own gold — the owner's G1 #E9C27A (KUMM plan 49, 2026-11-10 13:41 «05 золото конана» · «и наши кнопочки влево вправо к нему приведи»;
# palette: KUMM researches/conan-ui-color-scheme/); was (222, 178, 102)
GOLD = (233, 194, 122, 255)
GOLD_HI = (255, 226, 160, 255)
FILL = (34, 30, 24, 235)
# hover — the game's lighter gold #ECD97C (G2), the same pair the «+» gets; was (255, 214, 140)
HOVER_RIM = (236, 217, 124, 255)
DIM_RIM, DIM_FILL, DIM_TRI = (120, 108, 90, 95), (28, 27, 26, 150), (150, 140, 120, 85)


def draw(left, rim, fill, tri, rim_w):
    big = SIZE * SS
    im = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = big / 2
    r = 26 * K * SS
    d.polygon([(c, c - r), (c + r, c), (c, c + r), (c - r, c)], fill=fill, outline=rim, width=int(rim_w * K * SS))
    h = 9 * K * SS
    w = h * 1.1
    x = c - w / 3 if left else c + w / 3            # centred by mass + the owner's nudge toward the tip (w/3)
    if left:
        pts = [(x - w / 2, c), (x + w / 2, c - h), (x + w / 2, c + h)]
    else:
        pts = [(x + w / 2, c), (x - w / 2, c - h), (x - w / 2, c + h)]
    d.polygon(pts, fill=tri)
    return im.resize((SIZE, SIZE), Image.LANCZOS)


def main(out):
    os.makedirs(out, exist_ok=True)
    for side, left in (("L", True), ("R", False)):
        for state, (rim, fill, tri, rw) in {"": (GOLD, FILL, GOLD_HI, 3), "Hover": (HOVER_RIM, FILL, GOLD_HI, 3),
                                            "Dim": (DIM_RIM, DIM_FILL, DIM_TRI, 2)}.items():
            name = "T_KrinikPageArrow%s%s" % (side, state)
            draw(left, rim, fill, tri, rw).save(os.path.join(out, name + ".tga"))
            print("ok", name)


if __name__ == "__main__":
    main(sys.argv[1])
