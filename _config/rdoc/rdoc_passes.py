"""rdoc_passes.py — list the render passes of a RenderDoc capture (KUMM bug 67): every marker / action whose name matches a filter, with its event id,
depth in the marker tree and child count, into rdoc_passes.out. Runs inside RenderDoc's Python:
    set RDOC_CAP=D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/conan_frame2988.rdc & set RDOC_FILTER=shadow|nanite|vsm
    "C:/Program Files/RenderDoc/qrenderdoc.exe" --python rdoc_passes.py
[TESTED: 2026-11-07 18:07 · opened conan_frame2988.rdc (5 GB), listed 20 706 actions with filter «.»; filter «shadow|nanite|vsm» found none — the Shipping exe has no markers]
"""
import os
import re
import time

import renderdoc as rd

OUT = 'D:/work/ai_sandbox/ConanExiles/_config/rdoc/rdoc_passes.out'
CAP = os.environ.get('RDOC_CAP', 'D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/conan_frame2988.rdc')
FILT = re.compile(os.environ.get('RDOC_FILTER', 'shadow|nanite|vsm'), re.I)
lines = []


def log(s):
    lines.append(s)


def walk(actions, depth):
    for a in actions:
        name = a.GetName(sf) if hasattr(a, 'GetName') else a.customName
        if FILT.search(name or '') and depth <= 6:
            log('%s[%d] %s  (children %d)' % ('  ' * depth, a.eventId, name, len(a.children)))
        walk(a.children, depth + 1)


try:
    rd.InitialiseReplay(rd.GlobalEnvironment(), [])
    cap = rd.OpenCaptureFile()
    st = cap.OpenFile(CAP, '', None)
    log('open: %s' % st)
    if st == rd.ResultCode.Succeeded:
        st, ctl = cap.OpenCapture(rd.ReplayOptions(), None)
        log('replay: %s' % st)
        if st == rd.ResultCode.Succeeded:
            sf = ctl.GetStructuredFile()
            walk(ctl.GetRootActions(), 0)
            ctl.Shutdown()
        cap.Shutdown()
except Exception as e:
    log('error: %r' % (e,))
with open(OUT, 'w', encoding='utf-8') as f:
    f.write(time.strftime('%H:%M:%S ') + CAP + '\n' + '\n'.join(lines) + '\n')
try:
    pyrenderdoc.Quit()  # noqa: F821
except Exception:
    os._exit(0)
