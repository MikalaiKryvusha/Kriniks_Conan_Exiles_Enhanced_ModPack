"""frame_settle.py — after every big change of the screen (a tab switch), how long until the picture stops changing, and what changes LATE.

Reads a screen video (60 fps desktop capture), downsamples to grey 480x270, and for each switch (a frame whose difference from the previous one is a
spike) prints: the frame and time of the switch, how many frames later the picture still changed (above a noise floor), and the boxes (in 3840x2160
coordinates) of the late changes. A late change 2+ frames after a switch is a jump or a late element (KUMM bug 64 items 15/17: «хаб вздрагивает»).
    python frame_settle.py <video.mp4> [--noise 1.5] [--spike 8]
[NOT-TESTED]
"""
import subprocess
import sys

import numpy as np

W, H = 480, 270
video = sys.argv[1]
noise = float(sys.argv[sys.argv.index('--noise') + 1]) if '--noise' in sys.argv else 1.5
spike = float(sys.argv[sys.argv.index('--spike') + 1]) if '--spike' in sys.argv else 8.0

raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', video, '-vf', 'scale=%d:%d,format=gray' % (W, H), '-f', 'rawvideo', '-'],
                     capture_output=True, check=True).stdout
frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.int16)
fps_out = subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=avg_frame_rate', '-of', 'csv=p=0', video],
                         capture_output=True, text=True).stdout.strip()
num, den = (int(x) for x in fps_out.split('/'))
fps = num / den
diffs = np.abs(frames[1:] - frames[:-1])
mean = diffs.mean(axis=(1, 2))
print('frames %d, fps %.1f, mean diff median %.2f' % (len(frames), fps, float(np.median(mean))))

i = 0
while i < len(mean):
    if mean[i] >= spike:
        start = i
        j = i + 1
        while j < len(mean) and mean[j] >= spike:  # the switch itself may take a few frames (crossfade)
            j += 1
        late = []
        for k in range(j, min(j + int(fps * 1.5), len(mean))):  # look 1.5 s after the switch settles
            d = diffs[k]
            m = d > 24
            if m.sum() > 40 and mean[k] >= noise * 0.1:
                ys, xs = np.nonzero(m)
                late.append((k - j + 1, int(m.sum()), (int(xs.min() * 8), int(ys.min() * 8), int(xs.max() * 8), int(ys.max() * 8))))
        print('switch at frame %d (%.2f s), %d frame(s) of change; late changes: %d' % (start + 1, (start + 1) / fps, j - start, len(late)))
        for l in late[:8]:
            print('   +%d frames (%.0f ms): %d px, box %s' % (l[0], l[0] * 1000 / fps, l[1], l[2]))
        i = j
    i += 1
