#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# set-reflections.sh <now|4|5> — switch the running game's reflections live by the remote and read them back.
#   now — the build as shipped: ray tracing off, screen traces on (Lumen software fallback; the white streak behind trunks)
#   4   — ray tracing on, screen traces on (screen first, hardware rays where the screen has nothing)
#   5   — ray tracing on, screen traces off (hardware rays only)
# Why (KUMM 2026-11-08, `[OWNER]` 14:02 «и дашь мне поигать в 4, и дашь поиграть в 5»): the owner plays each variant and the agent switches on his word.
# `r.RayTracing.Enable` takes > 10 s to apply (game map) — the read-back waits for it.
# Exit: 0 applied and read back · 2 bad argument · 4 the remote failed / the game is dead.
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
#   6   — «pure rays»: as 5, plus the two other screen paths off (distant screen traces, scene colour at hit) — `[OWNER]` 14:44 «экранное отражение - зло»
case "${1:-}" in
  now) RT=0; ST=1; DST=1; SC=1 ;;
  4)   RT=1; ST=1; DST=1; SC=1 ;;
  5)   RT=1; ST=0; DST=1; SC=1 ;;
  6)   RT=1; ST=0; DST=0; SC=0 ;;
  # off — no rays and no screen traces: the software fallback only (the owner 2026-11-08 23:56 «и лучи выключить, и отражение в экранном пространстве?»)
  off) RT=0; ST=0; DST=0; SC=1 ;;
  # sw — the third way (KUMM researches/conan-water-reflections, 2026-11-09): software Lumen (distance fields — cooked in the game: r.GenerateMeshDistanceFields 1)
  #      with a longer reach: no rays, no screen traces, trace distance ×4, 6 global SDF clipmaps of 50 m base extent (defaults 1 · 4 · 25 m)
  sw)  RT=0; ST=0; DST=0; SC=1; TDS=4; NCM=6; CME=5000 ;;
  *) echo "usage: set-reflections.sh now|4|5|6|off|sw"; exit 2 ;;
esac
TDS="${TDS:-1}"; NCM="${NCM:-4}"; CME="${CME:-2500}"   # every variant but sw puts the software reach back to the game's defaults
RES="$GAME_UNIX/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"
bash pult.sh "exec r.Lumen.TraceDistanceScale $TDS" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.AOGlobalDistanceField.NumClipmaps $NCM" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.LumenScene.GlobalSDF.ClipmapExtent $CME" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.Lumen.Reflections.ScreenTraces $ST" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.Lumen.Reflections.DistantScreenTraces $DST" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.Lumen.Reflections.SampleSceneColorAtHit $SC" > /dev/null 2>&1 || exit 4
bash pult.sh "exec r.RayTracing.Enable $RT" > /dev/null 2>&1
sleep 15
bash pult.sh "lua local K=StaticFindObject('/Script/Engine.Default__KismetSystemLibrary'); return K:GetConsoleVariableFloatValue('r.RayTracing.Enable')..' '..K:GetConsoleVariableFloatValue('r.Lumen.Reflections.ScreenTraces')" > /dev/null 2>&1 || exit 4
echo "variant $1: RayTracing.Enable ScreenTraces = $(cat "$RES")"
exit 0
