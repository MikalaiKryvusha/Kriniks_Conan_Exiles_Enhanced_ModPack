-- wall-stand.lua — KUMM wall jump recon (KrinikConanLocomotion PLAN, the owner 2026-11-02 09:07 / 2026-11-14 09:54): a climbing stand without real input.
-- Steps by `_G.__ws_step` (one remote call each, the hub closed, the hero on foot):
--   'find'     — a ring of line traces around the hero (every 15°, up to 12 m, at chest height) → the nearest near-vertical hit (|normal.Z| < 0.3); the hero
--                turned to face it and put 60 cm from it; keeps `S.wall` (yaw, dist, normal, point) and `S.yaw`. At the desert arch run it TWICE: from the
--                teleport point the nearest wall is one the hero does not climb (yaw 135, 572 cm); the second run finds the climbable one (yaw 165).
--   'climb'    — 1.2 s: AddMovementInput into the wall every tick; the jump PRESS (`_26`, InputKeyEvent 0) at `_G.__ws_cpress` (0.35), the RELEASE (`_27`, 1) at
--                `_G.__ws_crel` (0.6, never before the press + 0.05); `Climb(false)` from the press − 0.05 to the press + 0.55 unless `_G.__ws_climbcall == false`
--                (the defaults climbed 2026-11-14 16:33 and 17:01; at 16:32 a press at 0.15 with the OLD fixed climb window 0.3–0.9 s took off before the
--                climb request and did not climb — the press-tied window is untested for early presses). Samples every 0.2 s: mode, z; the last sample
--                line lists the moments the events really fired (`events: press@… release@…`).
--   'jumpwall' — on the wall: PRESS at 0.05 s, RELEASE at `_G.__ws_rel` (0.25); samples every 0.1 s: mode, place, velocity, for 1 s.
--   'airshot'  — W6: jump PRESS 0.05 / RELEASE 0.12, the bow's draw (RMB press `_7`) at `_G.__ws_draw` (0.25), the shot (LMB `_9` / `_10`) at `_G.__ws_shot`
--                (0.75), RMB release `_8` at shot + 0.2; `_G.__ws_exit8` — leave substate 8 at 0.1 s by hand (experiment); samples every 0.1 s: mode,
--                substates 0..22 (`ECharacterSubState`), character state (`ECharacterState`: 0 Aggressive, 3 EquipItem, 12 Climbing), `bow@<socket>`; for
--                `_G.__ws_end` (1.6).
--   'read'     — the samples as text; 'wallinfo', 'hooktest', 'kick' — the 15:2x recon steps.
-- The press / release roles were read live 2026-11-14 16:3x by `input-bindings-probe.lua`; before that this stand had them swapped.
-- One input chain at a time (judge 2026-11-14 16:5x, round 4 17:1x): `climb`, `jumpwall`, `airshot`, `kick` and `find` stop a running chain (counter
-- `_G.__ws_gen`), which first sends every release it still owes and notes «older chain stopped at …» in the current samples; an event that waits for
-- another fires ≥ 0.05 s after it, never in the same tick; a chain that ends sends its owed releases; a failed event or per-tick call is written into
-- the samples. The knobs stay in `_G` between calls — every chain step echoes the values it ran with, and its last sample the moments that fired.
-- Not undone by a stop: the `bWantsToClimb` that `Climb(false)` sets.
-- Read-only except the hero's place and input. [TESTED: 2026-11-14 17:01–17:05 · the chain runner: `climb` with the defaults climbed (mode 7 from 0.41 s),
-- `airshot` on the wall and on the ground, `jumpwall`, `climb` with a second press (W8); 17:1x the round-4 runner: the `events:` line («press@0.35
-- release@0.61») and the stop path («(older chain stopped at 0.51: press@0.35 release@0.51)», the owed release sent) · KUMM
-- testcases/reports/2026-11-14_conan-wall-jump-press-order-and-real-space.md]; `kick`'s stop call [NOT-TESTED]
local S = _G.__ws or {}
_G.__ws = S
local step = _G.__ws_step or 'find'
local pc = FindFirstOf('PlayerController')
local p = pc and pc.Pawn
if not (p and p:IsValid()) then return 'no hero' end
local ksl = StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
local CHEST, RANGE, STEP_DEG = 60, 1200, 15

