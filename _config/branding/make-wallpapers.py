# make-wallpapers.py — the build's wallpaper with both logos and the versions in large digits (KUMM plan 36 W26).
# `[OWNER]` «и наше лого и лого оригинальной игры (нужно найти его в ПНГ) будем накладывать на картинку-оригинал-волпейпер» ·
# «и внизу тоже будем крупно цифрами писать версии» · 2026-10-30 22:44. Order as in the main menu: the game's logo left, ours right
# (`[OWNER]` «в главном меню - справа» · 22:40); under the game's logo the game version, under ours the build version (22:39).
#
#   python -X utf8 make-wallpapers.py <layout> <wallpaper> <out> [--game 3.0.1] [--pack 0.9.0]
#   layouts (four for the owner's choice — «4 варианта!» · 22:50):
#     top-centre — the pair centred at the top, each version under its logo
#     sky-left — the pair over the clouds on the left, each version under its logo
#     top-centre-digits-bottom — the pair centred at the top, both versions large at the bottom edge
#     stack-left — the game's logo above, ours under it, each version to the right of its logo
# Geometry is in shares of the picture height, so one call serves 1080p, 2K and 4K. Output by the extension: .webp for review, .jpg q95
# for players. Logos: conan-exiles-enhanced-logo.webp (the game's texture T_UI_ConanExiles_Enhanced_Logo, exported by
# devkit/kit-export-textures.py) and krinik-modpack-logo.webp; font fonts/Cardo-Bold.ttf (the game's UI face, OFL).
# [TESTED: 2026-10-30 · four layouts and the final A3-smaller rendered at 4K and looked at; 1080p/2K/4K built]
import argparse
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
LOGOS = os.path.join(HERE, "..", "..", "art", "logos")   # the pack root's art folder since 2026-11-18 (interview #040 Q2 A)
GAME_LOGO = os.path.join(LOGOS, "conan-exiles-enhanced-logo.webp")
PACK_LOGO = os.path.join(LOGOS, "krinik-modpack-logo.webp")
FONT = os.path.join(HERE, "fonts", "Cardo-Bold.ttf")
LAYOUTS = ("top-centre", "sky-left", "top-centre-digits-bottom", "stack-left")
LOGO_H = 0.26          # logo height, share of the picture height — the owner: A2 «хорошо» 22:53, then «А3 лучше» + «чуть чуть меньше оба логотипа»
GAP = 0.035            # [AI] gap between the logos / between a logo and its digits, share of the height
PACK_DX = 0.04         # our logo (and its digits) moved right, share of the height: «лого криника чуть-чуть правее, чтобы не так голову сильно трогало» (22:53)
MARGIN = 0.045         # [AI] distance from the picture edge, share of the height
DIGIT_H = 0.125        # font size of the version digits — A3
UNDER = 0.012          # [AI] gap between a logo and the digits under it, share of the height
INK = (233, 213, 193)  # the prompt row ink of the game UI (measured 2026-10-30 21:22) — the logos' warm beige
HALO_ALPHA = 210       # [AI] the dark halo behind the digits — legible on clouds and on sand
HALO_BLUR = 0.08       # [AI] halo blur radius, share of the font size
# A light drop shadow under the digits (`--shadow`): on the light V2 «Реализм» the halo alone left «3.1.1» unreadable over the pale towers
# (the owner 2026-11-18 15:54 «не читается, нужна лёгкая тень»). Off by default, so the v1 wallpapers rebuild as they were.
SHADOW_OFFSET = 0.035  # [AI] shadow offset down and right, share of the font size
SHADOW_BLUR = 0.03     # [AI] shadow blur radius, share of the font size
SHADOW_ALPHA = 190     # [AI] shadow opacity (0–255)
shadow_on = False      # set by --shadow in main()


def trimmed(path):
    im = Image.open(path).convert("RGBA")
    return im.crop(im.split()[3].getbbox())


def fit_h(im, h):
    return im.resize((max(1, round(im.width * h / im.height)), round(h)), Image.LANCZOS)


