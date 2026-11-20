# Mock-ups of the «Оставить отзыв» button (KUMM plan 36 W37) on the real main-menu frame — the taste class: the owner picks
# (`[OWNER]` «кнопку можно было бы сделать "Оставить отзыв"» · «только как-то в стиле логотипов ее сделать красиво» · 2026-10-31 00:41).
# The plate is cut from OUR logo's «MOD PACK» banner (end caps + tiled plain stone); the letters — bronze with a bevel; fonts in fonts/ (OFL).
# usage: python -X utf8 mock-feedback-button.py <menu_frame_1920.jpg> <out_dir>      → A / Б / В, full 4K frame + a close crop each
# Shown 2026-10-31 00:49 — review folder 16. [NOT-TESTED] in game: a mock-up, not the kit button
import os
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

BR = "D:/work/ai_sandbox/ConanExiles/_config/branding"
DL = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
LOGO = "D:/work/ai_sandbox/ConanExiles/art/logos/krinik-modpack-logo.webp"   # art moved 2026-11-18
GAME_LOGO = "D:/work/ai_sandbox/ConanExiles/art/logos/conan-exiles-enhanced-logo.webp"
K = 2.0   # 1080p units → 4K pixels

logo = Image.open(LOGO).convert("RGBA")
banner = logo.crop((0, 830, 3992, 1440))          # the «MOD PACK» plate, 3992×610
LEFT, RIGHT = banner.crop((0, 0, 650, 610)), banner.crop((3390, 0, 3992, 610))
for cap, x0, x1 in ((LEFT, 0, 300), (RIGHT, RIGHT.width - 300, RIGHT.width)):   # crumbs of KRINIK above the curls
    _a = cap.split()[3]
    ImageDraw.Draw(_a).rectangle((x0, 0, x1, 40), fill=0)
    cap.putalpha(_a)
BOLD = {}   # font path -> extra stroke: Forum is a Regular, «MOD PACK» is heavier
FILL = banner.crop((660, 0, 760, 610))             # plain stone between the left ornament and «M»


def plate(inner_w):
    """The plate at the banner's own scale: left cap + tiled plain stone (mirrored every other tile) + right cap."""
    out = Image.new("RGBA", (LEFT.width + inner_w + RIGHT.width, 610), (0, 0, 0, 0))
    out.alpha_composite(LEFT, (0, 0))
    x, flip = LEFT.width, False
    while x < LEFT.width + inner_w:
        t = FILL.transpose(Image.FLIP_LEFT_RIGHT) if flip else FILL
        out.alpha_composite(t.crop((0, 0, min(t.width, LEFT.width + inner_w - x), 610)), (x, 0))
        x, flip = x + t.width, not flip
    out.alpha_composite(RIGHT, (LEFT.width + inner_w, 0))
    return out