local function trace(s, e)
    local hit = {}
    local ok = ksl:LineTraceSingle(p, s, e, 0, true, { p }, 0, hit, true, { R = 1, G = 0, B = 0, A = 1 }, { R = 0, G = 1, B = 0, A = 1 }, 0)
    return ok, hit
end

if step == 'find' then
    _G.__ws_gen = (_G.__ws_gen or 0) + 1                -- stops a running input chain (the same counter as run_chain's)
    local loc = p:K2_GetActorLocation()
    local s = { X = loc.X, Y = loc.Y, Z = loc.Z + CHEST }
    local best = nil
    for deg = 0, 345, STEP_DEG do
        local r = math.rad(deg)
        local e = { X = s.X + math.cos(r) * RANGE, Y = s.Y + math.sin(r) * RANGE, Z = s.Z }
        local ok, hit = trace(s, e)
        if ok and math.abs(hit.ImpactNormal.Z) < 0.3 and (not best or hit.Distance < best.dist) then
            best = { yaw = deg, dist = hit.Distance, nx = hit.ImpactNormal.X, ny = hit.ImpactNormal.Y, nz = hit.ImpactNormal.Z,
                     px = hit.ImpactPoint.X, py = hit.ImpactPoint.Y }
        end
    end
    if not best then return 'no vertical wall within ' .. RANGE .. ' cm' end
    -- stand 60 cm off the wall along its normal, facing it
    local nl = math.sqrt(best.nx * best.nx + best.ny * best.ny)
    local tx, ty = best.px + best.nx / nl * 60, best.py + best.ny / nl * 60
    p:K2_SetActorLocation({ X = tx, Y = ty, Z = loc.Z + 20 }, false, {}, true)
    local yaw = math.deg(math.atan(-best.ny, -best.nx))
    pc:SetControlRotation({ Pitch = 0, Yaw = yaw, Roll = 0 })
    p:K2_SetActorRotation({ Pitch = 0, Yaw = yaw, Roll = 0 }, true)
    S.wall = best
    S.yaw = yaw
    return string.format('wall at ring yaw %d, %.0f cm, normal (%.2f, %.2f, %.2f); hero put 60 cm off, facing yaw %.0f', best.yaw, best.dist, best.nx, best.ny, best.nz, yaw)
end

-- The hero's own input events (roles from the class's bindings, 2026-11-14 16:3x / 16:4x).
local function ev(name, key) return function() p[name](p, { KeyName = FName(key) }) end end
local JUMP_PRESS, JUMP_RELEASE = ev('InpActEvt_Jump_K2Node_InputActionEvent_26', 'SpaceBar'), ev('InpActEvt_Jump_K2Node_InputActionEvent_27', 'SpaceBar')

