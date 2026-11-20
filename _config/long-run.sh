#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# long-run.sh <минут> <метка> — долгий прогон сборки (KUMM план 35, критерий 1 «прогон ≥ 1 ч без падений»): облёты krinik-show по кругу
# (bench-flight.sh, PresentMon в фоне, без видео), между облётами — хаб открыть/закрыть (пауза KrinikPauseGameInMenu), пока не выйдет срок.
# Игра уже в мире, замок машины взят. В конце — сводка: новые папки Saved/Crashes, жив ли процесс, ошибки Lua в UE4SS.log с начала прогона.
# Журнал не «ждётся» циклом: прогон — это действия, журнал читается один раз в конце (память no-blocking-log-wait-loops).
# [NOT-TESTED]
MIN="$1"; TAG="$2"
export GAME="${GAME:-$GAME_FWD}"
cd "$(dirname "$0")"
CR="$GAME/ConanSandbox/Saved/Crashes"
U="$GAME/ConanSandbox/Binaries/Win64/ue4ss/UE4SS.log"
crashes0=$(ls "$CR" | wc -l)
ulines0=$(wc -l < "$U")
t0=$(date +%s); end=$((t0 + MIN * 60)); i=0
echo "start $(date '+%H:%M:%S') · срок $MIN мин · падений в папке $crashes0"
while [ "$(date +%s)" -lt "$end" ]; do
  i=$((i + 1))
  if ! tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH | grep -q Conan; then echo "$(date '+%H:%M:%S') ПРОЦЕСС ИГРЫ ИСЧЕЗ"; break; fi
  bash bench-flight.sh krinik-show "${TAG}-$i" > "/tmp/long-run-$i.txt" 2>&1
  echo "$(date '+%H:%M:%S') облёт $i: $(tail -1 "/tmp/long-run-$i.txt" | cut -c1-120)"
  bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('CharacterInventory'), true, false); return 'hub'" > /dev/null
  sleep 5
  bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('CharacterInventory'), false, false); return 'closed'" > /dev/null
done
crashes1=$(ls "$CR" | wc -l)
alive=$(tasklist //FI "IMAGENAME eq ConanSandbox-Win64-Shipping.exe" //NH | grep -c Conan)
echo "end $(date '+%H:%M:%S') · облётов $i · новых падений $((crashes1 - crashes0)) · процесс жив: $alive"
# Окно отчёта о падении нашего прогона — закрыть по PID (HOUSE_RULES §1, слово владельца 2026-10-26 ≈19:39)
if [ "$crashes1" -gt "$crashes0" ]; then
  powershell -NoProfile -ExecutionPolicy Bypass -File close-crash-reporter.ps1 -Since "$(date -d "@$t0" '+%Y-%m-%d %H:%M:%S')"
fi
tail -n +"$ulines0" "$U" | grep -a -i -E 'ошибк|упал|error' | grep -v -E 'СБОРКА|ЗУМ' | cut -c1-200 | sort | uniq -c | sort -rn | head -15
