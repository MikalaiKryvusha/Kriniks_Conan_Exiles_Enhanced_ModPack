#!/usr/bin/env bash
# bench-scout.sh "<команда облёта>" <папка вывода> — разведочный облёт KrinikConanBench: кадр окна игры в фоне каждые ~2 с
# (имя — секунда полёта), строки `EV fly=prog` мода в prog.txt, затем листы кадров (bench-sheets.py).
#
# Зачем (EXP-0332): маршрут строится циклом «разведка → лист кадров по секундам → правка точек», высоты — по `gnd` из журнала,
# а не на глаз. Окно игры вперёд не выводится (capture-window.ps1 снимает его в фоне): владелец работает в браузере.
# Пример: bash _config/bench-scout.sh "fly krinik-show hold=5" "D:/Temp/.../scout-show2"
# Ожидание ограничено: метка начала — 60 с, сам облёт — MAX_S (пустые ждущие циклы над журналом запрещены, память владельца).
# [NOT-TESTED]
set -u
CMDLINE="$1"; O="$2"
MAX_S=300
GAME="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")"
B="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikConanBench"
CFG="D:/work/ai_sandbox/ConanExiles/_config"
mkdir -p "$O"; rm -f "$O"/t*.jpg "$O"/sheet*.webp "$O"/lst*.txt
# игра должна идти: 2026-10-25 вечером разведка без игры 300 с снимала несуществующее окно (Get-Process на каждом кадре)
tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //FO CSV //NH | grep -q "ConanSandbox" || { echo "игра не запущена"; exit 3; }
L=$(wc -l < "$B/bench.log")
echo "$CMDLINE" > "$B/bench-cmd.txt"
for i in $(seq 1 120); do tail -n +$((L + 1)) "$B/bench.log" | grep -a -q "EV fly=start" && break; sleep 0.5; done
tail -n +$((L + 1)) "$B/bench.log" | grep -a -q "EV fly=start" || { echo "нет метки начала облёта за 60 с:"; tail -n +$((L + 1)) "$B/bench.log" | tail -3; exit 4; }
T0=$(date +%s)
while ! tail -n +$((L + 1)) "$B/bench.log" | grep -a -q "EV fly=done"; do
  t=$(( $(date +%s) - T0 ))
  powershell -NoProfile -File "$CFG/capture-window.ps1" -Out "$(cygpath -w "$O")/t$(printf %03d $t).jpg" -Width 960 > /dev/null
  sleep 1
  [ $t -gt $MAX_S ] && { echo "облёт не кончился за $MAX_S с"; break; }
done
tail -n +$((L + 1)) "$B/bench.log" | grep -a -E "облёт|EV fly=(start|done)|ошибка"
tail -n +$((L + 1)) "$B/bench.log" | grep -a "EV fly=prog" > "$O/prog.txt"
python -I -X utf8 "$CFG/bench-sheets.py" "$O"
