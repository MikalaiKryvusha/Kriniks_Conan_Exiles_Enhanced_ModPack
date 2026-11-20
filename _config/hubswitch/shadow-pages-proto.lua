-- shadow-pages-proto.lua — PROTOTYPE of plan 48's controller core («shadow pages»), v3 (2026-11-07). Our own built instance of every hub page stays in
-- the viewport; hidden ones at RenderOpacity 0 and HitTestInvisible. On each native switch (CarouselWindow:OnChildActivated, inside the native call)
-- ONLY opacities change — the game's newborn page 0, ours 1 (the crash rule: SetVisibility inside that call crashes the game, bisect 00:10; opacity is
-- safe); the next tick moves hit-testing (ours SelfHitTestInvisible, the rest HitTestInvisible). Lazy build: one page per 400 ms, nearest first, right
-- then left. Our own births are ignored while we build (the class notify does not fire for page windows; the UserWidget notify + a class check does).
-- Log «[shadow]». A remote dofile — not in the build. [NOT-TESTED]
if _G.__shadow3 then return 'already armed' end
_G.__shadow3 = true
local ORDER = { 'CharacterInventory', 'FeatWindow', 'Attributes', 'CharacterStatsWindow', 'ExilesJourney', 'Guild', 'Followers', 'FullscreenMap', 'Stores' }
local CLASS = {
    CharacterInventory = '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C',
    FeatWindow = '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C',
    Attributes = '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
    CharacterStatsWindow = '/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C',
    ExilesJourney = '/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C',
    Guild = '/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C',
    Followers = '/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C',
    FullscreenMap = '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C',
    Stores = '/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C',
}
local BYCLASS = {}
for id, p in pairs(CLASS) do BYCLASS[p:match('%.([%w_]+)$')] = id end
local VIS_SHOWN, VIS_HIDDEN = 4, 3          -- SelfHitTestInvisible (children clickable) / HitTestInvisible (no clicks)
local Z = 41
local function L(m) print('[shadow] ' .. m .. string.char(10)) end
local mine, building, newborn, shown, births = {}, false, nil, nil, 0
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    births = births + 1
    if building then return end
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    if ok and BYCLASS[c] then newborn = { BYCLASS[c], w } end
end)
local pc = FindFirstOf('PlayerController')
local lib = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
local function build(id)
    if mine[id] then return end
    local cls = StaticFindObject(CLASS[id])
    if not (cls and cls:IsValid()) then pcall(function() LoadAsset(CLASS[id]) end); cls = StaticFindObject(CLASS[id]) end
    if not (cls and cls:IsValid()) then L('no class ' .. id); return end
    local b0 = births
    building = true
    local w = lib:Create(pc, cls, pc)
    w:SetRenderOpacity(0.0)
    w:AddToViewport(Z)
    w:SetVisibility(VIS_HIDDEN)
    building = false
    mine[id] = w
    ExecuteInGameThreadWithDelay(300, function() L(string.format('built %s, births %d', id, births - b0)) end)
end
RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    if not newborn then return end
    local id, gw = newborn[1], newborn[2]
    newborn = nil
    local ours = mine[id]
    if not ours then L('switch to ' .. id .. ': not built yet — the game page stays'); return end
    local prev = shown
    -- inside the native call: opacity only
    pcall(function() gw:SetRenderOpacity(0.0) end)
    if prev then pcall(function() prev:SetRenderOpacity(0.0) end) end
    pcall(function() ours:SetRenderOpacity(1.0) end)
    shown = ours
    -- the next tick: who takes the clicks
    ExecuteInGameThreadWithDelay(1, function()
        pcall(function() gw:SetVisibility(VIS_HIDDEN) end)
        if prev then pcall(function() prev:SetVisibility(VIS_HIDDEN) end) end
        pcall(function() ours:SetVisibility(VIS_SHOWN) end)
        L('switch to ' .. id .. ': ours shown')
    end)
end)
-- the page on screen now: the game's own (the hub was opened by the game); our queue starts from it
local cur = 'CharacterInventory'
local ci = 1
for i, id in ipairs(ORDER) do if id == cur then ci = i end end
local queue = {}
for d = 1, #ORDER - 1 do
    for _, id in ipairs({ ORDER[(ci - 1 + d) % #ORDER + 1], ORDER[(ci - 1 - d) % #ORDER + 1] }) do
        local dup = (id == cur)
        for _, q in ipairs(queue) do if q == id then dup = true end end
        if not dup then queue[#queue + 1] = id end
    end
end
table.insert(queue, 1, cur)
local function step(i) if i > #queue then L('all built') return end build(queue[i]); ExecuteInGameThreadWithDelay(400, function() step(i + 1) end) end
step(1)
return 'armed v3; queue ' .. table.concat(queue, ',')
