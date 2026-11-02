--[[============================================================================
  KrinikPauseGameInMenu (имя — слово владельца 13.09 ~23:05) — время почти стоит, пока открыто
  меню персонажа с вкладками (инвентарь, характеристики и прочие)
  ============================================================================

  ЗАКАЗ ВЛАДЕЛЬЦА, дословно (13.09.2026 ~22:50–23:05, KUMM ideas/05):
    «было бы хорошо ещё паузу в инвентаре ставить» · «нужен мод на паузу в инвентаре,
     не только в меню» · «там не только инвентарь, там меню с множеством табов» ·
    «вот полностью в этом меню с табами находишься - нужно замедлять время».

  КАК (разведка 13.09):
    · мод PauseGame (Мастерская 3723599319, пауза в меню ESC работает) делает паузу НЕ
      паузой игры, а замедлением: GameplayStatics.SetGlobalTimeDilation. Интерфейс при этом
      живёт — ровно то, что нужно для инвентаря;
    · окна игры — «модули интерфейса» по именам; открывает и закрывает их нативная
      GUIModuleController.ActivateModule(moduleName, activate, force). В графе героя видны
      CharacterInventory, CraftingGUI, GUICarousel (закрываются вместе), BreathingMeter
      (полоса дыхания — её паузить НЕЛЬЗЯ), RespawnPointSelection;
    · нативную функцию, вызванную из блюпринта, UE4SS перехватывает (как Character:Jump у
      мода бега), поэтому мод живёт на событии, без цикла опроса.

  ⚠️ «Хук встал» ≠ «хук работает» (EXP-0071): мод считает вызовы и через минуту печатает
  счёт; каждое имя модуля пишет в журнал при смене его состояния — так находится полный
  список вкладок меню.
============================================================================]]

local MOD_NAME = "KrinikConanUI:PauseGameInMenu"   -- до 2026-10-30 — отдельный мод KrinikPauseGameInMenu

-- Модули, пока открыт любой из которых время почти стоит. GUICarousel — предположительно
-- само меню с вкладками; CharacterInventory — инвентарь. Список дополняется по журналу.
local PAUSE_MODULES = {
    GUICarousel = true,
    CharacterInventory = true,
}
-- ⚙️ ОПЫТ 16.09.2026 (баг 12). A/B доказал: с этим модом диалог «Выберите Черту» мёртв, без него
-- работает. Мод делает ДВА дела, и надо знать, какое виновато: замедление времени и перехват
-- ActivateModule. Перехват с 0.2.0 нужен ТОЛЬКО ради журнала модулей — поэтому он снимается флагом
-- первым. Флаг оставлен в коде: он же рубильник для следующего, кто будет это перепроверять.
local HOOK_MODULES = true    -- перехват ActivateModule: журнал модулей И признак модалки игры

-- 🩹 ЛЕЧЕНИЕ БАГА 12 (16.09.2026). Игра сама поднимает поверх меню модалку «Выберите Черту»
-- (модуль PerkSelection, виджет W_PerkSelection_C). Под нашим замедлением она МЁРТВАЯ: пункт
-- подсвечивается наведением, но не выбирается, «Отложить выбор» не закрывает, Esc не закрывает.
-- Доказано A/B на одном сохранении: мод выключен — тот же клик по тому же пункту срабатывает
-- (Сила 9 → 10, очки 12 → 11).
--
-- Почему исключение, а не костыль: владелец заказывал паузу в МЕНЮ, куда он вошёл сам
-- («вот полностью в этом меню с табами находишься — нужно замедлять время»). Модалка, которую
-- игра выставляет ему НАВСТРЕЧУ, в этот заказ не входит. Так что мы не «чиним обход», а
-- возвращаемся к заказу.
--
-- Границы знания, честно: почему именно эта модалка не переживает 0.0001, мы НЕ выяснили —
-- обычная кнопка меню под тем же замедлением работает (клик «+» списал очко, Проворство 9 → 10),
-- и меню ESC собрано на том же классе кнопки. Клик испускает нативный C++ FLXButtonBase,
-- исходников игры кит не везёт. Поэтому лечение закрывает ОБЕ уцелевшие причины разом:
-- перехват снят (HOOK_MODULES = false) и время в модалке не трогается.
-- Список исключений оставлен ПУСТЫМ намеренно: с 0.5.0 лечим значением замедления, а не списком
-- окон. Механизм ниже рабочий и проверенный — если найдётся окно, которое не переживает даже 0.01,
-- впиши сюда его имя, и пауза будет сниматься на время его жизни.
local NO_PAUSE_MODULES = {}

-- Имена ESC-меню взяты НАБЛЮДЕНИЕМ, а не догадкой, и их ДВА — вот почему:
--   · `IngameMenu` — родное имя модуля, перехват печатал его 16.09, когда владелец открыл ESC;
--   · но в проверке 22:19 ESC открывался и закрывался ДВАЖДЫ подряд, а `IngameMenu` не пришёл ни
--     разу — в этой сборке ESC-меню через ActivateModule не проходит. Зато ровно вместе с ним
--     открывается и закрывается `SML_ModList` — панель мода Simple Modlist, которая живёт в
--     ESC-меню. Это НАБЛЮДАЕМЫЙ ЗАМЕНИТЕЛЬ, а не догадка.
-- ⚠️ ЧЕСТНАЯ ГРАНИЦА: заменитель — чужой мод. Уберут Simple Modlist — ESC перестанет опознаваться
-- и получит замедление меню (0.03) вместо почти нуля. Это не поломка, а ослабление: игру в ESC всё
-- равно морозит мод PauseGame из Мастерской. Признак, по которому это ловится: в журнале при
-- открытом ESC стоит «меню открыто: замедление времени 0.03», а не 0.0001.
local ESC_MODULES = { IngameMenu = true, SML_ModList = true }

