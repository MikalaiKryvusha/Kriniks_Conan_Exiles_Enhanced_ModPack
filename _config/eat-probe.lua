-- eat-probe.lua — KUMM 2026-11-07, the owner's 10:59 defect «при съедании или выпивании чего-то в инвентаре, из-за замедления мира - проценты голода и жажды
-- увеличиваются или медленно или с задержкой»: uses the quick-bar item in slot `_G.__ep_slot` (0-based) by its own OnUseItem(hero, controller) — the player's
-- «use» — and samples the hunger system's FoodCurrent / DrinkCurrent every 500 ms of REAL time (os.time is too coarse, the game's real-time seconds are used)
-- for `_G.__ep_secs` seconds. Read `_G.__ep.out`. [NOT-TESTED]
local h = FindFirstOf('BasePlayerChar_C')
local pc = FindFirstOf('PlayerController')
local gs = StaticFindObject('/Script/Engine.Default__GameplayStatics')
local hs = h:GetHungerSystem()
local slot, secs = _G.__ep_slot or 0, _G.__ep_secs or 10
local t = { rows = {}, out = 'running' }
_G.__ep = t
local t0 = gs:GetRealTimeSeconds(pc)
local function row(tag)
    t.rows[#t.rows + 1] = string.format('%5.1fs %s food %.1f drink %.1f dil %.3f', gs:GetRealTimeSeconds(pc) - t0, tag, hs.FoodCurrent, hs.DrinkCurrent,
        gs:GetGlobalTimeDilation(h))
end
row('before')
local item = h:GetShortcutBarInventory():GetItem(slot)
if not (item and item:IsValid()) then t.out = 'no item in slot ' .. slot; return t.out end
local ok, e = pcall(function() item:OnUseItem(h, pc) end)
row(ok and ('used ' .. item:GetFullName():match('[^.]+$')) or ('use failed ' .. tostring(e)))
local n = 0
local function step()
    ExecuteInGameThreadWithDelay(500, function()
        n = n + 1
        row('')
        if n * 0.5 >= secs then t.out = table.concat(t.rows, '\n'); return end
        step()
    end)
end
step()
return 'armed'
