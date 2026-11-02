--[==[===========================================================================
  KrinikConanArchery 0.9.0 — лук героя: стрела из лука в точку прицела, вид стрелы и прицела
  (до 2026-10-28 — KrinikArrowAim; `[OWNER]` «мод KrinikConanAim переименовываем в KrinikConanArchery» · 2026-10-28 20:39)
  KUMM план 36 п. 32, 35–37. 0.3.0 — схема владельца 2026-10-27 18:4x:
  `[OWNER]` «из камеры по линии прицела в момент выстрела пускаем луч щуп -
  получаем точку, на которую смотрит прицел» · «стрелу спавним в точке привязки
  к луку» · «рисуем стрелу честно вылетом из лука без перехватаа, но траекторию
  выпуска стрелы делаем лучм так, чтобы стрела выпускалась ровно в ту же точку,
  в которую попал луч щуп камеры» · «стрелу не скрываем на начале полета».
  Прежний путь 0.1–0.2 (стрела переносилась на линию камеры и пряталась первые
  3 м — «стерла появляется на 3 метрах - не красиво») — в истории git пака.
  Выключить — убрать enabled.txt.
  ============================================================================

  ЧТО ДЕЛАЕТ — на каждой стреле героя, одним событием:
   1. Луч-щуп из камеры через прицел (канал видимости, 100 м) — точка, куда
      смотрит прицел; не попал ни во что — точка в конце луча.
   2. Стрела остаётся там, где её родила игра, — у лука; её скорость
      направляется прямой линией из этой точки в точку щупа. Баллистику не
      считаем и вектор не поднимаем: `[OWNER]` «балистику свавнер не считает,
      поднимать иссуственно вектор выпуска стрелы не нужно» · «это
      ответственность игрока - брать поправку на баллистику». Родной подъём
      игры (0.0675 × (1 − 0.72 × заряд)) снимаем — это и есть искусственный
      подъём.
   3. Разброс игры (движение, стат точности, ездовой, перки) сохраняется: те же
      углы вбок и вверх, что игра дала относительно взгляда, переносятся на
      линию «лук → точка» (вариант Б владельца: «вернёт в игру всё
      перечисленное»).
   4. Стрела не ломается при ударе (родной шанс 0.65): «стрелы не втыкаются
      и исчезают, бесит». Тело стрелы ×3 (`[OWNER]` «можешь увеличить стрелу
      до x3?»). Видна с первого кадра.
  Раз за запуск, на первом выстреле (точными значениями — повторяемо):
   5. След стрелы: прозрачность 0.35, ширина 0.1 от родной, без сноса
      частиц, без колец «звукового барьера» (п. 35, 37).
   6. Полоски разброса у точки прицела скрыты: «полоски мешают, путают».

  ЧЕГО НЕ ДЕЛАЕТ: обзор камеры после выстрела не держит (п. 34, EXP-0349).

  ЦЕНА. Ни опроса, ни поиска по сцене: событие появления снаряда, камера — у
  контроллера стрелявшего, один луч на выстрел. Свой замер — сводка раз в
  минуту, если стрелы были. Загружает только UE4SS (Mods/). Пультом НЕ
  подгружать: вторая копия в отдельном Lua-окружении удваивает обработку
  (стрела ×9, EXP-0348).

  [NOT-TESTED] — 0.3.0 целиком; проверки — кейсы AIM11–AIM15 по журналу.
===========================================================================]==]

-- ------------------------------------------------------------------ настройки
-- У каждого числа — источник: слово владельца или замер (карта игры Конана).
local CFG = {
    arrow_classes   = { "Bow", "Crossbow" },  -- лук и арбалет героя; метательное и магия — не трогаем
    lift_k          = 0.0675,  -- родной подъём: 0.0675 × CrosshairOffsetMod (байткод GetProjectileDirection)
    lift_charge_k   = 0.72,    -- CrosshairOffsetMod ≈ 1 − 0.72 × заряд (замер 22:32–22:55, остаток −0.08° при заряде 0.60)
    probe_cm        = 10000.0, -- длина щупа: столько же у выключенной родной ветки сведения (инструкция 178)
    min_aim_cm      = 100.0,   -- точка ближе к луку — стена в упор: летим по взгляду камеры, а не вбок
    max_from_cam_cm = 2500.0,  -- стрела родилась дальше от камеры — не наш выстрел; штанга мода камеры — до 2125 см (раскладка B)
    no_break        = true,    -- «бесит»: родной шанс поломки 0.65
    -- Был 3.0 («до x3», заметность в полёте): по границам увеличенной сетки игра ставила воткнутую копию на 1,2 м дальше от точки удара —
    -- стрела висела в воздухе (KUMM bugs/73, 2026-11-01). [AI] 1.0 — до слова владельца: крупная стрела в полёте — его вкус, вопрос задан.
    mesh_scale      = 1.0,
    -- Крупная стрела в полёте — по схеме владельца (`[OWNER]` 2026-11-01 16:23 «лететь в воздухе должна физическая оригинальная стрела x1 размера, а
    -- визуальная модель лететь должна x3. Физическая стрела и визуальная модель сввввввввввввввввязаны в наккооооооооооооооооонечникееееееее»): ниже, dress_arrow.
    visual_scale    = 3.0,
    trail_opacity   = 0.35,    -- «тоньше, но заметнее»; родное начало кривой FadeTrail — 1.0
    trail_width     = 0.1,     -- «сделай трассер 0.1»; родная ширина ленты — 10
    log_shots       = 10,      -- сколько первых выстрелов писать в журнал строкой
    check_landing   = true,    -- первые log_shots стрел: где встала стрела против точки щупа (кейс AIM12)
    -- п. 34: удержание прицела ВЫКЛЮЧЕНО 2026-10-27 20:2x — у владельца камера плясала и залипала (EXP-0349, EXP-0353); FieldOfViewReset
    -- откатывает к предыдущей цели, а не к обычному обзору. Причина отъезда — данные монтажа натяжки (EaseOut 0,1 уведомления обзора),
    -- чинится правкой монтажа, не перехватом.
    keep_aim        = false,
    release_poll_ms = 100,     -- как часто, ТОЛЬКО пока мод держит прицел после выстрела, проверяем отпускание ПКМ
    release_fov_s   = 0.1,     -- переход к обычному обзору по отпусканию ПКМ после выстрела — как родной FieldOfViewChangeDuration
    -- п. 43: от первого лица в прицельной стойке камера — над стрелой (`[OWNER]` «камеру нужно помещать над стрелой» · «её нужно перемещать
    -- ТОЛЬКО на прицельную стойку» · «левее» · 2026-10-27 20:0x). Сдвиг штанги FirstPersonCameraArm.SocketOffset: назад, вправо, вверх, см.
    -- Замер позы натяжки 20:05: хвост стрелы (правая рука) — вперёд 8, вправо 26, вниз 10 от камеры; лук — вперёд 82, вправо 22, вниз 15.
    fp_aim_offset   = { X = -5.0, Y = 16.0, Z = 6.0 },
    -- Натяжка БЕЗ ПКМ от первого лица — свой сдвиг: `[OWNER]` «может в обычной стрельбе нужно сильнее правее двигать» · 2026-10-28 19:0x.
    -- [AI] вправо 24 (×1,5 от прикладки) — число до первого взгляда владельца. Вверх 11: поза выстрела опускает голову, а с ней камеру
    -- первого лица, на 10–11 см (замер D1 2026-10-28: покой 73,9 см над героем, поза 63,0–63,6), а `[OWNER]` «ниже опускать не нужно, только
    -- чуть правее двигать от idle состояния» · 2026-10-28 ≈20:10. С Z 11 камера в позе — на высоте покоя.
    fp_hip_offset   = { X = -5.0, Y = 24.0, Z = 11.0 },
    -- подъём по высоте при натяжке без ПКМ — сразу: поза опускает голову за ≈70 мс раньше, чем приходит сигнал «стрела на тетиве», и при
    -- 100 мс первый выстрел серии всё же проваливался на 5,4 см (кейс D2 2026-10-28); вправо — плавно, fp_shift_ms
    fp_hip_z_ms     = 1,
    fp_hip_hold_ms  = 700,     -- после выстрела без ПКМ сдвиг держим столько; новый выстрел раньше — сдвиг не уходит (частая стрельба D1)
    -- Новое натяжение с зажатой ПКМ: монтаж перезапускается, уведомление обзора старого кончается (цель 0) раньше, чем начнётся новое (цель
    -- 1), и за кадр между ними обзор отъезжает 75° → 80,8° (кейс J1 2026-10-28) — `[OWNER]` «камера все еще дергается при последовательных
    -- выстрел в ПКМ прикладке от третьего лица при начале нового натяжения» · 2026-10-28 ≈20:12. Цель 0 при зажатой ПКМ сразу после прицела
    -- переписываем обратно на прицел в том же перехвате, до тика контроллера.
    hold_aim_on_redraw = true,
    -- `[OWNER]` «Камеру при прикладке от перового лица нужно двигать не резко, а плавно, условно, за 500 мс в позицию прикладки, и за 500 мс -
    -- возврат к обычной после прикладки» · 2026-10-28
    fp_shift_ms     = 500,
    fp_shift_step_ms = 16,     -- шаг перехода ≈ кадр; шаги идут только во время самого перехода
    -- `[OWNER]` «В первом лице приближение камеры при прикладке делать не таким сильным, но немножко делать» · 2026-10-28. Игра даёт прицелу
    -- обычный обзор ×0,5 (`SetFieldOfViewTarget`, байткод 3.0.1: 107,5° → 53,75°) в обоих видах; мод ставит aim_fov_deg градусов в обоих.
    -- Владелец на пробе 2026-10-28 18:5x: «зум от первого лица в прикладке сделай 75» (было [AI] ×0,8 → 86°) · «от третьего лица тоже зум
    -- в прикладке 75».
    aim_fov_deg     = 75.0,
    arrow_len_cm    = 76.0,    -- длина сетки, если границы StaticMeshToShow не прочлись (SM_basic_wood_arrow 76,4 см по Z)
    glint_scale     = 1.5,     -- п. 38: «по радиусу эффекта нужно на 50 процентов больше»
    -- W15 (0.4.0): баллистика Oblivion Remastered — натяжка задаёт СКОРОСТЬ при постоянной гравитации; минимум скорости повыше обливионовского
    -- (`[OWNER]` «баллистика стрел Oblivion Remastered с повышенным минимумом минимальной скорости скорости» · 2026-10-30 08:33; ранее
    -- «для мгновенных выстрелов в конане нужно будет какой-то винимум поставить. не такой мелкий, как в обливионе» · 2026-10-28). Числа —
    -- KUMM researches/conan-archery/README.md: ArrowGravityScale 0,55 (DefaultAltar.ini Remastered); доля скорости = min + (1 − min) × заряд;
    -- min — кандидаты 0,4 / 0,5 / 0,6, выбор его глазом; [AI] 0,5 до его взгляда. Обливион — 0,25 (fArrowBowTimerBase).
    ballistics      = true,
    arrow_gravity   = 0.55,
    min_speed_share = 0.5,
    grav_reapply_ms = {},  -- пусто: повтор через 40 и 150 мс не помог (прогон 09:44) — блюпринт стрелы ставит гравитацию КАЖДЫЙ тик; лечить нативно
    -- 0.6.0: тиковый пересчёт снимается в корне. Байткод ExecuteUbergraph_BP_BaseProjectile 3.0.1 (kismet-trace 2026-10-30): каждый тик
    -- ЕСЛИ IsValid(ProjectileGravityCurve) — ProjectileGravityScale = Кривая(время) × (1 − PowerChargeGravityModMax × PowerChargeMod).
    -- Кривые лука постоянные: FC_BowProjectileGravCurve_15m 1,2 · _30m 1,0 · _45m 0,8 (класс дальности лука). Кривую назначает оружие
    -- событием интерфейса при рождении стрелы — за ≈1 с до вылета, то есть ДО нашего обработчика; сняв её на вылете, мы оставляем тик без
    -- пересчёта, и наша постоянная гравитация держится. Ноль процессора: одна запись на стрелу, без опроса.
    drop_grav_curve = true,
    summary_s       = 60.0,
    -- 1.0.0: стрелы остаются в трупе (`[OWNER]` 2026-11-01 09:11, ниже раздел «стрелы в трупе»)
    keep_in_corpse      = true,
    corpse_find_ms      = 150,     -- труп рождается рядом со смертью: ищем его после уборки существа
    corpse_radius_cm    = 400,     -- копия дальше этого от трупа — не его стрела
    corpse_arrow_life_s = 900,     -- срок копии в трупе, когда у трупа нет своего срока ([AI] 15 мин)
    -- Срок воткнутой стрелы (`[OWNER]` 2026-11-01 16:18 «срок жизни стрел везде, и в земле, и в трупах, и в стенах нужжжжжжжжжен 5 минут - с возможностью
    -- настроить в модах стрельбы из лука - в минутах, от 1, до 30»): игра даёт копии BP_DummyProjectile срок из полей летящей стрелы
    -- DummyProjectileOnGroundLifetime (родное 30 с) и DummyProjectileAttachedToCharacterLifetime (15 с). Ставим оба стреле героя при вылете — копию
    -- игра ставит и убирает сама. Шкала хаба arc_stuck_min.
    stuck_life_min      = 5,
    -- Список выбора стрел мода Arrow Quick Swap при натяжении (`[OWNER]` 2026-11-02 12:54–12:56 «если есть из чего выбирать - показывается, если не из чего
    -- выбирать - не показывается» · «если выключена - то он никогда не показывается, даже не мерцает ни чуть-чуть»): шкала хаба arc_ammo_list.
    ammo_list           = true,
}

