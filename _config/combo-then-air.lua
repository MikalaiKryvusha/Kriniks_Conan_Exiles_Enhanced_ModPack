-- combo-then-air.lua — KUMM 2026-11-07, KrinikConanLocomotion melee case M3: two ground swings (c0, c1), Space pressed during the second (the game
-- queues the jump until the swing ends), and a swing pressed on the FIRST tick the hero is airborne. Expected with the take-off reset: the air montage is the
-- first light step (…_light_c0), not the next combo step. Read `_G.__cta.out`. [NOT-TESTED]
local h = FindFirstOf('BasePlayerChar_C')
local lmb, space = { KeyName = FName('LeftMouseButton') }, { KeyName = FName('SpaceBar') }
local t = { rows = {}, out = 'running' }
_G.__cta = t
local function press()
    h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_10(lmb)
    ExecuteInGameThreadWithDelay(60, function() h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_9(lmb) end)
end
local function mont()
    local m = '-'
    pcall(function() local am = h.Mesh:GetAnimInstance():GetCurrentActiveMontage(); m = am and am:IsValid() and am:GetFName():ToString() or '-' end)
    return m
end
local function row(tag) t.rows[#t.rows + 1] = string.format('%s: mode=%d montage=%s', tag, h.CharacterMovement.MovementMode, mont()) end
press(); row('ground press 1')
ExecuteInGameThreadWithDelay(450, function() press(); row('ground press 2') end)
ExecuteInGameThreadWithDelay(700, function()
    h:InpActEvt_Jump_K2Node_InputActionEvent_27(space)
    ExecuteInGameThreadWithDelay(40, function() h:InpActEvt_Jump_K2Node_InputActionEvent_26(space) end)
    row('space (queued)')
end)
local function wait_air(n)
    ExecuteInGameThreadWithDelay(1, function()
        if h.CharacterMovement.MovementMode == 3 then
            row('airborne'); press()
            ExecuteInGameThreadWithDelay(150, function() row('air +150') end)
            ExecuteInGameThreadWithDelay(400, function() row('air +400'); t.out = table.concat(t.rows, '\n') end)
            return
        end
        if n > 600 then row('never airborne'); t.out = table.concat(t.rows, '\n'); return end
        wait_air(n + 1)
    end)
end
-- the jump on the first tick the swing has ended (the combo window may still be open then), unless the queued Space already took off
local function wait_swing_end(n)
    ExecuteInGameThreadWithDelay(1, function()
        if h.CharacterMovement.MovementMode == 3 then wait_air(0); return end
        local att = {}
        pcall(function() h:IsAttacking(att) end)
        if att.IsAttacking ~= true then row('swing ended — Jump()'); h:Jump(); wait_air(0); return end
        if n > 900 then row('swing never ended'); t.out = table.concat(t.rows, '\n'); return end
        wait_swing_end(n + 1)
    end)
end
ExecuteInGameThreadWithDelay(760, function() wait_swing_end(0) end)
return 'armed'
