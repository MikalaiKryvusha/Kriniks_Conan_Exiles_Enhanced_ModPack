#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# palm-shadow-series.sh — one A/B series of palm-leaf shadow clips under a FIXED time of day (KUMM bug 67).
#
# Why (2026-11-06 run report `KUMM/testcases/reports/2026-11-06_conan-palm-shadow-sun-step.md`, verdict INVALID): the clips were overexposed
# (HDR desktop captured without `hdr.ps1 off`) and the time of day drifted ≈ one game hour over the series, so A1 and A2 — the same
# setting — differed 2×. This script fixes both: HDR off for the whole series, `SetTimeOfDay($TOD)` before EVERY clip, and every
# cvar of the series reset to its LIVE value (read at the start) before each clip, so a clip never inherits the previous one's setting.
#
#   bash palm-shadow-series.sh <out dir> "<label>|<cvar> <value>;<cvar> <value>" ...
#   e.g. bash palm-shadow-series.sh /d/work/ai_sandbox/ConanExiles/_scratch/ps A "A|DynamicSky.SolarUpdateAngleDelta 0.003" "B|DynamicSky.SolarUpdateAngleDelta 0.003;r.Shadow.Virtual.ResolutionLodBiasDirectional -1.5"
# Env: TOD (game hour, default 10.0) · SETTLE (s after the set, default 4) · SEC (clip length, default 8) · BOX "x0 y0 x1 y1" (metric region, 3840×2160).
# The hero and the camera are NOT touched here — pose the stand first (the oasis, the view on sand under the fronds), then run.
# Out: <out>/<label>.mkv (60 fps, HEVC) and one metric line per clip in <out>/metric.txt (temporal 2nd difference: sway ≈ 0, jitter high).
# Exit: 0 done · 2 the remote silent / the game dead (pult.sh exit 4 — HOUSE_RULES rule 29).
# [TESTED: 2026-11-07 · 22 clips: reset to base, time of day, quiet-stand, window capture, metric — frames read · KUMM testcases/reports/2026-11-07_conan-palm-shadow-levers-wind-steps.md; WAKE=1 refused while the owner typed (rule 30) — use fixed-cam.lua instead]
set -u
cd "$(dirname "$0")" || exit 2
OUT="$1"; shift
TOD="${TOD:-10.0}"; SETTLE="${SETTLE:-4}"; SEC="${SEC:-8}"; BOX="${BOX:-2100 1300 3700 1650}"
mkdir -p "$OUT"
RES="$GAME_UNIX/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"
P() { bash pult.sh "$1" > /dev/null 2>&1; }

# every cvar named by any spec → its live value now (the reset target before each clip)
declare -A BASE
for spec in "$@"; do
  IFS=';' read -ra kv <<< "${spec#*|}"
  for pair in "${kv[@]}"; do
    name="${pair%% *}"; [ -n "$name" ] || continue
    [ -n "${BASE[$name]+x}" ] && continue
    P "lua return tostring(StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'):GetConsoleVariableFloatValue('$name'))" || exit 2
    BASE[$name]="$(tr -d '\r\n' < "$RES")"
    echo "base $name = ${BASE[$name]}" | tee -a "$OUT/metric.txt"
  done
done

# CAPTURE = the GAME WINDOW by Windows Graphics Capture (`gfxcapture`), never the desktop (`ddagrab`): 2026-11-07 13:3x the first series
# recorded the owner's VS Code for all 8 clips — he started typing, the game went behind, ddagrab took whatever was in front (metric all 0.000).
# gfxcapture takes the game's own window even when covered — the background twin of HOUSE_RULES rule 16.2; no focus, no input (rule 30);
# its 8-bit output is SDR-mapped, so HDR is not toggled (the toggle would blink the owner's screen) — check one frame for overexposure first.
POSE="${POSE:-}"   # "pitch yaw" — re-set before each clip: the camera turns to face the hero while the game is behind
for spec in "$@"; do
  label="${spec%%|*}"
  for name in "${!BASE[@]}"; do P "exec $name ${BASE[$name]}" || exit 2; done
  IFS=';' read -ra kv <<< "${spec#*|}"
  for pair in "${kv[@]}"; do [ -n "$pair" ] && { P "exec $pair" || exit 2; }; done
  P "lua FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay($TOD); return 'tod'" || exit 2
  # WAKE=1: a real Shift tap first — after ≈30 s with no real input the game's idle camera takes over, hides the HUD, orbits the hero and ignores
  # SetControlRotation (game map, «The game's idle camera»); 2026-11-07 the pose was lost mid-series. Needs the game in front and the PC free (rule 30).
  # QUIET=<m>: clear humanoids and beasts within <m> metres before each clip — 2026-11-07 a camp fighter walked in and the camera went into the fight
  [ -n "${QUIET:-}" ] && P "lua _G.__qs_radius=$QUIET; return dofile('D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')"
  [ "${WAKE:-0}" = 1 ] && powershell -NoProfile -File mouse-seq.ps1 -Seq "kdown:0xA0,wait:60,kup:0xA0" -KeepFront -MinIdle 2 > /dev/null
  [ -n "$POSE" ] && { P "lua FindFirstOf('FunCombat_PlayerController_C'):SetControlRotation({Pitch=${POSE% *},Yaw=${POSE#* },Roll=0.0}); return 'pose'" || exit 2; }
  sleep "$SETTLE"
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "gfxcapture=window_exe=(?i)ConanSandbox-Win64-Shipping:capture_cursor=0:max_framerate=60" -t "$SEC" \
    -vf "hwdownload,format=bgra" -c:v hevc_nvenc -preset p5 -tune hq -rc vbr -cq 18 -b:v 60M -maxrate 100M -bufsize 100M "$OUT/$label.mkv"
  m=$(/c/Python314/python.exe -X utf8 shadow_flicker_metric.py "$OUT/$label.mkv" $BOX 2>&1 | tail -1)
  echo "$label | ${spec#*|} | $m" | tee -a "$OUT/metric.txt"
done
for name in "${!BASE[@]}"; do P "exec $name ${BASE[$name]}"; done
echo "series done → $OUT"
