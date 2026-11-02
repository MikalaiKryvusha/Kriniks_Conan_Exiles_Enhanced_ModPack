-- stone-stand.lua — moved from a session scratchpad into the pack 2026-11-02 (it served P6–P9 of plan 42 and the 11-02 batch); run:
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/stone-stand.lua')"
-- Stand for plan 42 cases P6/P7: the nearest pickable stone (SM_rock_small*, scale > 0) within 30 m; the hero put 60 cm east of it,
-- the view turned at the stone with the pitch STAND_PITCH (the owner's case: stones at his feet, the camera above).
local STAND_PITCH = _G.__stand_pitch or -50.0
local OFFSET_CM = _G.__stand_offset or 60.0
local pc = FindFirstOf("FunCombat_PlayerController_C")
local p = pc:K2_GetPawn()
local hl = p:K2_GetActorLocation()
local h = { X = hl.X, Y = hl.Y, Z = hl.Z }
local cls = StaticFindObject('/Script/Foliage.FoliageInstancedStaticMeshComponent')
local best, bd, bmesh = nil, 1e18, ""
for _, a in ipairs(FindAllOf("InstancedFoliageActor") or {}) do
  local arr = a:K2_GetComponentsByClass(cls)
  for i = 1, #arr do
    local c = arr[i]:get()
    if c:IsValid() and c:GetClass():GetFName():ToString() == "PickupFoliageComponent_C" then
      local mesh = c.StaticMesh:GetFName():ToString()
      if mesh:find("SM_rock_small", 1, true) then
        local r = c:GetInstancesOverlappingSphere(h, 3000, true)
        local t = {}
        for j = 1, #r do
          c:GetInstanceTransform(r[j]:get(), t, true)
          if t.Scale3D and t.Scale3D.X > 0.001 then
            local dx, dy, dz = t.Translation.X - h.X, t.Translation.Y - h.Y, t.Translation.Z - h.Z
            local d = dx * dx + dy * dy + dz * dz
            if d < bd then bd, best, bmesh = d, { X = t.Translation.X, Y = t.Translation.Y, Z = t.Translation.Z }, mesh end
          end
        end
      end
    end
  end
end
if not best then return "no stone within 30 m" end
_G.__stand_stone = best
p:K2_SetActorLocation({ X = best.X + OFFSET_CM, Y = best.Y, Z = best.Z + 100.0 }, false, {}, true)
pc:SetControlRotation({ Pitch = STAND_PITCH, Yaw = 180.0, Roll = 0.0 })
return string.format("stone %s at %.0f %.0f %.0f (was %.0f m away); hero +%.0f cm east, pitch %.0f", bmesh, best.X, best.Y, best.Z,
  math.sqrt(bd) / 100.0, OFFSET_CM, STAND_PITCH)
