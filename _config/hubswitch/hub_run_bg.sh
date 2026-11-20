#!/usr/bin/env bash
# hub_run_bg.sh <tag> <tab> <tab> … — the BACKGROUND twin of hub_run.sh (HOUSE_RULES rule 16): the game window is recorded by window capture (gfxcapture —
# it records the game even behind the owner's window, ≈ 40–45 fps), the tabs are switched by the remote (tab-switch.lua, carousel indices), 3 s apart, then
# hub_switches.py reads every switch. No real input, no screen taken from the owner. The hub must be open. KUMM bug 101 item 3, 2026-11-14.
# Desktop HDR is left as it is (turning it off blinks the owner's screen): the frames are washed, the change counts still hold.
# [NOT-TESTED]
set -u -o pipefail
S="D:/work/ai_sandbox/ConanExiles/_scratch/hubswitch/bg"
HERE="$(cd "$(dirname "$0")" && pwd)"
TAG="$1"; shift
GAP=3
SEC=$(( ${#} * (GAP + 2) + 4 ))   # a remote call takes ≈ 1.5 s on top of the gap (m_all.mp4 lost its last three switches)
mkdir -p "$S"
rm -f "$S/$TAG.mp4"                                # never analyse an older clip of the same tag (judge 15:43)
(ffmpeg -nostdin -v error -y -f lavfi -i "gfxcapture=window_exe=(?i)ConanSandbox-Win64-Shipping:capture_cursor=0" -vf hwdownload,format=bgra \
    -c:v h264_nvenc -preset p4 -cq 18 -t "$SEC" "$S/$TAG.mp4" > "$S/rec_$TAG.log" 2>&1 &)
sleep 2
cd "$HERE/.." || exit 3
for t in "$@"; do
    bash pult.sh "lua _G.__tab=$t; return dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/tab-switch.lua')" | tail -1 || { echo "remote failed at tab $t" >&2; exit 4; }
    sleep "$GAP"
done
while tasklist 2>/dev/null | grep -qi "ffmpeg.exe"; do sleep 1; done   # the clip is complete only when ffmpeg ended (judge 15:43)
ls -la "$S/$TAG.mp4" || exit 3
cd "$S" && python -I "$HERE/hub_switches.py" "$TAG.mp4" | cut -c1-420
