#!/usr/bin/env bash
# corpse-prompt-shot.sh <tag> [outdir] — the corpse-prompt stand in one call (KUMM plan 36 W6, bug 70).
# The corpse is made BY CODE where we look (`[OWNER]` «убивай кодом» · 2026-10-30 21:13): the nearest live hostile HumanoidNPC within RADIUS_M
# (default 200) — its location is read BEFORE KillCharacter and kept in _G.__kc; the hero is put 150 cm from THAT point and the camera aimed at
# it. Bug 70: the old stand moved and aimed at the nearest `DismemberedBodySkeletalMesh_C` — any body piece in the world, often not the corpse
# just made — and the strip stopped appearing after 19:58. Steps: world entry → god mode → wildlife within 80 m removed → kill by code → move →
# 3 aim passes at the recorded point → corpse-loot-geom.sh noaim (4K frame, background). The game must already run (launch-bg.ps1).
# Exit: 0 strip in viewport · 1 no strip · 2 no NPC to kill. [NOT-TESTED]
TAG="${1:-shot}"; OUT="${2:-D:/Temp/claude/corpse-prompt}"; R="${RADIUS_M:-200}"
cd "$(dirname "$0")"
mkdir -p "$OUT"
bash enter-world-remote.sh 2>&1 | tail -1
bash god-on.sh 2>&1 | tail -1
bash pult.sh "lua local p=FindFirstOf('BasePlayerChar_C'); local h=p:K2_GetActorLocation(); local n=0; for _,x in ipairs(FindAllOf('Character') or {}) do local f=x:GetFullName(); if not f:find('Default__') and f:find('Wildlife') then local ok,l=pcall(function() return x:K2_GetActorLocation() end); if ok and l and math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2)<8000 then x:K2_DestroyActor(); n=n+1 end end end; return 'wildlife removed '..n" | tail -1
k=$(bash pult.sh "lua local p=FindFirstOf('BasePlayerChar_C'); local h=p:K2_GetActorLocation(); local best,bd,bl; for _,x in ipairs(FindAllOf('HumanoidNPCCharacter_C') or {}) do local f=x:GetFullName(); if not f:find('Default__') then local ok,l=pcall(function() return x:K2_GetActorLocation() end); if ok and l then local d=math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2+(l.Z-h.Z)^2)/100; if d<=$R and (not bd or d<bd) then best,bd,bl=x,d,l end end end end; if not best then return 'none' end; _G.__kc={X=bl.X,Y=bl.Y,Z=bl.Z}; local nm=best:GetFName():ToString(); best:KillCharacter(0, FText(''), p, {}, 0.0, p); return string.format('killed %s at %.1f m (%.0f %.0f %.0f)', nm, bd, bl.X, bl.Y, bl.Z)" | tail -1)
echo "$k"
case "$k" in killed*) ;; *) exit 2;; esac
sleep 3
bash pult.sh "lua local p=FindFirstOf('BasePlayerChar_C'); local c=_G.__kc; p:K2_SetActorLocation({X=c.X+150.0,Y=c.Y,Z=c.Z+20.0},false,{},false); return 'hero moved next to the kill'" | tail -1
sleep 2
for i in 1 2 3; do
  bash pult.sh "lua local pc=FindFirstOf('FunCombat_PlayerController_C'); local c=_G.__kc; local cam=pc.PlayerCameraManager:GetCameraLocation(); local dx,dy,dz=c.X-cam.X,c.Y-cam.Y,c.Z-40.0-cam.Z; pc:SetControlRotation({Pitch=math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy))),Yaw=math.deg(math.atan(dy,dx)),Roll=0.0}); return 'aim $i'" | tail -1
  sleep 0.5
done
r=$(OUT="$OUT" bash corpse-loot-geom.sh "$TAG" noaim 2>&1 | tail -1)
echo "$r"
case "$r" in *inViewport=true*) exit 0;; *) exit 1;; esac
