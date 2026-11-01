--[[============================================================================
  ConanAttributeProbe — первый шаг идеи 03 «атрибуты как в Морровинде»
  ============================================================================

  ВОПРОС, НА КОТОРЫЙ ОТВЕЧАЕТ ЭТОТ ФАЙЛ, РОВНО ОДИН:
      читается ли из Lua значение атрибута живого персонажа?
  Пока ответа нет, вся идея (бег от Ловкости, выносливость от Выдержки) —
  теория.

  АДРЕС ВЗЯТ НЕ ПЕРЕБОРОМ, А У DEV KIT (безоконный Python-командлет, 12.09.2026,
  KUMM/ideas/03_*): у класса ConanCharacter (родитель Character) есть
      GetIntStat(StatID: ECharIntStatID, Mode: EStatModifierMode) -> int32
  а номера перечисления сняты там же. ⚠️ Кит НОВЕЕ игры (CL 374980 против
  373655), номера могли сдвинуться. Поэтому первым печатается LEVEL — уровень
  героя владелец знает, и он сразу говорит, верна ли нумерация.

  ПРАВИЛА, ОПЛАЧЕННЫЕ ПАДЕНИЯМИ ИГРЫ (EXP-0052, EXP-0062):
  - ни одного вечного цикла: срабатывает само несколько раз после появления
    героя и замолкает; дальше — только по клавише;
  - запись только по клавише (Alt + Numpad * и /), родные значения возвращаются;
  - каждый вызов в своём pcall.

  ВСЕ КЛАВИШИ ЗОНДА — С ALT. Голый нумпад и Ctrl+нумпад заняты модом камеры
  (Numpad . — его зонд дождя, * и / — ось вращения), Ctrl+нумпад ещё и UE4SS.
  Alt + Numpad . — прочитать; Alt + Numpad * — бег и прыжок x2; Alt + Numpad / — вернуть;
  Alt + Numpad + — серия замеров движения (40 точек за 8 с, считать speed-from-log.py);
  Alt + Numpad − — сторож 4 мин (только изменения); Alt + Numpad 0 — Проворство +10.
  ⚠️ LeftAlt у Конана — уворот: каждое нажатие кувыркает героя. Замер поэтому серией.
============================================================================]]

local MOD_NAME = "ConanAttributeProbe"

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, ok and s or tostring(fmt)))
end

local VK_DECIMAL = 0x6E   -- Numpad . (сырой код, не таблица Key — см. мод камеры)

-- ECharIntStatID по киту. LEVEL — контрольный: его значение владелец знает.
local STATS = {
    { "LEVEL",                 4 },
    { "ATTRIBUTE_ATHLETICISM", 19 },  -- Ловкость — ради неё всё
    { "ATTRIBUTE_MIGHT",       17 },  -- Сила
    { "ATTRIBUTE_HEALTH",      14 },  -- Живучесть
    { "ATTRIBUTE_STAMINA",     15 },  -- Выдержка
    { "ATTRIBUTE_ENCUMBRANCE", 16 },  -- Мастерство
    { "ATTRIBUTE_LEADERSHIP",  27 },  -- Авторитет
    { "STAMINA_MAX",           6 },
    { "HEALTH_MAX",            0 },
    { "FEAT_POINTS_TOTAL",     3 },
    { "FEAT_POINTS_USED",      2 },
}

-- EStatModifierMode по киту: FULL — с перками и бонусами, BASE — вложенные очки.
local MODES = { { "FULL", 0 }, { "BASE", 1 } }

-- Цепочка с концом: 30 попыток по 10 с (5 минут на вход в мир), потом молчит.
local AUTO_TRIES   = 30
local AUTO_STEP_MS = 10000

