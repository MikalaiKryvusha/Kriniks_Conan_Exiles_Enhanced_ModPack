-- stop-sprint-probe.lua — which game function clears the hero's sprint when a bow draw starts mid-sprint (KUMM bug 93, case S1b).
-- Why: the sampler showed bTrySprint false at the first 100 ms sample of substate 11 while SprintKeyIsDown stayed true (2026-11-13 09:47). The only
-- blueprint writer of bTrySprint = false is BaseBPCombat_C:StopSprint (bytecode: «if TrySprint() → bTrySprint = False»); its blueprint callers are
-- HandleUseItem, WeaponEquipped, OnSubstateChanged_Sprint and the event graph (ServerStopSprint). This probe hooks them all (game thread callbacks) and
-- appends one line per call into _G.__ssp: the time since arming, the function, the hero's substates.
--   arm:  bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/stop-sprint-probe.lua')"   (once per game session)
--   read: bash pult.sh "lua return _G.__ssp"
-- [NOT-TESTED]
local t0 = os.clock()
_G.__ssp = ''
local function subs(c)
    local t = {}
    for s = 0, 40 do
        local o = {}
        if pcall(function() c:InSubstate(s, o) end) and o.Success then t[#t + 1] = tostring(s) end
    end
    return table.concat(t, ',')
end
local function note(fn, ctx)
    local ok, c = pcall(function() return ctx:get() end)
    if not ok or not c:IsValid() or not c:IsPlayerControlled() then return end
    _G.__ssp = _G.__ssp .. string.format(' [%.2f %s sub=%s try=%s key=%s]', os.clock() - t0, fn, subs(c), tostring(c.bTrySprint), tostring(c.SprintKeyIsDown))
end
if _G.__ssp_armed then return 'already armed — read _G.__ssp' end
_G.__ssp_armed = true
local armed = {}
for _, fn in ipairs({ 'StopSprint', 'HandleUseItem', 'WeaponEquipped', 'OnSubstateChanged_Sprint', 'StartSprint' }) do
    local ok = pcall(function()
        RegisterHook('/Game/Characters/BaseBPCombat.BaseBPCombat_C:' .. fn, function(ctx) pcall(note, fn, ctx) end)
    end)
    armed[#armed + 1] = fn .. (ok and '+' or '-')
end
local ok2 = pcall(function()
    RegisterHook('/Game/Characters/BasePlayerChar.BasePlayerChar_C:SprintAction', function(ctx) pcall(note, 'SprintAction', ctx) end)
end)
armed[#armed + 1] = 'SprintAction' .. (ok2 and '+' or '-')
return 'armed: ' .. table.concat(armed, ' ')
