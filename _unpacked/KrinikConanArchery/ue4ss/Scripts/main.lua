--[==[===========================================================================
  KrinikConanArchery 1.0.0 — лук героя: стрела из лука в точку прицела, вид стрелы и прицела
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
    mesh_scale      = 3.0,     -- «до x3» (×9 «ракета» была от двух копий мода, не от числа)
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
    into_body       = true,    -- п. 42: воткнутую в существо стрелу досылаем внутрь тела
    into_body_cm    = 15.0,    -- на сколько копию досылаем в тело за точку удара о физическое тело — НИЖНЯЯ граница; вкус — глаз владельца
    -- W13 (2026-10-31): игра ставит копию в ImpactPoint — на поверхность физического тела, у каппы он толще шкуры (байткод
    -- BP_BaseProjectile.SpawnDummyProjectile). Досылаем до глубины кости удара по ходу стрелы: проекция кости на линию полёта, в пределах
    -- [into_body_cm, into_body_max_cm].
    -- 10:34: на гуманоиде кость вышла ≥ 60 см впереди начала копии — начало сетки стрелы на одном её конце, сетка ≈ 76 см по местной Z
    -- (проба кита 10:39). Поэтому досыл считаем от НАКОНЕЧНИКА: наконечник = начало копии + длина сетки × (местная Z · ход стрелы).
    -- Стенд 2026-10-31 10:57–10:59 (каппа, три попадания): начало копии стоит на 180–187 см ПЕРЕД точкой удара — копия рождается там, где
    -- стрела была до последнего шага полёта, кость головы — на 237 см; кадр сбоку: стрела висит в воздухе перед мордой. Ведём наконечник
    -- к ТОЧКЕ УДАРА и на tip_in_cm глубже (к кости — нельзя: у головы каппы стрела ушла бы в тушу целиком).
    into_body_max_cm = 200.0,
    -- Наконечник относительно точки удара (минус — не доходя). Точка удара, которую отдаёт игра, лежит ГЛУБЖЕ кожи: по кадрам сбоку
    -- (длина стрелы 76 см — масштаб) кожа ближе неё на 21 см (бедро человека), 27 (грудь), 39 (морда каппы); с +10 стрела прошивала бедро
    -- и грудь насквозь (стенд 11:33, 11:36). −15: наконечник встаёт в 6–24 см под кожей. Вкус — глаз владельца.
    tip_in_cm       = -15.0,
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
-- <игра>\ConanSandbox\Saved\KrinikSettings.lua, ключи arc_ballistics → CFG.ballistics, arc_nobreak → CFG.no_break, arc_fov → CFG.aim_fov_deg
-- (нет ключа — свои значения ниже). Читается при загрузке и при смене общего номера KrinikSettingsVersion — сверка на каждой стреле и прицеле,
-- в те же моменты, когда эти значения и читаются; своего таймера нет. [NOT-TESTED]
local ARC_DEFAULTS = { ballistics = CFG.ballistics, no_break = CFG.no_break, aim_fov_deg = CFG.aim_fov_deg }
local ARC_KEYS = { arc_ballistics = "ballistics", arc_nobreak = "no_break", arc_fov = "aim_fov_deg" }
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
    log("настройки окна: баллистика %s, стрелы не ломаются %s, обзор %.0f° (%s)", tostring(CFG.ballistics), tostring(CFG.no_break), CFG.aim_fov_deg, why)
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

-- ------------------------------------------------------------ вид стрелы
local function dress_arrow(actor)
    arc_settings_check()
    if CFG.no_break then actor.CanBreakOnImpact = false end
    local mesh = actor:GetComponentByClass(StaticFindObject(MESH_CLASS))
    if mesh and mesh:IsValid() then mesh:SetRelativeScale3D(scaled(mesh.RelativeScale3D, CFG.mesh_scale)) end
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

-- ------------------------------------------- воткнутая стрела — в тушку
-- План 36 п. 42: `[OWNER]` «нужно понять, чем вызвано втыкание стрел в воздух вокруг моба, визуально некрасиво это, тоже нужно
-- починить. головка стрелы должна внутрь тушки прятаться» · 2026-10-27 19:1x. Воткнутая копия `BP_DummyProjectile` встаёт в точке
-- удара и цепляется к телу существа (журнал 19:21: «удар в CharacterMesh0, прицеплена к CharacterMesh0»). Здесь копия, прицепленная
-- к телу существа (не игрока), досылается по ходу стрелы внутрь. Урон — родной, уже нанесён; трогаем только вид. [TESTED: 2026-10-31 · каппа (голова, рука) и жители (бедро, грудь), кадры сбоку в 4K · KUMM testcases/reports/2026-10-31_conan-arrow-push-tip-to-impact.md]
local DUMMY_CLASS = "/Game/Items/Weapons/BP_DummyProjectile.BP_DummyProjectile_C"
local stuck_logged = 0

local dummies_seen = 0

local function sink_into_body(dummy)
    if not dummy:IsValid() then return end
    local cap = dummy.HitResultFromProjectile.Component:Get()
    -- Журнал первых копий: прогон 2026-10-27 19:17 не дал ни одной строки — видно ли событие и во что бьётся стрела (кейс AIM20).
    if dummies_seen < CFG.log_shots then
        dummies_seen = dummies_seen + 1
        local par = dummy.RootComponent:GetAttachParent()
        log("копия стрелы #%d: удар в %s (%s), кость удара %s, прицеплена к %s, сокет %s", dummies_seen,
            (cap and cap:IsValid()) and cap:GetFName():ToString() or "ничто",
            (cap and cap:IsValid()) and cap:GetClass():GetFName():ToString() or "-",
            dummy.HitResultFromProjectile.BoneName:ToString(),
            (par and par:IsValid()) and par:GetFName():ToString() or "ничему",
            dummy.RootComponent:GetAttachSocketName():ToString())
    end
    -- Прогон 19:21: у каппы стрела бьёт в тело (`CharacterMesh0`, физические тела скелета) и копия прицеплена к нему, капсула ни при
    -- чём. Физические тела толще шкуры — копия встаёт на их поверхности, «в воздухе». Досылаем её по ходу стрелы на into_body_cm внутрь;
    -- прицепка к телу остаётся прежней (K2_SetActorLocation у прицепленного актёра правит его относительное место).
    if not cap or not cap:IsValid() or not cap:GetClass():GetFName():ToString():find("SkeletalMesh", 1, true) then return end
    local mob = cap:GetOwner()
    if not mob or not mob:IsValid() or not mob:IsA(StaticFindObject("/Script/Engine.Character")) or mob:IsPlayerControlled() then return end
    local v = dummy.ProjectileVelocityOnImpact
    local speed = math.sqrt(dot(v, v))
    if speed < 1.0 then return end
    local at = dummy:K2_GetActorLocation()
    at = { X = at.X, Y = at.Y, Z = at.Z }              -- вектор из вызова копируем в числа сразу (EXP-0403, чтения векторов пульта)
    -- Глубина кости удара по линии полёта: у толстого физического тела (каппа) копия стоит далеко от кости — досыл ограничен ею. [TESTED: 2026-10-31 · каппа (голова, рука) и жители (бедро, грудь), кадры сбоку в 4K · KUMM testcases/reports/2026-10-31_conan-arrow-push-tip-to-impact.md]
    -- Наконечник: начало копии + длина сетки × (её местная Z · ход стрелы). Знак Z не угадываем — читаем; точку удара пишем в журнал
    -- рядом, чтобы прогон сам показал, где наконечник стоит относительно неё (стенд W13, 2026-10-31).
    local len = CFG.arrow_len_cm
    local okm, mn, mx = pcall(function()
        local b = dummy.StaticMeshToShow:GetBoundingBox()
        return b.Min.Z, b.Max.Z
    end)
    if okm and mn and mx and mx - mn > 10 then len = mx - mn end
    local along = 1.0
    local oku, uz = pcall(function()
        local u = dummy.RootComponent:GetUpVector()
        return (u.X * v.X + u.Y * v.Y + u.Z * v.Z) / speed
    end)
    if oku and uz then along = uz end
    local tip = len * along
    local imp = dummy.HitResultFromProjectile.ImpactPoint
    local imp_ahead = ((imp.X - at.X) * v.X + (imp.Y - at.Y) * v.Y + (imp.Z - at.Z) * v.Z) / speed
    -- наконечник — к точке удара со сдвигом tip_in_cm, но не дальше кости удара (стенд 11:33 — плотник, бедро, досыл 121 при кости на 188 см:
    -- наконечник ушёл за середину кости и вышел из ноги с другой стороны). Если наконечник уже дальше — прежний минимальный досыл.
    local want = imp_ahead - tip + CFG.tip_in_cm
    local depth = -1.0
    local bone = dummy.HitResultFromProjectile.BoneName
    local okb, bl = pcall(function() local s = cap:GetSocketLocation(bone); return { X = s.X, Y = s.Y, Z = s.Z } end)
    if okb and bl then
        depth = ((bl.X - at.X) * v.X + (bl.Y - at.Y) * v.Y + (bl.Z - at.Z) * v.Z) / speed
        want = math.min(want, depth - tip)
    end
    local push = math.max(CFG.into_body_cm, math.min(CFG.into_body_max_cm, want))
    dummy:K2_SetActorLocation(add(at, scaled(v, push / speed)), false, {}, true)
    -- Игра сама цепляет копию к кости удара (прогон 2026-10-29 11:01: «кость удара rig_bone_L_leg_J01 … сокет rig_bone_L_leg_J01») —
    -- стрела ходит с той частью тела, в которую попала; кость пишется в журнал ради разбора стрел «в воздухе» у каппы (план 36 W13).
    if stuck_logged < CFG.log_shots then
        stuck_logged = stuck_logged + 1
        log("в тушку: %s — стрела дослана на %.0f см внутрь (кость по линии полёта %.0f см, наконечник %.0f см = сетка %.0f × %.2f, точка удара %.0f см), кость %s",
            mob:GetClass():GetFName():ToString(), push, depth, tip, len, along, imp_ahead, dummy.RootComponent:GetAttachSocketName():ToString())
    end
end

-- Копия цепляется к телу в своём BeginPlay; работаем через 100 мс, когда она уже на месте (поля копии живы, это не уборка).
NotifyOnNewObject(DUMMY_CLASS, function(dummy)
    if not CFG.into_body then return end
    -- уведомление о новом объекте приходит не обязательно в игровом потоке: туда — одним прыжком, задержка — уже там (EXP-0062)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(100, function()
            local ok, err = pcall(sink_into_body, dummy)
            if not ok and errors < 5 then errors = errors + 1; log("ошибка «в тушку»: %s", tostring(err)) end
        end)
    end)
end)

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
    if v == FOV_AIM then aim_deg_last = c.FieldOfViewTarget end
    -- Новое натяжение при зажатой ПКМ (CFG.hold_aim_on_redraw): цель 0 сразу после прицела — конец уведомления старого монтажа; новое придёт
    -- следом. Номер и угол цели — обратно на прицел здесь же, до тика контроллера: кадра отъезда нет. Отпускание ПКМ выводит из прицела как
    -- прежде (release_aim видит номер 1). [NOT-TESTED]
    if CFG.hold_aim_on_redraw and v == FOV_DEFAULT and was == FOV_AIM and aim_deg_last and rmb_held(c) then
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
