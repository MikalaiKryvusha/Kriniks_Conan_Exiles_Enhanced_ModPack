#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/../game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# make_volumes.sh — the release archive of the build: export → 7-Zip zip volumes ≤ 700 MB → unpack into a clean folder → the same files and hashes.
#   bash _config/release/make_volumes.sh <work dir on D:> [name]
# Plan 35 Г10: `[OWNER]` «пока ее разбиваем локально на архивы не более 700мб веса каждый, зип, чтобы побить на несколько малых архивов» · 2026-10-26.
# Eight mod paks are over 700 MB, so one-zip-per-volume cannot be done: a multi-volume zip without compression (paks are compressed by the engine),
# parts <name>.zip.001, .002 … — opened by 7-Zip or WinRAR from the first part (the README says so).
# Steps: (1) the game's config back to the pack's etalon (deploy-config.py — the live game holds the agent's run settings); (2) Deploy-ModPack.ps1 -Export
# with -ConfigFrom the game; (3) 7z a -tzip -mx0 -v700m; (4) every part ≤ 700 MiB; (5) 7z x the first part into <work>/check; (6) the file list and the
# SHA-256 of every file equal the export's. Exit 0 — volumes ready; 1 — a check failed; 2 — usage / tools. The game must be CLOSED.
# Step 1 OVERWRITES the live game's Game.ini / GameUserSettings.ini (backup in _config/backup/<stamp>): after a release run on the owner's working game, copy
# them back from that backup (release 0.9.0, 2026-11-02 — restored by hand).
# Other part sizes without a new export: a 7-Zip zip volume is a plain byte cut of one zip, so `cat <name>.zip.0?? | split -b <bytes> -d -a 3
# --numeric-suffixes=1 - <name>.zip.` gives the same archive in new parts (0.9.0 in three, 2026-11-03: SHA-256 of the stream equal, `7z t` OK).
# GitHub release assets must be under 2 GiB each — parts for GitHub stay below that.
# [TESTED: 2026-11-02 · two runs, 19 parts, «OK: 241 files, hashes equal» · KUMM testcases/reports/2026-11-02_conan-release-0.9.0.md]
# pipefail: the export and the mod-list step are piped into `tail` — without it their failure passed as `tail`'s 0 and the script zipped whatever lay in
# the export folder (the judge 2026-11-18, round 2, finding 1).
set -uo pipefail
WORK="${1:-}"; NAME="${2:-}"
[ -z "$WORK" ] && { echo "usage: make_volumes.sh <work dir> [name]"; exit 2; }
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
# The default name — Krinik_Mod_Pack_<packVersion of the manifest, dots as underscores>: the launcher finds the parts by it (was the constant 0_9_0,
# KUMM plans/55 R1, 2026-11-18).
# Dots AND hyphens become underscores («0.9.1-RC1» → 0_9_1_RC1): the launcher's part and bundle patterns are Krinik_[A-Za-z0-9_]+ (the judge 2026-11-20,
# round 3, finding 1).
[ -z "$NAME" ] && NAME="Krinik_Mod_Pack_$(cd "$PACK" && node -p "require('./modpack.json').packVersion.replace(/[.-]/g, '_')")"
SEVEN="/c/Program Files/7-Zip/7z.exe"
GAME="$GAME_FWD"
# Part size: 700 MiB by default; make_release.sh asks for the release part size (KRINIK_VOLUME_BYTES) so the volumes ARE the release parts — no second copy of
# 13 GB (the owner 2026-11-18 18:55 asked why the release needed 50 GB).
VOLUME_BYTES=${KRINIK_VOLUME_BYTES:-$((700 * 1024 * 1024))}
VOLUME="${VOLUME_BYTES}b"
LIMIT=$VOLUME_BYTES
[ -x "$SEVEN" ] || { echo "no 7-Zip at $SEVEN"; exit 2; }
# grep without -q reads the whole list: under pipefail `grep -q` exits at the first match, tasklist may die of SIGPIPE, and the pipeline's non-zero status
# would skip the refusal while the game runs. The CSV form: tasklist's table cuts an image name to 25 characters («ConanSandbox-Win64-Shippi»), so the
# full name never matched and the refusal never fired (the judge 2026-11-20, round 3, finding 2). Git Bash needs «//» for a Windows switch. [NOT-TESTED]
tasklist //FO CSV //NH 2>/dev/null | grep -i '^"ConanSandbox' > /dev/null && { echo "the game is running - close it first"; exit 2; }
EXPORT="$WORK/$NAME"; OUTZ="$WORK/volumes"; CHECK="$WORK/check"
for d in "$EXPORT" "$OUTZ" "$CHECK"; do [ -e "$d" ] && { echo "$d exists - give an empty work dir"; exit 2; }; done
mkdir -p "$OUTZ" "$CHECK"
cd "$PACK" || exit 2
echo "1. etalon config"; /c/Python314/python.exe -X utf8 _config/deploy-config.py Game.ini GameUserSettings.ini || exit 1
echo "2. export"; powershell -NoProfile -File ../KUMM/Deploy-ModPack.ps1 -PackDir . -Export "$EXPORT" -ConfigFrom "$GAME" | tail -5 || exit 1
# 2b (2026-11-03, KUMM plan 44 step 3): the fields of the game's mod list (description, author, URL, change note) from the README table, in the export's paks.
echo "2b. mod list fields"; /c/Python314/python.exe -I -X utf8 _config/devkit/set-pak-modinfo.py "$EXPORT" --work "$WORK/modinfo-work" | tail -3 || exit 1
# 2c (KUMM HOUSE_RULES 40): every Krinik pak of the export carries the author, the author URL and this release's change note — before the zip. [NOT-TESTED]
echo "2c. Krinik mod-list fields"; /c/Python314/python.exe -I -X utf8 _config/devkit/set-pak-modinfo.py "$EXPORT" --check-krinik || exit 1
echo "3. volumes";(cd "$WORK" && "$SEVEN" a -tzip -mx0 "-v$VOLUME" "$OUTZ/$NAME.zip" "$NAME" > "$WORK/7z-a.log") || { tail -5 "$WORK/7z-a.log"; exit 1; }
echo "4. sizes"; big=0
for f in "$OUTZ"/"$NAME".zip.*; do s=$(stat -c %s "$f"); [ "$s" -gt "$LIMIT" ] && { echo "TOO BIG $f $s"; big=1; }; done
ls -la "$OUTZ" | tail -n +2
[ $big = 0 ] || exit 1
echo "5. unpack"; "$SEVEN" x -y "-o$CHECK" "$OUTZ/$NAME.zip.001" > "$WORK/7z-x.log" || { tail -5 "$WORK/7z-x.log"; exit 1; }
echo "6. compare"; (cd "$EXPORT" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$WORK/export.sha"
(cd "$CHECK/$NAME" && find . -type f -print0 | sort -z | xargs -0 sha256sum) > "$WORK/check.sha"
if cmp -s "$WORK/export.sha" "$WORK/check.sha"; then echo "OK: $(wc -l < "$WORK/export.sha") files, hashes equal"; exit 0; fi
diff "$WORK/export.sha" "$WORK/check.sha" | head -10; exit 1
