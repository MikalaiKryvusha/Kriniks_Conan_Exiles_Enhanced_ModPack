#!/usr/bin/env bash
# static-bench.sh <label> [seconds] — PresentMon on the running game for N seconds (default 60) while the camera stands still; prints the bench-report line
# and the CSV path. The journal row goes to `_bench/bench-journal.jsonl` like a flight's.
# Why (KUMM 2026-11-09, `[OWNER]` 00:07 «минуту стой - пиши FPS график» · «Померяем в среднем на статичных сценах в выборке по 5 сценам по минутному бенчу»):
# the reflection settings are compared on still water views, not on the fly-through.
# Needs: the game running (the remote not needed). Exit: 0 measured · 3 no game · 4 PresentMon wrote no CSV.
# [NOT-TESTED]
set -u
LABEL="$1"; SEC="${2:-60}"
OUT="D:/work/ai_sandbox/ConanExiles/_library/_bench"
PM="/d/work/ai_sandbox/_tools/PresentMon-2.5.1-x64.exe"
mkdir -p "$OUT"
CSV="$OUT/$(date +%Y-%m-%d_%H%M%S)_${LABEL}.csv"
PID=$(tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //FO CSV //NH | head -1 | cut -d'"' -f4)
[ -n "$PID" ] && [ "$PID" -eq "$PID" ] 2>/dev/null || { echo "игра не запущена"; exit 3; }
# Один захват за раз (EXP-0493, 2026-11-09 00:55): «остановленный» TaskStop'ом прогон жил дальше, и каждый захват с --stop_existing_session обрезал чужой до 7–39 с
# из 60. Живой PresentMon = чужой захват идёт: отказ, а не обрыв его сессии. Exit 5.
# @guard one-presentmon-at-a-time
# THREAT:         a second batch starts while a first (stopped by TaskStop, still alive) captures — both captures cut short, settings switched under each other
# PROVED-AGAINST: a PresentMon process left alive by hand (`--timed 120` in the background), then static-bench.sh — must print «уже идёт захват» and exit 5
# GAP:            a capture tool other than PresentMon-2.5.1-x64.exe is not seen
# ON-REAL-PATH:   NOT YET
if tasklist //FI "IMAGENAME eq PresentMon-2.5.1-x64.exe" //FO CSV //NH | grep -qi presentmon; then
  echo "уже идёт захват: PresentMon жив — второй замер не запускаю (ps -ef | grep -E 'bash|sleep|PresentMon')"; exit 5
fi
logman stop kumm-pm -ets >/dev/null 2>&1
"$PM" --process_id "$PID" --output_file "$CSV" --timed "$SEC" --terminate_after_timed --no_console_stats \
  --session_name kumm-pm --stop_existing_session > "$OUT/_pm.log" 2>&1
[ -s "$CSV" ] || { echo "PresentMon не записал CSV"; tail -3 "$OUT/_pm.log"; exit 4; }
python -I -X utf8 "D:/work/ai_sandbox/ConanExiles/_config/bench-report.py" "$CSV" "$LABEL" "$OUT/bench-journal.jsonl"
echo "csv $CSV"
