-- shadow-pages-v8.lua — v7 + the AFTERIMAGE of «Параметры» (2026-11-07 07:1x). The per-tick probe (tick-visibility-probe.lua, 07:08) showed v7 holds
-- the old page on 9 of 11 transitions; from one GAME page to the other the native switch removes the old page itself and 3–4 ticks show the bare world.
-- v8 keeps OUR «Параметры» instance hidden (rebuilt after the game kills it) and, leaving the game's «Параметры», shows ours inside the native switch
-- (opacity only) until the new page is shown. «Снаряжение» → «Параметры» stays open (we cannot have our own «Снаряжение»).
-- v7 header follows.
-- shadow-pages-v7.lua — plan 48 controller core, the MIXED design (2026-11-07 07:0x). Run after the hub is open (remote dofile, NOT in the build).
-- What v5/v6 proved (plan 48): pages are kept by NAME (a Lua ref is a raw pointer, the game destroys extra instances); our own «Снаряжение» cannot live
-- beside the open hub (one open inventory window — SetInteractionActor closes the hub) and the game kills any second «Параметры» window. So:
--   * OURS (Таланты, Хар-ки, Путешествие, Клан, Спутники, Карта, Базар): our own instance, built once, kept in the viewport, shown the tick after the native
--     switch; the game's newborn of that class is hidden (opacity 0 + HitTestInvisible) and rebuilds invisibly;
--   * GAME (Снаряжение, Параметры): the game's newborn is held at opacity 0 until it is QUIET (no UserWidget born for QUIET_SAMPLES ticks in a row, or
--     HOLD_MAX_TICKS), then shown in one tick; until then the previous page stays on screen (the owner's design: the old page until the new one is complete).
--   * inside the native switch (OnChildActivated) only the game's newborn is touched, opacity only (SetVisibility there crashes, EXP-0474).
-- Counters in _G.__v7; no prints in callbacks. [NOT-TESTED]
local CL = { '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C', '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C', '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
  '/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C', '/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C',
  '/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C', '/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C',
  '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C', '/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C' }
local GAME_PAGE = { [1] = true, [4] = true }
local Z_ORDER = 41
local QUIET_SAMPLES = 2
local HOLD_MAX_TICKS = 60
local SHORT, IDX = {}, {}
for i, p in ipairs(CL) do SHORT[i] = p:match('%.([%w_]+)$'); IDX[SHORT[i]] = i end
local S = { names = {}, display = nil, gen = 0, switches = 0, lost = 0, readded = 0, holds = 0, hold_ticks_max = 0, hold_timeouts = 0,
  errors = 0, last_err = '' }
_G.__v7 = S
local births = 0

local function err(e) S.errors = S.errors + 1; S.last_err = tostring(e) end

local function find_by_name(i, name)
    if not name then return nil end
    for _, w in ipairs(FindAllOf(SHORT[i]) or {}) do
        local ok, n = pcall(function() return w:GetFullName() end)
        if ok and n == name then return w end
    end
    return nil
end

local function build(i)
    local pc = FindFirstOf('PlayerController')
    local c = StaticFindObject(CL[i])
    if not (c and c:IsValid()) then pcall(function() LoadAsset(CL[i]) end); c = StaticFindObject(CL[i]) end
    if not (c and c:IsValid()) then return nil end
    local w = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary'):Create(pc, c, pc)
    w:SetRenderOpacity(0.0)
    w:AddToViewport(Z_ORDER)
    w:SetVisibility(3)
    S.names[i] = w:GetFullName()
    return w
end

-- our page i alive and in the viewport (rebuilt / re-added when the game took it)
local function ours(i)
    local w = find_by_name(i, S.names[i])
    if not w then S.lost = S.lost + 1; return build(i) end
    if not w:IsInViewport() then w:AddToViewport(Z_ORDER); S.readded = S.readded + 1 end
    return w
end

local function is_ours(w)
    local ok, n = pcall(function() return w:GetFullName() end)
    if not ok then return false end
    for _, name in pairs(S.names) do if name == n then return true end end
    return false
end

-- the page now on screen: { i, name } — hide it (ours: opacity 0 + HitTestInvisible; the game's was removed natively, opacity 0 to be sure)
local function hide_display(except_name)
    local d = S.display
    if not d or d[2] == except_name then return end
    local w = find_by_name(d[1], d[2])
    if w then pcall(function() w:SetRenderOpacity(0.0); w:SetVisibility(3) end) end
end

-- the afterimage: OUR «Параметры», hidden, drawn only while leaving the game's «Параметры» until the next page is shown
local AFTERIMAGE = 4
local AFTERIMAGE_REBUILD_TICKS = 10      -- the game kills other stats windows while its own is born (twice) — rebuild ours after that
local function hide_afterimage()
    if not S.after then return end
    S.after = false
    local a = find_by_name(AFTERIMAGE, S.names[AFTERIMAGE])
    if a then pcall(function() a:SetRenderOpacity(0.0) end) end
end
local function rebuild_afterimage_later()
    ExecuteInGameThreadWithDelay(AFTERIMAGE_REBUILD_TICKS, function()
        pcall(function()
            if not (S.display and S.display[1] == AFTERIMAGE) then return end
            if not find_by_name(AFTERIMAGE, S.names[AFTERIMAGE]) then S.lost = S.lost + 1; build(AFTERIMAGE) end
        end)
    end)
end

for i = 1, #CL do if not GAME_PAGE[i] or i == AFTERIMAGE then local ok, e = pcall(build, i); if not ok then err(e) end end end

NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    births = births + 1
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    if ok and IDX[c] then _G.__v7nb = { IDX[c], w } end
end)

local function hold_until_quiet(gen, i, name, quiet, ticks, last_births)
    ExecuteInGameThreadWithDelay(1, function()
        local ok, e = pcall(function()
            if gen ~= S.gen then return end                       -- a newer switch took over
            local now = births
            quiet = (now == last_births) and quiet + 1 or 0
            ticks = ticks + 1
            if quiet < QUIET_SAMPLES and ticks < HOLD_MAX_TICKS then hold_until_quiet(gen, i, name, quiet, ticks, now); return end
            if ticks >= HOLD_MAX_TICKS then S.hold_timeouts = S.hold_timeouts + 1 end
            if ticks > S.hold_ticks_max then S.hold_ticks_max = ticks end
            local w = find_by_name(i, name)
            if w then w:SetRenderOpacity(1.0) end
            hide_display(name)
            hide_afterimage()
            S.display = { i, name }
            if i == AFTERIMAGE then rebuild_afterimage_later() end
        end)
        if not ok then err(e) end
    end)
end

RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local nb = _G.__v7nb
    _G.__v7nb = nil
    if not nb then return end
    pcall(function() nb[2]:SetRenderOpacity(0.0) end)           -- inside the native call: the newborn only, opacity only
    -- leaving the game's «Параметры» (removed natively): our copy holds the screen, opacity only (reads + opacity are safe inside the switch)
    if S.display and S.display[1] == AFTERIMAGE and nb[1] ~= AFTERIMAGE then
        pcall(function()
            local a = find_by_name(AFTERIMAGE, S.names[AFTERIMAGE])
            if a then a:SetRenderOpacity(1.0); S.after = true end
        end)
    end
    local name = nil
    pcall(function() name = nb[2]:GetFullName() end)
    S.gen = S.gen + 1
    local gen = S.gen
    ExecuteInGameThreadWithDelay(1, function()
        local ok, e = pcall(function()
            if gen ~= S.gen or not name then return end
            local i = nb[1]
            if is_ours(find_by_name(i, name) or nb[2]) then return end
            S.switches = S.switches + 1
            if GAME_PAGE[i] then
                S.holds = S.holds + 1
                hold_until_quiet(gen, i, name, 0, 0, births)
                return
            end
            local page = ours(i)
            local gw = find_by_name(i, name)
            if gw then pcall(function() gw:SetRenderOpacity(0.0); gw:SetVisibility(3) end) end
            if page then
                page:SetRenderOpacity(1.0); page:SetVisibility(4)
                local pn = S.names[i]
                hide_display(pn)
                hide_afterimage()
                S.display = { i, pn }
            end
        end)
        if not ok then err(e) end
    end)
end)

local n = 0
for i = 1, #CL do if S.names[i] then n = n + 1 end end
return 'v8 armed, our pages ' .. n .. ', errors ' .. S.errors
