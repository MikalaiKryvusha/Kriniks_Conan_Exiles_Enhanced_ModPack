#!/usr/bin/env bash
# water-scenes.sh <out dir> <settings> "<name> <startX> <startY> <march yaw> <view yaw>" ... (the shore point by shore-find.lua, the camera by behind-cam.lua) — reflection settings on still water views: per scene and per setting a 4K frame
# WITHOUT the interface, then the interface back, 11:00 and a one-minute PresentMon capture (static-bench.sh).
#   <settings> — comma list for set-reflections.sh: off,6[,<name of a set-reflections variant>]
# Why (KUMM 2026-11-09, `[OWNER]` 00:07 «поставь пожалуйста героя в 5 разных мест на карте у воды на пляже, смотри на воду» · «Снимай кадр без интерфейса. Затем
# возвращай интерфейс, ставь время 11 часов, и минуту стой - пиши FPS график. И так с каждоый настройкой в кадом месте»).
# The interface is hidden by the game's own idle-camera mode (`GUIModuleController:EnableVanityCameraMode(true)` hides the HUD; our CameraActor view target
# does not move). The hero stands where `tp_ground.sh` puts him; the camera is `fixed-cam.lua` (dz / pitch / yaw from the hero).
# Out: <out>/<NN>_<name>_<setting>.jpg (no interface) and one bench line per run; a summary line per run is echoed «scene setting avg median cpu gpu».
# Exit: 0 done · 4 the remote failed / the game is dead (HOUSE_RULES rule 29).
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
# Один прогон за раз (EXP-0493): три прогона шли одновременно и портили друг другу замеры. Замок — файл с PID живого прогона; мёртвый PID замок не держит. Exit 5.
# @guard one-water-batch-at-a-time
# THREAT:         a batch «stopped» by TaskStop keeps running and a new batch starts next to it
# PROVED-AGAINST: a lock file holding a live PID (a `sleep 120` in the background) — the script must print «уже идёт прогон» and exit 5; a dead PID — must take the lock
# GAP:            a batch started by an older copy of this script (no lock) is not seen — static-bench.sh's PresentMon guard covers its captures
# ON-REAL-PATH:   NOT YET
LOCK="D:/work/ai_sandbox/ConanExiles/_library/_bench/.water-scenes.pid"
mkdir -p "$(dirname "$LOCK")"
if [ -f "$LOCK" ] && OLD=$(cat "$LOCK") && [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
  echo "уже идёт прогон water-scenes (PID $OLD) — второй не запускаю; остановить: kill $OLD и проверить ps"; exit 5
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
OUT="$1"; SETTINGS="$2"; shift 2
mkdir -p "$OUT"
P() { bash pult.sh "$1" > /dev/null 2>&1; }
TOD="lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(11.0); return 'tod'"
N=0
for spec in "$@"; do
  set -- $spec
  NAME="$1"; X="$2"; Y="$3"; MY="$4"; VY="$5"
  N=$((N + 1)); NN=$(printf '%02d' "$N")
  bash tp_ground.sh "$X" "$Y" 15 > /dev/null 2>&1 || { echo "$NAME: no ground at start"; continue; }
  # the hero walks (by measurement) to the water's edge along MY, then the camera stands behind him looking along VY
  P "lua _G.__sf={yaw=$MY, step=300, max=60000}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/shore-find.lua')" || exit 4
  P "lua _G.__bc={yaw=$VY}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/behind-cam.lua')" || exit 4
  for V in ${SETTINGS//,/ }; do
    bash set-reflections.sh "$V" || exit 4
    # a still, equal scene before every frame and capture (`[OWNER]` 2026-11-09 00:45–00:47 «мобов нужно убивать ДО замера в радиусе 600 метров» · «и дать игре
    # обработать это - секунл 30» · «или просто не убивай, а всех замораживай на месте» · «и дождь нужно отключать»): weather stopped and frozen, NPCs within 600 m
    # frozen (no kill — a kill pass stutters), 30 s for the game to settle; the stand keeper's kill timer must be OFF for the whole batch
    P "lua local h=FindFirstOf('BP_SC_WeatherHandler_C'); h:ForceStopAllWeathers(); h:FreezeWeather(); return 'weather off'" || exit 4
    # 132 NPCs at the jungle delta took longer than the remote's answer window (2026-11-09 01:10, exit 4 with the game alive) — a late answer is not a dead game
    P "lua _G.__fz={radius=600}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/freeze-npcs.lua')" || { sleep 10; bash pult.sh "lua return 'alive'" > /dev/null 2>&1 || exit 4; }
    sleep 30
    P "lua FindFirstOf('GUIModuleController'):EnableVanityCameraMode(true); return 'hud off'" || exit 4
    P "$TOD" || exit 4
    sleep 4
    powershell -File capture-window.ps1 -Out "$OUT/${NN}_${NAME}_$V.jpg" -Width 3840 > /dev/null 2>&1
    P "lua FindFirstOf('GUIModuleController'):EnableVanityCameraMode(false); return 'hud on'" || exit 4
    # NO_BENCH=1 — frames only. ONE batch at a time: every capture starts PresentMon with the session «kumm-pm» and --stop_existing_session, so a second batch
    # cuts the first one's capture short (2026-11-09 00:55: 7.6 / 27.6 / 39 s of 60 s — a batch «stopped» by TaskStop kept running; check `ps` before a batch)
    if [ "${NO_BENCH:-0}" != "1" ]; then
      P "$TOD" || exit 4
      sleep 3
      LINE=$(bash static-bench.sh "ws-${NN}-${NAME}-$V" 60 | head -1) || exit 4
      echo "$NN $NAME $V | $LINE"
    else
      echo "$NN $NAME $V | frame $OUT/${NN}_${NAME}_$V.jpg"
    fi
  done
done
exit 0