-- One input chain: `events` = { key, at, fn, after = <key that must have fired first>, release = true }. A newer call (S.gen moved) stops this chain; on
-- stop or end every owed release whose press went is sent, so no input stays held. Samples go into this chain's own table (`S.samples` at the start).
local MIN_GAP = 0.05                                  -- an event never fires in the same tick as the event it waits for (judge round 4)
local function stop_chains() _G.__ws_gen = (_G.__ws_gen or 0) + 1 end   -- own global: survives a reset of `_G.__ws`
local function run_chain(dur, events, per_tick, every, sampler)
    stop_chains()
    local gen, samples, t0, done, nextSample, tick_err = _G.__ws_gen, {}, os.clock(), {}, 0, false
    S.samples = samples
    local function fire(e, t)
        done[e.key] = t
        local ok, err = pcall(e.fn)
        if not ok then samples[#samples + 1] = string.format('%s FAILED: %s', e.key, tostring(err)) end
    end
    local function fired()                            -- «press@0.35 release@0.60» — the moments that really happened
        local r = {}
        for _, e in ipairs(events) do if done[e.key] then r[#r + 1] = string.format('%s@%.2f', e.key, done[e.key]) end end
        return table.concat(r, ' ')
    end
    local function finish(t)
        for _, e in ipairs(events) do
            if e.release and not done[e.key] and (not e.after or done[e.after]) then fire(e, t) end
        end
    end
    local function tick()
        ExecuteInGameThreadWithDelay(1, function()
            local t = os.clock() - t0
            if _G.__ws_gen ~= gen then                -- a newer step took over: release what is owed, say so in the CURRENT samples
                finish(t)
                local cur = _G.__ws and _G.__ws.samples
                if cur then cur[#cur + 1] = string.format('(older chain stopped at %.2f: %s)', t, fired()) end
                return
            end
            if per_tick then
                local ok, err = pcall(per_tick, t)
                if not ok and not tick_err then tick_err = true; samples[#samples + 1] = 'per-tick FAILED: ' .. tostring(err) end
            end
            for _, e in ipairs(events) do
                if not done[e.key] and t > e.at and (not e.after or (done[e.after] and t >= done[e.after] + MIN_GAP)) then fire(e, t) end
            end
            if t >= nextSample then
                nextSample = nextSample + every
                local ok, s = pcall(sampler, t)
                samples[#samples + 1] = ok and s or ('sample FAILED: ' .. tostring(s))
            end
            if t < dur then tick() else finish(t); samples[#samples + 1] = 'events: ' .. fired() end
        end)
    end
    tick()
end

if step == 'climb' then
    if not S.yaw then return 'run find first' end
    local fx, fy = math.cos(math.rad(S.yaw)), math.sin(math.rad(S.yaw))
    local cpress = _G.__ws_cpress or 0.35
    local crel = math.max(_G.__ws_crel or 0.6, cpress + 0.05)
    local climbcall = _G.__ws_climbcall ~= false
    local events = {
        { key = 'press', at = cpress, fn = JUMP_PRESS },
        { key = 'release', at = crel, fn = JUMP_RELEASE, after = 'press', release = true },
    }
    local cpress2 = _G.__ws_cpress2                    -- W8: a second press soon after the grab (e.g. 0.6 — the climb starts ≈ 0.40 s)
    if cpress2 then
        events[#events + 1] = { key = 'press2', at = cpress2, fn = JUMP_PRESS, after = 'release' }
        events[#events + 1] = { key = 'release2', at = cpress2 + 0.1, fn = JUMP_RELEASE, after = 'press2', release = true }
    end
    run_chain(1.2, events, function(t)
        p:AddMovementInput({ X = fx, Y = fy, Z = 0 }, 1.0, false)
        if climbcall and t > cpress - 0.05 and t < cpress + 0.55 then p:Climb(false) end   -- the native climb asked while airborne at the wall
    end, 0.2, function(t)
        local m = p.CharacterMovement
        return string.format('%.2f mode %d/%d z %.0f', t, m.MovementMode, m.CustomMovementMode, p:K2_GetActorLocation().Z)
    end)
    return string.format('climb running 1.2 s (press %.2f, release %.2f, climb call %s, second press %s)', cpress, crel, tostring(climbcall), tostring(cpress2))
end

if step == 'read' then
    return table.concat(S.samples or {}, ' | ')
end

if step == 'wallinfo' then                           -- while climbing: the movement mode and the native CurrentWall struct, field by field
    local m = p.CharacterMovement
    local out = { string.format('mode %d/%d', m.MovementMode, m.CustomMovementMode) }
    local ok, w = pcall(function() return m.CurrentWall end)
    if ok and w then
        for _, f in ipairs({ 'Normal', 'ImpactNormal', 'Location', 'ImpactPoint', 'WallNormal', 'HitNormal', 'Component', 'Actor', 'Time', 'bValid' }) do
            local okf, v = pcall(function() return w[f] end)
            if okf and v ~= nil then
                if type(v) == 'userdata' or type(v) == 'table' then
                    local okx, s = pcall(function() return string.format('(%.2f, %.2f, %.2f)', v.X, v.Y, v.Z) end)
                    out[#out + 1] = f .. '=' .. (okx and s or tostring(v))
                else out[#out + 1] = f .. '=' .. tostring(v) end
            end
        end
    else out[#out + 1] = 'CurrentWall unreadable: ' .. tostring(w) end
    local okd, d = pcall(function() local c = m.ClimbDirection return string.format('(%.2f, %.2f, %.2f)', c.X, c.Y, c.Z) end)
    out[#out + 1] = 'ClimbDirection=' .. (okd and d or '?')
    return table.concat(out, ' ')
end

if step == 'hooktest' then                           -- does the hero's StartJump run when Jump is pressed ON the wall? (the hook point of the feature)
    if not S.hooked then
        RegisterHook('/Game/Characters/BaseBPCombat.BaseBPCombat_C:StartJump', function(ctx)
            local ok, mode = pcall(function() return ctx:get().CharacterMovement.MovementMode end)
            print(string.format('[WSJ] StartJump fired, movement mode %s\n', ok and tostring(mode) or '?'))
        end)
        S.hooked = true   -- only after RegisterHook returned (judge 15:43)
    end
    return 'StartJump hook armed — press jumpwall and read UE4SS.log [WSJ]'
end

if step == 'kick' then                               -- the prototype: leave the climb, launch along the wall normal and up; samples for 1.2 s
    stop_chains()                                     -- a climb chain still pushing into the wall would spoil the kick's flight (judge round 4)
    local m = p.CharacterMovement
    if m.MovementMode ~= 7 then return 'not climbing (mode ' .. m.MovementMode .. ')' end
    local loc, fwd = p:K2_GetActorLocation(), p:GetActorForwardVector()
    local s = { X = loc.X, Y = loc.Y, Z = loc.Z + 40 }
    local ok, hit = trace(s, { X = s.X + fwd.X * 150, Y = s.Y + fwd.Y * 150, Z = s.Z + fwd.Z * 150 })
    if not ok then return 'no wall in front (forward trace 150 cm)' end
    local nx, ny = hit.ImpactNormal.X, hit.ImpactNormal.Y
    local nl = math.sqrt(nx * nx + ny * ny)
    if nl < 0.5 then return string.format('the surface in front is not a wall (normal z %.2f)', hit.ImpactNormal.Z) end
    nx, ny = nx / nl, ny / nl
    local push, up = _G.__ws_push or 350, _G.__ws_up or 300
    m:ExitClimbing()
    p:LaunchCharacter({ X = nx * push, Y = ny * push, Z = up }, true, true)
    S.samples = {}
    local t0 = os.clock()
    local nextSample = 0
    local function tick()
        ExecuteInGameThreadWithDelay(1, function()
            local t = os.clock() - t0
            if t >= nextSample then
                nextSample = nextSample + 0.1
                pcall(function()
                    local l, v = p:K2_GetActorLocation(), p:GetVelocity()
                    S.samples[#S.samples + 1] = string.format('%.1f m%d (%.0f,%.0f,%.0f) v(%.0f,%.0f,%.0f)', t, p.CharacterMovement.MovementMode, l.X - loc.X, l.Y - loc.Y, l.Z - loc.Z, v.X, v.Y, v.Z)
                end)
            end
            -- the landing (judge round 6, R6 (1): the gap at a high jump speed): the first walking sample after the launch, distance along the normal
            if not S.kick_landed and t > 0.2 and p.CharacterMovement.MovementMode == 1 then
                local l = p:K2_GetActorLocation()
                S.kick_landed = string.format('landed at %.2f s: %.0f cm along the wall normal, z %+.0f', t, (l.X - loc.X) * nx + (l.Y - loc.Y) * ny, l.Z - loc.Z)
            end
            if t < (_G.__ws_kdur or 1.2) then tick() end
        end)
    end
    S.kick_landed = nil
    tick()
    return string.format('kick: normal (%.2f, %.2f), push %.1f, up %d — read S.kick_landed after the flight', nx, ny, push, up)
end

if step == 'jumpwall' then                          -- while climbing: the hero's own jump press / release; samples until `_G.__ws_jdur` (1.0 s)
    -- `_G.__ws_steer` = { yaw = <deg> } — the remote twin of a held WASD key during the flight: AddMovementInput toward that world yaw every tick from the
    -- press + 0.1 s (air control, the owner's 17:38 design). A «landed …» line (only after a flight — mode 3 seen) gives the distance from the wall start: the
    -- whole horizontal one and its part along the wall's normal (`S.wall`); «not landed by …» when the time ran out (judge round 5).
    local rel = math.max(_G.__ws_rel or 0.25, 0.1)
    local dur = _G.__ws_jdur or 2.0
    local steer = _G.__ws_steer
    local sx, sy = 0, 0
    if steer then sx, sy = math.cos(math.rad(steer.yaw)), math.sin(math.rad(steer.yaw)) end
    local start = p:K2_GetActorLocation()
    local landed, flew = nil, false
    local wnx, wny = 0, 0
    if S.wall then local nl = math.sqrt(S.wall.nx ^ 2 + S.wall.ny ^ 2); wnx, wny = S.wall.nx / nl, S.wall.ny / nl end
    run_chain(dur, {
        { key = 'press', at = 0.05, fn = JUMP_PRESS },
        { key = 'release', at = rel, fn = JUMP_RELEASE, after = 'press', release = true },
    }, function(t)
        if steer and t > 0.15 and p.CharacterMovement.MovementMode == 3 then p:AddMovementInput({ X = sx, Y = sy, Z = 0 }, 1.0, false) end
        local mode = p.CharacterMovement.MovementMode
        if mode == 3 then flew = true end
        if not landed and flew and mode == 1 then
            local l = p:K2_GetActorLocation()
            local dx, dy = l.X - start.X, l.Y - start.Y
            landed = string.format('landed at %.2f s: %.0f cm horizontally from the wall start (%.0f along the wall normal), z %+.0f', t,
                math.sqrt(dx * dx + dy * dy), dx * wnx + dy * wny, l.Z - start.Z)
            S.samples[#S.samples + 1] = landed
        end
        if not landed and t >= dur - 0.02 then landed = 'none'; S.samples[#S.samples + 1] = string.format('not landed by %.1f s (flew: %s)', dur, tostring(flew)) end
    end, 0.1, function(t)
        local m, l, v = p.CharacterMovement, p:K2_GetActorLocation(), p:GetVelocity()
        return string.format('%.2f mode %d/%d loc (%.0f, %.0f, %.0f) vel (%.0f, %.0f, %.0f)', t, m.MovementMode, m.CustomMovementMode, l.X, l.Y, l.Z, v.X, v.Y, v.Z)
    end)
    return string.format('jumpwall running %.1f s (press 0.05, release %.2f, steer %s)', dur, rel, steer and tostring(steer.yaw) or 'none')
end

if step == 'airshot' then                           -- W6: a jump (on the wall or on the ground), then in the air the bow's draw and the shot
    local tdraw, tshot, tend = _G.__ws_draw or 0.25, _G.__ws_shot or 0.75, _G.__ws_end or 1.6
    local exit8 = _G.__ws_exit8 == true
    local events = {
        { key = 'jump', at = 0.05, fn = JUMP_PRESS },
        { key = 'jump_up', at = 0.12, fn = JUMP_RELEASE, after = 'jump', release = true },
        { key = 'rmb', at = tdraw, fn = ev('InpActEvt_SpecialActionV2_K2Node_InputActionEvent_7', 'RightMouseButton') },
        { key = 'lmb', at = tshot, fn = ev('InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_9', 'LeftMouseButton'), after = 'rmb' },
        { key = 'lmb_up', at = tshot + 0.06, fn = ev('InpActEvt_PrimaryActionV2_K2Node_InputActionEvent_10', 'LeftMouseButton'), after = 'lmb', release = true },
        { key = 'rmb_up', at = tshot + 0.2, fn = ev('InpActEvt_SpecialActionV2_K2Node_InputActionEvent_8', 'RightMouseButton'), after = 'rmb', release = true },
    }
    if exit8 then table.insert(events, 1, { key = 'exit8', at = 0.1, fn = function() p:ExitSubstate(8, {}) end, after = 'jump' }) end   -- experiment
    run_chain(tend, events, nil, 0.1, function(t)
        local r = {}
        for s = 0, 22 do local o = {}; p:InSubstate(s, o); if o.Success then r[#r + 1] = tostring(s) end end   -- ECharacterSubState is 0..22
        local bow, arr = '-', {}                      -- where the bow hangs (judge 16:5x: in a sheath socket during EquipItem?)
        p:GetAttachedActors(arr, true, false)
        for i = 1, #arr do
            local a = arr[i]:get()
            if a:IsValid() and a:GetClass():GetFName():ToString():lower():find('bow', 1, true) then bow = a:GetAttachParentSocketName():ToString() end
        end
        return string.format('%.2f m%d [%s] s%s bow@%s', t, p.CharacterMovement.MovementMode, table.concat(r, ','), tostring(p:GetCharacterState()), bow)
    end)
    return string.format('airshot running %.1f s (draw %.2f, shot %.2f, exit8 %s) — read after', tend, tdraw, tshot, tostring(exit8))
end
return 'unknown step'
