-- collapse-test.lua — a kept hub page that STAYS in the viewport: collapse it, then show it — does anything get rebuilt? (KUMM plan 48, the fork «own
-- show/hide of kept pages»). The kept CraftingGUI window is added once (births then are the re-add's), then 3 cycles Collapsed (1) -> SelfHitTestInvisible
-- (4), 300 ms apart; births and panel-created calls are counted per cycle. Removed at the end. [NOT-TESTED]
local births, created, armed = 0, 0, true
NotifyOnNewObject('/Script/UMG.UserWidget', function() if armed then births = births + 1 end end)
local win
for _, w in ipairs(FindAllOf('CraftingGUI_C') or {}) do
    local n = w:GetFullName()
    if not n:find('Default__', 1, true) and not n:find(':WidgetTree.', 1, true) then win = w end
end
if not win then return 'no kept CraftingGUI window' end
local function L(m) print('[collapse] ' .. m .. string.char(10)) end
win:AddToViewport(40)
win:SetVisibility(1)
local function cycle(k)
    births = 0
    win:SetVisibility(4)
    ExecuteInGameThreadWithDelay(300, function()
        L(string.format('cycle %d: shown, births %d', k, births))
        births = 0
        win:SetVisibility(1)
        ExecuteInGameThreadWithDelay(300, function()
            L(string.format('cycle %d: collapsed, births %d', k, births))
            if k < 3 then cycle(k + 1) else armed = false; pcall(function() win:RemoveFromParent() end) end
        end)
    end)
end
ExecuteInGameThreadWithDelay(800, function() L('after the re-add: births ' .. births); cycle(1) end)
return 'collapse test started'
