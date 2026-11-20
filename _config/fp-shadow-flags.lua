-- fp-shadow-flags.lua — KUMM bug 98 (read-only remote probe, 2026-11-13): who of the hero's visible parts may cast a shadow. Walks the hero's component tree
-- from the root through AttachChildren (the bow, the quiver, armour pieces and the held arrow are actors attached to the mesh's sockets — their roots show up here
-- too) and prints, per primitive component: owner · name · visible · hiddenInGame · CastShadow · dynamic · hidden-shadow · ownerNoSee · onlyOwnerSee · selfOnly.
-- Run in first person AND in third person; the difference is the game's first-person switch.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/fp-shadow-flags.lua')"
-- [NOT-TESTED]
local pc = FindFirstOf('FunCombat_PlayerController_C')
local h = pc:K2_GetPawn()
local out = {}
local function b(v) return v and '1' or '0' end
local function flags(c)
    local ok, s = pcall(function()
        local fpt = '?'
        pcall(function() fpt = tostring(c.FirstPersonPrimitiveType) end)   -- UE 5.5+: 0 None · 1 FirstPerson · 2 WorldSpaceRepresentation (bug 98 hypothesis 0)
        return string.format('vis %s hig %s cast %s dyn %s hidSh %s noSee %s onlySee %s self %s fpType %s',
            b(c:IsVisible()), b(c.bHiddenInGame), b(c.CastShadow), b(c.bCastDynamicShadow), b(c.bCastHiddenShadow),
            b(c.bOwnerNoSee), b(c.bOnlyOwnerSee), b(c.bSelfShadowOnly), fpt)
    end)
    return ok and s or ('flags failed: ' .. tostring(s))
end
local prim = StaticFindObject('/Script/Engine.PrimitiveComponent')
local seen = 0
local function walk(c, depth)
    if not c or not c:IsValid() or depth > 6 or seen > 60 then return end
    seen = seen + 1
    if c:IsA(prim) then
        local o = c:GetOwner()
        out[#out + 1] = string.format('%s%s · %s · %s', string.rep('  ', depth), o and o:IsValid() and o:GetFName():ToString() or '?',
            c:GetFName():ToString(), flags(c))
    end
    pcall(function() c.AttachChildren:ForEach(function(_, e) walk(e:get(), depth + 1) end) end)
end
walk(h.RootComponent, 0)
local cam = pc.PlayerCameraManager
out[#out + 1] = string.format('camera %s · fov %.0f', cam:GetFName():ToString(), cam:GetFOVAngle())
return table.concat(out, '\n')
