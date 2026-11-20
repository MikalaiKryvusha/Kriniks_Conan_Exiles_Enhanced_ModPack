"""sun_disk_track.py — does the SUN DISK move smoothly or in steps? (KUMM bug 67: the light may step, the visible sun must not)

Tracks the centroid of the brightest pixels in a box around the sun, frame by frame (variable-rate decode, repeats dropped), and prints the
path: total travel, the per-frame step distribution, and how many frames the disk stood still (< 0.05 px). A smooth disk moves a little every
frame; a disk tied to a stepping light stands still, then jumps.
    python sun_disk_track.py <video> <x0> <y0> <x1> <y1>      (box in the video's pixels)
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np

video = sys.argv[1]
x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
w, h = x1 - x0, y1 - y0
raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vf', 'crop=%d:%d:%d:%d,format=gray' % (w, h, x0, y0),
                      '-fps_mode', 'passthrough', '-f', 'rawvideo', '-'], capture_output=True, check=True).stdout
f = np.frombuffer(raw, np.uint8).reshape(-1, h, w).astype(np.float32)
pts = []
for fr in f:
    thr = fr.max() - 3          # the disk core: within 3 levels of the brightest pixel
    ys, xs = np.nonzero(fr >= thr)
    pts.append((xs.mean(), ys.mean()))
p = np.array(pts)
keep = [0]
for i in range(1, len(p)):     # drop repeats of the same rendered frame
    if np.abs(f[i] - f[keep[-1]]).mean() > 0.02:
        keep.append(i)
p = p[keep]
step = np.hypot(np.diff(p[:, 0]), np.diff(p[:, 1]))
print('frames %d  travel %.1f px  step median %.3f p99 %.3f max %.2f  still frames %d of %d' %
      (len(p), float(np.hypot(*(p[-1] - p[0]))), float(np.median(step)), float(np.percentile(step, 99)), float(step.max()),
       int((step < 0.05).sum()), len(step)))
