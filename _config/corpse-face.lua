-- corpse-face.lua — the hero put 150 cm from the nearest Corpse_C (within 30 m), facing it, the view pitched down (bug 75 stand: the quick-loot window
-- opens by the player's own look). Run after corpse-stand.sh: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/corpse-face.lua')"
-- The corpse ACTOR stands far from its body (KrinikConanArchery notes: «the actor's location is 37 m off the body») — aim at the mesh's pelvis bone. [NOT-TESTED]
local pc = FindFirstOf("FunCombat_PlayerController_C")
local p = pc:K2_GetPawn()
local h = p:K2_GetActorLocation()
local best, bd
for _, x in ipairs(FindAllOf("Corpse_C") or {}) do
    local f = x:GetFullName()
    if not f:find("Default__", 1, true) and f:find("Corpse_C", 1, true) then
        local ok, l = pcall(function()   -- the body: the first SkeletalMeshComponent (KrinikConanArchery corpse_mesh), its bounds origin
            local arr = x:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))
            return arr[1]:get():K2_GetComponentLocation()
        end)
        if ok and l and (l.X ~= 0 or l.Y ~= 0) then
            local d = math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2)
            if d < (_G.__cf_radius or 3000) and (not bd or d < bd) then best, bd = l, d end
        end
    end
end
if not best then return "no corpse body within 30 m" end
_G.__cf_body = { X = best.X, Y = best.Y, Z = best.Z }   -- for corpse-aim.lua (the crosshair onto the body, next call)
local dist = _G.__cf_dist or 150
p:K2_SetActorLocation({ X = best.X + dist, Y = best.Y, Z = best.Z + 100 }, false, {}, true)
pc:SetControlRotation({ Pitch = _G.__cf_pitch or -35.0, Yaw = 180.0, Roll = 0.0 })
return string.format("corpse body at %.0f %.0f %.0f (%.1f m); hero +%d cm east, facing west", best.X, best.Y, best.Z, bd / 100, dist)
