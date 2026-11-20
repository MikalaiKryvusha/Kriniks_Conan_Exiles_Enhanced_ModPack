#!/usr/bin/env bash
# m6-air-shot.sh — the bow's shot in a jump by REAL input (KUMM, KrinikConanLocomotion case M6: the remote's LMB does not shoot the bow, so the case needs the
# game in front and real keys). Steps: hero to the oasis stand, a side camera (fixed-cam.lua) → `input.ps1 -Key 3` (game to front,
# the bow from slot 3) → window capture 3 s at 60 fps while mouse-seq sends Space, RMB down (draw), LMB click (release), RMB up → the hero's Z sampled by the remote
# right after, and a 12-frame sheet of the clip for the eye.
#   bash m6-air-shot.sh <out dir>
# Exit: 0 ran · 4 the game is dead.
# [TESTED: 2026-11-07 19:2x · ran end to end on the live game: capture and sheet made, but the real keys did not move the hero (see KUMM KrinikConanLocomotion.md «M6 try») — the input path needs fixing]
set -u
cd "$(dirname "$0")" || exit 2
OUT="${1:?out dir}"; mkdir -p "$OUT"
bash pult.sh "lua local p=FindFirstOf('PlayerController').Pawn; p:K2_TeleportTo({X=-78551,Y=245321,Z=-19950},{Pitch=0,Yaw=0,Roll=0}); return 'tp'" > /dev/null || exit 4
sleep 3
bash pult.sh "lua if _G.__fixed_cam and _G.__fixed_cam:IsValid() then _G.__fixed_cam:K2_DestroyActor(); _G.__fixed_cam=nil end; _G.__fc={x=-78551, y=246121, z=-19850, pitch=-5, yaw=-90}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')" > /dev/null || exit 4
bash pult.sh "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'" > /dev/null || exit 4
powershell -NoProfile -File input.ps1 -Key 3 > /dev/null 2>&1
sleep 1.5
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "gfxcapture=window_exe=(?i)ConanSandbox-Win64-Shipping:capture_cursor=0:max_framerate=60" -t 3 -vf "hwdownload,format=bgra" -c:v hevc_nvenc -qp 18 "$OUT/m6.mkv" &
sleep 0.4
powershell -NoProfile -File mouse-seq.ps1 -Seq "kdown:0x20,wait:60,kup:0x20,wait:120,rdown,wait:450,lclick,wait:700,rup" > /dev/null 2>&1
wait
ffmpeg -hide_banner -loglevel error -y -i "$OUT/m6.mkv" -vf "fps=8,scale=640:-1,tile=4x3" -frames:v 1 "$OUT/m6_sheet.webp"
echo "clip $OUT/m6.mkv · sheet $OUT/m6_sheet.webp"