-- 🩹 0.5.0, 16.09.2026. БЫЛО 0.0001 (нижняя граница движка, как у мода PauseGame из Мастерской) —
-- и это оказалось СЛИШКОМ круто для интерфейса Конана. Наблюдения, на которых это стоит:
--   · модалка «Выберите Черту» под 0.0001 мертва полностью (баг 12);
--   · но и ОБЫЧНАЯ кнопка «+» на полосе атрибута под 0.0001 срабатывает ЧЕРЕЗ РАЗ — 16.09 в
--     21:58–22:00 из пяти кликов подряд прошёл один; при 1.0 проходят все.
-- То есть дело не в конкретном окне, а в самом значении: игра обрабатывает нажатия по игровому
-- времени, и на 1/10000 скорости они теряются. Лечение поэтому не «исключить окно», а «замедлять
-- сильно, но не насмерть»: 0.01 — это в сто раз медленнее, за пять минут в меню мир проживает три
-- секунды. Для голода, жажды и врагов это стояние на месте, а интерфейс остаётся живым.
-- ⏱️ 0.6.0 — ДВА ЗАМЕДЛЕНИЯ, слово владельца 16.09 22:17–22:18:
--   «только в меню, которое по ESC нужно сильнее замедление делать, почти ноль» ·
--   «а в меню, которое интерфейс игры, характеристики — там 0.03 давай сделаем».
-- Почему они РАЗНЫЕ, а не одно (это и есть причина, по которой заказ разумен):
--   · в ESC-меню игрок ничего не «настраивает» в игровых данных — там кнопки выхода и опций, и
--     баг 12 туда не достаёт; значит можно почти ноль, как у мода PauseGame из Мастерской;
--   · в меню с вкладками игрок РАБОТАЕТ: жмёт «+» на атрибутах, отвечает модалкам, таскает вещи —
--     и вот там слишком крутое замедление съедает нажатия (баг 12).
-- 0.05 владелец принял («норм», «пойдёт») и тут же уточнил до 0.03 — его цифра, не моя.
local MENU_DILATION = 0.03      -- меню с вкладками, сундуки, станции крафта
local ESC_DILATION  = 0.0001    -- меню по ESC: почти ноль
local NORMAL_DILATION = 1.0

-- Состояние — выше функций, которые его читают (EXP-0072).
local open_modules = {}      -- имя модуля из PAUSE_MODULES → true, пока открыт
local last_state = {}        -- имя любого модуля → последнее записанное в журнал состояние
-- 0.6.0: это больше НЕ флаг «мы поставили паузу», а ЧИСЛО — какое замедление сейчас применено.
-- Так выбор между ESC и меню с вкладками не требует второго состояния (Оккам).
local we_paused = NORMAL_DILATION
local hook_calls = 0
-- ⚠️ ЗДЕСЬ, А НЕ НИЖЕ. Оплачено 16.09.2026 21:52: объявленное ниже on_activate, это имя пришло в
-- замыкание как nil — «attempt to index a nil value (global 'modal_open')», и исключение молча не
-- сработало. Тот же класс, что EXP-0072 и грабля 09.09 в ConanModPackStatus: локальное имя,
-- объявленное НИЖЕ места использования, равно nil.
local esc_open = {}          -- имя модуля ESC-меню → true, пока открыто
local modal_open = {}        -- имя модалки игры (NO_PAUSE_MODULES) → true, пока открыта
local modal_was = nil
-- 🩹 0.4.0, слово владельца 16.09 21:56: «работает, но игру с паузы снимает» — «меня бить начали
-- в мире, когда ты в меню залез». Снимать паузу НАСОВСЕМ нельзя: это меняет баг на потерю самой
-- паузы, ради которой мод и написан.
-- Наблюдение, из которого выросла догадка: клик «+» по полосе атрибута под 0.0001 РАБОТАЕТ (очко
-- списалось, Проворство 9 → 10), а кнопки модалки — нет. Разница в том, что модалка РОЖДАЕТСЯ при
-- замороженном времени. Значит время нужно отпустить не навсегда, а на короткую фору, пока виджет
-- встаёт, и сразу вернуть паузу. Мир успевает прожить ~1 секунду вместо всего разговора.
local MODAL_GRACE_MS = 1000
local modal_grace = 0        -- сколько тиков опроса ещё держим время живым

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, ok and s or tostring(fmt)))
end

-- ===================== 0.16.0: ПАНЕЛЬ ИНВЕНТАРЯ — ТОЛЬКО «НАСТРОЙКИ МОДОВ»; КНОПКА HOSAV СПРЯТАНА ВСЕГДА =====================
-- Слово владельца 2026-11-01 15:49 «соответственно, она там одна должна остаться» · «настройки рыбалки и настройки интерфейса оттуда уходят»
-- (KUMM plans/40_epic40_phase3_inventory_button_list.md). Окна Hosav и рыбалки теперь открывает список «Настройки модов» (krinik_mods_button.lua).
-- Кнопка рыбалки: её вставку (BPC_EFT_Tuning.Graft) мод сам больше не зовёт — опрос заглушён НАТИВНО (KRINIK MODIFIED, таймер 0.3 → 1e9),
-- а 0.8.0–0.12.0 этого раздела звали Graft по событию «Снаряжения» и клали кнопку в ряд; теперь не зовём — кнопки нет. Код вставки и раскладки
-- ряда (0.8.0, 0.10.0, 0.12.0) удалён целиком (история — git пакета до 2026-11-01).
-- Кнопка Hosav — свой слой поверх экрана (W_UI_SettingsButton); её опрос тоже заглушён нативно (Delay 3.0 → 1e9), а показывал её этот раздел
-- по событию «Снаряжения» (0.7.0). Теперь по тому же событию её внутренняя кнопка СВОРАЧИВАЕТСЯ: Hosav создаёт кнопку ПОСЛЕ события XCS_Panel
-- (гонка 26.10 17:56) — поэтому повтор, пока кнопка не найдена: не больше HOSAV_RETRIES раз через HOSAV_RETRY_MS, конечная цепочка после события,
-- не цикл опроса (EXP-0052); новое событие отменяет недоделанный повтор (поколение want_gen). Ассет кнопки не правим: видимость её внутренней
-- кнопки и так ставит только этот раздел (автор — опросом, который заглушён).
-- [NOT-TESTED]
local EQUIPMENT_MODULE = "XCS_Panel"
local VIS_COLLAPSED = 1   -- то же значение, что ставит сам Hosav (байткод: Byte 1)
local HOSAV_RETRIES, HOSAV_RETRY_MS = 4, 250
local want_gen = 0
local function hide_hosav_button(tries, gen)
    tries = tries or 0
    if gen == nil then want_gen = want_gen + 1; gen = want_gen end
    if gen ~= want_gen then return end
    local n = 0
    for _, b in ipairs(FindAllOf("W_UI_SettingsButton_C") or {}) do
        if b and b:IsValid() then
            local inner = b.WBP_ButtonBase
            if inner and inner:IsValid() then
                inner:SetVisibility(VIS_COLLAPSED)
                n = n + 1
            end
        end
    end
    if n == 0 and tries < HOSAV_RETRIES then
        -- таймер UE4SS зовёт не из игрового потока, а виджет трогают только из него
        ExecuteInGameThreadWithDelay(HOSAV_RETRY_MS, function()
            ExecuteInGameThread(function() hide_hosav_button(tries + 1, gen) end)
        end)
        return
    end
    log("кнопка Hosav «Настройки интерфейса»: скрыта (%d, повторов %d)", n, tries)
