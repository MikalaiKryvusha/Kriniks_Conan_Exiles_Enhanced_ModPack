-- sprint-gate-microbench.lua — KUMM bug 93 cost: the whole gate (old and new) and its pieces, run N times on the game thread WHILE the hero sprints with the bow drawn
-- (start the run first). Also the Lua GC: collectgarbage("count") before / after, and the same loops with GC stopped. A test probe, not mod code. [TESTED: 2026-11-17 · old 313 µs / new 147 µs read while sprinting drawn · KUMM testcases/reports/2026-11-17_conan-bow-sprint-cost.md]
local N = _G.__mb_n or 300
local pc = FindFirstOf('FunCombat_PlayerController_C')
local c = pc and pc:K2_GetPawn()
if not (c and c:IsValid()) then return 'no hero' end
local function bow_in_hand(h)
    local arr = {}
    h:GetAttachedActors(arr, true, false)
    for i = 1, #arr do
        local a = arr[i]:get()
        if a:IsValid() and a:GetClass():GetFName():ToString():lower():find("bow", 1, true) then
            return not a:GetAttachParentSocketName():ToString():lower():find("sheath", 1, true)
        end
    end
    return false
end
local function in_sub(s) local o = {}; c:InSubstate(s, o); return o.Success == true end
local function old_gate()
    if not c:IsPlayerControlled() then return false end
    if not (in_sub(11) or in_sub(15) or in_sub(16)) then return false end
    local v = c:GetVelocity(); if v.X * v.X + v.Y * v.Y < 100 then return 'slow' end
    local a = {}; c:GetAngleOfMovement(a)
    if in_sub(13) or in_sub(14) or in_sub(18) then return 'tired' end
    if not c.CharacterMovement:IsMovingOnGround() then return 'air' end
    return bow_in_hand(c)
end
local DRAW, TIRED = { [11] = true, [15] = true, [16] = true }, { [13] = true, [14] = true, [18] = true }
local function new_gate()
    local drawn, tired = false, false
    for _, v in ipairs(c:GetSubstateList()) do
        if type(v) == "userdata" then v = v:get() end
        if DRAW[v] then drawn = true elseif TIRED[v] then tired = true end
    end
    if not drawn then return false end
    if tired then return 'tired' end
    local m = c.CharacterMovement
    local mode = m.MovementMode
    if mode ~= 1 and mode ~= 2 then return 'air' end
    local v = m.Velocity; if v.X * v.X + v.Y * v.Y < 100 then return 'slow' end
    local a = {}; c:GetAngleOfMovement(a)
    return bow_in_hand(c)
end
local function bench(name, f)
    local r = tostring(f())
    local kb0 = collectgarbage("count")
    local t0 = os.clock()
    for _ = 1, N do f() end
    local us = (os.clock() - t0) * 1e6 / N
    return string.format('%s %.1f us (result %s, heap %+.0f KB)', name, us, r, collectgarbage("count") - kb0)
end
local out = {}
out[#out + 1] = bench('old gate', old_gate)
out[#out + 1] = bench('new gate', new_gate)
out[#out + 1] = bench('GetSubstateList+loop', function() local n = 0; for _, v in ipairs(c:GetSubstateList()) do if type(v) == "userdata" then v = v:get() end; n = n + 1 end; return n end)
out[#out + 1] = bench('CharacterMovement.MovementMode', function() return c.CharacterMovement.MovementMode end)
out[#out + 1] = bench('CharacterMovement.Velocity', function() local v = c.CharacterMovement.Velocity; return v.X end)
out[#out + 1] = bench('bow_in_hand', function() return bow_in_hand(c) end)
collectgarbage("stop")
out[#out + 1] = bench('new gate, GC stopped', new_gate)
collectgarbage("restart")
local t0 = os.clock(); collectgarbage("collect"); out[#out + 1] = string.format('full collect %.1f ms, heap now %.0f KB', (os.clock() - t0) * 1000, collectgarbage("count"))
return table.concat(out, ' | ')
