--[[
  KrinikConanUI:Vignette — сила виньеток по краю экрана: голод, жажда, мало здоровья; шкала у каждой, крайнее левое положение — выключено
  (KUMM plans/40_epic40_phase1_vignettes.md).

  Слово владельца 2026-10-30 ≈08:25: «мерцающая виньетка вокруг контура хкрана при голобе, жажде или нижком здоровье - должна интенсивность
  регулироваться ползунком. Крайнее левое положение ползунков - ВЫКЛ полный соответствующей виньетки» · 2026-11-01 13:20: «по умолчанию в поставлке
  сборки виньетки голота и жажды ВЫКЛ, виньетка нижкого здоровья тусклая, типа 10% или на каком значении она едва заметна».

  Как рисует игра (разведка KUMM researches/conan-vignettes/README.md, живые пробы 2026-11-01 13:3x–13:5x):
  - контейнер W_FullScreenEffectContainer_C держит эффекты W_FullScreenBuffEffect_C; что рисует эффект — видно по кисти его Image:
    MID_HealthScreenEffectMat — кровь по краям при ранении (виджет живёт с рождения HUD, игра пишет параметр Intensity: 0 при полном здоровье,
    0.3 при 60 %, 0.7 при 15 %); T_BuffFullScreenEffect_HungerThirst — тёмная рамка, ОДНА текстура на голод и на жажду, новый виджет на каждое
    «умирает от голода / жажды».
  - Сила = RenderOpacity корня эффекта: игра его не трогает (кадры при 15 % здоровья: 1.0 — полная рамка, 0.1 — едва заметна, 0 — нет).
  - Голод от жажды по кисти не отличить, а поле Buff и обход отражения этого класса из Lua роняют игру (падения 13:31 и 13:52) — поэтому вид
    решается в миг рождения по запасам героя: еда 0 — голод, вода 0 — жажда, обе 0 — бо́льшая из двух сил.

  События, без опроса (HOUSE_RULES правило 7): рождение HUD Hosav (+600 мс, как у соседних разделов) — подписка на рождение эффектов (класс к этому
  мигу уже загружен: контейнер жив) и сила живым эффектам; рождение эффекта (+200 мс — кисть ставится после создания); «Сохранить» хаба —
  S.on_change, сила всем живым. Самозамер: сумма и худший вызов, строка раз в минуту, только если были вызовы.
  [TESTED: 2026-11-01 · живая игра, путь игрока: голод и жажда по умолчанию 0.00, здоровье 0.10 при входе, шкала голода мышью 50 → 100 → 0 и
   «Сохранить» — сила живого эффекта следом, перезапуск хранит 0.50 · KUMM testcases/reports/2026-11-01_conan-vignettes.md; пропорция на глаз
   и сила здоровья по умолчанию — выбор владельца, папка отсмотра 48]
]]

local MOD = "KrinikConanUI:Vignette"
local HUD_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_NewHealthUI.W_NewHealthUI_C"
local EFFECT_CLASS_PATH = "/Game/UI/HUD/W_FullScreenBuffEffect.W_FullScreenBuffEffect_C"
local ATTACH_DELAY_MS = 600       -- дерево HUD достраивается не в тот же кадр, что создание
local BRUSH_DELAY_MS = 200        -- кисть эффекта ставится после NotifyOnNewObject
local SUMMARY_S = 60
-- Силы по умолчанию — поставка сборки (слово владельца 13:20): голод и жажда выключены, здоровье едва заметно.
-- Здоровье 0.25 — `[OWNER]` 2026-11-01 14:34 по кадрам папки отсмотра 48 (0 / 5 / 10 / 15 / 25 %): «ставь 25%, потом я буду играть и глаами найду
-- желаемое знаечение» (до этого стояло [AI] 0.10).
local DEFAULT = { hunger = 0.0, thirst = 0.0, health = 0.25 }
local KEY = { hunger = "ui_vig_hunger", thirst = "ui_vig_thirst", health = "ui_vig_health" }

local settings = require("krinik_settings")

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

-- полное имя эффекта → { w = виджет, kind = health | hunger | thirst | both }. Не таблица со слабыми ключами: обёртку UObject из UE4SS сборщик
-- мусора Lua уносит сразу, и «Сохранить» находил ноль живых (прогон 2026-11-01, первое сохранение); мёртвые записи выбрасываются при применении.
local live = {}
local subscribed = false
local stats = { n = 0, sum = 0.0, worst = 0.0, last = os.clock() }

