-- create-page-test.lua — can OUR code build a hub page without the module controller? (KUMM plan 48, the controller's core). Creates a NEW instance of
-- the page class by WidgetBlueprintLibrary:Create, adds it to the viewport at RenderOpacity 0, counts UserWidget births for 1 s, then shows it
-- (opacity 1) for the agent's frame; removes it after _G.__cp_hold ms. Set _G.__cp_class to the class path first. [NOT-TESTED]
local path = _G.__cp_class or '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C'
local cls = StaticFindObject(path)
if not (cls and cls:IsValid()) then
    local ok = pcall(function() LoadAsset(path) end)
    cls = StaticFindObject(path)
    if not (cls and cls:IsValid()) then return 'class not found: ' .. path end
end
local births, armed = 0, true
NotifyOnNewObject('/Script/UMG.UserWidget', function() if armed then births = births + 1 end end)
local pc = FindFirstOf('PlayerController')
local lib = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
local w = lib:Create(pc, cls, pc)
if not (w and w:IsValid()) then return 'create failed' end
w:SetRenderOpacity(0.0)
w:AddToViewport(41)
local b0 = births
ExecuteInGameThreadWithDelay(1000, function()
    print(string.format('[cpage] %s: births after add %d (1 s); shown now%s', path, births, string.char(10)))
    armed = false
    w:SetRenderOpacity(1.0)
    ExecuteInGameThreadWithDelay(_G.__cp_hold or 6000, function() pcall(function() w:RemoveFromParent() end) end)
end)
_G.__cp_widget = w
return 'created ' .. w:GetFullName() .. ' births at create ' .. b0
