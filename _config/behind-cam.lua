-- behind-cam.lua — the hero faces a heading and a fixed camera stands behind him (third-person look over his shoulder, as the game's own camera).
-- Use: bash pult.sh "lua _G.__bc={yaw=50, dist=350, up=160, pitch=-3}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/behind-cam.lua')"
-- Why (KUMM 2026-11-09, water-scenes.sh): `fixed-cam.lua` places a camera at the hero + dz or at absolute coordinates; a beach view needs the camera BEHIND the
-- hero along his heading, so the hero stands in the frame looking over the water.
-- [NOT-TESTED]
local a = _G.__bc or {}
local yaw, dist, up, pitch = a.yaw or 0, a.dist or 350, a.up or 160, a.pitch or -3
local pc = FindFirstOf('PlayerController')
local hero = pc.Pawn
hero:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, false)
local h = hero:K2_GetActorLocation()
local r = math.rad(yaw)
_G.__fc = { x = h.X - dist * math.cos(r), y = h.Y - dist * math.sin(r), z = h.Z + up, pitch = pitch, yaw = yaw }
return dofile('D:/work/ai_sandbox/ConanExiles/_config/fixed-cam.lua')
