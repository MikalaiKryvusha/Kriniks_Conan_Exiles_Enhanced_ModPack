--[[
  KrinikConanUI:HudBlink — голод, жажда и вес начинают мерцать заранее: тускло у порога, к пределу — во всю яркость (KUMM план 36 W36).

  Слово владельца 2026-10-30 ≈14:23: «в моде ХУД - мерцать голодом, жаждой и весом нужно на 20% быстрее» · «а начинать тускло мерчать нужно на 10% -
  для голода и жажды, и на 10% от макс веса - для веса.» · «тускло и по мере приближения к 0% - на полную яркость».

  Как устроен HUD Hosav (конспект KUMM games/ConanExiles/mods/UIMod_Hosav.md): родной код мигает только на пределе — еда/вода ровно 0 %
  (Progress_Food / Progress_Drink), вес ≥ максимума (Get_WeightText): PlayAnimation(NoFood | NoWater | OverEncumbered_Weight, по кругу, скорость
  0.30 — правка пака, было 0.25) и свой флаг In…Animation. Анимации цветовые: еда и вода — рамка значка белая → красная (≈0.5 с) → белая,
  вес — красная картинка, прозрачность 0 → 1 → 0.

  Этот раздел ведёт участок ДО предела: еда/вода от 10 % до 0 %, вес от 90 % до 100 % максимума. Тусклость — без перекраски: та же анимация
  играется туда-обратно (PingPong) только по началу кривой, до доли L её середины, L = 0.25 у порога → 1.0 у предела; скорость × L, поэтому
  период мигания тот же, что у полного (≈3.3 с при 0.30). Флаг Hosav раздел не трогает: на пределе мигание отдаёт родному коду, после предела
  родной код делает один обратный проход и гасит флаг — раздел при следующем опросе снова ставит своё мигание.

  Опрос — раз в 250 мс на игровом потоке: несколько чтений полей, вызов анимации только при смене ступени яркости (10 ступеней). Событий
  «еда изменилась» у BP_HungerSystem в известной карте нет — [AI] решение, как у счётчика кадров. Самозамер: сумма и худший вызов раз в минуту.
  [TESTED: 2026-10-30 · H1–H10 в игре: тусклое с порога, полное у предела, скорость 0.30 · KUMM testcases/reports/2026-10-30_conan-hud-blink-early.md]
]]

local MOD = "KrinikConanUI:HudBlink"
local HUD_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_NewHealthUI.W_NewHealthUI_C"
local POLL_MS = 250
local ATTACH_DELAY_MS = 600          -- дерево HUD достраивается не в тот же кадр, что создание (как у раздела обводки)
local FOOD_ZONE = 0.10               -- «на 10% - для голода и жажды»
local WEIGHT_ZONE = 0.90             -- «на 10% от макс веса»: последние 10 % до предела
-- Оба порога — значения по умолчанию: игрок меняет их шкалами хаба «Моды Krinik'а» (ключи ui_blink_food, ui_blink_weight; KUMM план 38 этап 2),
-- опрос читает хранилище каждый раз (поиск в таблице — без цены). [NOT-TESTED]
local settings = require("krinik_settings")
local DIM = 0.25                     -- яркость у порога ([AI] — на глаз владельца)
local SPEED = 0.30                   -- скорость полного мигания (правка пака Hosav, KUMM план 36 W36)
local STEPS = 10                     -- ступени яркости: анимация перезапускается только при смене ступени
local PINGPONG = 2                   -- EUMGSequencePlayMode::PingPong
local STAT_WEIGHT = 12               -- GetFloatStat(12, 0) — текущий вес героя (Get_WeightText Hosav)
local SUMMARY_S = 60

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end

local smooth = nil
local last = {}                      -- имя анимации → ступень, 'bp' (мигает родной код) или nil
local stats = { n = 0, sum = 0.0, worst = 0.0, plays = 0, last = os.clock() }

