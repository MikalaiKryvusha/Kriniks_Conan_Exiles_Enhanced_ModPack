--[[
  KrinikConanUI:HudBlink — голод, жажда и вес начинают мерцать заранее: едва заметно у порога, к пределу — во всю силу (KUMM план 36 W36).

  Слово владельца 2026-10-30 ≈14:23: «в моде ХУД - мерцать голодом, жаждой и весом нужно на 20% быстрее» · «а начинать тускло мерчать нужно на 10% -
  для голода и жажды, и на 10% от макс веса - для веса.» · «тускло и по мере приближения к 0% - на полную яркость».
  Уточнение 2026-11-01 11:54: «мерчание голода и жажды неправильное» · «на 10% должно быть в едва заметный нежный розовый, и чем ближе к 0%, тем
  насыщеннее красный».

  Как устроен HUD Hosav (конспект KUMM games/ConanExiles/mods/UIMod_Hosav.md): родной код мигает только на пределе — еда/вода ровно 0 %
  (Progress_Food / Progress_Drink), вес ≥ максимума (Get_WeightText): PlayAnimation(NoFood | NoWater | OverEncumbered_Weight, по кругу, скорость
  0.30 — правка пака, было 0.25). Анимации цветовые: еда и вода — ContentColorAndOpacity рамки значка (Border_EatImage / Border_WaterImage) белая →
  красная (≈0.5 с) → белая; вес — Image_Weight_Blinking, красная, прозрачность 0 → 1 → 0.

  Почему не анимацией (до 2026-11-01 раздел играл её PingPong по началу кривой, PlayAnimationTimeRange(…, 0, 0.5 × L, …)): игра НЕ держит конец
  отрезка — замер пультом 2026-11-01 11:57: при конце 0.15 с цвет рамки дошёл до G 0.10 (почти полный красный) и с бесконечным, и с 1000 повторами;
  ролик всех ступеней показал полный красный на каждой (KUMM testcases/reports/2026-11-01_conan-hud-blink-all-steps-video.md). Поэтому ниже порога
  раздел сам ведёт цвет: пульс (1 − cos) / 2 с периодом родного мигания (1 / 0.30 ≈ 3.3 с), пик — от PEAK_MIN у порога до 1 у предела; для еды и
  воды пик — насколько рамка уходит от белого к красному (в sRGB, чтобы «едва заметно» было едва заметно на глаз), для веса — прозрачность красной
  картинки. Выше порога рамка возвращается к белому, картинка веса — к прозрачной.
  На самом пределе (еда/вода 0 %, вес ≥ максимума) — тот же наш пульс с пиком 1, родная анимация Hosav остановлена: она стартует в миг, когда значок
  дошёл до предела, и два значка на пределе мигали в разных фазах. Слово владельца 2026-11-03 19:41 (его кадр: вода 0 %, вес 102 %): «мерцают
  крассным в рассинхрон» · «Нужно синхронизировать, чтобы слушались одну шину» · «мерцание должно быть синхронным». Шина — одна фаза
  os.clock() % PERIOD_S на все значки (paint_all).
  [TESTED: 2026-11-03 · вода 0 % и вес 102 %: 12 из 12 замеров одна доля красного, родные анимации стоят; еда 5 % — та же фаза; ролик 60 к/с ·
   KUMM testcases/reports/2026-11-03_conan-hud-blink-one-bus.md]

  Опрос запаса — раз в 250 мс; цикл цвета — шаг PULSE_MS, живёт, только пока хоть один значок ниже порога и выше предела. Событий «еда изменилась»
  у BP_HungerSystem в известной карте нет — [AI] решение, как у счётчика кадров. Самозамер: сумма и худший вызов раз в минуту, опрос и цвет отдельно.
  [TESTED: 2026-11-01 · живая игра: пик красного по пикселям 44 → 127 от 9.7 % к 0.7 % (было ≈ 120 на каждом), вес 93 % — прозрачность 0 → 0.40 → 0,
   выход из 0 % — родная анимация остановлена, пульс до полного красного · KUMM testcases/reports/2026-11-01_conan-hud-blink-all-steps-video.md]
  Открыто: худший шаг 3–6 мс раз в минуту при среднем 0.1 мс — и в опросе, и у раздела криков; игра в фоне, os.clock — настенные часы; честный замер
  худшего кадра — блок замеров кадров (STATUS).
]]

