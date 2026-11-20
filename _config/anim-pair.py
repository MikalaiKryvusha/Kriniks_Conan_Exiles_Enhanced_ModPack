"""Side-by-side looping animated WebP of two bursts (left | right), cropped to a row band. Usage: anim_pair.py <dirL> <dirR> <y0> <y1> <out.webp>"""
import sys, glob, os
from PIL import Image

dl, dr, y0, y1, out = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
fl = sorted(glob.glob(os.path.join(dl, 'f_*.jpg')))
fr = sorted(glob.glob(os.path.join(dr, 'f_*.jpg')))
n = min(len(fl), len(fr))
frames = []
for a, b in zip(fl[:n], fr[:n]):
    A, B = Image.open(a).convert('RGB'), Image.open(b).convert('RGB')
    w, h = A.size
    box = (0, int(h * y0), w, int(h * y1))
    A, B = A.crop(box), B.crop(box)
    pair = Image.new('RGB', (w * 2 + 8, A.size[1]), (255, 255, 255))
    pair.paste(A, (0, 0)); pair.paste(B, (w + 8, 0))
    frames.append(pair)
frames[0].save(out, save_all=True, append_images=frames[1:], duration=125, loop=0, quality=90)
print('frames', n, 'size', frames[0].size, '->', out)
