"""sign_style.py -- the ONE place the caption's look lives.

WHY A SEPARATE MODULE. The style used to be copied into caption.py and
variants.py, and the two drifted apart the moment one was edited. One fact,
one place (DRY): the sheet the owner picks from and the frames that ship are
drawn by the SAME function, so what he approves is what he gets.

THE STYLE IS MEASURED, NOT REMEMBERED. Read off the old run's surviving
frames (1920x1080, _staryj-zahod-0909/) with ImageMagick, row by row:

    left margin      62 px  -> 3.25% of the width
    accent rule      y 850, 127 px wide, 4 px thick, green #3B9361
    headline         cap ~34 px -> 3.15% of the height, semibold
    subline          cap ~21 px -> 1.95% of the height, regular
    second language  gold #ECC55D (most saturated pixel of that line)
    text white       #EDEEF2 (cool, not pure white)
    baselines        918 / 951 / 1008 / 1042 -> 33 px inside a language
                     block, 57 px between the two blocks
    bottom margin    34 px -> 3.15% of the height

THREE CORRECTIONS THE OWNER GAVE ON TOP OF THAT STYLE:
  * the shadow covers THE AREA WHERE THE TEXT IS AND NO WIDER -- his words,
    2026-09-10. Not a band across the frame, not a wash that keeps going to
    the right past the words.
  * both languages carry EQUAL weight -- same size, one block above the
    other, not a title with a small translation under it. (The old run had
    English big and Russian small; that is the one thing changed here.)
  * no camera numbers in the caption. They live in shots.csv beside the
    frames, for whoever wants to reproduce a shot.

[NOT-TESTED] at birth; verified by the agent's own eye on a rendered sheet
before anything is shown to the owner (EXP-0081: an artifact made for the eye
is checked by the eye, and by the AGENT'S eye first).
"""

from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageFilter

# --- the measured constants, all as fractions of the frame ----------------
# These are the OLD RUN's numbers, kept as measured so the source of the style
# stays readable. What the owner tunes are the two dials below them.
LEFT_FRAC = 0.0325      # left margin, share of width
BOTTOM_FRAC = 0.0315    # gap under the last line, share of height
HEAD_CAP_FRAC = 0.0315  # cap height of a headline, share of height
IN_BLOCK_FRAC = 0.0350  # headline -> its subline
BETWEEN_FRAC = 0.0530   # one language block -> the next
RULE_GAP_FRAC = 0.0250  # accent rule -> the first headline
RULE_W_FRAC = 0.0660    # accent rule width, share of width
RULE_H_FRAC = 0.0037    # accent rule thickness, share of height
PAD_TOP_FRAC = 0.0120   # shadow padding above the rule, share of height
PAD_BOTTOM_FRAC = 0.0140
PAD_LEFT_FRAC = 0.0100  # shares of width
PAD_RIGHT_FRAC = 0.0120

# --- the two dials the owner turns ----------------------------------------
# SCALE shrinks or grows the WHOLE caption -- text, spacing, rule and the
# shadow that follows them -- in one number. The margins from the frame edge
# are deliberately NOT scaled: the caption sits where it sits, it just gets
# smaller. Owner, 2026-09-10: "всю плашку меньше на 20 процентов", and then
# another 20 % on top of that -- 0.80 * 0.80.
SCALE = 0.64

# How tall the explaining line is relative to its headline. The old run had
# 0.62 and the owner asked twice for a bigger explaining line, so it does NOT
# ride down with SCALE -- shrinking the block would otherwise hand back
# exactly the small line he rejected.
SUB_OF_HEAD = 0.88

# The mod's name, small, in the top-left corner (owner, 2026-09-10, in place
# of the THIS MOD badge). It sits ABOVE the game's compass: the top strip of
# a Conan frame is clear until about 2 % of the height, and these two numbers
# keep the line inside it.
CORNER_CAP_FRAC = 0.0180     # owner asked for it bigger, 2026-09-10
CORNER_TOP_FRAC = 0.0075     # used only when the line is put in the corner
CORNER_TRACK_FRAC = 0.0022   # a little tracking, share of width
ABOVE_GAP_FRAC = 0.0150      # name -> the plate beneath it

