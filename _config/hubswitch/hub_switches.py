"""hub_switches.py — every hub tab switch in one long screen recording: how many frames the change takes, whether two pages are blended,
whether the luma walks (a wave), and what changes LATE (up to --window s after the switch).

    python hub_switches.py <rec.mp4> [--spike 4] [--noise 0.35] [--window 4.5] [--skip-top 0]

Frames are taken as recorded (-fps_mode passthrough, real timestamps), grey 960x540.
switch   = a frame whose mean |diff| to the previous frame >= spike.
change   = frames from the switch on while mean |diff| > noise (gaps of 1 still frame allowed).
blend    = transition frames whose coefficient alpha between the frame before the switch (A) and the settled frame (B) lies in 0.1..0.9.
late     = frames after the change, within the window, with > 300 px changed by > 24 levels (box printed in 3840x2160 px).
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np

W, H = 960, 540
SC = 3840 // W


def arg(name, default):
    return float(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


clip = sys.argv[1]
spike, noise, window, skip_top = arg('--spike', 4.0), arg('--noise', 0.35), arg('--window', 4.5), int(arg('--skip-top', 0))
raw = subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-i', clip, '-fps_mode', 'passthrough', '-vf', 'scale=%d:%d,format=gray' % (W, H),
                      '-f', 'rawvideo', '-'], capture_output=True, check=True).stdout
F = np.frombuffer(raw, np.uint8).reshape(-1, H, W)
pts = [float(x) for x in subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'frame=pts_time', '-of', 'csv=p=0',
                                         clip], capture_output=True, text=True).stdout.split() if x.strip()]
n = min(len(F), len(pts))
print('%s: %d frames, %.1f s, %.0f fps' % (clip.split('/')[-1], n, pts[n - 1] - pts[0], (n - 1) / (pts[n - 1] - pts[0])))
md = np.zeros(n)
for k in range(1, n):
    md[k] = np.abs(F[k].astype(np.int16) - F[k - 1]).mean()

k = 1
while k < n:
    if md[k] < spike:
        k += 1
        continue
    s = k
    e = k
    j = k + 1
    while j < n and (md[j] > noise or (j + 1 < n and md[j + 1] > noise and md[j] > noise * 0.5)):
        e = j
        j += 1
    A = F[s - 1].astype(np.float32)
    bi = min(e + 10, n - 1)
    B = F[bi].astype(np.float32)
    D = (B - A).ravel()
    DD = float(D @ D) or 1.0
    alphas = [float(((F[i].astype(np.float32) - A).ravel() @ D) / DD) for i in range(s, e + 1)]
    lumas = [float(F[i].mean()) for i in range(s - 1, e + 2)]
    blend = sum(1 for a in alphas if 0.1 < a < 0.9)
    late = []
    t_end = pts[s] + window
    i = e + 1
    while i < n and pts[i] <= t_end:
        if md[i] >= spike:
            break  # the next switch
        d = np.abs(F[i].astype(np.int16) - F[i - 1])
        if skip_top:
            d[:skip_top // SC] = 0
        m = d > 24
        if m.sum() > 300:
            ys, xs = np.nonzero(m)
            late.append('+%.0fms %dpx (%d,%d..%d,%d)' % ((pts[i] - pts[s]) * 1000, int(m.sum()), xs.min() * SC, ys.min() * SC, xs.max() * SC, ys.max() * SC))
        i += 1
    print('switch @%.3fs frames %d..%d = %d frame(s) %.0f ms | blend frames %d | alpha %s | luma %s | late %d %s' % (
        pts[s] - pts[0], s, e, e - s + 1, (pts[e] - pts[s]) * 1000 + 1000 / 90, blend, ' '.join('%.2f' % a for a in alphas[:8]),
        ' '.join('%.0f' % l for l in lumas[:10]), len(late), '; '.join(late[:6])))
    k = max(i, e + 1)
