"""Flicker of a still view: mean absolute frame-to-frame difference (0-255) in a box, over a burst of frames (capture-burst.ps1).
Usage: python flicker-metric.py <dir with burst frames> <y0> <y1> [<x0> <x1>]   (fractions 0..1 of the height / width; x defaults to the whole width)
Also writes <dir>/strip.webp: the box of the first 8 frames stacked, to SEE what blinks.
Why (KUMM bug 89, 2026-11-09): the water reflection blinks; a frame series measures it without the owner's screen. The box — the owner points at one spot
(17:34: the far water where two spires reflect).
[TESTED: 2026-11-09 · run on river_bend bursts, numbers in KUMM bugs/89]"""
import sys, os, glob
from PIL import Image, ImageChops, ImageStat

d, y0, y1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
x0, x1 = (float(sys.argv[4]), float(sys.argv[5])) if len(sys.argv) > 5 else (0.0, 1.0)
files = sorted(f for f in glob.glob(os.path.join(d, '*')) if f.lower().endswith(('.jpg', '.png', '.webp')) and 'strip' not in f)
imgs = []
for f in files:
    im = Image.open(f).convert('L')
    w, h = im.size
    imgs.append(im.crop((int(w * x0), int(h * y0), int(w * x1), int(h * y1))))
diffs = [ImageStat.Stat(ImageChops.difference(a, b)).mean[0] for a, b in zip(imgs, imgs[1:])]
print(f'frames {len(imgs)} box x{x0}-{x1} y{y0}-{y1} mean_abs_diff {sum(diffs) / len(diffs):.2f} min {min(diffs):.2f} max {max(diffs):.2f}')
cw = 1280
ch = max(1, int(imgs[0].size[1] * cw / imgs[0].size[0]))
strip = Image.new('L', (cw, ch * min(len(imgs), 8)))
for i, im in enumerate(imgs[:8]):
    strip.paste(im.resize((cw, ch)), (0, i * ch))
strip.save(os.path.join(d, 'strip.webp'), quality=90)
