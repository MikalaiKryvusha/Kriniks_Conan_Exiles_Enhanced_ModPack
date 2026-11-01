#!/usr/bin/env bash
# corpse-stand.sh [max_m] — a corpse near the hero for the corpse cases (KUMM plan 36 W6, W10a, W25), by the remote, one action per call.
#
# WHY. 2026-10-30 16:20 a corpse-stand attempt crashed the game: it looped FindAllOf('BaseBPCombat_C') — the ANCESTOR class of every character, class
# defaults included — and called GetOwner() on each (KUMM EXP-0386 / EXP-0387). The way that worked on 2026-10-28 (case R1): KillCharacter on the LIVE
# NPC itself. This script does only that:
#   1. find the nearest live humanoid NPC (FindAllOf('HumanoidNPCCharacter_C'), full name filtered: /Engine/Transient… or the level, never Default__ or
#      a template), not farther than max_m (default 30 m), report its name and distance — nothing is kept in _G (a dead actor is destroyed later);
#   2. a liveness check of the remote;
#   3. find the same NPC again by its name and call npc:KillCharacter(0, FText(''), hero, {}, 0.0, hero);
#   4. a liveness check; print the corpse's name.
# Exit: 0 killed · 2 no NPC within max_m · 3 the remote is silent (the game may be gone — close the crash window by PID, restore the save).
# [TESTED: 2026-10-30 · background run: 40 m → «no NPC» rc 2; 200 m → the oasis boss at 43.4 m killed, rc 0, the game alive, KillCharacterWithRagdoll in the log · KUMM testcases/reports/2026-10-30_conan-corpse-stand.md]
MAX_M="${1:-30}"
cd "$(dirname "$0")"
FILTER='local fn=x:GetFullName(); if not fn:find("Default__",1,true) and not fn:find(":WidgetTree",1,true) and not fn:find("_C_GEN_VARIABLE",1,true) then'
FIND="local p=FindFirstOf('BasePlayerChar_C'); local h=p:K2_GetActorLocation(); local best,bd; for _,x in ipairs(FindAllOf('HumanoidNPCCharacter_C') or {}) do $FILTER local ok,l=pcall(function() return x:K2_GetActorLocation() end); if ok and l then local d=math.sqrt((l.X-h.X)^2+(l.Y-h.Y)^2+(l.Z-h.Z)^2)/100; if d<=$MAX_M and (not bd or d<bd) then best,bd=x:GetFName():ToString(),d end end end end"
alive() { bash pult.sh "lua return 'alive'" | tail -1 | grep -q alive; }

r=$(bash pult.sh "lua $FIND; if not best then return 'none' end; return string.format('%s %.1f', best, bd)" | tail -1)
echo "nearest: $r"
case "$r" in none|"") echo "no NPC within ${MAX_M} m"; exit 2;; esac
alive || { echo "remote silent after the search"; exit 3; }
name="${r%% *}"
k=$(bash pult.sh "lua local p=FindFirstOf('BasePlayerChar_C'); local t; for _,x in ipairs(FindAllOf('HumanoidNPCCharacter_C') or {}) do if x:GetFName():ToString()=='$name' then t=x end end; if not t then return 'gone' end; t:KillCharacter(0, FText(''), p, {}, 0.0, p); return 'killed $name'" | tail -1)
echo "$k"
alive || { echo "remote silent after the kill"; exit 3; }
case "$k" in killed*) exit 0;; *) exit 2;; esac
