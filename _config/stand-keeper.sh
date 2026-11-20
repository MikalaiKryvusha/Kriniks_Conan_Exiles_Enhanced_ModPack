#!/usr/bin/env bash
# stand-keeper.sh — keeps the test stand clean for the whole run (HOUSE_RULES rule 11): god mode on, then INSIDE THE GAME a UE4SS timer every PERIOD
# seconds kills every humanoid NPC and listed beast within RADIUS_M of the hero (quiet-stand.lua via stand-keeper.lua; one `[stand-keeper]` line per pass
# to UE4SS.log; the last pass also in _G.__stand_keeper_last).
# Why: `[OWNER]` 2026-11-07 16:45–16:47 «Что твоего героя пиздят со всех сторон!» · «600 м!!!!» · «каждые 20 секунд!!!» — a one-off quiet-stand of 60 m before a
# series left the hero beaten by respawned fighters during the clips (bug 67, the Nanite-buffer series of 16:4x — void).
# Why in the game and not a bash loop: the remote has ONE answer file (result.txt); a second process calling pult.sh every 20 s mixed its answers with the
# series' own (16:48 god-on read the series' «tod 11» and failed). The in-game timer costs one remote call to start and one to stop.
#   bash stand-keeper.sh           # on: 600 m, every 20 s, god on
#   bash stand-keeper.sh last      # the last pass (time · killed · left alive)
#   bash stand-keeper.sh off       # stop the timer (god stays as it is)
# Exit: 0 done · 1 the remote refused · 2 the remote silent · 4 the game is dead (rule 29).
# [TESTED: 2026-11-07 · `on` 16:49:21 (god ok, timer started), `last` returned the 16:49:41 pass; `off` 20:17 - the loop ended on its next pass («[stand-keeper] stopped» 20:17:24)]
cd "$(dirname "$0")" || exit 2
RADIUS_M="${RADIUS_M:-600}"; PERIOD="${PERIOD:-20}"
case "${1:-on}" in
  off)  bash pult.sh "lua _G.__stand_keeper_on = false; return 'stand-keeper off'"; exit $? ;;
  last) bash pult.sh "lua return tostring(_G.__stand_keeper_last)"; exit $? ;;
esac
bash god-on.sh || exit $?
bash pult.sh "lua _G.__qs_radius = $RADIUS_M; _G.__sk_period_ms = $(( PERIOD * 1000 )); return dofile('D:/work/ai_sandbox/ConanExiles/_config/stand-keeper.lua')"
