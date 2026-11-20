"""rdoc_shaders.py — for every distinct compute shader dispatched in a RenderDoc capture, print its entry point and the names of the resources it binds
(reflection), so the anonymous Shipping passes can be identified by what they read and write (KUMM bug 67: find the Virtual Shadow Map passes).
    set RDOC_CAP=D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/conan_frame2988.rdc & set RDOC_MAX=4000
    "C:/Program Files/RenderDoc/qrenderdoc.exe" --python rdoc_shaders.py      → rdoc_shaders.out
[NOT-TESTED]
"""
import os
import time

import renderdoc as rd

OUT = 'D:/work/ai_sandbox/ConanExiles/_config/rdoc/rdoc_shaders.out'
CAP = os.environ.get('RDOC_CAP', 'D:/work/ai_sandbox/ConanExiles/_scratch/rdoc/conan_frame2988.rdc')
MAXE = int(os.environ.get('RDOC_MAX', '100000'))
lines, seen = [], {}


def flat(actions, acc):
    for a in actions:
        if a.flags & rd.ActionFlags.Dispatch or a.flags & rd.ActionFlags.Drawcall:
            acc.append(a)
        flat(a.children, acc)
    return acc


try:
    rd.InitialiseReplay(rd.GlobalEnvironment(), [])
    cap = rd.OpenCaptureFile()
    if cap.OpenFile(CAP, '', None) == rd.ResultCode.Succeeded:
        st, ctl = cap.OpenCapture(rd.ReplayOptions(), None)
        if st == rd.ResultCode.Succeeded:
            acts = flat(ctl.GetRootActions(), [])
            lines.append('actions with work: %d' % len(acts))
            for a in acts[:MAXE]:
                ctl.SetFrameEvent(a.eventId, False)
                ps = ctl.GetPipelineState()
                stage = rd.ShaderStage.Compute if a.flags & rd.ActionFlags.Dispatch else rd.ShaderStage.Pixel
                sh = ps.GetShader(stage)
                if sh in seen:
                    seen[sh][1] += 1
                    continue
                refl = ps.GetShaderReflection(stage)
                if refl is None:
                    seen[sh] = [a.eventId, 1, '(no reflection)']
                    continue
                names = [r.name for r in refl.readOnlyResources] + ['W:' + r.name for r in refl.readWriteResources] + \
                        ['CB:' + c.name for c in refl.constantBlocks]
                seen[sh] = [a.eventId, 1, '%s %s | %s' % (str(stage).split('.')[-1], refl.entryPoint, ' '.join(names)[:600])]
            for sh, (eid, n, desc) in sorted(seen.items(), key=lambda kv: kv[1][0]):
                lines.append('[%d] x%d %s' % (eid, n, desc))
            ctl.Shutdown()
        cap.Shutdown()
except Exception as e:
    lines.append('error: %r' % (e,))
with open(OUT, 'w', encoding='utf-8') as f:
    f.write(time.strftime('%H:%M:%S ') + CAP + '\n' + '\n'.join(lines) + '\n')
try:
    pyrenderdoc.Quit()  # noqa: F821
except Exception:
    os._exit(0)
