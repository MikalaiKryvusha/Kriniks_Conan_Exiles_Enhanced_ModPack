"""shadow_flicker_metric.py — how much a screen region FLICKERS in a video (KUMM bug 67, palm leaf shadows).

Flicker = frame-to-frame jitter, not smooth motion: the temporal SECOND difference |f[t+1] - 2 f[t] + f[t-1]| per pixel (a smoothly swaying shadow
gives ~0, a shadow that jumps back and forth gives a lot), averaged over the region, then the median and p90 over frames. Also the first difference
for reference. Region in 3840x2160 coordinates.
    python shadow_flicker_metric.py <video> <x0> <y0> <x1> <y1>
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np

video = sys.argv[1]
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
w, h = (x1 - x0) // 2, (y1 - y0) // 2
# -fps_mode passthrough: the window capture (gfxcapture) writes variable-rate video — the game renders ~45 fps, not 60 (2026-11-07: 98 frames in 3 s);
# a constant-rate decode would invent repeats, and a repeat reads as d1 = 0 then a spike, i.e. as jitter.
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vf', 'crop=%d:%d:%d:%d,scale=%d:%d,format=gray' % (x1 - x0, y1 - y0, x0, y0, w, h),
                      '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'], capture_output=True, check=True).stdout
f = np.frombuffer(raw, np.uint8).reshape(-1, h, w).astype(np.float32)
# and repeats the capture itself delivered (no new game frame) — dropped the same way: keep a frame only if it differs from the last kept one
keep = [0]
for i in range(1, len(f)):
    if np.abs(f[i] - f[keep[-1]]).mean() > 0.02:
        keep.append(i)
f = f[keep]
d1 = np.abs(f[1:] - f[:-1]).mean(axis=(1, 2))
d2 = np.abs(f[2:] - 2 * f[1:-1] + f[:-2]).mean(axis=(1, 2))
print('unique frames %d  second-diff median %.3f p90 %.3f  |  first-diff median %.3f p90 %.3f' %
      (len(f), float(np.median(d2)), float(np.percentile(d2, 90)), float(np.median(d1)), float(np.percentile(d1, 90))))
