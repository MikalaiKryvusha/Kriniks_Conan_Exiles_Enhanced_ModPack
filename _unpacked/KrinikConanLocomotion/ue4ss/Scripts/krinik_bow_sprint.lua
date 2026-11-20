--[[
  KrinikConanLocomotion · bow_sprint — the hero sprints with the bow drawn and shoots on the run (KUMM games/ConanExiles/mods/KrinikConanLocomotion.md,
  «Sprint + bow»). The owner's words: 2026-11-07 20:50 «Спринт и стрельбу делаем возможными одновременно»; 2026-11-08 12:22 «очень хочется это»;
  2026-11-10 19:03 «особенно мне важно - спринт с луком» · 19:09 «Спринт с луком делаем».

  How the game decides the movement (read live 2026-11-10 19:2x–19:4x by REAL input and the bytecode of BaseBPCombat::EvaluateMovementType):
   - the hero's movement row is the FIRST valid row of DT_CharacterMovement in its order — AttackingRootMotion, UsingItem, Casual, Ranged, Sprint (0…65°,
     speed 773), front, IsBlockingWithPerk, Side, Back; a row is valid when its condition function (EvaluateMovement_RangeCombat, EvaluateMovement_Sprint, …)
     says Success AND |GetAngleOfMovement| lies inside the row's DirectionRequirment;
   - while the bow is drawn (substates 11 attack, 15 power charge, 16 charge hold) the Ranged row is valid → MaxWalkSpeed 214, and the native
     AConanCharacter::K2_CanSprint answers false (Shift held, bTrySprint true).
  Measured with live hooks: only the Ranged row taken away → 428 (the run); both levers → substate 7 (sprint) next to 15 / 16, MaxWalkSpeed 735, a shot on the run
  fired («#1 из лука, заряд 0.52», 19:28:20) and the sprint went on.

  What this section does — at the game's own decision points (HOUSE_RULES rule 24), no polling. ONE gate decides both levers (judge round 1, finding 1):
  the player, Shift held (bTrySprint), the bow in hand and drawn (11 / 15 / 16 — 11 opens the draw and the release), on the ground, not exhausted
  (13 / 14 / 18), moving (horizontal speed > MOVING_CMS) and |GetAngleOfMovement| inside the Sprint row's own window read from DT_CharacterMovement.
  Standing, sideways or backwards nothing changes.
   a. post-hook of the native K2_CanSprint (the 2nd callback — EXP-0504): the gate open → Value = true;
   b. hook of the blueprint EvaluateMovement_RangeCombat (its callback runs after the body, before the caller reads Success — EXP-0487): the gate open →
      Success = false, so the first valid row becomes Sprint (the open gate already holds every condition of EvaluateMovement_Sprint, see on_range_combat).
  The gate opens from substate 11 (the draw's first substate): with 15 / 16 only (build 3) a sprint started BEFORE the draw broke at its first moments — the
  owner's order (KUMM bug 93); measured by real input on build 7 2026-11-13 10:43: sprint 660 → RMB → 7,11 → 7,11,15,16 at 660 → the shot → the sprint kept.
  Cost: K2_CanSprint ≈ 28–40 calls a second, by the hero only (127 NPCs around did not call it, 19:3x); without Shift held a callback reads one property and
  returns. The gate's answer is kept for GATE_KEEP_MS (one movement evaluation calls it twice (once per hook; more if the game asks K2_CanSprint elsewhere) — judge finding 3). The minute line: calls, sum, worst.
  [TESTED: 2026-11-13 · build 7, real input on the owner's save: S1b (sprint, then draw, shot, sprint kept), S3, S6 pass; S8, S9 and the frame-time cost open ·
  KUMM testcases/reports/2026-11-13_conan-bow-sprint-sprint-then-draw.md] — cases KUMM testcases/TC_conan_bow_sprint_2026-11-10.md
]]

local PREFIX = "[KrinikConanLocomotion:BowSprint] "
local function log(fmt, ...) print(PREFIX .. string.format(fmt, ...) .. "\n") end

local CAN_SPRINT = "/Script/ConanSandbox.ConanCharacter:K2_CanSprint"
local RANGE_COMBAT = "/Game/Characters/BaseBPCombat.BaseBPCombat_C:EvaluateMovement_RangeCombat"
local HERO_CLASS = "/Game/Characters/BasePlayerChar.BasePlayerChar_C"
local MOVEMENT_TABLE = "/Game/Systems/Combat/DirectionalMovement/DT_CharacterMovement.DT_CharacterMovement"
local SPRINT_ROW = "Sprint"                -- the row name in DT_CharacterMovement (read live 2026-11-10 19:4x)
-- 11 attack, 15 power charge, 16 charge hold (ECharacterSubState.h). 11 is the FIRST substate of a draw and of a release: without it the gate stayed shut
-- for the draw's first moments, the Ranged row won, the game stopped the sprint and cleared bTrySprint — a sprint started BEFORE the draw never came back
-- (the owner 2026-11-13 09:14 «в момент натяжения, когда выполняется приближение камеры - спринт прерывается», KUMM bug 93; judge round 2, finding 2).
-- With the bow in hand (bow_in_hand, the gate's last test) 11 is normally the bow's own attack (a bow model attached by the remote without the game's
-- wield played an unarmed 11 — test gear, bug 93).
local DRAW_SUBSTATES = { 11, 15, 16 }
local EXHAUSTED_SUBSTATES = { 13, 14, 18 } -- the game forbids sprint / jump in these (14 — out of stamina)
local MOVING_CMS = 10                      -- below this horizontal speed the hero stands: no sprint while aiming in place
local GATE_KEEP_MS = 5                     -- one movement evaluation asks the gate twice (once per hook) within a millisecond or two
local TABLE_TRIES = 20                     -- the movement table is read lazily; give up after this many misses (logged)
local LOG_FIRST = 5                        -- first events of each kind into the log
local REPORT_S = 60                        -- the cost line once a minute of WALL time (HOUSE_RULES rule 7)

-- ---- the Sprint row's direction window, from the game's own table ---------------------------------------------------------------------
local sprint_dir, table_tries = nil, 0     -- { min, max } degrees; nil — not read yet: the gate stays shut
local function txt(x)                      -- the same reader as _config/live-rows.lua: a string, a wrapper with :get(), an object with ToString
    if type(x) == "string" then return x end
    local ok, v = pcall(function() return x:get() end)
    if ok and v ~= nil then x = v end
    if type(x) == "string" then return x end
    local ok2, s = pcall(function() return x:ToString() end)
    return ok2 and s or tostring(x)
end
local function column(lib, dt, name)
    local col, out = lib:GetDataTableColumnAsString(dt, FName(name)), {}
    if type(col) == "table" then for _, e in ipairs(col) do out[#out + 1] = txt(e) end
    else col:ForEach(function(_, e) out[#out + 1] = txt(e) end) end
    return out
end
local function read_sprint_dir()
    local lib = StaticFindObject("/Script/Engine.Default__DataTableFunctionLibrary")
    local dt = StaticFindObject(MOVEMENT_TABLE)
    if not lib or not lib:IsValid() then return nil, "no DataTableFunctionLibrary" end
    if not dt or not dt:IsValid() then return nil, "DT_CharacterMovement not loaded" end
    local names = {}
    dt:ForEachRow(function(n, _) names[#names + 1] = txt(n) end)
    local conds, dirs = column(lib, dt, "Condition"), column(lib, dt, "DirectionRequirment")
    if #conds ~= #names or #dirs ~= #names then return nil, ("columns %d / %d for %d rows"):format(#conds, #dirs, #names) end
    for i = 1, #names do
        if names[i] == SPRINT_ROW or conds[i] == SPRINT_ROW then
            local x, y = dirs[i]:match("X=([%-%d%.]+),Y=([%-%d%.]+)")
            if x then return { tonumber(x), tonumber(y) } end
            return nil, "row Sprint: no direction in «" .. dirs[i] .. "»"
        end
    end
    return nil, "no row Sprint among " .. #names
end
local function ensure_table()
    if sprint_dir or table_tries >= TABLE_TRIES then return sprint_dir end
    table_tries = table_tries + 1
    local ok, d, why = pcall(read_sprint_dir)
    if ok and d then
        sprint_dir = d
        log("окно направления спринта из таблицы игры: %.0f…%.0f° (попытка %d)", d[1], d[2], table_tries)
    elseif table_tries == TABLE_TRIES then
        log("окно направления спринта не прочитано за %d попыток: %s — раздел ничего не меняет", TABLE_TRIES, tostring(ok and why or d))
    end
    return sprint_dir
end

-- ---- the one gate --------------------------------------------------------------------------------------------------------------------------
-- One game call through UE4SS costs 25–42 µs on this machine, a property read 0–2 µs (KUMM bug 93 «Cost», microbench 2026-11-17 05:2x, the game in front:
-- InSubstate 34, IsPlayerControlled 36, GetVelocity 42, GetAngleOfMovement 24, IsMovingOnGround 6, the attached-actor bow walk 54, GetSubstateList 36,
-- bTrySprint / GetAddress ≈ 0–2). The gate made ≈ 10 calls (six InSubstate alone) ≈ 0.4 ms — the minute line read the full path over the 1 ms clock step on
-- 45 % of its calls. Now: ONE substate list for both tests, the player test kept per pawn, the walking mode and the velocity read as properties. [NOT-TESTED]
local DRAW_SET, EXHAUSTED_SET = {}, {}
for _, s in ipairs(DRAW_SUBSTATES) do DRAW_SET[s] = true end
for _, s in ipairs(EXHAUSTED_SUBSTATES) do EXHAUSTED_SET[s] = true end
-- drawn, tired — from one GetSubstateList(): a Lua table of wrappers, :get() gives the substate number (read live 2026-11-17: [11, 15, 16] in a full draw); a
-- TArray userdata shape is read by ForEach too (judge item 6 — the same two shapes column() above handles).
local function draw_state(c)
    local drawn, tired = false, false
    local function one(v)
        if type(v) == "userdata" then v = v:get() end
        if DRAW_SET[v] then drawn = true elseif EXHAUSTED_SET[v] then tired = true end
    end
    local list = c:GetSubstateList()
    if type(list) == "table" then for _, v in ipairs(list) do one(v) end
    elseif list ~= nil then list:ForEach(function(_, e) one(e) end) end
    return drawn, tired
end
-- IsPlayerControlled kept for the last pawn asked (36 µs a call; K2_CanSprint is asked by the hero only — 127 NPCs around never called it, 2026-11-10 19:3x)
local player = { addr = nil, yes = false }
local function is_player(c, addr)
    if player.addr ~= addr then player.addr, player.yes = addr, c:IsPlayerControlled() == true end
    return player.yes
end
-- The bow in the hands: krinik_air_combat's ONE reading (a «bow» class attached and not on the sheath socket), shared through `_G` and read at call time
-- (KUMM bug 105 judge r12 — this file kept a third copy). Missing (that section failed to load) → no bow, said once: the bow sprint stays off. [NOT-TESTED] that branch
local no_bow_fn_said = false
local function bow_in_hand(c)
    local f = _G.__krinik_bow_in_hand
    if f then return f(c) == true end
    if not no_bow_fn_said then no_bow_fn_said = true; log("нет проверки «лук в руках» из раздела krinik_air_combat — спринт с луком выключен") end
    return false
end
-- «The bow in hand» kept for one continuous draw: the walk over the attached actors is the gate's dearest piece (54–67 µs and ≈ 5 KB of garbage a call —
-- microbench3 2026-11-17 05:3x, the hero sprinting with the bow drawn: the whole gate 147 µs, this walk 67). The weapon cannot change while the draw stands —
-- a swap ends the draw first, and the draw is read fresh on every gate. Only a YES is kept (judge 2026-11-17 item 1: a «no» caught at the draw's first moment —
-- the bow still on its sheath socket — kept for the whole draw would lose the sprint, bug 93's own failure); a «no» is asked again at every gate (its cost lands
-- only on a melee swing with Shift held). The yes is dropped when a gate finds no draw and when no gate asked for BOW_GAP_MS — mostly the latter: after the draw
-- the native K2_CanSprint answers true and no gate is asked (judge item 5); a swap to a sword and its swing (11) takes ≈ 1 s, a sprinting draw asks every 5–30 ms.
local BOW_GAP_MS = 100
local bow_kept = { addr = nil, t = -1e9 }
local function bow_in_hand_kept(c, addr, now)
    if bow_kept.addr == addr and now - bow_kept.t <= BOW_GAP_MS then bow_kept.t = now; return true end
    if bow_in_hand(c) then bow_kept.addr, bow_kept.t = addr, now; return true end
    bow_kept.addr = nil
    return false
end
local angle_missing_logged = false
local ANGLE_OUT = {}                       -- the out table of GetAngleOfMovement, reused (one less allocation per gate)
-- the hero runs forward with the bow in hand: everything of the gate but the player test and the draw itself (gate_now asks those first)
local function running_with_bow(c, addr, now, tired)
    if tired or not ensure_table() then return false end
    local m = c.CharacterMovement
    -- the engine's own test, not a mode number (judge item 3: this engine's movement-mode enum is Funcom's — climbing is 7, stock UE has 6 — and a property
    -- compare would silently differ if IsMovingOnGround counts a mode of theirs); 6 µs
    if not m:IsMovingOnGround() then return false end
    local v = m.Velocity
    if v.X * v.X + v.Y * v.Y < MOVING_CMS * MOVING_CMS then return false end
    ANGLE_OUT.Value = nil
    c:GetAngleOfMovement(ANGLE_OUT)
    if ANGLE_OUT.Value == nil then
        if not angle_missing_logged then angle_missing_logged = true; log("ошибка: GetAngleOfMovement не дал Value — раздел ничего не меняет") end
        return false
    end
    local angle = math.abs(ANGLE_OUT.Value)
    if angle < sprint_dir[1] or angle > sprint_dir[2] then return false end
    return bow_in_hand_kept(c, addr, now)
end
local function gate_now(c, addr, now)   -- the player first: an NPC archer leaves after one call (judge round 3, finding 6)
    if not is_player(c, addr) then return false end
    local drawn, tired = draw_state(c)
    if not drawn then bow_kept.addr = nil; return false end   -- the draw is over: «the bow in hand» is asked again at the next draw
    return running_with_bow(c, addr, now, tired)
end
local gate_cache = { addr = nil, t = -1, open = false }
local gate_ran = false                     -- this call computed the gate (the full path) — the minute line splits the cost by it
local function gate(c)   -- called only after bTrySprint was read true
    local now, addr = os.clock() * 1000, c:GetAddress()
    if gate_cache.addr == addr and now - gate_cache.t <= GATE_KEEP_MS then return gate_cache.open end
    gate_ran = true
    gate_cache.addr, gate_cache.t, gate_cache.open = addr, now, gate_now(c, addr, now)
    return gate_cache.open
end

-- ---- bookkeeping: first events, the minute line ----------------------------------------------------------------------------------------
local counts = { can = 0, fall_through = 0 }
-- The minute line splits the cost (KUMM bug 93 «Cost», 2026-11-17): the FULL path (this call computed the gate: substates, velocity, angle, the bow) and the
-- LIGHT one (an early return or the 5 ms cache) — each with its worst call and its count over SPIKE_MS — plus the Lua heap's growth over the minute. On Windows
-- os.clock is the WALL clock (the C runtime's clock()), so a preempted game thread or a Lua GC step inside a call reads as our cost: a spike that shows in the
-- light path as often as in the full one is not our work. [NOT-TESTED]
local SPIKE_MS = 1.0
local cost = { sum = 0, worst = 0, n = 0, t = os.time(), full_n = 0, full_worst = 0, full_spikes = 0, light_worst = 0, light_spikes = 0, kb = collectgarbage("count") }
local errors, depth = 0, 0
local function counted(kind, text)
    counts[kind] = counts[kind] + 1
    if counts[kind] <= LOG_FIRST then log("%s (%d)", text, counts[kind]) end
end
local function measured(f, ...)
    if depth > 0 then   -- a nested call (a game function called inside our callback reaching another of our hooks): counted in the outer one
        local ok, err = pcall(f, ...)
        if not ok and errors < 5 then errors = errors + 1; log("ошибка: %s", tostring(err)) end
        return
    end
    depth = 1
    gate_ran = false
    local t0 = os.clock()
    local ok, err = pcall(f, ...)
    local dt = (os.clock() - t0) * 1000
    depth = 0
    cost.sum, cost.n = cost.sum + dt, cost.n + 1
    if dt > cost.worst then cost.worst = dt end
    if gate_ran then
        cost.full_n = cost.full_n + 1
        if dt > cost.full_worst then cost.full_worst = dt end
        if dt > SPIKE_MS then cost.full_spikes = cost.full_spikes + 1 end
    else
        if dt > cost.light_worst then cost.light_worst = dt end
        if dt > SPIKE_MS then cost.light_spikes = cost.light_spikes + 1 end
    end
    if not ok and errors < 5 then errors = errors + 1; log("ошибка: %s", tostring(err)) end
    if os.time() - cost.t >= REPORT_S then
        local kb = collectgarbage("count")
        log("за минуту вызовов %d, своё время %.3f мс, худший %.3f мс (часы с шагом 1 мс); полный путь %d вызовов, худший %.3f, дольше %.0f мс — %d; лёгкий — худший %.3f, дольше %.0f мс — %d; память Lua всего мода %+.0f КБ (со сборками мусора); спринт с луком: разрешений %d, переходов %d",
            cost.n, cost.sum, cost.worst, cost.full_n, cost.full_worst, SPIKE_MS, cost.full_spikes, cost.light_worst, SPIKE_MS, cost.light_spikes, kb - cost.kb,
            counts.can, counts.fall_through)
        cost.sum, cost.worst, cost.n, cost.t = 0, 0, 0, os.time()
        cost.full_n, cost.full_worst, cost.full_spikes, cost.light_worst, cost.light_spikes, cost.kb = 0, 0, 0, 0, 0, kb
    end
end

-- ---- the two levers ------------------------------------------------------------------------------------------------------------------------
local function on_can_sprint(ctx, value)
    if value:get() == true then return end
    local c = ctx:get()
    if c.bTrySprint ~= true or not gate(c) then return end
    value:set(true)
    counted("can", "лук натянут: K2_CanSprint → true")
end

-- The Ranged row gives way only when the Sprint row right after it is sure to win: EvaluateMovement_Sprint = TrySprint (bTrySprint) AND K2_CanSprint
-- AND NOT InSubstate(18) (bytecode, Locomotion notes), and the same open gate holds bTrySprint, excludes 18 and makes (a) answer K2_CanSprint = true, and
-- checks the Sprint row's direction window. The nested call of EvaluateMovement_Sprint that stood here proved the same thing twice per evaluation
-- (judge round 2, finding 4 — dropped for cost, finding 3).
local function on_range_combat(ctx, success)
    if success:get() ~= true then return end
    local c = ctx:get()
    if c.bTrySprint ~= true or not gate(c) then return end
    success:set(false)
    counted("fall_through", "лук натянут и спринт зажат: тип движения — спринт")
end

-- No third lever (build 7, 2026-11-13): a WeaponEquipped post-hook that set bTrySprint back after the game's StopSprint (builds 5–6) never fired with a
-- properly wielded bow — an RMB in a sprint does not take such a bow up again (no «WeaponEquipped» in the S1b run, KUMM bug 93); it was seen only with a
-- bow model the remote attached. Dropped by Occam (judge round 4: its bow test was fragile, a hot-bar swap to the bow kept a sprint vanilla stops). If a
-- sheathed bow mid-sprint turns out to stop the sprint in play (TC case S9), the lever comes back with that observation.

NotifyOnNewObject(HERO_CLASS, function()
    ExecuteInGameThread(function()
        -- a new hero (a respawn) may be born at a freed pawn's address: every per-pawn memo starts clean (judge 2026-11-17 item 4)
        player.addr, bow_kept.addr, gate_cache.addr = nil, nil, nil
        -- each hook is registered once, and a failed one is tried again at the next hero's birth (a respawn); the error text goes through "%s" — a «%»
        -- inside it broke string.format and skipped the second hook (judge round 2, finding 5)
        ensure_table()
        if not _G.__krinik_bow_sprint_can then
            local ok1, e1 = pcall(function()
                -- native function: the 2nd callback is the POST one (Value is written by then); a single callback would be a pre-hook
                RegisterHook(CAN_SPRINT, function() end, function(ctx, value) measured(on_can_sprint, ctx, value) end)
            end)
            _G.__krinik_bow_sprint_can = ok1
            log("%s", ok1 and "перехват K2_CanSprint поставлен" or ("перехват K2_CanSprint не встал — " .. tostring(e1)))
        end
        if not _G.__krinik_bow_sprint_range then
            local ok2, e2 = pcall(function()
                RegisterHook(RANGE_COMBAT, function(ctx, success) measured(on_range_combat, ctx, success) end)
            end)
            _G.__krinik_bow_sprint_range = ok2
            log("%s", ok2 and "перехват EvaluateMovement_RangeCombat поставлен" or ("перехват EvaluateMovement_RangeCombat не встал — " .. tostring(e2)))
        end
    end)
end)

log("взведён: спринт с натянутым луком — только в окне направления спринта, в движении, по правилам выносливости игры")