local TAG = "[KrinikConanArchery] "
local PROJECTILE_CLASS = "/Script/Engine.ProjectileMovementComponent"
local MESH_CLASS = "/Script/Engine.StaticMeshComponent"
local KSL = "/Script/Engine.Default__KismetSystemLibrary"
local TRACE_VISIBILITY = 0     -- ETraceTypeQuery::TraceTypeQuery1 — канал видимости, как у облёта KrinikConanBench
local FADE_CURVE = "/Game/Items/Weapons/Bow/BP_Visual_BowProjectileBase.BP_Visual_BowProjectileBase_C:CurveFloat_1"
local CROSSHAIR_ALPHA = "/Game/UI/Data/Curves/C_CrosshairAccuracyAlpha.C_CrosshairAccuracyAlpha"
local RINGS_MATERIAL = "M_particle_powershot_circles"
local NATIVE_FADE_START, NATIVE_RIBBON_WIDTH = 1.0, 10.0
local ZERO_DRIFT = { ParticleModuleVelocity_0 = "StartVelocity", ParticleModuleLocationPrimitiveSphere_0 = "StartRadius" }
-- Одна таблица результата на все лучи (утечка UE4SS < 1181, тот же приём в KrinikConanBench).
local HIT, NOCOLOR = {}, { R = 0, G = 0, B = 0, A = 0 }

local shots, templates_done = 0, false
local stat_n, stat_sum, stat_worst, stat_since = 0, 0.0, 0.0, os.clock()

local function log(fmt, ...) print(TAG .. fmt:format(...) .. "\n") end

-- Страница «KrinikConanArchery» окна «Моды Krinik'а» (KUMM план 38 этап 2; образец — KrinikConanGraphics): общее хранилище
-- <игра>\ConanSandbox\Saved\KrinikSettings.lua, ключи arc_ballistics → CFG.ballistics, arc_nobreak → CFG.no_break, arc_fov → CFG.aim_fov_deg,
-- arc_stuck_min → CFG.stuck_life_min (2026-11-01)
-- (нет ключа — свои значения ниже). Читается при загрузке и при смене общего номера KrinikSettingsVersion — сверка на каждой стреле и прицеле,
-- в те же моменты, когда эти значения и читаются; своего таймера нет. [NOT-TESTED]
local ARC_DEFAULTS = { ballistics = CFG.ballistics, no_break = CFG.no_break, aim_fov_deg = CFG.aim_fov_deg, stuck_life_min = CFG.stuck_life_min,
    ammo_list = CFG.ammo_list }
local ARC_KEYS = { arc_ballistics = "ballistics", arc_nobreak = "no_break", arc_fov = "aim_fov_deg", arc_stuck_min = "stuck_life_min",
    arc_ammo_list = "ammo_list" }
local ARC_SRC = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/", "\\")
local ARC_STORE = (ARC_SRC:match("^(.*)\\ConanSandbox\\Binaries\\") or "") .. "\\ConanSandbox\\Saved\\KrinikSettings.lua"
local arc_seen_version = nil

local function arc_read_store(why)
    local t = {}
    local chunk = loadfile(ARC_STORE)
    if chunk then
        local ok, r = pcall(chunk)
        if ok and type(r) == "table" then t = r end
    end
    for key, field in pairs(ARC_KEYS) do
        local v = t[key]
        if v == nil then CFG[field] = ARC_DEFAULTS[field] else CFG[field] = v end
    end
    log("настройки окна: баллистика %s, стрелы не ломаются %s, обзор %.0f°, стрела торчит %.0f мин (%s)", tostring(CFG.ballistics), tostring(CFG.no_break),
        CFG.aim_fov_deg, CFG.stuck_life_min, why)
end

local function arc_settings_check()
    local ok, v = pcall(function() return ModRef:GetSharedVariable("KrinikSettingsVersion") end)
    if ok and v ~= nil and v ~= arc_seen_version then
        arc_seen_version = v
        arc_read_store("номер настроек " .. tostring(v))
    end
end
arc_read_store("загрузка")
local function add(a, b) return { X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z } end
local function sub(a, b) return { X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z } end
local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
local function scaled(v, k) return { X = v.X * k, Y = v.Y * k, Z = v.Z * k } end
local function unit(v) return scaled(v, 1.0 / math.sqrt(dot(v, v))) end

-- Базис направления: вперёд, вправо (горизонтально), вверх — как у камеры (приборы bow-socket-offset.sh, arrow-offset.sh).
local function basis(f)
    local r = unit({ X = -f.Y, Y = f.X, Z = 0.0 })
    local u = { X = f.Y * r.Z - f.Z * r.Y, Y = f.Z * r.X - f.X * r.Z, Z = f.X * r.Y - f.Y * r.X }
    if u.Z < 0 then u = scaled(u, -1) end
    return f, r, u
end

local function view_forward(rot)
    local cp, sp = math.cos(math.rad(rot.Pitch)), math.sin(math.rad(rot.Pitch))
    return { X = cp * math.cos(math.rad(rot.Yaw)), Y = cp * math.sin(math.rad(rot.Yaw)), Z = sp }
end

local function is_arrow(actor)
    local cn = actor:GetClass():GetFName():ToString()
    for _, p in ipairs(CFG.arrow_classes) do
        if cn:find(p, 1, true) then return true end
    end
    return false
end

-- Без родного подъёма: игра даёт dir = Normal(W + (0,0,L)), W — единичный взгляд с разбросом. Ищем W: |k·dir − L·z| = 1.
local function strip_lift(dir, charge)
    local L = CFG.lift_k * math.max(0.0, 1.0 - CFG.lift_charge_k * charge)
    local k = L * dir.Z + math.sqrt(math.max(0.0, 1.0 - L * L + L * L * dir.Z * dir.Z))
    local w = { X = k * dir.X, Y = k * dir.Y, Z = k * dir.Z - L }
    return unit(w), L
end

-- Щуп: по взгляду камеры через прицел. Начало — точка луча напротив лука, а не сама камера: мод камеры уводит её далеко за
-- спину (раскладка B, штанга до 21 м — `[OWNER]` «мод камеры может её сильно сдвигать, учитывай это» · 2026-10-27 19:0x), и
-- дерево или стена между камерой и героем дали бы точку позади лука. Возвращает точку и что задели (имя или «небо»).
-- Луч — каналом видимости: он попадает в ТЕЛО моба (`CharacterMesh0`), а канал самой стрелы (ch5) видит только капсулу
-- столкновений (`CollisionCylinder`, у детёныша каппы радиус 49 см) — замер пультом 2026-10-27 19:1x. Профиль стрелы («Custom»)
-- мобов не видел вовсе: щуп прошёл сквозь каппу в землю. `[OWNER]` «и луч щуп должен уметь точку на мобов строить» · 2026-10-27.
local function trace(pawn, actor, a, b)
    return StaticFindObject(KSL):LineTraceSingle(pawn, a, b, TRACE_VISIBILITY, false, { pawn, actor }, 0, HIT, true, NOCOLOR,
        NOCOLOR, 0.0)
end

local function probe(pawn, actor, cam, f, from)
    local start = add(cam, scaled(f, math.max(0.0, dot(sub(from, cam), f))))
    local far = add(cam, scaled(f, CFG.probe_cm))
    local hit = trace(pawn, actor, start, far)
    if not hit then return far, "небо" end
    local p = HIT.ImpactPoint
    local who = "?"
    pcall(function() who = HIT.HitObjectHandle.ReferenceObject:Get():GetFName():ToString() end)
    return { X = p.X, Y = p.Y, Z = p.Z }, who
end

-- -------------------------------------------- шаблоны: раз за запуск, точно
local function for_each_module(tpl, fn)
    tpl.Emitters:ForEach(function(_, em)
        em:get().LODLevels:ForEach(function(_, lv)
            local lod = lv:get()
            fn(lod, nil)
            lod.Modules:ForEach(function(_, mo) fn(lod, mo:get()) end)
        end)
    end)
end

-- Полоски разброса у точки прицела (п. 6 шапки) — прозрачность кривой C_CrosshairAccuracyAlpha в ноль. Раньше — только на первой стреле
-- запуска, и до первого выстрела полоски были видны (владелец 2026-10-28 18:5x: «а как ты так мод сделал. что полоски разброса вернулись?» —
-- он целился, не стреляя). Теперь — и на первом входе в прицел (кривая уже загружена: прицел на экране); повтор безвреден.
-- И на КАЖДОМ входе в прицел: обнулённые один раз полоски возвращались (`[OWNER]` «линии разброса у прицела вернулись - в моде арчери криника -
-- убрать их» · 2026-10-28 22:59) — похоже, игра выгружает кривую и грузит её заново с родными ключами. Сколько ключей пришлось обнулить снова —
-- в журнал (reloads), чтобы причина была видна. [NOT-TESTED]
local bars_done = false
local bars_reloads = 0
local function hide_bars()
    local bars = StaticFindObject(CROSSHAIR_ALPHA)
    if not bars or not bars:IsValid() then return false end
    local nonzero = 0
    bars.FloatCurve.Keys:ForEach(function(_, k)
        local key = k:get()
        if key.Value ~= 0.0 then nonzero = nonzero + 1; key.Value = 0.0 end
    end)
    if bars_done and nonzero > 0 then
        bars_reloads = bars_reloads + 1
        if bars_reloads <= CFG.log_shots then log("полоски прицела вернулись (%d ключ.) — обнулены снова (%d)", nonzero, bars_reloads) end
    end
    bars_done = true
    return true
end

-- Строка «Ударная волна полного заряда» и её код (tune_wave) убраны 2026-11-02 по ответу владельца в интервью #031 (A: «убрать строку,
-- пока спрайт не найден. Найдётся — вернём её уже к нему»): P_bow_powercharge_release на экране не рисует ничего. Код — в истории git (пак a848a58).

