-- s9_probe.lua — case S9 of bug 93 (2026-11-22 20:3x): the bow on its SHEATH, the heroine sprinting, RMB pressed mid-sprint by the hero's own input event.
-- Runs 4 s: bTrySprint + AddMovementInput every 16 ms (as sprint-run-probe.lua); RMB down (InpActEvt_SpecialActionV2_…_7) at 1.5 s, up (…_8) at 2.7 s;
-- a row every ~250 ms: time, speed, MaxWalkSpeed, substates, where the bow hangs. Result: s9_probe.txt beside it; _G.__s9_done = true. A one-shot probe.
local OUT = [[D:/work/ai_sandbox/KUMM/.work/tmp/s9_probe.txt]]
local pc = FindFirstOf('FunCombat_PlayerController_C')
local p = pc.Pawn
local fwd = p:GetActorForwardVector()
local rows = {}
local function bow_where()
    local arr = {}
    p:GetAttachedActors(arr, true, false)
    for i = 1, #arr do
        local a = arr[i]:get()
        if a:IsValid() and a:GetClass():GetFName():ToString():lower():find("bow", 1, true) then
            return a:GetAttachParentSocketName():ToString()
        end
    end
    return "no bow"
end
local function substates()
    local subs = {}
    for s = 0, 40 do
        local o = {}
        if pcall(function() p:InSubstate(s, o) end) and o.Success then subs[#subs + 1] = tostring(s) end
    end
    return table.concat(subs, ",")
end
rows[#rows + 1] = "start: bow on " .. bow_where() .. ", HasWeaponsEquipped " .. tostring(p:HasWeaponsEquipped())
local DOWN_S, UP_S, LEN_S, ROW_S = _G.__s9_down or 1.5, _G.__s9_up or 2.7, _G.__s9_len or 4.0, _G.__s9_row or 0.25
local t0, next_row, rmb_down, rmb_up = os.clock(), 0, false, false
local STEP_MS = 16
local function step()
    if not p:IsValid() then return end
    local dt = os.clock() - t0
    local watch = _G.__s9_watch   -- watch only: the input is REAL (mouse-seq.ps1) — the remote cannot hold RMB, the game reads the physical key
    if not watch then
        p.bTrySprint = true
        p:AddMovementInput(fwd, 1.0, false)
    end
    if not watch and not rmb_down and dt >= DOWN_S then
        rmb_down = true
        pcall(function() p:InpActEvt_SpecialActionV2_K2Node_InputActionEvent_7({ KeyName = FName('RightMouseButton') }) end)
        rows[#rows + 1] = ("%.2f s RMB down"):format(dt)
    end
    if not watch and not rmb_up and dt >= UP_S then
        rmb_up = true
        pcall(function() p:InpActEvt_SpecialActionV2_K2Node_InputActionEvent_8({ KeyName = FName('RightMouseButton') }) end)
        rows[#rows + 1] = ("%.2f s RMB up"):format(dt)
    end
    if dt >= next_row then
        next_row = next_row + ROW_S
        local v = p:GetVelocity()
        rows[#rows + 1] = ("%.2f s speed %.0f max %.0f subs %s bow %s"):format(dt, math.sqrt(v.X * v.X + v.Y * v.Y), p.CharacterMovement.MaxWalkSpeed,
            substates(), bow_where())
    end
    if dt >= LEN_S then
        if not watch then p.bTrySprint = false end
        local f = io.open(OUT, "w")
        if f then f:write(table.concat(rows, "\n"), "\n"); f:close() end
        _G.__s9_done = true
        return
    end
    ExecuteInGameThreadWithDelay(STEP_MS, function() pcall(step) end)
end
_G.__s9_done = false
ExecuteInGameThread(function() pcall(step) end)
return "s9 started: " .. rows[1]