end
local function live(o) return o ~= nil and o:IsValid() end

-- ===================== 0.9.0: ПОЗДНИЕ ВСТАВКИ МОДОВ НА «СНАРЯЖЕНИИ» — ПО РОЖДЕНИЮ ПОРТРЕТА ГЕРОЯ =====================
-- Владелец 29.10 с кадром: «вот что обвел с задержкой появляется на экране, а не сразу при его открытии» — значки школ магии Era of Trials,
-- эмблема с мечом Enhanced Armory and Arsenal и «Аксессуары» общей библиотеки Accessory System (KUMM bugs/64 п. 17, 26). Оба мода ждут портрет героя таймером Delay по ИГРОВОМУ
-- времени (EoT 0.1 с, EAA 1.0 с): сигнал модуля CharacterInventory приходит на 50 мс раньше, чем хаб создаёт W_UICharacterDisplay_C. А в хабе
-- это же мод держит время мира 0.03 — секунда EAA тянулась ≈33 с, 0,1 с EoT — 0,8–3,3 с (замер пультом 17:56, A-B по замедлению).
-- Лечение — событие вместо ожидания: их задержки заглушены НАТИВНО (KRINIK MODIFIED, строки flt:), а здесь по рождению портрета на «Снаряжении»
-- зовём их же код с той точки, куда вернулся бы Delay (ExecuteUbergraph — то, что делает сам Delay при возврате): EAA — 286, EoT — 15.
-- Один вызов на кадр (рождений бывает несколько подряд), только пока открыта вкладка «Снаряжение» (XCS_Panel).
-- ⚠️ Звать точку возврата чужого блюпринта можно, ТОЛЬКО если её код заново спрашивает мир (EAA 286 — GetAllWidgetsOfClass; EoT 15 —
-- module:GetWindowRoot(), модуль живёт долго). У Accessory System точка 61 начинается с приведения сохранённого окна хаба, а хаб пересоздаётся на
-- каждой вкладке: вызов снаружи уронил игру 29.10 18:19 (EXPERIENCE EXP-0371) — ему задержка только сокращена в паке (0.2 → 0.0015).
-- Компоненты ищутся через героя (GetComponentByClass), не перебором FindAllOf по классу компонента (EXP-0330).
-- Виджет EAA сам красит камень и показывает свои кнопки в UpdateIndicator — по Delay 0.2 после рождения (под паузой 6,7 с): зовём сразу.
-- [NOT-TESTED]
local DISPLAY_CLASS = "/Game/UI/Inventory/CharacterDisplay/W_UICharacterDisplay.W_UICharacterDisplay_C"
local EAA_CLASS = "/Game/Mods/EnhancedArmoryAndArsenal/UI/AC_EAA_Inventorybutton.AC_EAA_Inventorybutton_C"
local EOT_CLASS = "/Game/Mods/EraOfTrials/Systems/UIModifications/EoT_AC_InterfaceInjectorComponent.EoT_AC_InterfaceInjectorComponent_C"
local EAA_ENTRY, EOT_INVENTORY_ENTRY = 286, 15
local inject_pending = false
local function hero_component(class_path)
    local pc = FindFirstOf("PlayerController")
    if not (pc and pc:IsValid()) then return nil end
    local pawn = pc:K2_GetPawn()
    if not (pawn and pawn:IsValid()) then return nil end
    local cls = StaticFindObject(class_path)
    if not (cls and cls:IsValid()) then return nil end
    local c = pawn:GetComponentByClass(cls)
    if c and c:IsValid() then return c end
    return nil
end
local function inject_late_mods()
    inject_pending = false
    if not last_state[EQUIPMENT_MODULE] then return end
    local t0 = os.clock()
    local eaa, eot, ind = 0, 0, 0
    local c = hero_component(EAA_CLASS)
    if c then
        local ok, e = pcall(function() c:ExecuteUbergraph_AC_EAA_Inventorybutton(EAA_ENTRY) end)
        if ok then eaa = 1 else log("EAA: вставка упала: %s", tostring(e)) end
        for _, w in ipairs(FindAllOf("BP_EAA_InventoryButton_C") or {}) do   -- виджеты, не компоненты: единицы штук
            if w and w:IsValid() and pcall(function() w:UpdateIndicator() end) then ind = ind + 1 end
        end
    end
    c = hero_component(EOT_CLASS)
    if c then
        local ok, e = pcall(function() c:ExecuteUbergraph_EoT_AC_InterfaceInjectorComponent(EOT_INVENTORY_ENTRY) end)
        if ok then eot = 1 else log("EoT: вставка упала: %s", tostring(e)) end
    end
    log("портрет героя родился — вставки EAA %d (индикатор %d), EoT %d (%.2f мс)", eaa, ind, eot, (os.clock() - t0) * 1000)
end
local function watch_character_display()
    local ok, e = pcall(function()
        NotifyOnNewObject(DISPLAY_CLASS, function()
            if inject_pending then return end
            inject_pending = true
            -- рождение — внутри CreateWidget, до AddChild: вставкам нужен родитель портрета, поэтому — следующим заходом игрового потока
            ExecuteInGameThread(function() pcall(inject_late_mods) end)
        end)
    end)
    log("рождение портрета героя: слежка %s", ok and "встала" or ("НЕ встала: " .. tostring(e)))
