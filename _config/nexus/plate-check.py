"""plate-check.py -- the caption plate must be THE SAME on every frame.

@guard plate-uniform
THREAT:         the caption plate sized per caption instead of per series, so
                the page shows a lower-third that grows and shrinks from
                picture to picture. Field: the owner spotted it himself --
                "на разных картинках размер плашки разный... ЭТО БАГ".
PROVED-AGAINST: the pre-fix behaviour, reproduced by measuring every caption's
                own plate: widths ran 1134..1525 px on a 3840 frame, a spread
                of 391 px (10.2 % of the width). The guard reds on it.
GAP:            two things it does not see. It measures the DARK PLATE, not
                the words -- a caption overflowing its plate would still pass.
                And its verdict ignores the LEFT edge: that edge is a constant
                in the code, while its measured position wanders with the
                background behind the blur (25 px on the fixed series against
                5 px on the right edge).
ON-REAL-PATH:   run against the shipped set in nexus-screenshots/podpisannye-*
                on 2026-09-10, green at 5 px of jitter.

WHY A MEASUREMENT AND NOT A READ OF THE CODE. The plate is a blurred edge over
sand of varying brightness, so its measured left edge wanders a few pixels by
background alone. The check therefore allows a small tolerance and compares
what a viewer would see, not what the source intends.

    python plate-check.py <raw_dir> <captioned_dir> [--tol 12]
"""

import os
import sys

from PIL import Image, ImageChops

# Calibrated, not guessed. Measured over the shipped series at four
# thresholds: at 40 the whole-frame diff is dominated by JPEG artefacts in
# detailed frames and the left edge wanders 1061 px; at 70 the same series
# gives 1 px on the left, 3 on the right, 1 at the bottom and 27 at the top --
# the top being the soft edge of the name's shadow over backgrounds of
# different brightness. Hence the tolerance: wide enough for a blurred edge,
# an order of magnitude tighter than the defect it exists for (390 px).
THRESHOLD = 70
DEFAULT_TOL = 30


def footprint(raw, cap):
    """The box the caption occupies in the frame.

    The WHOLE frame, not a half. The first version looked only at the bottom,
    where the block lived then; the owner moved it to the top right corner and
    the guard came back with None instead of a box. A guard that assumes where
    its subject lives stops guarding the moment the subject moves."""
    d = ImageChops.difference(raw, cap).convert("L")
    return d.point(lambda v: 255 if v > THRESHOLD else 0).getbbox()


def main(argv):
    raw_dir, cap_dir = argv[1], argv[2]
    tol = int(argv[argv.index("--tol") + 1]) if "--tol" in argv else DEFAULT_TOL

    boxes = {}
    for name in sorted(os.listdir(cap_dir)):
        if not name.lower().endswith(".jpg"):
            continue
        key = os.path.splitext(name)[0]
        raw_path = os.path.join(raw_dir, key + ".png")
        if not os.path.exists(raw_path):
            continue
        with Image.open(raw_path) as raw, \
             Image.open(os.path.join(cap_dir, name)) as cap:
            boxes[key] = footprint(raw.convert("RGB"), cap.convert("RGB"))

    if len(boxes) < 2:
        print("нечего сравнивать: найдено пар кадр/подпись — %d" % len(boxes))
        return 1

    def spread(vals):
        return max(vals) - min(vals)

    widths = {k: b[2] - b[0] for k, b in boxes.items()}
    for k in sorted(boxes):
        b = boxes[k]
        print("%-18s x %4d..%4d  y %4d..%4d   %d x %d"
              % (k, b[0], b[2], b[1], b[3], widths[k], b[3] - b[1]))

    # THE VERDICT IS TAKEN ON THE PLATE'S WIDTH AND ON ALL FOUR EDGES, with a
    # tolerance sized for a blurred edge. Every edge of the plate ends in a
    # gradient, and a gradient crosses the threshold sooner over a dark
    # background than over a bright one -- so a few tens of pixels of wander
    # are the instrument, not the plate. What the guard exists to catch is an
    # order of magnitude larger: the defect it was proved against moved the
    # right edge by 390 px.
    right = spread([b[2] for b in boxes.values()])
    top = spread([b[1] for b in boxes.values()])
    bottom = spread([b[3] for b in boxes.values()])
    left = spread([b[0] for b in boxes.values()])
    width = spread([b[2] - b[0] for b in boxes.values()])

    print()
    print("кадров: %d · ширина %d px · левый %d · правый %d · верх %d · низ %d"
          % (len(boxes), width, left, right, top, bottom))

    if max(width, left, right, top, bottom) > tol:
        wide = max(widths, key=lambda k: widths[k])
        thin = min(widths, key=lambda k: widths[k])
        print("КРАСНО: плашка разного размера (допуск %d px). "
              "Шире всех %s (%d), уже всех %s (%d)."
              % (tol, wide, widths[wide], thin, widths[thin]))
        return 1
    print("ЗЕЛЕНО: плашка одинаковая на всех кадрах (допуск %d px)" % tol)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
