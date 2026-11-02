#!/usr/bin/env bash
# bench-flight.sh <маршрут|"speed=… x,y,z …"> <метка> [--video] — один облёт KrinikConanBench с замером PresentMon (и видео).
#
# Зачем (2026-10-25, слово владельца «научиться делать бенч - летать камерой по миру, как сделали в Обливионе» · «будет здорово,
# если ты в нашем бенче сможешь тоже писать видео»): облёт по одному маршруту с одной скоростью — повторяемое «до/после», а не
# пробежка вручную. Игра уже в мире (launch-bg.ps1 + вход пультом), замок машины взят.
# Шаги: команда облёта → ждём «EV fly=start <сек>» в bench.log мода → PresentMon (и ddagrab → hevc_nvenc, если --video) ровно на
# время полёта → bench-report.py. Видео снимает ЭКРАН: на время облёта игра должна быть впереди — звать владельца голосом заранее.
# [NOT-TESTED]
set -u
ROUTE="$1"; LABEL="$2"; VIDEO="${3:-}"
GAME="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")"
MOD="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikConanBench"
OUT="D:/Games/Conan Exiles Mods/_bench"
PM="/d/work/ai_sandbox/_tools/PresentMon-2.5.1-x64.exe"
mkdir -p "$OUT"
STAMP="$(date +%Y-%m-%d_%H%M%S)"
CSV="$OUT/${STAMP}_${LABEL}.csv"

PID=$(tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //FO CSV //NH | head -1 | cut -d'"' -f4)
[ -n "$PID" ] && [ "$PID" -eq "$PID" ] 2>/dev/null || { echo "игра не запущена"; exit 3; }

LINES=$(wc -l < "$MOD/bench.log" 2>/dev/null || echo 0)
if [[ "$ROUTE" == *","* ]]; then echo "fly $ROUTE" > "$MOD/bench-cmd.txt"; else echo "fly $ROUTE" > "$MOD/bench-cmd.txt"; fi

# Ждём метку начала не дольше 60 с: мод висит на первой точке 30 с, пока мир подгружается (слово владельца 21:13 «постоять
# 30 секунд … только затем включать логи, запись видео и начинать пролёт») — PresentMon и видео стартуют ПОСЛЕ метки
DUR=""
for i in $(seq 1 120); do
  DUR=$(tail -n +$((LINES + 1)) "$MOD/bench.log" 2>/dev/null | grep -a -o "EV fly=start [0-9.]*" | head -1 | awk '{print $3}')
  [ -n "$DUR" ] && break
  sleep 0.5
done
[ -z "$DUR" ] && { echo "нет метки начала облёта:"; tail -n +$((LINES + 1)) "$MOD/bench.log" | tail -5; exit 4; }
SEC=$(python -c "import math;print(math.ceil(float('$DUR')))")
echo "облёт $ROUTE: $SEC с"

logman stop kumm-pm -ets >/dev/null 2>&1
"$PM" --process_id "$PID" --output_file "$CSV" --timed "$SEC" --terminate_after_timed --no_console_stats \
  --session_name kumm-pm --stop_existing_session > "$OUT/_pm.log" 2>&1 &
PMP=$!
if [ "$VIDEO" = "--video" ]; then
  ffmpeg -hide_banner -loglevel error -y -f lavfi -i "ddagrab=output_idx=0:framerate=60" -t "$SEC" \
    -c:v hevc_nvenc -preset p5 -tune hq -rc vbr -cq 20 -b:v 40M -maxrate 80M -bufsize 80M "$OUT/${STAMP}_${LABEL}.mkv" &
  VP=$!
fi
wait $PMP
[ "$VIDEO" = "--video" ] && wait $VP
python -I -X utf8 "D:/work/ai_sandbox/ConanExiles/_config/bench-report.py" "$CSV" "$LABEL" "$OUT/bench-journal.jsonl"
tail -n +$((LINES + 1)) "$MOD/bench.log" | grep -a -E "облёт|EV|ошибка" | tail -4
