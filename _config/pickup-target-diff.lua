-- pickup-target-diff.lua — KUMM bug 96, judge round 2, finding 1 (read-only remote probe):
--   bash pult.sh "lua _G.__ptd_n = 50; return dofile('D:/work/ai_sandbox/ConanExiles/_config/pickup-target-diff.lua')"
-- The plate's actor branch in two orders on the SAME traces: OLD (component → owner → interface → cosine → line of sight, pack 26f4cfa) and NEW (cosine
-- first from the impact point, the game calls only for a hit that can beat the best — krinik_pickup_prompt.lua after round 2). For 24 view directions around
-- the hero (yaw every 30°, pitch −10 and −35) it compares the chosen target (must be identical) and the time of each order over _G.__ptd_n repeats per
-- direction (os.clock steps 1 ms on this machine — the repeats are timed together). Restores the view at the end. Prints hits per direction too: the cost
-- difference grows with the hits. [NOT-TESTED]
local N = _G.__ptd_n or 50
local pc = FindFirstOf('FunCombat_PlayerController_C')
local hero = pc:K2_GetPawn()
local ksl = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local iface = StaticFindObject('/Script/ConanSandbox.InteractableInterface')
local NC = { R = 0, G = 0, B = 0, A = 0 }
local LOS_AHEAD = 10.0
local function valid(o) return o ~= nil and o:IsValid() end

local function traces(loc, fwd, len)
    local stop = { X = loc.X + fwd.X * len, Y = loc.Y + fwd.Y * len, Z = loc.Z + fwd.Z * len }
    local sphere, line = {}, {}
    ksl:SphereTraceMulti(pc, loc, stop, pc.TraceSphereRadius, 6, false, { hero }, 0, sphere, true, NC, NC, 0)
    ksl:LineTraceMulti(pc, loc, stop, 6, false, { hero }, 0, line, true, NC, NC, 0)
    return { sphere, line }
end

local function cosine(p, loc, fwd)
    local dx, dy, dz = p.X - loc.X, p.Y - loc.Y, p.Z - loc.Z
    local d = math.sqrt(dx * dx + dy * dy + dz * dz)
    return d > 0 and math.abs((dx * fwd.X + dy * fwd.Y + dz * fwd.Z) / d) or 0.0
end

local function old_order(sets, loc, fwd)
    local best, best_cos = nil, 0.0
    for _, hits in ipairs(sets) do
        for i = 1, #hits do
            local h = hits[i]:get()
            local comp = h.Component:Get()
            local owner = valid(comp) and comp:GetOwner() or nil
            if valid(owner) then
                local ci = ksl:DoesImplementInterface(comp, iface)
                if ci or ksl:DoesImplementInterface(owner, iface) then
                    local p = h.ImpactPoint
                    local c = cosine(p, loc, fwd)
                    if c > best_cos then
                        if pc:CheckLineOfSight(owner, { X = p.X + fwd.X * LOS_AHEAD, Y = p.Y + fwd.Y * LOS_AHEAD, Z = p.Z + fwd.Z * LOS_AHEAD }, comp, h.Item, false) then
                            best, best_cos = (ci and comp or owner), c
                        end
                    end
                end
            end
        end
    end
    return best
end

local function new_order(sets, loc, fwd)
    local best, best_cos = nil, 0.0
    for _, hits in ipairs(sets) do
        for i = 1, #hits do
            local h = hits[i]:get()
            local p = h.ImpactPoint
            local c = cosine(p, loc, fwd)
            if c > best_cos then
                local comp = h.Component:Get()
                local owner = valid(comp) and comp:GetOwner() or nil
                if valid(owner) then
                    local ci = ksl:DoesImplementInterface(comp, iface)
                    if ci or ksl:DoesImplementInterface(owner, iface) then
                        if pc:CheckLineOfSight(owner, { X = p.X + fwd.X * LOS_AHEAD, Y = p.Y + fwd.Y * LOS_AHEAD, Z = p.Z + fwd.Z * LOS_AHEAD }, comp, h.Item, false) then
                            best, best_cos = (ci and comp or owner), c
                        end
                    end
                end
            end
        end
    end
    return best
end

local function name(o) return o and o:GetFName():ToString() or 'none' end
local r0 = pc:GetControlRotation()
local cam, bonus = hero.CameraThirdPerson, hero.ThirdPersonSpringArm.TargetArmLength
local km = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
local out, same, diff, t_old, t_new, hits_total = {}, 0, 0, 0.0, 0.0, 0
for _, pitch in ipairs({ -10.0, -35.0 }) do
    for yaw = 0, 330, 30 do
        -- the trace follows the view direction from the camera's place (the control rotation turns the view; the camera's own place lags a frame,
        -- so the direction is built from the rotation itself)
        local f = km:GetForwardVector({ Pitch = pitch, Yaw = yaw, Roll = 0 })
        local fwd = { X = f.X, Y = f.Y, Z = f.Z }
        local loc = cam:K2_GetComponentLocation()
        local sets = traces(loc, fwd, pc.InteractionDistance + bonus)
        local nh = #sets[1] + #sets[2]
        hits_total = hits_total + nh
        local a, b = old_order(sets, loc, fwd), new_order(sets, loc, fwd)
        if a == b or (a and b and a:GetFullName() == b:GetFullName()) then same = same + 1 else diff = diff + 1 end
        local t0 = os.clock(); for _ = 1, N do old_order(sets, loc, fwd) end; local t1 = os.clock()
        for _ = 1, N do new_order(sets, loc, fwd) end; local t2 = os.clock()
        t_old, t_new = t_old + (t1 - t0), t_new + (t2 - t1)
        out[#out + 1] = string.format('p%d y%d hits %d: %s / %s', pitch, yaw, nh, name(a), name(b))
    end
end
pc:SetControlRotation(r0)
table.insert(out, 1, string.format('SAME %d DIFF %d · hits %d over 24 directions · per call: old %.4f ms, new %.4f ms (%d repeats each)', same, diff,
    hits_total, t_old * 1000 / (24 * N), t_new * 1000 / (24 * N), N))
return table.concat(out, '\n')
