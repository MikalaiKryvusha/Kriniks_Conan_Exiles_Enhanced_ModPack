"""leaf_pop_finder.py — find where a leaf SHADOW on the ground pops off between two consecutive frames and show it with red arrows (KUMM bug 67;
[OWNER] 2026-11-07 15:59–16:01 «сделай его раскадровку и проанализируй ffmpeg» · «посмотри на кадры, где ЛИСТ тень листа ЕСТЬ» · «и где её НЕТ» ·
«выделишь два кадра, где ты увидил тень листа, и где её нет в следующем кадре, красными стрелками покажешь на такие места»).

A pop-off = a ground pixel that is dark (in shadow) in frame t, light in t+1 and dark again in t+2 — the leaf shadow vanished for one frame and came back,
which wind sway cannot do. Searched only on the ground (below SKY_CUT of the frame, outside the HUD), at half resolution.
Writes <out>_pair.webp: frame t | frame t+1 side by side (1920 wide each), red arrows at the strongest pop-off blobs, enlarged insets under them.
    python leaf_pop_finder.py <video> <out prefix> [thr=18]
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw

video, out = sys.argv[1], sys.argv[2]
THR = float(sys.argv[3]) if len(sys.argv) > 3 else 18.0
SKY_CUT, HUD_RIGHT, HUD_BOTTOM = 0.45, 0.78, 0.86
probe = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0', video],
                       capture_output=True, text=True, check=True).stdout.strip().split(',')
W, H = int(probe[0]) // 2, int(probe[1]) // 2
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vf', 'scale=%d:%d,format=rgb24' % (W, H), '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'],
                     capture_output=True, check=True).stdout
rgb = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)
g = rgb.astype(np.float32).mean(axis=3)
mask = np.zeros((H, W), bool)
mask[int(H * SKY_CUT):int(H * HUD_BOTTOM), :int(W * HUD_RIGHT)] = True
# pop-off at t: dark at t, light at t+1, dark at t+2
off = (g[1:-1] - g[:-2] > THR) & (g[1:-1] - g[2:] > THR) & mask   # index k -> the LIGHT frame is k+1, the shadow frame k
score = off.reshape(off.shape[0], -1).sum(axis=1)
k = int(score.argmax())
t = k                      # frame with the shadow
print('frames %d  pop-off pixels per frame: max %d at frame %d -> %d (median %d)' % (len(g), int(score[k]), t, t + 1, int(np.median(score))))
# blobs: 24-px cells with the most pop-off pixels in that frame
cell = 24
o = off[k]
cells = []
for y in range(0, H - cell, cell):
    for x in range(0, W - cell, cell):
        s = int(o[y:y + cell, x:x + cell].sum())
        if s > 6:
            cells.append((s, x + cell // 2, y + cell // 2))
cells.sort(reverse=True)
picked = []
for s, x, y in cells:
    if all(abs(x - px) > 120 or abs(y - py) > 120 for _, px, py in picked):
        picked.append((s, x, y))
    if len(picked) == 3:
        break
print('pop-off places (half-res x,y, pixels):', [(x, y, s) for s, x, y in picked])
A = Image.fromarray(rgb[t].copy())
Bm = Image.fromarray(rgb[t + 1].copy())
INS, Z = 64, 4
canvas = Image.new('RGB', (W * 2, H + INS * Z + 20), (20, 20, 20))
canvas.paste(A, (0, 0))
canvas.paste(Bm, (W, 0))
d = ImageDraw.Draw(canvas)
for i, (s, x, y) in enumerate(picked):
    for ox in (0, W):
        d.line([(ox + x - 110, y - 110), (ox + x - 14, y - 14)], fill=(255, 0, 0), width=7)
        d.polygon([(ox + x - 6, y - 6), (ox + x - 34, y - 14), (ox + x - 14, y - 34)], fill=(255, 0, 0))
        d.rectangle([ox + x - INS // 2, y - INS // 2, ox + x + INS // 2, y + INS // 2], outline=(255, 0, 0), width=3)
    for j, img in enumerate((A, Bm)):
        crop = img.crop((x - INS // 2, y - INS // 2, x + INS // 2, y + INS // 2)).resize((INS * Z, INS * Z), Image.NEAREST)
        px = j * W + i * (INS * Z + 20) + 10
        canvas.paste(crop, (px, H + 10))
        d.rectangle([px, H + 10, px + INS * Z, H + 10 + INS * Z], outline=(255, 0, 0), width=3)
d.text((20, 20), 'frame %d: shadow of the leaf IS here' % t, fill=(255, 255, 0))
d.text((W + 20, 20), 'frame %d (next): the shadow is GONE' % (t + 1), fill=(255, 255, 0))
canvas.save(out + '_pair.webp', quality=90)
print('written', out + '_pair.webp')
