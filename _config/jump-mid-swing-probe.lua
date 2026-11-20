-- jump-mid-swing-probe.lua — KUMM 2026-11-07 (KrinikConanLocomotion, melee): a swing on the ground (the hero's PrimaryActionV2 events), then a jump
-- `jump_after_ms` later by the hero's own Jump input event (pressed + released) — does the hero leave the ground? `launch = true` adds our fix by hand
-- (LaunchCharacter with JumpZVelocity when the jump was refused). Read `_G.__jms.out`. [NOT-TESTED]
local cfg = _G.__jms or {}
local h = FindFirstOf('BasePlayerChar_C')
local t = { out = 'running', rows = {} }
for k, v in pairs(cfg) do t[k] = v end
_G.__jms = t
local function state(tag)
    local att = {}
    pcall(function() h:IsAttacking(att) end)
    local z = 0
    pcall(function() z = h:K2_GetActorLocation().Z end)
    t.rows[#t.rows + 1] = string.format('%s: attacking=%s mode=%d z=%.0f', tag, tostring(att.IsAttacking), h.CharacterMovement.MovementMode, z)
end
local lmb = { KeyName = FName('LeftMouseButton') }
local space = { KeyName = FName('SpaceBar') }
state('start')
h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_10(lmb)
ExecuteInGameThreadWithDelay(60, function() h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_9(lmb) end)
ExecuteInGameThreadWithDelay(t.jump_after_ms or 250, function()
    state('before jump')
    pcall(function() h:InpActEvt_Jump_K2Node_InputActionEvent_27(space) end)
    ExecuteInGameThreadWithDelay(30, function()
        pcall(function() h:InpActEvt_Jump_K2Node_InputActionEvent_26(space) end)
        state('after jump input')
        if t.launch and h.CharacterMovement:IsMovingOnGround() then
            h:LaunchCharacter({ X = 0, Y = 0, Z = h.CharacterMovement.JumpZVelocity }, false, true)
            state('launched')
        end
        for i, ms in ipairs({ 100, 250, 500, 900, 1400, 1900, 2400, 3000 }) do
            ExecuteInGameThreadWithDelay(ms, function() state('+' .. ms); if i == 8 then t.out = table.concat(t.rows, '\n') end end)
        end
    end)
end)
return 'armed'
