-- gauge-lag-probe.lua — KUMM 2026-11-07, eating in the hub: the quick-bar item `_G.__gl_slot` is used, then every 250 ms of REAL time the hunger system's food
-- and the visible hunger gauges' CachedActualValue (what the gauge polled) and CurrentDisplayValue (what it shows) are sampled for `_G.__gl_secs` s.
-- Read `_G.__gl.out`. [NOT-TESTED]
local h = FindFirstOf('BasePlayerChar_C')
local pc = FindFirstOf('PlayerController')
local gs = StaticFindObject('/Script/Engine.Default__GameplayStatics')
local hs = h:GetHungerSystem()
local t = { rows = {}, out = 'running' }
_G.__gl = t
local t0 = gs:GetRealTimeSeconds(pc)
local function gauge()
    for _, g in ipairs(FindAllOf('WBP_HungerGauge_C') or {}) do
        if g:IsVisible() then return g end
    end
end
local function row(tag)
    local g = gauge()
    t.rows[#t.rows + 1] = string.format('%5.2fs %s food %.2f gauge polled %.2f shows %.2f', gs:GetRealTimeSeconds(pc) - t0, tag, hs.FoodCurrent,
        g and g.CachedActualValue or -1, g and g.CurrentDisplayValue or -1)
end
row('before')
local item = h:GetShortcutBarInventory():GetItem(_G.__gl_slot or 0)
if _G.__gl_food then                                   -- any food item instance of the hero (the bag) instead of a quick-bar slot
    item = nil
    for _, it in ipairs(FindAllOf('BPGameItemFood_C') or {}) do
        local ok, own = pcall(function() return it:GetFullName():find('Default__', 1, true) == nil end)
        if ok and own and not item then item = it end
    end
    t.rows[#t.rows + 1] = 'food item: ' .. tostring(item and item:GetFullName():match('[^.]+$'))
end
if item and item:IsValid() then item:OnUseItem(h, pc) end
row('used')
local n, secs = 0, _G.__gl_secs or 40
local function step()
    ExecuteInGameThreadWithDelay(250, function()
        n = n + 1
        local g = gauge()
        if n % 4 == 0 or (g and math.abs(g.CurrentDisplayValue - hs.FoodCurrent) > 0.01 and n % 2 == 0) then row('') end
        if gs:GetRealTimeSeconds(pc) - t0 >= secs then t.out = table.concat(t.rows, '\n'); return end
        step()
    end)
end
step()
return 'armed'