end

-- ===================== 0.8.0: УХОД СО «СНАРЯЖЕНИЯ» — РАНЬШЕ СОБЫТИЯ XCS_Panel =====================
-- То же видео: при переходе на «Таланты» кнопка Hosav висела 3 кадра поверх ванильной «Показать контент из DLC». Замер пультом 2026-10-29
-- 16:56 (метки журнала): NextCarouselWindow 17.535 → XCS_Panel false 17.681 — событие ухода опаздывает на 146 мс; при возврате
-- PrevCarouselWindow → XCS_Panel true — 42 мс. Вкладку меняет родной класс хаба CarouselWindow (родитель W_Carousel_C; у блюпринта своих
-- Next/Prev нет — перехват по пути блюпринта «no UFunction», 16:55): NextCarouselWindow / PrevCarouselWindow (E/Q) и SetCarouselIndex
-- (выбор вкладки по номеру). На их входе кнопка прячется; если новая вкладка опять «Снаряжение», XCS_Panel true покажет её снова.
-- [NOT-TESTED]
local CAROUSEL_CLASS = "/Script/ConanSandbox.CarouselWindow"
local function on_carousel_switch(which)
    -- 0.16.0: кнопка Hosav спрятана всегда; на входе карусели прячутся «Настройки модов» и их список (krinik_mods_button.lua)
    if _G.__krinik_mods_button then _G.__krinik_mods_button(false) end
    log("карусель хаба: %s — «Настройки модов» спрятаны до XCS_Panel", which)
end
local function hook_carousel()
    for _, fn in ipairs({ "NextCarouselWindow", "PrevCarouselWindow", "SetCarouselIndex" }) do
        local ok, e = pcall(function()
            RegisterHook(CAROUSEL_CLASS .. ":" .. fn, function() pcall(on_carousel_switch, fn) end)
        end)
        log("карусель хаба: перехват %s:%s %s", CAROUSEL_CLASS, fn, ok and "встал" or ("НЕ встал: " .. tostring(e)))
    end
end

-- ===================== 0.7.0: КРАФТ В ИНВЕНТАРЕ НА ПАУЗЕ — ВЫКЛЮЧАТЕЛЬ, ПОКА НЕ ЗАМЕРЕНО =====================
-- Решение владельца 26.10: «мир замедлен, но крафт быстрый в инвентаре» · «я за то, чтобы в инвентаре ускорить» · «это будет немного
-- читерство, но для соло ПВЕ игры сойдет». Ручка найдена пультом: у героя СВОЯ очередь `BasePlayerChar_C.CraftingQueue` с
-- `CraftTimeMultiplier` (станции мира не трогаются). Замер 2026-10-31 11:50–11:54 настоящим крафтом «Грубой повязки» в открытом инвентаре
-- (замедление 0.03): множитель умножает ДЛИТЕЛЬНОСТЬ и читается при СТАРТЕ предмета (0.03 посреди начатого — без перемен; 33.3 на старте —
-- предмет почти стоит); с множителем = замедлению повязка готова за ≈ 2.5 с настоящего времени, без него — ≈ минута. Множитель = замедлению
-- держит настоящее время крафта прежним в любом меню (Esc 0.0001 тоже). [TESTED: 2026-10-31 · через мод: инвентарь открыт → множитель 0.03 → повязка за ≈ 2.5–3 с, закрыт → 1.0 · KUMM testcases/reports/2026-10-31_conan-craft-speed-in-inventory.md]
local CRAFT_SPEEDUP = true
-- Выключатель — строка «Крафт в меню без замедления» хаба «Моды Krinik'а» (ключ ui_craft, KUMM план 38 этап 2); выключен — множитель 1.0, чтобы
-- не остался прежний 0.03 от включённого. [NOT-TESTED]
local settings = require("krinik_settings")
local function hero_craft_multiplier(value)
    if not settings.get("ui_craft", CRAFT_SPEEDUP) then value = 1.0 end
    for _, q in ipairs(FindAllOf("CraftingQueue") or {}) do
        if q:IsValid() and q:GetFullName():find("BasePlayerChar_C", 1, true) then
            q.CraftTimeMultiplier = value
            log("крафт героя: CraftTimeMultiplier = %s", tostring(value))
        end
    end
end

local function world_context()
    local pc = FindFirstOf("PlayerController")
    if pc and pc:IsValid() then return pc end
    return nil
end

local function set_dilation(value, reason)
    local ctx = world_context()
    if not ctx then log("%s: нет PlayerController — время не тронуто", reason); return false end
    local gs = StaticFindObject("/Script/Engine.Default__GameplayStatics")
    if not (gs and gs:IsValid()) then log("%s: GameplayStatics не найден", reason); return false end
    local ok, e = pcall(function() gs:SetGlobalTimeDilation(ctx, value) end)
    local now = "?"
    pcall(function() now = ("%.4f"):format(gs:GetGlobalTimeDilation(ctx)) end)
    log("%s: замедление времени %s → лежит %s%s", reason, tostring(value), now, ok and "" or (" · ОШИБКА " .. tostring(e)))
    return ok
end

local function any_open()
    for _ in pairs(open_modules) do return true end
    return false
end

-- 0.9.1: опрос паузы (poll, объявлен ниже) зовётся и по событию вкладки «Снаряжение». Оплачено 2026-10-29 18:30: при ПЕРВОМ открытии хаба время
-- ещё 1.0 до 250 мс (цикл опроса), и сокращённая задержка Accessory System (0.0015, пак EAA) срабатывала раньше, чем рождался портрет героя, —
-- кнопки «Аксессуары» не было вовсе. Замедление по событию держит время хаба одним с первого кадра. Имя объявлено здесь: локальное, объявленное
-- НИЖЕ места вызова, было бы nil (EXP-0072).
local poll_now = nil