local function tune_templates(actor)
    templates_done = true
    local tpl = actor.TracerParticleSystem.Template
    local seen, report = {}, {}
    for_each_module(tpl, function(lod, mod)
        if not mod then
            local mat = lod.RequiredModule.Material
            if mat and mat:IsValid() and mat:GetFName():ToString():find(RINGS_MATERIAL, 1, true) then
                lod.bEnabled = false
                report[#report + 1] = "кольца выкл"
            end
            return
        end
        if seen[mod:GetAddress()] then return end
        seen[mod:GetAddress()] = true
        local name = mod:GetFName():ToString()
        if ZERO_DRIFT[name] then
            mod[ZERO_DRIFT[name]].Table.Values:ForEach(function(_, v) v:set(0.0) end)
        elseif name == "ParticleModuleSize_0" then
            mod.StartSize.Table.Values:ForEach(function(_, v)
                if v:get() > 0 then v:set(NATIVE_RIBBON_WIDTH * CFG.trail_width) end
            end)
        end
    end)
    local fade = StaticFindObject(FADE_CURVE)
    if fade and fade:IsValid() then
        fade.FloatCurve.Keys:ForEach(function(_, k)
            local key = k:get()
            if key.Value > 0 then key.Value = NATIVE_FADE_START * CFG.trail_opacity end
        end)
    end
    log("шаблоны: %s, след %.2f / ширина %.2f, снос 0, полоски прицела %s", table.concat(report, ", "),
        CFG.trail_opacity, CFG.trail_width, hide_bars() and "скрыты" or "НЕ найдены")
end

-- ------------------------------------------- воткнутая стрела: игра ставит копию сама, по РОДНОМУ размеру стрелы
-- Стрела «в воздухе» перед мордой каппы (план 36 п. 42, 2026-10-27) и над песком (`[OWNER]` 2026-11-01 15:06 «стрелы висят в воздухе») — НАША
-- ошибка, не игры (KUMM bugs/73). Контроль 2026-11-01 15:08 (Lua мода выключен): копия BP_DummyProjectile стоит в 62 см от точки удара — наконечник
-- в песке. С модом — 187 см; без нашей баллистики — те же 187; с mesh_scale 1 — снова 62 (15:13). Байткод BP_BaseProjectile:
-- SpawnDummyProjectile → GetAdjustedProjectileImpactPosition отступает от точки удара назад по ходу стрелы на величину из GetComponentBounds(ProjectileMesh),
-- а dress_arrow растил ProjectileMesh ×3 («до x3»). До 2026-11-01 это лечилось досылом копии после её рождения (числа под каппу, бедро, песок —
-- костыль, HOUSE_RULES правило 24) — досыл удалён. Вернуть сетке родной размер в пре-перехвате SpawnDummyProjectile не помогло (15:16–15:21:
-- перехват срабатывал, масштаб 1.00, а копия всё равно в 187 см — границы берутся не в этот миг). Поэтому mesh_scale = 1: стрела родного
-- размера, копию игра ставит сама. [TESTED: см. KUMM testcases/TC_conan_hub_rows_audit_2026-11-01.md, раздел «bug 73»]
local DUMMY_CLASS = "/Game/Items/Weapons/BP_DummyProjectile.BP_DummyProjectile_C"
local dummies_seen = 0
local copy_errors = 0
-- Стрела, которая УБИЛА: труп рождается раньше её копии (кейс A10, 2026-11-01 23:16 — «копий 0» при рождении трупа, стрела ушла с существом).
-- Раздел «стрелы в трупе» ниже запоминает последний труп; копия, рождённая в первые CORPSE_LATE_S после него, проходит ту же отвязку и перенос.
local CORPSE_LATE_S = 2.0
local last_corpse, last_corpse_t = nil, -1e9
local on_corpse_born                      -- объявлена ниже, в разделе «стрелы в трупе»

-- Журнал первых копий: где игра поставила копию относительно точки удара (родная стрела — ≈ 62 см: копия считается от хвоста).
NotifyOnNewObject(DUMMY_CLASS, function(dummy)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(100, function()
            if on_corpse_born and last_corpse and os.clock() - last_corpse_t < CORPSE_LATE_S then
                local okc, errc = pcall(on_corpse_born, last_corpse)   -- [NOT-TESTED] кейс A10
                if not okc and copy_errors < 5 then copy_errors = copy_errors + 1; log("ошибка поздней стрелы в трупе: %s", tostring(errc)) end
            end
            local ok, err = pcall(function()
                if not dummy:IsValid() or dummies_seen >= CFG.log_shots then return end
                dummies_seen = dummies_seen + 1
                local cap = dummy.HitResultFromProjectile.Component:Get()
                local a = dummy:K2_GetActorLocation()
                local ax, ay, az = a.X, a.Y, a.Z
                local i = dummy.HitResultFromProjectile.ImpactPoint
                local ix, iy, iz = i.X, i.Y, i.Z
                log("копия стрелы #%d: удар в %s, кость %s, от точки удара %.0f см, срок %.1f с", dummies_seen,
                    (cap and cap:IsValid()) and cap:GetFName():ToString() or "ничто", dummy.HitResultFromProjectile.BoneName:ToString(),
                    math.sqrt((ax - ix) ^ 2 + (ay - iy) ^ 2 + (az - iz) ^ 2), dummy:GetLifeSpan())
            end)
            if not ok and copy_errors < 5 then copy_errors = copy_errors + 1; log("ошибка журнала копий: %s", tostring(err)) end
        end)
    end)
end)

-- ------------------------------------------------------------ вид стрелы
-- Видимая стрела ×CFG.visual_scale поверх физической ×1, наконечник к наконечнику (схема владельца 16:23, bugs/73). Родная ProjectileMesh остаётся
-- ×1 — по её границам игра ставит воткнутую копию (GetAdjustedProjectileImpactPosition), — и прячется только для отрисовки. Своя сетка — родным
-- AddComponentByClass актёра (без столкновений), прицеплена к ProjectileMesh: локальная ось Z сетки стрелы идёт от хвоста (0) к наконечнику (max Z,
-- ≈ 76 см — конспект мода), поэтому при масштабе s сдвиг вдоль Z = maxZ × (1 − s): наконечники совпадают, крупное древко уходит назад.
-- Работа — один раз на выстрел героя, в том же вызове, что и остальной вид стрелы. [NOT-TESTED]
local ATTACH_SNAP, ATTACH_KEEP_RELATIVE = 2, 0   -- EAttachmentRule: SnapToTarget, KeepRelative
local IDENTITY = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 }, Translation = { X = 0.0, Y = 0.0, Z = 0.0 }, Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
local visual_errors = 0
local visual_logged = false
local ARROW_TIP_FALLBACK_CM = 76.0   -- SM_basic_wood_arrow: Z −0.3…76.1 (зонд кита 2026-10-31, конспект мода)
-- Крупная стрела гаснет В МИГ УДАРА (`[OWNER]` 2026-11-01 21:07 «когда стрела попадает в землю - наша x3 отображается долго вместе с настоящей x1» ·
-- «нашу x3 мгновенно нужно скрывать, когда происходит слолкновение, и показывать только настоящую x1»). Причина: после удара игра держит летевший
-- актёр живым ради угасания следа, а наша сетка — его отдельный компонент. Событие игры — остановка снаряда (BP_BaseProjectile.StopProjectileInternal,
-- и при попадании, и при поломке стрелы): по нему своя сетка прячется; реестр «актёр → своя сетка» — по адресу актёра, запись живёт до остановки.
-- [TESTED: 2026-11-01 21:13 · владелец: земля, камни, враги · KUMM testcases/reports/2026-11-01_conan-arrow-x3-hidden-at-impact.md]
local STOP_FUNC = "/Game/Items/Weapons/BP_BaseProjectile.BP_BaseProjectile_C:StopProjectileInternal"
local VISUALS_CAP = 64                -- стрел в полёте одновременно куда меньше; переполнение = актёры, ушедшие без остановки, — реестр чистится целиком
local visuals, visuals_n, stop_hooked = {}, 0, false
local function hook_stop()
    stop_hooked = true
    local ok, err = pcall(RegisterHook, STOP_FUNC, function(ctx)
        local a = ctx:get()
        local key = a and a:IsValid() and a:GetAddress()
        local vis = key and visuals[key]
        if vis then
            visuals[key] = nil; visuals_n = visuals_n - 1
            if vis:IsValid() then
                vis:SetVisibility(false, false)
                log("удар: крупная стрела спрятана (видна: %s), в полёте своих стрел %d", tostring(vis:IsVisible()), visuals_n)
            end
        end
    end)
    log("гашение крупной стрелы при ударе: %s", ok and "подписано" or ("ошибка " .. tostring(err)))
end
local function add_visual_arrow(actor)
    local pm = actor.ProjectileMesh
    if not (pm and pm:IsValid()) then pm = actor:GetComponentByClass(StaticFindObject(MESH_CLASS)) end
    if not (pm and pm:IsValid()) then return end
    local sm = pm.StaticMesh
    if not (sm and sm:IsValid()) then return end
    -- конец стрелы по оси Z: границы сетки (центр + полуразмер); GetBoundingBox из Lua приходит без полей Min/Max (прогон 17:46)
    local max_z = ARROW_TIP_FALLBACK_CM
    pcall(function() local b = sm:GetBounds(); local z = b.Origin.Z + b.BoxExtent.Z; if z > 1.0 then max_z = z end end)
    local s = CFG.visual_scale
    local vis = actor:AddComponentByClass(StaticFindObject(MESH_CLASS), true, IDENTITY, false)
    if not (vis and vis:IsValid()) then return end
    vis:SetCollisionEnabled(0)
    vis:SetStaticMesh(sm)
    for i = 0, pm:GetNumMaterials() - 1 do vis:SetMaterial(i, pm:GetMaterial(i)) end
    vis:K2_AttachToComponent(pm, FName("None"), ATTACH_SNAP, ATTACH_SNAP, ATTACH_KEEP_RELATIVE, false)
    vis:SetRelativeScale3D({ X = s, Y = s, Z = s })
    vis:K2_SetRelativeLocation({ X = 0.0, Y = 0.0, Z = max_z * (1.0 - s) }, false, {}, false)
    if not visual_logged then
        visual_logged = true
        log("крупная стрела: сетка %s ×%.1f, конец по Z %.1f см, сдвиг %.1f см", sm:GetFName():ToString(), s, max_z, max_z * (1.0 - s))
    end
    pm:SetVisibility(false, false)   -- только сама сетка: след и прочие дети родной сетки видимы
    if not stop_hooked then hook_stop() end
    if visuals_n >= VISUALS_CAP then visuals, visuals_n = {}, 0 end
    visuals[actor:GetAddress()] = vis; visuals_n = visuals_n + 1
end

local function dress_arrow(actor)
    arc_settings_check()
    if CFG.no_break then actor.CanBreakOnImpact = false end
    -- срок воткнутой копии (CFG.stuck_life_min выше): у летящей стрелы (BP_BaseProjectile) два поля — в землю/стену и в существо; игра
    -- передаёт копии одно из них в её ProjectileDummyLifetime (пульт 2026-11-01 17:34: 30 и 15 с; поле ProjectileDummyLifetime есть только у копии)
    local life = CFG.stuck_life_min * 60.0
    actor.DummyProjectileOnGroundLifetime = life
    actor.DummyProjectileAttachedToCharacterLifetime = life
    -- mesh_scale ≠ 1 сдвигает воткнутую копию назад от точки удара (раздел выше, bugs/73) — по умолчанию 1.
    if CFG.mesh_scale ~= 1.0 then
        local mesh = actor:GetComponentByClass(StaticFindObject(MESH_CLASS))
        if mesh and mesh:IsValid() then mesh:SetRelativeScale3D(scaled(mesh.RelativeScale3D, CFG.mesh_scale)) end
    end
    if CFG.visual_scale ~= 1.0 then
        local ok, err = pcall(add_visual_arrow, actor)
        if not ok and visual_errors < 5 then visual_errors = visual_errors + 1; log("крупная стрела: ошибка %s", tostring(err)) end
    end
end

-- Кейс AIM12: воткнувшаяся стрела стоит на месте ≥ 0,6 с (карта игры) — читаем её точку через полёт + 0,3 с.
local function check_landing(n, actor, point, d, dist, speed)
    local _, r, u = basis(d)
    ExecuteInGameThreadWithDelay(math.floor(dist / speed * 1000.0 + 300.0), function()
        pcall(function()
            if not actor:IsValid() then return log("#%d: стрела исчезла до проверки", n) end
            local m = sub(actor:K2_GetActorLocation(), point)
            log("#%d встала против точки: вбок %+.0f, вверх %+.0f, вдоль %+.0f см", n, dot(m, r), dot(m, u), dot(m, d))
        end)
    end)
end

-- ------------------------------------------------------------- выстрел
local hip_on, hip_off   -- сдвиг камеры при стрельбе без ПКМ и возврат; тела — ниже, у сдвига от первого лица

