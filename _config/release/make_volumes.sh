#!/usr/bin/env bash
# make_volumes.sh — the release archive of the build: export → 7-Zip zip volumes ≤ 700 MB → unpack into a clean folder → the same files and hashes.
#   bash _config/release/make_volumes.sh <work dir on D:> [name]
# Plan 35 Г10: `[OWNER]` «пока ее разбиваем локально на архивы не более 700мб веса каждый, зип, чтобы побить на несколько малых архивов» · 2026-10-26.
# Eight mod paks are over 700 MB, so one-zip-per-volume cannot be done: a multi-volume zip without compression (paks are compressed by the engine),
# parts <name>.zip.001, .002 … — opened by 7-Zip or WinRAR from the first part (the README says so).
# Steps: (1) the game's config back to the pack's etalon (deploy-config.py — the live game holds the agent's run settings); (2) Deploy-ModPack.ps1 -Export
# with -ConfigFrom the game; (3) 7z a -tzip -mx0 -v700m; (4) every part ≤ 700 MiB; (5) 7z x the first part into <work>/check; (6) the file list and the
# SHA-256 of every file equal the export's. Exit 0 — volumes ready; 1 — a check failed; 2 — usage / tools. The game must be CLOSED.
# [NOT-TESTED]
set -u
WORK="${1:-}"; NAME="${2:-Krinik_Mod_Pack_0_9_0}"
[ -z "$WORK" ] && { echo "usage: make_volumes.sh <work dir> [name]"; exit 2; }
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
SEVEN="/c/Program Files/7-Zip/7z.exe"
GAME="D:/Games/Conan Exiles 3.0.1"
VOLUME=700m
LIMIT=$((700 * 1024 * 1024))
[ -x "$SEVEN" ] || { echo "no 7-Zip at $SEVEN"; exit 2; }
tasklist 2>/dev/null | grep -qi "ConanSandbox-Win64-Shipping" && { echo "the game is running - close it first"; exit 2; }
EXPORT="$WORK/$NAME"; OUTZ="$WORK/volumes"; CHECK="$WORK/check"
for d in "$EXPORT" "$OUTZ" "$CHECK"; do [ -e "$d" ] && { echo "$d exists - give an empty work dir"; exit 2; }; done
mkdir -p "$OUTZ" "$CHECK"
cd "$PACK" || exit 2
echo "1. etalon config"; /c/Python314/python.exe -X utf8 _config/deploy-config.py Game.ini GameUserSettings.ini || exit 1
echo "2. export"; powershell -NoProfile -File ../KUMM/Deploy-ModPack.ps1 -PackDir . -Export "$EXPORT" -ConfigFrom "$GAME" | tail -5 || exit 1
echo "3. volumes"; (cd "$WORK" && "$SEVEN" a -tzip -mx0 "-v$VOLUME" "$OUTZ/$NAME.zip" "$NAME" > "$WORK/7z-a.log") || { tail -5 "$WORK/7z-a.log"; exit 1; }
echo "4. sizes"; big=0
for f in "$OUTZ"/"$NAME".zip.*; do s=$(stat -c %s "$f"); [ "$s" -gt "$LIMIT" ] && { echo "TOO BIG $f $s"; big=1; }; done
ls -la "$OUTZ" | tail -n +2
[ $big = 0 ] || exit 1
echo "5. unpack"; "$SEVEN" x -y "-o$CHECK" "$OUTZ/$NAME.zip.001" > "$WORK/7z-x.log" || { tail -5 "$WORK/7z-x.log"; exit 1; }
echo "6. compare"; (cd "$EXPORT" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$WORK/export.sha"
(cd "$CHECK/$NAME" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$WORK/check.sha"
if cmp -s "$WORK/export.sha" "$WORK/check.sha"; then echo "OK: $(wc -l < "$WORK/export.sha") files, hashes equal"; exit 0; fi
diff "$WORK/export.sha" "$WORK/check.sha" | head -10; exit 1