local MOD = "KrinikConanUI:HudBlink"
local HUD_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_NewHealthUI.W_NewHealthUI_C"
local POLL_MS = 250
local PULSE_MS = 50                  -- шаг цвета 20 раз в секунду: пульс в 3.3 с идёт без заметных ступенек
local ATTACH_DELAY_MS = 600          -- дерево HUD достраивается не в тот же кадр, что создание (как у раздела обводки)
local FOOD_ZONE = 0.10               -- «на 10% - для голода и жажды»
local WEIGHT_ZONE = 0.90             -- «на 10% от макс веса»: последние 10 % до предела
-- Оба порога — значения по умолчанию: игрок меняет их шкалами хаба «Моды Krinik'а» (ключи ui_blink_food, ui_blink_weight; KUMM план 38 этап 2),
-- опрос читает хранилище каждый раз (поиск в таблице — без цены).
local settings = require("krinik_settings")
local PEAK_MIN = 0.15                -- пик у порога: «едва заметный нежный розовый» ([AI] число — на глаз владельца)
local PERIOD_S = 1.0 / 0.30          -- период родного мигания Hosav (скорость 0.30 по кривой в 1 с)
local STAT_WEIGHT = 12               -- GetFloatStat(12, 0) — текущий вес героя (Get_WeightText Hosav)
local SUMMARY_S = 60

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local smooth = nil
-- значок → пик (число 0…1 — ведёт раздел), 'bp' (предел — мигает родной код) или nil (выше порога)
local peak = { food = nil, water = nil, weight = nil }
local logged = { food = nil, water = nil, weight = nil }   -- последняя десятая доля пика в журнале
local pulsing = false
-- Две корзины: опрос запаса и шаг цвета — худший вызов каждой отдельно (всплески 3–4 мс 2026-11-01 надо отнести к своему месту).
local stats = { poll = { n = 0, sum = 0.0, worst = 0.0 }, pulse = { n = 0, sum = 0.0, worst = 0.0 }, last = os.clock() }

local function measure(t0, kind)
    local dt = (os.clock() - t0) * 1000.0
    local s = stats[kind]
    s.n = s.n + 1; s.sum = s.sum + dt; if dt > s.worst then s.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S then
        local p, q = stats.poll, stats.pulse
        log("минута: опрос %d вызовов, всего %.3f мс, худший %.3f мс · цвет %d шагов, всего %.3f мс, худший %.3f мс",
            p.n, p.sum, p.worst, q.n, q.sum, q.worst)
        for _, b in ipairs({ p, q }) do b.n, b.sum, b.worst = 0, 0.0, 0.0 end
        stats.last = os.clock()
    end
end

-- Доля пути к красному k (0 — белый, 1 — красный) в линейный зелёный и синий: UMG считает цвет линейным, глаз видит sRGB.
local function lin(srgb) return srgb ^ 2.2 end

-- Одна таблица цвета на значок на всю жизнь раздела: новый литерал 30 раз в секунду — мусор, а сборка мусора Lua дала всплески 3–4 мс
-- в минутной сводке (2026-11-01 12:1x).
local COL = { food = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }, water = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 },
              weight = { R = 1.0, G = 0.0, B = 0.0, A = 0.0 } }

local function paint(name, k)
    local c = COL[name]
    if name == "weight" then
        c.A = k
        smooth.Image_Weight_Blinking:SetColorAndOpacity(c)
    else
        local g = lin(1.0 - k)
        c.G = g; c.B = g
        if name == "food" then smooth.Border_EatImage:SetContentColorAndOpacity(c) else smooth.Border_WaterImage:SetContentColorAndOpacity(c) end
    end
end

-- Без замыкания на каждый шаг (pcall с именованной функцией): ни одного нового объекта Lua 20 раз в секунду.
local function paint_all()
    if not valid(smooth) then return false end
    local any = false
    local p = (1.0 - math.cos(2.0 * math.pi * (os.clock() % PERIOD_S) / PERIOD_S)) * 0.5
    for name, v in pairs(peak) do
        if type(v) == "number" then any = true; paint(name, v * p) end
    end
    return any
end

local function pulse_step()
    local t0 = os.clock()
    local ok, any = pcall(paint_all)
    any = ok and any
    measure(t0, "pulse")
    if any then ExecuteInGameThreadWithDelay(PULSE_MS, pulse_step) else pulsing = false end
