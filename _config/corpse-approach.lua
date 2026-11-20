-- corpse-approach.lua — the hero put DIST cm from the nearest Corpse_C body ON THE SIDE HE ALREADY STANDS (the line body → hero), facing it; sets
-- _G.__cf_body for corpse-fill.lua / corpse-aim.lua. Run: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/corpse-approach.lua')"
-- Why (KUMM bug 75, 2026-11-03 19:2x): corpse-face.lua puts the hero EAST of the body — in a canyon that was inside a cliff (frame st5) and a crevice
-- (st6); the side the hero came from is open ground by construction. _G.__ca_dist (default 300 — the distance the quick-loot window opened at, bug 75),
-- _G.__ca_radius (default 3000 cm). [NOT-TESTED]
local DIST = _G.__ca_dist or 300
local RADIUS = _G.__ca_radius or 3000
local pc = FindFirstOf("FunCombat_PlayerController_C")
local p = pc:K2_GetPawn()
local hl = p:K2_GetActorLocation()
local h = { X = hl.X, Y = hl.Y, Z = hl.Z }
local best, bd
for _, x in ipairs(FindAllOf("Corpse_C") or {}) do
    if not x:GetFullName():find("Default__", 1, true) then
        local ok, l = pcall(function()
            return x:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))[1]:get():K2_GetComponentLocation()
        end)
        if ok and l and (l.X ~= 0 or l.Y ~= 0) then
            local d = math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2)
            if d < RADIUS and (not bd or d < bd) then best, bd = { X = l.X, Y = l.Y, Z = l.Z }, d end
        end
    end
end
if not best then return "no corpse within " .. RADIUS / 100 .. " m" end
local dx, dy = h.X - best.X, h.Y - best.Y
local len = math.sqrt(dx * dx + dy * dy)
if len < 1 then dx, dy, len = 1, 0, 1 end
local to = { X = best.X + dx / len * DIST, Y = best.Y + dy / len * DIST, Z = math.max(h.Z, best.Z) + 100 }
local yaw = math.deg(math.atan(best.Y - to.Y, best.X - to.X))
p:K2_TeleportTo(to, { Pitch = 0.0, Yaw = yaw, Roll = 0.0 })
pc:SetControlRotation({ Pitch = -25.0, Yaw = yaw, Roll = 0.0 })
_G.__cf_body = best
return string.format("corpse body at %.0f %.0f %.0f (%.1f m); hero %d cm from it on his own side, yaw %.1f", best.X, best.Y, best.Z, bd / 100, DIST, yaw)
