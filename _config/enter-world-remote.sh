#!/usr/bin/env bash
# enter-world-remote.sh — вход в мир из главного меню пультом KrinikAgentRemote, без мыши и без фокуса окна.
# Зачем: `-continuesession` и `open …?listen` не работают (HOUSE_RULES KUMM, строка пульта Конана); щелчок мышью отбирает экран
# у владельца (память «Конан: игра — в фоне»). Шаги: `dump B_Continue` → имена виджета меню и его дерева из dump.txt →
# `call <меню> <обработчик нажатия> <дерево>.B_Continue` → ждём `LoadMap(/Game/Maps/ConanSandbox` в журнале игры (≤ 180 с).
# Запуск — после launch-bg.ps1. Код 0 — мир загружен; 3 — нет меню за 120 с; 4 — мир не загрузился за 180 с.
# [NOT-TESTED]
set -u
GAME="$(python -I -X utf8 -c "import sys;sys.path.insert(0,r'D:\work\ai_sandbox\ConanExiles\_config');import game_target as g;print(g.GAME_DIR)")"
R="$GAME/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote"
LOG="$GAME/ConanSandbox/Saved/Logs/ConanSandbox.log"
HANDLER="BndEvt__W_MainMenu_MainMenu_B_Continue_K2Node_ComponentBoundEvent_11_SignalClicked__DelegateSignature"

# Одна команда пульта; ответ — по НОВОЙ строке в done.txt (≤ 10 с). Не по исчезновению cmd.txt: пульт удаляет cmd.txt ДО того, как
# выполнит команду и напишет dump.txt, — 2026-10-26 00:39 прибор прочёл dump.txt прошлого запуска, взял номер меню, которого ещё нет,
# и пульт дважды ответил «НЕ исполнено: call …» (игра висела в меню; так же 25.10 в 23:07 и 23:30 при запуске на переднем плане).
remote() {
  local n0; n0=$(wc -l < "$R/done.txt" 2>/dev/null || echo 0)
  echo "$1" > "$R/cmd.txt"
  for i in $(seq 1 20); do
    [ "$(wc -l < "$R/done.txt" 2>/dev/null || echo 0)" -gt "$n0" ] && return 0
    sleep 0.5
  done
  rm -f "$R/cmd.txt"; return 1
}

MENU=""; TREE=""
for i in $(seq 1 60); do
  if remote "dump B_Continue"; then
    # только кнопка живого меню, которую видно (образец класса — «Collapsed …:WidgetTree.B_Continue» — не годится)
    LINE=$(grep -a -E "^(Visible|SelfHitTestInvisible|HitTestInvisible) .*W_MainMenu_MainMenu_C_[0-9]+\.WidgetTree_[0-9]+\.B_Continue$" "$R/dump.txt" | head -1)
    MENU=$(echo "$LINE" | grep -o "W_MainMenu_MainMenu_C_[0-9]*" | head -1)
    TREE=$(echo "$LINE" | grep -o "WidgetTree_[0-9]*" | head -1)
    [ -n "$MENU" ] && [ -n "$TREE" ] && break
  fi
  sleep 2
done
[ -z "$MENU" ] && { echo "нет главного меню за 120 с"; exit 3; }
# Вход в мир под СВЁРНУТЫМ окном роняет игру: 2026-10-31 07:49 сборщик отзыва свернул игру, пульт нажал «Продолжить» — на «Starting Login»
# D3D12 «Dest width out of bounds … [8, 8, 1] … [1920, 1080, 1]», E_INVALIDARG, падение (KUMM testcases TC_conan_feedback_button M0; контроль без
# сворачивания вошёл). Игрок свёрнутое окно нажать не может — это путь только пульта. Свёрнутое окно разворачивается без захвата фокуса.
powershell -NoProfile -Command "Add-Type -Namespace KE -Name W -MemberDefinition '[DllImport(\"user32.dll\")] public static extern bool IsIconic(System.IntPtr h); [DllImport(\"user32.dll\")] public static extern bool ShowWindow(System.IntPtr h, int c);'; Get-Process ConanSandbox-Win64-Shipping -ErrorAction SilentlyContinue | Where-Object { [KE.W]::IsIconic(\$_.MainWindowHandle) } | ForEach-Object { [void][KE.W]::ShowWindow(\$_.MainWindowHandle, 4); 'restored minimized game window (SW_SHOWNOACTIVATE)' }"
sleep 1
# Нажатие повторяется, если загрузка не началась за 20 с: 2026-10-25 23:07 при запуске на переднем плане первое нажатие
# пришло раньше, чем меню было готово, — `PreLoadMap` в журнале не появился, мир не грузился 180 с; второе нажатие — мир за 30 с.
# (строка PreLoadMap пишется и при загрузке карты меню — считаем НОВЫЕ строки после нажатия)
N0=$(grep -a -c "PreLoadMap_Callback begin" "$LOG")
for try in 1 2 3; do
  remote "call $MENU $HANDLER $TREE.B_Continue" || { echo "пульт не взял команду call"; exit 3; }
  echo "нажато «Продолжить» ($try): $MENU $TREE"
  for i in $(seq 1 10); do [ "$(grep -a -c "PreLoadMap_Callback begin" "$LOG")" -gt "$N0" ] && break 2; sleep 2; done
done
# 2026-11-20 (KUMM issue #6, report testcases/reports/2026-11-20_conan-immortal-heroine-save.md): the SAVE keeps the hero's god mode across sessions — a run
# that switched it on (god-on.sh, stand-keeper.sh) and ended without `god-on.sh off` + a save left the owner's heroine immortal. Every agent entry reads the
# flag BEFORE any command of the run and says it aloud; the run ends with `god-on.sh off` and a save (the Esc menu's CloseAndReturnToMainMenu).
# [TESTED: 2026-11-20 20:27–20:29 · G4: «ВЫКЛ» → god on + save through the menu → the «ВНИМАНИЕ» line (red) → god off + save → «ВЫКЛ» · KUMM testcases/reports/2026-11-20_conan-immortal-heroine-save.md]
god_state() {
  local RES="$R/result.txt" s=""
  for _ in 1 2 3 4 5; do
    bash "$(dirname "$0")/pult.sh" 'lua local p=FindFirstOf("BasePlayerChar_C"); return p and p:IsValid() and tostring(p.bCanBeDamaged) or "no hero"' > /dev/null 2>&1
    s=$(tr -d '\r\n' < "$RES" 2>/dev/null)
    [ "$s" = "true" ] || [ "$s" = "false" ] && break
    sleep 2
  done
  case "$s" in
    true)  echo "режим бога в сохранении: ВЫКЛ (bCanBeDamaged=true)" ;;
    false) echo "ВНИМАНИЕ: в сохранении включён режим бога (bCanBeDamaged=false). Перед игрой владельца выключите его командой god-on.sh off и сохраните игру через меню." ;;
    *)     echo "режим бога: не прочитан ($s)" ;;
  esac
}
for i in $(seq 1 90); do
  grep -a -q "LoadMap(/Game/Maps/ConanSandbox" "$LOG" && { echo "мир загружен ($((i * 2)) с)"; god_state; exit 0; }
  sleep 2
done
echo "мир не загрузился за 180 с"; exit 4
