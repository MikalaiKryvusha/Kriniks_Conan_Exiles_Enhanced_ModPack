"""logo.py -- the mod's name in dimensional bronze over the logo frame.

THE ASK (owner, 2026-09-10): the mod's name on the logo image, in a bronze
DIMENSIONAL face, Conan style; under it the descriptor that used to sit after
the dash in the proposed title. Refined by him the same evening: bronze B
(struck metal), the title a little larger, the second line MUCH larger and
set in Arial, both lines in capitals.

    KRINIK CAMERA BEHIND
    THIRD PERSON CAMERA CONTROL

The title's face is Crom (installed by the owner); the second line is
Arial Bold by his word. It has NO CYRILLIC -- checked by
rendering: Latin and digits come out, Russian comes out empty -- so the logo
speaks English and any Russian line would need a second family.

HOW THE DEPTH IS MADE. Not a filter, five stacked passes, back to front:

    1. drop shadow   a blurred mask under everything, so the letters hold on
                     a bright sky
    2. extrusion     the mask repeated step by step down-right in dark
                     bronze -- this is what makes it a SOLID, not an outline
    3. face          a vertical metal gradient clipped to the glyphs:
                     highlight along the top, deep bronze at the foot
    4. bevel         a light rim where the face turns up (mask minus mask
                     shifted down-right) and a dark rim where it turns down
    5. contour       a dark edge so the metal separates from the landscape

    python logo.py <source.png> <out_dir> [--variant a|b|c] [--sheet]

[NOT-TESTED] at birth; every variant is opened and looked at by the agent
before the owner sees the sheet (EXP-0081).
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops

CROM = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Windows", "Fonts", "Crom_v1.ttf")   # the per-user font folder
# The second line is Arial by the owner's word (2026-09-10): Crom is a
# barbaric display face and at descriptor size its quirks -- the K drawn as
# a small k, the curled D -- start reading as mistakes rather than style.
ARIAL = "arialbd.ttf"

# Both lines are forced to upper case: the owner asked for caps, and a
# forced .upper() means a later edit of the strings cannot break that.
TITLE = "KRINIK CAMERA BEHIND".upper()
SUBTITLE = "THIRD PERSON CAMERA CONTROL".upper()

# --- the three bronzes on offer -------------------------------------------
# Each is a vertical ramp: (position 0..1, colour). Position 0 is the top of
# the glyph. Real cast bronze is bright where it faces the sky and deep in
# the hollows, which is why every ramp ends dark.
BRONZE = {
    # a: warm poster bronze, the Conan-cover look
    "a": [(0.00, (247, 222, 173)), (0.30, (216, 160, 91)),
          (0.55, (169, 112, 47)), (1.00, (107, 63, 23))],
    # b: struck metal -- a narrow hot highlight, then a fast fall
    "b": [(0.00, (255, 244, 214)), (0.16, (232, 186, 116)),
          (0.34, (150, 92, 38)), (0.70, (196, 133, 62)), (1.00, (74, 43, 16))],
    # c: aged bronze -- the same metal with patina settling in the shadows
    "c": [(0.00, (238, 209, 160)), (0.28, (198, 142, 78)),
          (0.60, (110, 96, 55)), (0.82, (74, 96, 74)), (1.00, (46, 58, 44))],
}
DEPTH_RGB = {"a": (58, 32, 12), "b": (44, 24, 9), "c": (34, 40, 30)}

# fractions of the frame's width/height, so a 4096 render and a 512 preview
# carry the same design
TITLE_W_FRAC = 0.90     # the title spans this share of the width
SUB_W_FRAC = 0.84
SUB_TRACK_FRAC = 0.006  # letter spacing of the subtitle, share of width
TOP_FRAC = 0.070        # where the title's cap line starts
GAP_FRAC = 0.036        # title -> subtitle
DEPTH_FRAC = 0.0085     # extrusion length, share of width
CONTOUR_FRAC = 0.0035


def _fit_width(text, target_px, font_path=CROM):
    """Pick the pixel size at which the text is target_px wide.

    Width, not cap height: on a logo the line must SPAN a known share of the
    frame, and Crom's caps vary enough that solving for height misses."""
    size = max(10, int(target_px / max(1, len(text)) * 1.6))
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    for _ in range(16):
        f = ImageFont.truetype(font_path, size)
        box = probe.textbbox((0, 0), text, font=f)
        w = box[2] - box[0]
        if abs(w - target_px) <= max(2, target_px * 0.004):
            return f, box
        size = max(10, int(round(size * target_px / max(w, 1))))
    return ImageFont.truetype(font_path, size), probe.textbbox(
        (0, 0), text, font=ImageFont.truetype(font_path, size))


