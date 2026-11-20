--[[
  KrinikConanLocomotion · wall_jump — Jump while climbing pushes the hero off the wall: ≈ 0.5 m along the wall's normal and up as high as the hero's own jump.
  The owner's word 2026-11-02 09:07 (KUMM game map «Climbing», verbatim there): «кнопка Прыжок должна выполнять прыжок героя прямо из состояния ползания …
  чуть-чуть отталкивается … в направлении вектора нормали, и немножко - вверх»; asked again 2026-11-14 09:54 «еще я хотел прыжки из карабкания по вертикальным
  поверхностям» (KUMM KrinikConanLocomotion.md, PLAN row).
  How (measured 2026-11-14 15:2x by the remote, the desert arch stand `_config/wall-stand.lua`):
  * climbing = `CharacterMovement.MovementMode` 7 (custom); the game does NOTHING on Jump while climbing — the key is free;
  * the hero's `BaseBPCombat_C:StartJump` still runs on that press (a remote post-hook logged mode 7) — our hook point, one call per press, no polling;
  * the wall's normal: a line trace forward from the chest (150 cm) — the native `CurrentWall` struct is not readable from Lua;
  * `CharacterMovement:ExitClimbing()` then `LaunchCharacter(normal × push + up × up, true, true)`: with 350 / 300 the hero flew ≈ 3 m off, peaked +46 cm,
    landed in 1 s (falling mode 3, then walking); 15:3x–17:4x shipped 250 / 350 (≈ 2 m off); since 17:4x `[AI]` numbers for the owner's design — below.
  Not a wall in front (a ceiling, a slope — |normal| of the horizontal part < 0.5) → nothing, the game's own behaviour stays.
  [TESTED: 2026-11-14 16:34 · W1 by the remote (press event _26 → push 250 / 350, ≈ 1.9 m off, +62 cm), W7 (the grab press and its release keep the climb),
  W5 by a REAL Space (log «прыжок со стены … (2)», 2.5 m off) · KUMM testcases/reports/2026-11-14_conan-wall-jump-press-order-and-real-space.md]
  [TESTED: 2026-11-14 17:05 · the 17:0x edit on a fresh game: W8 (a press 0.2 s after the grab → «нажатие раньше 0.4 с …», the climb kept), W9 (a second
  climb after the push → «… (2)») · same report] — the «climb start unseen» branch [NOT-TESTED] (needs a failed mode-change hook). Known: the bow cannot be
  drawn in the flight after a push — the game re-equips for 1.35 s after a climb (TC W6, KUMM interview #035).
  [TESTED: 2026-11-14 17:48–17:53 · the owner's 17:38 design: W10 push 45 → landed 46–47 cm off, up = JumpZ 444 × 1.00 (W12; the apex vs a ground jump's
  not compared); W11 steering along the wall (remote 100 cm, a REAL D 125 cm) and W13 (real keys: push, W back, Space in the air caught the wall, the next
  Space pushed) ran while the mod still set AirControl 0.35 — and W13's catch may come from the stand's leftover `bWantsToClimb`; both to re-run on the
  final build · KUMM testcases/TC_conan_wall_jump_2026-11-14.md]
  [TESTED: 2026-11-14 18:06 · the judge round-5 edit on a fresh game: `JumpZVelocity` forced to 420 on the wall (as after damage) → the push still «444 вверх
  (прыжок героя 444 × 1.00)», the property still 420 after it (the law was used); landed 46 cm off, 46 along the normal · KUMM TC W15] — the 0.05 s guard and
  the push scaling at other Agility values [NOT-TESTED].

  The grab IN THE AIR (KUMM bug 105): `[OWNER]` 2026-11-16 21:38 «Нужно чтобы герой если он летит в прыжке и касается стены - он цепляется за неё» · 21:42 «нужно
  бежать к стене, на бегу прыгнуть так, чтобы в полёте в стену ударится» (verbatim in KUMM bugs/105). The game's rule, read by real input 2026-11-16 21:44 (KUMM
  game map «Climbing»): the Space PRESS sets `CharacterMovement.bWantsToClimb`, the Space RELEASE clears it, and a falling hero grabs a wall he touches only while
  the wish stands — so a tapped Space bounces off the wall. Ours: a post-hook on the hero's Jump event (it runs after the whole body) — after a RELEASE body
  the wish is cleared, and while falling the game's own `Climb(false)` sets it again for the rest of the flight; the landing, and the end of a climb that wish
  gave, take back the wish WE set (the ground state of a released Space). Not in the flight of a wall push of ours — the push lands 0.5 m off, and a wish then
  re-caught the same wall (stand 2026-11-14 18:24; TC G5b 22:29 — W held, the same wall caught 0.13 s after the push): no re-wish from the push until the
  landing or a NEW press in that flight (the player's own wish — wall to wall).
  ONE hook for both the press and the release: UE4SS runs a hook registered on `…InputActionEvent_27` for `_26` too, and the other way round — the two names
  differ only by the number FName keeps apart from the name (debug probe `KUMM/.work/wallgrab/hook-order.lua`, 2026-11-16 22:38:12: one real press printed
  «startjump, press, release», one real release «press, release»). So the event is told by its EFFECT, read after its body: the press body sets the wish, the
  release body clears it. (Build r1 read a «second release at the push» from this; build r3, with both names hooked, ran its press branch right after every
  release and lost the landing clear — TC G4.)
  [TESTED: 2026-11-16 23:14–23:21 · build r7 by real input: G1 ×4 (a 30 ms tap grabs), G4 (the landing takes our wish back), G5b / G5c (no re-grab after the push,
  W held, Space tapped or held), G9 (climbing down takes it back), G10 (the push −20: 81 → 61) · KUMM testcases/reports/2026-11-16_conan-jump-wall-grab.md] —
  G6 (two walls) [NOT-TESTED]; G7 (the bow drawn — decided by the owner 2026-11-16 23:24, `cancel_draw` below) — see its tag there; the top of the wall waits
  for the owner (KUMM interview #037 Q1).
]]

local PREFIX = "[KrinikConanLocomotion:WallJump] "
local function log(fmt, ...) print(PREFIX .. string.format(fmt, ...) .. "\n") end

local COMBAT_CLASS = "/Game/Characters/BaseBPCombat.BaseBPCombat_C"
local HERO_CLASS = "/Game/Characters/BasePlayerChar.BasePlayerChar_C"
local MODE_CUSTOM_CLIMB = 7          -- EMovementMode MOVE_Custom: the game's climbing (read live 2026-11-14)
-- The owner's design of 2026-11-14 17:38 (KUMM KrinikConanLocomotion.md, verbatim there): «от стены не сильно в сторону отпрыгивал, метра пол» · «чем лучше
-- герой прыгает … от стены тоже прыгает выше». `[AI]` numbers for it:
-- * up = the hero's OWN jump speed × WALL_UP_K, taken from krinik_oblivion_locomotion's law (`_G.__krinik_hero_jump_z`, 420 + 3 × Agility) — NOT from
--   `CharacterMovement.JumpZVelocity`, which the game resets to its literal 420 after any damage and which nothing rewrites on the wall (judge round 5);
--   then the live property if it is a positive number, then 420;
-- * push = PUSH_REF × REF_JUMP / up: the flight lasts about in proportion to the jump speed, so the sideways gap stays ≈ 0.5 m for a better jumper too
--   (45 at 444 → 46–47 cm, TC W10; a speed alone would grow the gap with Agility — judge round 5).
-- WASD steers the flight by the game's OWN air control (`CharacterMovement.AirControl` 0.60, read live 17:4x), so nothing of ours sets it.
-- (Before: a fixed 250 / 350, ≈ 2 m off.)
local PUSH_REF, REF_JUMP = 45, 444   -- cm/s along the wall's normal at the jump speed 444 (Agility 8): 46–47 cm from the wall start to the landing (TC W10)
local WALL_UP_K = 1.0                -- × the hero's jump speed: the wall jump goes as high as the hero's own jump [NOT-TESTED] the apex comparison
local UP_FALLBACK = 420              -- cm/s, the game's own JumpZVelocity literal
local CHEST_Z, REACH = 40, 150       -- the forward trace: from 40 cm above the actor's centre, 150 cm long
local MIN_WALL = 0.5                 -- the horizontal part of the normal at least this long — a wall, not a ceiling or a slope
local LOG_FIRST = 10
local ksl = nil
local count, misses = 0, 0
-- Which event is which (read live 2026-11-14 16:3x from the class's input bindings, `_config/input-bindings-probe.lua`): the hero's Jump PRESS is
-- `InpActEvt_Jump_K2Node_InputActionEvent_26` (InputKeyEvent 0), the RELEASE is `_27` (1); StartJump runs inside the PRESS, the release never calls it.
-- So the release of the press that grabbed the wall cannot push (the judge's round-1 worry came from the stand, which had the two events swapped).
-- The time-on-the-wall rule stays as a cheap guard: the push is given only after MIN_CLIMB_S on the wall, so a climb that would start inside the press
-- itself never turns that press into a push. Whether a real grab can start inside the press is NOT settled (the stand's climbs are started by its
-- `Climb(false)`; W13's real-Space catch may ride the stand's leftover `bWantsToClimb`). Such a grab and the press's StartJump would run in one call,
-- microseconds apart, while any later grab comes on a movement tick after the press — so 0.05 s is enough (judge round 5). 0.4 s until 17:4x, 0.15 s until
-- 18:0x — both dropped a fast second tap in the owner's wall-to-wall chain («прыгать со стены на стену», 17:39).
local MIN_CLIMB_S = 0.05
local climb_t = nil
local early, unseen = 0, 0
-- The grab in the air (bug 105, header): the hero's Jump event — registered under the RELEASE's name, it fires for the press `_26` too (header: UE4SS keeps
-- the two names as one); registering both names would run the handler twice per event.
local JUMP_EVENT = HERO_CLASS .. ":InpActEvt_Jump_K2Node_InputActionEvent_27"
local MODE_FALLING = 3               -- EMovementMode MOVE_Falling: a jump's or a push's flight
local wished = false                 -- the wish now standing is OURS (set at a release in this flight), so the landing takes it back
-- The flight of a wall push: true from the push until the landing (any mode but falling) or a NEW press in that flight; releases re-wish only outside it.
-- `push_t` — the push's moment: the Jump event handled within PUSH_CALL_S of it is the very press that pushed (its body ended in the same call); two real
-- presses are never that close (a fast double tap is ≥ 50 ms).
local push_flight, push_t = false, 0
local PUSH_CALL_S = 0.02
local DUP_S, last_event_t = 0.005, -1   -- the same key event delivered twice (on_jump_event)
local left_wc = false                   -- the wish as on_jump_event last LEFT it: tells a duplicate call, and whether a release really cleared a wish
local blocked, renew = 0, 0
local last_mode = nil                -- the mode before the current change: leaving the climb is told by it (judge r1, item 1); declared before own() resets it
-- The hang's stamina — OUR reason flag (KUMM bug 106 item 2; `[OWNER]` 2026-11-16 22:31 «вис на стене должен медленно но расходывать выносливость, помимо того
-- что ползание по стене расходует выносливость» · 2026-11-17 09:18 «можно без таймера? а просто следить за событием "повис на стене" и за событием "слез со
-- стены", а в промежутке - снимать выносливость с определённой скоростью» · 09:33 «новый флаг разрабатываем»; verbatim in KUMM interviews/interview_037).
-- How the game itself spends stamina over time (read 2026-11-17 09:2x by the remote — KUMM game map «How the game spends stamina over time»): a blueprint sets a
-- REASON BIT once at the event (`StaminaDegenerationBitmaskSet(2)` at the sprint's start, 4 in water) and the game's own ≈ 10 Hz stamina tick takes the bit's rate.
-- The rates are native (bit 2 → SprintStaminacost 8, 4 → SwimStaminacost 2.5, 32 → 6.7; any other bit → 0 — a new bit adds nothing to the game's sum), so the
-- new reason is kept HERE: `hang_on` goes up at the grab and down when the climb ends (the mode-change events below — no polling), and while it stands the game's
-- own stamina tick on the wall takes HANG_PER_S × the real time since its previous tick: `BasePlayerChar_C:ReceiveClimbingStaminaCostModifier`, which the game
-- calls ≈ 10 times a second on a climbing hero, still or moving (71 calls in 7.06 s hanging still, 2026-11-17 09:29), and never off the wall. No timer of ours.
-- [TESTED: 2026-11-17 09:50 · r3 by the remote on the desert arch: 2.0 / s still (108 → 88 in 10 s), the crawl pays the game's cost plus ours, an empty bar →
-- the game drops the hero (never below 0), the push and the climb down end the hang, each hang starts from zero · KUMM testcases/reports/
-- 2026-11-17_conan-wall-hang-stamina.md] — the cost with the game in front and real keys [NOT-TESTED].
-- The whole time on the wall pays — still or crawling, on top of the game's own crawling cost (≈ 18 / s): «в промежутке» between the two events `[AI]`.
local HANG_PER_S = 2.0               -- [AI] stamina per second on the wall: the rate recommended in interview #037 Q2 (a full bar of 108 ≈ 54 s); the owner may name another
local HANG_TICK_MAX_S = 0.25         -- one tick takes at most this much time — a hitch, a pause or a missed tick never lands as a lump (the game's tick is 0.1 s)
local hang_on, hang_t, hang_acc = false, 0, 0                 -- the flag, the previous tick's moment, the fraction not yet taken (the bar is whole numbers)
-- Per hang, for its one log line at the end (the mod measures itself — HOUSE_RULES rule 7). `os.clock` steps by 1 ms here (KUMM bugs 93, 99), so a call's own
-- time is not printed as microseconds: the line counts the ticks whose call crossed a clock step — that share × 1 ms is the mean cost (judge r1, item 3).
local hang_t0, hang_taken, hang_ticks, hang_slow = 0, 0, 0, 0
local hang_logged = 0

-- The hang flag (above): up at the grab, down at the climb's end; both idempotent — the mode hook fires twice per change, and the push ends the hang itself too.
local function hang_begin()
    if hang_on then return end
    hang_on, hang_t, hang_acc = true, os.clock(), 0
    hang_t0, hang_taken, hang_ticks, hang_slow = hang_t, 0, 0, 0
end

-- One line per hang, every hang (no LOG_FIRST cap: a climb lasts seconds, the line is the drain's only witness — judge r2, item 2). The time on the wall is
-- up to the LAST game tick: a death on the wall is ended only by the new pawn's first event, which may come a minute later (judge r2, item 6).
local function hang_end(why)
    if not hang_on then return end
    hang_on, hang_acc = false, 0
    hang_logged = hang_logged + 1
    log("вис кончился (%s): %.1f с на стене, расход виса %d (%.1f в секунду), тиков игры %d, из них пересекли шаг часов 1 мс — %d (%d)", tostring(why),
        hang_t - hang_t0, hang_taken, HANG_PER_S, hang_ticks, hang_slow, hang_logged)
end

-- The state belongs to ONE hero: a new player pawn (a respawn) starts clean. Told by the pawn's address in the handlers, not by any birth of the class (judge r3:
-- another BasePlayerChar_C born mid-flight would have dropped the push's guard); the dead body's mode changes are not the player's, so nothing ended its flight.
local hero_addr = nil
local function own(c)
    local ok, a = pcall(function() return c:GetAddress() end)
    if not ok or a == hero_addr then return end
    hang_end("новый герой")                          -- a hang of the old pawn (death on the wall) still says its line (judge r1, item 6)
    hero_addr = a
    wished, push_flight, push_t, left_wc, last_mode, climb_t = false, false, 0, false, nil, nil
end
local rewish, landed_off, skipped = 0, 0, 0
local JUMP_BLOCKERS = { 13, 14, 18 } -- substates where the game forbids a jump for a reason (14 — exhausted); the same set as krinik_air_combat's mid-draw jump

-- The game's climbing: custom mode 7 with the custom sub-mode 0 (read live 2026-11-14) — one test for every branch (judge r1, item 7).
local function is_climb(m) return m.MovementMode == MODE_CUSTOM_CLIMB and m.CustomMovementMode == 0 end

local function in_substate(c, s)
    local out = {}
    c:InSubstate(s, out)
    return out.Success == true
end

-- The bow's draw ends at the grab (`[OWNER]` 2026-11-16 23:24 «при натянутом луке и прыжке на стену - натяжение снимается, герой повисает на стене. ПКМ прикладка
-- не работает в висе на стене» · 23:31 «то что она с луком в лекоыв руке висит - ок» · «гдавное, чтобы не в стойке натяжения висела»; verbatim in KUMM bugs/105,
-- TC G7 / G7b). Read 23:2x by real input: a draw begun in the jump goes on on the wall (substates 11 / 15 / 16, the aim view 1 / 75, the bow in hand) until RMB goes
-- up, while a NEW RMB press on the wall draws nothing — the game's own refusal keeps G7b. So only the draw brought onto the wall is ended: the game's own
-- `ExitSubstate` for the hold 16, the draw 15 and the attack 11 (read 23:39 on a hero hanging in the draw with RMB held: mode 7 kept, the substates gone, the aim
-- view back to normal by itself within 0.3 s and the draw not restarted; the frame shows the climbing pose with the bow in the left hand — the owner: ok).
-- NOT `CancelAttackTry()`: it ends the draw too, but the cancelled attack throws the hero off the wall within 7 ms (r8, 23:33:46.2277 → .2344 «лазание
-- кончилось (режим 3)»; on a hero hanging WITHOUT a draw it keeps the climb). On the next game-thread step, not inside the mode-change hook (EXP-0535).
-- [TESTED: 2026-11-17 04:55–04:57 · build r14 by real input, every row read WHILE RMB was held (the owner's rule): G7 — a full draw, the jump, the grab → substates
-- 11,15,16 gone, the draw montage stopped by identity, 2.6 s on the wall with RMB held and no relapse; G7e — RMB pressed in the flight 0.18 s before the touch →
-- the same, 2.2 s held; both 300 ms reads «висит на стене, стойки лука нет, атака игры false» · KUMM testcases/reports/2026-11-17_conan-wall-grab-bow-cancel-r14.md]
-- — the relapse branch (a stance back on the wall at 300 ms) [NOT-TESTED]: never seen live; the top of the wall waits for the owner (KUMM interview #037 Q1).
-- The bow's substates (`ECharacterSubState.h`): 11 attack (the draw's first ≈ 0.55 s, the release tail after a shot, a redraw), 15 PowerCharge, 16 ChargeHold.
local BOW_SUBSTATES = { 11, 15, 16 }
local EXIT_ORDER = { 16, 15, 11 }    -- the hold, the draw, the attack — the order read live 23:39
-- The bow's draw montage by identity (judge r13 item 1) and the name part of the bow's combat montages (the equip `AM_combat_2h_bow_3rd_equip` is not one).
local BOW_DRAW_MONTAGE = "/Game/Characters/humans/animations/combat/2h_bow/AM_combat_2h_bow_combo_heavy_c0.AM_combat_2h_bow_combo_heavy_c0"
local BOW_COMBO = "2h_bow_combo"
local draw_asset = nil
local cancels, relapses, cancel_err = 0, 0, 0   -- cancel_err caps the log of all three error sites together (one burst may hide another — accepted, judge r13 item 9)
local no_bow_fn_said = false
local CHECK_MS = 300                 -- the second read after a cancel: the r10 relapse came from the montage playing on, a CancelAttackTry throw-off 7 ms later — neither
                                     -- is visible in the same step (judge r12 item 3); 0.3 s is how long the aim view took to return by itself (23:39)

-- The bow in the hands (not on its sheath): krinik_air_combat's reading, shared through `_G` and read at call time (judge round 2: copies of one test drift;
-- krinik_bow_sprint reads the same one). Missing (that section failed to load) → «no bow», said once: nothing is cancelled then. [NOT-TESTED] the missing branch
local function bow_in_hand(c)
    local f = _G.__krinik_bow_in_hand
    if f then return f(c) == true end
    if not no_bow_fn_said then no_bow_fn_said = true; log("нет проверки «лук в руках» из раздела krinik_air_combat — стойка лука на стене не снимается") end
    return false
end

-- The bow's stance the hero brought onto the wall: the bow in hand AND any of its substates, returned as the list that stands ("11,15,16"), or nil. The list,
-- not a name: a draw and the release tail after a shot both read 11,15 (judge r13 item 6). Only the bow (`[AI]` judge r12 item 5: the owner named the bow's
-- stance; a melee swing or another weapon's charge is left alone).
local function bow_stance(c)
    if not bow_in_hand(c) then return nil end
    local on = {}
    for _, s in ipairs(BOW_SUBSTATES) do if in_substate(c, s) then on[#on + 1] = tostring(s) end end
    return #on > 0 and table.concat(on, ",") or nil
end

-- Stops the bow's montages that are PLAYING and says which. The draw, the full hold, the shot's release tail and a redraw are ONE montage,
-- `AM_combat_2h_bow_combo_heavy_c0` (the 15 ms recorder 2026-11-17 04:4x: 11 → 11,16 → 11,15,16; LMB → 16 ends — the arrow is shot — 11,15 play on 0.7 s in
-- the same montage; a held RMB redraws it). By identity, never «whatever is current» (judge r12 item 1, r13 item 1: `GetCurrentMontage` is the montage started
-- LAST — a hit reaction started after the draw would hide it, and the draw would play on and re-enter 15 / 16): the draw asset itself (found once, loaded
-- while the hero draws) and the current montage when it is one of the bow's combat montages; each stopped only if the anim instance says it is playing.
local function stop_bow_montages(c)
    local anim = c.Mesh:GetAnimInstance()
    if not (anim and anim:IsValid()) then return "нет экземпляра анимации" end
    if not (draw_asset and draw_asset:IsValid()) then
        local a = StaticFindObject(BOW_DRAW_MONTAGE)
        draw_asset = (a and a:IsValid()) and a or nil
    end
    local cands = {}                 -- built by append: a nil inside a table constructor would end ipairs at the first hole
    if draw_asset then cands[#cands + 1] = draw_asset end
    local cur = c:GetCurrentMontage()
    if cur and cur:IsValid() and cur:GetFName():ToString():find(BOW_COMBO, 1, true) then cands[#cands + 1] = cur end
    local stopped, seen = {}, {}
    for _, mt in ipairs(cands) do
        -- by the object, not the short name (judge r14 item 2: a same-named asset elsewhere would hide the playing one); active = playing OR paused (item 4)
        local key = mt:GetAddress()
        if not seen[key] and anim:Montage_IsActive(mt) then c:StopAnimMontage(mt); stopped[#stopped + 1] = mt:GetFName():ToString() end
        seen[key] = true
    end
    return #stopped > 0 and ("остановлена " .. table.concat(stopped, ", ")) or "не играла"
end

local function end_stance(c)
    local said = stop_bow_montages(c)
    for _, s in ipairs(EXIT_ORDER) do c:ExitSubstate(s, {}) end
    return said
end

-- What the hero is in, said as read (the log never claims more than the read): on the wall — the bow's stance and the game's attack flag (judge r12 item 4: the
-- substates end, the flag may not, and the next draw or jump would be refused while it stands); off the wall — the mode and the flag (a fresh draw on the
-- ground is the player's, not judged here — judge r13 item 5).
local function state_line(c)
    local m = c.CharacterMovement
    local att = {}
    c:IsAttacking(att)
    if not is_climb(m) then return string.format("лазание кончилось, режим %s, атака игры %s", tostring(m.MovementMode), tostring(att.IsAttacking)) end
    local st = bow_stance(c)
    return string.format("висит на стене, %s, атака игры %s", st and ("стойка лука есть: " .. st) or "стойки лука нет", tostring(att.IsAttacking))
end

-- The second look CHECK_MS after the grab (judge r13 item 2): a stance back ON the wall is ended once more — always, not only while the log counter runs.
-- `n` — the cancel's number, or nil when the grab had no stance to end (then only a relapse is said).
local function recheck(c, n)
    ExecuteInGameThreadWithDelay(CHECK_MS, function()
        local ok2, e2 = pcall(function()
            if not c:IsValid() then return end
            local back = is_climb(c.CharacterMovement) and bow_stance(c) or nil
            if back then
                local said2 = end_stance(c)
                relapses = relapses + 1
                if relapses <= LOG_FIRST then
                    log("захват стены: через %d мс стойка лука %s на стене (подсостояния %s) — снята, анимация лука %s; сейчас: %s (%d)",
                        CHECK_MS, n and "ВЕРНУЛАСЬ" or "появилась", back, said2, state_line(c), relapses)
                end
            elseif n and n <= LOG_FIRST then
                log("захват стены в стойке лука: через %d мс — %s (%d)", CHECK_MS, state_line(c), n)
            end
        end)
        if not ok2 and cancel_err < LOG_FIRST then cancel_err = cancel_err + 1; log("проверка после захвата стены не удалась: %s", tostring(e2)) end
    end)
end

-- Called at the grab: everything happens on the next game-thread step, read there (judge r12 item 6: no engine read inside the mode-change hook, and a stance
-- entered between the hook and the step is caught too). The second look is armed for every grab with the bow in hand (judge r14 item 3: a draw entered a tick
-- after this step) and BEFORE any log line, so a throwing log never disarms it (judge r14 items 1, 5).
local function cancel_draw(c)
    ExecuteInGameThread(function()
        local ok, err = pcall(function()
            if not c:IsValid() or not is_climb(c.CharacterMovement) then return end   -- the grab ended within the step: an air draw is not cut
            if not bow_in_hand(c) then return end                                      -- no bow in hand: nothing of ours to look at
            local st = bow_stance(c)
            if not st then recheck(c, nil); return end                                 -- no stance now (an RMB release before the step ended it); look once more
            -- The bow's montage first: left playing, a draw begun ≈ 0.25 s before the touch re-entered 15 / 16 on the wall and the hero crawled up in the draw
            -- (r10 23:46, the owner saw it 23:49 «я видел, как она в натяжке ползёт по стене»); stopped + the exits, the stance stayed gone with RMB held (23:49).
            local said = end_stance(c)
            cancels = cancels + 1
            local n = cancels
            recheck(c, n)
            if n <= LOG_FIRST then
                local okl, line = pcall(state_line, c)
                log("захват стены в стойке лука (подсостояния %s): анимация лука %s, подсостояния сняты — сейчас: %s (%d)", st, said,
                    okl and line or ("не прочитано: " .. tostring(line)), n)
            end
        end)
        if not ok and cancel_err < LOG_FIRST then cancel_err = cancel_err + 1; log("снятие стойки лука не удалось: %s", tostring(err)) end
    end)
end

local function wall_normal(c)
    ksl = ksl or StaticFindObject('/Script/Engine.Default__KismetSystemLibrary')
    local loc, fwd = c:K2_GetActorLocation(), c:GetActorForwardVector()
    local s = { X = loc.X, Y = loc.Y, Z = loc.Z + CHEST_Z }
    local e = { X = s.X + fwd.X * REACH, Y = s.Y + fwd.Y * REACH, Z = s.Z + fwd.Z * REACH }
    local hit = {}
    if not ksl:LineTraceSingle(c, s, e, 0, true, { c }, 0, hit, true, { R = 0, G = 0, B = 0, A = 0 }, { R = 0, G = 0, B = 0, A = 0 }, 0) then return nil end
    local nx, ny = hit.ImpactNormal.X, hit.ImpactNormal.Y
    local nl = math.sqrt(nx * nx + ny * ny)
    if nl < MIN_WALL then return nil end
    return nx / nl, ny / nl
end

-- The game's own stamina tick on the wall (header of `hang_on`). The bar is whole numbers: the fraction waits in hang_acc. An empty bar is the game's to act
-- on — it drops an exhausted hero off the wall itself (2026-11-17 09:3x: the degeneration tick took the bar to 0 and the game dropped the hero, mode 7 → 3) — so
-- the hang never takes the bar below zero. Only OUR hero's ticks count (the address own() keeps — a host's partner climbing at the same time is not ours; judge
-- r1, item 2); the address is a Lua-side read, no game call. A tick never calls own(): it must not reset the state.
local function on_climb_tick(ctx)
    if not hang_on then return end
    local t0 = os.clock()
    local c = ctx:get()
    local oka, a = pcall(function() return c:GetAddress() end)
    if not oka or a ~= hero_addr then return end
    local dt = t0 - hang_t
    hang_t = t0
    if dt <= 0 then return end
    if dt > HANG_TICK_MAX_S then dt = HANG_TICK_MAX_S end
    hang_ticks = hang_ticks + 1
    hang_acc = hang_acc + HANG_PER_S * dt
    if hang_acc >= 1 then
        local take = math.floor(hang_acc)
        hang_acc = hang_acc - take
        local cur = c:GetIntStat(5, 0)               -- ECharIntStatID 5 = StaminaCurrent (KUMM game map «Climbing»)
        if cur > 0 then
            if take > cur then take = cur end
            c:AdjustStaminaCurrent(-take)
            hang_taken = hang_taken + take
        end
    end
    if os.clock() > t0 then hang_slow = hang_slow + 1 end
end

local function on_mode_changed(ctx)
    local c = ctx:get()
    if not c:IsPlayerControlled() then return end
    own(c)
    local m = c.CharacterMovement
    local climbing = is_climb(m)
    local was_climb = last_mode == "climb"
    last_mode = climbing and "climb" or m.MovementMode
    if climbing then
        climb_t = os.clock()                         -- every entry (judge round 2: a missed exit must not leave an old moment)
        hang_begin()                                 -- the hang flag up: the event «повис»; idempotent, so outside the gate below — a stale «climb» left by a
                                                     -- missed exit must not start a free climb (judge r2 2026-11-17, item 1)
        if not was_climb then                        -- the grab itself, once (the mode hook fires twice per change)
            -- A throw (only the scheduling can throw here) must not skip the bookkeeping below — and is said, not dropped (judge round 2).
            local okd, ed = pcall(cancel_draw, c)
            if not okd and cancel_err < LOG_FIRST then cancel_err = cancel_err + 1; log("снятие стойки лука не поставлено в очередь игры: %s", tostring(ed)) end
        end
    else
        climb_t = nil
        hang_end("режим " .. tostring(m.MovementMode) .. "/" .. tostring(m.CustomMovementMode)) -- the event «слез»: any mode but the climb (over the top, down,
                                                     -- dropped, pushed off, exhausted); the sub-mode said, so «7/1» is not read as the climb itself
    end
    if m.MovementMode ~= MODE_FALLING then push_flight = false end   -- the push's flight is over (a stale guard would eat a later jump's re-wish)
    -- OUR wish lives through the flight and through the climb it gave: a grab keeps it (the game holds it true while climbing — game map). It is taken back
    -- when the flight ends without a wall (walking, swimming) and when the climb it gave ends (climbed over the top, climbed down, dropped off): the game's own
    -- release that would clear it came before the grab, and a wish left standing would grab the next wall with no Space, or the same wall on a drop (judge r1).
    if wished and not climbing and (m.MovementMode ~= MODE_FALLING or was_climb) then
        wished = false
        pcall(function() m.bWantsToClimb = false end)
        landed_off = landed_off + 1
        if landed_off <= LOG_FIRST then log("%s (режим %d) — наше желание зацепиться снято (%d)", was_climb and "лазание кончилось" or "полёт кончился без стены", m.MovementMode, landed_off) end
    end
    -- The wish as it stands now — our clear above and the game's own changes at a mode change included — is what the next Jump event compares with (judge r3:
    -- a value left by an old re-wish let a refused mid-air press after a landing be overridden).
    left_wc = m.bWantsToClimb == true
end

-- The hero's Jump event, press or release, read after its whole body (StartJump and our push included — KUMM EXP-0530); told apart by the effect (header):
-- 1. the press that pushed off a wall — this very call (the push ran microseconds ago inside its body): the wish off AGAIN, after the body — the push cleared
--    it inside StartJump, yet the recorder read it true 10 ms after the push with the key still down (TC G5b, 22:29:56), so the rest of the body sets it;
--    a held Space must not hand the same wall back;
-- 2. the wish stands → a PRESS (its body set it): the wish is the player's own now — a landing must not take back a Space he still holds (judge r1, item 2);
--    a press in a push's flight is his new wish, so the push's guard ends (wall to wall);
-- 3. the wish is off → a RELEASE (its body cleared it): in a push's flight — nothing (the same wall); falling, and the wish this handler last left was ON (the
--    release really cleared one — a press the game refused leaves it off and is not overridden, judge r2 item 4) — the game's own climb call sets the wish
--    again, so a wall touched later in this flight is grabbed as with a held Space; on the ground or on the wall the game's own release stands.
-- One key event may reach this hook twice in the same moment (22:47:43.5360 and .5362 — one real release after a push): a call within DUP_S of the previous that
-- finds the wish as the previous call LEFT it is that same event (a duplicate by time alone would swallow a real release that shares one input pass with its
-- press — judge r2 item 2); the second call would otherwise read our fresh re-wish as a press and lose the landing clear.
local function on_jump_event(ctx)
    local c = ctx:get()
    if not c:IsPlayerControlled() then return end
    own(c)
    local m = c.CharacterMovement
    local now, wc = os.clock(), m.bWantsToClimb == true
    if now - last_event_t < DUP_S and wc == left_wc then return end
    last_event_t = now
    local was = left_wc
    left_wc = wc
    if push_flight and now - push_t < PUSH_CALL_S then
        pcall(function() m.bWantsToClimb = false end)
        left_wc = false
        return
    end
    if wc then
        wished = false
        if push_flight then
            push_flight = false
            renew = renew + 1
            if renew <= LOG_FIRST then log("новое нажатие пробела в полёте после толчка — снова цепляемся за стену (%d)", renew) end
        end
        return
    end
    wished = false                                   -- the game's release has just cleared whatever stood
    if push_flight then                              -- the flight of a wall push: no re-wish, the same wall must not re-catch the hero
        skipped = skipped + 1
        if skipped <= LOG_FIRST then log("отпускание в полёте после толчка от стены — желание не ставим, та же стена героя не поймает (%d)", skipped) end
        return
    end
    if m.MovementMode ~= MODE_FALLING or not was then return end
    wished = true                                    -- before the call: a grab inside it would see the wish as ours (judge r1, item 8)
    c:Climb(false)
    left_wc = m.bWantsToClimb == true
    rewish = rewish + 1
    if rewish <= LOG_FIRST then log("пробел отпущен в полёте — желание зацепиться оставлено до конца полёта (%d)", rewish) end
end

local function on_start_jump(ctx)
    local c = ctx:get()
    if not c:IsPlayerControlled() then return end
    own(c)
    local m = c.CharacterMovement
    if not is_climb(m) then return end
    if not climb_t then                              -- the climb start was not seen (the mode-change hook missing?) — no push, said so
        unseen = unseen + 1
        if unseen <= LOG_FIRST then log("прыжок на стене: начало лазания не замечено — толчка нет (%d)", unseen) end
        return
    end
    if os.clock() - climb_t < MIN_CLIMB_S then      -- a press within MIN_CLIMB_S of the grab — the climb stays
        early = early + 1
        if early <= LOG_FIRST then log("прыжок на стене: нажатие раньше %.2f с после захвата стены — лазание остаётся (%d)", MIN_CLIMB_S, early) end
        return
    end
    local nx, ny = wall_normal(c)
    if not nx then
        misses = misses + 1
        if misses <= LOG_FIRST then log("прыжок на стене: впереди не стена — оставлено игре (%d)", misses) end
        return
    end
    -- The push is a jump and pays as one (`[OWNER]` 2026-11-16 22:31 «прыжок из виса на стене должен расходовать выносливость», verbatim in KUMM bugs/106):
    -- an exhausted hero (the game's own jump blockers) stays on the wall; otherwise the game's own jump cost — BasePlayerChar_C:GetStaminaJumpCost → Value
    -- (−20 on the owner's hero, read 2026-11-16 21:0x) → AdjustStaminaCurrent, as the mid-draw jump of krinik_air_combat. [TESTED: 2026-11-16 23:16 · G10 79 → 59,
    -- 81 → 61 by a debug probe · KUMM report 2026-11-16_conan-jump-wall-grab.md] — the blocker branch is a safety net: the game drops an exhausted hero off the wall
    -- before any press (23:20).
    for _, s in ipairs(JUMP_BLOCKERS) do
        if in_substate(c, s) then
            blocked = blocked + 1
            if blocked <= LOG_FIRST then
                log("прыжок на стене: %s (подсостояние %d) — толчка нет, герой висит дальше (%d)", s == 14 and "герой выбился из сил" or "игра запрещает прыжок", s, blocked)
            end
            return
        end
    end
    local jz = _G.__krinik_hero_jump_z and _G.__krinik_hero_jump_z() or nil
    local src = "закон Проворства"                  -- where the height came from, said in the log (judge round 6)
    if type(jz) ~= "number" or jz <= 0 then
        local okp, v = pcall(function() return m.JumpZVelocity end)
        if okp and type(v) == "number" and v > 0 then jz, src = v, "свойство JumpZVelocity" else jz, src = UP_FALLBACK, "запасное 420" end
    end
    local up = jz * WALL_UP_K
    local push = PUSH_REF * REF_JUMP / up
    wished = false                                   -- the push clears the wish itself (below); before ExitClimbing, so its mode change does not report a climb end (judge r3)
    m:ExitClimbing()
    -- The climb wish off: with it on, a near-vertical flight of a strong jumper re-caught the SAME wall (stand 18:24, up 720 — no landing in 4.5 s); a new
    -- catch is the player's Space in the air, which runs the game's own Climb() and sets the wish again (TC R6 (1)). [TESTED: 2026-11-14 18:29 · the wish
    -- false after the push, landed 46 cm (Agility 8); a 720 / 27.8 flight with the wish off landed 98 cm off (it re-caught before); remote press in the air
    -- at the wall → wish true, mode 7 in 0.02 s; its RELEASE cleared the wish again — whether a REAL press then pushes is open (TC R6 (1))]
    pcall(function() m.bWantsToClimb = false end)
    c:LaunchCharacter({ X = nx * push, Y = ny * push, Z = up }, true, true)
    -- The guard state right after the launch, before anything that may throw (judge r2 item 1: a failed charge left the guard off and the same wall re-caught).
    climb_t = nil                                    -- the climb is over here, whether or not the mode-change hook sees this exit (judge 16:5x)
    hang_end("толчок от стены")                      -- the same for the hang flag (judge r1 2026-11-17, item 1); a no-op when the mode change already ended it
    push_flight, push_t = true, os.clock()           -- no re-wish in this push's flight (header: the same wall)
    -- The cost is a negative change: toward zero on a fraction, never past the game's own number (math.ceil(−20.5) = −20 — judge r2).
    local okc, cost = pcall(function() local o = {}; c:GetStaminaJumpCost(o); return o.Value end)
    local paid = okc and tostring(cost) or "не прочитана"
    if okc and type(cost) == "number" and cost < 0 then
        local okp, perr = pcall(function() c:AdjustStaminaCurrent(math.ceil(cost)) end)
        if not okp then paid = "ошибка списания: " .. tostring(perr) end
    end
    count = count + 1
    if count <= LOG_FIRST then log("прыжок со стены: толчок %.0f от стены по нормали (%.2f, %.2f) и %.0f вверх (прыжок героя %.0f × %.2f, %s), выносливость %s (%d)", push, nx, ny, up, jz, WALL_UP_K, src, paid, count) end
end

-- The blueprint class is ready when the hero is born; the hook is registered once per game start (the pattern of krinik_air_combat).
NotifyOnNewObject(HERO_CLASS, function()
    ExecuteInGameThread(function()
        if _G.__krinik_wall_jump_hooked then return end
        _G.__krinik_wall_jump_hooked = true
        local hooks = { { COMBAT_CLASS .. ":StartJump", on_start_jump }, { COMBAT_CLASS .. ":HandleOnMovementModeChanged", on_mode_changed },
                        { JUMP_EVENT, on_jump_event }, { HERO_CLASS .. ":ReceiveClimbingStaminaCostModifier", on_climb_tick } }
        for _, h in ipairs(hooks) do
            -- Each hook its own error budget: the 10 Hz wall tick throwing steadily must not spend the lines of the other hooks (judge r1 2026-11-17, item 4).
            local errs = 0
            local name = h[1]:match(":(.+)$")
            local ok, err = pcall(function()
                RegisterHook(h[1], function(ctx)
                    local ok2, e2 = pcall(h[2], ctx)
                    if not ok2 and errs < 5 then errs = errs + 1; log("ошибка в %s: %s", name, tostring(e2)) end
                end)
            end)
            log(ok and "перехват %s поставлен%s" or "перехват %s не встал — %s", name, ok and "" or tostring(err))
        end
    end)
end)

log("взведён: прыжок во время лазания отталкивает от стены (%d × %d / прыжок героя по нормали, вверх — прыжок героя × %.2f; на стене не меньше %.2f с); в полёте герой цепляется за стену и после отпускания пробела; вис на стене тратит %.1f выносливости в секунду", PUSH_REF, REF_JUMP, WALL_UP_K, MIN_CLIMB_S, HANG_PER_S)
