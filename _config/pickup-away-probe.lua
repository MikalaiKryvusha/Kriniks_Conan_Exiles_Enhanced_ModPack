-- pickup-away-probe.lua — KUMM 2026-11-07, the owner's 10:41 word on «E Взять» (checks 10 / s while shown, fade 0.10 s): with the plate shown, the view is
-- turned 90° away and the plate's render opacity is sampled every tick; reported: ticks / ms (by the game's own clock) until the fade starts and until it ends.
-- Use after `stone-stand.lua` with the plate shown: `return dofile('…/_config/pickup-away-probe.lua')`, then `return _G.__pap.out`. [NOT-TESTED]
local pc = FindFirstOf('PlayerController')
local gs = StaticFindObject('/Script/Engine.Default__GameplayStatics')
local plate
for _, w in ipairs(FindAllOf('UserWidget') or {}) do
    local n = w:GetFullName()
    if n:find('WBP_Crosshair_C', 1, true) and not n:find('Default__', 1, true) then
        local p = w:GetWidgetFromName(FName('HB_KrinikPickup'))
        if p and p:IsValid() then plate = p end
    end
end
local t = { rows = {}, out = 'running' }
_G.__pap = t
if not plate then t.out = 'no plate'; return 'no plate' end
local function now() return gs:GetRealTimeSeconds(pc) end
local t0 = now()
local first_drop, gone = nil, nil
local r = pc:GetControlRotation()
pc:SetControlRotation({ Pitch = r.Pitch, Yaw = r.Yaw + 90.0, Roll = r.Roll })
local function sample(n)
    ExecuteInGameThreadWithDelay(1, function()
        local op = plate:GetRenderOpacity()
        local ms = (now() - t0) * 1000
        if not first_drop and op < 0.999 then first_drop = ms end
        if not gone and (op <= 0.001 or plate:GetVisibility() == 1) then gone = ms end
        if n % 3 == 0 then t.rows[#t.rows + 1] = string.format('%.0f ms op %.2f vis %d', ms, op, plate:GetVisibility()) end
        if gone or n > 400 then
            t.out = string.format('fade starts %.0f ms after the turn, plate gone %.0f ms after (fade %.0f ms)\n', first_drop or -1, gone or -1,
                (gone or 0) - (first_drop or 0)) .. table.concat(t.rows, ' | ')
            return
        end
        sample(n + 1)
    end)
end
sample(0)
return 'armed'
