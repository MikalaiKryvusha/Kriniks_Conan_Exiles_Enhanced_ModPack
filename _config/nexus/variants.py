"""variants.py -- caption candidates on one frame, so the owner names a letter.

WHY THE PREVIOUS SHEET WAS THROWN AWAY. Its four variants differed only in
the BACKING PLATE, while the style the owner actually liked -- the old run --
differs in TYPOGRAPHY: an accent rule above the line, a corner badge, a
headline with an explaining line under it, the second language in gold. None
of that was on the sheet, so no letter he could have named would have got him
what he wanted. Measured, not remembered: see sign_style.py.

WHAT IS STILL OPEN, and therefore what these three vary. His corrections are
already settled and are NOT variables here: the shadow covers the text's own
area and no wider, both languages carry equal weight, no camera numbers.
What is left is how the two languages are told apart:

    A  headlines the same size, Russian in gold, English in white,
       each with its explaining line
    B  the same, but both headlines white -- order alone separates them
    C  headlines only, no explaining lines: a short caption, a small shadow

    python variants.py <frame> <out.jpg>
"""

import sys

from PIL import Image, ImageDraw, ImageFont

import sign_style as st

RU_HEAD = "Камера выше, взгляд вниз"
RU_SUB = "Видно землю перед героем — куда идёшь и что под ногами."
EN_HEAD = "Raised and angled down"
EN_SUB = "The ground ahead is in frame — where you step and what waits there."

CANDIDATES = (
    ("A — русский золотом, английский белым, с пояснениями",
     dict(gold=True, sublines=True)),
    ("B — оба заголовка белые, с пояснениями",
     dict(gold=False, sublines=True)),
    ("C — только заголовки, без пояснений",
     dict(gold=True, sublines=False)),
)


def one(base, gold, sublines):
    im = base.copy()
    blocks = [
        (RU_HEAD, RU_SUB, st.GOLD if gold else st.WHITE),
        (EN_HEAD, EN_SUB, st.WHITE),
    ]
    st.draw(im, blocks, accent=st.SOFT_RED, sublines=sublines)
    return im


def main(src, out):
    base = Image.open(src).convert("RGB")
    made = [(name, one(base, **kw)) for name, kw in CANDIDATES]

    tile_w = 1280
    tile_h = int(round(tile_w * base.height / base.width))
    label_h = 46
    sheet = Image.new("RGB", (tile_w + 20, (tile_h + label_h) * len(made) + 10),
                      (22, 22, 24))
    d = ImageDraw.Draw(sheet)
    try:
        lf = ImageFont.truetype("segoeui.ttf", 27)
    except OSError:
        lf = ImageFont.load_default()
    for i, (name, im) in enumerate(made):
        y = 10 + i * (tile_h + label_h)
        sheet.paste(im.resize((tile_w, tile_h)), (10, y))
        d.text((14, y + tile_h + 10), name, font=lf, fill=(238, 234, 226))
    sheet.save(out, quality=93)
    print("лист вариантов подписи: %s (%dx%d)" % (out, sheet.width, sheet.height))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
