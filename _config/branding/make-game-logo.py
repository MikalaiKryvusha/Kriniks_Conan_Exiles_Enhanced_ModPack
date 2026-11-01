# make-game-logo.py — the game's logo for the menus, from the owner's upscale (KUMM plan 36 W26):
#   `[OWNER]` «и почему оригинальное логи в меню такое мутное?» · «легко заменяить? я бы апскейл сделал» · 2026-10-31 01:01;
#   «сделал апскейл, бери ультрамикс, R сотри и красиво четко нарисуй вверху справа R» · 01:09.
#
#   python -X utf8 make-game-logo.py <upscale_3x.png> <out_dir>
#     → <out_dir>/conan-exiles-enhanced-logo-3x.webp   the cleaned master, 3072×1536, lossless (the pack keeps this, never the PNG)
#     → <out_dir>/T_UI_ConanExiles_Enhanced_Logo.tga   the kit texture, 1024×512 (Lanczos from the master)
#
# Why 1024 and not 3072: the widest the game ever draws this logo is 1024 px (the Esc menu, 512 units at 4K; the main menu — 768 px). The vanilla
# texture's blur comes from its mip chain (game map, 2026-10-31), not from too few pixels; our texture goes WITHOUT mips, and a texture much larger
# than its drawn size would shimmer without them. The upscale's gain is the cleaner, crisper 1024 made from it.
# [NOT-TESTED]
import os
import sys

from PIL import Image, ImageDraw, ImageFont

R_BOX = (3008, 150, 3072, 222)     # the blurry ® of the upscale (crop 2026-10-31 01:09: circle ≈ 3020..3060 × 165..205); N's edge ends ≈ 3002
R_CENTRE = (3040, 185)             # where the new ® goes — the old one's centre
R_SIZE = 50                        # px: the glyph's em at 3x — the circle comes out ≈ 40 px, the old one's diameter
R_INK = (34, 30, 26, 255)          # the old ®'s dark ink (sampled from the crop)
R_FONT = "C:/Windows/Fonts/segoeuib.ttf"   # bold — the old one's weight
SS = 8                             # supersampling of the glyph — a smooth circle


def main():
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    im = Image.open(src).convert("RGBA")
    a = im.split()[3]
    ImageDraw.Draw(a).rectangle(R_BOX, fill=0)          # erase the old ®
    im.putalpha(a)
    font = ImageFont.truetype(R_FONT, R_SIZE * SS)
    l, t, r, b = font.getbbox("®")
    g = Image.new("RGBA", (r - l + 4 * SS, b - t + 4 * SS), (0, 0, 0, 0))
    ImageDraw.Draw(g).text((2 * SS - l, 2 * SS - t), "®", font=font, fill=R_INK)
    g = g.resize((g.width // SS, g.height // SS), Image.LANCZOS)
    im.alpha_composite(g, (R_CENTRE[0] - g.width // 2, R_CENTRE[1] - g.height // 2))
    im.save(os.path.join(out, "conan-exiles-enhanced-logo-3x.webp"), "WEBP", lossless=True)
    im.resize((1024, 512), Image.LANCZOS).save(os.path.join(out, "T_UI_ConanExiles_Enhanced_Logo.tga"))
    print("master", im.size, "® glyph", g.size)


if __name__ == "__main__":
    main()
