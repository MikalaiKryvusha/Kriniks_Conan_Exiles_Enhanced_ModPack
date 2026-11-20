#!/usr/bin/env bash
# snap.sh — one snapshot of the launcher against the local test feed (KUMM plan 54, cases F2–F6, L1).
#   bash snap.sh <out dir> <name> <dpi> [report] -- <feed.mjs args>
# Starts feed.mjs on a free port in the background, runs the launcher exe of <out dir> with KRINIK_LAUNCHER_SNAPSHOT=<out>/<name>.png;<dpi>[;report]
# and KRINIK_LAUNCHER_FEED, stops the feed by its PID, converts the PNG to WebP, prints the launcher log lines of this run and the feed's request log.
# The launcher log goes to <out dir>/tmp (TEMP of the run). Exit: the launcher's code.
# [NOT-TESTED]
set -u
OUT="$(cd "$1" && pwd -W)"; NAME="$2"; DPI="$3"; shift 3
REPORT=""; [ "${1:-}" = "report" ] && { REPORT=";report"; shift; }
[ "${1:-}" = "--" ] && shift
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT=$((20000 + RANDOM % 20000))
mkdir -p "$OUT/tmp"
node "$HERE/feed.mjs" --port "$PORT" --log "$OUT/tmp/feed_$NAME.log" "$@" &
FEED=$!
curl -s -o /dev/null --retry 10 --retry-connrefused --retry-delay 1 "http://127.0.0.1:$PORT/ready"   # the feed is up before the launcher asks
: > "$OUT/tmp/KrinikConanLauncher.log"
TEMP="$OUT/tmp" TMP="$OUT/tmp" KRINIK_LAUNCHER_FEED="http://127.0.0.1:$PORT/releases" KRINIK_LAUNCHER_SNAPSHOT="$OUT/$NAME.png;$DPI$REPORT" "$OUT/KrinikConanLauncher.exe"
RC=$?
kill "$FEED" 2>/dev/null
/c/Python314/python.exe D:/work/ai_sandbox/SvarogsDream/tools/to_webp.py "$OUT/$NAME.png" | tail -1
cat "$OUT/tmp/KrinikConanLauncher.log"
grep -v "/releases ua=curl" "$OUT/tmp/feed_$NAME.log" | tail -3
exit $RC
