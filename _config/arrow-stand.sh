#!/usr/bin/env bash
. "$(dirname "${BASH_SOURCE[0]}")/game-target.sh"   # GAME_FWD / GAME_UNIX from targets.json (2026-11-13, KUMM plan 53)
# arrow-stand.sh <verb> [arg] — the archery stand by the remote, ONE remote call per verb (KUMM plan 36 W13, EXP-0405).
#
# WHY. Four stands of 2026-10-31 morning failed on the same rakes: «the nearest humanoid» was the hero's own companion (0.8 m, 6.2 m), an actor kept
# in _G read back 0 0 0, vectors read inside one call came back reused. Here the target is found by its CLASS on every call (never kept), every vector
# is copied into numbers at once, and the creature is placed in front of the camera — the camera is never turned by arithmetic.
#   bash arrow-stand.sh summon               # CheatManager:Summon of the class (default: adult green Kappa), prints «<name> <m>» of the nearest one
#   bash arrow-stand.sh place 8              # the target to 8 m straight ahead of the camera yaw, on the hero's ground height, facing the hero
#   bash arrow-stand.sh freeze | release     # CustomTimeDilation 0 / 1 on the target
#   bash arrow-stand.sh info                 # «<name> <m> td=<t>» of the target
#   CLASS=HumanoidNPCCharacter_C bash arrow-stand.sh info   # another class (careful: humanoids include the hero's companions)
# Exit: 0 ok · 1 the remote answered fail / no target · 2 the remote silent.
# [NOT-TESTED]
cd "$(dirname "$0")" || exit 2
VERB="${1:-info}"; ARG="${2:-}"
CLASS="${CLASS:-BP_NPC_Wildlife_Kappa_Green_C}"
CLASS_PATH="${CLASS_PATH:-/Game/Characters/NPCs/Primates/Blueprints/BP_NPC_Wildlife_Kappa_Green.BP_NPC_Wildlife_Kappa_Green_C}"
RES="$GAME_UNIX/ConanSandbox/Binaries/Win64/ue4ss/Mods/KrinikAgentRemote/result.txt"

# The nearest live instance of CLASS to the hero, class defaults and templates filtered (corpse-stand.sh); t = the actor, td = its distance in m.
# NAME=<actor name> pins the target: the Exiled Lands hold many wild Kappas (8 within 200 m of the oasis, 2026-10-31 11:03), one walked in mid-stand.
FIND="local p=FindFirstOf('BasePlayerChar_C'); local hl=p:K2_GetActorLocation(); local h={X=hl.X,Y=hl.Y,Z=hl.Z}; local t,td; for _,x in ipairs(FindAllOf('$CLASS') or {}) do local fn=x:GetFullName(); if not fn:find('Default__',1,true) and not fn:find('_C_GEN_VARIABLE',1,true) and ('${NAME:-}'=='' or x:GetFName():ToString()=='${NAME:-}') then local ok,l=pcall(function() local v=x:K2_GetActorLocation(); return {X=v.X,Y=v.Y,Z=v.Z} end); if ok and l then local d=math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2+(l.Z-h.Z)^2)/100; if not td or d<td then t,td=x,d end end end end"

call() { bash pult.sh "lua $1" > /dev/null; local rc=$?; [ -f "$RES" ] && tr -d '\r' < "$RES"; echo; return $rc; }

case "$VERB" in
  summon)
    call "FindFirstOf('PlayerController').CheatManager:Summon('$CLASS_PATH'); return 'summoned'" || exit $?
    sleep 10   # the owner 2026-10-31 11:33: «движок какое-то время грузит фигуру» · «дай секунд 10 загрузиться» (a summoned figure without its look reads as nothing)
    call "$FIND; if not t then return 'none' end; return string.format('%s %.1f', t:GetFName():ToString(), td)" ;;
  place)
    D="${ARG:-8}"
    call "$FIND; if not t then return 'none' end; local r=FindFirstOf('PlayerController'):GetControlRotation(); local yaw=math.rad(r.Yaw); local c={X=h.X+math.cos(yaw)*$D*100, Y=h.Y+math.sin(yaw)*$D*100, Z=h.Z}; t:K2_SetActorLocation(c,false,{},true); t:K2_SetActorRotation({Pitch=0,Yaw=r.Yaw+180,Roll=0},true); local n=t:K2_GetActorLocation(); return string.format('%s placed %.1f m ahead (yaw %.1f) at %.0f %.0f %.0f', t:GetFName():ToString(), $D, r.Yaw, n.X, n.Y, n.Z)" ;;
  freeze|release)
    TD=0; [ "$VERB" = release ] && TD=1
    call "$FIND; if not t then return 'none' end; t.CustomTimeDilation=$TD; return string.format('%s td=%s', t:GetFName():ToString(), tostring(t.CustomTimeDilation))" ;;
  info)
    # no health read: an unproven property name crashed UE4SS natively on 2026-10-31 (EXP-0403) — pcall does not catch it
    call "$FIND; if not t then return 'none' end; return string.format('%s %.1f m td=%s', t:GetFName():ToString(), td, tostring(t.CustomTimeDilation))" ;;
  *) echo "verbs: summon · place <m> · freeze · release · info"; exit 1 ;;
esac
