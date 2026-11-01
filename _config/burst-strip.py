# burst-strip.py <dir> <out.webp> <y0> <y1> [first] [count] — one horizontal band (rows y0..y1 of each frame) stacked frame under frame,
# labelled with ms: what appears, moves or vanishes in that band over time (KUMM bugs/64 п. 15–17, нижняя панель хаба).
# [NOT-TESTED]
import os
import sys
from PIL import Image, ImageDraw

d, out, y0, y1 = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
first = int(sys.argv[5]) if len(sys.argv) > 5 else 0
count = int(sys.argv[6]) if len(sys.argv) > 6 else 20
files = sorted(f for f in os.listdir(d) if f.startswith("f_") and f.endswith(".jpg"))[first:first + count]
w = Image.open(os.path.join(d, files[0])).size[0]
band = y1 - y0
sheet = Image.new("RGB", (w, band * len(files)))
for i, f in enumerate(files):
    t = Image.open(os.path.join(d, f)).crop((0, y0, w, y1))
    ImageDraw.Draw(t).text((w - 90, 2), f[2:-4] + " ms", fill=(255, 255, 0))
    sheet.paste(t, (0, i * band))
sheet.save(out, "WEBP", quality=90)
print(len(files), "bands ->", out)
