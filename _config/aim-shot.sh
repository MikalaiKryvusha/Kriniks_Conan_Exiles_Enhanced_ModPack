#!/usr/bin/env bash
# aim-shot.sh [hold_ms] — ОДИН настоящий выстрел из лука проверенной последовательностью и вердикт по журналу KrinikConanArchery.
# Зачем (2026-10-31, KUMM EXP-0416 / EXP-0405, класс stale-stand): вечерний стенд придумывал «открывающие» нажатия (`kdown 1`, средняя кнопка,
# `I`) и решил, что мод не входит в прицел; утренняя голая последовательность «ПКМ — пауза — ЛКМ — отпустить ПКМ» работает и после окна
# настроек. Стенд берёт её отсюда и не изобретает свою. Лук должен быть в руке (быстрый слот 1 у сейва владельца).
#   bash _config/aim-shot.sh          # натяжка 1500 мс
#   bash _config/aim-shot.sh 800      # короче натяжка
# Код: 0 — в журнале есть вход в прицел и выстрел; 1 — нет (печатает последние строки мода); 2 — нет журнала.
# [TESTED: 2026-10-31 23:28 · живая игра: выстрел — «вход в прицел: 1 · выстрелов: 1», код 0; контроль с открытым инвентарём — 0 · 0, код 1]
HOLD="${1:-1500}"
cd "$(dirname "$0")" || exit 2
GAME="${GAME:-$(python -I -c "import sys; sys.path.insert(0, '.'); import game_target; print(game_target.GAME_DIR)")}"
L="$GAME/ConanSandbox/Binaries/Win64/ue4ss/UE4SS.log"
[ -f "$L" ] || { echo "нет журнала $L"; exit 2; }
n0=$(wc -l < "$L")
sleep 3   # the bow settles after its equip input (it was a 3-s input-idle wait before the owner cancelled the busy-keyboard rules)
powershell -File mouse-seq.ps1 -Seq "rdown,wait:$HOLD,lclick,wait:400,rup,wait:500" >/dev/null
sleep 1
# Признаки — строки, которые пишутся при КАЖДОМ выстреле. «прицел: обзор» и «#N из лука, заряд» мод лука пишет только первые CFG.log_shots = 10 раз за
# сессию: с одиннадцатого выстрела скрипт отвечал «0 · 0» на настоящие попадания (KUMM 2026-11-21 23:01, кейс R24b, EXP-0606). Вход в прицел — строка
# KrinikConanCamera «прицел лука: вход»; выстрел — строка мода лука «стрела упала» (одна на стрелу), а без неё — старая «из лука, заряд».
# [TESTED: 2026-11-21 23:10 · живая игра, 13-й+ выстрел сессии: «вход в прицел: 1 · выстрелов: 1», код 0; контроль с открытым инвентарём — 0 · 0, код 1]
WIN=$(tail -n +"$((n0 + 1))" "$L")
NEW=$(echo "$WIN" | grep "KrinikConanArchery\]")
AIM=$(echo "$WIN" | grep -c -E "KrinikConanCamera\] прицел лука: вход|KrinikConanArchery\] прицел: обзор")
SHOT=$(echo "$NEW" | grep -c -E "\] стрела упала")   # one line per arrow (the mod writes «удар:» too, so «удар:» would count a shot twice)
[ "$SHOT" -eq 0 ] && SHOT=$(echo "$NEW" | grep -c "из лука, заряд")
echo "вход в прицел: $AIM · выстрелов: $SHOT"
if [ "$AIM" -ge 1 ] && [ "$SHOT" -ge 1 ]; then echo "$NEW" | grep -E "из лука, заряд|\] удар: |\] стрела упала" | tail -1 | cut -c30-200; exit 0; fi
echo "$NEW" | tail -5 | cut -c30-200
exit 1