end

-- Родная анимация значка (Hosav). Пока значок в зоне раздела, она стоит: анимация веса после первого прохода числится «играющей» на последнем
-- кадре и каждый кадр пишет прозрачность 0 (замер 2026-11-01 12:05: наш цвет держался 0.00, после StopAnimation — пульс 0 → 0.40 → 0); после
-- предела Hosav делает обратный проход еды и воды — он тоже перебил бы пульс.
local ANIM = { food = "NoFood", water = "NoWater", weight = "OverEncumbered_Weight" }

-- Новый пик значка: уход выше порога возвращает родной вид, на пределе цвет отдаёт родной анимации.
local function set_peak(name, v)
    local prev = peak[name]
    peak[name] = v
    if type(v) == "number" then
        local anim = smooth[ANIM[name]]
        if smooth:IsAnimationPlaying(anim) then smooth:StopAnimation(anim); log("%s: родная анимация остановлена", name) end
    end
    if type(prev) == "number" and v == nil then paint(name, 0.0) end
    if type(v) == "number" then
        local tenth = math.floor(v * 10 + 0.5)
        if tenth ~= logged[name] then log("%s: пик %.1f", name, v); logged[name] = tenth end
        if not pulsing then pulsing = true; ExecuteInGameThreadWithDelay(PULSE_MS, pulse_step) end
    else
        if v ~= prev then log("%s: %s", name, v == 'bp' and "предел — мигает игра" or "выше порога"); logged[name] = nil end
    end
end

-- Пик по доле пути от порога к пределу: d = 0 у порога … 1 у предела.
local function peak_of(d) return PEAK_MIN + (1.0 - PEAK_MIN) * math.max(0.0, math.min(1.0, d)) end

local function tick()
    if not valid(smooth) then return end
    local pawn = smooth:GetOwningPlayerPawn()
    if not valid(pawn) then return end
    local t0 = os.clock()
    local hs = pawn.BP_HungerSystem
    if valid(hs) then
        local zone = settings.get("ui_blink_food", FOOD_ZONE)
        for _, s in ipairs({ { "food", hs.FoodCurrent, hs.FoodMax }, { "water", hs.DrinkCurrent, hs.DrinkMax } }) do
            local v = (s[3] and s[3] > 0) and (s[2] / s[3]) or 1.0
            local p
            if v <= 0 then p = 1.0 elseif v <= zone then p = peak_of(1.0 - v / zone) end
            set_peak(s[1], p)
        end
    end
    local es = pawn.BP_EncumbranceSystem
    if valid(es) then
        local max = es:GetEncumbranceMax()
        local r = (max and max > 0) and (pawn:GetFloatStat(STAT_WEIGHT, 0) / max) or 0.0
        local wz = math.min(0.99, settings.get("ui_blink_weight", WEIGHT_ZONE))
        local p
        if r >= 1.0 then p = 1.0 elseif r >= wz then p = peak_of((r - wz) / (1.0 - wz)) end
        set_peak("weight", p)
    end
    measure(t0, "poll")
end

-- Живой W_SmoothHP — переменная виджета того HUD, что родился: FindFirstOf('W_SmoothHP_C') отдаёт ШАБЛОН из класса HUD
-- (`…W_NewHealthUI_C:WidgetTree.W_SmoothHP`), у которого анимации никто не видит (прогон 2026-10-30 14:44 — ни одной строки мигания при воде 2 %).
NotifyOnNewObject(HUD_CLASS_PATH, function(hud)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(ATTACH_DELAY_MS, function() pcall(function()
            if not valid(hud) then return end
            smooth = hud.W_SmoothHP
            peak = { food = nil, water = nil, weight = nil }
            logged = { food = nil, water = nil, weight = nil }
            log("HUD: %s", valid(smooth) and smooth:GetFullName() or "W_SmoothHP не найден")
        end) end)
    end)
end)

LoopInGameThreadWithDelay(POLL_MS, function() pcall(tick) end)
log("загружен: еда и вода с %d %%, вес с %d %% максимума, пик %.2f → 1, период %.1f с, свой пульс цвета", FOOD_ZONE * 100, WEIGHT_ZONE * 100,
    PEAK_MIN, PERIOD_S)
