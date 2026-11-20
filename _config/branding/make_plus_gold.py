# make_plus_gold.py — the attribute row's «+» in Conan's own gold as OUR textures (KUMM plan 49 G1: `[OWNER]` 2026-11-10 13:41 «05 золото конана» — verbatim in plan 49).
#
# Why a texture and not a tint (found 2026-11-14 00:5x on the 3.1.0 build): the button brush tint is CLAMPED at 1.0 per channel on screen — with the live «+»
# tint R 1.5623, 1.0 and (control) 0.3, the rim read (188, 194, 141), the same to the pixel, and (133, 182, 131) (KUMM plan 49, the 3.1.0 kit session). The game's
# olive texture at R ≤ 1.0 cannot reach #E9C27A. So the gain the mockup applied (plus_brightness_mockup.py: display × tint / 0.495) is baked INTO the texture,
# in linear light, clamped at 1.0, alpha kept; the kit brushes then draw them at tint 1.0:
#   T_KrinikPlusGold      = T_Attributes_perk_button_default × (1.5623, 0.9872, 0.4539)   — normal, rim → #E9C27A (G1)
#   T_KrinikPlusGoldHover = T_Attributes_perk_button_hover   × (1.6082, 1.2698, 0.4701)   — hovered, the lighter gold #ECD97C (G2)
# The gains are kit-plus-button-gold.py's (0.495 × lin(target) / lin(the rim (139, 142, 127) measured at 0.495)). Pressed stays the game's hover texture with
# its dark tint (all channels < 1 — no clamp). Sources: the game's own 50 × 50 textures exported by the kit (kit-export-textures.py) — the same resolution.
#   python -X utf8 make_plus_gold.py <T_Attributes_perk_button_default.tga> <T_Attributes_perk_button_hover.tga> <out dir> [<preview.webp>]
# [TESTED: 2026-11-14 · the two textures baked, imported and drawn in the 3.1.0 game: K5 rim (206, 175, 107), K6 hover (229, 206, 104) · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
import os
import sys

from PIL import Image

GAINS = {"T_KrinikPlusGold": (1.5623, 0.9872, 0.4539), "T_KrinikPlusGoldHover": (1.6082, 1.2698, 0.4701)}


def to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(v):
    v = min(max(v, 0.0), 1.0)
    s = v * 12.92 if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
    return int(round(s * 255))


def bake(src, gain):
    im = Image.open(src).convert("RGBA")
    lut = [[to_srgb(to_lin(c) * g) for c in range(256)] for g in gain]   # per channel: sRGB in → sRGB out
    r, g, b, a = im.split()
    return Image.merge("RGBA", (r.point(lut[0]), g.point(lut[1]), b.point(lut[2]), a))


def main(default_tga, hover_tga, out_dir, preview=None):
    os.makedirs(out_dir, exist_ok=True)
    made = {}
    for name, src in (("T_KrinikPlusGold", default_tga), ("T_KrinikPlusGoldHover", hover_tga)):
        im = bake(src, GAINS[name])
        im.save(os.path.join(out_dir, name + ".tga"))
        made[name] = im
        print("ok", name, im.size)
    if preview:   # the game's two textures at the game's tints beside ours at 1.0, ×6, on the screen's dark plate — for the eye
        tiles = [bake(default_tga, (0.495,) * 3), made["T_KrinikPlusGold"], bake(hover_tga, (0.724,) * 3), made["T_KrinikPlusGoldHover"]]
        w = tiles[0].width * 6
        sheet = Image.new("RGBA", (w * len(tiles), w), (22, 24, 30, 255))
        for i, t in enumerate(tiles):
            sheet.alpha_composite(t.resize((w, w), Image.LANCZOS), (w * i, 0))
        sheet.convert("RGB").save(preview, quality=90)
        print("preview", preview)


if __name__ == "__main__":
    if len(sys.argv) < 4:
        raise SystemExit("usage: make_plus_gold.py <default.tga> <hover.tga> <out dir> [<preview.webp>]")
    main(*sys.argv[1:5])
