-- KrinikConanBench — облёт мира камерой по маршруту для замера рывков (бенчмарк), прибор агента; в сборку владельца не едет.
-- [NOT-TESTED]
-- Слово владельца 2026-10-25 вечером: «научиться делать бенч - летать камерой по миру, как сделали в Обливионе» · «чтобы облёт
-- был зрелищным» · «на 2 минуты, но чтобы побывать и увидеть красивые места». Образец — бенчмарк OblvBench из
-- github.com/LTSharpe/OblivionRemasteredPerformanceFix (MIT), `mods/ue4ss/OblvBench/Scripts/{main,bench}.lua`.
--
-- Вторая версия — после замечаний владельца к облётам 20:53 и 20:59: «ты не убрал героя» · «ты не включил бессмертие» ·
-- «ты врезаешься в скалы» · «не выключил интерфейсы» · «счётчик кадров можно было бы не скрывать» · «движение в бенче обливиона
-- медленнее и более плавное, камера летает, как птица - а у тебя с резкими поворотами, по прямой линии». Первая версия вела
-- самого героя (режим Flying + скорость) — у Провала его держала река, у Безымянного города скалы: облёт стоял по 45 с.
-- Теперь как у OblvBench: отдельная камера-актёр (CameraActor + SetViewTarget), перемещение без физики (K2_TeleportTo — без
-- 'Out'-параметра), положение и поворот сглажены (SmoothDamp; поворот — два каскада, чтобы и скорость поворота менялась плавно),
-- взгляд — на точку пути впереди. Герой спрятан, бессмертен, без столкновений и переносится под камеру (мир подгружается вокруг
-- него), после облёта — на своё место. Интерфейс игры свёрнут, кроме нашего счётчика кадров (KrinikFpsCounter).
-- Покадровый шаг — LoopInGameThreadAfterFrames(1, …) на игровом потоке (у OblvBench LoopAsync + ExecuteInGameThread «тихо
-- убивал» полёт: два потока делят одно состояние Lua).
--
-- Команды — строки в ue4ss/Mods/KrinikConanBench/bench-cmd.txt (журнал — bench.log рядом, время — os.clock()):
--   pos                         позиция и курс героя → bench.log и bench-pos.txt (снимать точки маршрута)
--   fly <имя>                   маршрут из routes.lua
--   fly speed=<см/с> x,y,z x,y,z …   маршрут прямо в строке (подбор)
--   stop                        прервать облёт
-- Метки: «EV fly=start <сек>» (начало замеряемого отрезка) и «EV fly=done» — по ним _config/bench-flight.sh мерит PresentMon.

