#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# god-on.sh [on|off] — бессмертие героя пультом ПО СОСТОЯНИЮ, а не вслепую.
# Зачем (KUMM EXP-0381, 2026-10-30 11:26): прогоны «с бессмертием» шли через консольную `exec God`, а она в 3.0.1 НИЧЕГО не включает —
# герой был уязвим; босс оазиса убил героя, вещи остались на трупе; сейв владельца восстановлен из Game_0_backup_1.db (копия улики —
# Conan Exiles Mods/_save-backup/2026-10-30_1127-hero-died-in-agent-run). Прежде сказано «exec God выключил бессмертие» — неверно, исправлено.
# Консольная `exec God` в 3.0.1 НЕ доходит до менеджера читов (пульт отвечает «ok», bCanBeDamaged не меняется — замер 11:31);
# работает прямой вызов CheatManager:God(). Как: читает bCanBeDamaged героя; зовёт God() только если состояние не то; читает снова и выходит 0, только если стало нужное.
#   bash god-on.sh        # бессмертие ВКЛ   (код 0 — герой неуязвим)
#   bash god-on.sh off    # бессмертие ВЫКЛ  (код 0 — герой уязвим)
# Код 1 — состояние не совпало после переключения; 2 — пульт не ответил.
# [NOT-TESTED]
cd "$(dirname "$0")" || exit 2
WANT="${1:-on}"
RES="$GAME_UNIX/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"
state() {
  bash pult.sh 'lua return tostring(FindFirstOf("PlayerController").Pawn.bCanBeDamaged)' > /dev/null 2>&1 || return 2
  tr -d '\r\n' < "$RES"
}
s=$(state) || exit 2
need=true; [ "$WANT" = "off" ] && need=false
# bCanBeDamaged = false значит бессмертие ВКЛ
if { [ "$need" = true ] && [ "$s" = "true" ]; } || { [ "$need" = false ] && [ "$s" = "false" ]; }; then
  bash pult.sh 'lua FindFirstOf("PlayerController").CheatManager:God(); return "t"' > /dev/null 2>&1
  s=$(state) || exit 2
fi
if { [ "$need" = true ] && [ "$s" = "false" ]; } || { [ "$need" = false ] && [ "$s" = "true" ]; }; then
  echo "god $WANT: ok (bCanBeDamaged=$s)"; exit 0
fi
echo "god $WANT: FAILED (bCanBeDamaged=$s)"; exit 1
