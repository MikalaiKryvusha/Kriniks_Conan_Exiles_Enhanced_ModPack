# plus_brightness_mockup.py — the owner's word 2026-11-10 13:13 «Мне нравится яркость твой стрелки. Можно плюсы ярче сделать?» · «но чтобы сохранить стиль конана».
# The game draws the attribute row's «+» (`LevelAttributeButton`) with its own texture T_Attributes_perk_button_default TINTED 0.495 (linear) in the normal state
# (hovered: T_Attributes_perk_button_hover at 0.724) — kit-probe-plus-button.json 2026-11-10. Brighter in the game's style = the same texture, a higher tint.
# This draws that on a real 4K frame: inside each «+» diamond the linear colour is scaled by tint / 0.495 (the game multiplies texture × tint in linear).
#   /c/Python314/python.exe -X utf8 plus_brightness_mockup.py <frame 3840x2160> <out dir>
# [NOT-TESTED]
import os
import sys
from PIL import Image, ImageDraw, ImageFont

SANS_B, SANS = "C:/Windows/Fonts/NotoSans-Bold.ttf", "C:/Windows/Fonts/NotoSans-Regular.ttf"
GAME_TINT = 0.495
PLUS_X = 729                                          # the «+» centres on the base frame (4K px), one per attribute row
PLUS_Y = (551, 762, 973, 1187, 1398, 1609)
R = 40                                                # the diamond's half-diagonal with its rim
VARIANTS = [("00_seychas_0495", "сейчас · оттенок игры 0,495", GAME_TINT),
            ("01_kak_pri_navedenii_072", "V1 · 0,72 — как у игры при наведении", 0.724),
            ("02_yarche_085", "V2 · 0,85", 0.85),
            ("03_polnaya_yarkost_100", "V3 · 1,0 — текстура игры без затемнения", 1.0),
            ("04_kak_strelka_140", "V4 · 1,4 — ближе к яркости стрелки", 1.4)]   # Slate takes a tint above 1: the same texture, brighter
# The owner 13:18 «неужели ты не видишь, как ты не соблюдаешь цветовую схему???» (his crop of V4: a cold pale-green «+» beside the warm gold arrow) — a GREY tint
# brightens the texture's own olive into a cold cream. A per-channel (warm) tint, measured on the frame (13:18): the «+» rim (139, 142, 127) and its brightest
# pixels (199, 188, 171) at the game's 0.495; our arrow's rim (222, 178, 102) and triangle (≈ 251, 230, 172). The tints below are LINEAR per channel (R, G, B).
# 13:2x the palette READ from the game (Funcom's FS_ styles, KUMM researches/conan-ui-color-scheme/fs-style-colors.tsv): the interactive gold of a scrollbar thumb
# is #E9C27A normal, #ECD97C hovered, #5E4A1F dragged. The «+» rim measured (139, 142, 127) is matched to those per channel (linear gains × the game's 0.495).
WARM = [("05_zoloto_konana_E9C27A", "G1 · золото Конана #E9C27A (обычное состояние)", (1.56, 0.99, 0.46)),
        ("06_zoloto_konana_navedenie_ECD97C", "G2 · светлое золото Конана #ECD97C (как под курсором)", (1.61, 1.27, 0.47))]


def to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(c):
    c = max(0.0, min(1.0, c))
    return round(255 * (12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055))


def brighten(img, gain):
    if not isinstance(gain, tuple):
        gain = (gain, gain, gain)
    gr, gg, gb = gain
    px = img.load()
    lut = [to_lin(v) for v in range(256)]
    for cy in PLUS_Y:
        for y in range(cy - R, cy + R + 1):
            for x in range(PLUS_X - R, PLUS_X + R + 1):
                if abs(x - PLUS_X) + abs(y - cy) > R:
                    continue
                r, g, b = px[x, y]
                px[x, y] = (to_srgb(lut[r] * gr), to_srgb(lut[g] * gg), to_srgb(lut[b] * gb))


def caption(img, title):
    d = ImageDraw.Draw(img, "RGBA")
    d.rounded_rectangle((60, 1990, 1900, 2120), 12, fill=(0, 0, 0, 190))
    d.text((90, 2000), title, font=ImageFont.truetype(SANS_B, 60), fill=(240, 232, 214))
    d.text((90, 2072), "нет механики — будет сделано (оттенок кнопки в виджете)", font=ImageFont.truetype(SANS, 40), fill=(190, 182, 166))


def main(frame, out):
    os.makedirs(out, exist_ok=True)
    base = Image.open(frame).convert("RGB")
    if base.size != (3840, 2160):
        raise SystemExit("the base frame must be 3840x2160, got %s" % (base.size,))
    for name, title, tint in ([] if os.environ.get("MOCK_ONLY_WARM") else VARIANTS):   # the viewer may hold the first files open
        img = base.copy()
        if tint != GAME_TINT:
            brighten(img, tint / GAME_TINT)
        caption(img, title)
        p = os.path.join(out, name + ".webp")
        img.save(p, "WEBP", quality=90)
        print(p)
    for name, title, tint in WARM:
        img = base.copy()
        brighten(img, tuple(t / GAME_TINT for t in tint))
        caption(img, title)
        p = os.path.join(out, name + ".webp")
        img.save(p, "WEBP", quality=90)
        print(p)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
