#!/usr/bin/env bash
# view-scout.sh — scout camera views at named world points: for each point the hero is put on the ground, a fixed camera is raised above him and
# turned to four headings; one 2x2 sheet per point shows where the water / the panorama is.
#   bash view-scout.sh <out dir> "<name> <X> <Y> [dz] [pitch]" ...
# Why (KUMM 2026-11-08, `[OWNER]` 13:24 «богатая галлерея сравнений, на кадров 15, те же сцены … побольше взглядов на воду, на панорамы»): a gallery
# of A/B pairs needs good views first; a heading picked blind wastes a pair. Picked views go to `rt-gallery.sh` as "<name> X Y dz pitch yaw".
# Needs: the game in the world, the remote (`pult.sh`), `tp_ground.sh`, `fixed-cam.lua`, `capture-window.ps1`, ffmpeg. Time of day 11.0 per point.
# Exit: 0 done · 4 the remote failed / the game is dead (HOUSE_RULES rule 29).
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; shift
mkdir -p "$OUT"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"; DZ="${4:-600}"; PITCH="${5:--10}"
  bash tp_ground.sh "$X" "$Y" 10 > /dev/null 2>&1 || { echo "$NAME: no ground"; continue; }
  P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'" || exit 4
  for YAW in 0 90 180 270; do
    P "lua _G.__fc={dz=$DZ, pitch=$PITCH, yaw=$YAW}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')" || exit 4
    sleep 3
    powershell -File capture-window.ps1 -Out "$OUT/${NAME}_y$YAW.jpg" > /dev/null 2>&1
  done
  ffmpeg -loglevel error -y -i "$OUT/${NAME}_y0.jpg" -i "$OUT/${NAME}_y90.jpg" -i "$OUT/${NAME}_y180.jpg" -i "$OUT/${NAME}_y270.jpg" \
    -filter_complex "[0][1][2][3]xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0,scale=1600:-1" "$OUT/${NAME}_sheet.webp"
  echo "$NAME: $OUT/${NAME}_sheet.webp (0 90 / 180 270)"
done
P "lua _G.__fc='off'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')"
exit 0