def digits(canvas, font, text, cx, cy):
    """Draw text centred on (cx, cy) by its ink box, over a soft dark halo (and a light drop shadow with --shadow)."""
    l, t, r, b = font.getbbox(text)
    x, y = round(cx - (l + r) / 2), round(cy - (t + b) / 2)
    if shadow_on:
        off = max(1, round(font.size * SHADOW_OFFSET))
        sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((x + off, y + off), text, font=font, fill=(0, 0, 0, SHADOW_ALPHA))
        canvas.alpha_composite(sh.filter(ImageFilter.GaussianBlur(max(1, font.size * SHADOW_BLUR))))
    halo = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    stroke = max(2, font.size // 14)
    ImageDraw.Draw(halo).text((x, y), text, font=font, fill=(0, 0, 0, HALO_ALPHA), stroke_width=stroke, stroke_fill=(0, 0, 0, HALO_ALPHA))
    canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(max(1, font.size * HALO_BLUR))))
    ImageDraw.Draw(canvas).text((x, y), text, font=font, fill=INK + (255,))


def compose(bg, layout, game_ver, pack_ver, logo_h=LOGO_H, digit_h=DIGIT_H):
    W, H = bg.size
    g, k = fit_h(trimmed(GAME_LOGO), logo_h * H), fit_h(trimmed(PACK_LOGO), logo_h * H)
    gap, margin, under, dx = round(GAP * H), round(MARGIN * H), round(UNDER * H), round(PACK_DX * H)
    font = ImageFont.truetype(FONT, round(digit_h * H))
    ink_h = font.getbbox("0")[3] - font.getbbox("0")[1]
    if layout == "stack-left":
        gx, gy = margin, margin
        kx, ky = margin + (g.width - k.width) // 2, margin + g.height + gap
        bg.alpha_composite(g, (gx, gy))
        bg.alpha_composite(k, (kx, ky))
        dx = margin + g.width + gap + font.getlength(game_ver) / 2
        digits(bg, font, game_ver, dx, gy + g.height / 2)
        digits(bg, font, pack_ver, dx, ky + k.height / 2)
        return
    pair_w = g.width + gap + k.width
    x0 = margin if layout == "sky-left" else (W - pair_w) // 2
    y0 = margin
    bg.alpha_composite(g, (x0, y0))
    bg.alpha_composite(k, (x0 + g.width + gap + dx, y0))
    gcx, kcx = x0 + g.width / 2, x0 + g.width + gap + dx + k.width / 2
    cy = H - margin - ink_h / 2 if layout == "top-centre-digits-bottom" else y0 + g.height + under + ink_h / 2
    digits(bg, font, game_ver, gcx, cy)
    digits(bg, font, pack_ver, kcx, cy)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("layout", choices=LAYOUTS)
    ap.add_argument("wallpaper")
    ap.add_argument("out")
    # Defaults — the game and the build of the pack's manifest (launcher.gameVersion, packVersion): the constants 3.0.1 / 0.9.0 outlived 0.9.1 (KUMM plans/55 R1).
    import json
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "modpack.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    ap.add_argument("--game", default=manifest["launcher"]["gameVersion"])
    ap.add_argument("--pack", default=manifest["packVersion"])
    ap.add_argument("--logo-h", type=float, default=LOGO_H, help="logo height, share of the picture height")
    ap.add_argument("--digit-h", type=float, default=DIGIT_H, help="digit font size, share of the picture height")
    ap.add_argument("--shadow", action="store_true", help="a light drop shadow under the digits (light backgrounds)")
    a = ap.parse_args()
    global shadow_on
    shadow_on = a.shadow
    bg = Image.open(a.wallpaper).convert("RGBA")
    compose(bg, a.layout, a.game, a.pack, a.logo_h, a.digit_h)
    out = bg.convert("RGB")
    if a.out.lower().endswith(".webp"):
        out.save(a.out, "WEBP", quality=90)
    else:
        out.save(a.out, "JPEG", quality=95, subsampling=0)
    print("%s %dx%d -> %s" % (a.layout, bg.width, bg.height, a.out))


if __name__ == "__main__":
    main()
