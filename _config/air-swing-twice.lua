-- air-swing-twice.lua — KUMM 2026-11-07, KrinikConanLocomotion melee case: a jump, a swing at +150 ms, a second press at +450 ms (inside the first swing —
-- where a ground swing would chain the combo); sampled: attacking, the montage, the movement mode, the height. Read `_G.__ast.out`. [NOT-TESTED]
local h = FindFirstOf('BasePlayerChar_C')
local key = { KeyName = FName('LeftMouseButton') }
local t = { rows = {}, out = 'running' }
_G.__ast = t
local function press()
    h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_10(key)
    ExecuteInGameThreadWithDelay(60, function() h:InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_9(key) end)
end
local function state(tag)
    local att, mont, z = {}, '-', 0
    pcall(function() h:IsAttacking(att) end)
    pcall(function() local am = h.Mesh:GetAnimInstance():GetCurrentActiveMontage(); mont = am and am:IsValid() and am:GetFName():ToString() or '-' end)
    pcall(function() z = h:K2_GetActorLocation().Z end)
    t.rows[#t.rows + 1] = string.format('%s: attacking=%s mode=%d z=%.0f montage=%s', tag, tostring(att.IsAttacking), h.CharacterMovement.MovementMode, z, mont)
end
state('start')
h:Jump()
ExecuteInGameThreadWithDelay(150, function() state('press 1'); press() end)
ExecuteInGameThreadWithDelay(450, function() state('press 2'); press() end)
for i, ms in ipairs({ 300, 600, 900, 1300, 1800, 2500 }) do
    ExecuteInGameThreadWithDelay(ms, function() state('+' .. ms); if i == 6 then t.out = table.concat(t.rows, '\n') end end)
end
return 'armed'
