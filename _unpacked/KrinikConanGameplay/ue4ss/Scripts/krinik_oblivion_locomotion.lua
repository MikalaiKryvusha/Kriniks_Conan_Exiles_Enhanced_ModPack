--[[============================================================================
  KrinikOblivionLocomotion — Проворство растит бег, спринт и прыжок, без потолка
  ============================================================================

  ЗАКАЗ ВЛАДЕЛЬЦА, дословно (13.09.2026 ~21:25, KUMM plans/08):
    «каждое очко Проворности будет давать +1 см/c к скорости бега и спринта
     и +1 см/c скорости взлёта, чуть-чуть больше времени в воздухе и чуть-чуть
     больше высоты подъёма».  Имя мода — слово владельца.

  ЗАКОН (одно место — раздел «ЗАКОН» ниже): n — Проворство героя, k — см/с за очко (1 → 5 → 3, слово
  владельца 13.09: сначала «+1», потом «чтобы там было на 100 очках проворства», потом «не +5, а +3»);
    бег 450 + k·n · спринт 773 + k·n · взлёт 420 + k·n см/с. Высота и время в воздухе
    следуют из взлёта сами (v²/2g, 2v/g). База измерена в игре 13.09 и совпала с
    таблицей DT_CharacterMovement (Front 450, Sprint 773, Back 325, Casual 150).

  РЫЧАГИ — все доказаны в игре зондом ConanAttributeProbe 13.09 (KUMM ideas/03):
    · бег: EncumbranceTier0..4SpeedMultiplier на герое — множитель поверх базы типа
      движения; проценты игры (голод 0.81, перк, замедления) ложатся сверху сами;
    · прыжок: пре-хук нативного Character:Jump ставит JumpZVelocity перед КАЖДЫМ
      прыжком — игра сбрасывает его литералом 420 при любом уроне;
    · урон от падения: пороги Min/Deadly(+Dive) на герое растут вместе с прыжком —
      свой прыжок не ранит, настоящий обрыв ранит соразмерно;
    · разгон: BP_ServerSettings_C.PlayerMovementAccelerationMultiplier, торможение:
      BrakingDecelerationWalking — растут вместе с бегом, иначе герой «плывёт».

  ⚠️ СПРИНТ. Рычаг бега — ОДИН множитель на все типы движения, поэтому спринт от
  него растёт как 773 × (450+n)/450 = 773 + 1.72·n, а не 773 + n. Ровно +n возможен,
  только если поймать пересчёт скорости: мод СЧИТАЕТ, срабатывает ли событие
  UpdateMaxMovementSpeed (EXP-0071: «хук встал» ≠ «хук работает»), и печатает счёт.
  Решение по спринту — после этого счёта (plans/08, Ш2).

  ПРАВИЛА, ОПЛАЧЕННЫЕ ПАДЕНИЯМИ ИГРЫ:
    · ОДИН медленный цикл (раз в секунду) на сессию; частые и накладывающиеся циклы
      роняли игру (EXP-0052, EXP-0062, баг UE4SS #1180);
    · ⛔ НЕ подхватывать правки через Ctrl+R: цикл нечем остановить, перезагрузка
      добавляет второй. Только перезапуск игры;
    · всё состояние объявлено ВЫШЕ использования (EXP-0051, EXP-0072), каждая
      ветка, которая должна сработать, печатает строку; перед раскаткой —
      python _config/lua-globals.py и luac -p.
============================================================================]]

local MOD_NAME = "KrinikConanGameplay:OblivionLocomotion"   -- до 2026-10-30 — отдельный мод KrinikOblivionLocomotion

-- ================================ ЗАКОН ================================
-- 13.09 ~21:25 было 1; 13.09 ~22:20 владелец проверил в игре: «на 500+ стало похоже на обливион.
-- Нужно подкрутить цифры, чтобы там было на 100 очках проворства» → 5 (на 100 очках то, что было на 500);
-- 13.09 ~22:30 владелец: «давай не +5, а +3 сделаем за очко» → 3.
local CM_PER_POINT   = 3      -- см/с за одно очко Проворства — слово владельца
local BASE_RUN       = 450    -- DT_CharacterMovement.Front.Speed = замер бега 13.09
local BASE_SPRINT    = 773    -- DT_CharacterMovement.Sprint.Speed = замер спринта 13.09
local BASE_JUMP      = 420    -- CDO JumpZVelocity = литерал SigilLongJumpDisable
local ATHLETICISM    = 19     -- ECharIntStatID по киту; сверено вживую 12.09 (все шесть атрибутов)
local STAT_FULL      = 0      -- EStatModifierMode: FULL — число с экрана «Хар-ки» (с бонусами)
local TICK_MS        = 1000   -- раз в секунду: читается одно целое число, пишется только при смене

local function run_mult(n)  return (BASE_RUN + CM_PER_POINT * n) / BASE_RUN end
-- Спринт: общий рычаг бега уже умножил его на run_mult, а нужно 773 + k·n. Остаток отдаётся
-- множителю спринта серверных настроек. [NOT-TESTED] применяет ли игра PlayerSprintSpeedScale:
-- в графах блюпринтов его нет (греп 13.09), значит, если применяет, то в C++. 13.09 ~22:20 владелец:
-- «на спринте ну очень быстро бегает, аж замного» — спринт шёл 773 × run_mult (на 532 очках 1 687
-- вместо 1 305). Проверка — строка «скорость сменилась» в журнале во время спринта.
-- ❌ ОПРОВЕРГНУТО 13.09 23:12: Проворство 2, бег лежит 410.4 (= 456 × 0.9), спринт вперёд 705.0 — отношение
-- 1.718, то есть пропорциональная ветка (773 × 1.0133 × 0.9 = 705.0); с поправкой было бы 701.1. Игра
-- PlayerSprintSpeedScale не применяет. Запись оставлена безвредной до замены рычага (KUMM plans/08).
local function sprint_fix(n) return (BASE_SPRINT + CM_PER_POINT * n) / (BASE_SPRINT * run_mult(n)) end
local function jump_z(n)    return BASE_JUMP + CM_PER_POINT * n end
local function jump_mult(n) return jump_z(n) / BASE_JUMP end

-- ============================== СОСТОЯНИЕ ==============================
-- Всё — здесь, выше функций, которые это читают (EXP-0072).
local TIER_VARS = {
    "EncumbranceTier0SpeedMultiplier", "EncumbranceTier1SpeedMultiplier",
    "EncumbranceTier2SpeedMultiplier", "EncumbranceTier3SpeedMultiplier",
    "EncumbranceTier4SpeedMultiplier",
}
local FALL_VARS = { "MinDamageVelocity", "DeadlyFallVelocity", "DiveMinDamageVelocity", "DiveDeadlyFallVelocity" }

local current_n     = nil    -- Проворство, под которое сейчас выставлены рычаги
local last_mws      = nil    -- последний прочитанный MaxWalkSpeed — пишется в журнал только при смене
local native_sprint = nil    -- родной PlayerSprintSpeedScale серверных настроек
local current_hero  = nil    -- полное имя объекта героя, к которому они выставлены
local native_hero   = nil    -- родные рычаги ЭТОГО объекта героя (новый герой — новые родные)
local native_server = nil    -- родной множитель разгона серверных настроек (общий, один раз)
local loop_started  = false
local counters = { jump = 0, jump_fixed = 0, update_speed = 0, apply_speed = 0, own_update = 0, hero_search = 0, hero_event = 0 }
-- 0.3.0, 2026-10-29 (KUMM plans/34, W16: опросы наших модов → события, слово владельца «да, но аккуратно … нужно будет ретестировать»):
-- раньше шаг раз в секунду звал FindAllOf("BasePlayerChar_C") по всей сцене и до трёх FindFirstOf("BP_ServerSettings_C").
-- Теперь герой и серверные настройки запоминаются; поиск по сцене — только когда пришло событие «появился новый герой»
-- (вход в мир, возрождение) или запомненный объект умер вместе с миром. Раз в секунду остаётся одно чтение Проворства у
-- запомненного героя: оно меняется и от вещей (режим FULL — с бонусами), а события смены атрибута игра наружу не даёт.
-- [NOT-TESTED]
local HERO_CLASS_PATH = "/Game/Characters/BasePlayerChar.BasePlayerChar_C"   -- BP-класс: срабатывал на героя после смерти (зонд 13.09); /Script-класс — нет
local hero_obj      = nil    -- запомненный живой герой
local need_find     = true   -- искать героя по сцене на ближайшем шаге (старт мода, событие появления)
local server_obj    = nil    -- запомненный BP_ServerSettings_C
-- Мод сам зовёт UpdateMaxMovementSpeed после записи. Без этого флага собственный вызов
-- засчитался бы как «пересчёт игры ловится» — опыт для спринта мерил бы сам себя.
local own_call = false

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, ok and s or tostring(fmt)))
end

