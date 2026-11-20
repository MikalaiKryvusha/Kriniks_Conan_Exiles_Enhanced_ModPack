#!/usr/bin/env bash
# loot-stand.sh — the WHOLE quick-loot stand in one command (KUMM bug 75): the oasis, noon, god, the nearest HUMANOID enemy killed (his corpse carries loot,
# so the quick-loot window opens by itself on a look — `[OWNER]` 2026-11-03 20:04 «окно квиклута показывается. когда есть что залутать из трупа»; a beast corpse
# never opens it), the hero 1.5 m from the body, the crosshair on its head. Then: bash loot-aim.sh (the game in front: Shift, aim, sweep by the game's answer), then bash loot-take-clip.sh <out.mkv> (SEQ without Shift).
# What paid for each step (2026-11-03 19:22–20:22, game map «When the quick-loot window opens», «The corpse / quick-loot stand»):
#  - a KAPPA corpse has no loot of its own; items put in by AddItemTemplate do not open the window → a humanoid (the oasis camp: boss + fighters, ≤ 250 m);
#  - the corpse component location is the death spot, the ragdoll lies off it → aim at a BONE; a female skeleton has 97 bones (bone 5 is an arm) → b_head;
#  - the view is our camera mod's → aim from PlayerCameraManager:GetCameraLocation(), 6 passes, the hero 1.5 m off (never on the body; 2026-11-03 21:12: from 3 m the window never opened, from 1.5 m the sweep hit at its step 27 — PickupInteractionDistance is 90);
#  - `exec TeleportPlayer` does nothing → K2_TeleportTo; quiet-stand first (crocodiles walk in).
# Exit: 0 ready · 1 no corpse · 2 the remote silent. [TESTED: 2026-11-03 20:13 · the boss «Эника из Киммерии», the window open with 7 items (frame), B1 clip ·
#  KUMM bugs/75 — by the same calls run one by one; this file as a whole: NOT-TESTED]
set -u
cd "$(dirname "$0")" || exit 2
P() { bash pult.sh "lua $1" | tail -1; }
bash god-on.sh > /dev/null 2>&1
P "FindFirstOf('BasePlayerChar_C'):K2_TeleportTo({X=-78166.0,Y=245999.0,Z=-15000.0},{Pitch=0.0,Yaw=0.0,Roll=0.0}); FindFirstOf('BP_TimeOfDayManager_C'):SetTimeOfDay(12.0); return 'oasis, noon'"
sleep 15
P "_G.__qs_radius=40; return dofile('D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')"
bash corpse-stand.sh 250 2>&1 | tail -1
sleep 5
P "_G.__qs_radius=40; return dofile('D:/work/ai_sandbox/ConanExiles/_config/quiet-stand.lua')"
for try in 1 2 3 4 5 6; do   # a fresh corpse is not ready at once — search again every 2 s
r=$(P "local hero=FindFirstOf('BasePlayerChar_C'); local h=hero:K2_GetActorLocation(); local best,bd,nm; for _,x in ipairs(FindAllOf('Corpse_C') or {}) do if not x:GetFullName():find('Default__',1,true) then local ok,m=pcall(function() return x:K2_GetComponentsByClass(StaticFindObject('/Script/Engine.SkeletalMeshComponent'))[1]:get() end); if ok and m and m:GetNumBones()>60 then local c=m:K2_GetComponentLocation(); for _,bn in ipairs({'b_head','b_neck_1','b_spine_3','b_spine_2'}) do local l=m:GetSocketLocation(FName(bn)); if l.X~=c.X or l.Y~=c.Y then local d=math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2); if math.abs(l.Z-h.Z)<3000 and (not bd or d<bd) then best,bd,nm={X=l.X,Y=l.Y,Z=l.Z},d,bn end; break end end end end end; if not best then return 'NO CORPSE' end; _G.__ls_body=best; local dx,dy=h.X-best.X,h.Y-best.Y; local len=math.max(1,math.sqrt(dx*dx+dy*dy)); hero:K2_TeleportTo({X=best.X+dx/len*150,Y=best.Y+dy/len*150,Z=best.Z+150},{Pitch=0.0,Yaw=math.deg(math.atan(-dy,-dx)),Roll=0.0}); return string.format('humanoid corpse (%s) at %.1f m, hero 1.5 m off', nm, bd/100)")
case "$r" in *"NO CORPSE"*) sleep 2;; *) break;; esac
done
echo "$r"
case "$r" in *"NO CORPSE"*) exit 1;; esac
sleep 3
for i in 1 2 3 4 5 6; do
  P "local pc=FindFirstOf('FunCombat_PlayerController_C'); local c=pc.PlayerCameraManager:GetCameraLocation(); local b=_G.__ls_body; local dx,dy,dz=b.X-c.X,b.Y-c.Y,b.Z-c.Z; pc:SetControlRotation({Pitch=math.deg(math.atan(dz,math.sqrt(dx*dx+dy*dy))),Yaw=math.deg(math.atan(dy,dx)),Roll=0.0}); return 'aim'" > /dev/null
  sleep 0.7
done
P "local pc=FindFirstOf('FunCombat_PlayerController_C'); local r=pc:GetControlRotation(); return string.format('ready: pitch %.1f yaw %.1f', r.Pitch, r.Yaw)"
