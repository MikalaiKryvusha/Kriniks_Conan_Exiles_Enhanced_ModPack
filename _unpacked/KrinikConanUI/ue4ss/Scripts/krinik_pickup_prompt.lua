--[[
  KrinikConanUI:PickupPrompt — лёгкая подсказка «E Взять», когда перед героем лежит то, что игра даёт поднять по E: камни, ветки, волокно, ягоды,
  грибы, водоросли, личинки, перья, яйца, паутина (KUMM plans/42_conan_pickup_prompt_foliage.md).

  Слово владельца 2026-11-01 21:14–21:34: «при наведении на палки, на траву, на камень - писать тонкий виджет E Поднять» · «меня бесит, что я навожу на
  камень - и ничего не появляется» · «ненавязчивый виджет, с полупрозначным фейд фоном, небольшой текст, легкий» · «не такой большой, как виджет трупов» ·
  «а может просто лучом перед героем раз в 1 секунду проверять?» · «фон у E едва заметный» · «без камень, просто Взять».

  Почему так (разведка того же вечера, план 42): всё это — экземпляры растительности (PickupFoliageComponent_C), не объекты; подсветки цели у них нет, и
  игра ищет их ТОЛЬКО в миг нажатия E (UpdateHighlightTarget — один вызов на нажатие), события «предмет под прицелом» нет. Поэтому проверка своя, РАЗ В
  СЕКУНДУ (исключение из правила «только по событию» — предложение владельца 21:30), пока плашка видна — 10 раз в секунду (CHECK_SHOWN_MS).
  ЩУП — РОДНОЙ ЩУП ПОДБОРА ИГРЫ, тот самый, которым E берёт предмет (`[OWNER]` 2026-11-02 14:20 «ДА НЕ СПИСКО БЛИЗКИХ УЖНО ПРОВЕРЯТЬ!» · «А ЩУП ИЗ
  ПРИЦЕЛА!» · «КОТОРЫМ И ПОДНИМАЮТ!» · 14:21 «ЭТИМ ЖЕ ЩУПОМ РАЗ В СЕКУНДУ ЩУПАТЬ, ЕСТЬ ЛИ В ЗОНЕ ВЗЯТИЯ ТО, ЧТО МОЖНО ВЗЯТЬ!»): статическая
  EnvironmentFunctionLibrary:PickupGatheringOneInstance — её зовёт UpdateHighlightTarget (байткод FunCombat_PlayerController, KUMM bugs/77) с теми же
  числами, что здесь: начало = активная камера героя + её взгляд × InteractionDistanceThirdPersonBonus (игра сама держит её равной штанге), направление —
  взгляд камеры, длина PickupInteractionDistance, радиус PickupTraceSphereRadius; «да» — игра делает найденный экземпляр целью E (ServerSetHighlightedObject).
  Функция только ищет: подбор — отдельный вызов игры по нажатию. До 2026-11-02 здесь была своя копия поиска по списку «близких» компонентов с обходом по
  кругу — новый камень ждал очереди до ≈ 14 с (бага 77), список убран целиком.
  С 2026-11-13 (KUMM bugs/96) перед щупом растительности — ветка объектов той же функции игры: тронутый куст становится актором-ресурсом, и E собирает
  с него; плашка спрашивает цель-актор так же, как игра, и горит над ресурсом, который игра сама называет подбираемым (actor_target ниже).
  Цена проверки с 2026-11-13: ветка объектов 0.125 мс + щуп растительности 0.045 мс (по 200 вызовов на месте куста).
  Плашка строится один раз внутри прицела WBP_Crosshair (его корень — CanvasPanel): мягкий фон — родная текстура T_UI_InteractionUnderlay (та же, что у
  полосы трупа), клавиша E в тонкой рамке с едва заметной заливкой, текст «Взять».
  Самозамер: сумма и худший шаг цепочки (любой — дошедший до конца, вышедший рано или сорвавшийся) раз в минуту по часам.
  [TESTED: 2026-11-02 · живая игра: родной щуп у камня «да», в небо «нет»; плашка за 0.3–1.2 с, гаснет за 0.3–0.4 с, в новом месте за 150 м — 0.9 с; E берёт
  цель щупа; проверка 0.089 мс (1000 вызовов) · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
]]

local MOD = "KrinikConanUI:PickupPrompt"
local CROSSHAIR = "/Game/UI/Widgets/HUD/Reticles/WBP_Crosshair.WBP_Crosshair_C"
local ENV_LIB = "/Script/ConanSandbox.Default__EnvironmentFunctionLibrary"   -- хозяин родного щупа подбора
local UNDERLAY = "/Game/UI/Textures/Backgrounds/T_UI_InteractionUnderlay.T_UI_InteractionUnderlay"
local CHECK_MS = 1000                -- «раз в 1 секунду» (владелец 21:30; 2026-11-02 14:21 — тем же родным щупом)
local CHECK_SHOWN_MS = 100           -- пока плашка видна — 10 раз в секунду (`[OWNER]` 2026-11-07 10:41 «опрос луча E Взять ускоряем до 10 раз в 1 секунду, пока
                                     -- луч открыт»; до того 200 — `[OWNER]` 2026-11-02 09:04 «должна повышаться до 5 раз в секунду»)
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
local BACK = { R = 0.0, G = 0.0, B = 0.0, A = 0.45 }      -- мягкий фон: родная текстура затухания; 0.85 → 0.6 (`[OWNER]` 21:53 «фон подсказки более прозрачным сделать») → 0.35 (21:57 «еще более прорначный фон») → 0.45 (`[OWNER]` 2026-11-07 10:22 «непрозрачность подкладки на 10% сильнее» — `[AI]` прочитано как +10 пунктов)
local BACK_PAD_X = 24.0              -- поля фона слева и справа: фон теперь и под E, поля равные (справа было 24 и до 2026-11-07)
local KEY_RIM = { R = 0.91, G = 0.89, B = 0.85, A = 0.90 }
local KEY_FILL = { R = 1.0, G = 1.0, B = 1.0, A = 0.09 }   -- «фон у E едва заметный»
local TEXT_COLOR = { R = 0.94, G = 0.93, B = 0.89, A = 1.0 }

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end
-- Ссылка, которую раздел держит между событиями (плашка, рамка E, контроллер, модуль интерфейса), годна, только пока объект по её адресу носит имя,
-- записанное при захвате: после выхода в меню и новой загрузки мира адрес может занять чужой объект, и IsValid() ответит «да» ему (KUMM EXP-0612;
-- судья 2026-11-22 21:5x, круг на RC4, находка 5). [NOT-TESTED]
local names = {}   -- [ключ ссылки] = полное имя при захвате
local function keep(key, o)
    names[key] = nil
    if o ~= nil and o:IsValid() then local ok, fn = pcall(o.GetFullName, o); if ok then names[key] = fn end end
    return o
end
local function kept(key, o)
    if not (o ~= nil and names[key] and o:IsValid()) then return false end
    local ok, fn = pcall(o.GetFullName, o)
    return ok and fn == names[key]
end

local plate = nil                    -- корень плашки внутри прицела; nil — прицела ещё нет
local key_rim = nil                  -- рамка клавиши E: её контур затухание не берёт (см. set_rim)
local shown = false
local stat_n, stat_sum, stat_max, stat_hits, errors = 0, 0.0, 0.0, 0, 0
-- время частей проверки за окно сводки (KUMM bugs/99: в мире владельца проверка 0.63 мс, а лучи и щуп в том же месте — 0.1 мс; где остальное?) [NOT-TESTED]
local part_ms = { strips = 0.0, actor = 0.0, foliage = 0.0 }

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
    -- Раскладка с 2026-11-07: мягкий фон под ВСЕЙ плашкой — [ фон: [клавиша E в своей рамке] [слово «Взять»] ] (`[OWNER]` 2026-11-07 10:22 «серую подкладку
    -- растягиваем так, чтобы E тоже над ней. И непрозрачность подкладки на 10% сильнее»; до того, с 2026-11-01 21:57, фон стоял только под словом).
    local row = construct("/Script/UMG.HorizontalBox", tree, "HB_KrinikPickup")
    local inner = construct("/Script/UMG.HorizontalBox", tree, "HB_KrinikPickupInner")
    local back = construct("/Script/UMG.Border", tree, "Brd_KrinikPickup")
    local brush = back.Background
    local tex = StaticFindObject(UNDERLAY)
    if not valid(tex) then tex = LoadAsset(UNDERLAY) end
    if valid(tex) then brush.ResourceObject = tex; brush.DrawAs = 3 end   -- Image: мягкая полоса затухания, как у трупа
    back:SetBrush(brush)
    back:SetBrushColor(BACK)
    back:SetPadding({ Left = BACK_PAD_X, Top = 3.0, Right = BACK_PAD_X, Bottom = 3.0 })
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
    local ks = inner:AddChildToHorizontalBox(key)
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
    local ts = inner:AddChildToHorizontalBox(tt)
    ts:SetVerticalAlignment(2)
    ts:SetPadding({ Left = KEY_GAP, Top = 0.0, Right = 0.0, Bottom = 0.0 })
    back:SetContent(inner)
    local bs = row:AddChildToHorizontalBox(back)
    bs:SetVerticalAlignment(2)
    local slot = root:AddChildToCanvas(row)
    slot:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    slot:SetAlignment({ X = 1.0, Y = 0.5 })           -- правый край — к точке прицела, середина по высоте — на её линии
    slot:SetAutoSize(true)
    place(row)
    row:SetRenderOpacity(0.0)                         -- первое появление — тоже с нуля
    row:SetVisibility(1)                              -- Collapsed, пока нечего взять
    plate, key_rim, shown = keep("plate", row), keep("rim", key), false
    log("плашка «E %s» в прицеле", TEXT)
end

-- Появление и скрытие — плавно (`[OWNER]` 21:54 «и показывать фейдом, скрывать фейдом»): прозрачность ведётся по часам за FADE_S, шаг ≈ кадр, как у
-- криков врагов (krinik_shout_fade.lua); новая смена направления подхватывает текущую прозрачность, а не начинает с края.
-- FADE_S 0.20 → 0.10 (`[OWNER]` 2026-11-07 10:41 «анимацию появления и закрытия фейдом плашки Взять ускоряем на 50%» · 10:42 «до 0,1 делаем»)
local FADE_S, FADE_STEP_MS = 0.10, 15
local fade_gen = 0

-- Контур рамки E рисуется своим цветом и прозрачность родителя не умножает (`[OWNER]` 2026-11-02 14:20 «фейд плохой, контур E не действует на фейд!»):
-- его альфа ведётся тем же числом, что прозрачность плашки. [TESTED: 2026-11-02 · кадр при прозрачности 0 — рамка была белой, теперь её нет; альфа рамки
-- 0.90 → 0 вместе с плашкой · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
local function set_rim(k)
    if not kept("rim", key_rim) then return end
    local b = key_rim.Background
    b.OutlineSettings.Color = { SpecifiedColor = { R = KEY_RIM.R, G = KEY_RIM.G, B = KEY_RIM.B, A = KEY_RIM.A * k }, ColorUseRule = 0 }
    key_rim:SetBrush(b)
end

local function show(on)
    if on == shown or not kept("plate", plate) then return end
    shown = on
    fade_gen = fade_gen + 1
    local gen = fade_gen
    local from = plate:GetRenderOpacity()
    if on then plate:SetRenderOpacity(from); set_rim(from); plate:SetVisibility(3) end   -- HitTestInvisible
    local t0 = os.clock()
    local function step()
        if gen ~= fade_gen or not kept("plate", plate) then return end   -- сменили направление — эта ступень уже не наша
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
-- Контроллер, библиотека и модуль интерфейса — в кэше; героя берём у контроллера на каждой проверке (actors ниже).
local pc_cached, lib_cached, gui_cached = nil, nil, nil
local CONTAINER_MODULE = FName("ContainerInfo")   -- модуль плашки трупа и окна быстрого лута (карта игры, «Плашка над трупом»)
-- Ссылка живёт дольше своего виджета: игра уничтожает плашку, а её память занимает новый объект, и valid() отвечает «да» уже ЧУЖОМУ объекту — IsInViewport()
-- пошёл бы на нём (увидено живьём 2026-11-22 в разделе паузы: ссылка на экран загрузки указывала на W_HotkeyIcon_C, KUMM bugs/118). Поэтому при рождении
-- запоминается полное имя плашки, и ссылка годится, только пока у объекта по ней то же имя (имя несёт класс и номер экземпляра; судья 2026-11-22, круг 1,
-- находки 7, 8). Плашка не из окна (шаблон, не Transient) в список не берётся. [NOT-TESTED]
local strips = {}                                 -- { w, name }: живые плашки взаимодействия по рождению
local function strip_born(w)
    local ok, fn = pcall(w.GetFullName, w)
    if ok and fn and fn:find("Transient", 1, true) then strips[#strips + 1] = { w = w, name = fn } end
end
NotifyOnNewObject("/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo.WBP_ContainerInfo_C", strip_born)
-- Остальные подсказки взаимодействия — собеседник, постройка, простой предмет, раб, павший союзник (KUMM bugs/83, карта игры «The other interaction
-- prompts»): цель-актор под прицелом, E достанется ей, а не кусту. Кадр 2026-11-06 08:54: «Нажмите E, чтобы говорить» и наша «E Взять» горели вместе. [NOT-TESTED]
for _, n in ipairs({ "W_DialogueNPCInfo", "W_PlaceableInfo", "W_SimpleInfo", "W_ThrallInfo", "W_DBNORevive" }) do
    NotifyOnNewObject("/Game/UI/HUD/FloatingNames/" .. n .. "." .. n .. "_C", strip_born)
end
local function strip_on_screen()
    for i = #strips, 1, -1 do
        local e = strips[i]
        local w = e.w
        local same = false
        if valid(w) then local ok, fn = pcall(w.GetFullName, w); same = ok and fn == e.name end
        if not same then table.remove(strips, i)
        elseif w:IsInViewport() and w:IsVisible() then return true end
    end
    return false
end
-- Героя берём у контроллера на каждой проверке, как UpdateHighlightTarget (K2_GetPawn в начале функции): запомненный однажды герой мог смениться,
-- а лучи и камера должны идти от того, кем игрок управляет сейчас (судья, раунд 2, 2026-11-13). Контроллер живёт всю игру — его ищем один раз.
-- Игра сразу приводит пешку к BasePlayerChar и без него цели не ищет; у чужой пешки нет AdjustableCamera и ThirdPersonSpringArm — каждая проверка
-- сорвалась бы ошибкой и съела три текста ошибок за игру (судья, раунд 3). Нет героя-персонажа — нет плашки, как у игры.
-- [TESTED: 2026-11-13 · TC_conan_no_take_prompt_bush run 4 (R1, R5 — герой на каждой проверке); приведение к BasePlayerChar — NOT-TESTED]
local hero_cls = nil
local hero_cls_warned = false
local function actors()
    -- одна сверка по имени на проверку (судья, второй круг на RC4, находка 4): только что найденный — свой по определению
    local pc_ok = kept("pc", pc_cached)
    if not pc_ok then pc_cached = keep("pc", FindFirstOf("FunCombat_PlayerController_C")); pc_ok = valid(pc_cached) end
    local hero = pc_ok and pc_cached:K2_GetPawn() or nil
    -- класс героя — блюпринт (нативного /Script/ConanSandbox.BasePlayerChar в 3.0.1 нет: судья, раунд 4; тот же путь у krinik_bow_sprint.lua)
    if not valid(hero_cls) then
        hero_cls = StaticFindObject("/Game/Characters/BasePlayerChar.BasePlayerChar_C")
        -- пешка есть, а класса нет — приведение молча пропускалось бы, плашка шла без проверки пешки (судья 2026-11-13, P1): одна строка за игру
        if valid(hero) and not valid(hero_cls) and not hero_cls_warned then
            hero_cls_warned = true
            log("класс героя BasePlayerChar_C не найден — пешка не проверяется")
        end
    end
    if valid(hero) and valid(hero_cls) and not hero:IsA(hero_cls) then hero = nil end
    return pc_cached, hero
end

-- ---- ветка объектов: цель E — актор под прицелом ---------------------------------------------------------------------------------------------
-- Куст, тронутый один раз, игра превращает в актор BP_ResourceActor_C с тем же мешем на том же месте: экземпляр растительности снят (масштаб 0), а
-- следующие нажатия E собирают уже с актора. Щуп растительности над таким кустом молчит — плашка гасла, хотя E брал (KUMM bugs/96, кадр владельца
-- 2026-11-13 11:09 «смотрю на куст, нет E Взять - баг»; замер: третье E по актору дало волокно 7 → 9).
-- Порядок игры (байткод 3.0.1 FunCombat_PlayerController::UpdateHighlightTarget, KUMM bugs/96 «Forensics»): сначала SphereTraceMulti (радиус
-- TraceSphereRadius) и LineTraceMulti по каналу 6 от камеры на InteractionDistance + штанга, без героя; из попаданий с InteractableInterface (у актора
-- или компонента) целью становится ближайшее к центру прицела (наибольший |cos|), прошедшее CheckLineOfSight(актор, попадание + взгляд × 10, …); и
-- ТОЛЬКО без такой цели — щуп растительности. Целью игра берёт КОМПОНЕНТ, если интерфейс у компонента (SelectObject), иначе актор — так и здесь.
-- Плашка повторяет этот порядок: цель есть → «E Взять» лишь для того, что игра сама называет подбираемым (GetIsPickupResource — у актора-ресурса
-- и у компонента растения для подбора); у трупа, сундука, собеседника, камня знаний E делает своё — плашка молчит.
-- Не повторены, и плашка от этого не лжёт: шаг InteractTargetOverride (его ставит только подъём павшего союзника, SOS_DBNO — там горит подсказка игры
-- W_DBNORevive, и плашка гаснет по ней); «нет попаданий сферы → сразу щуп» (сфера по тому же отрезку ловит всё, что ловит линия) — судья, 2026-11-13.
-- [TESTED: 2026-11-13 · F1–F5, F7 и камень у гнезда змей: тронутый куст — плашка и E +волокно; нетронутый, яйцо, камень — плашка; песок, труп — нет ·
-- KUMM testcases/reports/2026-11-13_conan-bush-prompt-resource-actor.md]
local KSL = "/Script/Engine.Default__KismetSystemLibrary"
local INTERACTABLE = "/Script/ConanSandbox.InteractableInterface"
local RESOURCE_BASE = "/Script/ConanSandbox.ResourceActorBase"
local PICKUP_FOLIAGE = "/Script/ConanSandbox.PickupFoliage"   -- класс компонента растения для подбора (PickupFoliageComponent_C)
local TRACE_CHANNEL = 6              -- канал луча взаимодействия в UpdateHighlightTarget: TraceTypeQuery7 = Trace_Interactable
local LOS_AHEAD = 10.0               -- точка проверки видимости: попадание + взгляд × 10, как у игры
local NO_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }
local ksl_cached, iface_cached, resource_cls, pickup_foliage_cls = nil, nil, nil, nil
local pickup_err_logged = false      -- первый срыв GetIsPickupResource уже в журнале
local pickup_err_n = 0               -- срывы GetIsPickupResource в окне сводки: после первого текста их видно хотя бы числом (судья, раунд 3, 2026-11-13)

-- Цель E по ветке объектов игры или nil (тогда игра спрашивает щуп растительности): компонент, если интерфейс у него, иначе актор-владелец.
local function actor_target(pc, hero, loc, fwd, bonus)
    if not valid(ksl_cached) then ksl_cached = StaticFindObject(KSL) end
    if not valid(iface_cached) then iface_cached = StaticFindObject(INTERACTABLE) end
    if not (valid(ksl_cached) and valid(iface_cached)) then return nil end
    local len = pc.InteractionDistance + bonus
    local stop = { X = loc.X + fwd.X * len, Y = loc.Y + fwd.Y * len, Z = loc.Z + fwd.Z * len }
    local sphere, line = {}, {}
    ksl_cached:SphereTraceMulti(pc, loc, stop, pc.TraceSphereRadius, TRACE_CHANNEL, false, { hero }, 0, sphere, true, NO_COLOR, NO_COLOR, 0)
    ksl_cached:LineTraceMulti(pc, loc, stop, TRACE_CHANNEL, false, { hero }, 0, line, true, NO_COLOR, NO_COLOR, 0)
    local best, best_cos = nil, 0.0
    for _, hits in ipairs({ sphere, line }) do
        for i = 1, #hits do
            -- Вид элементов, замеченный 2026-11-13: элемент выхода — обёртка параметра (:get()), Component — слабый указатель (:Get()).
            local h = hits[i]:get()
            -- Косинус считаем первым, по одной точке удара. Попадание, которое к центру прицела не ближе лучшего, игра всё равно отбросит, и для него не
            -- нужны ни компонент, ни владелец, ни интерфейс, ни проверка видимости. Выбор тот же, что у игры, а три-четыре вызова функций игры платит лишь
            -- попадание, способное стать целью: у лагеря с десятками предметов прежний порядок дорожал с каждым попаданием (судья, раунд 2, 2026-11-13).
            -- [NOT-TESTED]
            local p = h.ImpactPoint
            local dx, dy, dz = p.X - loc.X, p.Y - loc.Y, p.Z - loc.Z
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            local c = d > 0 and math.abs((dx * fwd.X + dy * fwd.Y + dz * fwd.Z) / d) or 0.0
            if c > best_cos then
                local comp = h.Component:Get()
                -- актор попадания — владелец компонента: HitObjectHandle.Actor из Lua не читается (UE4SS, 2026-11-13)
                local owner = valid(comp) and comp:GetOwner() or nil
                if valid(owner) then
                    local comp_iface = ksl_cached:DoesImplementInterface(comp, iface_cached)
                    if comp_iface or ksl_cached:DoesImplementInterface(owner, iface_cached) then
                        local seen = pc:CheckLineOfSight(owner, { X = p.X + fwd.X * LOS_AHEAD, Y = p.Y + fwd.Y * LOS_AHEAD, Z = p.Z + fwd.Z * LOS_AHEAD },
                            comp, h.Item, false)
                        if seen then best, best_cos = (comp_iface and comp or owner), c end
                    end
                end
            end
        end
    end
    return best
end

-- E по этой цели соберёт ресурс рукой? Ответ самой игры: GetIsPickupResource (выход Value) — у актора-ресурса (флаг isPickup его HarvestableComponent)
-- и у компонента растения для подбора (всегда «да»); любая другая цель — нет.
local function is_pickup_resource(target)
    if not valid(resource_cls) then resource_cls = StaticFindObject(RESOURCE_BASE) end
    if not valid(pickup_foliage_cls) then pickup_foliage_cls = StaticFindObject(PICKUP_FOLIAGE) end
    local kind = (valid(resource_cls) and target:IsA(resource_cls)) or (valid(pickup_foliage_cls) and target:IsA(pickup_foliage_cls))
    if not kind then return false end
    local out = {}
    local ok, err = pcall(function() target:GetIsPickupResource(out) end)
    -- Сорвавшийся вызов гасит плашку молча, и в журнале не видно, почему над кустом нет «E Взять». Первый срыв за игру пишем в журнал один раз
    -- (судья, раунд 2, 2026-11-13). [NOT-TESTED]
    if not ok then pickup_err_n = pickup_err_n + 1 end
    if not ok and not pickup_err_logged then
        pickup_err_logged = true
        log("GetIsPickupResource сорвался у %s: %s", tostring(target:GetFullName()), tostring(err))
    end
    return ok and (out.Value == true or out.value == true)
end

local function check()
    local pc, hero = actors()
    if not (valid(pc) and valid(hero)) then show(false); return end
    if not valid(lib_cached) then lib_cached = StaticFindObject(ENV_LIB) end
    if not valid(lib_cached) then show(false); return end
    -- Камера и надбавка — ветка UpdateHighlightTarget слово в слово: активна камера первого лица AdjustableCamera — она и надбавка 0; иначе камера
    -- CameraThirdPerson и надбавка = длина штанги ThirdPersonSpringArm (игра пишет её в InteractionDistanceThirdPersonBonus только при нажатии E, поэтому
    -- поле контроллера до первого нажатия — 0, замер 2026-11-02 14:38; берём ту же длину сами).
    -- Труп или сундук под прицелом — E откроет его, а не куст: UpdateHighlightTarget сперва ищет цель-актор и только без неё зовёт щуп растений
    -- (KUMM bugs/80, байткод контроллера). Плашку трупа показывает модуль ContainerInfo — пока он открыт, наша «E Взять» не горит
    -- (`[OWNER]` 2026-11-03 19:57 «нужно ту плашку показывать, которая сработает»). [NOT-TESTED]
    -- Флаг модуля один не ловит плашку (aim-sweep.lua, 2026-11-03 20:4x) — смотрим и на сам виджет, запомненный при рождении (без поиска).
    local gui_ok = kept("gui", gui_cached)
    if not gui_ok then gui_cached = keep("gui", FindFirstOf("GUIModuleController")); gui_ok = valid(gui_cached) end
    local ts = os.clock()
    local strip = (gui_ok and gui_cached:IsModuleActive(CONTAINER_MODULE)) or strip_on_screen()
    part_ms.strips = part_ms.strips + (os.clock() - ts) * 1000.0
    if strip then show(false); return end
    -- Активность CameraThirdPerson НЕ спрашиваем, хотя игра её спрашивает (байткод 3.0.1): игра ищет цель только в миг нажатия E, когда настоящий
    -- ввод уже вернул камеру, а плашка спрашивает между нажатиями — и там обе камеры бывают неактивны при обычном виде (стенд 2026-11-13 14:4x: после
    -- облёта простоя HUD вернулся, а IsActive у обеих — false). Копия проверки гасила бы плашку там, где E сработает (судья, раунд 2 — не применено).
    local cam, bonus = hero.AdjustableCamera, 0.0
    if not (valid(cam) and cam:IsActive()) then cam, bonus = hero.CameraThirdPerson, hero.ThirdPersonSpringArm.TargetArmLength end
    if not valid(cam) then show(false); return end
    local loc, fwd = cam:K2_GetComponentLocation(), cam:GetForwardVector()
    local dir = { X = fwd.X, Y = fwd.Y, Z = fwd.Z }
    -- Сперва цель-актор (порядок игры, см. actor_target): есть — решает она; нет — щуп растительности.
    local ta = os.clock()
    local target = actor_target(pc, hero, loc, dir, bonus)
    part_ms.actor = part_ms.actor + (os.clock() - ta) * 1000.0
    local found
    if target ~= nil then
        found = is_pickup_resource(target)
    else
        local start = { X = loc.X + dir.X * bonus, Y = loc.Y + dir.Y * bonus, Z = loc.Z + dir.Z * bonus }
        local tf = os.clock()
        found = lib_cached:PickupGatheringOneInstance(pc, hero, pc, start, dir, pc.PickupInteractionDistance, pc.PickupTraceSphereRadius, {}, {}) == true
        part_ms.foliage = part_ms.foliage + (os.clock() - tf) * 1000.0
    end
    show(found)
    stat_n = stat_n + 1
    if found then stat_hits = stat_hits + 1 end
end

-- Ритм — цепочка ExecuteInGameThreadWithDelay в игровом потоке (LoopAsync крутится в чужом потоке — правило проекта, check-lua-game-thread.py);
-- одна цепочка на всю игру; сводка в журнал — раз в минуту по часам (HOUSE_RULES правило 7), а не через 60 шагов: при горящей плашке шаг 100 мс, и
-- сводка шла каждые 6 с (судья, раунд 3, 2026-11-13). Шаг цепочки — CHECK_MS, пока плашки нет, и CHECK_SHOWN_MS, пока она видна.
-- Время меряется вокруг ВСЕГО шага: ранний выход (нет героя, открыта плашка трупа) и срыв тоже стоят времени — в них живут поиски FindFirstOf, пока кэш
-- пуст (судья, раунд 3). Сводка: шаги, дошедшие до конца проверки, время, худший шаг, проверки с горящей плашкой, ошибки проверки и срывы
-- GetIsPickupResource; первые три текста ошибок за игру — отдельными строками. [NOT-TESTED]
local ticking = false
local stat_ticks, stat_err = 0, 0
local stat_t0 = os.clock()
local STAT_EVERY_S = 60
local function tick()
    if kept("plate", plate) then
        stat_ticks = stat_ticks + 1
        local t0 = os.clock()
        local ok, err = pcall(check)
        if not ok then
            errors, stat_err = errors + 1, stat_err + 1
            if errors <= 3 then log("ошибка проверки: %s", tostring(err)) end
            pcall(show, false)   -- проверка сорвалась — плашка гаснет, а не застывает в прошлом ответе (судья, 2026-11-13)
        end
        local ms = (os.clock() - t0) * 1000.0
        stat_sum = stat_sum + ms
        if ms > stat_max then stat_max = ms end
    end
    local window = os.clock() - stat_t0
    if window >= STAT_EVERY_S then
        -- окно без единого шага (главное меню, прицела нет) строки не пишет; длина окна в строке — после экрана загрузки окно бывает длиннее минуты (судья, раунд 4)
        if stat_ticks > 0 then
            log("за %.0f с: шагов %d, дошли до конца %d, своё время %.3f мс, худший шаг %.3f мс, проверок с плашкой %d, ошибок %d, срывов GetIsPickupResource %d" ..
                " · части: подсказки %.0f мс (в списке %d), цель-актор %.0f мс, растения %.0f мс, прочее %.0f мс",
                window, stat_ticks, stat_n, stat_sum, stat_max, stat_hits, stat_err, pickup_err_n, part_ms.strips, #strips, part_ms.actor, part_ms.foliage,
                -- прочее = поиски по сцене при пустом кэше, камера, GetIsPickupResource — всё вне трёх счётчиков частей (судья 2026-11-13, P2)
                stat_sum - part_ms.strips - part_ms.actor - part_ms.foliage)
        end
        stat_ticks, stat_err, stat_n, stat_sum, stat_max, stat_hits, pickup_err_n = 0, 0, 0, 0.0, 0.0, 0, 0
        part_ms.strips, part_ms.actor, part_ms.foliage = 0.0, 0.0, 0.0
        stat_t0 = os.clock()
    end
    ExecuteInGameThreadWithDelay(shown and CHECK_SHOWN_MS or CHECK_MS, tick)
end

NotifyOnNewObject(CROSSHAIR, function(w)
    if w:GetFullName():find("Default__", 1, true) then return end
    ExecuteInGameThreadWithDelay(600, function()
        -- за 600 мс игра могла пересоздать прицел (экран загрузки в игре): мёртвый объект не трогаем — pcall не ловит падение игры (судья, раунд 3)
        if valid(w) then
            local ok, err = pcall(build, w)
            if not ok then log("ошибка сборки: %s", tostring(err)) end
        end
        if not ticking then ticking = true; stat_t0 = os.clock(); ExecuteInGameThreadWithDelay(CHECK_MS, tick) end   -- окно сводки — от старта цепочки
    end)
end)

-- «Сохранить» в хабе: плашка встаёт на новое место сразу (событие хранилища, не опрос)
settings.on_change(function(changed)
    if changed.ui_pickup_x == nil and changed.ui_pickup_y == nil then return end
    if kept("plate", plate) then
        local ok, err = pcall(place, plate)
        log(ok and "место плашки: %s %%, %s %%" or "место плашки не применено: %s", ok and settings.get("ui_pickup_x", PLATE_X_DEFAULT) or tostring(err),
            settings.get("ui_pickup_y", PLATE_Y_DEFAULT))
    end
end)

log("загружен: «E %s» родным щупом подбора раз в %d мс, при видимой плашке — раз в %d мс", TEXT, CHECK_MS, CHECK_SHOWN_MS)
