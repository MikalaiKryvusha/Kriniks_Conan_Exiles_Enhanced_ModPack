#!/usr/bin/env bash
# bench-batch.sh <файл шагов> — пачка облётов эталона в одном запуске игры: на каждом шаге — команды пульта, потом облёт с замером.
# Файл шагов: строка «метка<ТАБ>команда пульта; команда; …» (команды можно не писать); «#» — комментарий.
# Строка «#read <имена через пробел>» — перед первым шагом в журнал игры пишутся текущие значения этих переменных (exec без значения).
# Зачем: очередь владельца 2026-10-26 («Замеры ручек подгрузки … Ветка появления NPC … Эталон на чистой игре») — десятки облётов
# A-B-A; один прибор вместо ручных шагов, чтобы пачка шла сама, а итог одной таблицей лёг в отчёт.
# Игра — в мире (enter-world-remote.sh), замок машины взят, кино выключено (слово владельца действует до обратного, HOUSE_RULES §1).
# [NOT-TESTED]
set -u
STEPS="$1"
CFG=/d/work/ai_sandbox/ConanExiles/_config
GAME="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")"
R="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
LOG="$GAME/ConanSandbox/Saved/Logs/ConanSandbox.log"

remote() {   # одна команда пульта; готовность — новая строка done.txt (EXP-0333)
  local n0; n0=$(wc -l < "$R/done.txt" 2>/dev/null || echo 0)
  echo "$1" > "$R/cmd.txt"
  for i in $(seq 1 20); do [ "$(wc -l < "$R/done.txt")" -gt "$n0" ] && return 0; sleep 0.5; done
  rm -f "$R/cmd.txt"; echo "пульт не взял: $1"; return 1
}

# \r срезается: git на этой машине при извлечении пишет CRLF (core.autocrlf), и команда пульта получила бы «1\r»
STEPS_LF="$(mktemp)"; tr -d '\r' < "$STEPS" > "$STEPS_LF"; STEPS="$STEPS_LF"
VARS=$(grep -E "^#read " "$STEPS" | sed 's/^#read //')
for v in $VARS; do remote "exec $v" >/dev/null; done
sleep 1
for v in $VARS; do grep -a "\]$v = " "$LOG" | tail -1 | sed -E 's/^\[[^]]*\]\[[^]]*\]//'; done

grep -v -E "^[[:space:]]*(#|$)" "$STEPS" | while IFS=$'\t' read -r label cmds; do
  if [ -n "${cmds:-}" ]; then
    IFS=';' read -ra parts <<< "$cmds"
    for c in "${parts[@]}"; do c="$(echo "$c" | sed 's/^ *//;s/ *$//')"; [ -n "$c" ] && remote "$c" >/dev/null; done
    sleep 2
  fi
  bad0=$(grep -a -c "Undermesh teleport\|Delaying playing state" "$LOG")
  line=$(bash "$CFG/bench-flight.sh" krinik-show "$label" < /dev/null | sed -n 2p)
  bad1=$(grep -a -c "Undermesh teleport\|Delaying playing state" "$LOG")
  flag=""; [ "$bad1" -gt "$bad0" ] && flag="  ⚠ в окне облёта Undermesh/режим ожидания — облёт не засчитывать"
  echo "$line · команды: ${cmds:-—}$flag"
done
