-- air-attack-probe.lua — KUMM 2026-11-07, the owner's melee-in-a-jump request (KrinikConanLocomotion): a background twin of «LMB» (the hero's own input
-- action events PrimaryActionV2 — pressed / released) with or without a jump, and what the game did: attacking, the montage, the movement mode, the height.
-- Use: `_G.__aap = { jump = true, press_after_ms = 150, order = '10,9' }; return dofile('…/_config/air-attack-probe.lua')`, then `return _G.__aap.out`.
-- [NOT-TESTED]
local cfg = _G.__aap or {}
local h = FindFirstOf('BasePlayerChar_C')
local key = { KeyName = FName('LeftMouseButton') }
local t = { out = 'running', rows = {} }
for k, v in pairs(cfg) do t[k] = v end
_G.__aap = t
local function state(tag)
    local att = {}
    pcall(function() h:IsAttacking(att) end)
    local m = h.CharacterMovement
    local mont = ''
    pcall(function() local am = h.Mesh:GetAnimInstance():GetCurrentActiveMontage(); mont = am and am:IsValid() and am:GetFName():ToString() or '-' end)
    local z = 0
    pcall(function() z = h:K2_GetActorLocation().Z end)
    t.rows[#t.rows + 1] = string.format('%s: attacking=%s mode=%d z=%.0f montage=%s', tag, tostring(att.IsAttacking), m.MovementMode, z, mont)
end
state('start')
if t.jump then h:Jump() end
if t.exit8 then ExecuteInGameThreadWithDelay(30, function() pcall(function() h:ExitSubstate(8, {}) end); state('exit8') end) end
local a, b = (t.order or '10,9'):match('(%d+),(%d+)')
ExecuteInGameThreadWithDelay(t.press_after_ms or 150, function()
    if t.reset_combo then pcall(function() h.ComboID = FName('None'); h.ServerComboID = FName('None') end) end
    state('before press id=' .. tostring(pcall(function() return h.ComboID:ToString() end) and h.ComboID:ToString()))
    pcall(function() h['InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_' .. a](h, key) end)
    ExecuteInGameThreadWithDelay(60, function()
        pcall(function() h['InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_' .. b](h, key) end)
        for i, ms in ipairs({ 40, 150, 300, 600, 1200 }) do
            ExecuteInGameThreadWithDelay(ms, function() state('+' .. ms) ; if i == 5 then t.out = table.concat(t.rows, '\n') end end)
        end
    end)
end)
return 'armed'