local function on_arrow(comp, tries)
    local t0 = os.clock()
    local actor = comp:GetOuter()
    if not actor or not actor:IsValid() or not is_arrow(actor) then return end
    local v = comp.Velocity
    local speed = math.sqrt(dot(v, v))
    -- Стрела на тетиве: снаряд без скорости за ≈1 с до вылета (замер 22:27) — ждём пару тиков, потом пропускаем.
    if speed < 1.0 then
        -- Стрела легла на тетиву — начало выстрела. Без ПКМ лук не натягивается (средняя кнопка и ЛКМ — мгновенный выстрел, заряд 0,00, кейс
        -- H1 2026-10-28), уведомлений натяжки нет, поэтому сдвиг от первого лица без ПКМ начинается здесь; назад — на вылете стрелы. [NOT-TESTED]
        local pawn = actor.Instigator
        if tries == 1 and hip_on and pawn and pawn:IsValid() and pawn:IsPlayerControlled() then pcall(hip_on, pawn) end
        if tries < 4 then ExecuteInGameThread(function() pcall(on_arrow, comp, tries + 1) end) end
        return
    end
    local pawn = actor.Instigator
    if not pawn or not pawn:IsValid() or not pawn:IsPlayerControlled() then return end
    local pcm = pawn:GetController().PlayerCameraManager

    local cam = pcm:GetCameraLocation()
    local f, r, u = basis(view_forward(pcm:GetCameraRotation()))
    local from = actor:K2_GetActorLocation()
    if math.sqrt(dot(sub(from, cam), sub(from, cam))) > CFG.max_from_cam_cm then return end

    -- Разброс игры — углы относительно взгляда, без родного подъёма.
    local charge = actor.PowerChargeMod or 0
    local w, L = strip_lift(scaled(v, 1.0 / speed), charge)
    local tan_r, tan_u = dot(w, r) / dot(w, f), dot(w, u) / dot(w, f)

    local point, who = probe(pawn, actor, cam, f, from)
    local to = sub(point, from)
    local d = dot(to, f) > CFG.min_aim_cm and unit(to) or f
    local _, dr, du = basis(d)
    local dir = unit(add(d, add(scaled(dr, tan_r), scaled(du, tan_u))))
    -- W15: скорость по натяжке, гравитация постоянная. Родная игра наоборот: скорость одна, натяжка меняет гравитацию (1,2 → 0,12) и кривые по
    -- дистанции FC_BowProjectileGravCurve_*. Прогон 2026-10-30 09:39: скорость приняла (5000 → 2500 при заряде 0), а гравитацию игра ПЕРЕПИСАЛА
    -- после нашей записи — через 0,3 с снова 1,20 / 0,13. Поэтому гравитация ставится ещё раз через grav_reapply_ms (два разовых таймера на
    -- стрелу, не опрос); перечитывание через 0,3 и 0,6 с в журнале покажет, держится ли. [NOT-TESTED]
    local new_speed, grav0 = speed, comp.ProjectileGravityScale
    local curve_note = ""
    if CFG.ballistics then
        local c = math.min(1.0, math.max(0.0, charge))
        new_speed = speed * (CFG.min_speed_share + (1.0 - CFG.min_speed_share) * c)
        if CFG.drop_grav_curve then
            -- 0.6.0: без кривой тик блюпринта гравитацию не трогает (см. CFG.drop_grav_curve).
            -- [TESTED: 2026-10-30 · 4 выстрела настоящим вводом, заряд 0 и 1: кривая снята, 0,55 через 0,3 и 0,6 с · KUMM testcases/reports/2026-10-30_conan-arrow-gravity-0.6.0.md]
            local had = actor.ProjectileGravityCurve
            local name = (had and had:IsValid()) and had:GetFName():ToString() or "нет"
            local ok, err = pcall(function() actor.ProjectileGravityCurve = nil end)
            local now = actor.ProjectileGravityCurve
            curve_note = string.format("; кривая гравитации %s → %s%s", name, (now and now:IsValid()) and "ОСТАЛАСЬ" or "снята",
                ok and "" or (" (ошибка: " .. tostring(err) .. ")"))
        end
        comp.ProjectileGravityScale = CFG.arrow_gravity
        for _, ms in ipairs(CFG.grav_reapply_ms) do
            ExecuteInGameThreadWithDelay(ms, function()
                pcall(function() if comp:IsValid() then comp.ProjectileGravityScale = CFG.arrow_gravity end end)
            end)
        end
    end
    comp.Velocity = scaled(dir, new_speed)
    dress_arrow(actor)
    if not templates_done then pcall(tune_templates, actor) end

    shots = shots + 1
    if hip_off then pcall(hip_off, pawn) end   -- выстрел без ПКМ от первого лица: камера сразу едет назад
    local ms = (os.clock() - t0) * 1000.0
    stat_n, stat_sum, stat_worst = stat_n + 1, stat_sum + ms, math.max(stat_worst, ms)
    if shots <= CFG.log_shots then
        local dist = math.sqrt(dot(to, to))
        log("#%d из лука, заряд %.2f: щуп — %s, %.1f м%s; подъём %.2f° снят, разброс вправо %+.2f° вверх %+.2f°; скорость %.0f → %.0f см/с, гравитация %.2f → %.2f%s",
            shots, charge, who, dist / 100.0, d == f and " (в упор — по взгляду)" or "", math.deg(math.atan(L)),
            math.deg(math.atan(tan_r)), math.deg(math.atan(tan_u)), speed, new_speed, grav0 or -1, comp.ProjectileGravityScale or -1, curve_note)
        local n = shots
        for _, ms in ipairs({ 300, 600 }) do
            ExecuteInGameThreadWithDelay(ms, function()
                pcall(function()
                    if not comp:IsValid() then return end
                    local vv = comp.Velocity
                    log("#%d через %.1f с: гравитация %.2f, скорость %.0f см/с", n, ms / 1000.0, comp.ProjectileGravityScale or -1, math.sqrt(dot(vv, vv)))
                end)
            end)
        end
        if CFG.check_landing and who ~= "небо" then check_landing(shots, actor, point, d, dist, new_speed) end
    end
    if os.clock() - stat_since >= CFG.summary_s then
        log("за минуту стрел %d, своё время %.3f мс, худшая %.3f мс", stat_n, stat_sum, stat_worst)
        stat_n, stat_sum, stat_worst, stat_since = 0, 0.0, 0.0, os.clock()
    end
end

-- Ошибки не глотаем молча: в пробах 22:40 «attempt to call a nil value» прятался в pcall, пока не вывели в журнал.
local errors = 0
local function guarded(comp)
    local ok, err = pcall(on_arrow, comp, 1)
    if not ok and errors < 5 then errors = errors + 1; log("ошибка: %s", tostring(err)) end
end

-- ------------------------------------------------- стрелы в трупе (не доделано) и уборка своих копий
-- `[OWNER]` 2026-11-01 09:11 «После смерти - регдол труп врага не должен уничтожать воткнутые в него стрелы - все стрелы сохраняются, торчат
-- из трупа, их можно собрать.» Стенд 2026-11-01 12:5x–13:10 (каппа, конспект KUMM games/ConanExiles/mods/KrinikConanArchery.md):
--   * при смерти рождается Corpse_C (родитель — родной CorpseBase), копии BP_DummyProjectile в этот миг ещё прицеплены к существу;
--   * существо убирается через 1–2 с; его OnDestroyed зовёт у копии DestroyDummyIfAttachedObjectIsDestroyed, а тот (байткод, вход 3484
--     графа) ПЕРВЫМ ЖЕ вызовом делает K2_DestroyActor — без проверок: перецепленная к трупу копия гибнет всё равно;
--   * копия, рождённая из Lua без своего удара, уходит сразу (место 0 0 0, прицепить нельзя).
-- Значит, стрелы в трупе требуют отвязать копию от OnDestroyed существа или породить копию со своим ударом по сетке трупа — следующий шаг
-- (конспект → Open). Что раздел делает сейчас: на рождение трупа цепляет копии этого существа к той же кости трупа со сроком трупа. Польза
-- проверена: наш досыл «в тушку» снимал копии с уборки игры — они висели в 0 0 0 без срока до конца игры (утечка, стенд 12:52); с
-- перецепкой их убирает родное событие (через 10 с копий 0). Стрелы при этом исчезают, как в игре без мода. [TESTED: 2026-11-01 · каппа,
-- 2–3 стрелы, копий через 10 с после смерти 0 · KUMM testcases/reports/2026-11-01_conan-arrows-corpse-recon.md]
local CORPSE_CLASS = "/Script/ConanSandbox.CorpseBase"
local KEEP_WORLD = 1                    -- EAttachmentRule::KeepWorld
local KEEP_RELATIVE = 0                 -- EAttachmentRule::KeepRelative

local function corpse_mesh(corpse)
    local arr = corpse:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))
    for i = 1, #arr do
        local c = arr[i]:get()             -- элемент массива UFunction — обёртка (EXP-0423)
        if c and c:IsValid() then return c end
    end
    return nil
end

local corpse_errors = 0                 -- свой счётчик: общий `errors` раздела к этому мигу бывает исчерпан, и ошибка тонула молча (прогон 13:02)
local function corpse_log_error(err)
    if corpse_errors < 20 then corpse_errors = corpse_errors + 1; log("ошибка «стрелы в трупе»: %s", tostring(err)) end
end

-- Стрелы в добыче трупа ↔ древки в его теле: corpse_arrows[полное имя трупа] = { corpse, inv, items = { [номер предмета] = { копии… } } }.
-- Игрок забрал стрелы из добычи — лишние древки этого предмета уходят (по событию окна добычи, не по таймеру).
local corpse_arrows = {}
local taken_copies = {}                 -- полное имя копии → true: собрана проходом трупа (поздний проход её не берёт второй раз — иначе две стрелы в добычу)
local function sync_corpse_arrows()
    for key, rec in pairs(corpse_arrows) do
        if not (rec.corpse:IsValid() and rec.inv:IsValid()) then
            corpse_arrows[key] = nil
        else
            for item, copies in pairs(rec.items) do
                local left = rec.inv:GetNumberOfItemsByTemplate(item)
                while #copies > left do
                    local c = table.remove(copies)
                    if c:IsValid() then c:K2_DestroyActor() end
                    log("стрелы в трупе: стрелу забрали из добычи — древко убрано (осталось %d)", #copies)
                end
            end
        end
    end
end
local function sync_later(ms)
    ExecuteInGameThreadWithDelay(ms, function()
        local ok, err = pcall(sync_corpse_arrows)
        if not ok then corpse_log_error(err) end
    end)
end
RegisterHook("/Script/ConanSandbox.QuickLootPanel:SlotItemAddedOrRemoved", function() sync_later(50) end)
-- Разделка туши зверя (E у каппы — «Разделать труп») уносит стрелу из добычи трупа, но окно добычи не открывается и его событие молчит
-- (кейс A13, 23:55: стрел в добыче 1 → 0, древко осталось). Поводом служит сама E: после нажатия — одна сверка через 2.5 с (анимация разделки),
-- только пока есть трупы со стрелами; не таймер. [NOT-TESTED]
RegisterKeyBind(Key.E, function()
    if next(corpse_arrows) then sync_later(2500) end
end)
-- Полное окно добычи (E у трупа каппы открыло его, 23:57): «Взять всё» по Q и перетаскивание мышью унесли стрелы (4 → 0), древки остались 4 —
-- событие быстрой добычи там молчит. Q и левая кнопка — тоже повод; сверка — один подсчёт на труп со стрелами. [NOT-TESTED]
RegisterKeyBind(Key.Q, function()
    if next(corpse_arrows) then sync_later(300) end
end)
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
    if next(corpse_arrows) then sync_later(300) end
end)