# The corner line is BRONZE -- the same metal as the logo's chosen variant B,
# so the frames and the logo read as kin. A flat fill would look painted, so
# the ramp is the logo's: a hot highlight along the top, then a fast fall.
# The logo's ramp starts almost white, which is right on a 4096 title and
# wrong here: at corner size that highlight is most of the letter, and against
# a bright sky the top of every glyph melts away. So the metal starts warm.
CORNER_BRONZE = [(0.00, (250, 226, 178)), (0.22, (222, 168, 98)),
                 (0.52, (176, 116, 50)), (0.78, (206, 146, 74)),
                 (1.00, (108, 64, 24))]

WHITE = (237, 238, 242)
GOLD = (236, 197, 93)
GREEN = (59, 147, 97)   # the old run's colour for a modded frame
RED = (176, 58, 46)     # the old run's colour for the vanilla frame
# The rule the owner asked for on 2026-09-10: a SOFT red, warm rather than
# alarm-coloured, so it sits with the sand instead of cutting across it. It
# is now the accent on every frame -- which is why the corner badge, not the
# rule, is what tells a modded frame from the vanilla one.
SOFT_RED = (196, 87, 74)

SHADOW_RGB = (5, 5, 7)
SHADOW_ALPHA = 210      # near black, as measured (luminance 10-14)
SHADOW_BLUR_FRAC = 0.0060   # softness; also how far the wash may spill out


def _font(size, bold):
    """Segoe UI Semibold for headlines, Segoe UI for sublines.

    The old captions read heavier than a regular weight, hence semibold
    first. Every name is tried so the script also runs on a machine without
    the Segoe family."""
    names = (("seguisb.ttf", "segoeuib.ttf", "arialbd.ttf")
             if bold else ("segoeui.ttf", "arial.ttf"))
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def _fit(cap_px, bold):
    """Solve for the pixel size whose CAP HEIGHT is cap_px.

    Font size and cap height are different numbers -- guessing one for the
    other is what once shipped a caption at half the intended size."""
    size = max(8, int(cap_px * 1.4))
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    f = _font(size, bold)
    for _ in range(14):
        box = probe.textbbox((0, 0), "HНg", font=f)
        cap = box[3] - box[1]
        if abs(cap - cap_px) <= 1:
            break
        size = max(8, int(round(size * cap_px / max(cap, 1))))
        f = _font(size, bold)
    return f


def _layout(W, H, blocks, sublines):
    """Place the caption BY BASELINE PITCH, the way the old run was set.

    The measured 33 px and 57 px are baseline-to-baseline distances, not empty
    space between line boxes. Reading them as gaps -- which the first attempt
    did -- spaces the block out to about double, and the caption goes airy
    where the old one was tight. Returns the lines with their baselines, the
    left margin and the block's outer box."""
    head_cap = H * HEAD_CAP_FRAC * SCALE
    head_f = _fit(head_cap, True)
    sub_f = _fit(head_cap * SUB_OF_HEAD, False)

    items = []                       # (text, font, colour, pitch before it)
    for i, (head, sub, colour) in enumerate(blocks):
        items.append((head, head_f, colour,
                      BETWEEN_FRAC * SCALE if i else 0.0))
        if sublines and sub:
            items.append((sub, sub_f, WHITE, IN_BLOCK_FRAC * SCALE))

    rel = [0.0]
    for _, _, _, pitch in items[1:]:
        rel.append(rel[-1] + H * pitch)

    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    left = int(W * LEFT_FRAC)
    # the last line's descender must land on the bottom margin
    last_bottom = probe.textbbox((0, 0), items[-1][0], font=items[-1][1],
                                 anchor="ls")[3]
    first = H - int(H * BOTTOM_FRAC) - last_bottom - rel[-1]
    baselines = [first + r for r in rel]

    boxes = [probe.textbbox((left, b), t, font=f, anchor="ls")
             for (t, f, _, _), b in zip(items, baselines)]
    box = (min(b[0] for b in boxes), min(b[1] for b in boxes),
           max(b[2] for b in boxes), max(b[3] for b in boxes))
    return items, baselines, left, box


