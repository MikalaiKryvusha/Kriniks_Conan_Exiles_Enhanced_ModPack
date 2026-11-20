-- spawn-creature.lua — spawn a creature of a LOADED class in front of the hero, give it its AI controller, optionally freeze it (KUMM bug 85 stands).
--   bash pult.sh "lua _G.__sc_class='/Game/Characters/NPCs/Hooved_Wild/Blueprints/BP_NPC_Wildlife_Gazelle.BP_NPC_Wildlife_Gazelle_C'; _G.__sc_n=3; return dofile('D:/work/ai_sandbox/ConanExiles/_config/spawn-creature.lua')"
-- _G.__sc_dist cm ahead (default 1200), _G.__sc_n creatures 300 cm apart (default 1), _G.__sc_freeze (default true: CustomTimeDilation 0).
-- Why: CheatManager:Summon spawns nothing in 3.0.1 (2026-11-07 22:1x); the native path is GameplayStatics BeginDeferredActorSpawnFromClass → FinishSpawningActor,
-- then Pawn:SpawnDefaultController (a spawned pawn has no brain otherwise). The class must be loaded (a live instance nearby or a previous load). [NOT-TESTED]
local cls = StaticFindObject(_G.__sc_class or "/Game/Characters/NPCs/Hooved_Wild/Blueprints/BP_NPC_Wildlife_Gazelle.BP_NPC_Wildlife_Gazelle_C")
if not (cls and cls:IsValid()) then return "class not loaded: " .. tostring(_G.__sc_class) end
local hero = FindFirstOf("BasePlayerChar_C")
local hl = hero:K2_GetActorLocation()
local yaw = math.rad(FindFirstOf("FunCombat_PlayerController_C"):GetControlRotation().Yaw)
local fx, fy = math.cos(yaw), math.sin(yaw)
local rx, ry = -fy, fx
local GS = StaticFindObject("/Script/Engine.Default__GameplayStatics")
local n = _G.__sc_n or 1
local dist = _G.__sc_dist or 1200
local made = {}
for i = 0, n - 1 do
    local off = (i - (n - 1) / 2) * 300
    local t = {
        Rotation = { X = 0.0, Y = 0.0, Z = math.sin((yaw + math.pi / 2) / 2), W = math.cos((yaw + math.pi / 2) / 2) },
        Translation = { X = hl.X + fx * dist + rx * off, Y = hl.Y + fy * dist + ry * off, Z = hl.Z + 60 },
        Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 },
    }
    local a = GS:BeginDeferredActorSpawnFromClass(hero, cls, t, 1, nil, 0)   -- 1 = AdjustIfPossibleButAlwaysSpawn
    if a and a:IsValid() then
        GS:FinishSpawningActor(a, t, 0)
        pcall(function() a:SpawnDefaultController() end)
        if _G.__sc_freeze ~= false then a.CustomTimeDilation = 0 end
        made[#made + 1] = a:GetFName():ToString()
    end
end
return "spawned " .. #made .. ": " .. table.concat(made, ", ")
