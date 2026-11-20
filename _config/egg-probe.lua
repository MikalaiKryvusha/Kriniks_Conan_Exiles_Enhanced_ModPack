-- bug 82 stand, step 2: re-aim from the CURRENT camera, then the same probe the plate asks (krinik_pickup_prompt.lua:207)
local hero = FindFirstOf('BasePlayerChar_C'); local pc = hero.Controller
local e = _G.__egg
local kml = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
local cam, bonus = hero.AdjustableCamera, 0.0
if not (cam and cam:IsValid() and cam:IsActive()) then cam, bonus = hero.CameraThirdPerson, hero.ThirdPersonSpringArm.TargetArmLength end
local from = cam:K2_GetComponentLocation()
pc:SetControlRotation(kml:FindLookAtRotation(from, e))
local fwd = cam:GetForwardVector()
local dir = { X = fwd.X, Y = fwd.Y, Z = fwd.Z }
local start = { X = from.X + dir.X * bonus, Y = from.Y + dir.Y * bonus, Z = from.Z + dir.Z * bonus }
local lib = StaticFindObject('/Script/ConanSandbox.Default__EnvironmentFunctionLibrary')
local found = lib:PickupGatheringOneInstance(pc, hero, pc, start, dir, pc.PickupInteractionDistance, pc.PickupTraceSphereRadius, {}, {})
local d = math.sqrt((from.X - e.X) ^ 2 + (from.Y - e.Y) ^ 2 + (from.Z - e.Z) ^ 2)
return ('probe %s · camera→egg %.0f cm · bonus %.0f · reach %.0f · radius %.0f · fwd (%.2f, %.2f, %.2f)'):format(tostring(found), d, bonus,
  pc.PickupInteractionDistance, pc.PickupTraceSphereRadius, dir.X, dir.Y, dir.Z)
