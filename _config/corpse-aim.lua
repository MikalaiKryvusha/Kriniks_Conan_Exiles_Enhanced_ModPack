-- corpse-aim.lua — the crosshair onto the corpse body found by corpse-face.lua (_G.__cf_body), so the game's own interaction trace (from the camera, along
-- the view — FunCombat_PlayerController.GetLineTraceStartAndEndFromCamera) hits the body and the quick-loot window opens by the player's own look.
-- Run a second call after corpse-face.lua (the camera has settled behind the hero by then):
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/corpse-aim.lua')"
-- Why (KUMM bug 75, 2026-11-02 15:2x): corpse-face turned the view to a fixed yaw 180 / pitch −35; a body in a bush or off that line was never under the
-- crosshair. _G.__cf_aim_dz raises the aim point above the body's root (default 30 cm). [NOT-TESTED]
local pc = FindFirstOf("FunCombat_PlayerController_C")
local p = pc:K2_GetPawn()
local b = _G.__cf_body
if not b then return "no _G.__cf_body — run corpse-face.lua first" end
local cam = p.CameraThirdPerson
if p.AdjustableCamera:IsActive() then cam = p.AdjustableCamera end
local c = cam:K2_GetComponentLocation()
-- The aim point: the body's PELVIS bone b_pelvis — the mesh root lies at the feet (frame 2026-11-02 15:24: the crosshair on the rug beside the feet, no window).
local target = { X = b.X, Y = b.Y, Z = b.Z + (_G.__cf_aim_dz or 30.0) }
for _, x in ipairs(FindAllOf("Corpse_C") or {}) do
    if not x:GetFullName():find("Default__", 1, true) then
        local ok, m = pcall(function() return x:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))[1]:get() end)
        if ok and m then
            local l = m:K2_GetComponentLocation()
            if math.abs(l.X - b.X) + math.abs(l.Y - b.Y) + math.abs(l.Z - b.Z) < 10 then
                local s = m:GetSocketLocation(FName("b_pelvis"))
                if s and (s.X ~= 0 or s.Y ~= 0) then target = { X = s.X, Y = s.Y, Z = s.Z } end
            end
        end
    end
end
local km = StaticFindObject("/Script/Engine.Default__KismetMathLibrary")
local r = km:FindLookAtRotation({ X = c.X, Y = c.Y, Z = c.Z }, target)
pc:SetControlRotation({ Pitch = r.Pitch, Yaw = r.Yaw, Roll = 0.0 })
local d = math.sqrt((target.X - c.X) ^ 2 + (target.Y - c.Y) ^ 2 + (target.Z - c.Z) ^ 2)
return string.format("aimed: pitch %.1f yaw %.1f, camera→body %.0f cm", r.Pitch, r.Yaw, d)
