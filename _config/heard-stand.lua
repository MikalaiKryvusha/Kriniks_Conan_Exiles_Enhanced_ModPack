-- heard-stand.lua — the hearing stand of KrinikConanArchery's «a missed arrow wakes the mob» (KUMM bug 85 TC K13): ONE remote call per step.
--   _G.__hs_step = 'near'   : the hero to _G.__hs_dist cm (default 2500) from the nearest live _G.__hs_class (default EAA_FeralTiger_C) — the creature is NOT moved
--                             (a creature teleported off its home is pulled back by its leash); remembers the creature's full name in _G.__hs_name
--   _G.__hs_step = 'dist'   : «<name> <m>» — the creature's distance to the hero now
--   _G.__hs_step = 'heard'  : the game's own «heard» on the creature: BPTargetDistributionComponent_C:UpdatedHeardActors({ hero })
-- [NOT-TESTED]
local step = _G.__hs_step or "dist"
local cls = _G.__hs_class or "EAA_FeralTiger_C"
local hero = FindFirstOf("BasePlayerChar_C")
local hl = hero:K2_GetActorLocation()
local hx, hy, hz = hl.X, hl.Y, hl.Z
local function find()
    if _G.__hs_name then
        for _, a in ipairs(FindAllOf(cls) or {}) do
            if a:IsValid() and a:GetFullName() == _G.__hs_name then return a end
        end
        return nil
    end
    local best, bd = nil, 1e18
    for _, a in ipairs(FindAllOf(cls) or {}) do
        if a:IsValid() and not a:GetFullName():find("Default__", 1, true) then
            local l = a:K2_GetActorLocation()
            local d = (l.X - hx) ^ 2 + (l.Y - hy) ^ 2
            if d < bd then best, bd = a, d end
        end
    end
    return best
end
if step == "near" then _G.__hs_name = nil end
local c = find()
if not c then return "no " .. cls end
local l = c:K2_GetActorLocation()
local cx, cy, cz = l.X, l.Y, l.Z
if step == "near" then
    _G.__hs_name = c:GetFullName()
    local dx, dy = hx - cx, hy - cy
    local d = math.sqrt(dx * dx + dy * dy)
    local r = _G.__hs_dist or 2500
    hero:K2_SetActorLocation({ X = cx + dx / d * r, Y = cy + dy / d * r, Z = cz + 100 }, false, {}, true)
    return string.format("%s: hero placed %.0f m from it", c:GetFName():ToString(), r / 100)
elseif step == "heard" then
    local t = c:GetComponentByClass(StaticFindObject("/Game/Systems/AI/NewAI/BPTargetDistributionComponent.BPTargetDistributionComponent_C"))
    if not (t and t:IsValid()) then return "no target distribution component" end
    t:UpdatedHeardActors({ hero })
    return c:GetFName():ToString() .. ": heard sent"
end
return string.format("%s %.1f m", c:GetFName():ToString(), math.sqrt((cx - hx) ^ 2 + (cy - hy) ^ 2 + (cz - hz) ^ 2) / 100)
