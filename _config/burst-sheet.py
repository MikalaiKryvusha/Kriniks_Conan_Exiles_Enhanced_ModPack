# burst-sheet.py <dir> <out.webp> [first] [count] [cols] [tile_w] — contact sheet of capture-burst.ps1 frames, each labelled with its ms.
# Зачем (2026-10-26, KUMM bugs/64 п. 15–17): клип вкладок хаба смотрится глазом частыми кадрами — что появляется поздно, что дёргается.
# [NOT-TESTED]
import os
import sys
from PIL import Image, ImageDraw

d, out = sys.argv[1], sys.argv[2]
first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
count = int(sys.argv[4]) if len(sys.argv) > 4 else 30
cols = int(sys.argv[5]) if len(sys.argv) > 5 else 5
tw = int(sys.argv[6]) if len(sys.argv) > 6 else 384
files = sorted(f for f in os.listdir(d) if f.startswith("f_") and f.endswith(".jpg"))[first:first + count]
im0 = Image.open(os.path.join(d, files[0]))
th = int(im0.size[1] * tw / im0.size[0])
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tw, rows * th))
for i, f in enumerate(files):
    t = Image.open(os.path.join(d, f)).resize((tw, th))
    ImageDraw.Draw(t).text((4, 4), f[2:-4] + " ms", fill=(255, 255, 0))
    sheet.paste(t, ((i % cols) * tw, (i // cols) * th))
sheet.save(out, "WEBP", quality=90)
print(len(files), "frames ->", out)
