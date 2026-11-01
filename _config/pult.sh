#!/usr/bin/env bash
# pult.sh — одна команда пульту KrinikAgentRemote и её ответ: строка done.txt, затем dump.txt или result.txt, если команда их пишет.
# Зачем (2026-10-26, дымовой прогон модов): enter-world-remote.sh держит remote() внутри себя; прогону окон модов нужна та же
# команда снаружи, по одной на вызов. Готовность — НОВАЯ строка done.txt, не исчезновение cmd.txt (EXP-0333).
#   bash _config/pult.sh "lua return 1+1"        # печатает «<n> ok lua …» и содержимое result.txt
#   bash _config/pult.sh "dump W_Inventory"       # и dump.txt
# Код 0 — пульт ответил ok; 1 — ответил fail; 2 — молчал 10 с.
# [NOT-TESTED]
GAME="${GAME:-$(python -I -c "import sys; sys.path.insert(0, r'$(dirname "$0")'); import game_target; print(game_target.GAME_DIR)")}"
R="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
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
echo "пульт молчит 10 с"; exit 2