local function measure(t0)
    local dt = (os.clock() - t0) * 1000.0
    stats.n = stats.n + 1; stats.sum = stats.sum + dt; if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S then
        log("минута: %d вызовов, всего %.3f мс, худший %.3f мс", stats.n, stats.sum, stats.worst)
        stats.n, stats.sum, stats.worst, stats.last = 0, 0.0, 0.0, os.clock()
    end
end

local function strength(kind)
    if kind == "both" then return math.max(strength("hunger"), strength("thirst")) end
    local k = tonumber(settings.get(KEY[kind], DEFAULT[kind])) or DEFAULT[kind]
    return math.max(0.0, math.min(1.0, k))
end

local function apply(w, kind)
    local k = strength(kind)
    w:SetRenderOpacity(k)
    return k
end

-- Вид эффекта по кисти и, для голода и жажды, по запасам героя в миг рождения. nil — не наш (жара, холод, дым — их не трогаем).
local function kind_of(w)
    local r = w.Image.Brush.ResourceObject
    if not valid(r) then return nil end
    local name = r:GetFName():ToString()
    if name:find("HealthScreenEffectMat", 1, true) then return "health" end
    if not name:find("HungerThirst", 1, true) then return nil end
    local pawn = w:GetOwningPlayerPawn()
    local hs = valid(pawn) and pawn:GetHungerSystem() or nil
    if not valid(hs) then return "both" end
    local food0, drink0 = hs.FoodCurrent <= 0, hs.DrinkCurrent <= 0
    if food0 and not drink0 then return "hunger" end
    if drink0 and not food0 then return "thirst" end
    return "both"
end

local function take(w)
    if not valid(w) or w:GetFullName():find("Default__", 1, true) then return end
    local t0 = os.clock()
    local kind = kind_of(w)
    if kind then
        live[w:GetFullName()] = { w = w, kind = kind }
        log("виньетка %s: сила %.2f (%s)", kind, apply(w, kind), w:GetFName():ToString())
    end
    measure(t0)
end

local function on_effect(w)
    ExecuteInGameThreadWithDelay(BRUSH_DELAY_MS, function()
        local ok, e = pcall(take, w)
        if not ok then log("ошибка: %s", tostring(e)) end
    end)
end

NotifyOnNewObject(HUD_CLASS_PATH, function(hud)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(ATTACH_DELAY_MS, function()
            local ok, e = pcall(function()
                if not subscribed then
                    NotifyOnNewObject(EFFECT_CLASS_PATH, on_effect)
                    subscribed = true
                    log("подписка на рождение эффектов поставлена")
                end
                -- эффекты, родившиеся раньше подписки (здоровье — с рождения HUD). Живой эффект принадлежит экземпляру игры
                -- (`…BP_ConanGameInstance_C_<n>.W_FullScreenBuffEffect_C_<n>`), не дереву виджетов; шаблон в чужом классе — `…_C:WidgetTree.<имя>`
                -- (EXP-0421) — отбрасываем его. Фильтр «WidgetTree_<n>.» отбросил бы все живые (прогон 2026-11-01 14:01).
                for _, w in ipairs(FindAllOf("W_FullScreenBuffEffect_C") or {}) do
                    if not w:GetFullName():find(":WidgetTree.", 1, true) then take(w) end
                end
            end)
            if not ok then log("ошибка при рождении HUD: %s", tostring(e)) end
        end)
    end)
end)

settings.on_change(function(changed)
    if changed[KEY.hunger] == nil and changed[KEY.thirst] == nil and changed[KEY.health] == nil then return end
    local t0 = os.clock()
    local n = 0
    for name, e in pairs(live) do
        if valid(e.w) then apply(e.w, e.kind); n = n + 1 else live[name] = nil end
    end
    log("сохранено: голод %.2f, жажда %.2f, здоровье %.2f — применено к %d", strength("hunger"), strength("thirst"), strength("health"), n)
    measure(t0)
end)

log("загружен: голод %.2f, жажда %.2f, здоровье %.2f", strength("hunger"), strength("thirst"), strength("health"))
