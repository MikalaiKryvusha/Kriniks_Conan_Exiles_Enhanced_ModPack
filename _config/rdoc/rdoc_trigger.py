"""rdoc_trigger.py — capture ONE frame of the game running under RenderDoc, without a key press (KUMM bug 67: the owner at the keyboard — HOUSE_RULES
rule 30 forbids real input; F12 in the game would need it). Runs inside RenderDoc's own Python:
    "C:/Program Files/RenderDoc/qrenderdoc.exe" --python rdoc_trigger.py
Connects to the first local RenderDoc target (the game launched by `renderdoccmd capture`), triggers a capture of N frames (env RDOC_FRAMES, default 1),
waits for the new capture, prints its path to rdoc_trigger.out next to this file, then quits qrenderdoc.
[NOT-TESTED]
"""
import os
import time

import renderdoc as rd

# A constant path: qrenderdoc runs the script without `__file__` (17:24 the first run died on that line silently and the window stayed open).
OUT = 'D:/work/ai_sandbox/ConanExiles/_config/rdoc/rdoc_trigger.out'
FRAMES = int(os.environ.get('RDOC_FRAMES', '1'))


def log(msg):
    with open(OUT, 'a', encoding='utf-8') as f:
        f.write(time.strftime('%H:%M:%S ') + msg + '\n')


ident = rd.EnumerateRemoteTargets('', 0)
if ident == 0:
    log('no RenderDoc target found')
else:
    tc = rd.CreateTargetControl('', ident, 'kumm-bug67', True)
    if tc is None:
        log('connect failed (another client attached?)')
    else:
        log('connected: %s pid %d api %s' % (tc.GetTarget(), tc.GetPID(), tc.GetAPI()))
        tc.TriggerCapture(FRAMES)
        got = 0
        t0 = time.time()
        while got < FRAMES and time.time() - t0 < 60:
            msg = tc.ReceiveMessage(None)
            if msg.type == rd.TargetControlMessageType.NewCapture:
                log('capture: %s' % msg.newCapture.path)
                got += 1
            elif msg.type == rd.TargetControlMessageType.Disconnected:
                log('disconnected')
                break
        if got < FRAMES:
            log('timeout: %d of %d captures' % (got, FRAMES))
        tc.Shutdown()
try:
    pyrenderdoc.Quit()  # noqa: F821 — the qrenderdoc context object
except Exception:
    os._exit(0)
