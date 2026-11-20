#!/usr/bin/env bash
# beach-try.sh <out dir> "<name> <X> <Y> <yaw>" ... — try beach views: the hero on the ground at X Y facing yaw, the camera behind him (behind-cam.lua),
# the interface hidden, 11:00, one 1920 frame each; a view is picked by eye before water-scenes.sh measures it.
# Why (KUMM 2026-11-09, `[OWNER]` 00:15 «ставь на пляжи» · 00:16 «больших водных массивово, а не луж!»).
# Exit: 0 done · 4 the remote failed / the game is dead.
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; shift
mkdir -p "$OUT"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
P "lua FindFirstOf('GUIModuleController'):EnableVanityCameraMode(true); return 'hud off'" || exit 4
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"; YAW="$4"
  bash tp_ground.sh "$X" "$Y" 10 > /dev/null 2>&1 || { echo "$NAME: no ground"; continue; }
  P "lua _G.__bc={yaw=$YAW}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/behind-cam.lua')" || exit 4
  P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'" || exit 4
  sleep 5
  powershell -File capture-window.ps1 -Out "$OUT/${NAME}.jpg" -Width 1920 > /dev/null 2>&1
  echo "$NAME: $OUT/${NAME}.jpg"
done
exit 0
