#!/usr/bin/env bash
# pult.sh — одна команда пульту KrinikAgentRemote и её ответ: строка done.txt, затем dump.txt или result.txt, если команда их пишет.
# Зачем (2026-10-26, дымовой прогон модов): enter-world-remote.sh держит remote() внутри себя; прогону окон модов нужна та же
# команда снаружи, по одной на вызов. Готовность — НОВАЯ строка done.txt, не исчезновение cmd.txt (EXP-0333).
#   bash _config/pult.sh "lua return 1+1"        # печатает «<n> ok lua …» и содержимое result.txt
#   bash _config/pult.sh "dump W_Inventory"       # и dump.txt
# Код 0 — пульт ответил ok; 1 — ответил fail; 2 — молчал 10 с; 4 — игра не работает (нет процесса или висит окно отчёта о падении).
# [NOT-TESTED]
# cygpath -w (2026-11-07 07:4x): called by an absolute Git-Bash path (/d/work/…) the folder reached Windows Python as «/d/…», game_target was not found,
# GAME came out empty and the command went to «/ConanSandbox/…» — 40 lines of «No such file» and «пульт молчит»; a relative call worked.
GAME="${GAME:-$(python -I -c "import sys; sys.path.insert(0, r'$(cygpath -w "$(dirname "$0")")'); import game_target; print(game_target.GAME_DIR)")}"
[ -n "$GAME" ] || { echo "pult.sh: папка игры не найдена (game_target.py)"; exit 2; }
R="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
# Страж живой игры (2026-11-07 00:03, слово владельца: «заебал ты скрипты свои запускать без контроля того, работает игра, или нахуй упала к ебеням»):
# прогон 00:00 уронил игру, а серия команд шла дальше в пустоту. Перед КАЖДОЙ командой: процесс игры жив и окна отчёта о падении нет — иначе код 4 и
# строка «ИГРА НЕ РАБОТАЕТ»; вызывающая серия обязана остановиться на коде 4. Коды 0/1/2 прежние.
game_alive() {   # tasklist cuts the image name to 25 chars: match the prefix (2026-11-07 00:07 the live game read as dead)
  tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH 2>/dev/null | grep -qi "ConanSandbox-Win64-Shipp" || { echo "ИГРА НЕ РАБОТАЕТ: процесса ConanSandbox-Win64-Shipping нет (упала или закрыта)"; return 1; }
  if tasklist //FI "IMAGENAME eq CrashReportClient.exe" //NH 2>/dev/null | grep -qi "CrashReportClient"; then
    echo "ИГРА УПАЛА: открыто окно отчёта о падении (CrashReportClient) — закрыть по PID (HOUSE_RULES 9), серию остановить"; return 1
  fi
}
game_alive || exit 4
n0=$(wc -l < "$R/done.txt" 2>/dev/null || echo 0)
t0=$(date +%s)
echo "$1" > "$R/cmd.txt"
for i in $(seq 1 40); do
  if [ "$(wc -l < "$R/done.txt" 2>/dev/null || echo 0)" -gt "$n0" ]; then
    last=$(tail -1 "$R/done.txt" | tr -d '\r')
    echo "$last"
    verb=${1%% *}
    # при отказе файлы ответа — от прошлой команды: не печатать их как ответ (2026-10-26, отказ стража показал старый result.txt)
    case "$last" in *" ok "*) ;; *) exit 1 ;; esac
    case "$verb" in
      dump|funcs|props|find) cat "$R/dump.txt" ;;
      lua) cat "$R/result.txt" ;;
    esac
    case "$last" in *" ok "*) exit 0 ;; *) exit 1 ;; esac
  fi
  sleep 0.25
done
rm -f "$R/cmd.txt"
game_alive || exit 4     # молчание пульта часто значит, что игра упала посреди команды
echo "пульт молчит 10 с"; exit 2
