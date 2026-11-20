-- pickup-cost-parts.lua — KUMM bug 99 (read-only remote probe, 2026-11-13): what the «E Взять» plate's check (KrinikConanUI krinik_pickup_prompt.lua) costs, part by
-- part, at the hero's current place and view. Each part runs N times; os.clock is wall time in 1 ms steps, so only the total over N calls is read (÷ N per call).
-- Parts: the sphere multi-trace and the line multi-trace (channel 6, the game's InteractionDistance + bonus, TraceSphereRadius) with their hit counts; the per-hit
-- loop of the mod (cosine, component, owner, two interface tests, line of sight) over those hits; the foliage probe PickupGatheringOneInstance; the info prompts the
-- mod walks each check (FindAllOf of the five W_*Info classes + the corpse strip — counts and one walk's cost).
--   bash pult.sh "lua _G.__pcp = {n=200}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/pickup-cost-parts.lua')"
-- [NOT-TESTED]
local N = (_G.__pcp and _G.__pcp.n) or 200
local pc = FindFirstOf('FunCombat_PlayerController_C')
local hero = pc:K2_GetPawn()
local ksl = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local iface = StaticFindObject('/Script/ConanSandbox.InteractableInterface')
local lib = StaticFindObject('/Script/ConanSandbox.Default__EnvironmentFunctionLibrary')
local NO = { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }
local cam, bonus = hero.AdjustableCamera, 0.0
if not (cam:IsValid() and cam:IsActive()) then cam, bonus = hero.CameraThirdPerson, hero.ThirdPersonSpringArm.TargetArmLength end
local loc, f = cam:K2_GetComponentLocation(), cam:GetForwardVector()
local len = pc.InteractionDistance + bonus
local stop = { X = loc.X + f.X * len, Y = loc.Y + f.Y * len, Z = loc.Z + f.Z * len }
local out = { string.format('N %d · camera %s · reach %.0f cm', N, cam:GetFName():ToString(), len) }
local function timed(name, fn)
    local t0 = os.clock()
    local r
    for _ = 1, N do r = fn() end
    out[#out + 1] = string.format('%-26s %.3f ms a call%s', name, (os.clock() - t0) * 1000.0 / N, r and (' · ' .. tostring(r)) or '')
end
local sphere, line = {}, {}
timed('sphere multi-trace', function() sphere = {}; ksl:SphereTraceMulti(pc, loc, stop, pc.TraceSphereRadius, 6, false, { hero }, 0, sphere, true, NO, NO, 0); return #sphere .. ' hits' end)
timed('line multi-trace', function() line = {}; ksl:LineTraceMulti(pc, loc, stop, 6, false, { hero }, 0, line, true, NO, NO, 0); return #line .. ' hits' end)
timed('per-hit loop (both lists)', function()
    local n = 0
    for _, hits in ipairs({ sphere, line }) do
        for i = 1, #hits do
            local h = hits[i]:get()
            local comp = h.Component:Get()
            local owner = comp and comp:IsValid() and comp:GetOwner() or nil
            if owner and owner:IsValid() then
                n = n + 1
                if ksl:DoesImplementInterface(comp, iface) or ksl:DoesImplementInterface(owner, iface) then
                    local p = h.ImpactPoint
                    pc:CheckLineOfSight(owner, { X = p.X + f.X * 10, Y = p.Y + f.Y * 10, Z = p.Z + f.Z * 10 }, comp, h.Item, false)
                end
            end
        end
    end
    return n .. ' hits with an owner'
end)
timed('foliage probe', function() return lib:PickupGatheringOneInstance(pc, hero, pc, { X = loc.X + f.X * bonus, Y = loc.Y + f.Y * bonus, Z = loc.Z + f.Z * bonus }, f,
    pc.PickupInteractionDistance, pc.PickupTraceSphereRadius, {}, {}) end)
local infos = 0
for _, n in ipairs({ 'W_DialogueNPCInfo_C', 'W_PlaceableInfo_C', 'W_SimpleInfo_C', 'W_ThrallInfo_C', 'W_DBNORevive_C', 'WBP_ContainerInfo_C' }) do
    local all = FindAllOf(n)
    infos = infos + (all and #all or 0)
end
out[#out + 1] = string.format('live info prompts the mod may walk: %d', infos)
return table.concat(out, '\n')