-- Герой — по классу, живой (у тела после смерти здоровье 0). Способ из зонда, 13.09.
local function local_hero()
    local list = FindAllOf("BasePlayerChar_C")
    if not list then return nil end
    local first
    for _, p in ipairs(list) do
        if p and p:IsValid() then
            first = first or p
            local hp = 0
            pcall(function() hp = p:GetIntStat(1, 0) end)
            if hp > 0 then return p end
        end
    end
    return first
end

-- Серверные настройки — один поиск на мир: объект живёт, пока жив мир.
local function server_settings()
    if server_obj and server_obj:IsValid() then return server_obj end
    server_obj = nil
    local ss = FindFirstOf("BP_ServerSettings_C")
    if ss and ss:IsValid() then server_obj = ss end
    return server_obj
end

local function hero_alive(h)
    local hp = 0
    pcall(function() hp = h:GetIntStat(1, 0) end)
    return hp > 0
end

-- Герой из памяти; поиск по сцене — только по флагу need_find. Флаг гаснет, когда найден ЖИВОЙ герой (новый герой в первые
-- мгновения бывает с нулём здоровья — тогда ищем на следующем шаге), или когда в сцене героя нет вовсе (главное меню: ждём события).
local function cached_hero()
    if need_find then
        counters.hero_search = counters.hero_search + 1
        local h = local_hero()
        if h == nil then need_find = false; hero_obj = nil; return nil end
        hero_obj = h
        if hero_alive(h) then need_find = false end
        return hero_obj
    end
    if hero_obj and hero_obj:IsValid() then return hero_obj end
    hero_obj = nil
    return nil