def _plate_of(W, H, box, rule_top, rule):
    """The shadow rectangle a caption needs: its text, padded.

    Padding follows SCALE like everything else, so the plate keeps its
    proportions when the owner turns the block up or down."""
    y0 = (rule_top if rule else box[1]) - int(H * PAD_TOP_FRAC * SCALE)
    y1 = min(H, box[3] + int(H * PAD_BOTTOM_FRAC * SCALE))
    x0 = max(0, box[0] - int(W * PAD_LEFT_FRAC * SCALE))
    x1 = min(W, box[2] + int(W * PAD_RIGHT_FRAC * SCALE))
    return (x0, y0, x1, y1)


def measure(W, H, blocks, sublines=True, rule=True):
    """What plate THIS caption would need, without drawing anything.

    Exists because the plate must be IDENTICAL on every frame of a series
    (the owner, 2026-09-10: "на разных картинках размер плашки разный, это
    баг"). Texts differ in length, so the SERIES decides the size: the caller
    measures every caption, takes the union, and hands that one rectangle to
    every draw()."""
    items, baselines, left, box = _layout(W, H, blocks, sublines)
    rule_h = max(2, int(H * RULE_H_FRAC * SCALE))
    rule_top = box[1] - int(H * RULE_GAP_FRAC * SCALE) - rule_h
    return _plate_of(W, H, box, rule_top, rule)


def union(boxes):
    """The smallest rectangle containing all of them -- the series' plate."""
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def draw(im, blocks, accent=GREEN, sublines=True, rule=True, plate=None,
         offset=(0, 0)):
    """Bake the caption into im (modified in place). Returns the shadow box.

    blocks: [(headline, subline, colour), ...] -- one entry per language,
    both at the SAME size, which is the owner's "equal weight".
    accent: the rule's colour.
    plate: the shadow rectangle to use. Pass the SERIES' rectangle (see
    measure/union) so every frame carries the same plate; leave it None and
    the plate hugs this one caption, which is what varied between frames.
    offset: move the WHOLE block -- plate, rule and every line -- by (dx, dy).
    The block is laid out once, in the bottom-left corner it was designed for,
    and then carried where the owner wants it. Re-deriving the layout for each
    corner would give four ways for the series plate to stop being one."""
    dx, dy = int(offset[0]), int(offset[1])
    W, H = im.size
    items, baselines, left, box = _layout(W, H, blocks, sublines)

    rule_h = max(2, int(H * RULE_H_FRAC * SCALE))
    rule_top = box[1] - int(H * RULE_GAP_FRAC * SCALE) - rule_h

    x0, y0, x1, y1 = plate or _plate_of(W, H, box, rule_top, rule)
    x0, y0, x1, y1 = x0 + dx, y0 + dy, x1 + dx, y1 + dy
    rule_top += dy
    blur = max(2, int(W * SHADOW_BLUR_FRAC * SCALE))

    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rectangle([x0, y0, x1, y1], fill=SHADOW_ALPHA)
    mask = mask.filter(ImageFilter.GaussianBlur(blur))
    dark = Image.new("RGBA", (W, H), SHADOW_RGB + (255,))
    dark.putalpha(mask)
    im.paste(Image.alpha_composite(im.convert("RGBA"), dark).convert("RGB"),
             (0, 0))

    d = ImageDraw.Draw(im)
    if rule:
        d.rectangle([left + dx, rule_top, left + dx + int(W * RULE_W_FRAC * SCALE),
                     rule_top + rule_h], fill=accent)

    for (text, f, colour, _), baseline in zip(items, baselines):
        d.text((left + dx, baseline + dy), text, font=f, fill=colour,
               anchor="ls")

    return (x0, y0, x1, y1)


def _ramp(width, top, height, stops):
    """A vertical colour ramp, as a full-canvas RGB image."""
    strip = Image.new("RGB", (1, max(1, height)))
    px = strip.load()
    for y in range(max(1, height)):
        t = y / max(1, height - 1)
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
    return strip.resize((width, max(1, height)))


