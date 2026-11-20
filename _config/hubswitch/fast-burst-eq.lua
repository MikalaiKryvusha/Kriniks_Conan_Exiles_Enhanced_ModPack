-- fast-burst-eq.lua — the E/Q variant of fast-burst.lua: the owner met the defect switching by E and Q (2026-11-07 10:23 «я по E Q переключался, когда
-- баги нашёл»). Bursts of `NextCarouselWindow` (E) / `PrevCarouselWindow` (Q) with gaps of one tick … 150 ms, every tick sampled (which hub pages are
-- DRAWN). A burst starts on «Снаряжение» (`SetCarouselIndex(0)`); E/Q walk the ring of all 9 tabs (measured 2026-11-07 10:2x; the game map's
-- «4 tabs only» of 06:46 did not hold) — the expected final tab is simulated on that ring. Verdict: the final drawn set is exactly that one page.
-- Use: `_G.__fb_cfg = { bursts = 8, seed = 5 }; return dofile('…/hubswitch/fast-burst-eq.lua')`, then `return _G.__fb.report()`. [NOT-TESTED]
local CLS = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C', 'W_FollowersView_C',
  'W_FullscreenMap_C', 'W_StoreWindow_C' }
local SHORT_NAME = { 'Снар', 'Тал', 'Хар', 'Пар', 'Пут', 'Клан', 'Спут', 'Карта', 'Базар' }
local GAPS_MS = { 1, 1, 16, 30, 50, 80, 120, 150 }
local EQ_RING = 9                                   -- 2026-11-07 10:2x: E/Q from the remote walk all 9 tabs (the «4 tabs» of 06:46 is stale)
local SWITCHES_MIN, SWITCHES_MAX = 8, 12
local START_SETTLE_MS, SETTLE_MS, BETWEEN_BURSTS_MS = 600, 1500, 2500
local cfg = _G.__fb_cfg or {}
local BURSTS = cfg.bursts or 8
math.randomseed(cfg.seed or 5)

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

local function sample(b)
    ExecuteInGameThreadWithDelay(1, function()
        local ok, l = pcall(drawn)
        b.ticks[#b.ticks + 1] = ok and table.concat(l, '+') or '!'
        if not b.stop then sample(b) end
    end)
end

local function run_burst(n)
    if n > BURSTS then F.done = true; return end
    local b = { want = 0, gaps = {}, dirs = {}, ticks = {}, marks = {} }
    F.bursts[n] = b
    local count = math.random(SWITCHES_MIN, SWITCHES_MAX)
    for s = 1, count do
        b.dirs[s] = math.random() < 0.6
        b.want = (b.want + (b.dirs[s] and 1 or -1)) % EQ_RING
        b.gaps[s] = GAPS_MS[math.random(1, #GAPS_MS)]
    end
    local function step(s)
        if s > count then
            ExecuteInGameThreadWithDelay(SETTLE_MS, function()
                b.stop = true
                ExecuteInGameThreadWithDelay(BETWEEN_BURSTS_MS, function() run_burst(n + 1) end)
            end)
            return
        end
        ExecuteInGameThreadWithDelay(b.gaps[s], function()
            local c = carousel()
            if not c then b.err = 'no carousel at switch ' .. s; b.stop = true; F.done = true; return end
            b.marks[#b.marks + 1] = #b.ticks
            local ok, e = pcall(function() if b.dirs[s] then c:NextCarouselWindow() else c:PrevCarouselWindow() end end)
            if not ok then b.err = tostring(e) end
            step(s + 1)
        end)
    end
    local c0 = carousel()
    if c0 then pcall(function() c0:SetCarouselIndex(0) end) end
    ExecuteInGameThreadWithDelay(START_SETTLE_MS, function() sample(b); step(1) end)
end

F.report = function()
    local out = {}
    for n, b in ipairs(F.bursts) do
        local want = SHORT_NAME[b.want + 1]
        local final = b.ticks[#b.ticks] or '?'
        local from = (b.marks[#b.marks] or 0) + 1
        local bare, run, worst, over = 0, 0, 0, 0
        for t = from, #b.ticks do
            local v = b.ticks[t]
            if v == '' then bare = bare + 1; run = run + 1; if run > worst then worst = run end else run = 0 end
            if v:find('+', 1, true) then over = over + 1 end
        end
        local tg = {}
        for s = 1, #b.dirs do tg[#tg + 1] = (b.dirs[s] and 'E' or 'Q') .. '/' .. b.gaps[s] end
        out[#out + 1] = string.format('#%d %s | want %s final [%s] | after last: bare %d (run %d) overlay %d ticks %d%s | %s', n,
            final == want and 'OK' or 'FAIL', want, final, bare, worst, over, #b.ticks - from + 1, b.err and (' ERR ' .. b.err) or '', table.concat(tg, ' '))
    end
    return (F.done and 'done ' or 'running ') .. #F.bursts .. '/' .. BURSTS .. '\n' .. table.concat(out, '\n')
end

run_burst(1)
return 'fast-burst-eq armed: ' .. BURSTS .. ' bursts'
