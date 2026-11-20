# corruption_label_mockup.py — KUMM bug 91: the hover label «Оскверненные Характеристики» of the purple corruption «+» on «Хар-ки» — four looks for the owner.
# The game draws the row's own CorruptionLabel (W_Attribute) next to the diamond with no plate: it runs over the right perk column (real hover 2026-11-10,
# hover-watch frame). The control showed the branch is the game's own (vanilla == ours). Variants on ONE real 4K frame of the screen, labelled, each element
# with its rule-23 status:
#   V1 on a dark plate ABOVE the diamond, centred · V2 on a plate UNDER the diamond · V3 the game's place (from the diamond to the right) but on a plate ·
#   V4 no label at all (the diamond's own glow says «you can spend a corruption point here»).
# The plate copies the look of our accepted page numbers' world: dark (22, 21, 20) at 0.9 with a muted bronze rim — the game's tooltip tone.
#   /c/Python314/python.exe -X utf8 corruption_label_mockup.py <frame 3840x2160> <out dir>
# [NOT-TESTED]
import os
import sys
from PIL import Image, ImageDraw, ImageFont

SANS = "C:/Windows/Fonts/NotoSans-Regular.ttf"   # the label's face in the game is a sans (frame of the hover)
SANS_B = "C:/Windows/Fonts/NotoSans-Bold.ttf"
DIAMOND = (2436, 970)              # the corruption «+» of Живучесть on the base frame (4K px)
DIAMOND_HALF = 34                  # half-height of the diamond with its glow core
TEXT = "Оскверненные Характеристики"
TEXT_SIZE = 44                     # the game's label measured on the hover frame: ≈ 40 px cap-to-descender at 4K
TEXT_RGB = (222, 204, 255)         # the label's lilac as the game draws it
PLATE_FILL = (22, 21, 20, 230)
PLATE_RIM = (150, 122, 80, 200)
PAD_X, PAD_Y, GAP, RADIUS = 22, 12, 22, 8
STATUS = "нет механики — будет сделано"
VARIANTS = [
    ("01_V1_plashka_nad_rombom", "V1 · плашка над ромбом", "above"),
    ("02_V2_plashka_pod_rombom", "V2 · плашка под ромбом", "below"),
    ("03_V3_kak_v_igre_s_plashkoy", "V3 · место игры (вправо), но с плашкой", "right"),
    ("04_V4_bez_podpisi", "V4 · без подписи", None),
]


def label(img, where):
    d = ImageDraw.Draw(img, "RGBA")
    f = ImageFont.truetype(SANS, TEXT_SIZE)
    l, t, r, b = d.textbbox((0, 0), TEXT, font=f)
    w, h = r - l, b - t
    pw, ph = w + 2 * PAD_X, h + 2 * PAD_Y
    cx, cy = DIAMOND
    if where == "above":
        x0, y0 = cx - pw // 2, cy - DIAMOND_HALF - GAP - ph
    elif where == "below":
        x0, y0 = cx - pw // 2, cy + DIAMOND_HALF + GAP
    else:
        x0, y0 = cx + DIAMOND_HALF + GAP, cy - ph // 2
    d.rounded_rectangle((x0, y0, x0 + pw, y0 + ph), RADIUS, fill=PLATE_FILL, outline=PLATE_RIM, width=2)
    d.text((x0 + PAD_X - l, y0 + PAD_Y - t), TEXT, font=f, fill=TEXT_RGB)
    return (x0, y0, x0 + pw, y0 + ph)


def caption(img, title, status):
    d = ImageDraw.Draw(img, "RGBA")
    fb, fs = ImageFont.truetype(SANS_B, 64), ImageFont.truetype(SANS, 40)
    d.rounded_rectangle((60, 1990, 1700, 2120), 12, fill=(0, 0, 0, 190))
    d.text((90, 2000), title, font=fb, fill=(240, 232, 214))
    d.text((90, 2072), status, font=fs, fill=(190, 182, 166))


def main(frame, out):
    os.makedirs(out, exist_ok=True)
    base = Image.open(frame).convert("RGB")
    if base.size != (3840, 2160):
        raise SystemExit("the base frame must be 3840x2160, got %s" % (base.size,))
    for name, title, where in VARIANTS:
        img = base.copy()
        if where:
            label(img, where)
        caption(img, title, STATUS if where else "нет механики — будет сделано (подпись убрана)")
        p = os.path.join(out, name + ".webp")
        img.save(p, "WEBP", quality=90)
        print(p)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
