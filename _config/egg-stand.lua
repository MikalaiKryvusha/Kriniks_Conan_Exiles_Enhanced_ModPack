-- bug 82 stand, step 1: the hero 150 cm from egg instance 0 of the nearest SM_KappaEggs_Blueprint_C, looking at it
local hero = FindFirstOf('BasePlayerChar_C'); local pc = hero.Controller
local hp = hero:K2_GetActorLocation()
local best, bd
for _, a in ipairs(FindAllOf('SM_KappaEggs_Blueprint_C') or {}) do
  if not a:GetFullName():find('Default__', 1, true) then
    local p = a:K2_GetActorLocation()
    local d = (p.X - hp.X) ^ 2 + (p.Y - hp.Y) ^ 2
    if not bd or d < bd then best, bd = a, d end
  end
end
local ism = best.InstancedBushes
local n = ism:GetInstanceCount()
local t = {}
ism:GetInstanceTransform(0, t, true)
local e = t.Translation
local tgt = { X = e.X - 150, Y = e.Y, Z = e.Z + 100 }
hero:K2_SetActorLocation(tgt, false, {}, true)
local kml = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
local cam = hero.CameraThirdPerson
local from = cam:K2_GetComponentLocation()
local rot = kml:FindLookAtRotation(from, { X = e.X, Y = e.Y, Z = e.Z })
pc:SetControlRotation(rot)
_G.__egg = { X = e.X, Y = e.Y, Z = e.Z }
return ('instances %d · egg0 (%.0f, %.0f, %.0f) · hero set to (%.0f, %.0f, %.0f) · rot (%.1f, %.1f)'):format(n, e.X, e.Y, e.Z, tgt.X, tgt.Y, tgt.Z, rot.Pitch, rot.Yaw)