local function valid(o) return o ~= nil and o:IsValid() end

-- Ступень яркости по доле пути к пределу: d = 0 у порога … 1 у предела.
local function level(d)
    local b = DIM + (1.0 - DIM) * d
    return math.max(1, math.min(STEPS, math.ceil(b * STEPS - 1e-6)))
end

local function apply(name, anim, step)
    local prev = last[name]
    if step == prev then return end
    if step == 'bp' then last[name] = 'bp'; return end          -- предел: мигание родного кода, не мешать
    if step == nil then
        if type(prev) == 'number' then smooth:StopAnimation(anim) end   -- RestoreState: цвет вернётся к исходному
        last[name] = nil; return
    end
    local L = step / STEPS
    local half = anim:GetEndTime() * 0.5
    smooth:PlayAnimationTimeRange(anim, 0.0, half * L, 0, PINGPONG, SPEED * L, true)
    stats.plays = stats.plays + 1
    log("%s: яркость %.1f (конец кривой %.3f с)", name, L, half * 2)
    last[name] = step
end

local function tick()
    if not valid(smooth) then return end
    local pawn = smooth:GetOwningPlayerPawn()
    if not valid(pawn) then return end
    local t0 = os.clock()
    local hs = pawn.BP_HungerSystem
    if valid(hs) then
        for _, s in ipairs({ { "NoFood", hs.FoodCurrent, hs.FoodMax }, { "NoWater", hs.DrinkCurrent, hs.DrinkMax } }) do
            local v = (s[3] and s[3] > 0) and (s[2] / s[3]) or 1.0
            local step
            local zone = settings.get("ui_blink_food", FOOD_ZONE)
            if v <= 0 then step = 'bp' elseif v <= zone then step = level(1.0 - v / zone) end
            apply(s[1], smooth[s[1]], step)
        end
    end
    local es = pawn.BP_EncumbranceSystem
    if valid(es) then
        local max = es:GetEncumbranceMax()
        local r = (max and max > 0) and (pawn:GetFloatStat(STAT_WEIGHT, 0) / max) or 0.0
        local step
        local wz = math.min(0.99, settings.get("ui_blink_weight", WEIGHT_ZONE))
        if r >= 1.0 then step = 'bp' elseif r >= wz then step = level((r - wz) / (1.0 - wz)) end
        apply("OverEncumbered_Weight", smooth.OverEncumbered_Weight, step)
    end
    local dt = (os.clock() - t0) * 1000.0
    stats.n = stats.n + 1; stats.sum = stats.sum + dt; if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S then
        log("минута: опросов %d, всего %.3f мс, худший %.3f мс, запусков анимации %d", stats.n, stats.sum, stats.worst, stats.plays)
        stats.n, stats.sum, stats.worst, stats.plays, stats.last = 0, 0.0, 0.0, 0, os.clock()
    end
end

-- Живой W_SmoothHP — переменная виджета того HUD, что родился: FindFirstOf('W_SmoothHP_C') отдаёт ШАБЛОН из класса HUD
-- (`…W_NewHealthUI_C:WidgetTree.W_SmoothHP`), у которого анимации никто не видит (прогон 2026-10-30 14:44 — ни одной строки мигания при воде 2 %).
NotifyOnNewObject(HUD_CLASS_PATH, function(hud)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(ATTACH_DELAY_MS, function() pcall(function()
            if not valid(hud) then return end
            smooth = hud.W_SmoothHP
            last = {}
            log("HUD: %s", valid(smooth) and smooth:GetFullName() or "W_SmoothHP не найден")
        end) end)
    end)
end)

LoopInGameThreadWithDelay(POLL_MS, function() pcall(tick) end)
log("загружен: еда и вода с %d %%, вес с %d %% максимума, тускло %.2f → полная, скорость %.2f", FOOD_ZONE * 100, WEIGHT_ZONE * 100, DIM, SPEED)
