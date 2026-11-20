-- shadow-pages-v9.lua — v7 + the hub's LIFECYCLE (2026-11-07 07:2x): our shown page must not stay over the world when the hub closes. The carousel
-- lives on and never hides (07:15), so «closed» = the game's page of the current tab has left the viewport; checked on events only — Esc / Tab keys
-- and the ActivateModule hook (the remote's path; the native Tab path does not pass it, pause module note 13.09) — never by a timer (HOUSE_RULES 7).
-- On close every page of ours is Collapsed (no layout, no paint); the next native switch (the hub's reopening) brings them back.
-- Delays of ExecuteInGameThreadWithDelay are MILLISECONDS (1 = the next tick). v7 header follows.
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
local S = { names = {}, display = nil, game_name = nil, closed = false, closes = 0, reopens = 0, gen = 0, switches = 0, lost = 0, readded = 0, holds = 0, hold_ticks_max = 0, hold_timeouts = 0,
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

-- v10: LAZY build (the owner's design 2026-11-06 23:07, plan 48): nothing is built at load; when the hub shows a tab, the missing pages of ours are
-- built ONE per tick, nearest first, alternating right and left (the carousel wraps); each build is timed (os.clock — CPU time, fine for a cost).
local LAZY_STEP_MS = 1
S.lazy_builds, S.build_ms_max, S.build_ms_sum, S.lazy_order = 0, 0, 0, ''
local function lazy_order(from)
    local order = {}
    for d = 1, #CL - 1 do
        for _, k in ipairs({ ((from - 1 + d) % #CL) + 1, ((from - 1 - d) % #CL) + 1 }) do
            local seen = false
            for _, o in ipairs(order) do if o == k then seen = true end end
            if not seen and not GAME_PAGE[k] then order[#order + 1] = k end
        end
    end
    return order
end
local function timed_build(k)
    local t0 = os.clock()
    local w = build(k)
    local ms = (os.clock() - t0) * 1000
    S.lazy_builds = S.lazy_builds + 1; S.build_ms_sum = S.build_ms_sum + ms
    if ms > S.build_ms_max then S.build_ms_max = ms end
    return w
end
local function lazy_build(order, n)
    if n > #order then S.lazy_busy = false; return end
    ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function()
        local ok, e = pcall(function()
            if S.closed then S.lazy_busy = false; return end          -- the hub closed: stop; the next opening resumes
            local k = order[n]
            if not find_by_name(k, S.names[k]) then timed_build(k) end
        end)
        if not ok then err(e) end
        if S.lazy_busy then lazy_build(order, n + 1) end
    end)
end
local function start_lazy(from)
    if S.lazy_busy then return end
    local order = lazy_order(from)
    S.lazy_busy = true
    S.lazy_order = table.concat(order, ',')
    lazy_build(order, 1)
end

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
            S.display = { i, name }
        end)
        if not ok then err(e) end
    end)
end

RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local nb = _G.__v7nb
    _G.__v7nb = nil
    if not nb then return end
    pcall(function() nb[2]:SetRenderOpacity(0.0) end)           -- inside the native call: the newborn only, opacity only
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
            S.game_name = { i, name }
            start_lazy(i)
            if S.closed then                                    -- the hub reopened: our pages back into layout (hidden until shown)
                S.closed = false; S.reopens = S.reopens + 1
                for k = 1, #CL do
                    local w = find_by_name(k, S.names[k])
                    if w then pcall(function() w:SetVisibility(3) end) end
                end
            end
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
                S.display = { i, pn }
            end
        end)
        if not ok then err(e) end
    end)
end)

-- the lifecycle: closed ⇔ the game's page of the current tab is out of the viewport; checked a tick and CLOSE_RECHECK_MS after each event
local CLOSE_RECHECK_MS = { 1, 100, 300 }
local function collapse_ours()
    for k = 1, #CL do
        local w = find_by_name(k, S.names[k])
        if w then pcall(function() w:SetRenderOpacity(0.0); w:SetVisibility(1) end) end
    end
end
local function check_closed()
    if S.closed or not S.game_name then return end
    local g = find_by_name(S.game_name[1], S.game_name[2])
    if g and g:IsInViewport() then return end
    S.closed = true; S.closes = S.closes + 1; S.gen = S.gen + 1; S.display = nil
    collapse_ours()
end
local function check_soon()
    for _, ms in ipairs(CLOSE_RECHECK_MS) do ExecuteInGameThreadWithDelay(ms, function() local ok, e = pcall(check_closed); if not ok then err(e) end end) end
end
RegisterKeyBind(Key.ESCAPE, function() ExecuteInGameThread(check_soon) end)
RegisterKeyBind(Key.TAB, function() ExecuteInGameThread(check_soon) end)
RegisterHook('/Script/ConanSandbox.GUIModuleController:ActivateModule', function() ExecuteInGameThread(check_soon) end)

local n = 0
for i = 1, #CL do if S.names[i] then n = n + 1 end end
return 'v10 armed (lazy), our pages ' .. n .. ', errors ' .. S.errors
