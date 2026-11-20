#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# walk-mod-windows.sh <out_dir> <module>… — open each UI module of the build by the pult (GUIModuleController.ActivateModule), frame it in the
# background (capture-window.ps1), close it. Зачем (2026-10-26, KUMM план 35, кейсы U3–U6; владелец: «побегать агентом по миру, увидеть наши
# моды в поставке глазами»): окна настроек модов проверяются кадром — по-русски ли, не вылезает ли текст. Имена модулей — живая таблица
# DT_UIModuleTable (карта игры, «Модули интерфейса»). Кадр: <out_dir>/w_<module>.jpg; строка «<module> → ok/fail».
# [NOT-TESTED]
OUT="$1"; shift
export GAME="${GAME:-$GAME_FWD}"
cd "$(dirname "$0")"
mkdir -p "$OUT"
for m in "$@"; do
  r=$(bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('$m'), true, false); return 'open'" | tail -1)
  sleep 1.5
  timeout 50 powershell -NoProfile -ExecutionPolicy Bypass -File capture-window.ps1 -Out "$OUT/w_$m.jpg" -Width 1280 >/dev/null 2>&1
  bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('$m'), false, false); return 'close'" >/dev/null
  sleep 0.5
  echo "$m → $r"
done
