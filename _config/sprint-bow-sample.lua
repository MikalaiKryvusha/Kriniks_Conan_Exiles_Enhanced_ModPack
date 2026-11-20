-- sprint-bow-sample.lua — sample the hero's sprint state every _G.__sbs_ms ms for _G.__sbs_s s, ON THE GAME THREAD, while REAL input (mouse-seq.ps1:
-- RMB held = the bow drawn, W + Shift held = sprint) drives him. Reads K2_CanSprint, bTrySprint, MaxWalkSpeed, the speed and the substates into _G.__sbs.
-- Why (KUMM Locomotion notes «Sprint + bow», 2026-11-10 19:2x): the remote's RMB event is a TAP — the draw ends in < 0.8 s — so only real input can hold the bow.
-- A chain of ExecuteInGameThreadWithDelay, never LoopAsync: an off-game-thread Lua loop in the remote's state races its game-thread Lua (bug 85 class); the
-- 2026-11-10 probes' LoopAsync never stopped (their «done» flag was re-made each step) and the game crashed at 19:14.
--   start: bash pult.sh "lua _G.__sbs_s=6; return dofile('D:/work/ai_sandbox/ConanExiles/_config/sprint-bow-sample.lua')"
--   read:  bash pult.sh "lua return _G.__sbs"
-- [NOT-TESTED]
-- The hero by its class (single player: one live BasePlayerChar_C). Note for probes: the actor's location is `K2_GetActorLocation()` — a call of
-- `GetActorLocation()` errors «attempt to call a TrivialObject value» (2026-11-13; first misread as an unreadable `.Pawn`).
local p = (FindAllOf('BasePlayerChar_C') or {})[1]
local STEP_MS = _G.__sbs_ms or 250
local LAST_S = _G.__sbs_s or 6
local t0 = os.clock()
_G.__sbs = ''

local function substates()
    local t = {}
    for s = 0, 40 do
        local o = {}
        local ok = pcall(function() p:InSubstate(s, o) end)
        if ok and o.Success then t[#t + 1] = tostring(s) end
    end
    return table.concat(t, ',')
end

local function sample()
    if not p:IsValid() then _G.__sbs = _G.__sbs .. ' [pawn gone]'; return end
    local dt = os.clock() - t0
    local o = {}
    pcall(function() p:K2_CanSprint(o) end)
    local v = p:GetVelocity()
    -- key = the blueprint's own «sprint key held» flag (BasePlayerChar.SprintKeyIsDown, set True on the press, False on the release — bytecode read
    -- 2026-11-13); try = the native bTrySprint that EvaluateMovement_Sprint reads. KUMM TC case S1b: does the draw clear `try` while `key` stays true?
    local ok_k, key = pcall(function() return p.SprintKeyIsDown end)
    _G.__sbs = _G.__sbs .. string.format(' [%.2f s: sub=%s v=%.0f max=%.0f can=%s try=%s key=%s]', dt, substates(), math.sqrt(v.X * v.X + v.Y * v.Y),
        p.CharacterMovement.MaxWalkSpeed, tostring(o.Value), tostring(p.bTrySprint), ok_k and tostring(key) or '?')
    if dt < LAST_S then ExecuteInGameThreadWithDelay(STEP_MS, function() pcall(sample) end) end
end
ExecuteInGameThread(function() pcall(sample) end)
return 'sampling ' .. LAST_S .. ' s'
