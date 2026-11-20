#!/usr/bin/env bash
# shore-try.sh <out dir> "<name> <startX> <startY> <march yaw> [view yaw]" ... — beach views by measurement: the hero on the ground at the start, marched along
# <march yaw> to the sea's edge (shore-find.lua), the camera behind him looking along [view yaw] (default = march yaw), the interface hidden, 11:00, a 1920 frame.
# Prints «name SHORE x y ground z» — the line to feed water-scenes.sh. Why: `[OWNER]` 2026-11-09 00:15 «ставь на пляжи» · 00:16 «больших водных массивово».
# Exit: 0 done · 4 the remote failed / the game is dead.
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; shift
mkdir -p "$OUT"
RES="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"; MY="$4"; VY="${5:-$4}"
  bash tp_ground.sh "$X" "$Y" 10 > /dev/null 2>&1 || { echo "$NAME: no ground at start"; continue; }
  P "lua _G.__sf={yaw=$MY, step=300, max=60000}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/shore-find.lua')" || exit 4
  R="$(cat "$RES")"
  case "$R" in SHORE*) ;; *) echo "$NAME: $R"; continue ;; esac
  P "lua _G.__bc={yaw=$VY}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/behind-cam.lua')" || exit 4
  P "lua FindFirstOf('GUIModuleController'):EnableVanityCameraMode(true); return 'hud off'" || exit 4
  P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'" || exit 4
  sleep 5
  powershell -File capture-window.ps1 -Out "$OUT/${NAME}.jpg" -Width 1920 > /dev/null 2>&1
  echo "$NAME $R view $VY"
done
exit 0
