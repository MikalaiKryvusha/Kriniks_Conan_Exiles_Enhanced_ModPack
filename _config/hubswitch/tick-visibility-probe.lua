-- tick-visibility-probe.lua — plan 48: which hub pages are DRAWN on each tick after a native switch (in the viewport, not Collapsed/Hidden, opacity > 0).
-- The acceptance of the hold design without a video: per tick exactly ONE page drawn, the old one until the new one, the swap within one tick; a tick with
-- 0 pages is a bare world, a tick with 2 is an overlay. Run after the controller (v7) is armed; then switch tabs; read `_G.__tvp.out`.
-- `os.clock` is CPU time — ticks are counted, not milliseconds (game map). [NOT-TESTED]
local CLS = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C', 'W_FollowersView_C',
  'W_FullscreenMap_C', 'W_StoreWindow_C' }
local SHORT_NAME = { 'Снар', 'Тал', 'Хар', 'Пар', 'Пут', 'Клан', 'Спут', 'Карта', 'Базар' }
local TICKS = 30
_G.__tvp = { out = {}, runs = 0 }

local function drawn()
    local list = {}
    for i, c in ipairs(CLS) do
        for _, w in ipairs(FindAllOf(c) or {}) do
            local ok, d = pcall(function()
                if not w:IsInViewport() then return false end
                local v = w:GetVisibility()
                if v == 1 or v == 2 then return false end      -- Collapsed, Hidden
                return w:GetRenderOpacity() > 0.01
            end)
            if ok and d then list[#list + 1] = SHORT_NAME[i] end
        end
    end
    return list
end

local function sample(run, t)
    ExecuteInGameThreadWithDelay(1, function()
        local ok, l = pcall(drawn)
        local row = _G.__tvp.out[run]
        row[#row + 1] = ok and (#l == 1 and l[1] or ('[' .. #l .. ':' .. table.concat(l, '+') .. ']')) or '!'
        if t < TICKS then sample(run, t + 1) end
    end)
end

RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local t = _G.__tvp
    if t.busy then return end                                   -- OnChildActivated fires twice per switch
    t.busy = true
    t.runs = t.runs + 1
    t.out[t.runs] = {}
    local run = t.runs
    -- tick 0: inside the native switch, after the controller's own hook (registered earlier) — what this frame will draw; reads only
    local ok, l = pcall(drawn)
    t.out[run][1] = ok and ('0:' .. table.concat(l, '+')) or '0:!'
    sample(run, 1)
    ExecuteInGameThreadWithDelay(TICKS + 2, function() t.busy = false end)
end)
return 'tick probe armed'
