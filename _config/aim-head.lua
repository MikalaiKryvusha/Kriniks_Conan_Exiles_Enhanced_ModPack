-- aim-head.lua — the crosshair onto the HEAD bone of the stand's creature (KUMM bug 85 TC K14–K17, headshots of KrinikConanArchery).
--   bash pult.sh "lua _G.__ah_class='BP_NPC_Wildlife_Kappa_C'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/aim-head.lua')"
-- The nearest live instance of _G.__ah_class (default the Kappa) to the hero; its first bone whose name contains «head» (case-insensitive) — the same test the
-- mod uses; the controller is turned to look from the active camera at that bone (+ _G.__ah_dz cm, default 0). Prints «<creature> <bone> <m> yaw pitch».
-- Afterwards a shot (remote LaunchProjectile or a real click) flies at the camera probe point — the bone. [NOT-TESTED]
local cls = _G.__ah_class or "BP_NPC_Wildlife_Kappa_C"
local pc = FindFirstOf("FunCombat_PlayerController_C")
local hero = pc:K2_GetPawn()
local h = hero:K2_GetActorLocation()
local hx, hy, hz = h.X, h.Y, h.Z
local best, bd = nil, 1e18
for _, a in ipairs(FindAllOf(cls) or {}) do
    if a:IsValid() and not a:GetFullName():find("Default__", 1, true) then
        local l = a:K2_GetActorLocation()
        local d = (l.X - hx) ^ 2 + (l.Y - hy) ^ 2 + (l.Z - hz) ^ 2
        if d < bd then best, bd = a, d end
    end
end
if not best then return "no " .. cls end
local mesh = best.Mesh
local bone = nil
for i = 0, mesh:GetNumBones() - 1 do
    local n = mesh:GetBoneName(i):ToString()
    if n:lower():find("head", 1, true) then bone = n; break end
end
if not bone then return "no head bone on " .. best:GetFName():ToString() end
local b = mesh:GetSocketLocation(FName(bone))
local tx, ty, tz = b.X, b.Y, b.Z + (_G.__ah_dz or 0.0)
local cam = hero.CameraThirdPerson
if hero.AdjustableCamera:IsActive() then cam = hero.AdjustableCamera end
local c = cam:K2_GetComponentLocation()
local cx, cy, cz = c.X, c.Y, c.Z
local dx, dy, dz = tx - cx, ty - cy, tz - cz
local yaw = math.deg(math.atan(dy, dx))
local pitch = math.deg(math.atan(dz, math.sqrt(dx * dx + dy * dy)))
pc:SetControlRotation({ Pitch = pitch, Yaw = yaw, Roll = 0.0 })
return string.format("%s %s %.1f m yaw %.1f pitch %.1f", best:GetFName():ToString(), bone, math.sqrt(bd) / 100, yaw, pitch)
