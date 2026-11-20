-- bush-corpse.lua — a humanoid corpse lying IN a pickable bush, made by code (KUMM bug 80: which prompt is true over a corpse in a bush).
-- 1) a 1 m grid within RADIUS around the hero is probed by the GAME's own foliage probe (EnvironmentFunctionLibrary:PickupGatheringOneInstance — what E
--    asks when no actor is targeted), from 2 m above each point straight down; the nearest true point is the bush;
-- 2) the nearest LIVING humanoid within 300 m (_G.__bc_npc_max, cm) is teleported onto it and killed there (KillCharacter as corpse-stand.sh).
-- Result in _G.__bush = {X,Y,Z}. Run: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/bush-corpse.lua')"  [NOT-TESTED]
local RADIUS = _G.__bc_radius or 10
local pc = FindFirstOf("FunCombat_PlayerController_C")
local hero = pc:K2_GetPawn()
local lib = StaticFindObject("/Script/ConanSandbox.Default__EnvironmentFunctionLibrary")
local h = hero:K2_GetActorLocation()
local hx, hy, hz = h.X, h.Y, h.Z
local best, bd, probes = nil, nil, 0
for dx = -RADIUS, RADIUS do
    for dy = -RADIUS, RADIUS do
        local d = math.sqrt(dx * dx + dy * dy)
        if d >= 2 and d <= RADIUS then
            local eye = { X = hx + dx * 100, Y = hy + dy * 100, Z = hz + 200 }
            probes = probes + 1
            if lib:PickupGatheringOneInstance(pc, hero, pc, eye, { X = 0, Y = 0, Z = -1 }, 400.0, pc.PickupTraceSphereRadius, {}, {}) == true then
                if not bd or d < bd then best, bd = { X = eye.X, Y = eye.Y, Z = hz }, d end
            end
        end
    end
end
if not best then return string.format("no pickable bush within %d m (%d probes)", RADIUS, probes) end
_G.__bush = best
local npc, nd
for _, x in ipairs(FindAllOf("HumanoidNPCCharacter_C") or {}) do
    local f = x:GetFullName()
    if not f:find("Default__", 1, true) and not f:find("WidgetTree", 1, true) then
        -- no IsDead on HumanoidNPCCharacter_C (2026-11-03 23:0x: «attempt to call a TrivialObject value» on all ten — the stand found nobody); a killed
        -- humanoid becomes a Corpse_C and its character goes, so every HumanoidNPCCharacter_C with a location is alive (as corpse-stand.sh takes it)
        local ok = pcall(function() return x:K2_GetActorLocation() end)
        if ok then
            local l = x:K2_GetActorLocation()
            local d = math.sqrt((l.X - hx) ^ 2 + (l.Y - hy) ^ 2)
            if d < (_G.__bc_npc_max or 30000) and (not nd or d < nd) then npc, nd = x, d end
        end
    end
end
if not npc then return string.format("bush at %.0f %.0f (%.1f m) but no living humanoid within 300 m", best.X, best.Y, bd) end
npc:K2_TeleportTo({ X = best.X, Y = best.Y, Z = best.Z + 120 }, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 })
npc:KillCharacter(0, FText(""), hero, {}, 0.0, hero)
return string.format("bush at %.0f %.0f %.0f (%.1f m from the hero, %d probes); %s (was %.0f m away) moved there and killed", best.X, best.Y, best.Z, bd, probes,
    npc:GetFName():ToString(), nd / 100)
