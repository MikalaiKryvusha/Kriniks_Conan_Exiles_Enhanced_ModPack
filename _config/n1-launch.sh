#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# n1-launch.sh <A|B> <label> — one fresh FRONT launch of the N1 series (KUMM researches/conan-hitch-profiler): B adds
# `[/Script/NavigationSystem.RecastNavMesh] bDoFullyAsyncNavDataGathering=True` to the game's Engine.ini before the launch and restores the ini after.
# Steps, each printed: owner-idle FREE (HOUSE_RULES rule 30 — the front launch waits for a free keyboard, as the owner-presence hook does) → launch-fg →
# world → read the flag back → weather off → one cold krinik-show flight → first-60 s hitches → close → ini restored (sha256 printed).
# [NOT-TESTED]
set -u
SIDE="$1"; LABEL="$2"
C=/d/work/ai_sandbox/ConanExiles/_config
INI="$GAME_UNIX/ConanSandbox/Saved/Config/Windows/Engine.ini"
cp "$INI" "$INI.bak-n1s"
if [ "$SIDE" = "B" ]; then printf '\r\n[/Script/NavigationSystem.RecastNavMesh]\r\nbDoFullyAsyncNavDataGathering=True\r\n' >> "$INI"; fi
for i in $(seq 1 100); do powershell -NoProfile -File D:/work/ai_sandbox/_tools/owner-idle.ps1 >/dev/null 2>&1 && break; sleep 3; done
echo "[$(date +%T)] side $SIDE: launch"
powershell -NoProfile -ExecutionPolicy Bypass -File "$C/launch-fg.ps1" -HoldSec 60 | tail -1
bash "$C/enter-world-remote.sh" | tail -1 || exit 4
bash "$C/pult.sh" "lua local n=FindFirstOf('RecastNavMesh'); local ok,v=pcall(function() return n:GetPropertyValue('bDoFullyAsyncNavDataGathering') end); return 'async gathering='..tostring(v)" | tail -1 || exit 4
bash "$C/pult.sh" "lua local h=FindFirstOf('BP_SC_WeatherHandler_C'); h:ForceStopAllWeathers(); h:FreezeWeather(); return 'weather off'" | tail -1 || exit 4
bash "$C/bench-flight.sh" krinik-show "$LABEL" 2>&1 | grep -a "$LABEL:"
python -I -X utf8 "$C/bench-first60.py" "$(ls -t "/d/work/ai_sandbox/ConanExiles/_library/_bench/"*"$LABEL".csv | head -1)"
powershell -NoProfile -ExecutionPolicy Bypass -File "$C/close-game.ps1" | tail -1
# close-game.ps1 leaves a game that did not close in 60 s («STILL RUNNING … not killing it», launch L2 21:11) — this run's own game is stopped by its PID
# (saves are ours during development, HOUSE_RULES rule 6), or the next launch refuses
PID_LEFT=$(tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //FO CSV //NH | head -1 | cut -d'"' -f4)
if [ -n "$PID_LEFT" ] && [ "$PID_LEFT" -eq "$PID_LEFT" ] 2>/dev/null; then powershell -NoProfile -Command "Stop-Process -Id $PID_LEFT -Force"; sleep 2; echo "stopped own PID $PID_LEFT"; fi
cp "$INI.bak-n1s" "$INI" && rm "$INI.bak-n1s"
echo "[$(date +%T)] ini restored, sha256 $(sha256sum "$INI" | cut -c1-12)"
