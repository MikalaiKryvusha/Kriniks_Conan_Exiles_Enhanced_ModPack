# make-palette-texture.py — the colour rectangle of the hub's palette (KUMM plan 40.3 I6.2; `[OWNER]` 2026-11-02 08:45 «вместо квадратиков фиксированных
# цветов, нужно дать прямоугольник палитры»). Writes <out>/T_KrinikPalette.tga, sRGB, for import-logo-texture.py (KIT_LOGO_TGA, KIT_TEX_NAME=T_KrinikPalette).
# The mapping is the Lua section's `palette_colour(x, y)` in krinik_mod_settings.lua — change both together:
#   x in [0, GREY_FROM): hue = x / GREY_FROM · 360; y in [0, 0.5]: saturation = 2y, value 1 (white → the pure hue); y in (0.5, 1]: saturation 1, value 2 − 2y
#   (the pure hue → black); x in [GREY_FROM, 1]: a grey column, value = 1 − y.
#   python -X utf8 make-palette-texture.py <out dir>
# [NOT-TESTED]
import colorsys
import os
import sys

from PIL import Image

W, H = 1024, 512          # the texture; the hub shows it at the kit's PAL_RECT_W × PAL_RECT_H
GREY_FROM = 0.92          # the grey column's start, a share of the width


def colour(x, y):
    if x >= GREY_FROM:
        g = 1.0 - y
        return g, g, g
    h = x / GREY_FROM
    if y <= 0.5:
        s, v = 2 * y, 1.0
    else:
        s, v = 1.0, 2 - 2 * y
    return colorsys.hsv_to_rgb(h, s, v)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    img = Image.new("RGB", (W, H))
    px = img.load()
    for j in range(H):
        y = j / (H - 1)
        for i in range(W):
            r, g, b = colour(i / (W - 1), y)
            px[i, j] = (round(r * 255), round(g * 255), round(b * 255))
    path = os.path.join(out, "T_KrinikPalette.tga")
    img.save(path)
    print(path)


if __name__ == "__main__":
    main()
