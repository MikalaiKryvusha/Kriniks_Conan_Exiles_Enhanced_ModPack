-- fast-burst.lua — the owner's 2026-11-07 10:1x defect («при быстром переключении табов ХАБА, иногда они не открываются, или открываются пустыми»):
-- bursts of native tab switches with short gaps (one tick … 150 ms), every tick sampled — which hub pages are DRAWN (in the viewport, not Collapsed/Hidden,
-- opacity > 0) — until 1.5 s after the last switch. Verdict per burst: the final drawn set must be exactly ONE page of the LAST target tab;
-- a run of ticks with 0 pages after the last switch = «empty», a wrong page at the end = «did not open».
-- Use (remote, the hub open, the controller armed): `_G.__fb_cfg = { bursts = 6, seed = 7 }; return dofile('…/hubswitch/fast-burst.lua')`,
-- then after ≈ 15 s `return _G.__fb.report()`. Switch path: `CarouselWindow:SetCarouselIndex(k)` (0-based) — the same native function a tab click
-- reaches (game map «Hub tab switching by the MOUSE»). [NOT-TESTED]
local CLS = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C', 'W_FollowersView_C',
  'W_FullscreenMap_C', 'W_StoreWindow_C' }
local SHORT_NAME = { 'Снар', 'Тал', 'Хар', 'Пар', 'Пут', 'Клан', 'Спут', 'Карта', 'Базар' }
local GAPS_MS = { 1, 1, 16, 30, 50, 80, 120, 150 }   -- 1 = the next tick (ExecuteInGameThreadWithDelay counts ms)
local SWITCHES_MIN, SWITCHES_MAX = 8, 12
local SETTLE_MS = 1500
local BETWEEN_BURSTS_MS = 2500
local cfg = _G.__fb_cfg or {}
local BURSTS = cfg.bursts or 6
math.randomseed(cfg.seed or 7)

local function drawn()
    local list = {}
    for i, c in ipairs(CLS) do
        for _, w in ipairs(FindAllOf(c) or {}) do
            local ok, d = pcall(function()
                if not w:IsInViewport() then return false end
                local v = w:GetVisibility()
                if v == 1 or v == 2 then return false end
                return w:GetRenderOpacity() > 0.01
            end)
            if ok and d then list[#list + 1] = SHORT_NAME[i] end
        end
    end
    return list
end

local function carousel()
    for _, w in ipairs(FindAllOf('W_Carousel_C') or {}) do
        local ok, live = pcall(function() return w:IsInViewport() end)
        if ok and live then return w end
    end
    return nil
end

local F = { bursts = {}, done = false }
_G.__fb = F

local function sample_until(b, until_ms_left)
    ExecuteInGameThreadWithDelay(1, function()
        local ok, l = pcall(drawn)
        b.ticks[#b.ticks + 1] = ok and table.concat(l, '+') or '!'
        if b.switching or os.clock() < b.stop_clock then sample_until(b) else b.finished = true end
    end)
end

local function run_burst(n)
    if n > BURSTS then F.done = true; return end
    local b = { targets = {}, gaps = {}, ticks = {}, marks = {}, switching = true, stop_clock = math.huge }
    F.bursts[n] = b
    local count = math.random(SWITCHES_MIN, SWITCHES_MAX)
    for s = 1, count do
        b.targets[s] = math.random(0, #CLS - 1)
        b.gaps[s] = GAPS_MS[math.random(1, #GAPS_MS)]
    end
    sample_until(b)
    local function step(s)
        if s > count then
            b.switching = false
            -- os.clock is CPU time; settle by delayed callback instead
            ExecuteInGameThreadWithDelay(SETTLE_MS, function()
                b.stop_clock = 0
                ExecuteInGameThreadWithDelay(BETWEEN_BURSTS_MS, function() run_burst(n + 1) end)
            end)
            return
        end
        ExecuteInGameThreadWithDelay(b.gaps[s], function()
            local c = carousel()
            if not c then b.err = 'no carousel at switch ' .. s; b.switching = false; b.stop_clock = 0; F.done = true; return end
            b.marks[#b.marks + 1] = #b.ticks
            local ok, e = pcall(function() c:SetCarouselIndex(b.targets[s]) end)
            if not ok then b.err = tostring(e) end
            step(s + 1)
        end)
    end
    step(1)
end

F.report = function()
    local out = {}
    for n, b in ipairs(F.bursts) do
        local last = b.targets[#b.targets]
        local want = SHORT_NAME[last + 1]
        local tail = {}
        for t = math.max(1, #b.ticks - 5), #b.ticks do tail[#tail + 1] = b.ticks[t] end
        local final = b.ticks[#b.ticks] or '?'
        -- bare ticks after the last switch, the longest run
        local from = (b.marks[#b.marks] or 0) + 1
        local bare, run, worst, over = 0, 0, 0, 0
        for t = from, #b.ticks do
            local v = b.ticks[t]
            if v == '' then bare = bare + 1; run = run + 1; if run > worst then worst = run end else run = 0 end
            if v:find('+', 1, true) then over = over + 1 end
        end
        local tg = {}
        for s = 1, #b.targets do tg[#tg + 1] = SHORT_NAME[b.targets[s] + 1] .. '/' .. b.gaps[s] end
        out[#out + 1] = string.format('#%d %s | want %s final [%s] %s | after last: bare %d (run %d) overlay %d ticks %d | tail %s%s', n,
            final == want and 'OK' or 'FAIL', want, final, final == want and '' or '<<<', bare, worst, over, #b.ticks - from + 1,
            table.concat(tail, ' '), b.err and (' ERR ' .. b.err) or '')
        out[#out + 1] = '   seq ' .. table.concat(tg, ' ')
    end
    return (F.done and 'done ' or 'running ') .. #F.bursts .. '/' .. BURSTS .. '\n' .. table.concat(out, '\n')
end

run_burst(1)
return 'fast-burst armed: ' .. BURSTS .. ' bursts'