def bronze_text(text, font, pad=40):
    """Embossed bronze letters like the logos': a vertical bronze gradient, a light bevel up-left, a dark bevel down-right, a drop shadow."""
    l, t, r, b = font.getbbox(text)
    w, h = r - l + 2 * pad, b - t + 2 * pad
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((pad - l, pad - t), text, font=font, fill=255, stroke_width=BOLD.get(font.path, 0), stroke_fill=255)
    grad = Image.new("RGBA", (w, h))
    gd = ImageDraw.Draw(grad)
    stops = [(0.0, (240, 214, 178)), (0.45, (201, 152, 104)), (1.0, (120, 74, 42))]
    y0, y1 = pad, h - pad
    for y in range(h):
        f = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        for (a, ca), (bb, cb) in zip(stops, stops[1:]):
            if a <= f <= bb:
                u = (f - a) / (bb - a)
                gd.line([(0, y), (w, y)], fill=tuple(round(ca[i] + (cb[i] - ca[i]) * u) for i in range(3)) + (255,))
                break
    s = max(2, font.size // 60)
    hi = ImageChops.subtract(mask, ImageChops.offset(mask, s, s))      # edges facing up-left
    lo = ImageChops.subtract(mask, ImageChops.offset(mask, -s, -s))    # edges facing down-right
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow.putalpha(ImageChops.offset(mask, 2 * s, 3 * s).filter(ImageFilter.GaussianBlur(3 * s)).point(lambda v: v * 0.85))
    out.alpha_composite(shadow)
    letters = grad.copy()
    letters.putalpha(mask)
    out.alpha_composite(letters)
    for m, col in ((hi, (255, 238, 210)), (lo, (60, 34, 16))):
        layer = Image.new("RGBA", (w, h), col + (0,))
        layer.putalpha(m.filter(ImageFilter.GaussianBlur(s * 0.6)).point(lambda v: v * 0.8))
        out.alpha_composite(layer)
    return out


def plate_button(text, font_path, size, height_px):
    font = ImageFont.truetype(font_path, size)
    tx = bronze_text(text, font)
    p = plate(tx.width + 200)
    p.alpha_composite(tx, ((p.width - tx.width) // 2, (p.height - tx.height) // 2 + 6))
    return p.resize((round(p.width * height_px / p.height), height_px), Image.LANCZOS)


def link_button(text, font_path, size, height_px):
    font = ImageFont.truetype(font_path, size)
    tx = bronze_text(text, font)
    w, h = tx.width, tx.height + 70
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(tx, (0, 0))
    d = ImageDraw.Draw(out)
    y = tx.height + 14
    d.line([(w * 0.18, y), (w * 0.82, y)], fill=(201, 152, 104, 230), width=6)
    d.polygon([(w / 2, y - 14), (w / 2 + 14, y), (w / 2, y + 14), (w / 2 - 14, y)], fill=(222, 182, 132, 255))
    return out.resize((round(w * height_px / h), height_px), Image.LANCZOS)


def menu(frame_path):
    """The 1080p menu frame upscaled to 4K, with our logo and both version lines where the kit puts them (kit-conanui-edit.json, 2026-10-31)."""
    bg = Image.open(frame_path).convert("RGBA").resize((3840, 2160), Image.LANCZOS)
    t = logo.crop(logo.split()[3].getbbox()).resize((round(427 * K), round(162 * K)), Image.LANCZOS)
    bg.alpha_composite(t, (round(507.5 * K), round(131.2 * K)))
    f = ImageFont.truetype("C:/Windows/Fonts/georgiab.ttf", round(22 * K))
    d = ImageDraw.Draw(bg)
    for txt, cx, top in (("3.0.1", 72 + 21 / 1024 * 384 + 999 / 1024 * 384 / 2, 302), ("1.0.0", 507.5 + 427 / 2, 283)):
        d.text((cx * K, top * K), txt, font=f, fill=(233, 213, 193, 255), anchor="mt")
    return bg


HOVER_GAIN = 1.25   # [AI] the hover texture: the same letters and rule, brighter
TEX_H = 160         # [AI] texture height in pixels: 4 × the 40-unit button — crisp at 4K, mips off


def textures(out):
    """`--textures <dir>`: the ACCEPTED button as the kit's two UI textures (TGA with alpha — the kit imports TGA; never PNG):
    the Б1 plate with «ОТЗЫВ» (Cormorant SC), 40 units — `[OWNER]` «высота 40 принята» · 2026-10-31 01:03 (round 5, review folder 20)."""
    os.makedirs(out, exist_ok=True)
    btn = plate_button("ОТЗЫВ", os.path.join(DL, "CormorantSC-Bold.ttf"), 420, TEX_H)
    hov = Image.merge("RGBA", [c.point(lambda v: min(255, round(v * HOVER_GAIN))) for c in btn.split()[:3]] + [btn.split()[3]])
    for name, im in (("T_KrinikFeedback", btn), ("T_KrinikFeedbackHover", hov)):
        im.save(os.path.join(out, name + ".tga"))
        print(name, im.size)


def main():
    if sys.argv[1] == "--textures":
        return textures(sys.argv[2])
    frame, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    cx, top = (507.5 + 427 / 2) * K, 322 * K   # under our logo and its version line
    BOLD[os.path.join(DL, "Forum-Regular.ttf")] = 9
    variants = {
        "А табличка, Forum": plate_button("ОСТАВИТЬ ОТЗЫВ", os.path.join(DL, "Forum-Regular.ttf"), 400, round(52 * K)),
        "Б табличка, Cormorant": plate_button("Оставить отзыв", os.path.join(DL, "CormorantSC-Bold.ttf"), 420, round(52 * K)),
        "В без таблички, Forum": link_button("ОСТАВИТЬ ОТЗЫВ", os.path.join(DL, "Forum-Regular.ttf"), 400, round(40 * K)),
    }
    for name, btn in variants.items():
        bg = menu(frame)
        bg.alpha_composite(btn, (round(cx - btn.width / 2), round(top)))
        bg.convert("RGB").save(os.path.join(out, name + ".webp"), "WEBP", quality=90)
        crop = bg.crop((round(cx - 700), round(80 * K), round(cx + 700), round(460 * K)))
        crop.convert("RGB").save(os.path.join(out, name + " — крупно.webp"), "WEBP", quality=90)
        print(name, btn.size)


if __name__ == "__main__":
    main()