local DIR = "ue4ss/Mods/KrinikConanBench/"
local CMD = DIR .. "bench-cmd.txt"
local LOG = DIR .. "bench.log"
local POLL_S = 0.05
-- Зависание на первой точке, пока мир подгружается; метка начала (и с ней PresentMon, видео) — только после него.
-- `[OWNER]` «в начале бенча на стартовой позиции нужно постоять 30 секунд - просто дать игре подгрузить локацию» · «только затем
-- включать логи, запись видео и начинать пролёт» · 2026-10-25 21:13 (3 с — облёт 21:07 начался с 19 к/с). Маршрут может задать своё `hold`.
local HOLD_S = 30.0
-- взгляд на точку пути через столько секунд полёта: 1,5 с — камера смотрела в ближние скалы; владелец 21:44 «просторы
-- красивейшие в игре! а ты камеру в стену и в камни направляешь!» — смотреть дальше, на горизонт
local LOOK_S = 3.0
local ROT_TAU = 0.8           -- с, сглаживание поворота камеры (на два каскада)
local POS_TAU = 0.25          -- с, сглаживание положения (высота над рельефом меняется ступенями)
local PITCH_BIAS = -6.0       -- град, взгляд чуть вниз, на землю
local CLEARANCE = 3500        -- см над землёй
-- с вперёд по пути, где мерить землю лучом: каждые 0,5 с на 4 с — при трёх лучах (0; 1; 2,5) узкая башня Архивов проскочила
-- между ними, и камера вошла в неё (облёт 21:07, два последних кадра)
local GROUND_AHEAD = { 0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0 }
-- Высота — огибающая, а не слежение (замечание владельца к облёту 21:07: «местами есть сильные качания камеры по высоте вверх -
-- вниз - не хватает более сильного сглаживания»): подъём заранее (максимум рельефа на 4 с вперёд) и за Z_UP_TAU, спуск — медленно,
-- за Z_DOWN_TAU, плюс своё сглаживание высоты камеры POS_Z_TAU.
local Z_UP_TAU, Z_DOWN_TAU = 0.7, 5.0     -- подъём быстрее (1,2 с — камера входила в скалы, облёт 21:35)
local POS_Z_TAU = 0.9
-- Крен и тангаж, «как самолёта» (слово владельца там же: «не хватает наклонов камеры, как самолёта - то в сторону качнуться, то по
-- тангажу»): крен — от скорости поворота, тангаж — добавка от набора и снижения высоты; оба сглажены.
local BANK_PER_DEG_S = 0.6    -- град крена на 1 град/с поворота
local BANK_MAX = 18.0
local BANK_TAU = 0.7
local CLIMB_PITCH_K = 0.8     -- доля угла набора высоты, которая уходит в тангаж
local TRACE_UP, TRACE_DOWN = 60000, 120000
local PAWN_EVERY_S = 0.25     -- как часто переносить героя к камере
-- Герой НАД камерой, в воздухе: под камерой над рекой он оказался под водой и утонул (облёт 21:35 — флаг урона от утопления
-- не защищает); после смерти игра создала новый HUD (интерфейс вернулся) и вид ушёл на игровую камеру.
-- 3 м было мало: невидимого героя видели мобы и бросались «на камеру» (бенч 22:09, слово владельца «мобов не отключил агрессию -
-- по-прежнему на камеру кидаются»; админская MakeMeInvisible не подействовала). 80 м над камерой — в воздухе, вне досягаемости.
local PAWN_ABOVE = 8000
-- Тангаж — в коридоре (слово владельца 21:37: «слишком высоко вверх нос не поднимай, ровно как и слишком низко - не красивые кадры»)
local PITCH_MIN, PITCH_MAX = -14.0, 4.0
local UI_RECHECK_S = 2.0      -- новые виджеты (игра создаёт их по ходу) — тоже свернуть
-- Посадка героя после облёта (см. land_frame): висеть над домом, пока луч от места героя вниз не найдёт землю
local LAND_HOVER = 300         -- см над домом, пока земля не подгрузилась
local LAND_PROBE_UP, LAND_PROBE_DOWN = 150, 3000   -- луч: от чуть выше места героя до 30 м ниже
local LAND_ABOVE_HOME = 20     -- см: ставим на прежнее место чуть выше, падение само опустит на землю
local LAND_TIMEOUT_S = 20.0
local MOVE_FALLING, MOVE_FLYING = 3, 5
local HIT, IGNORE, NOCOLOR = {}, {}, { R = 0, G = 0, B = 0, A = 0 }   -- одна таблица результата на все лучи (утечка UE4SS < 1181)

local function log(s)
    local f = io.open(LOG, "a")
    if f then f:write(("%.3f %s\n"):format(os.clock(), s)); f:close() end
    print("[KrinikConanBench] " .. s .. "\n")
end

local ok_routes, ROUTES = pcall(dofile, DIR .. "Scripts/routes.lua")
if not ok_routes then ROUTES = {}; log("routes.lua не прочитан: " .. tostring(ROUTES)) end

local function pc() local p = FindFirstOf("PlayerController"); return p and p:IsValid() and p or nil end
local function pawn() local p = pc(); local w = p and p.Pawn; return w and w:IsValid() and w or nil end
local function ksl() return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end
local function gps() return StaticFindObject("/Script/Engine.Default__GameplayStatics") end
local function norm(a) a = (a + 180) % 360; return a - 180 end
local function console(line)
    local p = pc()
    if p then ksl():ExecuteConsoleCommand(p, line, p) end
end

-- Unity-style SmoothDamp (как в OblvBench): критическое затухание, скорость непрерывна
local function smooth(cur, target, vel, tau, dt)
    if tau <= 0 or dt <= 0 then return target, 0 end
    local omega = 2 / tau
    local x = omega * dt
    local e = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x)
    local change = cur - target
    local temp = (vel + omega * change) * dt
    vel = (vel - omega * temp) * e
    return target + (change + temp) * e, vel