-- Герой — по классу, НЕ через PlayerController.Pawn: запуск 12.09 23:37 показал,
-- что Pawn у найденного контроллера пуст всё время, пока камера уже держала
-- BasePlayerChar_C. В одиночной игре такой объект один (у рабов свой класс).
local last_pawn_count = 1
local function local_pawn()
    local list = FindAllOf("BasePlayerChar_C")
    if not list or #list == 0 then return nil, "BasePlayerChar_C ещё нет" end
    -- После смерти тело героя может остаться вторым BasePlayerChar_C (13.09, опыт
    -- «переживают ли ступени смерть»): берём ЖИВОГО — у тела здоровье 0. Число
    -- экземпляров печатаем только при его смене, иначе сторож спамил бы раз в секунду.
    if #list ~= last_pawn_count then
        log("  BasePlayerChar_C теперь %d (было %d)", #list, last_pawn_count)
        last_pawn_count = #list
    end
    local first
    for _, p in ipairs(list) do
        if p and p:IsValid() then
            first = first or p
            local hp = 0
            pcall(function() hp = p:GetIntStat(1, 0) end)
            if hp > 0 then return p end
        end
    end
    if not first then return nil, "BasePlayerChar_C невалиден" end
    return first
end

-- true, если герой найден и чтение состоялось (удачное или нет — неважно).
local function read_attributes(reason)
    local pawn, why = local_pawn()
    if not pawn then
        log("%s: %s", reason, why)
        return false
    end
    local pawn_name = pawn:GetFullName()
    log("---- ЧТЕНИЕ (%s): %s ----", reason, pawn_name)

    -- Второй источник: компонент StatHolder ЭТОГО героя (по киту у него тот же
    -- GetIntStat). Свой — тот, чьё полное имя продолжает имя героя.
    local holder
    pcall(function()
        local short = pawn_name:match("([^%.]+)$")
        for _, h in ipairs(FindAllOf("StatHolder") or {}) do
            if h:IsValid() and h:GetFullName():find(short .. ".", 1, true) then holder = h; break end
        end
    end)
    log("  StatHolder героя: %s", holder and holder:GetFullName() or "не найден")

    local sources = { { "char", pawn } }
    if holder then sources[2] = { "holder", holder } end
    for _, s in ipairs(STATS) do
        local parts = {}
        for _, src in ipairs(sources) do
        for _, m in ipairs(MODES) do
            local v
            local ok, err = pcall(function() v = src[2]:GetIntStat(s[2], m[2]) end)
            local label = src[1] .. "." .. m[1]
            if ok then
                parts[#parts + 1] = ("%s=%s"):format(label, tostring(v))
            else
                parts[#parts + 1] = ("%s=ОШИБКА(%s)"):format(label, tostring(err))
            end
        end
        end
        log("  %-22s [%2d]  %s", s[1], s[2], table.concat(parts, "  "))
    end
    log("---- КОНЕЦ. Проверка нумерации: LEVEL обязан совпасть с уровнем героя. ----")
    return true
end

-- ПРЕДВАРИТЕЛЬНОЕ ОБЪЯВЛЕНИЕ: функция определена ниже, в разделе движения, а зовётся
-- отсюда. Без этой строки auto_try видела бы nil и молча не ставила перехват (EXP-0051).
local install_speed_hooks

local tries = 0
local function auto_try()
    tries = tries + 1
    ExecuteInGameThread(function()
        local done = false
        pcall(function() done = read_attributes(("авто %d/%d"):format(tries, AUTO_TRIES)) end)
        if done then
            -- Рычаги движения — переменные блюпринта героя: читаются, только когда
            -- BasePlayerChar_C уже в мире (класс грузится вместе с ним).
            local ok, err = pcall(install_speed_hooks)
            if not ok then log("рычаги движения не прочитаны: %s", tostring(err)) end
        elseif tries < AUTO_TRIES then
            ExecuteWithDelay(AUTO_STEP_MS, auto_try)
        end
    end)
end

-- ============ ДВИЖЕНИЕ: опыт «скорость бега и прыжок» (идея 03, шаг 2) ============
-- Рычаги сняты у Dev Kit 13.09: у ConanCharacter есть int RunSpeed / WalkSpeed,
-- float MovementSpeedOverride и UpdateMaxMovementSpeed() — игра сама пересчитывает
-- из них MaxWalkSpeed компонента с учётом перегруза. Прыжок — JumpZVelocity
-- компонента (родное 420). Это ПЕРВАЯ запись этого мода: только по клавише,
-- родные значения запоминаются при первой записи и возвращаются Alt + Numpad /.
local VK_MULTIPLY = 0x6A   -- Alt + Numpad * — удвоить бег и прыжок (каждое нажатие ещё x2)
local VK_DIVIDE   = 0x6F   -- Alt + Numpad / — вернуть родные значения
local native = nil
local native_agi = nil   -- родное Проворство для возврата (опыт «выше 20», 13.09)

local function fmt_vec(v)
    local s = "?"
    pcall(function() s = ("%.0f, %.0f, %.0f"):format(v.X, v.Y, v.Z) end)
    return s
end

local function read_movement(reason)
    local pawn, why = local_pawn()
    if not pawn then log("%s: %s", reason, why); return nil end
    local cm
    pcall(function() cm = pawn.CharacterMovement end)
    local function get(obj, f)
        local v; local ok = pcall(function() v = obj[f] end)
        return ok and tostring(v) or "нет"
    end
    local loc, vel, ms = "?", "?", "?"
    pcall(function() loc = fmt_vec(pawn:K2_GetActorLocation()) end)
    if cm then pcall(function() vel = fmt_vec(cm.Velocity) end) end
    pcall(function() ms = tostring(pawn:GetMovementSpeed()) end)
    -- Гипотеза владельца 13.09: здоровье и сытость сами меняют скорость и прыжок.
    local hp, st = "?", "?"
    pcall(function() hp = ("%d/%d"):format(pawn:GetIntStat(1, 0), pawn:GetIntStat(0, 0)) end)
    pcall(function() st = ("%d/%d"):format(pawn:GetIntStat(5, 0), pawn:GetIntStat(6, 0)) end)
    log("ДВИЖЕНИЕ (%s) %s  здоровье=%s  выносл=%s  место=(%s)  скорость=(%s)",
        reason, os.date("%H:%M:%S"), hp, st, loc, vel)
    log("  RunSpeed=%s WalkSpeed=%s Override=%s GetMovementSpeed=%s",
        get(pawn, "RunSpeed"), get(pawn, "WalkSpeed"), get(pawn, "MovementSpeedOverride"), ms)
    if cm then
        log("  MaxWalkSpeed=%s JumpZVelocity=%s MovementMode=%s",
            get(cm, "MaxWalkSpeed"), get(cm, "JumpZVelocity"), get(cm, "MovementMode"))
    else
        log("  CharacterMovement не прочитался")
    end
    return pawn, cm
end

-- ============ РЫЧАГ БЕГА: множители ступеней перегруза на герое ============
-- Что доказано 13.09.2026 замером (серии ЗАМЕР, speed-from-log.py):
--   · RunSpeed/WalkSpeed x2 бег НЕ меняют — 450 до и после. Базу даёт сам блюпринт:
--     ApplyNewMovementSpeed(NewSpeed = STR_CharacterMovement.Speed типа движения);
--   · перехват ApplyNewMovementSpeed (C++ и блюпринт) ВСТАЁТ и НЕ СРАБАТЫВАЕТ:
--     cpp=0 bp=0 за минуту, пока MaxWalkSpeed пересчитывался (EXP-0071, снова).
-- Поэтому не перехват, а ДАННЫЕ, которые формула читает сама:
--   MaxWalkSpeed = NewSpeed × перк × замедления × эмоция × GetEncumbranceSpeedMultiplier,
--   а последний выбирает EncumbranceTier0..4SpeedMultiplier по ступени перегруза
--   (граф функции в T3D героя). Умножив все пять ступеней на одно число, мод
--   масштабирует бег, а проценты игры и порядок ступеней остаются внутри.
-- [TESTED: 2026-09-13 10:25–10:28 · контроль и опыт подряд, серии ЗАМЕР:
--   родные ступени — бег 405, стоя 292.5; ступени x2 — бег 729, стоя 526.5,
--   то есть ровно 450×2×0.81 и 325×2×0.81 (множитель голода 0.81 игра наложила
--   сама); T0=2.000 во всех 40 точках и через 1.5 мин; Alt+/ вернул 263.25 = 325×0.81]
-- [NOT-TESTED] переживает ли запись смерть, возрождение и загрузку сохранения.
-- Родные 13.09: T0..T3 = 1.0, T4 (перегруз) = 0.3, Agi15PerkSpeedMultiplier = 1.1.
local TIER_VARS = {
    "EncumbranceTier0SpeedMultiplier", "EncumbranceTier1SpeedMultiplier",
    "EncumbranceTier2SpeedMultiplier", "EncumbranceTier3SpeedMultiplier",
    "EncumbranceTier4SpeedMultiplier",
}
-- Соседи по разделу «Movement» блюпринта — только читаются, чтобы знать родные.
local MOVE_VARS = {
    "PerkEncumbranceSpeedMultiplier", "Agi15PerkSpeedMultiplier", "MovementModeMultiplier",
    "SwimmingMovementMultiplier", "SwimSpeedModifier", "ClimbSpeedModifier",
    "GravityMultiplier", "JumpStaminaCostModifier", "CarrySpeed",
    "MinDamageVelocity", "DeadlyFallVelocity", "DiveMinDamageVelocity", "DiveDeadlyFallVelocity",
}

-- ОБЪЯВЛЕНЫ ЗДЕСЬ, ВЫШЕ install_speed_hooks, которая их читает: объявленные ниже места
-- использования, в Lua они были бы nil молча (EXP-0051, EXP-0072 — поймано до запуска).
local tier_boost, jump_boost = 1, 1
local jump_calls, jump_hero, jump_fixed = 0, 0, 0
local apply_boosts   -- определена ниже, в разделе множителей
local spawn_notify_set = false

install_speed_hooks = function()
    -- Имя осталось от перехвата; теперь это разовое чтение рычагов при появлении героя
    -- и подписка на ПОЯВЛЕНИЕ НОВОГО героя (после смерти — новый объект, 13.09 11:02).
    -- Подписываемся здесь, а не при загрузке мода: класс блюпринта грузится с миром, а
    -- 12.09 подписка на C++-класс /Script/ConanSandbox.BasePlayerChar не сработала ни разу.
    if not spawn_notify_set then
        spawn_notify_set = true
        local ok, err = pcall(function()
            NotifyOnNewObject("/Game/Characters/BasePlayerChar.BasePlayerChar_C", function(obj)
                local name = "?"
                pcall(function() name = obj:GetFullName():match("([^%.]+)$") end)
                log("НОВЫЙ ГЕРОЙ: %s (бег x%s, прыжок x%s) — переприменю через 3 с",
                    name, tostring(tier_boost), tostring(jump_boost))
                ExecuteWithDelay(3000, function() ExecuteInGameThread(function()
                    if tier_boost ~= 1 or jump_boost ~= 1 then
                        pcall(apply_boosts, local_pawn(), "после появления")
                    end
                end) end)
            end)
        end)
        log("подписка на появление героя %s", ok and "встала" or ("НЕ встала: " .. tostring(err)))
        ExecuteWithDelay(45000, function()
            log("ПРОВЕРКА перехвата прыжка: Character:Jump вызовов %d, героя %d, исправлено %d",
                jump_calls, jump_hero, jump_fixed)
        end)
    end
    local pawn = local_pawn()
    if not pawn then return end
    local parts = {}
    for _, v in ipairs(TIER_VARS) do
        local val = "нет"; pcall(function() val = ("%.3f"):format(pawn[v]) end)
        parts[#parts + 1] = v:gsub("EncumbranceTier(%d)SpeedMultiplier", "T%1") .. "=" .. val
    end
    log("РЫЧАГИ перегруз: %s", table.concat(parts, " "))
    parts = {}
    for _, v in ipairs(MOVE_VARS) do
        local val = "нет"; pcall(function() val = ("%.3f"):format(pawn[v]) end)
        parts[#parts + 1] = v .. "=" .. val
    end
    log("РЫЧАГИ прочие: %s", table.concat(parts, " "))
    pcall(function()
        local cm = pawn.CharacterMovement
        log("РЫЧАГИ компонент: GravityScale=%.3f MaxSwimSpeed=%.1f MaxFlySpeed=%.1f MaxCustomMovementSpeed=%.1f",
            cm.GravityScale, cm.MaxSwimSpeed, cm.MaxFlySpeed, cm.MaxCustomMovementSpeed)
    end)
end

-- ============ МНОЖИТЕЛИ И ИХ ПЕРЕПРИМЕНЕНИЕ (опыт 13.09 ~11:10) ============
-- Что доказано к этому месту (сторож, 13.09 11:01–11:03):
--   · ступени перегруза урон ПЕРЕЖИВАЮТ, смерть — НЕТ: новый BasePlayerChar_C
--     появляется с родными 1.0 и 420 → множитель надо переприменять при появлении героя;
--   · JumpZ сбрасывается на 420 при ЛЮБОМ уроне: BaseBPCombat.TakeHealthDamage зовёт
--     SigilLongJumpDisable, а та пишет литерал 420 (ещё OnSubstateChanged_Sprint и
--     ServerAction) — данных, из которых игра берёт 420, нет. Поэтому прыжок ставится
--     ПЕРЕД каждым прыжком: StartJump героя зовёт нативный Character:Jump, а нативные
--     функции движка этот UE4SS перехватывает (мод камеры; EXP-0071 «Not for»).
-- [TESTED: 2026-09-13 11:11–11:13 · сторож + серия ЗАМЕР:
--   прыжок: хук Character:Jump сработал на каждый прыжок героя; после урона игра держала
--   420 — хук поставил 1680 до взлёта, подъём по точкам 1438 при расчётных 1440;
--   появление: NotifyOnNewObject(BP-класс) сработал на нового героя после смерти через 10 с,
--   переприменение дало T0=4.000 и JumpZ=1680 на новом объекте (сторож подтвердил)]
-- (tier_boost, jump_boost, счётчики и apply_boosts объявлены выше install_speed_hooks.)

-- Урон от падения (BaseBPCombat: ServerEndFalling → ShouldApplyFallDamage →
-- CalculateFallDamagePercent → ApplyFallDamage): процент = (|Vz| − Min) / (Deadly − Min).
-- На ровном месте скорость приземления после прыжка РАВНА JumpZ, поэтому простое правило
-- «пороги растут тем же множителем, что прыжок» сохраняет родное отношение: свой прыжок
-- не ранит, чужой обрыв ранит соразмерно.
-- [TESTED: 2026-09-13 11:15–11:17 · родные Min −1000, Deadly −2400 (Dive −700/−1400);
--   формула сходится с замерами: 840 → 0, 1680 → 48.6% (126 из 260, наблюдалось 128),
--   3360 → смерть. С порогами x4 прыжок 1680 — без урона; с порогами x8 прыжок 3360
--   (подъём ~57 м) — без урона, тот же прыжок без правила убил героя]
local FALL_VARS = { "MinDamageVelocity", "DeadlyFallVelocity", "DiveMinDamageVelocity", "DiveDeadlyFallVelocity" }

local function remember_native(pawn, cm)
    if native then return end
    native = { tiers = {}, fall = {} }
    pcall(function() native.jump = cm.JumpZVelocity end)
    -- Разгон и торможение (опыт 13.09 11:26): на x8 бег 3600 набирался ~0.8 с. Торможение
    -- `BrakingDecelerationWalking` масштабируется записью (50 → 400, остановка за 0.2 с), а
    -- `MaxAcceleration` запись НЕ держит: BaseBPCombat.MovementGraph пишет его сам —
    -- ApplyNewAccelerationRate.Value × BP_ServerSettings_C.PlayerMovementAccelerationMultiplier.
    -- [TESTED: 2026-09-13 11:32 · множитель 1.0 → x2/x4/x8 даёт MaxAcceleration 8000/16000/32000;
    --  бег x8 набрал 3600 с 1314 за 0.21 с вместо ~0.8 с; торможение 50 → 400 держится]
    -- [NOT-TESTED] действует ли общий множитель серверных настроек на NPC.
    pcall(function() native.brake = cm.BrakingDecelerationWalking end)
    pcall(function()
        local ss = FindFirstOf("BP_ServerSettings_C")
        if ss and ss:IsValid() then native.accmul = ss.PlayerMovementAccelerationMultiplier end
    end)
    log("  родные разгона: PlayerMovementAccelerationMultiplier=%s BrakingDecelerationWalking=%s",
        tostring(native.accmul), tostring(native.brake))
    for _, v in ipairs(TIER_VARS) do pcall(function() native.tiers[v] = pawn[v] end) end
    for _, v in ipairs(FALL_VARS) do pcall(function() native.fall[v] = pawn[v] end) end
    log("  родные запомнены: jump=%s T0=%s Min=%s Deadly=%s DiveMin=%s DiveDeadly=%s",
        tostring(native.jump), tostring(native.tiers[TIER_VARS[1]]),
        tostring(native.fall.MinDamageVelocity), tostring(native.fall.DeadlyFallVelocity),
        tostring(native.fall.DiveMinDamageVelocity), tostring(native.fall.DiveDeadlyFallVelocity))
end

apply_boosts = function(pawn, reason)
    if not (pawn and native) then return end
    local cm
    pcall(function() cm = pawn.CharacterMovement end)
    local bad = {}
    for _, v in ipairs(TIER_VARS) do
        local ok, e = pcall(function() pawn[v] = native.tiers[v] * tier_boost end)
        if not ok then bad[#bad + 1] = v .. ": " .. tostring(e) end
    end
    local okj = pcall(function() cm.JumpZVelocity = native.jump * jump_boost end)
    if native.accmul then
        pcall(function()
            local ss = FindFirstOf("BP_ServerSettings_C")
            ss.PlayerMovementAccelerationMultiplier = native.accmul * tier_boost
        end)
    end
    if native.brake then pcall(function() cm.BrakingDecelerationWalking = native.brake * tier_boost end) end
    for _, v in ipairs(FALL_VARS) do
        if native.fall[v] then
            local ok, e = pcall(function() pawn[v] = native.fall[v] * jump_boost end)
            if not ok then bad[#bad + 1] = v .. ": " .. tostring(e) end
        end
    end
    pcall(function() pawn:UpdateMaxMovementSpeed() end)
    local t0, jz, mn, dd = "?", "?", "?", "?"
    pcall(function() t0 = ("%.3f"):format(pawn[TIER_VARS[1]]) end)
    pcall(function() jz = ("%.0f"):format(cm.JumpZVelocity) end)
    pcall(function() mn = ("%.0f"):format(pawn.MinDamageVelocity) end)
    pcall(function() dd = ("%.0f"):format(pawn.DeadlyFallVelocity) end)
    local acc = "?"
    pcall(function() acc = ("%.0f/%.0f"):format(cm.MaxAcceleration, cm.BrakingDecelerationWalking) end)
    log("  %s: бег x%s (T0 лежит %s, разгон/торможение %s) · прыжок x%s (JumpZ лежит %s) · падение Min %s Deadly %s%s", reason,
        tostring(tier_boost), t0, acc, tostring(jump_boost), jz, mn, dd,
        (#bad == 0 and okj) and "" or (" ОШИБКИ " .. table.concat(bad, "; ") .. (okj and "" or " JumpZ")))
end

local function scale_movement(k)
    local pawn, cm = read_movement("до записи")
    if not (pawn and cm) then return end
    remember_native(pawn, cm)
    tier_boost, jump_boost = tier_boost * k, jump_boost * k
    apply_boosts(pawn, "запись x" .. tostring(k))
end

local function restore_movement()
    local pawn = local_pawn()
    tier_boost, jump_boost = 1, 1
    if pawn and native_agi ~= nil then
        pcall(function() pawn:SetIntStat(19, native_agi) end)
        local now = -1
        pcall(function() now = pawn:GetIntStat(19, 1) end)
        log("возврат Проворства: %d (лежит %d)", native_agi, now)
    end
    if not (pawn and native) then log("возврат: множители 1, писать некуда"); return end
    apply_boosts(pawn, "возврат")
    read_movement("после возврата")
end

-- Прыжок: пре-хук нативного Character:Jump. Вызывают его и NPC — считаем всех,
-- пишем только герою и только если игра успела сбросить значение.
local function on_jump(ctx)
    jump_calls = jump_calls + 1
    if jump_boost == 1 or not native then return end
    local ch = ctx:get()
    if not ch:GetFullName():find("BasePlayerChar_C", 1, true) then return end
    jump_hero = jump_hero + 1
    local cm = ch.CharacterMovement
    local want = native.jump * jump_boost
    local was = cm.JumpZVelocity
    if math.abs(was - want) > 0.5 then
        cm.JumpZVelocity = want
        jump_fixed = jump_fixed + 1
        log("ПРЫЖОК хук #%d: игра держала JumpZ %.0f → поставил %.0f (лежит %.0f)",
            jump_hero, was, want, cm.JumpZVelocity)
    else
        log("ПРЫЖОК хук #%d: JumpZ уже %.0f", jump_hero, was)
    end
end

local jump_hook_ok = pcall(function()
    RegisterHook("/Script/Engine.Character:Jump", function(ctx)
        local ok, e = pcall(on_jump, ctx)
        if not ok then log("ПРЫЖОК хук упал: %s", tostring(e)) end
    end)
end)
log("перехват Character:Jump %s", jump_hook_ok and "встал" or "НЕ встал")

-- ============ ЗАМЕР РАЗБЕГА: серия точек, а не два чтения ============
-- [TESTED: 2026-09-13 · одиннадцать живых серий: кувырок виден первыми 6 точками (928→0),
--  бег — плато |v|, прыжок — дуга Z (JumpZ 420 → подъём 87, 840 → 358 при 90/360 по
--  v²/2g); speed-from-log.py сходится с |v| до 2–4 %]
-- Зачем серия, 13.09.2026: у Конана LeftAlt — это УВОРОТ
-- (DodgeActionV2), поэтому каждое чтение по Alt+Numpad . кувыркало героя
-- (скорость 926, минус 21 выносливости) — два чтения «до и после разбега»
-- мерили кувырки, а не бег. Правый Alt не спасает: на этой машине он AltGr,
-- Windows зажимает с ним LeftCtrl, и UE4SS видит Ctrl+Alt.
-- Поэтому одна клавиша ДО разбега запускает серию, кувырок успевает кончиться,
-- а скорость считается по точкам внутри бега. Δt берётся из меток времени
-- журнала (_config/speed-from-log.py), не из счёта задержек.
-- Цепочка конечная: SAMPLE_COUNT шагов и тишина (EXP-0052, EXP-0062).
local VK_ADD         = 0x6B   -- Alt + Numpad + — серия замеров движения
local SAMPLE_COUNT   = 40
local SAMPLE_STEP_MS = 200
local sampling       = false  -- объявлено ВЫШЕ использования (EXP-0072)

local function sample_once(i)
    local pawn = local_pawn()
    if not pawn then log("ЗАМЕР %02d героя нет", i); return end
    local cm
    pcall(function() cm = pawn.CharacterMovement end)
    local loc, hv, mws, jz, st = "?", -1, "?", "?", "?"
    pcall(function() loc = fmt_vec(pawn:K2_GetActorLocation()) end)
    pcall(function() local v = cm.Velocity; hv = math.sqrt(v.X * v.X + v.Y * v.Y) end)
    pcall(function() mws = ("%.1f"):format(cm.MaxWalkSpeed) end)
    pcall(function() jz = ("%.0f"):format(cm.JumpZVelocity) end)
    pcall(function() st = ("%d/%d"):format(pawn:GetIntStat(5, 0), pawn:GetIntStat(6, 0)) end)
    local t0 = "?"
    pcall(function() t0 = ("%.3f"):format(pawn.EncumbranceTier0SpeedMultiplier) end)
    log("ЗАМЕР %02d место=(%s) |v|=%.0f MaxWalkSpeed=%s JumpZ=%s выносл=%s RunSpeed=%s T0=%s",
        i, loc, hv, mws, jz, st, tostring(pawn.RunSpeed), t0)
end

local function sample_series()
    if sampling then log("ЗАМЕР: серия уже идёт, нажатие пропущено"); return end
    sampling = true
    log("ЗАМЕР начат: %d точек через %d мс", SAMPLE_COUNT, SAMPLE_STEP_MS)
    local i = 0
    local function step()
        i = i + 1
        ExecuteInGameThread(function()
            local ok, err = pcall(sample_once, i)
            if not ok then log("ЗАМЕР %02d упал: %s", i, tostring(err)) end
            if i < SAMPLE_COUNT then
                ExecuteWithDelay(SAMPLE_STEP_MS, step)
            else
                sampling = false
                log("ЗАМЕР конец")
            end
        end)
    end
    step()
end

RegisterKeyBind(VK_ADD, { ModifierKey.ALT }, function()
    local ok, err = pcall(sample_series)
    if not ok then sampling = false; log("ЗАМЕР не стартовал: %s", tostring(err)) end
end)

-- ============ ПРЕДЕЛ АТРИБУТА: примет ли игра Проворство выше 20 ============
-- [TESTED: 2026-09-13 11:42 · 2 → 12 → 22: FULL=BASE=22 обратным чтением, экран «Хар-ки»
--  показал «22», перки на 5 и 15 зажглись; Alt+/ вернул 2. НЕ проверено: перки выбора 10/20,
--  переживает ли >20 сохранение и загрузку]
-- Опыт 13.09 ~11:42 для интервью #004, вопрос 3: шкала в игре 0–20 (перки на
-- 5/10/15/20). Alt+Numpad 0 — Проворство +10 записью SetIntStat(19, …) у героя; повторное
-- нажатие — ещё +10; Alt+Numpad . читает. Родное значение запоминается и возвращается
-- Alt+Numpad / вместе с остальным. Копия сохранения — до опыта (запись может уйти в базу).
local VK_NUMPAD0 = 0x60
local ATHLETICISM = 19
-- native_agi объявлена рядом с native (выше restore_movement) — поймал lua-globals.py.

local function bump_agility(delta)
    local pawn = local_pawn()
    if not pawn then log("АТРИБУТ: героя нет"); return end
    local before_full, before_base = -1, -1
    pcall(function() before_full = pawn:GetIntStat(ATHLETICISM, 0); before_base = pawn:GetIntStat(ATHLETICISM, 1) end)
    if native_agi == nil then native_agi = before_base end
    local ok, ret = pcall(function() return pawn:SetIntStat(ATHLETICISM, before_base + delta) end)
    local after_full, after_base = -1, -1
    pcall(function() after_full = pawn:GetIntStat(ATHLETICISM, 0); after_base = pawn:GetIntStat(ATHLETICISM, 1) end)
    log("АТРИБУТ Проворство: было FULL=%d BASE=%d → SetIntStat(%d) %s → лежит FULL=%d BASE=%d",
        before_full, before_base, before_base + delta, ok and ("ок, вернул " .. tostring(ret)) or ("ОШИБКА " .. tostring(ret)),
        after_full, after_base)
end

RegisterKeyBind(VK_NUMPAD0, { ModifierKey.ALT }, function() ExecuteInGameThread(function()
    local ok, err = pcall(bump_agility, 10)
    if not ok then log("АТРИБУТ упал: %s", tostring(err)) end
end) end)

-- ============ СТОРОЖ: что меняется у героя, пока он живёт ============
-- [TESTED: 2026-09-13 11:01–11:17 · четыре прогона: поймал урон и сброс JumpZ в одну
--  секунду, смерть (hp=0/0) и новый объект героя с родными значениями]
-- Зачем, 13.09.2026 ~11:05: JumpZ 840 у здорового героя держался 4 минуты,
-- а у умирающего от жажды сбросился на 420 через 8 с — стоя и без строки в журнале игры.
-- Второй вопрос тот же по форме: переживают ли записанные ступени перегруза смерть и
-- возрождение (новый объект героя или тот же). Сторож раз в секунду сравнивает снимок с
-- прошлым и пишет ТОЛЬКО разницу — по времени строки видно, что поменялось вместе.
-- Конечная цепочка: WATCH_STEPS шагов (EXP-0052), повторное нажатие — отказ.
local VK_SUBTRACT   = 0x6D   -- Alt + Numpad − — сторож на WATCH_STEPS секунд
local WATCH_STEPS   = 240
local WATCH_STEP_MS = 1000
local watching      = false  -- объявлено ВЫШЕ использования (EXP-0072)

local function snapshot()
    local pawn = local_pawn()
    if not pawn then return { pawn = "нет героя" } end
    local s = { pawn = "?" }
    pcall(function() s.pawn = pawn:GetFullName():match("([^%.]+)$") end)
    pcall(function() s.hp = ("%d/%d"):format(pawn:GetIntStat(1, 0), pawn:GetIntStat(0, 0)) end)
    pcall(function() s.st = ("%d/%d"):format(pawn:GetIntStat(5, 0), pawn:GetIntStat(6, 0)) end)
    pcall(function() s.t0 = ("%.3f"):format(pawn.EncumbranceTier0SpeedMultiplier) end)
    pcall(function() s.grav = ("%.3f"):format(pawn.GravityMultiplier) end)
    pcall(function()
        local cm = pawn.CharacterMovement
        s.jz = ("%.0f"):format(cm.JumpZVelocity)
        s.acc = ("%.0f/%.0f"):format(cm.MaxAcceleration, cm.BrakingDecelerationWalking)
        s.gs = ("%.3f"):format(cm.GravityScale)
        s.mode = tostring(cm.MovementMode)
    end)
    return s
end

local WATCH_KEYS = { "pawn", "hp", "st", "t0", "jz", "acc", "grav", "gs", "mode" }

local function watch_series()
    if watching then log("СТОРОЖ: уже идёт, нажатие пропущено"); return end
    watching = true
    local prev, i = nil, 0
    log("СТОРОЖ начат: %d шагов по %d мс, пишу только изменения", WATCH_STEPS, WATCH_STEP_MS)
    local function step()
        i = i + 1
        ExecuteInGameThread(function()
            pcall(function()
                local s = snapshot()
                local diff = {}
                for _, k in ipairs(WATCH_KEYS) do
                    local v = s[k] and tostring(s[k]) or "-"
                    if not prev or (prev[k] and tostring(prev[k]) or "-") ~= v then
                        diff[#diff + 1] = k .. "=" .. v
                    end
                end
                if #diff > 0 then log("СТОРОЖ %03d %s", i, table.concat(diff, " ")) end
                if i % 30 == 0 then log("СТОРОЖ %03d жив", i) end
                prev = s
            end)
            if i < WATCH_STEPS then
                ExecuteWithDelay(WATCH_STEP_MS, step)
            else
                watching = false
                log("СТОРОЖ конец")
            end
        end)
    end
    step()
end

RegisterKeyBind(VK_SUBTRACT, { ModifierKey.ALT }, function()
    local ok, err = pcall(watch_series)
    if not ok then watching = false; log("СТОРОЖ не стартовал: %s", tostring(err)) end
end)

RegisterKeyBind(VK_MULTIPLY, { ModifierKey.ALT }, function() ExecuteInGameThread(function()
    local ok, err = pcall(scale_movement, 2)
    if not ok then log("запись упала: %s", tostring(err)) end
end) end)

RegisterKeyBind(VK_DIVIDE, { ModifierKey.ALT }, function() ExecuteInGameThread(function()
    local ok, err = pcall(restore_movement)
    if not ok then log("возврат упал: %s", tostring(err)) end
end) end)

-- Старт от загрузки мода, не от NotifyOnNewObject: 12.09 23:37 подписка на
-- /Script/ConanSandbox.BasePlayerChar не вызвалась ни разу.
ExecuteWithDelay(AUTO_STEP_MS, auto_try)

RegisterKeyBind(VK_DECIMAL, { ModifierKey.ALT }, function() ExecuteInGameThread(function()
    pcall(read_attributes, "Alt+Numpad .")
    pcall(read_movement, "Alt+Numpad .")
end) end)

log("загружен. Alt+Numpad . — атрибуты и движение; Alt+* — бег и прыжок x2; Alt+/ — вернуть родные; Alt++ — серия замеров; Alt+− — сторож 4 мин.")
log("Ни одного вечного цикла и ни одного перехвата. Запись — только по * и / (бег — ступени перегруза).")