-- 0.13.0: ПОДСКАЗКИ ПАНЕЛИ РЫБАЛКИ БЕЗ МЕРЦАНИЯ. Слово владельца 2026-10-30: «по хочеру поп-апы открываются - и с ними такой же баг мерцания
-- при перерисовки их размера, как в основном ХАБе было» (KUMM план 36 W17). W_EFT_Tooltip.Txt_Tip — AutoWrapText True внутри SizeBox (до 380):
-- перенос берёт ширину ПРОШЛОГО кадра, подсказка рождается в одну строку и прыгает в две. Лечение — как у подсказки предмета в хабе
-- (KrinikUIFixes 1.2.0): AutoWrapText false + WrapTextAt 380. Ассет не поддался: имени WrapTextAt нет в таблице имён пакета, а добавленное имя
-- zen-заголовок не знает — игра упала при загрузке мода («ObjectSerializationError … W_EFT_Tooltip», прогон 2026-10-30 08:41); круг
-- to-legacy → to-zen у этого виджета расходится на 4 байта. Поэтому — правило дома «Lua — только когда ассет не поддаётся: один раз, без
-- опроса»: правка — на каждом ОТКРЫТИИ панели (ниже — почему не один раз), по событию, не по таймеру.
-- [TESTED: 2026-10-30 · короткая подсказка «Холод» 490×80 с первого кадра в 3 из 3 переоткрытий (до правки — одна строка → две); у длинной в 1 из 3
--  остаётся отставание фона на один кадр · KUMM testcases/reports/2026-10-30_conan-fishing-tooltip-translation.md]
local TIP_WRAP_AT = 380.0
local TIP_FIX_DELAY_MS = 1000   -- окно панели и его подсказки рождаются ПОСЛЕ ActivateModule: в момент события класса подсказки ещё нет (прогон 08:52)
-- Шаблон правится на КАЖДОМ открытии: после закрытия панели игра выгружает класс подсказки и при следующем открытии грузит его заново, с
-- исходными значениями (пультом 2026-10-30 09:0x: правка шаблона держалась, пока панель открыта, и пропадала после переоткрытия). Подсказки
-- панель создаёт при своём рождении (34 экземпляра), поэтому правятся и они — один проход по текстам, только на открытии (лаг открытия допустим).
local function fix_fishing_tips()
    local n = 0
    for _, t in ipairs(FindAllOf("TextBlock") or {}) do   -- templates-ok: the template IS edited on purpose (reloaded on every open, see above)
        local fn = t:GetFullName()
        if fn:find("W_EFT_Tooltip_C", 1, true) and fn:find("Txt_Tip", 1, true) then
            t.AutoWrapText = false
            t.WrapTextAt = TIP_WRAP_AT
            n = n + 1
        end
    end
    log("подсказка рыбалки: перенос по ширине %.0f поставлен %d текстам (шаблон и живые)", TIP_WRAP_AT, n)
end

