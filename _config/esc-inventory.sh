#!/usr/bin/env bash
# esc_inventory.sh — plan 61 step 1 (2026-11-22 20:5x): every window of the «Настройки модов» list opened over the hub by the remote, a posted Esc
# (post-key.ps1, background), then: is the window still active, is a full-screen UI (the hub) still up. One line per module. Stops on a dead game (pult exit 4).
cd /d/work/ai_sandbox/ConanExiles/_config || exit 9
P() { bash pult.sh "$1" | tail -1; return "${PIPESTATUS[0]}"; }
MODS="KrinikModSettings ExilesFishingTuning AMR_Settings LLH_Settings PrP_Settings SM_UI_Settings DN_UI_Settings EmberlightMasterConfig EAA_Armorsettings HosavUIsettings LBPRWidgetID NightTerrorsSettings PIFC_Settings"
STATE="lua local g=FindFirstOf('GUIModuleController') return 'mod='..tostring(g:IsModuleActive(FName('%s')))..' fs='..tostring(g:IsFullscreenGUIActive())"
for m in $MODS; do
  st=$(P "$(printf "$STATE" "$m")") || { echo "$m: GAME DEAD"; exit 4; }
  case "$st" in *fs=false*) P "lua _G.__tab=0; return dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/open-tab.lua')" >/dev/null; sleep 2 ;; esac
  P "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('$m'), true, false); return 'open'" >/dev/null || { echo "$m: GAME DEAD"; exit 4; }
  sleep 1.5
  before=$(P "$(printf "$STATE" "$m")")
  powershell -NoProfile -ExecutionPolicy Bypass -File post-key.ps1 -Key Escape >/dev/null 2>&1
  sleep 1.2
  after=$(P "$(printf "$STATE" "$m")") || { echo "$m: GAME DEAD after Esc"; exit 4; }
  echo "$m · before Esc: $before · after Esc: $after"
  case "$after" in *mod=true*) P "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('$m'), false, false); return 'closed'" >/dev/null ;; esac
  sleep 0.8
done
echo "INVENTORY DONE"
