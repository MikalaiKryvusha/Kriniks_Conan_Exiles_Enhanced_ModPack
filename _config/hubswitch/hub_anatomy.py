"""hub_anatomy.py — what happens frame by frame in one hub tab-switch clip.

For every frame: time, mean luma (a dark wave = luma dip), mean |diff| to the previous frame, the blend coefficient alpha of the frame
between the FIRST frame (old page) and the LAST frame (new page, settled) with its residual (a crossfade = alpha walks 0..1 with a small
residual; a clean switch = alpha jumps 0 -> 1 in one frame), and the bounding box of the change vs the previous frame (in 3840x2160 px).
Also prints per-row-band luma for frames where luma dips, to see a band crawling.
    python hub_anatomy.py <clip.mp4> [--from N] [--to M]
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np

W, H = 960, 540
SCALE = 3840 // W
clip = sys.argv[1]
a0 = int(sys.argv[sys.argv.index('--from') + 1]) if '--from' in sys.argv else 0
a1 = int(sys.argv[sys.argv.index('--to') + 1]) if '--to' in sys.argv else 10 ** 9

raw = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', clip, '-fps_mode', 'passthrough', '-vf', 'scale=%d:%d,format=gray' % (W, H), '-f', 'rawvideo', '-'],
                     capture_output=True, check=True).stdout
F = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
n = len(F)
fps = 90.0
pts = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'frame=pts_time', '-of', 'csv=p=0', clip],
                     capture_output=True, text=True).stdout.split()
t = [float(x) for x in pts if x.strip()]
A, B = F[0], F[-1]
D = (B - A).ravel()
DD = float(D @ D) or 1.0
print('%s: %d frames, %.2f s' % (clip.split('/')[-1], n, t[-1] if t else n / fps))
print(' fr   t_ms  luma  dprev  alpha  resid  change-box(3840px)  px>24')
for k in range(max(1, a0), min(n, a1)):
    f = F[k]
    d = np.abs(f - F[k - 1])
    m = d > 24
    alpha = float((f - A).ravel() @ D) / DD
    resid = float(np.abs(f - (A + alpha * (B - A))).mean())
    box = '-'
    if m.sum() > 30:
        ys, xs = np.nonzero(m)
        box = '%d,%d..%d,%d' % (xs.min() * SCALE, ys.min() * SCALE, xs.max() * SCALE, ys.max() * SCALE)
    if d.mean() < 0.15 and k > a0 + 1 and '--all' not in sys.argv:
        continue  # still frame: skip
    print('%3d %6.0f %5.1f %6.2f %6.2f %6.2f  %-24s %d' % (k, (t[k] - t[0]) * 1000 if t else k * 1000 / fps, f.mean(), d.mean(), alpha, resid, box,
                                                       int(m.sum())))
