#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# ab-launch.sh <ini-block file for side A | -> <ini-block file for side B | -> <A|B> <label> — one fresh FRONT launch of an A-B-B-A series with an ini block
# appended to the game's Engine.ini for the chosen side (`-` = nothing), the ini restored after (sha256 printed). The generalisation of n1-launch.sh
# (KUMM researches/conan-hitch-profiler, HOUSE_RULES 11.6e: before / after numbers by PresentMon only).
# [NOT-TESTED]
set -u
FA="$1"; FB="$2"; SIDE="$3"; LABEL="$4"
C=/d/work/ai_sandbox/ConanExiles/_config
INI="$GAME_UNIX/ConanSandbox/Saved/Config/Windows/Engine.ini"
cp "$INI" "$INI.bak-ab"
BLK="$FA"; [ "$SIDE" = "B" ] && BLK="$FB"
[ "$BLK" != "-" ] && { printf '\r\n' >> "$INI"; sed 's/$/\r/' "$BLK" >> "$INI"; }
for i in $(seq 1 100); do powershell -NoProfile -File D:/work/ai_sandbox/_tools/owner-idle.ps1 >/dev/null 2>&1 && break; sleep 3; done
echo "[$(date +%T)] side $SIDE ($BLK): launch"
powershell -NoProfile -ExecutionPolicy Bypass -File "$C/launch-fg.ps1" -HoldSec 60 | tail -1
bash "$C/enter-world-remote.sh" | tail -1 || exit 4
bash "$C/pult.sh" "lua local n=FindFirstOf('RecastNavMesh'); local ok,v=pcall(function() return n:GetPropertyValue('bDoFullyAsyncNavDataGathering') end); local h=FindFirstOf('BP_SC_WeatherHandler_C'); h:ForceStopAllWeathers(); h:FreezeWeather(); return 'async='..tostring(v)..' weather off'" | tail -1 || exit 4
bash "$C/bench-flight.sh" krinik-show "$LABEL" 2>&1 | grep -a "$LABEL:"
python -I -X utf8 "$C/bench-first60.py" "$(ls -t "/d/work/ai_sandbox/ConanExiles/_library/_bench/"*"$LABEL".csv | head -1)"
echo "log lines this launch: $(wc -l < "$GAME_UNIX/ConanSandbox/Saved/Logs/ConanSandbox.log")"
powershell -NoProfile -ExecutionPolicy Bypass -File "$C/close-game.ps1" | tail -1
PID_LEFT=$(tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //FO CSV //NH | head -1 | cut -d'"' -f4)
if [ -n "$PID_LEFT" ] && [ "$PID_LEFT" -eq "$PID_LEFT" ] 2>/dev/null; then powershell -NoProfile -Command "Stop-Process -Id $PID_LEFT -Force"; sleep 2; echo "stopped own PID $PID_LEFT"; fi
cp "$INI.bak-ab" "$INI" && rm "$INI.bak-ab"
echo "[$(date +%T)] ini restored, sha256 $(sha256sum "$INI" | cut -c1-12)"