end

local function read_agility(hero)
    local n
    pcall(function() n = hero:GetIntStat(ATHLETICISM, STAT_FULL) end)
    return n
end

-- ============================== ЗАПИСЬ ==============================
local function remember_native(hero, name)
    native_hero = { name = name, tiers = {}, fall = {} }
    for _, v in ipairs(TIER_VARS) do pcall(function() native_hero.tiers[v] = hero[v] end) end
    for _, v in ipairs(FALL_VARS) do pcall(function() native_hero.fall[v] = hero[v] end) end
    pcall(function() native_hero.brake = hero.CharacterMovement.BrakingDecelerationWalking end)
    if native_server == nil then
        pcall(function()
            local ss = server_settings()
            if ss then native_server = ss.PlayerMovementAccelerationMultiplier end
        end)
    end
    if native_sprint == nil then
        pcall(function()
            local ss = server_settings()
            if ss then native_sprint = ss.PlayerSprintSpeedScale end
        end)
        log("родной множитель спринта сервера: %s", tostring(native_sprint))
    end
    log("родные героя %s: T0=%s T4=%s Min=%s Deadly=%s торможение=%s · разгон сервера=%s",
        name, tostring(native_hero.tiers[TIER_VARS[1]]), tostring(native_hero.tiers[TIER_VARS[5]]),
        tostring(native_hero.fall.MinDamageVelocity), tostring(native_hero.fall.DeadlyFallVelocity),
        tostring(native_hero.brake), tostring(native_server))
