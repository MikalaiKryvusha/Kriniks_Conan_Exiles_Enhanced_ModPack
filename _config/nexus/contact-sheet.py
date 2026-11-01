"""contact-sheet.py -- all frames of a series on one page, each labelled with
the camera settings that produced it.

WHY. The owner judges by eye and the agent cannot (the chat's image budget is
spent). One page beats twelve files: he sees the whole range at once and can
name the one he wants instead of opening them one by one.

The label is the SETTINGS, not a prose caption. A prose caption is what lied
last time; a settings line either matches the frame or is refutable.
"""

import os
import sys
from PIL import Image, ImageDraw, ImageFont

SETTINGS = {
    "01-vanilla":        "ВАНИЛЬ — мод выключен, камера Конана как есть",
    "02-behind":         "строго за спиной · бок 0 · высота 65 · дист 190 · наклон 0",
    "03-closest":        "вплотную · бок 0 · высота 65 · дист 70 · наклон 0",
    "04-close-tilt":     "близко с наклоном · высота 90 · дист 90 · наклон -10",
    "05-normal-tilt":    "обычная с наклоном · высота 65 · дист 190 · наклон -10",
    "06-lift-soft":      "подъём лёгкий · высота 110 · дист 220 · наклон -8",
    "07-lift-mid":       "подъём средний · высота 150 · дист 250 · наклон -12",
    "08-lift-strong":    "подъём сильный · высота 190 · дист 280 · наклон -16",
    "09-lift-tall":      "подъём высокий · высота 240 · дист 300 · наклон -20",
    "10-shoulder-right": "плечо вправо · бок 90 · высота 65 · дист 190 · наклон -6",
    "11-shoulder-left":  "плечо влево · бок -90 · высота 65 · дист 190 · наклон -6",
    "12-lift-shoulder":  "подъём + плечо · бок 70 · высота 150 · дист 250 · наклон -12",
    "13-far":            "далеко · высота 65 · дист 950 · наклон -6",
    "14-panorama":       "панорама · высота 200 · дист 950 · наклон -14",
    "15-limit":          "предел мода · высота 300 · дист 1000 · наклон -18",
}

COLS = 3
TILE_W = 640
LABEL_H = 46
PAD = 10
BG = (24, 24, 26)
FG = (235, 230, 220)


def font(size):
    for name in ("arial.ttf", "segoeui.ttf", "tahoma.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def main(folder, out_path):
    names = sorted(f for f in os.listdir(folder) if f.lower().endswith((".png", ".jpg")))
    if not names:
        print("no frames in", folder)
        return 1

    first = Image.open(os.path.join(folder, names[0]))
    tile_h = int(TILE_W * first.height / first.width)
    rows = (len(names) + COLS - 1) // COLS

    sheet_w = COLS * TILE_W + (COLS + 1) * PAD
    sheet_h = rows * (tile_h + LABEL_H) + (rows + 1) * PAD
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    draw = ImageDraw.Draw(sheet)
    f_title = font(22)
    f_sub = font(17)

    for i, name in enumerate(names):
        col, row = i % COLS, i // COLS
        x = PAD + col * (TILE_W + PAD)
        y = PAD + row * (tile_h + LABEL_H + PAD)
        im = Image.open(os.path.join(folder, name)).convert("RGB").resize((TILE_W, tile_h))
        sheet.paste(im, (x, y))
        key = os.path.splitext(name)[0]
        draw.text((x + 4, y + tile_h + 4), key, font=f_title, fill=FG)
        draw.text((x + 4, y + tile_h + 26), SETTINGS.get(key, ""), font=f_sub, fill=(170, 170, 175))

    sheet.save(out_path, quality=92)
    print("contact sheet: %s  (%dx%d, %d frames)" % (out_path, sheet.width, sheet.height, len(names)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
