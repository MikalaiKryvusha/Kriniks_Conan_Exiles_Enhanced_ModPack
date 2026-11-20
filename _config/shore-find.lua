-- shore-find.lua — from the hero, march along a heading and find the water's edge of the sea: ground traced down every `step` cm; the first point whose ground
-- lies below the sea surface is water; the shore point is the last dry one. Moves the hero there (120 above the ground) facing the heading.
-- Use: bash pult.sh "lua _G.__sf={yaw=60, step=300, max=40000, sea=-20240, back=400}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/shore-find.lua')"
--   sea — the ocean surface Z (WaterBodyOcean_2 at −20240, 2026-11-09); back — how far behind the edge the hero stands (cm).
-- Why (KUMM 2026-11-09, `[OWNER]` «ставь на пляжи» · «больших водных массивово»): a point picked from a top frame lands under water or on a slope;
-- the edge is found by measuring the ground against the sea level. Only streamed terrain answers — keep `max` within ≈ 1 km of the hero.
-- [NOT-TESTED]
local a = _G.__sf or {}
local yaw, step, maxd, sea, back = a.yaw or 0, a.step or 300, a.max or 40000, a.sea or -20240, a.back or 400
local p = FindFirstOf('PlayerController').Pawn
local ksl = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local h = p:K2_GetActorLocation()
local r = math.rad(yaw)
local cx, cy = math.cos(r), math.sin(r)
local function ground(x, y)
  local hit = {}
  local ok = ksl:LineTraceSingle(p, { X = x, Y = y, Z = h.Z + 30000 }, { X = x, Y = y, Z = -80000 }, 0, true, { p }, 0, hit, true,
    { R = 1, G = 0, B = 0, A = 1 }, { R = 0, G = 1, B = 0, A = 1 }, 0)
  if not ok then return nil end
  return hit.ImpactPoint.Z
end
local lastdry
for d = 0, maxd, step do
  local x, y = h.X + cx * d, h.Y + cy * d
  local z = ground(x, y)
  if z and z > sea then lastdry = d
  elseif z and lastdry then
    local sd = math.max(0, lastdry - back)
    local sx, sy = h.X + cx * sd, h.Y + cy * sd
    local sz = ground(sx, sy) or z
    p:K2_SetActorLocation({ X = sx, Y = sy, Z = sz + 120 }, false, {}, true)
    p:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false)
    return string.format('SHORE %.0f %.0f ground %.0f (sea %.0f, water starts %.0f m ahead, hero %.0f m back from the edge)', sx, sy, sz, sea, d / 100, back / 100)
  end
end
return 'NO EDGE within ' .. (maxd / 100) .. ' m'
