-- egg-find.lua — KUMM bug 82: pickable eggs as the game holds them — foliage components (the stone-stand pattern, safe: no FindAllOf over components),
-- meshes whose name has «egg», instances not taken (scale > 0) within _G.__ef_m metres (default 300) of the hero.
--   bash pult.sh "lua _G.__ef_m=300; return dofile('D:/work/ai_sandbox/ConanExiles/_config/egg-find.lua')"
-- With _G.__ef_go = true the hero is put 150 cm west of the nearest egg, looking at it (pitch from the camera), like egg-stand.lua.
-- [NOT-TESTED]
local R = (_G.__ef_m or 300) * 100
local pc = FindFirstOf("FunCombat_PlayerController_C")
local p = pc:K2_GetPawn()
local hl = p:K2_GetActorLocation()
local h = { X = hl.X, Y = hl.Y, Z = hl.Z }
local cls = StaticFindObject('/Script/Foliage.FoliageInstancedStaticMeshComponent')
local meshes, best, bd, bmesh, bcomp = {}, nil, 1e18, '', ''
for _, a in ipairs(FindAllOf("InstancedFoliageActor") or {}) do
  local arr = a:K2_GetComponentsByClass(cls)
  for i = 1, #arr do
    local c = arr[i]:get()
    if c:IsValid() then
      local mesh = c.StaticMesh:GetFName():ToString()
      if mesh:lower():find('egg', 1, true) then
        local key = mesh .. ' [' .. c:GetClass():GetFName():ToString() .. ']'
        local r = c:GetInstancesOverlappingSphere(h, R, true)
        local t, live = {}, 0
        for j = 1, #r do
          c:GetInstanceTransform(r[j]:get(), t, true)
          if t.Scale3D and t.Scale3D.X > 0.001 then
            live = live + 1
            local dx, dy, dz = t.Translation.X - h.X, t.Translation.Y - h.Y, t.Translation.Z - h.Z
            local d = dx * dx + dy * dy + dz * dz
            if d < bd then bd, best, bmesh, bcomp = d, { X = t.Translation.X, Y = t.Translation.Y, Z = t.Translation.Z }, mesh, c:GetFName():ToString() end
          end
        end
        meshes[key] = (meshes[key] or 0) + live
      end
    end
  end
end
local out = {}
for k, v in pairs(meshes) do out[#out + 1] = k .. ' ' .. v end
if not best then return 'no egg instance within ' .. (R / 100) .. ' m · meshes: ' .. table.concat(out, ' | ') end
local res = string.format('nearest %s in %s at (%.0f %.0f %.0f) %.0f m · meshes: %s', bmesh, bcomp, best.X, best.Y, best.Z, math.sqrt(bd) / 100, table.concat(out, ' | '))
if _G.__ef_go then
  _G.__egg = best
  p:K2_SetActorLocation({ X = best.X - 150, Y = best.Y, Z = best.Z + 100 }, false, {}, true)
  local kml = StaticFindObject('/Script/Engine.Default__KismetMathLibrary')
  pc:SetControlRotation(kml:FindLookAtRotation(p.CameraThirdPerson:K2_GetComponentLocation(), best))
  res = res .. ' · hero moved'
end
return res
