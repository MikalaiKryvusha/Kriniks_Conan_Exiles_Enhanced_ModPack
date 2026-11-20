#!/usr/bin/env bash
# sprint-cost-run.sh - KUMM bug 93 cost: sprint with the bow drawn by real input in chunks (owner-idle checked before each), the hero turned around between chunks.
# A test probe, not mod code. [TESTED: 2026-11-17 · four builds measured by it · KUMM testcases/reports/2026-11-17_conan-bow-sprint-cost.md]
#   bash sprint-cost-run.sh <chunks> <chunk_ms> <mode: draw|nodraw|idle>
set -u
N="$1"; MS="$2"; MODE="$3"
C=/d/work/ai_sandbox/ConanExiles/_config
cd "$C" || exit 2
for i in $(seq 1 "$N"); do
  powershell -NoProfile -File D:/work/ai_sandbox/_tools/owner-idle.ps1 > /dev/null || { echo "chunk $i: owner BUSY - stop"; exit 5; }
  bash pult.sh "lua local pc=FindFirstOf('FunCombat_PlayerController_C'); local p=pc:K2_GetPawn(); p:AdjustStaminaCurrent(200); local r=pc:GetControlRotation(); local y=(r.Yaw+180)%360; pc:SetControlRotation({Pitch=0,Yaw=y,Roll=0}); return 'yaw '..math.floor(y)" | tail -1 || exit 4
  case "$MODE" in
    draw)   SEQ="rdown,wait:900,kdown:W,kdown:0xA0,wait:$MS,kup:0xA0,kup:W,rup,wait:200" ;;
    nodraw) SEQ="kdown:W,kdown:0xA0,wait:$MS,kup:0xA0,kup:W,wait:200" ;;
    idle)   SEQ="wait:$MS" ;;
  esac
  powershell -NoProfile -File mouse-seq.ps1 -Seq "$SEQ" | tail -1
  echo "chunk $i done $(date +%H:%M:%S)"
done