end

local function apply(hero, n, reason)
    local rm, jm = run_mult(n), jump_mult(n)
    local bad = {}
    for _, v in ipairs(TIER_VARS) do
        local base = native_hero.tiers[v]
        if base then
            local ok, e = pcall(function() hero[v] = base * rm end)
            if not ok then bad[#bad + 1] = v .. ": " .. tostring(e) end
        end
    end
    for _, v in ipairs(FALL_VARS) do
        local base = native_hero.fall[v]
        if base then
            local ok, e = pcall(function() hero[v] = base * jm end)
            if not ok then bad[#bad + 1] = v .. ": " .. tostring(e) end
        end
    end
    local cm
    pcall(function() cm = hero.CharacterMovement end)
    if cm and native_hero.brake then pcall(function() cm.BrakingDecelerationWalking = native_hero.brake * rm end) end
    if cm then pcall(function() cm.JumpZVelocity = jump_z(n) end) end
    if native_server then
        pcall(function() server_settings().PlayerMovementAccelerationMultiplier = native_server * rm end)
    end
    if native_sprint then
        pcall(function() server_settings().PlayerSprintSpeedScale = native_sprint * sprint_fix(n) end)
    end
    own_call = true
    pcall(function() hero:UpdateMaxMovementSpeed() end)
    own_call = false
    local mws, jz = "?", "?"
    pcall(function() mws = ("%.1f"):format(cm.MaxWalkSpeed) end)
    pcall(function() jz = ("%.0f"):format(cm.JumpZVelocity) end)
    log("%s: Проворство %d → бег %d (x%.4f), спринт по закону %d, взлёт %d, высота %.2f м · лежит MaxWalkSpeed %s, JumpZ %s%s",
        reason, n, BASE_RUN + CM_PER_POINT * n, rm, BASE_SPRINT + CM_PER_POINT * n, jump_z(n), jump_z(n) ^ 2 / 1960 / 100, mws, jz,
        #bad == 0 and "" or (" · ОШИБКИ " .. table.concat(bad, "; ")))
end

-- Один шаг цикла: читает Проворство и объект героя; пишет ТОЛЬКО если что-то сменилось.
local function tick()
    local hero = cached_hero()
    if not hero then return end
    local name = "?"
    pcall(function() name = hero:GetFullName() end)
    local n = read_agility(hero)
    if n == nil then return end
    if name ~= current_hero then
        remember_native(hero, name)
        current_hero, current_n = name, n
        apply(hero, n, "герой появился")
    elseif n ~= current_n then
        local was = current_n
        current_n = n
        apply(hero, n, ("Проворство %d → %d"):format(was, n))
    end
    -- Наблюдение для спринта: итоговая скорость, какой её поставила игра, — только при смене.
    local mws
    pcall(function() mws = hero.CharacterMovement.MaxWalkSpeed end)
    if mws and (last_mws == nil or math.abs(mws - last_mws) > 0.5) then
        last_mws = mws
        log("скорость сменилась: MaxWalkSpeed %.1f · Проворство %d · по закону бег %d, спринт %d · множитель спринта %.4f",
            mws, n, BASE_RUN + CM_PER_POINT * n, BASE_SPRINT + CM_PER_POINT * n, sprint_fix(n))
    end
end

local function start_loop()
    if loop_started then return end
    loop_started = true
    if type(LoopInGameThreadWithDelay) == "function" then
        LoopInGameThreadWithDelay(TICK_MS, function() local ok, e = pcall(tick); if not ok then log("шаг упал: %s", tostring(e)) end end)
        log("цикл: штатный на игровом потоке, раз в %d мс", TICK_MS)
    else
        local function chain()
            ExecuteInGameThread(function() local ok, e = pcall(tick); if not ok then log("шаг упал: %s", tostring(e)) end end)
            ExecuteInGameThreadWithDelay(TICK_MS, chain)
        end
        chain()
        log("цикл: цепочка, раз в %d мс (штатного в этой сборке нет)", TICK_MS)
    end
end

-- ============================== ПРЫЖОК ==============================
-- Пре-хук нативного Character:Jump: зовут и NPC — пишем только герою.
local function on_jump(ctx)
    local ch = ctx:get()
    if not ch:GetFullName():find("BasePlayerChar_C", 1, true) then return end
    counters.jump = counters.jump + 1
    if current_n == nil then return end
    local cm = ch.CharacterMovement
    local want = jump_z(current_n)
    if math.abs(cm.JumpZVelocity - want) > 0.5 then
        cm.JumpZVelocity = want
        counters.jump_fixed = counters.jump_fixed + 1
    end
end

local jump_hook_ok = pcall(function()
    RegisterHook("/Script/Engine.Character:Jump", function(ctx)
        local ok, e = pcall(on_jump, ctx)
        if not ok then log("прыжок: хук упал: %s", tostring(e)) end
    end)
end)
log("перехват Character:Jump %s", jump_hook_ok and "встал" or "НЕ встал")

-- ============== ОПЫТ ДЛЯ СПРИНТА: ловит ли UE4SS пересчёт скорости ==============
-- Только счёт, никакой записи. Если счёт растёт при старте и остановке бега и спринта —
-- спринт можно сделать ровно +n правкой итоговой скорости после пересчёта.
for key, path in pairs({
    update_speed = "/Script/ConanSandbox.ConanCharacter:UpdateMaxMovementSpeed",
    apply_speed  = "/Script/ConanSandbox.ConanCharacter:ApplyNewMovementSpeed",
}) do
    local ok, e = pcall(function()
        RegisterHook(path, function()
            if own_call then counters.own_update = counters.own_update + 1 else counters[key] = counters[key] + 1 end
        end)
    end)
    log("счётчик %s: %s", path, ok and "встал" or ("НЕ встал: " .. tostring(e)))
end

-- Отчёт о счётчиках раз в минуту, 10 раз, и тишина: конечная цепочка (EXP-0052).
local REPORTS, REPORT_MS = 10, 60000
local report_i = 0
local function report()
    report_i = report_i + 1
    log("СЧЁТ #%d: прыжков героя %d (поправлено %d) · игра звала UpdateMaxMovementSpeed %d, ApplyNewMovementSpeed %d · свои вызовы %d · Проворство %s · событий «новый герой» %d, поисков героя по сцене %d",
        report_i, counters.jump, counters.jump_fixed, counters.update_speed, counters.apply_speed, counters.own_update, tostring(current_n),
        counters.hero_event, counters.hero_search)
    if report_i < REPORTS then ExecuteInGameThreadWithDelay(REPORT_MS, report) end
end

-- ============================== СТАРТ ==============================
-- Цикл заводится сразу: шаг сам молчит, пока героя нет, и сам поймёт нового героя
-- после смерти или загрузки (другое полное имя объекта) — по событию появления, без поиска по сцене каждую секунду.
local notify_ok, notify_err = pcall(function()
    NotifyOnNewObject(HERO_CLASS_PATH, function()
        counters.hero_event = counters.hero_event + 1
        need_find = true
    end)
end)
log("событие «новый герой» (%s): %s", HERO_CLASS_PATH, notify_ok and "подписано" or ("НЕ подписано: " .. tostring(notify_err)))
start_loop()
ExecuteInGameThreadWithDelay(REPORT_MS, report)
log("загружен 0.3.0 (герой по событию, без поиска по сцене каждую секунду). Закон: +%d см/с за очко Проворства к бегу, спринту и взлёту. Правки — только перезапуском игры.", CM_PER_POINT)
