#!/usr/bin/env bash
# craft-close-test.sh <N> [<seconds in the hub before closing>] [<fix lua>] — the hero crafts N items of a recipe that STARTED in the open hub; the hub is
# closed after the given real seconds; prints the count of finished items every 0.25 s for 15 s after the close.
# Why (KUMM bug 94, the owner 2026-11-13 09:46 «Я закрываю хаб - и они МГНОВЕННО изготавляются»): KrinikConanUI krinik_pause_in_menu slows the world to
# 0.03 in a full-screen menu and sets the hero's CraftTimeMultiplier 0.03; the game reads the multiplier at an item's START, so whatever started in the
# hub keeps a 0.03 duration after the close. Expected after a fix: after the close the items keep coming at the recipe's normal pace (twine 14174 ≈ 0.5 s
# each by craft-measure.sh's header), never a burst.
# The remote only — no real input. Ingredients: fibers 12001 are added to the backpack by the script. <fix lua> — an optional remote chunk run right after
# the close (a candidate fix to compare), e.g. "q:MulticastStartStop(false); q:MulticastStartStop(true)".
# [NOT-TESTED]
N="${1:-20}"; HOLD="${2:-1.0}"; FIX="${3:-}"
# The recipe: RECIPE / OUT / ING / ING_N from the environment. Default 14000 (inventory, TimeToCraft 10 s in RecipesTable, 3 × 14001 → 53000) — the twine
# 14174 (0.5 s) is too fast to see anything: 20 of them were done in 1.1 s with the hub CLOSED (2026-11-13; the build's craft time is also scaled).
RECIPE="${RECIPE:-14000}"; OUT="${OUT:-53000}"; FIBER="${ING:-14001}"; ING_N="${ING_N:-3}"
cd "$(dirname "$0")"
INV="local p=FindAllOf('BasePlayerChar_C')[1]; local me=p:GetFullName():match('[^.]+\$'); local bp,q,rm; for _,x in ipairs(FindAllOf('ItemInventory') or {}) do if x:IsValid() and x:GetFullName():find(me,1,true) then local n=x:GetFName():ToString(); if n=='BackpackInventory' then bp=x elseif n=='CraftingQueue' then q=x elseif n=='RecipeManager' then rm=x end end end"
# the result counted across ALL the hero's inventories: 53000 lands on the shortcut bar, not in the backpack (2026-11-13 — a backpack-only count read 0 for 10 done)
count() { bash pult.sh "lua local p=FindAllOf('BasePlayerChar_C')[1]; local me=p:GetFullName():match('[^.]+\$'); local s=0; for _,x in ipairs(FindAllOf('ItemInventory') or {}) do if x:IsValid() and x:GetFullName():find(me,1,true) and x:GetFName():ToString()~='CraftingQueue' then s=s+x:GetNumberOfItemsByTemplate($OUT) end end; return 'n='..s" 2>/dev/null | tail -1 | sed -n 's/.*n=\([0-9]*\).*/\1/p'; }
hub() { bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('CharacterInventory'), $1, false); return 'hub'" > /dev/null || exit 4; }
bash pult.sh "lua $INV; bp:AddItemTemplate($FIBER, -1, FName('None'), $((N * ING_N + ING_N)), false, 100.0, 0.0); return 'fibers'" > /dev/null || exit 4
hub true
sleep 2
n0=$(count)
bash pult.sh "lua $INV; local r=rm:GetItemByTemplateID($RECIPE, 0); local k=0; for i=1,$N do if q:CraftItems(r) then k=k+1 end end; return 'queued '..k..' mult '..tostring(q.CraftTimeMultiplier)" | tail -1
sleep "$HOLD"
echo "in the hub before the close: $(( $(count) - n0 )) done"
hub false
[ -n "$FIX" ] && bash pult.sh "lua $INV; $FIX; return 'fix done'" | tail -1
t0=$(date +%s.%N)
line="t0 n=$n0 |"
for i in $(seq 1 60); do
  n=$(count); t=$(awk "BEGIN{printf \"%.2f\", $(date +%s.%N) - $t0}")
  line="$line $t:$((n - n0))"
  [ "$((n - n0))" -ge "$N" ] && break
  sleep 0.25
done
echo "$line"
bash pult.sh "lua $INV; q.CraftTimeMultiplier=1.0; return 'mult reset'" > /dev/null