def _tracked_width(text, font, track):
    """Width of the line when every letter is pushed apart by track px."""
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    return (sum(probe.textlength(ch, font=font) for ch in text)
            + track * max(0, len(text) - 1))


def _fit_tracked(text, target_px, track, font_path=CROM):
    """Same solve as _fit_width, but for a letter-spaced line.

    The subtitle is spaced because Crom is a dense display face: set solid at
    caption size its counters close up and the line reads as a smear."""
    size = max(8, int(target_px / max(1, len(text)) * 1.4))
    for _ in range(16):
        f = ImageFont.truetype(font_path, size)
        w = _tracked_width(text, f, track)
        if abs(w - target_px) <= max(2, target_px * 0.004):
            return f
        size = max(8, int(round(size * target_px / max(w, 1))))
    return ImageFont.truetype(font_path, size)


def _draw_tracked(mask, text, font, track, x, baseline):
    """Draw a letter-spaced line into an L mask, letter by letter."""
    d = ImageDraw.Draw(mask)
    cx = float(x)
    for ch in text:
        d.text((cx, baseline), ch, font=font, fill=255, anchor="ls")
        cx += d.textlength(ch, font=font) + track


def _ramp(size, stops):
    """A vertical colour ramp as an RGB image of the given size."""
    w, h = size
    strip = Image.new("RGB", (1, h))
    px = strip.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                k = (t - p0) / max(1e-6, p1 - p0)
                px[0, y] = tuple(int(c0[j] + (c1[j] - c0[j]) * k)
                                 for j in range(3))
                break
        else:
            px[0, y] = stops[-1][1]
    return strip.resize((w, h))


def _mask_of(text, font, box, canvas):
    """The glyph coverage of one line, drawn into a full-canvas L mask."""
    m = Image.new("L", canvas, 0)
    ImageDraw.Draw(m).text((-box[0], -box[1]), text, font=font, fill=255)
    return m


def _metal(mask, stops, depth_rgb, depth_px, contour_px, canvas):
    """Turn a flat glyph mask into a lit, extruded bronze layer (RGBA)."""
    W, H = canvas
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))

    # --- 1. drop shadow: the letters must hold on a bright sky
    sh = mask.filter(ImageFilter.GaussianBlur(max(2, depth_px * 1.1)))
    sh = ImageChops.offset(sh, int(depth_px * 0.6), int(depth_px * 1.1))
    shadow = Image.new("RGBA", canvas, (0, 0, 0, 255))
    shadow.putalpha(sh.point(lambda v: int(v * 0.62)))
    out = Image.alpha_composite(out, shadow)

    # --- 2. extrusion: the mask walked back to front, so it reads as a solid
    ext = Image.new("L", canvas, 0)
    for i in range(depth_px, 0, -1):
        ext = ImageChops.lighter(
            ext, ImageChops.offset(mask, int(i * 0.72), int(i * 1.0)))
    side = Image.new("RGBA", canvas, depth_rgb + (255,))
    side.putalpha(ext)
    out = Image.alpha_composite(out, side)

    # --- 5a. contour under the face, so the metal separates from the sky
    if contour_px:
        grown = mask.filter(ImageFilter.MaxFilter(contour_px * 2 + 1))
        edge = Image.new("RGBA", canvas, (26, 15, 6, 255))
        edge.putalpha(grown)
        out = Image.alpha_composite(out, edge)

    # --- 3. the face: a metal ramp clipped to the glyphs
    bbox = mask.getbbox()
    face = Image.new("RGBA", canvas, (0, 0, 0, 0))
    if bbox:
        band = _ramp((W, bbox[3] - bbox[1]), stops)
        strip = Image.new("RGB", canvas, stops[-1][1])
        strip.paste(band, (0, bbox[1]))
        face = strip.convert("RGBA")
        face.putalpha(mask)
    out = Image.alpha_composite(out, face)

    # --- 4. the bevel: a lit rim on the up-facing edge, dark on the other
    lift = max(1, int(depth_px * 0.30))
    up = ImageChops.subtract(mask, ImageChops.offset(mask, -lift, -lift))
    dn = ImageChops.subtract(mask, ImageChops.offset(mask, lift, lift))
    hi = Image.new("RGBA", canvas, (255, 240, 208, 255))
    hi.putalpha(up.point(lambda v: int(v * 0.55)))
    lo = Image.new("RGBA", canvas, (48, 26, 10, 255))
    lo.putalpha(dn.point(lambda v: int(v * 0.45)))
    out = Image.alpha_composite(out, hi)
    out = Image.alpha_composite(out, lo)
    return out


