"""shadow_pop_map.py — a MAP of where shadows blink across the whole frame (KUMM bug 67; [OWNER] 2026-11-07 16:07 «видишь, что по ВСЕМУ пятну теневому то
тут то там мерцает?»). A blink = a pixel whose brightness jumps by > THR and back by > THR on the next frame (either way: shadow→light→shadow or the
reverse). Counts blinks per pixel over the clip (half resolution) and paints them red over a middle frame; prints the blink count inside the ground area.
    python shadow_pop_map.py <video> <out.webp> [thr=14] [box=x0,y0,x1,y1]
box — the counted area in 1920×1080 pixels (drawn as a white frame on the map). Without it — the old fixed "ground area"; 2026-11-07 16:4x that area held
the palm crown itself (the owner's low camera under the tree), so the wind on the visible fronds swamped the shadow count — pick a box of bare sand.
[TESTED: 2026-11-07 · bare-sand box vs the old area on the c1 series, frames read]
"""
import os
import subprocess
import sys

import numpy as np
from PIL import Image

video, out = sys.argv[1], sys.argv[2]
THR = float(sys.argv[3]) if len(sys.argv) > 3 else 14.0
W, H = 1920, 1080
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vf', 'scale=%d:%d,format=rgb24' % (W, H), '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'],
                     capture_output=True, check=True).stdout
rgb = np.frombuffer(raw, np.uint8).reshape(-1, H, W, 3)
g = rgb.astype(np.float32).mean(axis=3)
d = np.diff(g, axis=0)
blink = (np.abs(d[:-1]) > THR) & (np.abs(d[1:]) > THR) & (np.sign(d[:-1]) != np.sign(d[1:]))
cnt = blink.sum(axis=0)
if len(sys.argv) > 4:
    x0, y0, x1, y1 = (int(v) for v in sys.argv[4].split(','))
else:
    x0, y0, x1, y1 = 0, int(H * 0.45), int(W * 0.78), int(H * 0.86)
ground = cnt[y0:y1, x0:x1]
print('frames %d  blinking pixels in the box: %d (%.2f %%), blink events %d' %
      (len(g), int((ground > 0).sum()), 100.0 * (ground > 0).mean(), int(ground.sum())))
base = rgb[len(rgb) // 2].astype(np.float32) * 0.6
m = np.clip(cnt * 120, 0, 255).astype(np.float32)
base[..., 0] = np.maximum(base[..., 0], m)
base[..., 1] = np.where(m > 0, 0, base[..., 1])
base[..., 2] = np.where(m > 0, 0, base[..., 2])
base[y0:y1, [x0, x1 - 1]] = 255
base[[y0, y1 - 1], x0:x1] = 255
Image.fromarray(base.astype(np.uint8)).save(out, quality=90)
