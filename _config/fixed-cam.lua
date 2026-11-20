-- fixed-cam.lua — a FIXED camera for repeatable clips: spawns a CameraActor and makes it the player's view target (KUMM bug 67).
-- Why: after ≈30 s with no real input the game's idle camera orbits the hero and ignores SetControlRotation (game map); a real Shift tap wakes it,
-- but that needs the game in front and steals the owner's keyboard (HOUSE_RULES rule 30). A CameraActor view target does not move at all.
--   bash pult.sh "lua _G.__fc={dz=350, pitch=-55, yaw=-135}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')"
--   _G.__fc = 'off' → the view back to the hero, the camera destroyed.
-- Position: the hero's location + dz (cm), or _G.__fc.x/y/z absolute. Leaves _G.__fixed_cam.
-- [TESTED: 2026-11-07 · held one view through 22 clips with the game behind and the idle camera active (frames read) · KUMM testcases/reports/2026-11-07_conan-palm-shadow-levers-wind-steps.md]
local a = _G.__fc or {}
local pc = FindFirstOf('FunCombat_PlayerController_C')
if a == 'off' then
    if _G.__fixed_cam and _G.__fixed_cam:IsValid() then
        pc:SetViewTargetWithBlend(pc.Pawn, 0.0, 0, 0.0, false)
        _G.__fixed_cam:K2_DestroyActor()
    end
    _G.__fixed_cam = nil
    return 'fixed cam off'
end
local h = pc.Pawn:K2_GetActorLocation()
local loc = { X = a.x or h.X, Y = a.y or h.Y, Z = a.z or (h.Z + (a.dz or 350)) }
local rot = { Pitch = a.pitch or -55.0, Yaw = a.yaw or -135.0, Roll = 0.0 }
local cam = _G.__fixed_cam
if not (cam and cam:IsValid()) then
    local GS = StaticFindObject('/Script/Engine.Default__GameplayStatics')
    local cls = StaticFindObject('/Script/Engine.CameraActor')
    local xf = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 }, Translation = loc, Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
    cam = GS:BeginDeferredActorSpawnFromClass(pc, cls, xf, 1, nil, 0)
    GS:FinishSpawningActor(cam, xf, 0)
    _G.__fixed_cam = cam
end
cam:K2_SetActorLocationAndRotation(loc, rot, false, {}, true)
pc:SetViewTargetWithBlend(cam, 0.0, 0, 0.0, false)
local l = cam:K2_GetActorLocation()
return string.format('fixed cam at %.0f %.0f %.0f pitch %.0f yaw %.0f', l.X, l.Y, l.Z, rot.Pitch, rot.Yaw)