-- 0.14.0: ПОДПИСИ СЛОЖНОСТИ РЫБАЛКИ — РАЗДЕЛЕНЫ ЧЕРТАМИ, НА РАВНОМ РАССТОЯНИИ. Слово владельца 2026-10-30 ≈08:15: «вот тут подписи сложности нужно
-- чем-то разделить, может вертикальными чертами и расставить на равномерном расстоянии, это подпись к ползунку» (KUMM план 36 W18a). Под ползунком
-- W_EFT_Panel ряд PresetLabels: четыре Fill-слота с весами 1·2·2·1 и тексты Txt_Preset0..3 — каждое слово стоит под своим делением, но русские слова
-- длинные: «Легко Спокойно» и «Строже Ваниль» почти слиплись, а между средними пусто (кадр 2026-10-30 16:39, KUMM games/ConanExiles/mods/JaarFishing.md).
-- Ассет не годится: те же названия панель показывает и крупной надписью текущей сложности (Txt_PresetState), а новых виджетов в ряд не добавить
-- правкой свойств. Поэтому на каждом открытии (класс панели перегружается, как у подсказок) — одна строка в Txt_Preset0 из ЕЁ ЖЕ четырёх слов
-- через « | », по центру; остальные три свёрнуты — их место отдаётся первой строке. Только сеттеры текста, видимости и выравнивания, без новых виджетов.
-- [TESTED: 2026-10-30 · first open and a re-open, frames 16:46, one line in the slider width · KUMM testcases/reports/2026-10-30_conan-fishing-difficulty-captions.md]
local CAPTION_SEP = " | "   -- один пробел: строка ровно во всю ширину шкалы (кадр 16:4x); два пробела или тонкие — вылезает за край колонки на 17 точек
local JUSTIFY_CENTER = 1   -- VIS_COLLAPSED — выше (одно имя верхнего уровня — один раз, _config/check-lua-shadow.py)
local function fix_fishing_captions()
    local done = 0
    for _, w in ipairs(FindAllOf("W_EFT_Panel_C") or {}) do
        local fn = w:GetFullName()
        -- живой экземпляр, не шаблон и не объект по умолчанию (KUMM EXP-0386, EXP-0385)
        if fn:find("/Engine/Transient", 1, true) and not fn:find("Default__", 1, true) and not fn:find(":WidgetTree", 1, true) then
            local t = {}
            for i = 0, 3 do
                local x = w:GetWidgetFromName(FName("Txt_Preset" .. i))
                if not (x and x:IsValid()) then t = nil; break end
                t[#t + 1] = x
            end
            if t and t[2]:GetVisibility() ~= VIS_COLLAPSED then
                local words = {}
                for i = 1, 4 do words[i] = t[i]:GetText():ToString() end
                t[1]:SetText(FText(table.concat(words, CAPTION_SEP)))
                t[1]:SetJustification(JUSTIFY_CENTER)
                for i = 2, 4 do t[i]:SetVisibility(VIS_COLLAPSED) end
                done = done + 1
            end
        end
    end
    log("подписи сложности рыбалки: одной строкой через черты в %d панелях", done)
end

local function on_activate(name, activate)
    if name == "ExilesFishingTuning" and activate then
        -- Задержка в игровом потоке (2026-10-31): ExecuteWithDelay зовёт из рабочего потока UE4SS — класс падений, check-lua-game-thread.py.
        ExecuteInGameThreadWithDelay(TIP_FIX_DELAY_MS, function()
            local ok, e = pcall(fix_fishing_tips)
            if not ok then log("подсказка рыбалки: ошибка %s", tostring(e)) end
            ok, e = pcall(fix_fishing_captions)
            if not ok then log("подписи сложности рыбалки: ошибка %s", tostring(e)) end
        end)
    end
    if name == EQUIPMENT_MODULE and activate and poll_now then
        local ok, e = pcall(poll_now)
        if not ok then log("опрос по событию упал: %s", tostring(e)) end
    end
    if last_state[name] ~= activate then
        last_state[name] = activate
        log("модуль %s: %s%s", name, activate and "открыт" or "закрыт", PAUSE_MODULES[name] and " (в списке паузы)" or "")
    end
    -- 0.6.0: ESC-меню опознаётся по имени модуля — ему своё, более крутое замедление.
    if ESC_MODULES[name] then
        if activate then esc_open[name] = true else esc_open[name] = nil end
    end
    -- 0.3.1: здесь же ведётся признак «игра подняла свою модалку» — баг 12.
    if NO_PAUSE_MODULES[name] then
        if activate then modal_open[name] = true else modal_open[name] = nil end
    end
    if PAUSE_MODULES[name] then
        if activate then open_modules[name] = true else open_modules[name] = nil end
    end
    -- 0.16.0: в панели инвентаря — только «Настройки модов» (по вкладке «Снаряжение»); кнопка Hosav сворачивается на каждом открытии
    if name == EQUIPMENT_MODULE then
        if activate then hide_hosav_button() end
        if _G.__krinik_mods_button then _G.__krinik_mods_button(activate) end   -- «Настройки модов» (krinik_mods_button.lua, план 40.3)
    elseif name == "CharacterInventory" then
        if activate then hide_hosav_button() elseif _G.__krinik_mods_button then _G.__krinik_mods_button(false) end
    end
end

-- ===================== 0.2.0: ПРИЗНАК «ПОЛНОЭКРАННЫЙ ИНТЕРФЕЙС ОТКРЫТ» =====================
-- Проверка 13.09 22:55: меню с вкладками (Tab) через ActivateModule НЕ проходит — открывается и
-- закрывается только XCS_Panel, боковая панель вкладки «Снаряжение». Кит (отражение классов)
-- показал у GUIModuleController нативные IsFullscreenGUIActive / IsModuleActive / ToggleModule,
-- у GUIModule — IsFullscreen. Меню с вкладками полноэкранное (сундуки и станции — тоже), поэтому
-- решение берётся из IsFullscreenGUIActive одним медленным циклом.
-- ⛔ Правки — только перезапуском игры (цикл нечем остановить, EXP-0062).
-- [TESTED: 2026-09-13 23:08–23:09 · вход в мир прошёл (главное меню и экран загрузки не замедляются);
--  Tab → «ОТКРЫТ», замедление 0.0001; два снимка через 20 с совпали до цифры (здоровье 238/260, голод 8 %,
--  жажда 0 %, опыт 528/821); Tab → «закрыт», 1.0000. НЕ проверено: сундуки и станции, смерть и возрождение,
--  ESC-меню вместе с PauseGame, работает ли крафт на паузе]
local POLL_MS = 250
local fullscreen_was = nil
local armed = false

-- ⚠️ ТОЛЬКО В МИРЕ. Оплачено 13.09 23:00: главное меню игры — тоже полноэкранный интерфейс; мод
-- замедлил время в нём до 0.0001, и загрузка мира не пошла дальше меню (35 кликов «Продолжить»
-- за 4 минуты). Нет живого героя — меню не наше: время не трогаем, а если сами замедлили — вернуть.
-- Поиск по сцене — НЕ на каждом опросе (HOUSE_RULES правило 7). До 2026-11-01 здесь и в poll() 4 раза в секунду шли FindAllOf героя и
-- FindFirstOf контроллера интерфейса — обход всего списка объектов игры (`[OWNER]` 2026-11-01 14:25 «уважительно к CPU работают моды твои?» ·
-- «не перебирают сотни объектов в каждом кадре?» · «или сотри объектов раз в 1...2 секунды?»). Теперь найденный объект держится; заново
-- ищем, только когда он умер или герой мёртв (смерть, загрузка мира), и не чаще раза в SEARCH_EVERY опросов (2 с).
local SEARCH_EVERY = 8
local hero_obj, gmc_obj = nil, nil
local hero_wait, gmc_wait = 0, 0
local searches = 0

local function hero_hp(p)
    local hp = 0
    pcall(function() hp = p:GetIntStat(1, 0) end)
    return hp
end

local function hero_in_world()
    if hero_obj and hero_obj:IsValid() and hero_hp(hero_obj) > 0 then return true end
    hero_obj = nil
    if hero_wait > 0 then hero_wait = hero_wait - 1; return false end
    hero_wait = SEARCH_EVERY
    searches = searches + 1
    for _, p in ipairs(FindAllOf("BasePlayerChar_C") or {}) do
        if p and p:IsValid() and hero_hp(p) > 0 then hero_obj = p; return true end
    end
    return false
end

local function cached_gmc()
    if gmc_obj and gmc_obj:IsValid() then return gmc_obj end
    gmc_obj = nil
    if gmc_wait > 0 then gmc_wait = gmc_wait - 1; return nil end
    gmc_wait = SEARCH_EVERY
    searches = searches + 1
    local g = FindFirstOf("GUIModuleController")
    if g and g:IsValid() then gmc_obj = g end
    return gmc_obj
end

-- 💥 ОПЛАЧЕНО КРЭШЕМ 16.09.2026 21:49. Здесь стоял опрос нативной gmc:IsModuleActive(name) раз в
-- 250 мс — игра упала на загрузке мира с EXCEPTION_ACCESS_VIOLATION (0x70), стек целиком в
-- UE4SS.dll. Урок: pcall НЕ защищает от нарушения доступа в нативном коде; неверный тип аргумента
-- у нативной функции — это не ошибка Lua, это падение процесса. Признак модалки берётся из УЖЕ
-- РАБОТАЮЩЕГО перехвата ActivateModule (он приносил «модуль PerkSelection: открыт» 16.09 в 21:03),
-- то есть из чистой таблицы Lua — новых нативных вызовов в цикле НЕТ.
local polls = 0
local function poll()
    polls = polls + 1
    if polls % 240 == 0 then   -- раз в минуту: сколько раз опрос дошёл до поиска по сцене (в мире с живым героем — 0)
        log("минута: поисков по сцене %d из 240 опросов", searches)
        searches = 0
    end
    local gmc = cached_gmc()
    if not gmc then return end
    local on = false
    local ok = pcall(function() on = gmc:IsFullscreenGUIActive() end)
    if not ok then return end
    local in_world = hero_in_world()
    if on and not in_world then on = false end
    -- ⚠️ СНАЧАЛА УВИДЕТЬ ЗАКРЫТЫМ. Оплачено 13.09 23:06: экран ЗАГРУЗКИ мира тоже полноэкранный, а живой
    -- герой в этот момент уже есть — мод замедлил время, и загрузка встала на 82 %. Поэтому пауза
    -- «взводится» только после того, как в мире полноэкранный интерфейс хоть раз увиден закрытым;
    -- новый герой (смерть, загрузка) снимает взвод.
    if not in_world then armed = false end
    if in_world and not on and not armed then
        armed = true
        log("взведено: герой в мире, интерфейс закрыт — дальше меню ставит паузу")
    end
    if on and not armed then on = false end
    -- 🩹 Баг 12: пока игра держит свою модалку — время НЕ наше. Ход времени возвращается
    -- на 1.0 и удерживается, а как только модалка закрыта, пауза меню встаёт обратно сама.
    local modal, modal_name = false, nil
    for n in pairs(modal_open) do modal, modal_name = true, n; break end
    if modal ~= modal_was then
        modal_was = modal
        if modal then
            modal_grace = math.ceil(MODAL_GRACE_MS / POLL_MS)
            log("модалка игры %s: ОТКРЫТА — отпускаю время на %d мс, чтобы она ожила", tostring(modal_name), MODAL_GRACE_MS)
        else
            modal_grace = 0
            log("модалка игры закрыта — пауза меню как обычно")
        end
    end
    -- Фора ТОЛЬКО на рождение модалки. Кончилась — пауза возвращается сама, хотя модалка ещё открыта.
    if modal and modal_grace > 0 then
        modal_grace = modal_grace - 1
        on = false
        if modal_grace == 0 then log("фора кончилась — пауза возвращается, модалка остаётся открытой") end
    end
    -- 0.6.0: ЧЕГО ХОТИМ прямо сейчас — одно число, а не «пауза вкл/выкл». Так два разных
    -- замедления (ESC и меню с вкладками) живут без второго флага, и переход между ними
    -- происходит сам собой, если игрок открыл ESC поверх меню.
    local esc = false
    for _ in pairs(esc_open) do esc = true; break end
    local want = NORMAL_DILATION
    local why = "меню закрыто"
    if on then
        if esc then want, why = ESC_DILATION, "ESC-меню открыто"
        -- «Замедление мира в меню» хаба — во сколько раз медленнее (ключ ui_menu_slow; 1 — без замедления); замедление = 1 / раз
        else want, why = 1.0 / math.max(1.0, settings.get("ui_menu_slow", 1.0 / MENU_DILATION)), "меню открыто" end
    end
    if on ~= fullscreen_was then
        fullscreen_was = on
        log("полноэкранный интерфейс: %s", on and "ОТКРЫТ" or "закрыт")
    end
    if want ~= we_paused then
        if set_dilation(want, why) then
            we_paused = want
            hero_craft_multiplier(want)   -- 0.7.0: крафт героя идёт с той же скоростью для игрока (выключено, см. CRAFT_SPEEDUP)
        end
    end
end
poll_now = poll   -- 0.9.1: тот же опрос — по событию вкладки «Снаряжение» (on_activate)

if type(LoopInGameThreadWithDelay) == "function" then
    LoopInGameThreadWithDelay(POLL_MS, function() local ok, e = pcall(poll); if not ok then log("опрос упал: %s", tostring(e)) end end)
    log("опрос IsFullscreenGUIActive: штатный цикл, раз в %d мс", POLL_MS)
else
    log("ОШИБКА: LoopInGameThreadWithDelay нет в этой сборке UE4SS — опрос не запущен")
end

-- ===================== 0.11.0: ESC В ОКНЕ МОДА ПОВЕРХ ХАБА ЗАКРЫВАЕТ ТОЛЬКО ЭТО ОКНО =====================
-- Слово владельца 29.10: Esc в окне рыбалки или Hosav закрывал весь хаб — «нужно сразу мод рыбалки закрывать» (KUMM план 36, STATUS 22:58 п. 1).
-- Окна игры поверх вкладки (выбор перка, бонусы невольника) — модули Modal, и их закрывает собственная кнопка «Отмена» с KeyShortcutName
-- «Escape» (FLXButtonBase). Окна модов нативно переведены в Modal (KRINIK MODIFIED, таблицы модулей Exiles Fishing и Hosav: хаб под окном
-- живёт), но такой кнопки у них нет: панель рыбалки глотает Esc и не закрывается (прогон 2026-10-29 23:5x). Добавить её в чужой блюпринт
-- наши приборы не умеют, поэтому Esc ловится здесь — событием клавиши, без опроса: окно модуля закрывается родным RootWidget.TryCloseWindow
-- (пультом 23:5x: панель закрылась, хаб на «Снаряжении», IsModuleActive сбросился). Класс окна — WidgetClass строки модуля в таблице мода.
-- Цена — только на нажатие Esc: до двух IsModuleActive и перебор экземпляров одного класса окна. Аргумент IsModuleActive — FName, не строка
-- (падение 16.09, выше). Экземпляров окна бывает несколько: игра создаёт окно заново при каждом открытии, а закрытое живёт до сборки мусора —
-- FindFirstOf вернул закрытое, и Esc при втором открытии панели не сработал (прогон 2026-10-30 00:08, два экземпляра, первый open=false).
-- [NOT-TESTED]
local MOD_WINDOWS = {
    { module = "ExilesFishingTuning", class = "W_EFT_Panel_C" },        -- Exiles Fishing, DT_Fishing_UIModule
    { module = "HosavUIsettings", class = "W_ExampleWidget_User_C" },   -- Hosav's Custom UI, UIModuleTable_UIH
    -- ours (KUMM plan 38, 2026-10-31 19:33): the row's CloseOnESC does not close a mod Modal window either — a real Esc left it open (case K8)
    { module = "KrinikModSettings", class = "W_KrinikModSettings_C" },  -- the «Моды Krinik'а» hub, DT_KrinikUIModule (section krinik_mod_settings)
}
local function close_mod_window_on_esc()
    local gmc = FindFirstOf("GUIModuleController")
    if not live(gmc) then return end
    for _, m in ipairs(MOD_WINDOWS) do
        if gmc:IsModuleActive(FName(m.module)) then
            for _, w in ipairs(FindAllOf(m.class) or {}) do
                if live(w) and w:IsOpen() then
                    w:TryCloseWindow()
                    log("Esc: окно %s закрыто, хаб под ним остаётся", m.module)
                    return
                end
            end
        end
    end
    -- 0.16.0: окна из списка «Настройки модов» (Xevyr, «Прочее»; krinik_mods_button.lua) — модуль закрывается сам, без класса окна
    if _G.__krinik_mods_menu_esc then _G.__krinik_mods_menu_esc() end
end
local esc_ok, esc_err = pcall(function()
    RegisterKeyBind(Key.ESCAPE, function()
        ExecuteInGameThread(function()
            local ok, e = pcall(close_mod_window_on_esc)
            if not ok then log("Esc: ошибка %s", tostring(e)) end
        end)
    end)
end)
log("Esc для окон модов: %s", esc_ok and "клавиша назначена" or ("НЕ назначена: " .. tostring(esc_err)))

-- 0.15.0 (2026-10-30, KUMM plan 36 W11): моды Криника — НАВЕРХУ списка модов в меню по Esc (Simple Modlist), остальные — в порядке загрузки.
-- `[OWNER]` «это только отображение, не ордер загрузки, наши моды вверху для красоты» · 2026-10-30 21:08 (интервью 027, вариант A).
-- Как устроено (пульт 23:4x): список строит `SML_UI_ModList_C` — `AppendModlist` дописывает строку в конец `modlistText`, затем текст ОДИН раз
-- кладётся в поле `ModListBox` (MultiLineEditableTextBox); переменная к полю не привязана — менять надо само поле. Наши паки в modlist.txt
-- последние нарочно (поздний перекрывает ранний), поэтому порядок загрузки не трогаем, переставляем только строки показа.
-- Вызов — по событию открытия `SML_ModList` (оно приходит вместе с ESC, см. ESC_MODULES), один раз, без опроса; повтор безвреден (Криник уже сверху).
local KRINIK_PREFIX = "^Krinik"
local MODLIST_DELAY_MS = 100   -- поле заполняется при рождении панели; 100 мс — запас на тот же кадр (прогон 23:4x: поле уже полное в момент события)
local function krinik_mods_on_top()
    local t0 = os.clock()
    for _, w in ipairs(FindAllOf("SML_UI_ModList_C") or {}) do
        if not w:GetFullName():find("Default__", 1, true) and live(w) then
            local box = w.ModListBox
            local text = box:GetText():ToString()
            if text:match(KRINIK_PREFIX) then return end
            local top, rest = {}, {}
            for line in text:gmatch("[^\n]+") do
                if line:match(KRINIK_PREFIX) then top[#top + 1] = line else rest[#rest + 1] = line end
            end
            if #top == 0 then return end
            for _, l in ipairs(rest) do top[#top + 1] = l end
            box:SetText(FText(table.concat(top, "\n")))
            log("список модов: Криник наверху (%d из %d строк), %.2f мс", #top - #rest, #top, (os.clock() - t0) * 1000)
            return
        end
    end
end

local hook_ok, hook_err = HOOK_MODULES and pcall(function()
    RegisterHook("/Script/ConanSandbox.GUIModuleController:ActivateModule", function(ctx, moduleName, activate)
        hook_calls = hook_calls + 1
        local ok, e = pcall(function()
            local name, on = moduleName:get():ToString(), activate:get()
            if on and (name == "SML_ModList" or name == "IngameMenu") then
                ExecuteInGameThreadWithDelay(MODLIST_DELAY_MS, function()
                    local ok2, e2 = pcall(krinik_mods_on_top)
                    if not ok2 then log("список модов: ошибка %s", tostring(e2)) end
                end)
            end
            on_activate(name, on)
        end)
        if not ok then log("перехват упал: %s", tostring(e)) end
    end)
end)
log("перехват GUIModuleController.ActivateModule %s", (not HOOK_MODULES) and "ВЫКЛЮЧЕН флагом" or (hook_ok and "встал" or ("НЕ встал: " .. tostring(hook_err))))
hook_carousel()   -- 0.8.0: родной класс загружен всегда — перехват ставится сразу
watch_character_display()   -- 0.9.0

-- Счёт через минуту и через пять — конечная цепочка, не цикл (EXP-0052).
ExecuteInGameThreadWithDelay(60000, function() log("СЧЁТ через 1 мин: вызовов ActivateModule %d", hook_calls) end)
ExecuteInGameThreadWithDelay(300000, function() log("СЧЁТ через 5 мин: вызовов ActivateModule %d", hook_calls) end)

log("загружен 0.16.0. Замедление, пока открыт полноэкранный интерфейс; меню с вкладками %.4f, ESC %.4f (баг 12: 0.0001 в меню убивало нажатия); в панели инвентаря только «Настройки модов», кнопка Hosav свёрнута; вставки EAA и EoT — по рождению портрета; пауза хаба — и по событию «Снаряжения»; Esc в окне мода закрывает только окно; рыбалка загорается при наведении; подсказки рыбалки без мерцания; ускорение крафта %s.", MENU_DILATION, ESC_DILATION, CRAFT_SPEEDUP and "ВКЛ" or "выкл")
