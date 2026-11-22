-- cam_watch.lua — watch the third-person camera while REAL input runs (bug 93 / issue #30 item «a sprint jump zooms in», 2026-11-22 20:4x).
-- Every 50 ms for _G.__cw_len s (default 5): the spring arm's TargetArmLength, the camera's FieldOfView, the hero's NewTargetArmLength, substates, Z.
-- Result: cam_watch.txt beside it; _G.__cw_done = true. A one-shot probe (six answers: one call, a few property reads per sample, 5 s, never shipped).
local OUT = [[D:/work/ai_sandbox/KUMM/.work/tmp/cam_watch.txt]]
local p = FindFirstOf('FunCombat_PlayerController_C').Pawn
local LEN = _G.__cw_len or 5.0
local rows, t0 = {}, os.clock()
local function subs()
    local s = {}
    for i = 0, 40 do local o = {}; if pcall(function() p:InSubstate(i, o) end) and o.Success then s[#s + 1] = tostring(i) end end
    return table.concat(s, ",")
end
local function sample()
    local dt = os.clock() - t0
    local arm, fov, nw, z = "?", "?", "?", "?"
    pcall(function() arm = ("%.0f"):format(p.ThirdPersonSpringArm.TargetArmLength) end)
    pcall(function() fov = ("%.1f"):format(p.CameraThirdPerson.FieldOfView) end)
    pcall(function() nw = ("%.0f"):format(p.NewTargetArmLength) end)
    pcall(function() z = ("%.0f"):format(p:K2_GetActorLocation().Z) end)
    rows[#rows + 1] = ("%.2f arm %s fov %s target %s z %s subs %s"):format(dt, arm, fov, nw, z, subs())
    if dt >= LEN then
        local f = io.open(OUT, "w"); if f then f:write(table.concat(rows, "\n"), "\n"); f:close() end
        _G.__cw_done = true
        return
    end
    ExecuteInGameThreadWithDelay(50, function() pcall(sample) end)
end
_G.__cw_done = false
ExecuteInGameThread(function() pcall(sample) end)
return "cam watch started"