def corner_box(size, text, above=None):
    """Where the corner line will land, without drawing it.

    Needed so the caption's plate can be grown to cover the name: bronze on
    sand is unreadable however heavy its own shadow, and the owner said so
    twice. A dark ground under the metal solves what more shadow could not."""
    W, H = size
    f = _fit(H * CORNER_CAP_FRAC, True)
    track = W * CORNER_TRACK_FRAC
    left = int(W * LEFT_FRAC)
    if above:
        baseline = above[1] - int(H * ABOVE_GAP_FRAC)
    else:
        baseline = int(H * CORNER_TOP_FRAC) + int(H * CORNER_CAP_FRAC)
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    w = (sum(probe.textlength(ch, font=f) for ch in text)
         + track * max(0, len(text) - 1))
    box = probe.textbbox((left, baseline), text, font=f, anchor="ls")
    return (left, box[1], int(left + w), box[3])


def corner(im, text, stops=None, above=None, on_plate=False,
           offset=(0, 0)):
    """The mod's name in bronze, spaced, standing on its own heavy shadow.

    `above` is the caption's plate: given it, the name sits DIRECTLY ON TOP of
    that plate (the owner's placement, 2026-09-10) and the two read as one
    block. Without it the name goes to the top-left corner, which is where it
    lived first.

    No rectangular plate under the name in either position -- what carries the
    letters over sky, sand or a piece of the game's interface is a shadow that
    FOLLOWS them: one tight copy offset down-right to lift the metal off the
    picture, one wide and heavy dropped low to pool underneath."""
    W, H = im.size
    stops = stops or CORNER_BRONZE
    f = _fit(H * CORNER_CAP_FRAC, True)
    track = W * CORNER_TRACK_FRAC
    left = int(W * LEFT_FRAC)
    if above:
        baseline = above[1] - int(H * ABOVE_GAP_FRAC)
    else:
        baseline = int(H * CORNER_TOP_FRAC) + int(H * CORNER_CAP_FRAC)

    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    cx = float(left + int(offset[0]))
    baseline += int(offset[1])
    for ch in text:
        d.text((cx, baseline), ch, font=f, fill=255, anchor="ls")
        cx += d.textlength(ch, font=f) + track

    # Two shadows, not one: a tight one that lifts the metal off the picture,
    # and a wide soft one that darkens whatever lies behind. When the line
    # stands ON the caption's plate (on_plate) the wide one is dropped: the
    # plate already is the dark ground, and piling a second wash on top only
    # muddies the metal.
    # NO OFFSET IN X OR Y (the owner, 2026-09-10). Both copies sit exactly on
    # the letters, so the shadow reads as the letters' own weight rather than
    # as a light source somewhere off to one side. Heaviness comes from
    # density and spread instead -- which is the only place left for it once
    # the offsets are gone.
    blur = max(4, int(H * 0.0080))
    tight = mask.filter(ImageFilter.GaussianBlur(blur))
    glow = tight.point(lambda v: min(255, int(v * 2.6)))
    if not on_plate:
        wide = mask.filter(ImageFilter.GaussianBlur(blur * 7))
        glow = ImageChops.lighter(
            glow, wide.point(lambda v: min(255, int(v * 6.0))))
    dark = Image.new("RGBA", (W, H), SHADOW_RGB + (255,))
    dark.putalpha(glow)
    im.paste(Image.alpha_composite(im.convert("RGBA"), dark).convert("RGB"),
             (0, 0))

    box = mask.getbbox()
    metal = Image.new("RGB", (W, H), stops[-1][1])
    if box:
        metal.paste(_ramp(W, box[1], box[3] - box[1], stops), (0, box[1]))
    lit = metal.convert("RGBA")
    lit.putalpha(mask)
    im.paste(Image.alpha_composite(im.convert("RGBA"), lit).convert("RGB"),
             (0, 0))


def badge(im, text, colour=GREEN):
    """The corner label of the old run -- which frame is the mod, which is
    vanilla. A label, not prose, so it stays short and English."""
    W, H = im.size
    f = _fit(H * 0.0175, True)
    spaced = " ".join(text.upper())
    d = ImageDraw.Draw(im)
    box = d.textbbox((0, 0), spaced, font=f)
    pad_x, pad_y = int(W * 0.010), int(H * 0.013)
    w = box[2] - box[0] + pad_x * 2
    h = box[3] - box[1] + pad_y * 2
    d.rectangle([0, 0, w, h], fill=colour)
    d.text((pad_x - box[0], pad_y - box[1]), spaced, font=f,
           fill=(255, 255, 255))
