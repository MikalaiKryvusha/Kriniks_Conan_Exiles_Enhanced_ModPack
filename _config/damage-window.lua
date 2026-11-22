-- damage-window.lua — a damage window for a stand case, closed BY THE GAME, never by the agent's reads (KUMM EXP-0603).
-- Why: R6 of 2026-11-21 — god off 4 m from a camp humanoid, frames every 2 s, god back only after the series: health 146 → 81 in 2 s, the heroine dead
-- within 10 s; the same mistake as G2 of 2026-11-20. A camp humanoid deals ≈ 30 a second to a level-25 heroine, so the agent's reads are too slow.
-- What: god mode OFF now; then a timer every _G.__dw_ms (100) on the game thread reads the hero's health and switches god back ON the moment it falls to
-- _G.__dw_frac (0.5) of the max or under, or after _G.__dw_max_s (30) seconds, or on _G.__dw_stop = true. One `[damage-window]` line per open and per close in
-- UE4SS.log; the state in _G.__dw_last.
--   pult.sh "lua _G.__dw_frac=0.5; _G.__dw_max_s=30; return dofile('D:/work/ai_sandbox/ConanExiles/_config/damage-window.lua')"
--   pult.sh "lua return tostring(_G.__dw_last)"     -- open … / closed: <why> hp <a>/<max> after <s> s
--   pult.sh "lua _G.__dw_stop = true; return 'stop'" -- close now (god on at the next tick)
-- Limit: a single hit larger than the health left above the floor between two ticks still kills — take a weak enemy for a strong hero.
-- Cost (EFFICIENT_CODE §1): trigger — one remote call per window; inputs — the pawn and the max health read once at the start, then one GetIntStat per tick;
-- a stand-only tool (never in the shipment), bounded by _G.__dw_max_s; its own os.clock sum is printed at the close (1 ms resolution on Windows).
-- Heal before a window (the tool refuses at or under the floor): pult.sh "lua FindFirstOf('PlayerController').CheatManager:SetStat('HealthCurrent', <max>.0) return 'ok'"
-- (the console `exec SetStat Health …` does nothing; the stat names are ECharIntStatID's — GAME_ARCHITECTURE_INTERNAL_MAP).
-- Judge round 1 (2026-11-22 09:47, all confirmed and fixed): a float input threw in string.format AFTER god went off and left the hero vulnerable with the window
-- locked → inputs are checked and rounded before god goes off, and everything after it runs in pcall that puts god back on; the game-thread tick had no pcall →
-- it has one, an error closes the window with god on; God() toggles the possessed pawn → it is called only while the controller still holds this hero; the
-- time-out counted whole seconds (os.time) → os.clock; the floor was `<=` at the start and `<` at the close → `<=` both.
-- Judge round 2 (09:52, three quality findings, all confirmed and fixed): no upper bound on the tick (a minute-long tick = a minute vulnerable) → 20…1000 ms,
-- max_s ≤ 600; one shared open flag let a not-yet-ended loop of a previous window close the next one → a token per window; a dead hero left the new pawn
-- vulnerable → god goes on for the pawn the controller holds now.
-- [TESTED: 2026-11-22 · case DW0 only (the time-out close) on the round-1 code: «open 09:43:23 hp 236/236» → «closed 09:43:28: time out … god ON, 47 ticks»,
--  bCanBeDamaged true inside, false after; the refusal at hp 56/236 seen 09:41 · KUMM testcases/reports/2026-11-22_conan-damage-window-and-waystone-recon.md]
-- [TESTED: 2026-11-22 · the round-1 code, case DW0b: the judge's float input `_G.__dw_max_s=2.5` → «open 09:48:43 … after 2.5 s» → «closed 09:48:46: time out …
--  after 2.6 s, god ON, 25 ticks»; `_G.__dw_frac=1.5` refused before god went off (bCanBeDamaged false) · the same report]
-- [TESTED: 2026-11-22 · the round-2 code, case DW0c: `_G.__dw_ms=60000` refused with god ON; a 2 s window «open 09:52:38» → «closed 09:52:40: time out … after 2.1 s,
--  god ON, 20 ticks» · the same report] · DW1 (the close by real hits) and the dead-hero path owed
local HP, HP_MAX = 1, 0                 -- ECharIntStatID: 0 = max HP, 1 = HP (GAME_ARCHITECTURE_INTERNAL_MAP, the stat list)

if _G.__dw_open then
    return 'damage-window already open: ' .. tostring(_G.__dw_last)
end

-- inputs first: every check that can fail runs BEFORE god goes off
local frac  = tonumber(_G.__dw_frac)  or 0.5
local tick  = math.floor(tonumber(_G.__dw_ms) or 100)
local max_s = tonumber(_G.__dw_max_s) or 30
if not (frac > 0 and frac < 1) then return 'damage-window: _G.__dw_frac must be between 0 and 1' end
if not (tick >= 20 and tick <= 1000) then return 'damage-window: _G.__dw_ms must be 20…1000' end      -- the tick is the only place the window closes
if not (max_s > 0 and max_s <= 600) then return 'damage-window: _G.__dw_max_s must be 0…600' end    -- NaN and infinity fail both

local pc = FindFirstOf('PlayerController')
local hero = pc and pc:IsValid() and pc.Pawn or nil
if not (hero and hero:IsValid()) then return 'damage-window: no hero' end
local cm = pc.CheatManager
if not (cm and cm:IsValid()) then return 'damage-window: no CheatManager' end
local hero_name = hero:GetFullName()

local hp_max = hero:GetIntStat(HP_MAX, 0)
local floor_hp = math.floor(hp_max * frac)
local hp0 = hero:GetIntStat(HP, 0)
if hp0 <= floor_hp then
    return string.format('damage-window: hp %d already at or under %d — heal first', hp0, floor_hp)
end

-- the cheat toggles whatever pawn the controller holds: touch it only while that pawn is still this hero
local function still_ours()
    local ok, same = pcall(function()
        return pc:IsValid() and hero:IsValid() and pc.Pawn and pc.Pawn:IsValid() and pc.Pawn:GetFullName() == hero_name
    end)
    return ok and same
end
local function god_on()
    if still_ours() and hero.bCanBeDamaged then pcall(function() cm:God() end) end
    return hero:IsValid() and not hero.bCanBeDamaged
end

-- god OFF: bCanBeDamaged = true means vulnerable (god-on.sh reads the same flag)
if not hero.bCanBeDamaged then cm:God() end
if not hero.bCanBeDamaged then return 'damage-window: god did not switch off' end

local t0 = os.clock()
local cost, ticks = 0, 0
local id = {}   -- this window's token: a loop of a previous window that has not ended yet never closes this one (judge round 2)
local function mine() return _G.__dw_open == id end
local ok_open, err_open = pcall(function()
    _G.__dw_open, _G.__dw_stop = id, false
    _G.__dw_last = string.format('open %s hp %d/%d, closes at or under %d or after %.1f s', os.date('%H:%M:%S'), hp0, hp_max, floor_hp, max_s)
    print('[damage-window] ' .. _G.__dw_last .. '\n')

    local function close(why, hp)
        local god = god_on()
        _G.__dw_open = nil
        _G.__dw_last = string.format('closed %s: %s hp %d/%d after %.1f s, god %s, %d ticks, cost %.0f ms', os.date('%H:%M:%S'), why, hp, hp_max,
            os.clock() - t0, god and 'ON' or 'FAILED', ticks, cost * 1000)
        print('[damage-window] ' .. _G.__dw_last .. '\n')
    end

    LoopAsync(tick, function()
        if not mine() then return true end
        ExecuteInGameThread(function()
            if not mine() then return end
            local ok, err = pcall(function()
                local c0 = os.clock()
                ticks = ticks + 1
                if not hero:IsValid() then
                    -- death or a new pawn: god goes on for whatever pawn the controller holds now (a stand keeps its hero immortal)
                    local god = false
                    pcall(function()
                        local p = pc:IsValid() and pc.Pawn or nil
                        if p and p:IsValid() then
                            if p.bCanBeDamaged then cm:God() end
                            god = not p.bCanBeDamaged
                        end
                    end)
                    _G.__dw_open = nil
                    _G.__dw_last = 'closed ' .. os.date('%H:%M:%S') .. ': the hero object is gone (death or a new pawn) · god on the pawn now held ' ..
                        (god and 'ON' or 'FAILED')
                    print('[damage-window] ' .. _G.__dw_last .. '\n')
                    return
                end
                local hp = hero:GetIntStat(HP, 0)
                cost = cost + (os.clock() - c0)
                if hp <= floor_hp then close('at or under the floor', hp)
                elseif _G.__dw_stop then close('stopped', hp)
                elseif os.clock() - t0 >= max_s then close('time out', hp) end
            end)
            if not ok and mine() then
                local god = god_on()
                _G.__dw_open = nil
                _G.__dw_last = 'closed ' .. os.date('%H:%M:%S') .. ': tick error — ' .. tostring(err) .. ' · god ' .. (god and 'ON' or 'FAILED')
                print('[damage-window] ' .. _G.__dw_last .. '\n')
            end
        end)
        return false
    end)
end)
if not ok_open then
    local god = god_on()
    _G.__dw_open = nil
    _G.__dw_last = 'not opened: ' .. tostring(err_open) .. ' · god ' .. (god and 'ON' or 'FAILED')
    print('[damage-window] ' .. _G.__dw_last .. '\n')
end
return _G.__dw_last
