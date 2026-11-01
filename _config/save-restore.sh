#!/usr/bin/env bash
# save-restore.sh -- put a saved copy of the Conan single-player save back, SAFELY.
#
#   bash save-restore.sh "<backup dir with Game_0.db | path to a .db>"
#   bash save-restore.sh --check            # only: integrity of the live Game_0.db
#
# WHY. 2026-10-30 15:38 the game crashed in an agent run; the run copied ONLY Game_0.db back over the
# live one. The crash had left Game_0.db-wal (SQLite write-ahead log) beside it; at the next start the
# game replayed that stale log onto the restored file -> "database disk image is malformed", the menu's
# "Continue" said "No save game profiles found" and world entry died. A SQLite file is restored together
# with its -wal/-shm: they are DELETED before the copy, and the result is checked before the game runs.
#
# Exit: 0 restored and intact · 2 the game is running (close it by PID first) · 3 source missing or
# itself damaged · 4 restored file fails the check.
# [TESTED: 2026-10-30 · R1-R5 and world entry on both launch paths after a restore · KUMM testcases/reports/2026-10-30_conan-save-restore-wal.md]
set -u
SAVED="/d/Games/Conan Exiles 3.0.1/ConanSandbox/Saved"
LIVE="$SAVED/Game_0.db"
PY="python -I -X utf8"

# Read-only integrity check: immutable=1 keeps sqlite from creating -wal/-shm next to the file.
check() {
  $PY -c '
import sqlite3, sys, pathlib
p = pathlib.Path(sys.argv[1]).resolve().as_posix()
c = sqlite3.connect("file:" + p + "?mode=ro&immutable=1", uri=True)
print(c.execute("pragma integrity_check").fetchone()[0])
' "$1" 2>&1 | tail -1
}

if [ "${1:-}" = "--check" ]; then r=$(check "$LIVE"); echo "live save: $r"; [ "$r" = "ok" ] && exit 0 || exit 4; fi

SRC="${1:-}"
[ -d "$SRC" ] && SRC="$SRC/Game_0.db"
[ -f "$SRC" ] || { echo "no source save: $SRC"; exit 3; }
if tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH 2>/dev/null | grep -q ConanSandbox; then
  echo "the game is running - close it first (by PID)"; exit 2
fi
r=$(check "$SRC"); [ "$r" = "ok" ] || { echo "source save is damaged: $r"; exit 3; }

for s in -wal -shm -journal; do
  if [ -f "$LIVE$s" ]; then rm -f "$LIVE$s" && echo "removed stale Game_0.db$s"; fi
done
cp "$SRC" "$LIVE" || exit 4
cmp -s "$SRC" "$LIVE" || { echo "copy differs from the source"; exit 4; }
r=$(check "$LIVE"); echo "restored from $SRC · integrity: $r"
[ "$r" = "ok" ] && exit 0 || exit 4
