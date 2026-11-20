#!/usr/bin/env bash
# top-scout.sh <out dir> "<name> <X> <Y>" ... — a top-down frame over each world point: the hero put on the ground there (tp_ground.sh), a fixed camera
# <H> cm above him looking straight down; the frame shows where the shore, the sand and the open water lie, so a shore point and a heading are picked by eye.
# Why (KUMM 2026-11-09, `[OWNER]` 00:15 «ставь на пляжи» · 00:16 «больших водных массивово, а не луж!»): map markers are place CENTRES, not shores.
# H — env TOP_H (default 25000 cm). North (+X) is up on the frame (yaw 0, pitch −89).
# Exit: 0 done · 4 the remote failed / the game is dead.
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; shift
mkdir -p "$OUT"
H="${TOP_H:-25000}"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"
  bash tp_ground.sh "$X" "$Y" 12 > /dev/null 2>&1 || echo "$NAME: no ground (hovering)"
  P "lua _G.__fc={dz=$H, pitch=-89.9, yaw=0}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')" || exit 4
  P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'" || exit 4
  sleep 5
  powershell -File capture-window.ps1 -Out "$OUT/${NAME}_top.jpg" -Width 1920 > /dev/null 2>&1
  echo "$NAME: $OUT/${NAME}_top.jpg"
done
P "lua _G.__fc='off'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')"
exit 0
