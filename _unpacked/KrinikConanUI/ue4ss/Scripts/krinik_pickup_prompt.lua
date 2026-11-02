--[[
  KrinikConanUI:PickupPrompt — лёгкая подсказка «E Взять», когда перед героем лежит то, что игра даёт поднять по E: камни, ветки, волокно, ягоды,
  грибы, водоросли, личинки, перья, яйца, паутина (KUMM plans/42_conan_pickup_prompt_foliage.md).

  Слово владельца 2026-11-01 21:14–21:34: «при наведении на палки, на траву, на камень - писать тонкий виджет E Поднять» · «меня бесит, что я навожу на
  камень - и ничего не появляется» · «ненавязчивый виджет, с полупрозначным фейд фоном, небольшой текст, легкий» · «не такой большой, как виджет трупов» ·
  «а может просто лучом перед героем раз в 1 секунду проверять?» · «фон у E едва заметный» · «без камень, просто Взять».

  Почему так (разведка того же вечера, план 42): всё это — экземпляры растительности (PickupFoliageComponent_C), не объекты; подсветки цели у них нет, и
  игра ищет их ТОЛЬКО в миг нажатия E (UpdateHighlightTarget — один вызов на нажатие), события «предмет под прицелом» нет. Поэтому проверка своя, РАЗ В
  СЕКУНДУ (исключение из правила «только по событию» — предложение владельца 21:30), пока плашка видна — 5 раз в секунду.
  ЩУП — РОДНОЙ ЩУП ПОДБОРА ИГРЫ, тот самый, которым E берёт предмет (`[OWNER]` 2026-11-02 14:20 «ДА НЕ СПИСКО БЛИЗКИХ УЖНО ПРОВЕРЯТЬ!» · «А ЩУП ИЗ
  ПРИЦЕЛА!» · «КОТОРЫМ И ПОДНИМАЮТ!» · 14:21 «ЭТИМ ЖЕ ЩУПОМ РАЗ В СЕКУНДУ ЩУПАТЬ, ЕСТЬ ЛИ В ЗОНЕ ВЗЯТИЯ ТО, ЧТО МОЖНО ВЗЯТЬ!»): статическая
  EnvironmentFunctionLibrary:PickupGatheringOneInstance — её зовёт UpdateHighlightTarget (байткод FunCombat_PlayerController, KUMM bugs/77) с теми же
  числами, что здесь: начало = активная камера героя + её взгляд × InteractionDistanceThirdPersonBonus (игра сама держит её равной штанге), направление —
  взгляд камеры, длина PickupInteractionDistance, радиус PickupTraceSphereRadius; «да» — игра делает найденный экземпляр целью E (ServerSetHighlightedObject).
  Функция только ищет: подбор — отдельный вызов игры по нажатию. До 2026-11-02 здесь была своя копия поиска по списку «близких» компонентов с обходом по
  кругу — новый камень ждал очереди до ≈ 14 с (бага 77), список убран целиком.
  Плашка строится один раз внутри прицела WBP_Crosshair (его корень — CanvasPanel): мягкий фон — родная текстура T_UI_InteractionUnderlay (та же, что у
  полосы трупа), клавиша E в тонкой рамке с едва заметной заливкой, текст «Взять».
  Самозамер: сумма и худшая проверка раз в 60 проверок.
  [TESTED: 2026-11-02 · живая игра: родной щуп у камня «да», в небо «нет»; плашка за 0.3–1.2 с, гаснет за 0.3–0.4 с, в новом месте за 150 м — 0.9 с; E берёт
  цель щупа; проверка 0.089 мс (1000 вызовов) · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
]]

local MOD = "KrinikConanUI:PickupPrompt"
local CROSSHAIR = "/Game/UI/Widgets/HUD/Reticles/WBP_Crosshair.WBP_Crosshair_C"
local ENV_LIB = "/Script/ConanSandbox.Default__EnvironmentFunctionLibrary"   -- хозяин родного щупа подбора
local UNDERLAY = "/Game/UI/Textures/Backgrounds/T_UI_InteractionUnderlay.T_UI_InteractionUnderlay"
local CHECK_MS = 1000                -- «раз в 1 секунду» (владелец 21:30; 2026-11-02 14:21 — тем же родным щупом)
local CHECK_SHOWN_MS = 200           -- пока плашка видна — 5 раз в секунду, чтобы увод взгляда с предмета закрывал её быстрее (`[OWNER]` 2026-11-02 09:04
                                     -- «при открытой плашке E Взять, частота опросов должна повышаться до 5 раз в секунду»)
local TEXT = "Взять"
local TEXT_SIZE = 15                 -- «небольшой текст»: подсказка трупа заметно крупнее
local KEY_D = 22                     -- рамка клавиши E, единицы интерфейса
local KEY_GAP = 6.0                  -- от рамки E до слова: 24 → 6 (`[OWNER]` 22:41 «кнопку E ближе поставь к Взять» · 22:48 «вариант 3», папка отсмотра 55)
-- Место плашки — строки хаба «E Взять: по горизонтали / по высоте», СДВИГ от прицела в % экрана (`[OWNER]` 2026-11-02 08:57 «дать настройку их положения
-- на экране через наши настройки модов? По высоте и по горизонтали?»). Плашка стоит ПРАВЫМ КРАЕМ к точке прицела, по её высоте: сдвиг 0 / 0 — вплотную
-- к точке. По умолчанию — на линии точки прицела и чуть левее неё (`[OWNER]` 2026-11-02 14:22 «и слишком далеко плашка от центра» · «поднять выше в одну
-- линию с точной прицела, и правее»; до того −14 % / +6 % от середины плашки — далеко слева и ниже). Значения по умолчанию — те же числа, что в хабе
-- (krinik_mod_settings.lua). [TESTED: 2026-11-02 · кадр 4K: на линии точки, правый край ≈ 60 px левее неё · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
local settings = require("krinik_settings")
local PLATE_X_DEFAULT, PLATE_Y_DEFAULT = -1, 0
local BACK = { R = 0.0, G = 0.0, B = 0.0, A = 0.35 }      -- мягкий фон: родная текстура затухания; 0.85 → 0.6 (`[OWNER]` 21:53 «фон подсказки более прозрачным сделать») → 0.35 (21:57 «еще более прорначный фон»)
local KEY_RIM = { R = 0.91, G = 0.89, B = 0.85, A = 0.90 }
local KEY_FILL = { R = 1.0, G = 1.0, B = 1.0, A = 0.09 }   -- «фон у E едва заметный»
local TEXT_COLOR = { R = 0.94, G = 0.93, B = 0.89, A = 1.0 }

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local plate = nil                    -- корень плашки внутри прицела; nil — прицела ещё нет
local key_rim = nil                  -- рамка клавиши E: её контур затухание не берёт (см. set_rim)
local shown = false
local stat_n, stat_sum, stat_max, stat_hits, errors = 0, 0.0, 0.0, 0, 0

-- ---- плашка ---------------------------------------------------------------------------------------------------------------------------------
local function construct(cls, outer, name)
    return StaticConstructObject(StaticFindObject(cls), outer, FName(name))
end

local function place(row)
    local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    local vp, sc = wll:GetViewportSize(row), wll:GetViewportScale(row)
    if not (sc and sc > 0) then return end
    local x, y = settings.get("ui_pickup_x", PLATE_X_DEFAULT), settings.get("ui_pickup_y", PLATE_Y_DEFAULT)
    row.Slot:SetPosition({ X = x / 100 * vp.X / sc, Y = y / 100 * vp.Y / sc })
end

local function build(cross)
    local tree = cross.WidgetTree
    local root = tree and tree.RootWidget
    if not valid(root) then log("прицел без корня"); return end
    -- Раскладка: [клавиша E в своей рамке] [слово «Взять» на мягком фоне] — фон только под словом (`[OWNER]` 21:57 «можно только под словом его
    -- оставить. убрать из-под кнопки» · «у кнопки свой фон есть»).
    local row = construct("/Script/UMG.HorizontalBox", tree, "HB_KrinikPickup")
    local back = construct("/Script/UMG.Border", tree, "Brd_KrinikPickup")
    local brush = back.Background
    local tex = StaticFindObject(UNDERLAY)
    if not valid(tex) then tex = LoadAsset(UNDERLAY) end
    if valid(tex) then brush.ResourceObject = tex; brush.DrawAs = 3 end   -- Image: мягкая полоса затухания, как у трупа
    back:SetBrush(brush)
    back:SetBrushColor(BACK)
    back:SetPadding({ Left = KEY_GAP, Top = 3.0, Right = 24.0, Bottom = 3.0 })
    local key = construct("/Script/UMG.Border", tree, "Brd_KrinikPickupKey")
    local kb = key.Background
    kb.DrawAs = 4                                     -- RoundedBox: тонкая рамка
    kb.OutlineSettings.CornerRadii = { X = 3.0, Y = 3.0, Z = 3.0, W = 3.0 }
    kb.OutlineSettings.Width = 1.0
    kb.OutlineSettings.Color = { SpecifiedColor = KEY_RIM, ColorUseRule = 0 }
    kb.OutlineSettings.RoundingType = 0
    kb.TintColor = { SpecifiedColor = KEY_FILL, ColorUseRule = 0 }
    key:SetBrush(kb)
    key:SetPadding({ Left = 6.0, Top = 0.0, Right = 6.0, Bottom = 0.0 })
    local ks = row:AddChildToHorizontalBox(key)
    ks:SetVerticalAlignment(2)
    local kt = construct("/Script/UMG.TextBlock", tree, "Txt_KrinikPickupKey")
    kt:SetText(FText("E"))
    local f = kt.Font; f.Size = TEXT_SIZE - 2; kt:SetFont(f)
    kt:SetColorAndOpacity({ SpecifiedColor = TEXT_COLOR, ColorUseRule = 0 })
    key:SetContent(kt)
    local tt = construct("/Script/UMG.TextBlock", tree, "Txt_KrinikPickup")
    tt:SetText(FText(TEXT))
    local f2 = tt.Font; f2.Size = TEXT_SIZE; tt:SetFont(f2)
    tt:SetColorAndOpacity({ SpecifiedColor = TEXT_COLOR, ColorUseRule = 0 })
    back:SetContent(tt)
    local bs = row:AddChildToHorizontalBox(back)
    bs:SetVerticalAlignment(2)
    bs:SetPadding({ Left = 2.0, Top = 0.0, Right = 0.0, Bottom = 0.0 })
    local slot = root:AddChildToCanvas(row)
    slot:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    slot:SetAlignment({ X = 1.0, Y = 0.5 })           -- правый край — к точке прицела, середина по высоте — на её линии
    slot:SetAutoSize(true)
    place(row)
    row:SetRenderOpacity(0.0)                         -- первое появление — тоже с нуля
    row:SetVisibility(1)                              -- Collapsed, пока нечего взять
    plate, key_rim, shown = row, key, false
    log("плашка «E %s» в прицеле", TEXT)
end

-- Появление и скрытие — плавно (`[OWNER]` 21:54 «и показывать фейдом, скрывать фейдом»): прозрачность ведётся по часам за FADE_S, шаг ≈ кадр, как у
-- криков врагов (krinik_shout_fade.lua); новая смена направления подхватывает текущую прозрачность, а не начинает с края.
local FADE_S, FADE_STEP_MS = 0.20, 15
local fade_gen = 0

-- Контур рамки E рисуется своим цветом и прозрачность родителя не умножает (`[OWNER]` 2026-11-02 14:20 «фейд плохой, контур E не действует на фейд!»):
-- его альфа ведётся тем же числом, что прозрачность плашки. [TESTED: 2026-11-02 · кадр при прозрачности 0 — рамка была белой, теперь её нет; альфа рамки
-- 0.90 → 0 вместе с плашкой · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
local function set_rim(k)
    if not valid(key_rim) then return end
    local b = key_rim.Background
    b.OutlineSettings.Color = { SpecifiedColor = { R = KEY_RIM.R, G = KEY_RIM.G, B = KEY_RIM.B, A = KEY_RIM.A * k }, ColorUseRule = 0 }
    key_rim:SetBrush(b)
end

local function show(on)
    if on == shown or not valid(plate) then return end
    shown = on
    fade_gen = fade_gen + 1
    local gen = fade_gen
    local from = plate:GetRenderOpacity()
    if on then plate:SetRenderOpacity(from); set_rim(from); plate:SetVisibility(3) end   -- HitTestInvisible
    local t0 = os.clock()
    local function step()
        if gen ~= fade_gen or not valid(plate) then return end   -- сменили направление — эта ступень уже не наша
        local k = math.min(1.0, (os.clock() - t0) / FADE_S)
        local target = on and 1.0 or 0.0
        local o = from + (target - from) * k
        plate:SetRenderOpacity(o)
        set_rim(o)
        if k < 1.0 then
            ExecuteInGameThreadWithDelay(FADE_STEP_MS, step)
        elseif not on then
            plate:SetVisibility(1)                    -- Collapsed: погасла — убрать из раскладки
        end
    end
    step()
end

-- ---- родной щуп подбора ---------------------------------------------------------------------------------------------------------------------
-- Контроллер ищется один раз (FindFirstOf — обход всех объектов движка): каждую секунду он давал миллисекунды (самозамер 2026-11-01 21:39 — худшая 6 мс).
-- Герой и библиотека — в кэше.
local pc_cached, hero_cached, lib_cached = nil, nil, nil
local function actors()
    if not valid(pc_cached) then pc_cached = FindFirstOf("FunCombat_PlayerController_C") end
    if not valid(hero_cached) and valid(pc_cached) then hero_cached = pc_cached:K2_GetPawn() end
    return pc_cached, hero_cached
end

local function check()
    local t0 = os.clock()
    local pc, hero = actors()
    if not (valid(pc) and valid(hero)) then show(false); return end
    if not valid(lib_cached) then lib_cached = StaticFindObject(ENV_LIB) end
    if not valid(lib_cached) then show(false); return end
    -- Камера и надбавка — ветка UpdateHighlightTarget слово в слово: активна камера первого лица AdjustableCamera — она и надбавка 0; иначе камера
    -- CameraThirdPerson и надбавка = длина штанги ThirdPersonSpringArm (игра пишет её в InteractionDistanceThirdPersonBonus только при нажатии E, поэтому
    -- поле контроллера до первого нажатия — 0, замер 2026-11-02 14:38; берём ту же длину сами).
    local cam, bonus = hero.AdjustableCamera, 0.0
    if not (valid(cam) and cam:IsActive()) then cam, bonus = hero.CameraThirdPerson, hero.ThirdPersonSpringArm.TargetArmLength end
    if not valid(cam) then show(false); return end
    local loc, fwd = cam:K2_GetComponentLocation(), cam:GetForwardVector()
    local dir = { X = fwd.X, Y = fwd.Y, Z = fwd.Z }
    local start = { X = loc.X + dir.X * bonus, Y = loc.Y + dir.Y * bonus, Z = loc.Z + dir.Z * bonus }
    local found = lib_cached:PickupGatheringOneInstance(pc, hero, pc, start, dir, pc.PickupInteractionDistance, pc.PickupTraceSphereRadius, {}, {}) == true
    show(found)
    local ms = (os.clock() - t0) * 1000.0
    stat_n, stat_sum = stat_n + 1, stat_sum + ms
    if found then stat_hits = stat_hits + 1 end
    if ms > stat_max then stat_max = ms end
end

-- Ритм — цепочка ExecuteInGameThreadWithDelay в игровом потоке (LoopAsync крутится в чужом потоке — правило проекта, check-lua-game-thread.py);
-- одна цепочка на всю игру; каждые 60 проверок — сводка в журнал. Шаг цепочки — CHECK_MS, пока плашки нет, и CHECK_SHOWN_MS, пока она видна.
local ticking = false
local function tick()
    if valid(plate) then
        local ok, err = pcall(check)
        if not ok then
            errors = errors + 1
            if errors <= 3 then log("ошибка проверки: %s", tostring(err)) end
        end
    end
    if stat_n >= 60 then
        log("за %d проверок своё время %.3f мс, худшая %.3f мс, щуп нашёл предмет %d раз", stat_n, stat_sum, stat_max, stat_hits)
        stat_n, stat_sum, stat_max, stat_hits = 0, 0.0, 0.0, 0
    end
    ExecuteInGameThreadWithDelay(shown and CHECK_SHOWN_MS or CHECK_MS, tick)
end

NotifyOnNewObject(CROSSHAIR, function(w)
    if w:GetFullName():find("Default__", 1, true) then return end
    ExecuteInGameThreadWithDelay(600, function()
        local ok, err = pcall(build, w)
        if not ok then log("ошибка сборки: %s", tostring(err)) end
        if not ticking then ticking = true; ExecuteInGameThreadWithDelay(CHECK_MS, tick) end
    end)
end)

-- «Сохранить» в хабе: плашка встаёт на новое место сразу (событие хранилища, не опрос)
settings.on_change(function(changed)
    if changed.ui_pickup_x == nil and changed.ui_pickup_y == nil then return end
    if valid(plate) then
        local ok, err = pcall(place, plate)
        log(ok and "место плашки: %s %%, %s %%" or "место плашки не применено: %s", ok and settings.get("ui_pickup_x", PLATE_X_DEFAULT) or tostring(err),
            settings.get("ui_pickup_y", PLATE_Y_DEFAULT))
    end
end)

log("загружен: «E %s» родным щупом подбора раз в %d мс, при видимой плашке — раз в %d мс", TEXT, CHECK_MS, CHECK_SHOWN_MS)
