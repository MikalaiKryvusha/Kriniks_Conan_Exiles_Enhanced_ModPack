#!/usr/bin/env bash
# make_release.sh — the whole shipment of a build release by one command (KUMM plans/55 criterion 8 and R7; 2026-11-18): the version comes from modpack.json.
#   bash _config/release/make_release.sh <empty work dir on D:> [notes file]
# Steps: (1) the release notes carry the launcher's game marker «<!-- krinik-game: <gameVersion> CL-<n> -->» equal to the manifest (the launcher matches the
# release to the player's game by it; KrinikConanUpdates.cs Feed.Parse) — default notes: _config/release/draft_<v>/github_release_notes_<v>.md;
# (2) build-docs.py — the guide PDF and the launcher exe from the current sources; (3) make_volumes.sh with KRINIK_VOLUME_BYTES=RELEASE_PART — export,
# 7-Zip zip volumes of RELEASE_PART bytes (below GitHub's 2 GiB asset limit — one part size for GitHub and Nexus, so parts a player took from either site
# lie beside the launcher and are recognised), unpack into a clean folder, every hash equal; (4) the volumes ARE the release parts: moved into release/,
# no second 13 GB copy cut from them (the judge 2026-11-18, round 2, finding 2: the old `cat | split` doubled the peak disk use to ≈ 52 GB); the stream's
# SHA-256 printed, `7z t` on the first part; (5) the guide PDF and the launcher exe copied beside the parts; (6) SHA256SUMS.txt of every asset.
# Output: <work>/release/ — the assets to upload. Exit 0 — ready; 1 — a step failed; 2 — usage / tools. The game must be CLOSED (make_volumes.sh refuses).
# make_volumes.sh step 1 writes the pack's etalon Game.ini / GameUserSettings.ini into the working game (its backup is in _config/backup/<stamp>).
# pipefail: a step piped into `tail` fails with its own status — without it a failed build-docs.py passed as `tail`'s 0, and the previous launcher exe and
# guide PDF were shipped and signed (the judge 2026-11-18, round 2, finding 1).
# [NOT-TESTED]
set -uo pipefail
WORK="${1:-}"
[ -z "$WORK" ] && { echo "usage: make_release.sh <empty work dir> [notes file]"; exit 2; }
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
SEVEN="/c/Program Files/7-Zip/7z.exe"
PY=/c/Python314/python.exe
RELEASE_PART=1992294400   # 1.86 GiB: the part size of the 0.9.0 GitHub release (7 parts), below GitHub's 2 GiB limit per asset
V=$(cd "$PACK" && node -p "require('./modpack.json').packVersion")
GV=$(cd "$PACK" && node -p "require('./modpack.json').launcher.gameVersion")
CL=$(cd "$PACK" && node -p "(require('./modpack.json').builtFor.match(/CL-(\\d+)/) || [])[1] || ''")
# The parts' stem: dots AND hyphens become underscores — «0.9.1-RC1» → Krinik_Mod_Pack_0_9_1_RC1. The launcher accepts only Krinik_[A-Za-z0-9_]+ as a
# part stem and a bundle folder (KrinikConanUpdates.cs PART, KrinikConanLauncher.cs BUNDLE_NAME): a hyphen hid every RC part from it (the judge 2026-11-20,
# round 3, finding 1). The notes are the release X.Y.Z's: an RC uses the notes of its release (draft_0_9_1/…). [NOT-TESTED]
NAME="Krinik_Mod_Pack_$(printf '%s' "$V" | tr '.-' '__')"
# A version with «+metadata» (ReleaseNumber accepts it) would give a stem the launcher rejects (the judge 2026-11-20, round 4, finding 9). [TESTED: 2026-11-20 · 0.9.1-RC1 passes, 0.9.1+b.5 refused (t_release A1, A2) · KUMM testcases/reports/2026-11-20_conan-launcher-judge4-fixes.md]
[[ $NAME =~ ^Krinik_[A-Za-z0-9_]+$ ]] || { echo "packVersion «$V» gives the part stem «$NAME», which the launcher does not accept (Krinik_[A-Za-z0-9_]+)"; exit 2; }
XYZ=$(printf '%s' "$V" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+' | tr '.' '_')
[ -n "$XYZ" ] || { echo "packVersion «$V» does not start with X.Y.Z"; exit 2; }
NOTES="${2:-$PACK/_config/release/draft_${XYZ}/github_release_notes_${XYZ}.md}"
[ -n "$CL" ] || { echo "no CL in builtFor of modpack.json"; exit 2; }
MARK="<!-- krinik-game: $GV CL-$CL -->"
echo "release $V for game $GV (CL-$CL) · $NAME · notes $NOTES"

echo "1. the notes carry the game marker"
[ -f "$NOTES" ] || { echo "no notes file $NOTES"; exit 1; }
grep -qF "$MARK" "$NOTES" || { echo "the notes lack «$MARK»"; exit 1; }
other=$(grep -o "krinik-game:[^>]*" "$NOTES" | grep -v -F "krinik-game: $GV CL-$CL" || true)
[ -z "$other" ] || { echo "the notes carry another marker: $other"; exit 1; }
# RC1, RC2 and the release share one notes file (draft_X_Y_Z): notes that name the parts of another release would send players to files that do not
# exist (the judge 2026-11-20, round 4, finding 4). [TESTED: 2026-11-20 · the RC1 notes pass for RC1, refused for RC2 (t_release B1, B2) · KUMM testcases/reports/2026-11-20_conan-launcher-judge4-fixes.md]
stems=$(grep -oE 'Krinik_Mod_Pack_[A-Za-z0-9_]+' "$NOTES" | sort -u | grep -vxF "$NAME" || true)
[ -z "$stems" ] || { echo "the notes name the parts of another release: $stems (this release: $NAME)"; exit 1; }
# A placeholder left in the guide would be printed into the PDF and shipped inside the archive (the judge 2026-11-20, round 4, finding 1). [TESTED: 2026-11-20 · a guide with {{ARCHIVE_SIZE}} refused, a clean one passes (t_release B3, B1) · KUMM testcases/reports/2026-11-20_conan-launcher-judge4-fixes.md]
GUIDE_HTML="$PACK/docs/guide/guide-$GV.html"
[ -f "$GUIDE_HTML" ] || { echo "no guide source $GUIDE_HTML"; exit 1; }
left=$(grep -oE '\{\{[A-Z_]+\}\}' "$GUIDE_HTML" | sort -u || true)
[ -z "$left" ] || { echo "the guide still holds placeholders: $left"; exit 1; }

echo "1b. the mod-list fields of the Krinik paks in the working game (KUMM HOUSE_RULES 40)"
# The working game is what the author plays and looks at: a Krinik pak there with an empty author, author URL or change note — or another release's
# change note — stops the release before anything is built (it stood after build-docs.py until the judge's round 3). The export gets the same check in
# make_volumes.sh step 2c. [NOT-TESTED]
. "$PACK/_config/game-target.sh"
"$PY" -I -X utf8 "$PACK/_config/devkit/set-pak-modinfo.py" "$GAME_FWD/ConanSandbox/Mods" --check-krinik || exit 1

echo "2. guide PDF and launcher"
(cd "$PACK" && "$PY" -X utf8 _config/release/build-docs.py) | tail -3 || exit 1
GUIDE="$PACK/$(cd "$PACK" && node -p "require('./modpack.json').guide")"
LAUNCHER="$PACK/_config/launcher/bin/KrinikConanLauncher.exe"
[ -f "$GUIDE" ] && [ -f "$LAUNCHER" ] || { echo "no guide PDF or launcher after build-docs.py"; exit 1; }

echo "3. volumes of $RELEASE_PART bytes (the release parts)"
KRINIK_VOLUME_BYTES=$RELEASE_PART bash "$PACK/_config/release/make_volumes.sh" "$WORK" "$NAME" || exit 1

echo "4. release parts"
REL="$WORK/release"; mkdir -p "$REL" || exit 1
mv "$WORK/volumes/$NAME".zip.[0-9][0-9][0-9] "$REL/" || exit 1
a=$(cat "$REL/$NAME".zip.[0-9][0-9][0-9] | sha256sum | cut -c1-64) || exit 1
"$SEVEN" t "$REL/$NAME.zip.001" > "$WORK/7z-t.log" || { tail -5 "$WORK/7z-t.log"; exit 1; }
echo "stream $a · $(ls "$REL/$NAME".zip.[0-9][0-9][0-9] | wc -l) parts · 7z t OK"

echo "4b. the notes of the release page with the archive's size"
# The total size of the parts is known only now: {{ARCHIVE_SIZE}} (the Russian half, decimal comma) and {{ARCHIVE_SIZE_EN}} (the English half) are filled
# in a COPY of the notes in the work folder (not in release/) — the draft stays the template for the next RC. The unit is the one Windows shows (1 ГБ = 2^30 bytes),
# so the number matches the free space the player sees. No placeholder may be left (the judge 2026-11-20, round 4, finding 1: nothing filled it). The
# public README gets the same two values: KRINIK_ARCHIVE_SIZE / KRINIK_ARCHIVE_SIZE_EN for mods-table.mjs, printed below. [NOT-TESTED]
bytes=$(stat -c %s "$REL/$NAME".zip.[0-9][0-9][0-9] | awk '{ s += $1 } END { printf "%d", s }') || exit 1
[ "${bytes:-0}" -gt 0 ] || { echo "the parts' size could not be read"; exit 1; }
EN_SIZE="$(awk -v b="$bytes" 'BEGIN { printf "%.1f", b / 1073741824 }') GB"
RU_SIZE="$(printf '%s' "${EN_SIZE% GB}" | tr '.' ',') ГБ"
OUT_NOTES="$WORK/release_notes_$NAME.md"
sed -e "s|{{ARCHIVE_SIZE}}|$RU_SIZE|g" -e "s|{{ARCHIVE_SIZE_EN}}|$EN_SIZE|g" "$NOTES" > "$OUT_NOTES" || exit 1
left=$(grep -oE '\{\{[A-Z_]+\}\}' "$OUT_NOTES" | sort -u || true)
[ -z "$left" ] || { echo "the notes still hold placeholders: $left"; exit 1; }
echo "archive $bytes bytes · RU «$RU_SIZE» · EN «$EN_SIZE» · notes for the release page: $OUT_NOTES"
echo "README: KRINIK_ARCHIVE_SIZE='$RU_SIZE' KRINIK_ARCHIVE_SIZE_EN='$EN_SIZE' node _config/public_release/mods-table.mjs . _config/public_release/README.template.md _config/public_release/README.draft.md"

echo "5. guide and launcher beside the parts"
cp "$GUIDE" "$LAUNCHER" "$REL/" || exit 1

echo "6. SHA256SUMS.txt"
(cd "$REL" && sha256sum -- * | grep -v SHA256SUMS > SHA256SUMS.txt)
cat "$REL/SHA256SUMS.txt"
ls -la "$REL"
echo "OK: release $V in $REL"
