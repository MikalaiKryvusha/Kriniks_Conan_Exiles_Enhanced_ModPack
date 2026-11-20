-- shadow-pages-v6.lua — plan 48 controller core (2026-11-07 07:0x). Run after the hub is open (remote dofile, NOT in the build).
-- v5 (crash-proof): the game DESTROYS some of our page instances (each native «Параметры» activation kills other stats windows) and a Lua ref is a raw
-- pointer — touching a dead one crashed inside UE4SS. So pages are kept by NAME and found alive through FindAllOf before every touch; a lost page is
-- rebuilt on the next tick; inside the native switch only the game's newborn gets opacity 0 (SetVisibility there crashes, EXP-0474); our previous page
-- stays on screen through that frame (the owner's design: the old page until the new one is ready).
-- v6 adds:
--   1. our CraftingGUI is initialised by SetInteractionActor(nil) — the full hub inventory (bag, paperdoll, crafting; frame craft_nil.jpg 07:0x); with the
--      hero as the actor it builds the follower layout instead;
--   2. after every switch every page of ours is kept alive: the «Параметры» activation takes our CraftingGUI OUT of the viewport and an unreferenced widget
--      is garbage-collected within seconds — it goes back into the viewport at once; a page already gone is rebuilt.
-- No prints in callbacks; counters in _G.__v5. [NOT-TESTED]
local CL = { '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C', '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C', '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
  '/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C', '/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C',
  '/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C', '/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C',
  '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C', '/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C' }
local SHORT, IDX = {}, {}
for i, p in ipairs(CL) do SHORT[i] = p:match('%.([%w_]+)$'); IDX[SHORT[i]] = i end
local Z_ORDER = 41
local CRAFTING = 1
local S = { names = {}, shown = nil, switches = 0, lost = 0, rebuilt = 0, readded = 0, newborn_ours = 0, errors = 0, last_err = '' }
_G.__v5 = S

local function err(e) S.errors = S.errors + 1; S.last_err = tostring(e) end

-- one of OUR pages, alive, or nil (by the name kept at its birth)
local function ours(i)
    local name = S.names[i]
    if not name then return nil end
    for _, w in ipairs(FindAllOf(SHORT[i]) or {}) do
        local ok, n = pcall(function() return w:GetFullName() end)
        if ok and n == name then return w end
    end
    return nil
end

local function build(i)
    local pc = FindFirstOf('PlayerController')
    local lib = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    local c = StaticFindObject(CL[i])
    if not (c and c:IsValid()) then pcall(function() LoadAsset(CL[i]) end); c = StaticFindObject(CL[i]) end
    if not (c and c:IsValid()) then return nil end
    local w = lib:Create(pc, c, pc)
    w:SetRenderOpacity(0.0)
    w:AddToViewport(Z_ORDER)
    w:SetVisibility(3)        -- HitTestInvisible: laid out, never clicked while hidden
    if i == CRAFTING then w:SetInteractionActor(nil) end   -- nil = the hero's own bag layout, not a follower's
    S.names[i] = w:GetFullName()
    return w
end

local function is_ours(w)
    local ok, n = pcall(function() return w:GetFullName() end)
    if not ok then return false end
    for _, name in pairs(S.names) do if name == n then return true end end
    return false
end

-- every page of ours but `skip`: back into the viewport if taken out, rebuilt if gone
local function keep_alive(skip)
    for k = 1, #CL do
        if k ~= skip then
            local w = ours(k)
            if not w then S.lost = S.lost + 1; if build(k) then S.rebuilt = S.rebuilt + 1 end
            elseif not w:IsInViewport() then w:AddToViewport(Z_ORDER); S.readded = S.readded + 1 end
        end
    end
end

for i = 1, #CL do local ok, e = pcall(build, i); if not ok then err(e) end end

-- the game's newborn page of this switch (UserWidget notify + class check; a page-class notify never fires for page windows — game map)
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    if ok and IDX[c] then _G.__v5nb = { IDX[c], w } end
end)

RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local nb = _G.__v5nb
    _G.__v5nb = nil
    if not nb then return end
    -- inside the native call: the newborn only (just born — a valid pointer), opacity only
    pcall(function() nb[2]:SetRenderOpacity(0.0) end)
    ExecuteInGameThreadWithDelay(1, function()
        local ok, e = pcall(function()
            if is_ours(nb[2]) then S.newborn_ours = S.newborn_ours + 1; return end
            local i = nb[1]
            local page = ours(i)
            if not page then S.lost = S.lost + 1; page = build(i); if page then S.rebuilt = S.rebuilt + 1 end
            elseif not page:IsInViewport() then page:AddToViewport(Z_ORDER); S.readded = S.readded + 1 end
            local prev = S.shown and ours(S.shown) or nil
            -- the game's newborn: hidden for good (it still rebuilds natively, invisibly)
            for _, w in ipairs(FindAllOf(SHORT[i]) or {}) do
                if not is_ours(w) then pcall(function() w:SetRenderOpacity(0.0); w:SetVisibility(3) end) end
            end
            if page then page:SetRenderOpacity(1.0); page:SetVisibility(4) end
            if prev and S.shown ~= i then prev:SetRenderOpacity(0.0); prev:SetVisibility(3) end
            S.shown = i
            S.switches = S.switches + 1
            keep_alive(i)
        end)
        if not ok then err(e) end
    end)
end)

local n = 0
for i = 1, #CL do if S.names[i] then n = n + 1 end end
return 'v6 armed, pages ' .. n .. ', errors ' .. S.errors
