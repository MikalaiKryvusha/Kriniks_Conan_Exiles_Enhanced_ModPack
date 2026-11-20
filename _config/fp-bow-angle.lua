-- fp-bow-angle.lua — KUMM bug 95 (read-only remote probe; was scratch b95c.lua 2026-11-13 13:0x): the camera, the head, the hands and the bow in the HERO's
-- frame (forward along the body's facing, up), cm from the hero's actor origin, at the current view pitch; plus the bow hand in the camera's axes and its angle
-- off the view centre against the half vertical view — the countable check of «the held bow is in the first-person frame» (in frame when the angle < the half
-- view; vanilla 3.0.1: 73–78° at pitch 0…−80 vs 37.5°). Stop the idle orbit first: `GUIModuleController:EnableVanityCameraMode(false)` — the orbit voids every
-- reading after ≈ 30 s.
local pc = FindFirstOf('FunCombat_PlayerController_C')
local h = pc:K2_GetPawn()
local km = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
local al, ar = h:K2_GetActorLocation(), h:K2_GetActorRotation()
local hf = km:GetForwardVector({ Pitch = 0, Yaw = ar.Yaw, Roll = 0 })
local cm = pc.PlayerCameraManager
local cl, cr = cm:GetCameraLocation(), cm:GetCameraRotation()
local f, u = km:GetForwardVector(cr), km:GetUpVector(cr)
local out = { string.format('view pitch %.0f', cr.Pitch) }
local function body(name, l)
    local d = { X = l.X - al.X, Y = l.Y - al.Y, Z = l.Z - al.Z }
    out[#out + 1] = string.format('%-10s ahead %5.0f up %5.0f', name, d.X * hf.X + d.Y * hf.Y, d.Z)
end
body('camera', cl)
local m = h.Mesh
for _, b in ipairs({ 'b_head', 'b_spine_3', 'b_L_prop', 'b_R_hand' }) do body(b, m:GetSocketLocation(FName(b))) end
local bl = m:GetSocketLocation(FName('b_L_prop'))
local d = { X = bl.X - cl.X, Y = bl.Y - cl.Y, Z = bl.Z - cl.Z }
local fw, up = d.X * f.X + d.Y * f.Y + d.Z * f.Z, d.X * u.X + d.Y * u.Y + d.Z * u.Z
out[#out + 1] = string.format('bow hand in camera axes: forward %.0f up %.0f · %.0f° off the centre (half vertical view %.1f°)', fw, up,
    math.deg(math.atan(math.abs(up), fw)), math.deg(math.atan(math.tan(math.rad(cm:GetFOVAngle() / 2)) * 9 / 16)))
return table.concat(out, '\n')
