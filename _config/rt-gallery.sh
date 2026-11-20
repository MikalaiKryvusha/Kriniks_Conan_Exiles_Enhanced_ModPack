#!/usr/bin/env bash
# rt-gallery.sh — the reflection A/B gallery: the same view shot twice, variant 5 (ray tracing ON, screen traces OFF) on the LEFT and variant 4 (ray
# tracing ON, screen traces ON) on the RIGHT, one side-by-side 4K-high image per view.
#   bash rt-gallery.sh <out dir> "<name> <X> <Y> <dz> <pitch> <yaw> [hour]" ...
# Why (KUMM 2026-11-08, `[OWNER]` 13:24 «по 4 и 5 нужно будет богатая галлерея сранений, на кадров 15, те же сцены, две колонки справа 4 слева 5. Разные сцены,
# желательно побольше взглядов на воду, на панорамы»). Views come from `view-scout.sh`. Ray tracing is switched on once (it takes > 10 s, game map);
# between the two shots only `r.Lumen.Reflections.ScreenTraces` changes, then 4 s settle. The game's time of day is set before EACH shot (the sun
# moves between two shots otherwise). At the end both cvars go back to the build's defaults (RT 0, screen traces 1).
# Out: <out>/<NN>_<name>_5_vs_4.webp (left 5, right 4) + the two source frames.
# Exit: 0 done · 4 the remote failed / the game is dead (HOUSE_RULES rule 29).
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; shift
mkdir -p "$OUT"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
bash pult.sh "exec r.RayTracing.Enable 1" > /dev/null 2>&1
sleep 15
P "exec r.Lumen.HardwareRayTracing.LightingMode 0" || exit 4
N=0
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"; DZ="$4"; PITCH="$5"; YAW="$6"; HOUR="${7:-11.0}"
  N=$((N + 1)); NN=$(printf '%02d' "$N")
  bash tp_ground.sh "$X" "$Y" 10 > /dev/null 2>&1 || { echo "$NAME: no ground"; continue; }
  P "lua _G.__fc={dz=$DZ, pitch=$PITCH, yaw=$YAW}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')" || exit 4
  sleep 6
  for V in 5 4; do
    ST=1; [ "$V" = 5 ] && ST=0
    P "exec r.Lumen.Reflections.ScreenTraces $ST" || exit 4
    P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay($HOUR); return 'tod'" || exit 4
    sleep 4
    powershell -File capture-window.ps1 -Out "$OUT/${NN}_${NAME}_$V.jpg" -Width 3840 > /dev/null 2>&1
  done
  ffmpeg -loglevel error -y -i "$OUT/${NN}_${NAME}_5.jpg" -i "$OUT/${NN}_${NAME}_4.jpg" \
    -filter_complex "[0]pad=iw+16:ih:0:0:color=black[a];[a][1]hstack" -quality 90 "$OUT/${NN}_${NAME}_5_vs_4.webp"
  echo "$NN $NAME done"
done
P "exec r.Lumen.Reflections.ScreenTraces 1"
bash pult.sh "exec r.RayTracing.Enable 0" > /dev/null 2>&1
P "lua _G.__fc='off'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')"
exit 0
