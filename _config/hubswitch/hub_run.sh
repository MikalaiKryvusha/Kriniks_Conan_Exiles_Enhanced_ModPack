#!/usr/bin/env bash
# hub_run.sh <tag> — one recorded pass over all 9 hub tabs by real mouse clicks, the hub already open, the game in front.
# Records 62 s at 144 fps (ddagrab), the click sequence of TC_conan_hub_instant_switch_2026-11-06.md, then the analysis.
# 2026-11-14 (KUMM bug 101, judge round 3): the folder is made BEFORE the recording; the wait matches mouse-seq's own owner-idle threshold (10 s) and is
# checked; mouse-seq's exit is checked — a refused input used to leave a clip with no clicks that the analysis read as a normal pass.
# [TESTED: 2026-11-14 · the old form recorded and analysed audit1 / fix1 (17 switches each); this form not run yet]
set -u -o pipefail
S="D:/work/ai_sandbox/ConanExiles/_scratch/hubswitch"
HERE="$(cd "$(dirname "$0")" && pwd)"            # the analyser lives next to this script; `$S` holds only the recordings
TAG="$1"
Y=0.0343
declare -A X=([inv]=0.1177 [feat]=0.2448 [attr]=0.3516 [stat]=0.4495 [jour]=0.5719 [clan]=0.668 [fol]=0.7505 [map]=0.836 [store]=0.907)
SEQ="wait:1500"
for t in map feat inv store attr fol stat clan jour inv feat; do SEQ="$SEQ,move:${X[$t]}/$Y,wait:300,lclick,wait:4500"; done
mkdir -p "$S/h69"
if ! powershell -NoProfile -File D:/work/ai_sandbox/ConanExiles/_config/wait-input-idle.ps1 -Min 10 -MaxWait 60 | tail -1; then
    echo "the owner is at the keyboard — no recording" >&2; exit 5
fi
(ffmpeg -nostdin -v error -y -f lavfi -i ddagrab=framerate=144:draw_mouse=0 -c:v h264_nvenc -preset p4 -cq 18 -t 62 "$S/h69/$TAG.mp4" > "$S/rec_$TAG.log" 2>&1 &)
sleep 1.5
SEQ_LOG="$(powershell -NoProfile -File D:/work/ai_sandbox/ConanExiles/_config/mouse-seq.ps1 -Seq "$SEQ" 2>&1)"
SEQ_RC=$?
sleep 8
ls -la "$S/h69/$TAG.mp4"
if [ "$SEQ_RC" -ne 0 ]; then
    echo "INPUT NOT SENT (mouse-seq exit $SEQ_RC): $(printf '%s\n' "$SEQ_LOG" | tail -n 1) — the clip has no clicks, no analysis" >&2
    exit "$SEQ_RC"
fi
cd "$S/h69" && python -I "$HERE/hub_switches.py" "$TAG.mp4" | cut -c1-420