end

-- ---------------------------------------------------------------- маршрут: сплайн Catmull-Rom, длина дуги, точка на ней
local SAMPLES = 16
local function spline(points)
    if #points < 3 then return points end
    local out = {}
    local function P(i) return points[math.max(1, math.min(#points, i))] end
    for i = 1, #points - 1 do
        local p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        for s = 0, SAMPLES - 1 do
            local t = s / SAMPLES
            local t2, t3 = t * t, t * t * t
            local q = {}
            for k = 1, #p1 do              -- x, y, z и (если задан) зазор точки
                q[k] = 0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                       + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3)
            end
            out[#out + 1] = q
        end
    end
    out[#out + 1] = points[#points]
    return out
end

-- Длина дуги и РАСПИСАНИЕ: у каждой точки своя скорость (5-е значение), между точками — среднее. Время до каждой точки
-- считается заранее, поэтому прогон повторяем: та же секунда — то же место.
-- Скорость по точкам — слово владельца к бенчу 22:09: «когда вверх над рекой поднимаешься, то зачем-то скорость снижаешь на
-- пикировании вниз - нужно наоборот ускоряться, так как на высоте скорость слабее чувствуется».
-- Скорость — ПО ЗЕМЛЕ (горизонтальная): разведка после правки скоростей показала, что на горке над рекой камера шла вперёд
-- 9–10 м/с вместо 16 — путь в 3D съедал подъём (вертикаль до 17 м/с), и владелец снова увидел торможение («ну опять при
-- снижении скорость замедлилась»). Время участка — горизонтальный путь / скорость; вертикаль не быстрее самой скорости.
local function build(points)
    local acc, tt, total, time = { 0 }, { 0 }, 0, 0
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local seg = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
        local ground = math.max(math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2), math.abs(b[3] - a[3]))
        total = total + seg
        time = time + ground / math.max(100, (a[5] + b[5]) / 2)
        acc[i], tt[i] = total, time
    end
    return acc, total, tt, time
end

-- Расстояние по пути в момент t (по расписанию tt)
local function dist_at(acc, tt, t)
    if t <= 0 then return 0 end
    for i = 2, #tt do
        if t <= tt[i] then
            local span = tt[i] - tt[i - 1]
            local k = span > 0 and (t - tt[i - 1]) / span or 1
            return acc[i - 1] + (acc[i] - acc[i - 1]) * k
        end
    end
    return acc[#acc]
end

-- Точка пути на расстоянии d: x, y, z и зазор над препятствием (4-е значение точки маршрута, иначе CLEARANCE)
local function at(points, acc, d)
    d = math.max(0, math.min(acc[#acc], d))
    for i = 2, #points do
        if d <= acc[i] or i == #points then
            local a, b = points[i - 1], points[i]
            local seg = acc[i] - acc[i - 1]
            local t = seg > 0 and math.min(1, math.max(0, (d - acc[i - 1]) / seg)) or 0
            local ca, cb = a[4] or CLEARANCE, b[4] or CLEARANCE
            local va, vb = a[5] or 0, b[5] or 0
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, ca + (cb - ca) * t,
                   va + (vb - va) * t
        end
    end
end

-- Луч по каналу видимости между двумя точками: Z точки попадания (и её X, Y) или nil
local function trace(p, ax, ay, az, bx, by, bz)
    local hit = ksl():LineTraceSingle(p, { X = ax, Y = ay, Z = az }, { X = bx, Y = by, Z = bz },
        0, false, IGNORE, 0, HIT, true, NOCOLOR, NOCOLOR, 0.0)
    if hit then local i = HIT.ImpactPoint; return i.Z, i.X, i.Y end
    return nil
end

-- Сколько надо подняться над задуманной высотой pz в точке (x, y), чтобы не врезаться, — или 0.
-- Проём (арка, ворота) против скалы (замечание владельца к облёту 21:18: «ну вот была арка!!! Нужно было через неё пролететь!
-- … А ты почему-то вверх ушел»): луч сверху вниз видит верх арки так же, как верх скалы. Различает луч ВПЕРЁД по ходу —
-- от прошлой точки пути к этой на задуманной высоте: чист, а под точкой свободно (луч вниз с самой высоты пути) — проём,
-- летим сквозь; упёрся — твёрдое, перелетаем с зазором clr.
local OPENING_FLOOR = 300     -- см: проём, только если под точкой пути свободно хотя бы столько
local function lift_need(p, px, py, pz, x, y, z, clr)
    local top = trace(p, x, y, z + TRACE_UP, x, y, z - TRACE_DOWN)
    local need = 0
    -- упор луча вперёд: верх препятствия — в самой точке удара (тонкая стена между точками пути: облёт 21:26, 104–108 с,
    -- камера вошла в ржавую стену, потому что за стеной, в следующей точке, земля снова низко)
    local hz, hx, hy
    if px then hz, hx, hy = trace(p, px, py, pz, x, y, z) end
    if hz then
        local wall = trace(p, hx, hy, z + TRACE_UP, hx, hy, z - TRACE_DOWN)
        if wall then need = math.max(need, wall + clr - z) end
    end
    if not top or top + clr <= z then return need end
    local below = trace(p, x, y, z + 50, x, y, z - TRACE_DOWN)
    if not hz and below and below + OPENING_FLOOR <= z then return need end
    return math.max(need, top + clr - z)
end

-- ---------------------------------------------------------------- интерфейс: всё свернуть, кроме счётчика кадров
local FPS_TEXT = "KrinikFpsText"
local VIS_COLLAPSED, VIS_HIDDEN, VIS_HIT_TEST_INVISIBLE = 1, 2, 3   -- ESlateVisibility
local HUD_CLASS = "W_NewHealthUI_C"   -- HUD Hosav: на его холсте стоит счётчик — сворачиваются дети холста, кроме счётчика

local function hide_ui()
    local list = {}
    local function collapse(w)
        local v = w:GetVisibility()
        if v ~= 1 then list[#list + 1] = { w, v }; w:SetVisibility(1) end
    end
    for _, u in ipairs(FindAllOf("UserWidget") or {}) do
        local ok, shown = pcall(function() return u:IsInViewport() end)
        if ok and shown then
            if u:GetClass():GetFName():ToString() == HUD_CLASS then
                local root = u.WidgetTree.RootWidget
                for i = 0, root:GetChildrenCount() - 1 do
                    local c = root:GetChildAt(i)
                    if c:GetFName():ToString() ~= FPS_TEXT then
                        collapse(c)
                    elseif c:GetVisibility() == VIS_COLLAPSED or c:GetVisibility() == VIS_HIDDEN then
                        -- счётчик держим видимым на любом HUD: владелец 2026-10-25 — «в первом пролёте у тебя фпс счетчик был, во
                        -- вторых двух - не было. Чем-то они различались» (в облётах B и C игра пересоздала HUD на 111 с) [NOT-TESTED]
                        c:SetVisibility(VIS_HIT_TEST_INVISIBLE)
                    end
                end
            else
                collapse(u)
            end
        end
    end
    return list
end

local function restore_ui(list)
    for _, e in ipairs(list or {}) do pcall(function() if e[1]:IsValid() then e[1]:SetVisibility(e[2]) end end) end
end

-- ---------------------------------------------------------------- камера
local function spawn_camera(p)
    local cm = p.PlayerCameraManager
    local loc, rot = cm:GetCameraLocation(), cm:GetCameraRotation()
    local xf = { Rotation = { X = 0, Y = 0, Z = 0, W = 1 }, Translation = { X = loc.X, Y = loc.Y, Z = loc.Z }, Scale3D = { X = 1, Y = 1, Z = 1 } }
    local a = gps():BeginDeferredActorSpawnFromClass(p, StaticFindObject("/Script/Engine.CameraActor"), xf, 1, nil, 1)
    a = gps():FinishSpawningActor(a, xf, 1)
    a:K2_TeleportTo(loc, rot)
    -- вид как у игровой камеры: поле зрения с менеджера камеры (постобработку мира дают объёмы уровня, а не камера)
    pcall(function() a.CameraComponent.FieldOfView = cm:GetFOVAngle() end)
    pcall(function() a.CameraComponent.bConstrainAspectRatio = false end)
    return a
end

-- ---------------------------------------------------------------- облёт
local fly = nil
local landing = nil   -- посадка героя после облёта (end_flight → land_frame)

local function start_flight(name, points, speed, opts)
    local w, p = pawn(), pc()
    if not w or not p then log("нет героя — облёт не начат") return end
    if #points < 2 then log("в маршруте меньше двух точек") return end
    -- Повторяемость (слово владельца 2026-10-25 21:10: «для воспроизводимости бенча нужно добавить - одинаковую погоду
    -- принудительно включать, и одинаковое время дня»): время суток и погода ставятся до зависания на первой точке.
    opts = opts or {}
    if opts.time then console("SetTimeOfDay " .. opts.time); log("время суток: SetTimeOfDay " .. opts.time) end
    if opts.clear then console("dw.DisableWeatherSystem 1"); log("погода: dw.DisableWeatherSystem 1 (ясно)") end
    local m = w.CharacterMovement
    local home = w:K2_GetActorLocation()
    local saved = { collision = w:GetActorEnableCollision(), damage = w.bCanBeDamaged,
                    home = { X = home.X, Y = home.Y, Z = home.Z } }
    w.bCanBeDamaged = false                 -- бессмертие: консольная God на героя Конана не действует (облёт 20:53)
    -- Мобы не видят героя (слово владельца 22:01: «в бенче нужно отключать агрессию мобов на героя - а то они нападают на камеру»):
    -- админская невидимость Конана для NPC; после облёта — обратно. [NOT-TESTED]
    console("MakeMeInvisible")
    w:SetActorHiddenInGame(true)
    w:SetActorEnableCollision(false)
    m:SetMovementMode(MOVE_FLYING, 0)
    local hidden = hide_ui()
    local cam = spawn_camera(p)
    p:SetViewTargetWithBlend(cam, 0, 0, 0, false)
    local norm_pts = {}
    -- сплайну нужны точки одной длины: x, y, z, зазор, скорость
    for i, q in ipairs(points) do norm_pts[i] = { q[1], q[2], q[3], q[4] or CLEARANCE, q[5] or speed } end
    points = spline(norm_pts)
    local acc, total, tt, time = build(points)
    local x, y, z = at(points, acc, 0)
    w:K2_TeleportTo({ X = x, Y = y, Z = z + PAWN_ABOVE }, { Pitch = 0, Yaw = 0, Roll = 0 })
    fly = { name = name, points = points, acc = acc, total = total, speed = speed, tt = tt, time = time, t0 = os.clock(), phase = "hold",
            pawn = w, ui_at = os.clock(),
            hold = tonumber(opts.hold) or HOLD_S,
            saved = saved, hidden = hidden, cam = cam, zoff = 0, last = os.clock(), pawn_at = 0, lifts = 0,
            c = nil }
    log(("облёт %s: %d точек сплайна, %.0f м, %.1f м/с в среднем, полёт %.1f с после %.1f с зависания; свернуто элементов интерфейса %d"):format(
        name, #points, total / 100, total / time / 100, time, fly.hold, #hidden))
end

local function end_flight(reason)
    local f = fly
    fly = nil
    if not f then return end
    local w, p = pawn(), pc()
    if p and w then pcall(function() p:SetViewTargetWithBlend(w, 0, 0, 0, false) end) end
    if f.cam and f.cam:IsValid() then pcall(function() f.cam:K2_DestroyActor() end) end
    if w then
        -- Посадка: герой висит над своим местом без столкновений, пока земля там не подгрузится, и только потом становится
        -- на неё (land_frame ниже). Владелец 2026-10-25: «в конце бенча есть проблема - что герой куда-то под текстуры
        -- проваливается» — дом в километрах от конца облёта, земли под ним в момент переноса ещё нет. [NOT-TESTED]
        local h = f.saved.home
        pcall(function() w:K2_TeleportTo({ X = h.X, Y = h.Y, Z = h.Z + LAND_HOVER }, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
        pcall(function() w.CharacterMovement.Velocity = { X = 0, Y = 0, Z = 0 } end)
        pcall(function() w:SetActorHiddenInGame(false) end)
        landing = { w = w, home = h, saved = f.saved, t0 = os.clock() }
    end
    restore_ui(f.hidden)
    pcall(console, "MakeMeVisible")
    log(("EV fly=done %s (%s), кадров с подъёмом над рельефом %d"):format(f.name, reason, f.lifts))
end

-- Каждый кадр после облёта: герой держится в воздухе над домом (полёт, скорость 0), луч вниз ищет землю у дома; нашёл (или прошло
-- LAND_TIMEOUT_S) — столкновения и падение возвращаются, уязвимость — как была.
local function land_frame(now)
    local L = landing
    if not L then return end
    local w, p = pawn(), pc()
    if not w or w ~= L.w or not p then landing = nil return end
    local h = L.home
    -- луч от самого места героя вниз (не сверху: дома под крышей сверху попадём в крышу); столкновения героя выключены
    local ground = trace(p, h.X, h.Y, h.Z + LAND_PROBE_UP, h.X, h.Y, h.Z - LAND_PROBE_DOWN)
    local waited = now - L.t0
    if ground or waited >= LAND_TIMEOUT_S then
        landing = nil
        pcall(function() w:K2_TeleportTo({ X = h.X, Y = h.Y, Z = h.Z + LAND_ABOVE_HOME }, { Pitch = 0, Yaw = 0, Roll = 0 }) end)
        pcall(function() w.CharacterMovement.Velocity = { X = 0, Y = 0, Z = 0 } end)
        pcall(function() w:SetActorEnableCollision(L.saved.collision ~= false) end)
        pcall(function() w.CharacterMovement:SetMovementMode(MOVE_FALLING, 0) end)
        pcall(function() w.bCanBeDamaged = L.saved.damage end)
        log(("EV land %s через %.1f с, земля %s"):format(ground and "на землю" or "без земли (время вышло)", waited,
            ground and ("%.0f"):format(ground) or "?"))
        return
    end
    pcall(function() w.CharacterMovement:SetMovementMode(MOVE_FLYING, 0) end)
    pcall(function() w.CharacterMovement.Velocity = { X = 0, Y = 0, Z = 0 } end)
end

local function frame(now)
    local f = fly
    if not f then return end
    local w, p = pawn(), pc()
    if not w or not p or not f.cam:IsValid() then end_flight("герой или камера пропали") return end
    if w ~= f.pawn then end_flight("герой сменился — смерть? замер недействителен") return end
    if now - f.ui_at >= UI_RECHECK_S then
        f.ui_at = now
        for _, e in ipairs(hide_ui()) do f.hidden[#f.hidden + 1] = e end
    end
    local dt = math.min(0.1, math.max(0.001, now - f.last))
    f.last = now
    local t = now - f.t0
    local d = 0
    if f.phase == "hold" then
        -- t = 0: секунды полёта считаются от метки начала (до правки 2026-10-25 вечером t оставалось 30 с зависания, и первая
        -- запись prog ждала t=31 — 31 с полёта, старт и арка, без замера)
        if t >= f.hold then f.phase = "run"; f.t0 = now; t = 0; log(("EV fly=start %.1f"):format(f.time)) end
    else
        if t >= f.time then end_flight("маршрут пройден") return end
        d = dist_at(f.acc, f.tt, t)
    end
    local _, _, _, _, vnow = at(f.points, f.acc, d)   -- скорость в этой точке пути: по ней — сколько метров «вперёд» смотреть
    vnow = math.max(100, vnow)
    -- где быть: точка пути + подъём над рельефом (земля здесь и впереди, лучами)
    local x, y, z = at(f.points, f.acc, d)
    local need = 0
    local px, py, pz
    for _, ahead in ipairs(GROUND_AHEAD) do
        local gx, gy, gz, clr = at(f.points, f.acc, d + vnow * ahead)
        need = math.max(need, lift_need(p, px, py, pz, gx, gy, gz, clr))
        px, py, pz = gx, gy, gz
    end
    -- луч вперёд от самой камеры (а не от задуманного пути): высота догоняет рельеф с запаздыванием, и камера входила в камни
    if f.c then
        local ax, ay, az = at(f.points, f.acc, d + vnow * 1.2)
        local hz, hx, hy = trace(p, f.c.x, f.c.y, f.c.z, ax, ay, f.c.z)
        if hz then
            local wall = trace(p, hx, hy, f.c.z + TRACE_UP, hx, hy, f.c.z - TRACE_DOWN)
            if wall then need = math.max(need, wall + CLEARANCE * 0.5 - z) end
        end
    end
    local ztau = need > f.zoff and Z_UP_TAU or Z_DOWN_TAU
    f.zoff = f.zoff + (need - f.zoff) * math.min(1, dt / ztau)
    if need > 0 then f.lifts = f.lifts + 1 end
    z = z + f.zoff
    -- куда смотреть: точка пути впереди (с тем же подъёмом)
    local lx, ly, lz = at(f.points, f.acc, d + vnow * LOOK_S)
    lz = lz + f.zoff
    local tyaw = math.deg(math.atan(ly - y, lx - x))
    local tpitch = math.deg(math.atan(lz - z, math.sqrt((lx - x) ^ 2 + (ly - y) ^ 2))) + PITCH_BIAS
    local c = f.c
    if not c then
        c = { x = x, y = y, z = z, vx = 0, vy = 0, vz = 0, yaw = tyaw, pitch = tpitch, vyaw = 0, vpitch = 0,
              s1y = tyaw, s1vy = 0, s1p = tpitch, s1vp = 0, roll = 0, vroll = 0 }
        f.c = c
    else
        c.x, c.vx = smooth(c.x, x, c.vx, POS_TAU, dt)
        c.y, c.vy = smooth(c.y, y, c.vy, POS_TAU, dt)
        c.z, c.vz = smooth(c.z, z, c.vz, POS_Z_TAU, dt)
        -- тангаж: добавка от набора/снижения высоты (нос вверх на подъёме)
        tpitch = tpitch + CLIMB_PITCH_K * math.deg(math.atan(c.vz, vnow))
        tpitch = math.max(PITCH_MIN, math.min(PITCH_MAX, tpitch))
        local tau = ROT_TAU / 2             -- два каскада: и угол, и скорость поворота меняются плавно
        c.s1y, c.s1vy = smooth(c.s1y, c.s1y + norm(tyaw - c.s1y), c.s1vy, tau, dt)
        c.s1p, c.s1vp = smooth(c.s1p, tpitch, c.s1vp, tau, dt)
        c.yaw, c.vyaw = smooth(c.yaw, c.yaw + norm(c.s1y - c.yaw), c.vyaw, tau, dt)
        c.pitch, c.vpitch = smooth(c.pitch, c.s1p, c.vpitch, tau, dt)
        -- крен: в сторону поворота, от его скорости (c.vyaw, град/с)
        local troll = math.max(-BANK_MAX, math.min(BANK_MAX, c.vyaw * BANK_PER_DEG_S))
        c.roll, c.vroll = smooth(c.roll, troll, c.vroll, BANK_TAU, dt)
    end
    f.cam:K2_TeleportTo({ X = c.x, Y = c.y, Z = c.z }, { Pitch = c.pitch, Yaw = c.yaw % 360, Roll = c.roll })
    -- Раз в секунду — где камера: кадр видео на секунде t сопоставляется с точкой карты, и маршрут правится по увиденному
    -- (слово владельца 21:22: «ты мог бы кадры из видео смотреть и понимать, на какой секунде куда тебе лететь»)
    if f.phase == "run" and t >= (f.prog_at or 0) then
        f.prog_at = math.floor(t) + 1
        -- gnd — верх рельефа под камерой: по нему задуманная высота точек маршрута ставится «земля + сколько нужно»
        -- (облёт 21:26: высоты точек оказались под землёй, и проём арки не распознался)
        local gnd = trace(p, c.x, c.y, c.z + TRACE_UP, c.x, c.y, c.z - TRACE_DOWN)
        log(("EV fly=prog t=%d cam=%.0f,%.0f,%.0f gnd=%s yaw=%.0f pitch=%.0f roll=%.0f lift=%.0f"):format(
            math.floor(t), c.x, c.y, c.z, gnd and ("%.0f"):format(gnd) or "?", c.yaw % 360, c.pitch, c.roll, f.zoff))
    end
    if p.PlayerCameraManager.ViewTarget.Target ~= f.cam then p:SetViewTargetWithBlend(f.cam, 0, 0, 0, false) end
    if now - f.pawn_at >= PAWN_EVERY_S then
        f.pawn_at = now
        w.CharacterMovement.Velocity = { X = 0, Y = 0, Z = 0 }
        w:K2_TeleportTo({ X = c.x, Y = c.y, Z = c.z + PAWN_ABOVE }, { Pitch = 0, Yaw = c.yaw % 360, Roll = 0 })
    end
end

-- ---------------------------------------------------------------- команды
local function parse_inline(rest)
    local speed = tonumber(rest:match("speed=(%d+)")) or 1500
    local pts = {}
    for tok in rest:gmatch("%S+") do
        local v = {}
        for n in tok:gmatch("[^,]+") do v[#v + 1] = tonumber(n) end
        if #v >= 3 and v[1] and v[2] and v[3] then pts[#pts + 1] = v end   -- x,y,z[,зазор]
    end
    return pts, speed
end

local function run(cmd)
    local verb, rest = cmd:match("^(%S+)%s*(.*)$")
    if verb == "pos" then
        local w, p = pawn(), pc()
        if not w then log("pos: нет героя") return end
        local l, r = w:K2_GetActorLocation(), p:GetControlRotation()
        local s = ("%.0f,%.0f,%.0f yaw=%.1f"):format(l.X, l.Y, l.Z, r.Yaw)
        if fly and fly.c then s = s .. (" cam=%.0f,%.0f,%.0f"):format(fly.c.x, fly.c.y, fly.c.z) end
        log("pos " .. s)
        local f = io.open(DIR .. "bench-pos.txt", "a"); if f then f:write(s .. "\n"); f:close() end
    elseif verb == "fly" and rest:find(",") then
        local pts, speed = parse_inline(rest)
        start_flight("строка", pts, speed, { hold = tonumber(rest:match("hold=(%d+)")) })
    elseif verb == "fly" then
        -- маршруты перечитываются на каждый облёт: правка точек — без перезапуска игры (цикл «разведка → правка точек»)
        local ok_r, fresh = pcall(dofile, DIR .. "Scripts/routes.lua")
        if ok_r and type(fresh) == "table" then ROUTES = fresh else log("routes.lua не перечитан: " .. tostring(fresh)) end
        local name, opt = rest:match("^(%S+)%s*(.*)$")
        local r = ROUTES[name]
        if not r then log("нет маршрута " .. tostring(name)) return end
        -- hold=N — только для подбора маршрута; замер идёт с зависанием маршрута (по умолчанию 30 с, слово владельца 21:13)
        local hold = tonumber((opt or ""):match("hold=(%d+)")) or r.hold
        start_flight(name, r.points, r.speed, { time = r.time, clear = r.clear, hold = hold })
    elseif verb == "stop" then
        end_flight("команда stop")
    else
        log("не понял: " .. cmd)
    end
end

local next_poll = 0
local function poll(now)
    if now < next_poll then return end
    next_poll = now + POLL_S
    local f = io.open(CMD, "r")
    if not f then return end
    local text = f:read("*a") or ""
    f:close()
    os.remove(CMD)
    for line in text:gmatch("[^\r\n]+") do
        local c = line:match("^%s*(.-)%s*$")
        if c ~= "" then
            local ok, err = pcall(run, c)
            if not ok then log("ошибка команды «" .. c .. "»: " .. tostring(err)) end
        end
    end
end

-- Ошибка покадрового кода — в журнал, не чаще раза в секунду; облёт при ошибке прерывается и всё возвращается как было
local err_at = 0
local ok_loop, why = pcall(LoopInGameThreadAfterFrames, 1, function()
    local now = os.clock()
    local ok, err = pcall(function() poll(now); frame(now); land_frame(now) end)
    if not ok then
        if now - err_at > 1 then err_at = now; log("ошибка кадра: " .. tostring(err)) end
        pcall(end_flight, "ошибка кадра")
    end
end)
log(ok_loop and "загружен: покадровый цикл в игровом потоке, жду команд в " .. CMD
            or "НЕТ покадрового цикла (LoopInGameThreadAfterFrames): " .. tostring(why))
