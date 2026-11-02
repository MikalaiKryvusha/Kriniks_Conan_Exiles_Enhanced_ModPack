#!/usr/bin/env bash
# slow-shot.sh <out.mp4> [crop] — a REAL full-charge bow shot recorded at 120 fps and slowed ×5 for the owner's eye.
# The stand first: quiet-stand.lua kills every humanoid / listed beast within 60 m and the recording is REFUSED while one is left alive (exit 3) —
# `[OWNER]` 2026-11-02 11:20 «героя ебашат, а ты видео пишешь блять» · «отвратительно по-прежнему тестовое окружение настраиваешь» · 11:22 «как ты заебал
# забывать свои подходы!» (HOUSE_RULES rule 11). The shot itself: RMB held 2.8 s (full draw), an LMB CLICK while RMB is held, RMB up (`[OWNER]` 11:07
# «нужно при зажатой ПКМ ещё ЛКМ нажимать»). Desktop HDR is switched off for the capture and back on after (a HDR capture is ×4.5 bright, EXP-0213).
# The game must be in front and in the world. Output: <out.mp4> (H.264, 24 fps — every captured frame, 2 s of game = 10 s of clip) and <out>.mkv kept beside.
# [TESTED: 2026-11-02 · two clips of the owner's review folder 60, 11:21 and 11:23 · KUMM testcases/reports/2026-11-02_conan-hub-rectangle-and-batch.md]
set -u
C="$(cd "$(dirname "$0")" && pwd)"
OUT="$1"; CROP="${2:-iw*0.5:ih*0.6:iw*0.25:ih*0.28}"
cd "$C"
q=$(bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')" | tail -1)
echo "stand: $q"
case "$q" in *"left alive 0"*) ;; *) echo "REFUSED: the stand is not quiet"; exit 3;; esac
bash pult.sh "lua FindFirstOf('GUIModuleController'):EnableVanityCameraMode(false); return 'vanity off'" > /dev/null
powershell -NoProfile -File D:/work/ai_sandbox/SvarogsDream/tools/hdr.ps1 off > /dev/null 2>&1
RAW="${OUT%.*}.mkv"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "ddagrab=framerate=120:draw_mouse=0" -t 6 -c:v hevc_nvenc -qp 16 "$RAW" &
sleep 0.5
powershell -NoProfile -File mouse-seq.ps1 -Seq "rdown,wait:2800,lclick,wait:900,rup" > /dev/null 2>&1
wait
powershell -NoProfile -File D:/work/ai_sandbox/SvarogsDream/tools/hdr.ps1 on > /dev/null 2>&1
ffmpeg -hide_banner -loglevel error -y -ss 2.6 -t 2.0 -i "$RAW" -vf "crop=$CROP,setpts=5*PTS,scale=1600:-2" -r 24 -c:v libx264 -crf 18 -pix_fmt yuv420p -an "$OUT"
ffprobe -v error -show_entries format=duration -of csv=p=0 "$OUT"
