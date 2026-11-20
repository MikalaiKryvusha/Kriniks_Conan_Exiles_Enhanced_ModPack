-- readd-test.lua — does a kept hub page rebuild its panels when it is merely put back on screen (AddToViewport), without the module controller?
-- (KUMM plan 48, the fork «own show/hide of kept pages»). Needs the KrinikHubPersistTest dev mod and the hub left from «Снаряжение» to another tab.
-- Counts UserWidget births and CraftingGUI_C:BP_Handle*PanelWidgetCreated calls for 600 ms after AddToViewport(40) of the kept CraftingGUI window,
-- then removes it again. Result in the return string. [NOT-TESTED]
local births, created = 0, 0
local armed = true
NotifyOnNewObject('/Script/UMG.UserWidget', function() if armed then births = births + 1 end end)
for _, fn in ipairs({ 'BP_HandleCenterPanelWidgetCreated', 'BP_HandleRightPanelWidgetCreated' }) do
    pcall(function() RegisterHook('/Game/UI/Inventory/CraftingGUI.CraftingGUI_C:' .. fn, function() if armed then created = created + 1 end end) end)
end
local win
for _, w in ipairs(FindAllOf('CraftingGUI_C') or {}) do
    local n = w:GetFullName()
    if not n:find('Default__', 1, true) and not n:find(':WidgetTree.', 1, true) then win = w end
end
if not win then return 'no kept CraftingGUI window' end
local before = tostring(win:IsInViewport()) .. ' vis ' .. tostring(win:GetVisibility())
births, created = 0, 0
win:AddToViewport(40)
win:SetVisibility(4)
local after = tostring(win:IsInViewport()) .. ' vis ' .. tostring(win:GetVisibility())
ExecuteInGameThreadWithDelay(600, function()
    armed = false
    print(string.format('[readd] births %d, panel-created calls %d (before %s, after %s)%s', births, created, before, after, string.char(10)))
    pcall(function() win:RemoveFromParent() end)
end)
return 'readd started: before ' .. before .. ', after ' .. after