local function rebirth(corpse, recs)
    if not corpse or not corpse:IsValid() then return end
    -- своя ли стрела — по кости: место стрелы в миг смерти против той же кости на сетке трупа (корень актёра трупа стоит не у тела:
    -- 3700 см в прогоне 13:02). Новая копия из Lua без своего удара сразу уходит (прогон 13:07: место 0 0 0, прицепить нельзя), а старая
    -- копия жива — отцеплена от убранного существа (наш досыл «в тушку» снимает её с уборки, стенд P8/P9 2026-10-31) — её и цепляем к трупу.
    local mesh = corpse_mesh(corpse)
    if not mesh then log("стрелы в трупе: у трупа %s нет сетки", corpse:GetFName():ToString()); return end
    local life = corpse:GetLifeSpan()
    if not life or life <= 0 then life = CFG.corpse_arrow_life_s end
    local inv = corpse:GetComponentByClass(StaticFindObject("/Script/ConanSandbox.ItemInventory"))   -- ItemInventoryReplicateToAll (разведка 23:45)
    if inv and not inv:IsValid() then inv = nil end
    local moved, skipped = 0, 0
    for _, rec in ipairs(recs) do
        local ok, err = pcall(function()
            local b = mesh:GetSocketLocation(FName(rec.bone))
            local d = math.sqrt((b.X - rec.at.X) ^ 2 + (b.Y - rec.at.Y) ^ 2 + (b.Z - rec.at.Z) ^ 2)
            if d > CFG.corpse_radius_cm then
                skipped = skipped + 1
                log("стрелы в трупе: кость %s трупа в %.0f см от стрелы — не его", rec.bone, d)
                return
            end
            local a = rec.dummy
            if not a:IsValid() then log("стрелы в трупе: копия ушла раньше трупа"); return end
            -- Место на трупе — ТО ЖЕ ОТНОСИТЕЛЬНО КОСТИ, что было на существе, а не прежнее место в мире: кость рэгдолла в этот миг лежит
            -- в другом месте (журнал 23:18 — «кость … (181 см)»), и стрела, оставленная в мире, висела в 1,8 м от тела (`[OWNER]` 2026-11-01 23:46
            -- «смотри» · «иногда такое случается все еще» — кадр: две стрелы в воздухе у трупа каппы). [NOT-TESTED]
            a:K2_DetachFromActor(KEEP_WORLD, KEEP_WORLD, KEEP_WORLD)
            local att = a:K2_AttachToComponent(mesh, FName(rec.bone), KEEP_RELATIVE, KEEP_RELATIVE, KEEP_RELATIVE, false)
            a.RootComponent:K2_SetRelativeLocationAndRotation(rec.rel_loc, rec.rel_rot, false, {}, true)
            a:SetLifeSpan(life)
            -- Стрела — в добычу трупа (`[OWNER]` 2026-11-01 23:41 «тогда делаем, что воткнытые в трум стрелы идут в инвентарь трупа», интервью #030):
            -- одна стрела того же предмета на копию; древко остаётся в теле, пока стрела лежит в добыче (sync_corpse_arrows). Вызов проверен
            -- пультом 23:48: AddItemTemplate(53612, −1, None, 1, true, 1, 0) — стрел в добыче трупа 0 → 1. [NOT-TESTED] в разделе
            if att and inv and rec.item and rec.item > 0 then
                inv:AddItemTemplate(rec.item, -1, FName("None"), 1, true, 1.0, 0.0)
                local key = corpse:GetFullName()
                corpse_arrows[key] = corpse_arrows[key] or { corpse = corpse, inv = inv, items = {} }
                local per = corpse_arrows[key].items
                per[rec.item] = per[rec.item] or {}
                table.insert(per[rec.item], a)
            end
            local now = a:K2_GetActorLocation()
            log("стрелы в трупе: копия у кости %s (%.0f см), место %.0f %.0f %.0f → %.0f %.0f %.0f, прицеплена %s", rec.bone, d,
                rec.at.X, rec.at.Y, rec.at.Z, now.X, now.Y, now.Z, tostring(att))
            if att then moved = moved + 1 end
        end)
        if not ok then corpse_log_error(err) end
    end
    log("стрелы в трупе: %s — к трупу прицеплено %d (игра уберёт их с существом), пропущено %d, срок %.0f с", corpse:GetFName():ToString(), moved, skipped, life)
end

on_corpse_born = function(corpse)       -- local выше: его зовёт и рождение поздней копии (стрела, которая убила)
    if not CFG.keep_in_corpse then return end
    local recs = {}
    local char = StaticFindObject("/Script/Engine.Character")
    local cmesh = corpse_mesh(corpse)
    for _, dummy in ipairs(FindAllOf("BP_DummyProjectile_C") or {}) do
        if dummy:IsValid() and not dummy:GetFullName():find("Default__", 1, true) then
            local par = dummy.RootComponent:GetAttachParent()
            local owner = par and par:IsValid() and par:GetOwner() or nil
            local dname = dummy:GetFullName()
            -- Своя ли копия этому трупу — по кости ДО отвязки и пометки: труп чужого существа рядом собрал копии из ЖИВОЙ каппы, отвязал их от её
            -- гибели и пометил, а потом отбросил по расстоянию («в 6190 см — не его», 2026-11-02 00:13) — её стрелы при смерти пропали. [NOT-TESTED]
            local mine = false
            if owner and owner:IsValid() and owner:IsA(char) and not owner:IsPlayerControlled() and not taken_copies[dname] and cmesh then
                local bone = dummy.RootComponent:GetAttachSocketName()
                local b, a = cmesh:GetSocketLocation(bone), dummy:K2_GetActorLocation()
                mine = math.sqrt((b.X - a.X) ^ 2 + (b.Y - a.Y) ^ 2 + (b.Z - a.Z) ^ 2) <= CFG.corpse_radius_cm
            end
            if mine then
                taken_copies[dname] = true
                -- GetTransform() из Lua отдал нули (прогон 13:04: все новые копии в 0 0 0) — место и поворот берутся проверенными вызовами
                local l, r = dummy:K2_GetActorLocation(), dummy:K2_GetActorRotation()
                local rl, rr = dummy.RootComponent.RelativeLocation, dummy.RootComponent.RelativeRotation   -- сдвиг от кости существа
                -- Путь «а» (KUMM researches/conan-arrows-in-corpse, план 40.4 R2): снять с OnDestroyed существа ТОЛЬКО привязку этой копии —
                -- тогда уборка существа её не убьёт, и копия с родным подбором по E переедет на кость трупа. UE4SS документирует Remove(цель, имя)
                -- у многоадресных и разреженных делегатов; есть ли он в 3.0.1 сборки — покажет журнал «отвязано N из M». [NOT-TESTED]
                local unbound = pcall(function() owner.OnDestroyed:Remove(dummy, "DestroyDummyIfAttachedObjectIsDestroyed") end)
                recs[#recs + 1] = {                        -- числа из вызова — сразу в свою таблицу (EXP-0403)
                    at = { X = l.X, Y = l.Y, Z = l.Z },
                    rot = { Pitch = r.Pitch, Yaw = r.Yaw, Roll = r.Roll },
                    rel_loc = { X = rl.X, Y = rl.Y, Z = rl.Z },
                    rel_rot = { Pitch = rr.Pitch, Yaw = rr.Yaw, Roll = rr.Roll },
                    bone = dummy.RootComponent:GetAttachSocketName():ToString(),
                    mesh = dummy.StaticMeshToShow,
                    loot = dummy.IsLootable,
                    item = dummy.ProjectileItemTemplateID,
                    owner = owner,
                    dummy = dummy,
                    unbound = unbound,
                }
            end
        end
    end
    local n_unbound = 0
    for _, rec in ipairs(recs) do if rec.unbound then n_unbound = n_unbound + 1 end end
    log("стрелы в трупе: родился %s, прицепленных к существам копий %d, отвязано от уборки существа %d из %d", corpse:GetClass():GetFName():ToString(),
        #recs, n_unbound, #recs)
    if #recs == 0 then return end
    ExecuteInGameThreadWithDelay(CFG.corpse_find_ms, function()
        local ok, err = pcall(rebirth, corpse, recs)
        if not ok then corpse_log_error(err) end
    end)
end

NotifyOnNewObject(CORPSE_CLASS, function(corpse)
    if corpse:GetFullName():find("Default__", 1, true) then return end
    -- рождение трупа — внутри смерти существа, тем же кадром; копии читаются сразу, пока ещё прицеплены
    last_corpse, last_corpse_t = corpse, os.clock()
    -- сбор — через CFG.corpse_find_ms: в миг рождения сетка трупа ещё не на месте тела, и проверка «своя ли копия» по кости отбросила свои же
    -- стрелы (2026-11-02 00:19, копий 0); через 150 мс расстояние верное (86–181 см), существо живо ещё 1–2 с — отвязка успевает. [NOT-TESTED]
    ExecuteInGameThreadWithDelay(CFG.corpse_find_ms, function()
        local ok, err = pcall(on_corpse_born, corpse)
        if not ok then corpse_log_error(err) end
    end)
end)
log("стрелы в трупе: %s", CFG.keep_in_corpse and "копии цепляются к трупу (стрелы пока исчезают — конспект)" or "выкл")

-- ------------------------------------------------- прицел после выстрела
-- План 36 п. 34: `[OWNER]` «если ПКС зажата, то нужно оставаться в прицеле после выстрела» · 2026-10-26; «и камеры мод нужно бы
-- починить после вчерашнего рефактора, чтобы она не отъезжала после выстрелов при продолжении удержания прицельной стойки игроком по
-- пкм» · 2026-10-27 19:0x. На выстреле родной C++ зовёт BP_PlayerFovController:SetFieldOfViewTarget(0), обзор 54° → 107°, и через
-- ≈0,7 с снова (1) (замер 2026-10-26 23:05). Что НЕ работает (EXP-0349): подмена аргумента; вызов (1) ИЗНУТРИ перехвата (подозреваемый
-- в падении, баг 65); запись поля FieldOfViewTarget — мимо перехода контроллера, после отпускания ПКМ камера застревала в зуме.
-- Здесь: перехват только смотрит; сброс на выстреле (был прицел, просят обычный, ПКМ зажата) — на СЛЕДУЮЩЕМ тике родной вызов (1).
-- Полей не пишем, на отпускание ПКМ не вмешиваемся: из прицела игра выходит своим путём. [NOT-TESTED]
local FOV_CONTROLLER = "/Game/Systems/Combat/BP_PlayerFovController.BP_PlayerFovController_C"
local FOV_FUNC = FOV_CONTROLLER .. ":SetFieldOfViewTarget"
local FOV_DEFAULT, FOV_AIM = 0, 1
local fov_last, fov_kept = nil, 0
local aim_deg_last, redraw_logged = nil, 0   -- угол последнего прицела; сколько раз держали прицел на новом натяжении
-- Номер выстрела на входе в прицел: прицел держим на «новом натяжении», только если с тех пор герой выстрелил. Натяжение, сорванное выносливостью,
-- тоже кончает уведомление монтажа при зажатой ПКМ — без выстрела; держать прицел там нечего (KUMM bugs/76, кейс S5: 2026-11-02 13:13 вид оставался
-- приближенным, а герой уже не целился).
-- [TESTED: 2026-11-02 · S6 (срыв — прицел уходит), S7 (выстрел с ПКМ — прицел держим) · KUMM testcases/reports/2026-11-02_conan-arrow-choice-and-bow-stance.md]
local shots_at_aim = 0
local fp_zoom_logged = 0
local fp_aim_shift   -- объявлена здесь, тело ниже: её зовёт и watch_release, который стоит выше неё
-- Прибор агента: пульт не изображает зажатую ПКМ (`IsInputKeyDown` видит только физическую кнопку — карта игры), поэтому файл
-- test_rmb.txt в папке мода изображает её для прогона без владельца. Читается только на событии сброса обзора, не каждый кадр.
local TEST_RMB_FILE = "ue4ss/Mods/KrinikConanArchery/test_rmb.txt"

local function rmb_held(c)
    if c:GetOwner():GetController():IsInputKeyDown({ KeyName = FName("RightMouseButton") }) then return true end
    local f = io.open(TEST_RMB_FILE, "r")
    if f then f:close(); return true end
    return false
end

-- Блеск полного заряда (план 36 п. 38): `[OWNER]` «блеск полного заряда на кончике стрелы по  радиусу эффекта нужно на 50 процентов
-- больше» · 2026-10-27 19:0x. Шаблон P_bow_powercharge_charged (пульт 19:16): четыре излучателя, стартовый размер 200 / 200 / 40 / 20 —
-- все ×glint_scale. Блеск горит при натяжке, раньше первой стрелы, поэтому — на первом входе в прицел (лук уже загрузил шаблон), раз за
-- запуск: модули шаблона живут весь запуск, повтор умножил бы ещё раз. [NOT-TESTED]
local GLINT = "/Game/Effects/Particles/P_bow_powercharge_charged.P_bow_powercharge_charged"
local glint_done = false

local function tune_glint()
    local tpl = StaticFindObject(GLINT)
    if not tpl or not tpl:IsValid() then return end
    glint_done = true
    local seen, sizes = {}, {}
    for_each_module(tpl, function(_, mod)
        if not mod or seen[mod:GetAddress()] then return end
        seen[mod:GetAddress()] = true
        if mod:GetFName():ToString():find("^ParticleModuleSize_") then
            mod.StartSize.Table.Values:ForEach(function(_, v)
                if v:get() > 1.0 then v:set(v:get() * CFG.glint_scale); sizes[#sizes + 1] = string.format("%.0f", v:get()) end
            end)
        end
    end)
    log("блеск заряда ×%.2f: размеры %s", CFG.glint_scale, table.concat(sizes, " "))
end

-- Список выбора стрел (мод Arrow Quick Swap, KUMM games/ConanExiles/mods/ArrowQuickSwap.md). Байткод AQS_Actor_Component.UpdateDisplayUI (2026-11-02 12:5x):
-- на подсостоянии 16 (прицел) — AllowShowingUI = истина, GetCurrentAmmoInventory (наполняет CurrentAmmo — по строке на СТОПКУ стрел, см. one_row_per_kind),
-- AmmoUI:AddToViewport;
-- окно рождается невидимым (наша правка ассета 2026-10-29, CanvasPanel_32 непрозрачность 0) и само при натяжении не показывается — только от колеса.
-- Владелец 12:54–12:56: показывать при натяжении, когда есть из чего выбрать; один вид или строка хаба выключена — окна нет вовсе, даже от колеса.
-- Поэтому после родного UpdateDisplayUI, на том же событии входа в прицел: непрозрачность САМОГО окна (SetRenderOpacity — анимация Reveal водит
-- только CanvasPanel_32, корень окна игра не трогает) = 1 или 0, и при «показывать» — родной RevealDisplay компонента (тот же путь, что у колеса,
-- с его же самоскрытием через MinDisplayTime). Ни таймера, ни опроса: одна проверка на вход и выход из прицела.
-- [TESTED: 2026-11-02 · L1–L4 по кадрам 120 к/с · KUMM testcases/reports/2026-11-02_conan-arrow-choice-and-bow-stance.md]
local AQS_CLASS = "/Game/Mods/ArrowQuickSwap/AQS_Actor_Component.AQS_Actor_Component_C"
local aqs_hooked, aqs_logged = false, 0

-- Ошибка автора AQS (KUMM bugs/78, замер 2026-11-02 15:0x): GetCurrentAmmoInventory кладёт в CurrentAmmo КАЖДУЮ СТОПКУ стрел — две стопки костяных дали
-- [51184, 51184, 53612]. Перебор CycleAmmoSelection ищет текущую стрелу по первому совпадению и шагает ±1 по этому списку, так что «вверх» с костяной
-- вело на вторую костяную — стрела не менялась никогда; и список выбора считал два вида там, где вид один. Ассет не поддаётся правке того же размера
-- (нужен Array_AddUnique, его импорта в ассете нет), поэтому — здесь, сразу после родного GetCurrentAmmoInventory (его зовёт только UpdateDisplayUI,
-- на входе в прицел): в списке остаётся первая стопка каждого вида (их число AQS берёт из своей карты AmmoCount — она и так по видам).
-- [TESTED: 2026-11-02 · 6 стопок (5 костяных): «стопок 6, видов 2», колесо вверх меняет стрелу каждым щелчком, окно 6 строк вместо 18; 0.20 мс вместе с
-- родным пересбором AQS · KUMM testcases/reports/2026-11-02_conan-wheel-in-bow-aim.md]
local function one_row_per_kind(comp)
    local arr = comp.CurrentAmmo
    local n = arr:GetArrayNum()
    local seen, keep = {}, {}
    for i = 1, n do
        local it = arr[i]
        local id = it.TemplateID
        if not seen[id] then seen[id] = true; keep[#keep + 1] = it end
    end
    if #keep == n then return n end
    arr:Empty()
    for i, it in ipairs(keep) do arr[i] = it end
    -- Строки окна AQS построило из сырого списка ещё до нас (кадр 2026-11-02 15:05: «Костяная · Железная · Костяная» при двух видах) — перестроить
    -- родными функциями окна: CreateAmmoWidgets без параметров читает CurrentAmmo компонента.
    local ui = comp.AmmoUI
    if ui and ui:IsValid() then
        ui:ClearVBoxAmmoWidgets()
        ui:CreateAmmoWidgets()
    end
    return #keep
end

local function on_aqs_display(ctx)
    local comp = ctx:get()
    if not (comp and comp:IsValid()) or not comp.AllowShowingUI then return end
    arc_settings_check()
    local stacks = comp.CurrentAmmo:GetArrayNum()
    local kinds = one_row_per_kind(comp)
    local ui = comp.AmmoUI
    if not (ui and ui:IsValid()) then return end
    local show = CFG.ammo_list and kinds >= 2
    ui:SetRenderOpacity(show and 1.0 or 0.0)
    if show then comp:RevealDisplay() end
    if aqs_logged < CFG.log_shots then
        aqs_logged = aqs_logged + 1
        log("выбор стрел при натяжении: стопок %d, видов %d, строка %s — %s", stacks, kinds, tostring(CFG.ammo_list), show and "показан" or "скрыт")
    end
end

local function hook_aqs()
    if aqs_hooked then return end
    local ok, err = pcall(RegisterHook, AQS_CLASS .. ":UpdateDisplayUI", function(ctx) pcall(on_aqs_display, ctx) end)
    aqs_hooked = ok
    log(ok and "выбор стрел: перехват UpdateDisplayUI поставлен" or ("выбор стрел: перехват не встал — " .. tostring(err)))
end

-- Тетива, застывшая натянутой (KUMM bugs/76, `[OWNER]` 2026-11-02 12:50 «герой пркращает натяжение, но лук остаётся в руках героя с натянутой титевой» ·
-- 13:38 «ОНА ТРЕУГОЛЬНАЯ!!!» · 13:45 «нужно чинить это баг»). Журнал пульта 13:47–13:48: натяжение, начатое в истощении (подсостояние 14), обрывается
-- на 0,41–0,46 монтажа AM_combat_2h_bow_combo_heavy_c0 — раньше точки удержания заряда (0,517); уведомление монтажа bow_secondary_draw (0,067) уже
-- запустило у лука анимацию A_combat_bow_string_heavy_charge, а bow_secondary_settle (6,843) не наступает: лук стоит на последнем кадре натяжения
-- (1,833 из 1,833), тетива треугольником к груди, руки на рукояти. Обычное отпускание ставит луку A_bow_3rd_secondary_special_settle. Родной путь
-- игры — обработчик AB_human_male_C:AnimNotify_bow_secondary_settle (вызван пультом 13:47 — тетива легла вдоль лука). Поэтому: после родного
-- события конца атаки (OnSubstateChanged_Attacking, Entered = ложь), если монтаж лука уже не играет, а тетива всё ещё в анимации натяжения, —
-- тот же родной обработчик. Ни таймера, ни опроса: проверка на событие конца атаки, через 100 мс (монтаж к тому мигу снят).
-- [TESTED: 2026-11-02 · B1 (натяжение при выносливости ≈ 5 — тетива отпущена), B2 (выстрел — не вмешивается), B3 (удержание — не вмешивается) · KUMM testcases/reports/2026-11-02_conan-arrow-choice-and-bow-stance.md]
local ATTACK_EVENT = "/Game/Characters/BasePlayerChar.BasePlayerChar_C:OnSubstateChanged_Attacking"
local BOW_MONTAGE_HINT, STRING_CHARGE_HINT = "2h_bow", "string_heavy_charge"
local settle_hooked, settle_fixed = false, 0

local function bow_string_of(pawn)
    for _, a in ipairs(FindAllOf("BP_bow_2h_C") or {}) do
        if a:IsValid() and a:GetAttachParentActor() == pawn then
            local m = a:GetComponentByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))
            if m and m:IsValid() then return m end
        end
    end
end

local function settle_if_stuck(pawn)
    if not (pawn and pawn:IsValid()) then return end
    local anim = pawn.Mesh:GetAnimInstance()
    local mont = anim:GetCurrentActiveMontage()
    if mont and mont:IsValid() and mont:GetFName():ToString():find(BOW_MONTAGE_HINT, 1, true) then return end
    local sm = bow_string_of(pawn)
    if not sm then return end
    local asset = sm:GetAnimInstance().CurrentAsset
    if not (asset and asset:IsValid() and asset:GetFName():ToString():find(STRING_CHARGE_HINT, 1, true)) then return end
    anim:AnimNotify_bow_secondary_settle()
    settle_fixed = settle_fixed + 1
    if settle_fixed <= CFG.log_shots then log("тетива осталась натянутой после оборванного натяжения — отпущена родным settle (%d)", settle_fixed) end
end

local function hook_settle()
    if settle_hooked then return end
    local ok, err = pcall(RegisterHook, ATTACK_EVENT, function(ctx, _sub, entered)
        if entered:get() then return end
        local pawn = ctx:get()
        ExecuteInGameThreadWithDelay(100, function() pcall(settle_if_stuck, pawn) end)
    end)
    settle_hooked = ok
    log(ok and "тетива: перехват конца атаки поставлен" or ("тетива: перехват не встал — " .. tostring(err)))
end

-- Компонент рождается с героем; класс мода грузится вместе с ним — подписка на рождение, плюс попытка сразу (горячая перезагрузка в мире).
NotifyOnNewObject(AQS_CLASS, function() ExecuteInGameThread(function() pcall(hook_aqs) end) end)
if StaticFindObject(AQS_CLASS) then pcall(hook_aqs) end

-- Отпускание ПКМ после удержанного выстрела (`[OWNER]` «если пкм отпускаю - она должна отъезжать, уходить из прицельного приближения» ·
-- 2026-10-27 19:5x). Наш вызов (1) оставлял обзор прицельным, если ПКМ отпущена раньше родного возврата в прицел (≈0,7 с), а (0) вне
-- перехода контроллер не принимает (19:50). Родной FieldOfViewReset возвращает обычный обзор (пульт 19:55: 90,9° → 105,8°). Опрос кнопки —
-- только пока мод держит прицел после выстрела (доли секунды — секунды), раз в release_poll_ms; кончается на отпускании. Новый выстрел с
-- зажатой ПКМ начинает свой опрос, старый видит смену номера и выходит. [NOT-TESTED]
local watching = 0
local function watch_release(c, n)
    watching = n
    local function tick()
        pcall(function()
            if watching ~= n or not c:IsValid() then return end
            if rmb_held(c) then return ExecuteInGameThreadWithDelay(CFG.release_poll_ms, tick) end
            watching = 0
            c:FieldOfViewReset()
            pcall(fp_aim_shift, c, false)
            if n <= CFG.log_shots then log("прицел: ПКМ отпущена — обычный обзор (%d)", n) end
        end)
    end
    ExecuteInGameThreadWithDelay(CFG.release_poll_ms, tick)
end

-- Первое лицо узнаём по месту камеры: она стоит в точке штанги первого лица (замер 20:03 — 0 см; от третьего лица штанга у головы, камера
-- в метрах от неё). Сдвиг самой штанги — в осях взгляда, на месте камеры относительно штанги он не сказывается.
local function first_person_arm(pawn)
    local arm = pawn.FirstPersonCameraArm
    if not arm or not arm:IsValid() then return nil end
    local cam = pawn:GetController().PlayerCameraManager:GetCameraLocation()
    local d = sub(arm:K2_GetComponentLocation(), cam)
    -- допуск — 10 см плюс наш собственный сдвиг штанги: со сдвигом (−5, 16, 6) камера в 18 см от точки штанги, и повторный прицел после
    -- выстрела считался третьим лицом — обзор уходил на 53,8° (кейс P2 2026-10-28)
    local o = arm.SocketOffset
    if math.sqrt(dot(d, d)) > 10.0 + math.sqrt(o.X * o.X + o.Y * o.Y + o.Z * o.Z) then return nil end
    return arm
end

-- Камера над стрелой от первого лица — только в прицельной стойке (п. 43). Ставим на входе в стойку, снимаем на выходе — плавно, за
-- fp_shift_ms (smoothstep). Переход, перебитый новым (отпустил ПКМ на полпути), идёт от текущего места с той же скоростью: время —
-- доля пути. Шаги — ExecuteInGameThreadWithDelay только пока идёт переход, без опроса между ними. [TESTED: 2026-10-28 · кейсы P1, P5 настоящей мышью:
-- ≈450 мс туда, ≈400 обратно, ≤ 4 см за отсчёт, разворот с полпути — testcases/reports/2026-10-28_conan-bow-fp-smooth-zoom.md]
local fp_shifted = nil   -- штанга, у которой сдвиг стоит или едет к стойке; nil — сдвиг снят или едет к нулю
local fp_tween = 0       -- номер текущего перехода; старый видит смену номера и выходит

-- z_ms — своё время для высоты (натяжка без ПКМ: вслед за позой, которая опускает голову за ≈70 мс, кейс D1 2026-10-28); nil — как у всего
local function shift_to(arm, to, z_ms)
    fp_tween = fp_tween + 1
    local my = fp_tween
    local o = arm.SocketOffset
    local from = { X = o.X, Y = o.Y, Z = o.Z }
    -- полный ход 0 ↔ цель — ровно fp_shift_ms для любой цели (прикладка, натяжка без ПКМ), часть пути — та же скорость
    local path = math.sqrt((to.X - from.X) ^ 2 + (to.Y - from.Y) ^ 2 + (to.Z - from.Z) ^ 2)
    local whole = math.max(1e-3, math.sqrt(from.X ^ 2 + from.Y ^ 2 + from.Z ^ 2), math.sqrt(to.X ^ 2 + to.Y ^ 2 + to.Z ^ 2))
    -- Время — по часам (os.clock на Windows — настенное время процесса), не по числу шагов: отложенный вызов (16 мс) срабатывает раз в кадр
    -- (≈29 мс), и счёт шагов растянул 500 мс до ≈900 (кейс P1 2026-10-28)
    local dur = math.max(0.001, CFG.fp_shift_ms / 1000 * path / whole)
    local dur_z = z_ms and math.max(0.001, z_ms / 1000) or dur
    local t0 = os.clock()
    local function step()
        pcall(function()
            if my ~= fp_tween or not arm:IsValid() then return end
            local e = os.clock() - t0
            local t, tz = math.min(1.0, e / dur), math.min(1.0, e / dur_z)
            local s, sz = t * t * (3 - 2 * t), tz * tz * (3 - 2 * tz)
            arm.SocketOffset = { X = from.X + (to.X - from.X) * s, Y = from.Y + (to.Y - from.Y) * s, Z = from.Z + (to.Z - from.Z) * sz }
            if t < 1.0 or tz < 1.0 then ExecuteInGameThreadWithDelay(CFG.fp_shift_step_ms, step) end
        end)
    end
    step()
end

local fp_target = nil    -- куда едет или где стоит сдвиг: прикладка или натяжка без ПКМ

-- offset — куда сдвигать (по умолчанию — прикладка); при уже стоящем сдвиге к другой цели — переезд к новой (ПКМ посреди натяжки без ПКМ)
fp_aim_shift = function(c, on, offset, z_ms)
    local pawn = c:GetOwner()
    if not pawn or not pawn:IsValid() then return end
    if on then
        offset = offset or CFG.fp_aim_offset
        if fp_shifted and fp_target == offset then return end
        local arm = fp_shifted or first_person_arm(pawn)
        if not arm then return end   -- третье лицо: не трогаем
        fp_shifted, fp_target = arm, offset
        shift_to(arm, offset, z_ms)
    elseif fp_shifted then
        local arm = fp_shifted
        fp_shifted, fp_target = nil, nil
        if arm:IsValid() then shift_to(arm, { X = 0.0, Y = 0.0, Z = 0.0 }) end
    end
end

-- Натяжка лука БЕЗ ПКМ от первого лица — тот же сдвиг над стрелой на время натяжки, назад после выстрела (`[OWNER]` «при стрельбе от первого
-- лица БЕЗ прикладки - тоже нужно будет на каждый выстрел камеру двигать в ту позицию, что в прикладке, и после выстрела - отодвигать назад» ·
-- 2026-10-28 19:0x). Монтаж натяжки один на все кнопки, поэтому событие — его уведомления, а не кнопка: BP_PowerCharge (натяжка 0,55–1,83 с)
-- начинает сдвиг; BP_SetChargeHold стоит в монтаже дважды (0,52–1,85 и 1,85–5,81), поэтому активные считаются, и назад — когда через 150 мс
-- после конца ни одного не осталось (стык двух удержаний возврата не даёт; конец удержания на выстреле, обрыв натяжки — дают). Выпуск
-- стрелы (on_arrow) возвращает сразу. Пока зажата ПКМ — сдвигом владеет прицельная стойка. [NOT-TESTED]
local POWER_CHARGE = "/Game/Systems/Combat/BP_PowerCharge.BP_PowerCharge_C"
local CHARGE_HOLD = "/Game/Systems/Combat/BP_SetChargeHold.BP_SetChargeHold_C"
local hip_shift = false     -- сдвиг поставлен натяжкой без ПКМ
local charge_active = 0     -- активные уведомления натяжки и удержания
local hip_logged = 0

local function player_of(mesh)
    local pawn = mesh and mesh:IsValid() and mesh:GetOwner()
    if pawn and pawn:IsValid() and pawn.IsPlayerControlled and pawn:IsPlayerControlled() then return pawn end
    return nil
end

-- Возврат сдвига после выстрела без ПКМ — через fp_hip_hold_ms; новая натяжка раньше отменяет его (номер hip_gen), и при частой стрельбе
-- камера не ходит вниз-вверх между выстрелами: поза ещё опущена, а сдвиг уже снят — провалы до −10 см (кейс D1 2026-10-28). [NOT-TESTED]
local hip_gen = 0

hip_on = function(pawn)
    local fov = pawn.BP_PlayerFovController
    if rmb_held(fov) then return end
    hip_gen = hip_gen + 1            -- отложенный возврат прошлого выстрела больше не нужен
    if fp_shifted then return end
    fp_aim_shift(fov, true, CFG.fp_hip_offset, CFG.fp_hip_z_ms)
    if fp_shifted then
        hip_shift = true
        if hip_logged < CFG.log_shots then hip_logged = hip_logged + 1; log("натяжка без ПКМ: камера над стрелой (%d)", hip_logged) end
    end
end

hip_off = function(pawn)
    if not hip_shift then return end
    hip_gen = hip_gen + 1
    local my = hip_gen
    ExecuteInGameThreadWithDelay(CFG.fp_hip_hold_ms, function()
        pcall(function()
            if my ~= hip_gen or not hip_shift or not pawn:IsValid() then return end
            hip_shift = false
            local fov = pawn.BP_PlayerFovController
            if rmb_held(fov) then return end   -- ПКМ зажали посреди натяжки: сдвиг теперь её, снимет отпускание
            fp_aim_shift(fov, false)
        end)
    end)
end

-- Звук полного заряда — только герою игрока (`[OWNER]` «у врагов тоже звучит Дзинь при полном нятяжении лука» · «Можно врагам не дзинкать, а
-- только для героя игрока?» · 2026-10-28). Монтаж натяжки общий с NPC, поэтому уведомление звука в монтаже (KrinikBowFixes) немое — громкость 0,
-- только держит звук загруженным; играет его этот мод по началу второго удержания BP_SetChargeHold (1,85–5,81 с монтажа — полный заряд,
-- длительность ≈ 3,96 с против 1,33 у первого), и только у героя игрока: player_of отсекает NPC.
-- Один раз на натяжку: пока ПКМ держат, петля удержания повторяет BP_SetChargeHold каждые ≈ 3,9 с, и звук шёл на каждый круг (прогон S3
-- 2026-10-28 22:36 на чистом стенде: два «дзинь» на 4,21 и 8,08 с записи; `[OWNER]` «повторять звук полного натяжения каждые 4 секунды не
-- нужно»). Флаг ding_played снимается там же, где камера уходит из натяжки: удержание кончилось по-настоящему, а не между кругами петли. [NOT-TESTED]
local CHARGE_SOUND = "/Game/Mods/KrinikConanArchery/S_ChargeFull.S_ChargeFull"
local FULL_HOLD_MIN_S = 2.0
local ding_logged = 0
local ding_played = false

local function play_charge_ding(pawn)
    local snd = StaticFindObject(CHARGE_SOUND)
    if not snd or not snd:IsValid() then
        if ding_logged < CFG.log_shots then ding_logged = ding_logged + 1; log("звук полного заряда: ассет не загружен (%s)", CHARGE_SOUND) end
        return
    end
    StaticFindObject("/Script/Engine.Default__GameplayStatics"):PlaySound2D(pawn, snd, 1.0, 1.0, 0.0, nil, pawn, false)
    if ding_logged < CFG.log_shots then ding_logged = ding_logged + 1; log("звук полного заряда — герою (%d)", ding_logged) end
end

local function on_charge_begin(mesh, cls, total)
    local pawn = player_of(mesh)
    if not pawn then return end
    charge_active = charge_active + 1
    hip_on(pawn)
    -- The spread bars are hidden at the start of EVERY draw too, not only on the aim entry: a draw without the aim view (the heavy attack on
    -- the middle button) never reaches on_fov_target, and the bars showed (`[OWNER]` «опять полоски разброса появились!!!!!!» · 2026-10-29
    -- 00:2x — his run had no aim-view entry in the log). A few curve keys, once per draw — no polling. [NOT-TESTED]
    local first = not bars_done
    if pcall(hide_bars) and first then log("полоски прицела скрыты в начале натяжки: %s", tostring(bars_done)) end
    if cls == CHARGE_HOLD and total and total > FULL_HOLD_MIN_S and not ding_played then
        ding_played = true
        play_charge_ding(pawn)
    end
end

local function on_charge_end(mesh)
    local pawn = player_of(mesh)
    if not pawn then return end
    charge_active = math.max(0, charge_active - 1)
    if charge_active > 0 then return end
    ExecuteInGameThreadWithDelay(150, function()
        pcall(function()
            if charge_active == 0 then ding_played = false end
            if charge_active == 0 and pawn:IsValid() then hip_off(pawn) end
        end)
    end)
end

local function on_fov_target(ctx, target)
    local v, c = target:get(), ctx:get()
    local was = fov_last
    fov_last = v
    if v == FOV_AIM and not glint_done then pcall(tune_glint) end
    if v == FOV_AIM and not aqs_hooked then pcall(hook_aqs) end   -- класс мода стрел уже загружен: подписка на рождение блюпринта может не сработать
    if v == FOV_AIM and not settle_hooked then pcall(hook_settle) end   -- класс героя загружен: его событие конца атаки доступно
    if v == FOV_AIM then
        local first = not bars_done
        if pcall(hide_bars) and first then log("полоски прицела скрыты на первом прицеливании: %s", tostring(bars_done)) end
    end
    -- Слабее зум в прицеле, в обоих видах. Перехват срабатывает ПОСЛЕ тела: цель уже обычный ×0,5, и переход контроллера только начался — его
    -- тик каждый кадр ведёт камеру к полю FieldOfViewTarget (байткод ExecuteUbergraph: Lerp к GetFieldOfViewTarget, пока ChangeCurrent > 0).
    -- Одна запись поля в начале перехода; вне перехода поле не пишем (EXP-0349). [TESTED: 2026-10-28 · от первого лица P1, P2, P7 (тогда 86°),
    -- после выстрела держится — testcases/reports/2026-10-28_conan-bow-fp-smooth-zoom.md; оба вида по 75° — кейс Z1, NOT-TESTED]
    -- Натяжка без ПКМ от первого лица — без зума, только сдвиг камеры (владелец 2026-10-28 19:0x: «Но зума не будет - только смещение
    -- камеры»): цель — обычный обзор (родной прицел ×0,5, обратно ×2). [NOT-TESTED]
    if v == FOV_AIM and not rmb_held(c) then
        local pawn = c:GetOwner()
        if pawn and pawn:IsValid() and first_person_arm(pawn) then
            c.FieldOfViewTarget = c.FieldOfViewTarget * 2.0
            return
        end
    end
    if v == FOV_AIM then arc_settings_check() end
    if v == FOV_AIM and CFG.aim_fov_deg then
        c.FieldOfViewTarget = CFG.aim_fov_deg
        if fp_zoom_logged < CFG.log_shots then
            fp_zoom_logged = fp_zoom_logged + 1
            log("прицел: обзор %.1f°", c.FieldOfViewTarget)
        end
    end
    if v == FOV_AIM then aim_deg_last = c.FieldOfViewTarget; shots_at_aim = shots end
    -- Новое натяжение при зажатой ПКМ (CFG.hold_aim_on_redraw): цель 0 сразу после прицела — конец уведомления старого монтажа; новое придёт
    -- следом. Номер и угол цели — обратно на прицел здесь же, до тика контроллера: кадра отъезда нет. Отпускание ПКМ выводит из прицела как
    -- прежде (release_aim видит номер 1). [NOT-TESTED]
    if CFG.hold_aim_on_redraw and v == FOV_DEFAULT and was == FOV_AIM and aim_deg_last and shots > shots_at_aim and rmb_held(c) then
        c.FieldOfView = FOV_AIM
        c.FieldOfViewTarget = aim_deg_last
        fov_last = FOV_AIM
        if redraw_logged < CFG.log_shots then
            redraw_logged = redraw_logged + 1
            log("прицел: новое натяжение с ПКМ — обзор держим %.1f° (%d)", aim_deg_last, redraw_logged)
        end
        return
    end
    if not CFG.keep_aim or v ~= FOV_DEFAULT or was ~= FOV_AIM then return end
    if not rmb_held(c) then return end
    ExecuteInGameThread(function()
        pcall(function()
            if c:IsValid() then
                c:SetFieldOfViewTarget(FOV_AIM)
                fov_kept = fov_kept + 1
                if fov_kept <= CFG.log_shots then log("прицел: ПКМ зажата — обзор возвращён прицельным (%d)", fov_kept) end
                watch_release(c, fov_kept)
            end
        end)
    end)
end

-- Сдвиг от первого лица — по событиям ПКМ героя, не по обзору: от первого лица прицел обзор не меняет и SetFieldOfViewTarget там не
-- приходит (пульт 20:17: ПКМ зажата, обзор 107,5°). Владелец 20:2x на пробе пультом: «от первого лица вид в прикладке стал хороший».
-- Кнопку читаем через 100 мс после события: на самом событии нажатия её состояние ещё старое (опыт 005bb38). [NOT-TESTED]
local RMB_EVENTS = { "InpActEvt_SpecialActionV2_K2Node_InputActionEvent_7", "InpActEvt_SpecialActionV2_K2Node_InputActionEvent_8" }
local HERO_CLASS = "/Game/Characters/BasePlayerChar.BasePlayerChar_C"

-- Выход из прицела по отпусканию ПКМ после выстрела. KrinikBowFixes держит уведомление обзора до конца монтажа (иначе зум падает при
-- зажатой ПКМ: после выстрела монтаж доигрывает сам, кейс N1 2026-10-28), и отпущенная сразу после выстрела ПКМ держала зум до конца
-- монтажа (≈0,9 с, кейс M2 2026-10-27). Отпущено, а цель контроллера прицельная (FieldOfView = 1) — один родной вызов FieldOfViewChange
-- (0.1, 0): по байткоду он при новой цели запускает переход контроллера к обычному обзору. Отпускание посреди натяжки игра закрывает сама
-- (монтаж прерван, цель уже 0) — тогда вызова нет. Позавчерашний «FieldOfViewChange не помог» был при цели уже 0 (EXP-0349).
-- Поправка по кейсу N9: через 100 мс после отпускания посреди натяжки цель ещё 1, вызов идёт и там — родной выход следом пустой, вреда нет.
-- [TESTED: 2026-10-28 · N1–N8, P2–P3 настоящей мышью: отпускание в любой момент → ≥ 100° за 114–204 мс, назад в прицел не уходит —
-- testcases/reports/2026-10-28_conan-bow-fp-smooth-zoom.md]
local release_logged = 0

local function release_aim(fov)
    if fov.FieldOfView ~= FOV_AIM then return end
    fov:FieldOfViewChange(CFG.release_fov_s, FOV_DEFAULT)
    if release_logged < CFG.log_shots then
        release_logged = release_logged + 1
        log("прицел: ПКМ отпущена — выход из прицела (%d)", release_logged)
    end
end

local function on_rmb_event(ctx)
    local pawn = ctx:get()
    ExecuteInGameThreadWithDelay(100, function()
        pcall(function()
            if not pawn:IsValid() then return end
            local fov = pawn.BP_PlayerFovController
            local held = rmb_held(fov)
            pcall(fp_aim_shift, fov, held)
            if not held then pcall(release_aim, fov) end
        end)
    end)
end

-- The spread bars show at the crosshair as soon as a bow is in hand, before any draw or aim (frame `sh0.jpg`, 2026-10-29 00:40: «— • —» with
-- the bow held, no draw) — that is what the owner saw («опять полоски разброса появились!!!!!!»). So they are hidden when the crosshair widget
-- is created (one event per world entry): a tick later, and once more a second later if the curve was not loaded yet. Checked live: zeroing
-- the curve at that state leaves only the dot (`bars_cmp.webp`). [NOT-TESTED] as a mod path.
local CROSSHAIR_WIDGET = "/Game/UI/Widgets/HUD/Reticles/WBP_Crosshair.WBP_Crosshair_C"
NotifyOnNewObject(CROSSHAIR_WIDGET, function()
    ExecuteInGameThreadWithDelay(100, function()
        local ok, hidden = pcall(hide_bars)
        if ok and hidden then log("полоски прицела скрыты при создании прицела") return end
        ExecuteInGameThreadWithDelay(1000, function()
            local ok2, hidden2 = pcall(hide_bars)
            log("полоски прицела при создании прицела: %s", tostring(ok2 and hidden2))
        end)
    end)
end)

-- Перехват ставится один раз, когда игра создала компонент обзора (класс уже загружен): до первого выстрела (d0688c2 — иначе первый
-- выстрел сбрасывал камеру). Глобальная ссылка — чтобы повторная загрузка мода не удвоила обработку (EXP-0348).
_G.__krinik_fov_fn = on_fov_target
_G.__krinik_rmb_fn = on_rmb_event
_G.__krinik_charge_begin_fn = on_charge_begin
_G.__krinik_charge_end_fn = on_charge_end
NotifyOnNewObject(FOV_CONTROLLER, function()
    ExecuteInGameThread(function()
        if not _G.__krinik_rmb_hooked then
            _G.__krinik_rmb_hooked = true
            for _, ev in ipairs(RMB_EVENTS) do
                local ok, err = pcall(function()
                    RegisterHook(HERO_CLASS .. ":" .. ev, function(ctx)
                        local fn = _G.__krinik_rmb_fn
                        if fn then pcall(fn, ctx) end
                    end)
                end)
                log(ok and ("ПКМ: перехват %s поставлен") or ("ПКМ: перехват %s не встал — " .. tostring(err)), ev)
            end
        end
        if _G.__krinik_fov_hooked then return end
        local ok, err = pcall(function()
            RegisterHook(FOV_FUNC, function(ctx, target)
                local fn = _G.__krinik_fov_fn
                if fn then
                    local ok2, e2 = pcall(fn, ctx, target)
                    if not ok2 and errors < 5 then errors = errors + 1; log("ошибка прицела: %s", tostring(e2)) end
                end
            end)
        end)
        _G.__krinik_fov_hooked = ok
        log(ok and "прицел: перехват SetFieldOfViewTarget поставлен" or ("прицел: перехват не встал — " .. tostring(err)))
    end)
end)

-- Перехваты уведомлений натяжки — когда класс уведомления загружен (вместе с монтажом лука), один раз на запуск; глобальные защёлки —
-- чтобы повторная загрузка мода не удвоила их (EXP-0348). Begin: (MeshComp, Animation, TotalDuration, …); End: (MeshComp, Animation, …).
local function hook_charge_notifies(cls)
    local key = "__krinik_hooked_" .. cls
    if _G[key] then return end
    _G[key] = true
    for _, ev in ipairs({ "Received_NotifyBegin", "Received_NotifyEnd" }) do
        local ok, err = pcall(function()
            RegisterHook(cls .. ":" .. ev, function(ctx, mesh, anim, total)
                local fn = ev == "Received_NotifyBegin" and _G.__krinik_charge_begin_fn or _G.__krinik_charge_end_fn
                if fn then
                    local ok2, e2 = pcall(fn, mesh:get(), cls, total and total:get())
                    if not ok2 and errors < 5 then errors = errors + 1; log("ошибка натяжки: %s", tostring(e2)) end
                end
            end)
        end)
        log(ok and "натяжка: перехват %s %s поставлен" or ("натяжка: перехват %s %s не встал — " .. tostring(err)), cls:match("[^.]+$"), ev)
    end
end
for _, cls in ipairs({ POWER_CHARGE, CHARGE_HOLD }) do
    NotifyOnNewObject(cls, function() ExecuteInGameThread(function() hook_charge_notifies(cls) end) end)
end

-- ------------------------------------------------------------- стрельба в прыжке (W14, KUMM план 37)
-- `[OWNER]` «стрельба в прыжке - одна из важнейших фисек Обливион» · «хватало бы, чтобы просто тело героя взлетало в воздух» · «Если герой уже
-- летит в воздухе и игрок делает или ПКМ с луком, или ЛКМ - то нужно сразу в воздухе начинать соответствующие действия по луку» · «если …
-- посреди стрельбы приходит дейсввие ПРЫЖОК - то герой должен продолжать стрельбу, но герой взмывает в воздух» · 2026-10-28.
-- Два родных запрета (байткод 3.0.1, 2026-10-30, KUMM games/ConanExiles/GAME_ARCHITECTURE_INTERNAL_MAP.md):
--  1. BaseBPCombat::ActionTry отказывает в атаке при подсостоянии 8 (падение). Перехват UE4SS на чертёжной функции срабатывает ПОСЛЕ её тела —
--     поэтому подсостояние снимаем раньше, в момент отрыва от земли (HandleOnMovementModeChanged → режим 3), только у героя с луком в руках.
--  2. BasePlayerChar::CanJumpInternal = родное И не подсостояние 13 И не IsAttacking() — натяжка лука считается атакой, прыжка нет. Ответ
--     функции перехватом не подменить (её зовёт C++, перехват не срабатывает) — поэтому после отказанного StartJump герой с луком, который
--     атакует, стоит на земле и не устал (подсостояния 13, 14, 18 — запреты игры по делу), получает толчок LaunchCharacter со скоростью
--     своего прыжка JumpZVelocity (420). Опыт пультом 2026-10-30 10:52–10:58: выстрел в воздухе, натяжка в прыжке не рвётся, руки стреляют.
-- Лук в руках = прикреплённый к герою актёр с «bow» в имени класса на гнезде не «sheath» (в руке Socket_Bow, за спиной sheath_bow).
-- Ноль опроса: два события на прыжок.
-- [TESTED: 2026-10-30 · кейсы M1–M5 настоящим вводом: выстрел в воздухе, толчок посреди натяжки, контроль «лук за спиной» · KUMM testcases/reports/2026-10-30_conan-jump-shooting-0.7.0.md]
CFG.jump_shooting = true
local COMBAT_CLASS = "/Game/Characters/BaseBPCombat.BaseBPCombat_C"
local SUB_FALLING, MODE_FALLING = 8, 3
local JUMP_BLOCKERS = { 13, 14, 18 }   -- подсостояния, при которых прыжок запрещён по делу (в т. ч. 14 — усталость)

local function bow_in_hand(c)
    local arr = {}
    c:GetAttachedActors(arr, true, false)
    for i = 1, #arr do
        local a = arr[i]:get()
        if a:IsValid() and a:GetClass():GetFName():ToString():lower():find("bow", 1, true) then
            return not a:GetAttachParentSocketName():ToString():lower():find("sheath", 1, true)
        end
    end
    return false
end

local function in_substate(c, s)
    local out = {}
    c:InSubstate(s, out)
    return out.Success == true
end

local jumps_launched, air_unlocked = 0, 0
local function on_movement_mode(ctx)
    local c = ctx:get()
    if not c:IsPlayerControlled() or c.CharacterMovement.MovementMode ~= MODE_FALLING then return end
    if not bow_in_hand(c) then return end
    c:ExitSubstate(SUB_FALLING, {})
    air_unlocked = air_unlocked + 1
    if air_unlocked <= CFG.log_shots then log("прыжок с луком: выстрел в воздухе разрешён (%d)", air_unlocked) end
end

local function on_start_jump(ctx)
    local c = ctx:get()
    if not c:IsPlayerControlled() then return end
    local m = c.CharacterMovement
    if not m:IsMovingOnGround() or c:CanJump() then return end    -- родной прыжок уже был или герой не на земле
    local att = {}
    c:IsAttacking(att)
    if att.IsAttacking ~= true or not bow_in_hand(c) then return end
    for _, s in ipairs(JUMP_BLOCKERS) do if in_substate(c, s) then return end end
    c:LaunchCharacter({ X = 0, Y = 0, Z = m.JumpZVelocity }, false, true)
    jumps_launched = jumps_launched + 1
    if jumps_launched <= CFG.log_shots then log("прыжок посреди натяжки: толчок %.0f см/с (%d)", m.JumpZVelocity, jumps_launched) end
end

_G.__krinik_mm_fn, _G.__krinik_jump_fn = on_movement_mode, on_start_jump
if CFG.jump_shooting then
    NotifyOnNewObject(FOV_CONTROLLER, function()
        ExecuteInGameThread(function()
            if _G.__krinik_jump_hooked then return end
            _G.__krinik_jump_hooked = true
            for fn, key in pairs({ HandleOnMovementModeChanged = "__krinik_mm_fn", StartJump = "__krinik_jump_fn" }) do
                local ok, err = pcall(function()
                    RegisterHook(COMBAT_CLASS .. ":" .. fn, function(ctx)
                        local f = _G[key]
                        if f then
                            local ok2, e2 = pcall(f, ctx)
                            if not ok2 and errors < 5 then errors = errors + 1; log("ошибка прыжка (%s): %s", fn, tostring(e2)) end
                        end
                    end)
                end)
                log(ok and "прыжок: перехват %s поставлен" or ("прыжок: перехват %s не встал — " .. tostring(err)), fn)
            end
        end)
    end)
end

-- Одна подписка на весь запуск. Появление компонента — во время конструирования, поэтому работа — на ближайшем тике.
NotifyOnNewObject(PROJECTILE_CLASS, function(comp)
    ExecuteInGameThread(function() guarded(comp) end)
end)
log("0.3.0: выстрел из лука в точку щупа камеры (%s); прицел после выстрела %s", PROJECTILE_CLASS, CFG.keep_aim and "держим" or "выкл")
