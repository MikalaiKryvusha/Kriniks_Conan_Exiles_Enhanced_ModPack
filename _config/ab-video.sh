#!/usr/bin/env bash
# ab-video.sh <out dir> <name> "<remote cmd A>" "<remote cmd B>" <labelA.txt> <labelB.txt> [cycles=5] [seconds=3]
# A-B video of a graphics option: the same still view, A for N s, B for N s, switched <cycles> times; the screen recorded at 60 fps (ddagrab -> hevc_nvenc),
# then each segment labelled with its option (the label text comes from a UTF-8 FILE — text travels through files, AGENT_GUIDE hygiene).
# Why (KUMM 2026-11-09, `[OWNER]` 17:11-17:13 «нужна не анимация, а видео» · «2 секунды одна опция. потом 2 - другая.» · «И так переключать раз 5. АБ сравнение» ·
# «только так идеально можно графику тестить»; HOUSE_RULES 11.6d).
# Needs: the game running, the stand set (camera, HUD as wanted), the owner away from the keyboard (game-front.ps1 refuses with exit 5 otherwise).
# Out: <out>/<name>.mp4 (labelled) and <out>/<name>_switches.txt (the moment of each switch, s from the recording start).
# Exit: 0 done · 4 the remote failed / the game is dead · 5 the owner at the keyboard · 6 the recording failed.
# [NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 4
OUT="$1"; NAME="$2"; CMD_A="$3"; CMD_B="$4"; LAB_A="$5"; LAB_B="$6"; CYCLES="${7:-5}"; SEC="${8:-3}"
mkdir -p "$OUT"
HDR=/d/work/ai_sandbox/SvarogsDream/tools/hdr.ps1
# switches by an ABSOLUTE schedule (target k = T0 + 1 + k*SEC): a remote call takes ≈ 1.2 s, and «call; sleep SEC» made 4.2-s segments and ran past the
# recording (2026-11-09 17:17, first run); the record covers the whole schedule + the last call's delay
TOTAL=$(( CYCLES * SEC * 2 + 4 ))
P() { bash pult.sh "$1" > /dev/null 2>&1; }
now() { date +%s.%N; }

FRONT=$(powershell -File game-front.ps1); RC=$?
[ "$RC" -eq 5 ] && { echo "владелец за клавиатурой — игру вперёд не вывожу"; exit 5; }
[ "$RC" -ne 0 ] && { echo "игра не вышла вперёд: $FRONT"; exit 4; }
PREV=$(echo "$FRONT" | awk '{print $2}')
powershell -File "$HDR" off > /dev/null 2>&1
P "$CMD_A" || exit 4
sleep 1

ffmpeg -hide_banner -loglevel error -y -f lavfi -i "ddagrab=output_idx=0:framerate=60" -t "$TOTAL" \
  -c:v hevc_nvenc -preset p5 -tune hq -rc vbr -cq 18 -b:v 60M -maxrate 120M -bufsize 120M "$OUT/$NAME.raw.mkv" &
VPID=$!
T0=$(now)
: > "$OUT/${NAME}_switches.txt"
k=0
for i in $(seq 1 "$CYCLES"); do
  for side in A B; do
    WAIT=$(awk -v t0="$T0" -v k="$k" -v s="$SEC" -v n="$(now)" 'BEGIN{w=t0+1+k*s-n; if (w<0) w=0; printf "%.3f", w}')
    sleep "$WAIT"
    if [ "$side" = A ]; then P "$CMD_A" || { kill $VPID; exit 4; }; else P "$CMD_B" || { kill $VPID; exit 4; }; fi
    echo "$side $(awk -v a="$(now)" -v b="$T0" 'BEGIN{printf "%.2f", a-b}')" >> "$OUT/${NAME}_switches.txt"
    k=$((k + 1))
  done
done
wait $VPID
powershell -File "$HDR" on > /dev/null 2>&1
[ -n "$PREV" ] && powershell -File game-front.ps1 -Restore "$PREV" > /dev/null 2>&1
[ -s "$OUT/$NAME.raw.mkv" ] || { echo "запись пуста"; exit 6; }

# labels: one drawtext per segment, enabled between this switch and the next; the text from the label files (copied next to the video, relative names)
cp "$LAB_A" "$OUT/labelA.txt"; cp "$LAB_B" "$OUT/labelB.txt"
FILTER=""
mapfile -t SW < "$OUT/${NAME}_switches.txt"
for k in "${!SW[@]}"; do
  set -- ${SW[$k]}; side=$1; t0=$2
  if [ $((k + 1)) -lt ${#SW[@]} ]; then set -- ${SW[$((k + 1))]}; t1=$2; else t1=$TOTAL; fi
  f=labelA.txt; [ "$side" = B ] && f=labelB.txt
  FILTER="${FILTER}drawtext=fontfile=arial.ttf:textfile=$f:fontsize=72:fontcolor=white:box=1:boxcolor=black@0.6:boxborderw=20:x=60:y=60:enable='between(t,$t0,$t1)',"
done
FILTER="${FILTER%,}"
cp /c/Windows/Fonts/arial.ttf "$OUT/arial.ttf"
( cd "$OUT" && ffmpeg -hide_banner -loglevel error -y -i "$NAME.raw.mkv" -vf "$FILTER" -c:v hevc_nvenc -preset p5 -cq 20 -tag:v hvc1 "$NAME.mp4" ) || exit 6
rm -f "$OUT/labelA.txt" "$OUT/labelB.txt" "$OUT/arial.ttf" "$OUT/$NAME.raw.mkv"
echo "video $OUT/$NAME.mp4"
cat "$OUT/${NAME}_switches.txt"
exit 0
