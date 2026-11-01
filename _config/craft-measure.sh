#!/usr/bin/env bash
# craft-measure.sh <множитель> [<рецепт> <результат> <хаб 1|0>] — замер крафта героя (KUMM план 35 Г12, план 36 п. 3, кейс P2).
# Хаб открыт (1) — пауза KrinikPauseGameInMenu, замедление мира 0.03; закрыт (0) — обычное время. Ставит CraftingQueue.CraftTimeMultiplier
# героя, ставит в очередь рецепт родным CraftingQueue:CraftItems(RecipeItem) (рецепт — из книги рецептов героя, GetItemByTemplateID(id, 0))
# и раз в секунду считает результат в рюкзаке — сколько секунд НАСТОЯЩЕГО времени до готового. Ограничено 90 с; в конце хаб закрыт,
# множитель 1. По умолчанию — «Бечевка» из инвентаря (№14174: 3 волокна 12001, 0,5 с). Нужно: игрок в мире, ингредиенты в рюкзаке
# (exec MakeMeAdmin; exec SpawnItem <id> <n>).
# [TESTED: 2026-10-26 · «Бечевка», множитель 1, хаб открыт — craft=true, готово за 3,0 с · testcases/reports/2026-10-26_conan-plan36-batch1.md]
MULT="${1:-1}"; RECIPE="${2:-14174}"; OUT="${3:-14174}"; HUB="${4:-1}"
cd "$(dirname "$0")"
INV="local p=FindFirstOf('BasePlayerChar_C'); local bp,q,rm; for _,x in ipairs(FindAllOf('ItemInventory') or {}) do if x:IsValid() and x:GetFullName():find(p:GetFullName():match('[^.]+\$'),1,true) then local n=x:GetFName():ToString(); if n=='BackpackInventory' then bp=x elseif n=='CraftingQueue' then q=x elseif n=='RecipeManager' then rm=x end end end"
count() { bash pult.sh "lua $INV; return 'n='..bp:GetNumberOfItemsByTemplate($OUT)" 2>/dev/null | tail -1 | sed -n 's/.*n=\([0-9]*\).*/\1/p'; }
hub() { bash pult.sh "lua FindFirstOf('GUIModuleController'):ActivateModule(FName('CharacterInventory'), $1, false); return 'hub'" > /dev/null; }
[ "$HUB" = 1 ] && hub true
sleep 2
n0=$(count)
t0=$(date +%s.%N)
start=$(bash pult.sh "lua $INV; q.CraftTimeMultiplier=$MULT; local r=rm:GetItemByTemplateID($RECIPE, 0); local ok=q:CraftItems(r); local gs=StaticFindObject('/Script/Engine.Default__GameplayStatics'); local d=gs:GetGlobalTimeDilation(FindFirstOf('PlayerController')); return string.format('craft=%s mult=%s dilation=%.4f', tostring(ok), tostring(q.CraftTimeMultiplier), d)" 2>/dev/null | tail -1)
echo "старт: $start · рецепт $RECIPE · результата было $n0"
done_at=""
for i in $(seq 1 90); do
  sleep 1
  n=$(count)
  if [ -n "$n" ] && [ -n "$n0" ] && [ "$n" -gt "$n0" ]; then done_at=$(date +%s.%N); break; fi
done
bash pult.sh "lua $INV; q.CraftTimeMultiplier=1.0; return 'reset'" > /dev/null
[ "$HUB" = 1 ] && hub false
if [ -n "$done_at" ]; then
  echo "готово: $n0 → $n за $(awk "BEGIN{printf \"%.1f\", $done_at - $t0}") с настоящего времени (множитель $MULT, хаб $HUB)"
else
  echo "за 90 с результат не появился (было $n0, стало ${n:-?}; множитель $MULT, хаб $HUB)"
fi