def render(src, variant="a"):
    base = Image.open(src).convert("RGB")
    W, H = base.size
    canvas = (W, H)

    depth = max(3, int(W * DEPTH_FRAC))
    contour = max(1, int(W * CONTOUR_FRAC))

    t_font, t_box = _fit_width(TITLE, W * TITLE_W_FRAC)
    t_w, t_h = t_box[2] - t_box[0], t_box[3] - t_box[1]
    t_x, t_y = (W - t_w) // 2, int(H * TOP_FRAC)

    t_mask = Image.new("L", canvas, 0)
    ImageDraw.Draw(t_mask).text((t_x - t_box[0], t_y - t_box[1]), TITLE,
                                font=t_font, fill=255)

    track = W * SUB_TRACK_FRAC
    s_font = _fit_tracked(SUBTITLE, W * SUB_W_FRAC, track, ARIAL)
    s_w = _tracked_width(SUBTITLE, s_font, track)
    s_ascent = s_font.getbbox("H")[3] - s_font.getbbox("H")[1]
    s_baseline = t_y + t_h + int(H * GAP_FRAC) + s_ascent
    s_mask = Image.new("L", canvas, 0)
    _draw_tracked(s_mask, SUBTITLE, s_font, track, (W - s_w) / 2, s_baseline)

    out = base.convert("RGBA")
    out = Image.alpha_composite(out, _metal(
        t_mask, BRONZE[variant], DEPTH_RGB[variant], depth, contour, canvas))
    # The subtitle is the same metal at half the depth and with no contour:
    # it is now a big line in its own right, but a second full extrusion
    # next to the title would read as two titles.
    out = Image.alpha_composite(out, _metal(
        s_mask, BRONZE[variant], DEPTH_RGB[variant],
        max(2, depth // 2), 0, canvas))
    return out.convert("RGB")


def main(argv):
    src = argv[1]
    out_dir = argv[2]
    want = None
    if "--variant" in argv:
        want = argv[argv.index("--variant") + 1]
    os.makedirs(out_dir, exist_ok=True)

    made = []
    for key in ([want] if want else ["a", "b", "c"]):
        im = render(src, key)
        path = os.path.join(out_dir, "logo-%s.jpg" % key)
        im.save(path, quality=94)
        made.append((key, path, im))
        print("%s -> %s (%dx%d)" % (key, path, im.width, im.height))

    if "--sheet" in argv and len(made) > 1:
        tile = 900
        sheet = Image.new("RGB", (tile * len(made) + 10 * (len(made) + 1),
                                  tile + 58), (20, 18, 16))
        d = ImageDraw.Draw(sheet)
        lf = ImageFont.truetype("segoeui.ttf", 26)
        names = {"a": "A - тёплая бронза, глубокая экструзия",
                 "b": "B - чеканка: узкий горячий блик",
                 "c": "C - старая бронза с патиной"}
        for i, (key, _, im) in enumerate(made):
            x = 10 + i * (tile + 10)
            sheet.paste(im.resize((tile, tile)), (x, 10))
            d.text((x + 4, tile + 20), names[key], font=lf, fill=(238, 232, 222))
        p = os.path.join(out_dir, "LIST-LOGOTIP.jpg")
        sheet.save(p, quality=92)
        print("лист: %s (%dx%d)" % (p, sheet.width, sheet.height))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
