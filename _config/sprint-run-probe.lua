-- sprint-run-probe.lua — run the hero forward with sprint held for ~2 s by the remote, and read what the game says about sprinting WHILE moving.
-- Why (KUMM Locomotion notes «Sprint + bow», 2026-11-09 19:1x): sprint-probe.lua read K2_CanSprint = false with the hero STANDING and no bow — a standing
-- hero cannot sprint, so the stand-still probe cannot tell whether a drawn bow is the refusal. This probe moves the hero (AddMovementInput every tick on the
-- game thread, bTrySprint = true) and samples K2_CanSprint, MaxWalkSpeed, the speed and the substates at ~1.5 s into _G.__srp.
--   start: bash pult.sh "lua _G.__srp_draw=false; return dofile('D:/work/ai_sandbox/ConanExiles/_config/sprint-run-probe.lua')"
--   read (≥ 2.5 s later): bash pult.sh "lua return tostring(_G.__srp)"
--   _G.__srp_draw=true — the bow is drawn first by the hero's own RMB-down input event (the bow must be in hand), released at the end.
--   The bow into the hand first: the hot-bar slot 1 (the owner's save, frame 2026-11-09 19:50) —
--   bash pult.sh "lua FindFirstOf('FunCombat_PlayerController_C').Pawn:InpActEvt_Shortcut0_K2Node_InputActionEvent_25({KeyName=FName('One')}); return 'slot 1'"
-- [NOT-TESTED]
local pc = FindFirstOf('FunCombat_PlayerController_C')
local p = pc.Pawn
local fwd = p:GetActorForwardVector()
local t0 = os.clock()
local sampled = false
_G.__srp = 'running'

local function substates()
    local subs = {}
    for s = 0, 40 do
        local o = {}
        local ok = pcall(function() p:InSubstate(s, o) end)
        if ok and o.Success then subs[#subs + 1] = tostring(s) end
    end
    return table.concat(subs, ',')
end

-- The bow check is the Locomotion mod's own (krinik_air_combat.lua bow_in_hand): GetAttachedActors with THREE args, a class name with «bow», not on the
-- «sheath» socket. A two-arg call errors silently — the 2026-11-09 19:1x probe read «no bow» that way.
local function bow_in_hand()
    local arr = {}
    p:GetAttachedActors(arr, true, false)
    for i = 1, #arr do
        local a = arr[i]:get()
        if a:IsValid() and a:GetClass():GetFName():ToString():lower():find("bow", 1, true) then
            return not a:GetAttachParentSocketName():ToString():lower():find("sheath", 1, true), a:GetClass():GetFName():ToString()
        end
    end
    return false, "none"
end
local bow, bow_class = bow_in_hand()
_G.__srp_bow = tostring(bow) .. " " .. bow_class

if _G.__srp_draw then
    pcall(function() p:InpActEvt_SpecialActionV2_K2Node_InputActionEvent_7({KeyName = FName('RightMouseButton')}) end)
end

-- 2026-11-10 19:2x: this was LoopAsync(16, …) with `local done` re-made at every step — the loop NEVER stopped, ran off the game thread in the remote's
-- Lua state (the bug 85 class) and is the likely cause of the 19:14 crash. Now a game-thread chain of ExecuteInGameThreadWithDelay that ends by itself.
local STEP_MS = 16
local function step()
    do
        if not p:IsValid() then return end
        p.bTrySprint = true
        p:AddMovementInput(fwd, 1.0, false)
        local dt = os.clock() - t0
        if not sampled and dt >= 1.5 then
            sampled = true
            local o = {}
            pcall(function() p:K2_CanSprint(o) end)
            local v = p:GetVelocity()
            _G.__srp = string.format('draw=%s bow_in_hand=%s K2_CanSprint=%s bTrySprint=%s MaxWalkSpeed=%.1f speed=%.1f substates=%s',
                tostring(_G.__srp_draw), _G.__srp_bow, tostring(o.Value), tostring(p.bTrySprint), p.CharacterMovement.MaxWalkSpeed,
                math.sqrt(v.X * v.X + v.Y * v.Y), substates())
        end
        if dt >= 2.2 then
            p.bTrySprint = false
            if _G.__srp_draw then
                pcall(function() p:InpActEvt_SpecialActionV2_K2Node_InputActionEvent_8({KeyName = FName('RightMouseButton')}) end)
            end
            return
        end
    end
    ExecuteInGameThreadWithDelay(STEP_MS, function() pcall(step) end)
end
ExecuteInGameThread(function() pcall(step) end)
return 'started draw=' .. tostring(_G.__srp_draw)
