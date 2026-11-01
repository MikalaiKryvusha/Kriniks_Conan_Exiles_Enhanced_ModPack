--[[============================================================================
  KrinikConanModPackManager (2026-10-31: ConanModPackStatus → KrinikConanModPackStatus → merged with KrinikIntro) — лампочка «моды сборки загружены» в главном меню
  ============================================================================

  ЗАЧЕМ. Вечер 08.09.2026: UE4SS падал на старте, ни один Lua-мод не грузился, и
  узнать это можно было только по журналу — владелец же видел просто игру, в
  которой «ничего не работает», и жал клавиши в пустоту. Прибор отвечает на
  вопрос «моя сборка сейчас жива?» ДО того, как человек потратит на это вечер.

  ДВА ОТВЕТА В ОДНОМ:
    * сама надпись видна   = Lua-загрузчик UE4SS жив (в тот вечер её бы не было);
    * что в ней написано   = моды-паки сборки подхвачены игрой.

  ============ ЧЕМ ЭТА ВЕРСИЯ ОТЛИЧАЕТСЯ ОТ ПЕРВОЙ, УБИТОЙ ============
  Первая версия 08.09.2026 УРОНИЛА ИГРУ и была снята через минуту. Обе её
  половины оказались неверны, и обе переделаны:

  1. РАСПОЗНАВАНИЕ. Было: искать загруженные пакеты движка через
     FindAllOf("Package") и смотреть, есть ли в путях "Mods". Результат в живой
     игре — НОЛЬ пакетов, то есть способ не работал вовсе.
     Стало: читать то, что игра САМА ПИШЕТ О СЕБЕ — строки монтирования паков в
     ConanSandbox.log. Это обычное чтение файла: уронить игру им нельзя.

  2. ПОКАЗ. Было: создать свой TextBlock через StaticConstructObject и вставить
     его в холст меню через AddChild. Игра умерла ровно на этом шаге — журнал
     мода обрывается на строке перед рисованием, игровой журнал на той же
     миллисекунде. И важный урок: pcall тут не спасал — он ловит ошибки Lua, а
     не падение внутри движка.
     Стало: НИЧЕГО НЕ СОЗДАЁМ. Находим уже существующую надпись в меню и меняем
     ей текст. Один вызов на живом объекте вместо конструирования и
     перестроения чужого дерева виджетов.

  ⚠️ НАДПИСЬ НЕ УМЕЕТ СКАЗАТЬ «ЗАГРУЗЧИК УМЕР». Это говорит её отсутствие: она
  живёт на том же UE4SS. Внутри мода это не лечится — нечем.
============================================================================]]

local MOD_NAME = "KrinikConanModPackManager"

local SCRIPT_DIR = debug.getinfo(1, "S").source:match("@?(.*[/\\])") or "./"
local CONFIG_PATH = SCRIPT_DIR .. "../config.lua"

local defaults = {
    -- Пусто = вычислить от папки мода: .../ue4ss/Mods/<мод>/Scripts вверх до
    -- ConanSandbox, затем Mods/modlist.txt и Saved/Logs/ConanSandbox.log.
    modlist_path = "",
    gamelog_path = "",

    -- "probe" - только разведка метаданных (безопасно, умолчание)
    -- "show"  - показывать надпись; включать ПОСЛЕ чтения отчёта разведки
    -- "off"   - ничего не показывать, только журнал
    mode = "probe",

    -- Классы-кандидаты для разведки. Найдены оффлайн в индексе контейнеров
    -- игры (KUMM/researches/ue5-iostore-index), а не перебором в памяти.
    probe_classes = {
        "/Game/UI/Widgets/Modals/W_TimedMessageBox.W_TimedMessageBox_C",
        "/Game/UI/Widgets/MainMenu/W_PatchNotesEntryView.W_PatchNotesEntryView_C",
        "/Game/UI/Widgets/Modals/W_MessageBox.W_MessageBox_C",
        "/Game/UI/Widgets/Cinematics/WBP_CinematicOpeningText.WBP_CinematicOpeningText_C",
    },
    probe_at_check = 5,         -- на каком тике снимать отчёт (меню появляется не сразу)
    survey_loaded = true,       -- обзор классов, которые игра загрузила сама
    survey_limit = 60,          -- сколько классов с надписями выписать

    -- ЗОНД ИНТЕРФЕЙСА ОДНОГО МОДА (заказ владельца: увеличить ТОЛЬКО HUD Hosav).
    -- Ждёт, пока виджеты мода появятся в памяти, и снимает отчёт ОДИН раз.
    -- Ждать приходится потому, что HUD живёт в МИРЕ, а не в меню, а завести
    -- отдельную цепочку таймеров ради ожидания нельзя - см. правило "одна
    -- цепочка на весь мод" ниже по файлу (EXP-0052).
    -- Снимаются только МЕТАДАННЫЕ (имена классов и свойств) плюс значения
    -- полей, известных ПОИМЁННО, - граница из EXP-0050.
    probe_widget_prefix = "",   -- пусто = зонд выключен; напр. "UIMod_Hosav"
    probe_widget_report = "",   -- пусто = widget-report.txt рядом с модом

    -- Классы, которые надо расписать В МИРЕ, а не в меню: в меню их ещё нет,
    -- а грузить их запрещено (LoadAsset уронил игру - см. запрет ниже).
    -- Снимаются тем же одним заходом, что и зонд виджетов.
    probe_world_classes = {},

    -- ПОИСК ЖИВЫХ ЭКЗЕМПЛЯРОВ ПО КОРОТКОМУ ИМЕНИ КЛАССА (FindAllOf).
    -- Заведено 2026-09-10 под вопрос: ЧЕМ мод EAA цепляется к камере игрока.
    -- Почему не хватает probe_world_classes: тот отвечает "класс загружен или
    -- нет" и расписывает метаданные, но НЕ говорит, создан ли экземпляр и на
    -- ком он висит. Для глушения нужен живой объект: остановить тик можно у
    -- экземпляра, а не у класса. Разница уже стоила проекту вечера - "хук
    -- встал" не равно "хук работает" (EXP-0071), и так же "класс есть" не
    -- равно "компонент висит".
    -- Только чтение: FindAllOf ничего не грузит и не создаёт.
    probe_find_classes = {},

    -- ОТБОР ПО ИМЕНИ для классов с тысячами экземпляров. Без него зонд по
    -- NiagaraComponent напечатает первые восемь попавшихся - и ни одного
    -- нужного. Подсказки сравниваются с ПОЛНЫМ именем экземпляра, без учёта
    -- регистра; совпавшие печатаются ВСЕ, сверх обычной восьмёрки.
    probe_find_hints = {},

    -- УВЕЛИЧЕНИЕ ОДНОГО ВИДЖЕТА (заказ владельца: "ТОЛЬКО ВОТ ЭТОГО МОДА
    -- ВВЕРХУ HUD УВЕЛИЧИТЬ РАЗМЕР"). 0 = выключено.
    hud_scale = 0,
    hud_scale_class = "W_SmoothHP_C",
    -- Точка, вокруг которой растёт виджет, в долях его размера.
    -- 0.5;0 - верх по центру: HUD стоит вверху экрана, и расти ему надо ВНИЗ,
    -- иначе увеличенный край уедет за верхнюю кромку.
    hud_pivot_x = 0.5,
    hud_pivot_y = 0.0,

    -- ТОЛЬКО ТОЧКА ПРИВЯЗКИ, БЕЗ МАСШТАБА. Заказ владельца 10.09.2026: «панель
    -- быстрых инструментов... я сделал её мелкой - но она не внизу экрана
    -- осталась, а уехала вверх - словно и там точка привязки неверная, не снизу».
    -- Размер панели задаёт САМ мод Hosav своими настройками; мы в него не лезем.
    -- Чиним ровно то, что сломано: точку, вокруг которой виджет сжимается.
    -- При точке 0.5;0.5 (умолчание) уменьшение тянет края к центру, и нижняя
    -- кромка уходит вверх. При 0.5;1.0 низ прибит к месту, а сжимается верх.
    -- Тот же приём вылечил блок здоровья, только там точка была в углу.
    -- Список, а не одна строка: панель у Конана не одна (есть ещё ячейки).
    -- Формат: { class = "...", pivot_x = 0.5, pivot_y = 1.0, offset_y = 0 }
    -- offset_y - сдвиг ВНИЗ в единицах Slate; им и лечится "панель повисла
    -- выше низа". Число подбирается глазом владельца, не вычисляется.
    hud_pin = {},

    -- ПУСТАЯ РАМКА СПРАВА В ГЛАВНОМ МЕНЮ. Заказ владельца 2026-10-25 «вот это убрать»
    -- (Конан 3.0.1, снимок). Найдена делением пополам пультом KrinikAgentRemote:
    -- Image_SideBar_1 - белая черта и тёмная подложка, Border_1 - рамка с орнаментом;
    -- внутри пустой текст - лента новостей Funcom, которой без сервера нечего показать.
    -- Имена - элементы дерева W_MainMenu_MainMenu_C. Пустой список = выключено.
    hide_menu_elements = {},

    -- ⚠️ ДЕЙСТВИЕ над окном игры, не наблюдение. По умолчанию выключено.
    hide_offline_modal = false,
    hide_method = "remove",     -- "remove" (убрать из вьюпорта) | "collapse" (спрятать)
    hide_window_ms = 60000,     -- только первые секунды после старта
    probe_report = "",          -- пусто = probe-report.txt рядом с модом

    -- Заполняется ПО ОТЧЁТУ разведки, не догадкой.
    -- Класс выбран по признаку, стоившему крэша: у него НЕТ графа Construct.
    -- W_MessageBox_C его имел и уронил игру в момент создания (EXP-0060).
    class_path = "/Game/UI/Widgets/Map/WBP_MapText.WBP_MapText_C",
    text_field = "ButtonText",
    viewport_z = 1000,
    lamp_via_modal = false,     -- ЗАПРЕТ владельца: модалку про сеть только удалять
    lamp_at_check = 5,          -- (для отключённого показа своим окном)
    lamp_seconds = 6,           -- сколько держать на экране
    lamp_hide_buttons = true,   -- мёртвая кнопка хуже её отсутствия

    checks = 30,                -- сколько раз попробовать (меню появляется не сразу)
    check_interval_ms = 2000,
    logging_enabled = true,
}

local cfg = {}
for k, v in pairs(defaults) do cfg[k] = v end

local function log(fmt, ...)
    if not cfg.logging_enabled then return end
    print(("[%s] %s\n"):format(MOD_NAME, fmt:format(...)))
end

local function load_config()
    local f = io.open(CONFIG_PATH, "r")
    if not f then log("config.lua не найден, беру умолчания"); return end
    f:close()
    local ok, loaded = pcall(dofile, CONFIG_PATH)
    if ok and type(loaded) == "table" then
        for k, v in pairs(loaded) do
            if cfg[k] ~= nil then cfg[k] = v end
        end
        log("config.lua прочитан")
    else
        log("config.lua не разобран (%s), беру умолчания", tostring(loaded))
    end
end

-- ---------------------------------------------------------------- ЭТАЛОН
-- Тот же файл, что читает сама игра. Восемь паков; девятый мод сборки,
-- No-Intro-Splash, это подмена файлов игры, а не пак, и в списке его нет и быть
-- не должно.
local function read_modlist()
    local path = cfg.modlist_path
    if path == "" then path = SCRIPT_DIR .. "../../../../../../Mods/modlist.txt" end
    local f = io.open(path, "r")
    if not f then
        log("modlist.txt не открылся (%s) — эталона нет", path)
        return {}
    end
    local names = {}
    for line in f:lines() do
        local pak = line:match("([^/\\]+)%.pak%s*$")
        if pak then names[#names + 1] = pak end
    end
    f:close()
    return names
end

-- ------------------------------------------------------------------ ФАКТ
-- Игра сама печатает в свой журнал, какие паки смонтировала. Берём правду
-- оттуда, а не гадаем по движку. Файл может быть большим, поэтому читаем
-- построчно и держим только совпадения.
local function mounted_paks()
    local path = cfg.gamelog_path
    if path == "" then
        path = SCRIPT_DIR .. "../../../../../../Saved/Logs/ConanSandbox.log"
    end
    local f = io.open(path, "r")
    if not f then
        log("игровой журнал не открылся (%s)", path)
        return nil          -- nil = "не знаю", это НЕ то же самое, что "ноль"
    end
    local seen = {}
    for line in f:lines() do
        if line:find("Mount", 1, true) or line:find("Pak", 1, true) then
            local pak = line:match("([^/\\'\"]+)%.pak")
            if pak then seen[pak:lower()] = true end
        end
    end
    f:close()
    return seen
end

local function compare(expected, seen)
    local found, missing = {}, {}
    for _, name in ipairs(expected) do
        if seen[name:lower()] then
            found[#found + 1] = name
        else
            missing[#missing + 1] = name
        end
    end
    return found, missing
end

-- Словами то, что посчитано. Отдельно от показа: строка нужна и в журнале,
-- и на экране, а журнал работает всегда.
local function plate_text(found, missing, total, seen)
    if total == 0 then
        return "СБОРКА: список модов не прочитан"
    elseif seen == nil then
        return "СБОРКА: журнал игры не прочитан"
    elseif #missing == 0 then
        return ("СБОРКА: моды %d/%d"):format(#found, total)
    elseif #found == 0 then
        return ("СБОРКА: ни один из %d модов не загружен"):format(total)
    else
        return ("СБОРКА: моды %d/%d, нет: %s")
            :format(#found, total, table.concat(missing, ", "))
    end
end

-- ---------------------------------------------------------- ПОКАЗ: ДВЕ СТАДИИ
-- Переписано 09.09.2026. Прошлая половина показа искала чужую надпись в живой
-- памяти и переписывала ей текст. Она уронила игру ТРИЖДЫ и снята целиком;
-- разбор всех отказов и почему они объяснимы - docs/06-интерфейс-модов.md.
--
-- Новый маршрут опирается на оффлайн-разведку ассетов (KUMM/researches/
-- ue5-iostore-index): имена классов виджетов игры найдены НА ДИСКЕ, а не
-- перебором в памяти. Осталась одна неизвестная - что у этих классов внутри.
-- Поэтому работа разбита на две стадии, и по умолчанию включена безопасная:
--
--   mode = "probe" (умолчание) - РАЗВЕДКА. Ничего не создаём, ничего не
--       показываем, в чужие объекты не пишем. Только перечисляем МЕТАДАННЫЕ
--       класса: имена свойств с типами и имена функций. Перечисление имён
--       безопасно; перебор ЗНАЧЕНИЙ чужих свойств - нет, он уже ронял игру
--       08.09 (EXCEPTION_ACCESS_VIOLATION 0x7378), и здесь его нет.
--   mode = "show" - ПОКАЗ. Включать ТОЛЬКО после того, как отчёт разведки
--       прочитан и в config.lua вписаны class_path и text_field.
--   mode = "off" - считать и писать в журнал, на экран не лезть вовсе.
--
-- ⚠️ Ключевая поправка, без которой маршрут упрётся снова: третий крэш 08.09
-- был записью в <Класс>_C:WidgetTree.X, то есть в ШАБЛОН КЛАССА. У виджета,
-- который мы создали САМИ, дети его WidgetTree - живые объекты нашего
-- экземпляра, и SetText у них законен. Разница не в вызове, а в том, чьему
-- объекту он адресован.

local UEHelpers = nil
do
    local ok, mod = pcall(require, "UEHelpers")
    if ok then UEHelpers = mod end
end

-- Куда писать отчёт разведки. Отдельный файл, а не только журнал: журнал игры
-- длинный, а отчёт нужно читать глазами и потом переносить в config.lua.
local function report_path()
    if cfg.probe_report ~= "" then return cfg.probe_report end
    return SCRIPT_DIR .. "../probe-report.txt"
end

-- ⛔️ LoadAsset ЗАПРЕЩЁН В ЭТОМ МОДЕ. Убран 09.09.2026 после ЧЕТВЁРТОГО крэша.
-- История: разведка 01:13:41 позвала LoadAsset для двух незагруженных классов,
-- оба раза он отказал, а в 01:14:08 игра оборвалась через AbortHandler
-- (ucrtbase abort, "Abort signal received"). Улика: строка про TPM в журнале
-- игры встречается и в трёх старых журналах, а AbortHandler - ТОЛЬКО в этом
-- запуске, и единственным новым в нём был LoadAsset. Отсрочка в 27 секунд
-- объяснима: неудачная синхронная загрузка оставляет битый пакет, а спотыкается
-- об него уже сборщик мусора или следующая потоковая загрузка.
--
-- И более общий вывод, который стоил этого запуска: СИНХРОННАЯ ЗАГРУЗКА АССЕТА
-- НЕ ЕСТЬ "ЧТЕНИЕ МЕТАДАННЫХ". Разведка обязана быть чистым наблюдением: она
-- смотрит на то, что игра загрузила САМА, и не заставляет её грузить ничего.
-- Незагруженный класс - это не проблема, а ответ: значит он в этом контексте
-- не используется, и лампочке он не годится.
local function find_class(object_path)
    local cls = StaticFindObject(object_path)
    if cls and cls:IsValid() then return cls, "загружен игрой" end
    return nil, "не загружен в этом контексте (грузить не пробуем - см. запрет выше)"
end

-- ⚠️ ТОЛЬКО ИМЕНА И ТИПЫ. Значения свойств здесь не читаются намеренно.
-- Имена дочерних виджетов UMG попадают в свойства класса (ObjectProperty), то
-- есть именно этот список и отвечает на вопрос "какому полю ставить текст".
local function describe_class(cls, out)
    local props, funcs = {}, {}
    -- ⚠️ Пустой список и НЕСРАБОТАВШЕЕ перечисление выглядят одинаково. Ошибку
    -- pcall пишем в отчёт, иначе отчёт соврёт молчанием (класс отказов, за
    -- который проект уже платил: EXP-0045).
    local ok_p, err_p = pcall(function()
        cls:ForEachProperty(function(prop)
            local ok, line = pcall(function()
                return ("%s : %s"):format(prop:GetFName():ToString(),
                                          prop:GetClass():GetFName():ToString())
            end)
            props[#props + 1] = ok and line or "<имя не прочиталось>"
        end)
    end)
    local ok_f, err_f = pcall(function()
        cls:ForEachFunction(function(fn)
            local ok, name = pcall(function() return fn:GetFName():ToString() end)
            funcs[#funcs + 1] = ok and name or "<имя не прочиталось>"
        end)
    end)
    table.sort(props); table.sort(funcs)
    if not ok_p then out[#out + 1] = "  ⚠ перечисление свойств отказало: " .. tostring(err_p) end
    if not ok_f then out[#out + 1] = "  ⚠ перечисление функций отказало: " .. tostring(err_f) end
    out[#out + 1] = ("  свойств %d, функций %d"):format(#props, #funcs)
    out[#out + 1] = "  --- свойства (имя : тип) ---"
    for _, l in ipairs(props) do out[#out + 1] = "    " .. l end
    out[#out + 1] = "  --- функции ---"
    for _, l in ipairs(funcs) do out[#out + 1] = "    " .. l end
end

-- ОБЗОР ТОГО, ЧТО ИГРА ЗАГРУЗИЛА САМА.
-- Список кандидатов выше составлен по каталогу с диска, и он угадывает, что
-- окажется в памяти в главном меню. Этот обзор не угадывает: он спрашивает у
-- игры, какие виджет-классы у неё СЕЙЧАС загружены, и у каких из них есть поле,
-- похожее на надпись. Только имена - ни загрузки, ни создания, ни чтения значений.
local TEXTISH = { "^T_", "^Txt", "Text", "Label", "Message", "Title", "Caption" }

local function looks_textish(name)
    for _, pat in ipairs(TEXTISH) do
        if name:find(pat) then return true end
    end
    return false
end

-- ⚠️ Первая попытка спрашивала FindAllOf("WidgetBlueprintGeneratedClass") и
-- получила пусто (отчёт 01:18:13): UE4SS перечисляет ЭКЗЕМПЛЯРЫ, а классы
-- экземплярами не являются. Спрашиваем то, что перечисляется, - живые виджеты
-- меню, - а класс берём у каждого из них. Заодно это честнее: так в списке
-- окажется ровно то, что игра прямо сейчас держит на экране.
local function survey_loaded(out)
    local widgets = nil
    local ok, err = pcall(function() widgets = FindAllOf("UserWidget") end)
    if not ok or not widgets then
        out[#out + 1] = "ОБЗОР: живые виджеты не перечислились: " .. tostring(err)
        return
    end
    out[#out + 1] = ("ОБЗОР: живых виджетов в памяти %d."):format(#widgets)
    out[#out + 1] = "Ниже - их классы, у которых есть поле, похожее на надпись."
    out[#out + 1] = ""
    local seen, listed = {}, 0
    for _, w in ipairs(widgets) do
        if listed >= cfg.survey_limit then break end
        local cname, fields = nil, {}
        pcall(function() cname = w:GetClass():GetFullName() end)
        if cname and not seen[cname] then
            seen[cname] = true
            pcall(function()
                w:GetClass():ForEachProperty(function(prop)
                    local n = prop:GetFName():ToString()
                    if looks_textish(n) then
                        fields[#fields + 1] =
                            ("%s : %s"):format(n, prop:GetClass():GetFName():ToString())
                    end
                end)
            end)
            if #fields > 0 then
                listed = listed + 1
                out[#out + 1] = "-- " .. cname
                for _, f in ipairs(fields) do out[#out + 1] = "     " .. f end
            end
        end
    end
    out[#out + 1] = ("(классов с надписями: %d, предел %d)"):format(listed, cfg.survey_limit)
    out[#out + 1] = ""
end

-- ЖИВЫЕ ОКНА СООБЩЕНИЙ И ИХ ТЕКСТ.
-- Заказ владельца 09.09.2026: не показывать модалку "нет сетевого подключения"
-- при запуске (игра только локальная). Чтобы гасить именно её, а не любое окно,
-- надо знать её текст. Это чтение значения свойства, ИЗВЕСТНОГО ПО ИМЕНИ
-- (T_Message из отчёта разведки), - ровно тот случай, который правилами
-- разрешён; запрещён слепой перебор ЗНАЧЕНИЙ всех свойств подряд.
local function read_text(node)
    local t
    if pcall(function() t = node.Text:ToString() end) and t and t ~= "" then return t end
    t = nil
    if pcall(function() t = node:GetText():ToString() end) and t and t ~= "" then return t end
    return nil
end

local function survey_messageboxes(out)
    local widgets = nil
    local ok = pcall(function() widgets = FindAllOf("UserWidget") end)
    if not ok or not widgets then return end
    out[#out + 1] = "--- живые окна сообщений (класс, текст поля T_Message) ---"
    local n = 0
    for _, w in ipairs(widgets) do
        local cname = nil
        pcall(function() cname = w:GetClass():GetFName():ToString() end)
        if cname and cname:find("MessageBox") then
            n = n + 1
            local full, txt = "?", nil
            pcall(function() full = w:GetFullName() end)
            pcall(function()
                local node = w.T_Message
                if node and node:IsValid() then txt = read_text(node) end
            end)
            out[#out + 1] = ("-- %s"):format(full)
            out[#out + 1] = ("     T_Message = %s"):format(txt or "<текст не прочитался>")
        end
    end
    if n == 0 then out[#out + 1] = "(ни одного живого окна сообщений сейчас нет)" end
    out[#out + 1] = ""
end

-- ------------------------------------------ ЗОНД ИНТЕРФЕЙСА ОДНОГО МОДА
--
-- ЗАЧЕМ. Заказ владельца 09.09.2026: «ТОЛЬКО ВОТ ЭТОГО МОДА ВВЕРХУ HUD
-- УВЕЛИЧИТЬ РАЗМЕР» (Hosav's Custom UI). Множитель Slate ApplicationScale не
-- годится - он тянет ВЕСЬ интерфейс, и на 1.25 у владельца вкладки вылезли за
-- экран. Значит масштабировать надо ЕГО виджет и только его, а для этого нужно
-- знать имя класса и имя поля масштаба.
--
-- ПОЧЕМУ НЕ ОФЛАЙН. Каталог ассетов мода снят с диска без запуска игры
-- (KUMM/researches/ue5-iostore-index - 204 файла, среди них W_NewHealthUI,
-- W_SmoothHP, WindowRoot_Health). Но офлайн даёт ИМЕНА, а не устройство:
-- содержимое сжато Oodle, отдельной библиотеки в поставке игры нет. Какой из
-- виджетов сидит вверху экрана и какое у него поле масштаба - это вопрос о
-- живой игре, и отвечает на него только живая игра.
--
-- ГРАНИЦА БЕЗОПАСНОСТИ (EXP-0050, EXP-0059). Перечисляются МЕТАДАННЫЕ - имена
-- классов, свойств, функций. Значения читаются только у полей, известных
-- ПОИМЁННО (RenderTransform у UWidget). Слепого перебора значений здесь нет:
-- он уронил игру 08.09, и pcall от падения внутри движка не защищает.
local widget_probe_done = false

local function widget_report_path()
    if cfg.probe_widget_report ~= "" then return cfg.probe_widget_report end
    return SCRIPT_DIR .. "../widget-report.txt"
end

-- Масштаб виджета лежит в FWidgetTransform.Scale. Это чтение поля, известного
-- по имени, - разрешённая половина. ⚠️ Отказ чтения структуры выглядит как
-- отсутствие значения (EXP-0045), поэтому неудачу пишем словами, а не пустотой.
local function read_render_scale(w)
    local sx, sy
    local ok = pcall(function()
        local t = w.RenderTransform
        sx, sy = t.Scale.X, t.Scale.Y
    end)
    if ok and sx then return ("%.3f x %.3f"):format(sx, sy) end
    return "<не прочиталось>"
end

-- Возвращает true, если отчёт снят (значит зонд больше не нужен).
local function survey_widgets_of_mod(prefix, out)
    local widgets = nil
    local ok, err = pcall(function() widgets = FindAllOf("UserWidget") end)
    if not ok or not widgets then
        log("зонд интерфейса: живые виджеты не перечислились: %s", tostring(err))
        return false
    end

    -- Сперва ищем, есть ли вообще чьи-то виджеты с этим префиксом. Их нет в
    -- меню и они появляются только в мире - это и есть наш признак "мир загружен".
    --
    -- ⚠️ ОТБИРАЕМ ПО КЛАССУ, А НЕ ПО ПУТИ ОБЪЕКТА. Первая редакция сверяла
    -- префикс с GetFullName() экземпляра и 09.09.2026 в 22:58 привела 14 штук,
    -- из которых ЖИВЫХ на экране не было НИ ОДНОГО: путь объекта совпадает с
    -- префиксом только у ШАБЛОНОВ внутри пакета мода
    -- (.../W_NewHealthUI.W_NewHealthUI_C:WidgetTree.W_SmoothHP), а живой
    -- экземпляр лежит в другом пакете, и его родство с модом видно ТОЛЬКО по
    -- классу. Отчёт при этом выглядел полным и правдоподобным - тот же класс
    -- отказов, что EXP-0058: неполный результат неотличим от полного.
    -- Путь объекта всё равно печатаем: по нему видно, шаблон это или живой.
    local mine = {}
    for _, w in ipairs(widgets) do
        local full, cls_name = nil, nil
        pcall(function() full = w:GetFullName() end)
        pcall(function() cls_name = w:GetClass():GetFullName() end)
        local hit = (cls_name and cls_name:find(prefix, 1, true))
                    or (full and full:find(prefix, 1, true))
        if hit then mine[#mine + 1] = { w = w, full = full or "<имя не прочиталось>" } end
    end
    if #mine == 0 then return false end          -- ещё не в мире: ждём следующий тик

    local stamp = "время неизвестно"
    pcall(function() stamp = os.date("%Y-%m-%d %H:%M:%S") end)
    out[#out + 1] = ("Отчёт зонда интерфейса, префикс «%s», %s"):format(prefix, stamp)
    out[#out + 1] = "Ничего не создавалось и не менялось: метаданные плюс поимённые поля."
    out[#out + 1] = ("Живых виджетов в памяти %d, из них с этим префиксом %d.")
        :format(#widgets, #mine)
    out[#out + 1] = ""
    out[#out + 1] = "--- живые экземпляры (полное имя · масштаб RenderTransform) ---"
    local classes, order = {}, {}
    for _, it in ipairs(mine) do
        out[#out + 1] = ("-- %s"):format(it.full)
        out[#out + 1] = ("     RenderTransform.Scale = %s"):format(read_render_scale(it.w))
        local cls, cname = nil, nil
        pcall(function() cls = it.w:GetClass(); cname = cls:GetFullName() end)
        if cname and not classes[cname] then
            classes[cname] = cls
            order[#order + 1] = cname
        end
    end
    out[#out + 1] = ""
    out[#out + 1] = ("--- устройство их классов (различных: %d) ---"):format(#order)
    table.sort(order)
    for _, cname in ipairs(order) do
        out[#out + 1] = ("== %s"):format(cname)
        if classes[cname] then describe_class(classes[cname], out) end
        out[#out + 1] = ""
    end
    return true
end

-- ЖИВЫЕ ЭКЗЕМПЛЯРЫ ПО КОРОТКОМУ ИМЕНИ КЛАССА.
-- Отвечает на вопрос, на который метаданные класса не отвечают: СОЗДАН ли
-- объект и на ком он висит. Возвращает true, если нашёлся хоть один — по
-- этому признаку зонд решает, снят отчёт или надо подождать мир.
local function find_live_instances(names, out)
    local found_any = false
    local any_hit = false      -- объявлено ВЫШЕ использования: в Lua имя,
                               -- объявленное ниже, равно nil (EXP-0072)
    for _, cname in ipairs(names) do
        local list
        local ok, err = pcall(function() list = FindAllOf(cname) end)
        local n = 0
        if ok and list then n = #list end
        if n > 0 then found_any = true end   -- считаем, но решает any_hit
        -- ⚠️ ОТКАЗ И ПУСТОТА ПИШУТСЯ ПО-РАЗНОМУ. Молчаливый pcall уже врал
        -- отчётом в этом моде (EXP-0045): "ничего не нашлось" и "перечисление
        -- отказало" — разные факты, и различать их обязан отчёт, а не читатель.
        out[#out + 1] = ("== FindAllOf(%s) -> %s"):format(
            cname, ok and ("экземпляров " .. n) or ("ОТКАЗ: " .. tostring(err)))
        log("поиск экземпляров %s -> %s", cname, ok and tostring(n) or "отказ")
        if ok and list then
            local hints = cfg.probe_find_hints or {}
            local shown, matched = 0, 0
            for i, o in ipairs(list) do
                local full
                pcall(function() full = o:GetFullName() end)
                full = tostring(full)

                -- Совпавшее с подсказкой печатаем ВСЕГДА, даже если восьмёрка
                -- уже исчерпана: ради него зонд и заведён.
                local hit = false
                for _, h in ipairs(hints) do
                    if full:lower():find(h:lower(), 1, true) then hit = true break end
                end

                if hit then
                    matched = matched + 1
                    out[#out + 1] = "  ★ " .. full
                    if matched == 1 then
                        local c
                        pcall(function() c = o:GetClass() end)
                        if c then describe_class(c, out) end
                    end
                elseif shown < 8 then
                    shown = shown + 1
                    out[#out + 1] = "    " .. full
                    if shown == 1 and #hints == 0 then
                        local c
                        pcall(function() c = o:GetClass() end)
                        if c then describe_class(c, out) end
                    end
                end
            end
            if n > shown + matched then
                out[#out + 1] = ("    ... ещё %d не показано"):format(n - shown - matched)
            end
            if #hints > 0 then
                -- Ноль совпавших - ЗНАЧИМЫЙ ответ, а не пустота: значит
                -- искомого в мире сейчас нет (дождя нет, эффект не создан).
                out[#out + 1] = ("    по подсказкам совпало: %d"):format(matched)
                -- ⚠️ И ЭТО ЖЕ РЕШАЕТ, СНЯТ ЛИ ОТЧЁТ. Без этой строки зонд
                -- считал бы себя закончившим, едва найдя ЛЮБОЙ экземпляр -
                -- а NiagaraComponent'ов в мире тысячи с первой секунды. Отчёт
                -- снялся бы в первую минуту, без дождя, и зонд замолчал бы
                -- навсегда. Ждём именно того, ради чего заведён.
                if matched > 0 then any_hit = true end
            elseif n > 0 then
                any_hit = true
            end
        end
        out[#out + 1] = ""
    end
    -- При заданных подсказках отчёт готов только когда совпало по ним.
    return any_hit
end

local function widget_probe()
    if widget_probe_done then return end
    local want_widgets = cfg.probe_widget_prefix ~= ""
    local find_list = cfg.probe_find_classes or {}
    if not want_widgets and #find_list == 0 then return end
    local out = {}
    if want_widgets then
        if not survey_widgets_of_mod(cfg.probe_widget_prefix, out) then return end
    end

    -- ⚠️ ПУСТОЙ РЕЗУЛЬТАТ - НЕ ОТВЕТ, А "ПРИШЛИ РАНО". Мир грузится десятки
    -- секунд, и отчёт, снятый до появления персонажа, скажет "экземпляров 0"
    -- и замолчит навсегда. Поэтому при нулевом улове отчёт НЕ снимаем и
    -- пробуем на следующем опросе; попытки видны в журнале, так что "рано" и
    -- "их правда нет" различимы. Число попыток ограничено сверху cfg.checks.
    local found_any = true
    if #find_list > 0 then
        found_any = find_live_instances(find_list, out)
        if not found_any then return end
    end
    widget_probe_done = true

    -- ⚠️ КЛАССЫ МИРА - ТЕМ ЖЕ ЗАХОДОМ. Заведено 09.09.2026 под конкретный
    -- вопрос: ГДЕ у игры считается зум камеры. В exe этих имён нет
    -- (`NewTargetArmLength`, `CameraZoomAmount`, `ThirdPersonCameraMaxArmLength`
    -- не встречаются ни разу) - значит зум живёт в блюпринте персонажа, а не в
    -- коде игры. Имя функции блюпринта с диска не достать (содержимое сжато
    -- Oodle), но в живой игре оно есть в метаданных класса.
    -- Это нужно, чтобы поставить предел ОДНИМ перехватом в месте, где число
    -- рождается, вместо гонки за игрой по таймеру. Слово владельца о том, как
    -- правильно: «логика должна быть, а не ловить что-то по кадрам».
    for _, path in ipairs(cfg.probe_world_classes or {}) do
        local cls, how = find_class(path)
        out[#out + 1] = ("== %s -> %s"):format(path, how)
        log("разведка мира: %s -> %s", path:sub(-55), how)
        if cls then describe_class(cls, out) end
        out[#out + 1] = ""
    end
    local f = io.open(widget_report_path(), "w")
    if f then
        f:write(table.concat(out, "\n"))
        f:close()
        log("отчёт зонда интерфейса записан: %s", widget_report_path())
    else
        log("отчёт зонда интерфейса записать не удалось, всё ниже - в этом журнале")
        for _, l in ipairs(out) do log("%s", l) end
    end
end

-- ------------------------------------ УВЕЛИЧЕНИЕ ОДНОГО ВИДЖЕТА (HUD Hosav)
--
-- ЗАКАЗ ВЛАДЕЛЬЦА, дословно: «умоляю тебя! Найди способ UI вернуть в тот
-- размер, что был. И ТОЛЬКО ВОТ ЭТОГО МОДА ВВЕРХУ HUD УВЕЛИЧИТЬ РАЗМЕР».
--
-- ПОЧЕМУ НЕ ApplicationScale. Это множитель ВСЕГО Slate: на 1.25 у владельца
-- вкладки Спутники/Карта вылезли за экран. Он остаётся отдельной, независимой
-- настройкой (владелец заказал её тоже, +10%) - но заказ про HUD им не
-- закрывается, о чём владелец сказал прямо.
--
-- ПОЧЕМУ НЕ НАСТРОЙКАМИ САМОГО МОДА. У Hosav размерных настроек ровно две -
-- Hotbar Size и Detail Font Size, обе Small/Medium/Large, и у владельца уже
-- Large. Это потолок предусмотренного автором.
--
-- ПОЧЕМУ ЭТО НЕ ОПЫТ, А ИЗВЕСТНЫЙ ПУТЬ. Масштаб виджета в этой игре работает,
-- и доказательство не наше: сам Hosav держит свой W_EnemyBuffList на
-- RenderTransform.Scale = 0.600 (замер зонда 09.09.2026 22:58). Мы делаем то
-- же самое, тем же полем, только числом больше.
--
-- ЧТО ИМЕННО УВЕЛИЧИВАЕТСЯ. W_SmoothHP_C - тот самый блок вверху экрана:
-- здоровье, стамина, еда, вода, порча, температура, опыт, броня, вес, компас,
-- пинг сервера (133 свойства, 75 функций - отчёт зонда). Живёт внутри
-- контейнера W_NewHealthUI_C. Ничего другого не трогаем.
--
-- ГРАНИЦА БЕЗОПАСНОСТИ. Виджет НЕ создаётся - создание роняло игру пять раз из
-- пяти (EXP-0060, EXP-0061). Здесь только вызов штатной функции UWidget на
-- УЖЕ СУЩЕСТВУЮЩЕМ объекте игры - тот же класс действия, которым мод уже
-- проверенно гасит модалку про сеть.
-- Печатает ВСЕГДА, мимо logging_enabled - как одноимённая функция в моде
-- камеры. ⚠️ Её отсутствие здесь стоило рабочей правки: 09.09.2026 23:43
-- масштаб HUD применялся верно и тут же падал на строке отчёта
-- («attempt to call a nil value (global 'say')»), pcall это глотал, и заказ
-- выглядел наполовину сделанным. Урок общий: перенося кусок из соседнего
-- мода, перенеси и то, на что он опирается.
local function say(fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, fmt:format(...)))
end

local hud_reported = false

local function scale_one_widget(w, s)
    -- Сперва штатная функция UWidget: она сама разбирается со структурой.
    -- ⚠️ Структурное свойство UE4SS отдаёт КОПИЕЙ, и правка полей копии в
    -- объект не попадает - за этот урок уже платил мод камеры. Поэтому
    -- запасной путь пишет структуру ЦЕЛИКОМ, а не по полям.
    if pcall(function() w:SetRenderScale({ X = s, Y = s }) end) then return true end
    local ok = pcall(function()
        w.RenderTransform = {
            Translation = { X = 0.0, Y = 0.0 },
            Scale       = { X = s,   Y = s   },
            Shear       = { X = 0.0, Y = 0.0 },
            Angle       = 0.0,
        }
    end)
    return ok
end

-- ПРИБИТЬ ВИДЖЕТ ЗА КРОМКУ: меняем ТОЛЬКО точку привязки, размер не трогаем.
-- ⚠️ Почему это безопаснее масштабирования: мы ничего не создаём и не считаем
-- за чужой мод - лишь говорим движку, вокруг какой точки применять ту
-- трансформацию, которую задал кто-то другой. Виджет не пересоздаётся.
local pin_reported = {}

local function apply_hud_pin()
    local list = cfg.hud_pin
    if type(list) ~= "table" or #list == 0 then return end

    local widgets = nil
    if not pcall(function() widgets = FindAllOf("UserWidget") end) or not widgets then return end

    for _, rule in ipairs(list) do
        local want = rule.class
        if type(want) == "string" and want ~= "" then
            local px = rule.pivot_x or 0.5
            local py = rule.pivot_y or 1.0
            local touched, seen = 0, 0
            for _, w in ipairs(widgets) do
                local cname = nil
                pcall(function() cname = w:GetClass():GetFName():ToString() end)
                if cname == want and w:IsValid() then
                    -- Шаблоны внутри пакетов на экране не живут - их не трогаем.
                    local full = nil
                    pcall(function() full = w:GetFullName() end)
                    if not (full and full:find("/Game/Mods/", 1, true)) then
                        seen = seen + 1
                        -- ЧТЕНИЕ ДО ЗАПИСИ. Иначе это правка каждые две секунды
                        -- на ровном месте; здесь же в покое - чистое чтение.
                        local cur_x, cur_y
                        pcall(function()
                            local pv = w.RenderTransformPivot
                            cur_x, cur_y = pv.X, pv.Y
                        end)
                        if not cur_x or math.abs(cur_x - px) > 0.001
                           or not cur_y or math.abs(cur_y - py) > 0.001 then
                            local ok = pcall(function()
                                w:SetRenderTransformPivot({ X = px, Y = py })
                            end)
                            if ok then touched = touched + 1 end
                        end

                        -- СДВИГ. Точка привязки говорит, ВОКРУГ ЧЕГО сжимать, и
                        -- не двигает виджет. Замер 10.09.2026: панель после
                        -- уменьшения повисла на ~85% высоты экрана вместо почти
                        -- самого низа - её выталкивает РАСКЛАДКА (внешнее гнездо
                        -- прежнего размера, уменьшенная полоска встала по его
                        -- центру). Лечится смещением, а не точкой.
                        --
                        -- ⚠️ ЧИТАЕМ ВЕСЬ ПРЕОБРАЗОВАТЕЛЬ И ПИШЕМ ЕГО ЦЕЛИКОМ.
                        -- UE4SS отдаёт структурное свойство КОПИЕЙ: правка
                        -- отдельного поля в объект не попадает, и ошибки при
                        -- этом нет (этот класс отказов мод уже проходил с
                        -- SocketOffset). Масштаб при этом чужой - его ставит
                        -- сам Hosav, и затирать его нельзя.
                        local dy = rule.offset_y
                        if type(dy) == "number" and dy ~= 0 then
                            local sx, sy, ang, shx, shy, tx, ty
                            local got = pcall(function()
                                local rt = w.RenderTransform
                                sx, sy = rt.Scale.X, rt.Scale.Y
                                ang = rt.Angle
                                shx, shy = rt.Shear.X, rt.Shear.Y
                                tx, ty = rt.Translation.X, rt.Translation.Y
                            end)
                            if got and ty and math.abs(ty - dy) > 0.5 then
                                pcall(function()
                                    w:SetRenderTransform({
                                        Scale = { X = sx or 1.0, Y = sy or 1.0 },
                                        Shear = { X = shx or 0.0, Y = shy or 0.0 },
                                        Angle = ang or 0.0,
                                        Translation = { X = tx or 0.0, Y = dy },
                                    })
                                end)
                                touched = touched + 1
                            end
                        end
                    end
                end
            end
            if touched > 0 or (seen > 0 and not pin_reported[want]) then
                pin_reported[want] = true
                say("привязка %s: живых %d, поправлено %d (точка %.2f;%.2f, сдвиг %s)",
                    want, seen, touched, px, py, tostring(rule.offset_y or 0))
            end
        end
    end
end

local function apply_hud_scale()
    local s = cfg.hud_scale
    if type(s) ~= "number" or s <= 0 then return end
    local want_class = cfg.hud_scale_class
    if type(want_class) ~= "string" or want_class == "" then return end

    -- Поиск сразу по классу (2 мс), а не перебор всех UserWidget с чтением класса у каждого: 1928 виджетов
    -- с именами стоили 26 мс за проход, а проход шёл раз в две секунды всю сессию (фриз — у tick ниже). [NOT-TESTED]
    local widgets = nil
    if not pcall(function() widgets = FindAllOf(want_class) end) or not widgets then return end

    local touched, seen_live = 0, 0
    for _, w in ipairs(widgets) do
        if w:IsValid() then
            -- Шаблоны внутри пакета мода трогать незачем: на экране они не
            -- живут. Признак живого - объект лежит НЕ в пакете мода.
            local full = nil
            pcall(function() full = w:GetFullName() end)
            local is_template = full and full:find("/Game/Mods/", 1, true) ~= nil
            if not is_template then
                seen_live = seen_live + 1
                -- ЧТЕНИЕ ДО ЗАПИСИ: пишем только при расхождении, иначе это
                -- была бы правка каждые две секунды на ровном месте.
                local cur = nil
                pcall(function() cur = w.RenderTransform.Scale.X end)
                if not cur or math.abs(cur - s) > 0.001 then
                    pcall(function()
                        w:SetRenderTransformPivot({ X = cfg.hud_pivot_x, Y = cfg.hud_pivot_y })
                    end)
                    if scale_one_widget(w, s) then touched = touched + 1 end
                end
            end
        end
    end

    if touched > 0 or (seen_live > 0 and not hud_reported) then
        hud_reported = true
        say("HUD %s: живых на экране %d, масштаб выставлен на %d (x%.2f)",
            want_class, seen_live, touched, s)
    end
end

local probe_done = false

local function probe()
    if probe_done then return end
    probe_done = true
    local out = {}
    local stamp = "время неизвестно"
    pcall(function() stamp = os.date("%Y-%m-%d %H:%M:%S") end)
    out[#out + 1] = "Отчёт разведки KrinikConanModPackManager, " .. stamp
    out[#out + 1] = "Ничего не создавалось и не менялось: перечислены только метаданные."
    out[#out + 1] = ""
    if cfg.survey_loaded then survey_loaded(out) end
    if cfg.survey_loaded then survey_messageboxes(out) end
    out[#out + 1] = "--- поимённые кандидаты из каталога на диске ---"
    out[#out + 1] = ""
    for _, path in ipairs(cfg.probe_classes) do
        local cls, how = find_class(path)
        out[#out + 1] = ("== %s -> %s"):format(path, how)
        log("разведка: %s -> %s", path:sub(-55), how)
        if cls then describe_class(cls, out) end
        out[#out + 1] = ""
    end
    local f = io.open(report_path(), "w")
    if f then
        f:write(table.concat(out, "\n"))
        f:close()
        log("отчёт разведки записан: %s", report_path())
    else
        log("отчёт разведки записать не удалось, всё ниже - в этом журнале")
        for _, l in ipairs(out) do log("%s", l) end
    end
end

-- ------------------------------------------- ЗАКАЗ: ГАСИТЬ МОДАЛКУ "БЕЗ СЕТИ"
-- Заказ владельца 09.09.2026: игра только локальная, и окно "Играть без
-- подключения" при каждом запуске лишнее.
--
-- ПРИЧИНА НЕУСТРАНИМА, И ЭТО ПРОВЕРЕНО, А НЕ ПРЕДПОЛОЖЕНО: домен сервисов
-- (services.live.exiles.wintercloud.net) ведёт на ghs.googlehosted.com и
-- отвечает отказом в соединении. В hosts блокировок нет. То есть сервисы Funcom
-- для этой сборки недоступны снаружи, и гашение окна не прячет чинимую поломку.
--
-- ОПОЗНАНИЕ - ПО ЖУРНАЛУ ИГРЫ, А НЕ ПО ТЕКСТУ ОКНА. Прочитать T_Message не
-- удалось (отчёт разведки 01:23:16: "<текст не прочитался>") - та же болезнь,
-- что и у прошлой попытки читать чужие надписи. Зато игра сама печатает
-- "Requested Message FlsOfflineMode", и журнал мод уже читает ради счёта модов.
-- Опознание по имени сообщения от самой игры точнее любого совпадения строк.
--
-- ⚠️ ЭТО ДЕЙСТВИЕ НАД ИМУЩЕСТВОМ ИГРЫ, А НЕ НАБЛЮДЕНИЕ. Поэтому по умолчанию
-- ВЫКЛЮЧЕНО, срабатывает один раз за сессию и только в первые секунды. Урок,
-- которым оплачено это разделение, - EXP-0059.
-- Объявлено ЗДЕСЬ, выше гасителя модалки, намеренно: наша собственная лампа -
-- тоже W_MessageBox_C, и гаситель обязан её пропускать, иначе мод потушит сам
-- себя. Локальное имя, объявленное НИЖЕ места использования, попало бы в
-- замыкание как nil - класс, за который в этом же моде уже платили.
local lamp = nil
local lamp_born_ms = nil

local function last_requested_message()
    local path = cfg.gamelog_path
    if path == "" then
        path = SCRIPT_DIR .. "../../../../../../Saved/Logs/ConanSandbox.log"
    end
    local f = io.open(path, "r")
    if not f then return nil end
    local last = nil
    for line in f:lines() do
        local m = line:match("Requested Message (%w+)")
        if m then last = m end
    end
    f:close()
    return last
end

-- ⚠️ ВСЕ экземпляры, а не первый попавшийся. 01:34:00 мод доложил, что окно
-- убрано, а на экране владельца оно осталось: окон этого класса у игры может
-- быть несколько (одно показано, другое лежит в запасе), и мы сняли не то.
local function find_live_messageboxes()
    local widgets, out = nil, {}
    local ok = pcall(function() widgets = FindAllOf("UserWidget") end)
    if not ok or not widgets then return out end
    for _, w in ipairs(widgets) do
        local cname = nil
        pcall(function() cname = w:GetClass():GetFName():ToString() end)
        if cname == "W_MessageBox_C" and w:IsValid() and w ~= lamp then
            out[#out + 1] = w                    -- своя лампа сюда не попадает
        end
    end
    return out
end

local offline_modal_handled = false
local offline_modal_reported = false

-- ⚠️ Прошедшее время приходит ПАРАМЕТРОМ, а не берётся из checks.
-- 09.09.2026 здесь стояло `checks`, объявленное НИЖЕ по файлу: в замыкание оно
-- попало как nil, арифметика упала, pcall проглотил ошибку - и заказ молча не
-- работал, не оставив в журнале ни строчки. Это известный класс (docs/06):
-- локальное имя, объявленное ниже места использования, равно nil.
-- ⚠️ РАБОТАЕМ ВСЮ ПЕРВУЮ МИНУТУ, А НЕ ОДИН РАЗ. Однократное срабатывание
-- считало успехом сам факт вызова, а не исчезновение окна с экрана. Игра
-- показывает окно позже нашего первого тика и может показать его снова.
-- ⚠️ РАБОТАЕМ ВСЮ ПЕРВУЮ МИНУТУ, А НЕ ОДИН РАЗ. Однократное срабатывание
-- считало успехом сам факт вызова, а не исчезновение окна с экрана.
--
-- ЛАМПА ЖИВЁТ ЗДЕСЬ ЖЕ (09.09.2026, после четвёртого отказа показа). Создавать
-- своё окно нельзя - это уронило игру в ту же секунду (docs/06, EXP-0060).
-- Зато у окна, которое игра показывает САМА, мы уже проверенно меняем состояние:
-- SetVisibility и RemoveFromParent на нём сработали. Значит вместо того, чтобы
-- просто убрать сообщение про сеть, мы сперва ПЕРЕПИШЕМ его текст на состояние
-- сборки, подержим несколько секунд и снимем. Один ход закрывает оба заказа.
--
-- Это НЕ запись в шаблон класса (третий крэш) и НЕ создание виджета (четвёртый):
-- это живой экземпляр, созданный самой игрой.
local modal_marked_ms = nil

local function hide_offline_modal(elapsed_ms, text)
    -- ⚠️ ПОСЛЕ УСПЕХА БОЛЬШЕ НЕ ИЩЕМ. 09.09.2026 однократность была снята, и
    -- поиск окон стал идти КАЖДЫЙ тик всю минуту: это перечисление 552 живых
    -- виджетов с чтением имени класса у каждого, тридцать раз подряд. Своей
    -- вины в обрывах я доказать не могу, но и держать такую нагрузку без нужды
    -- незачем: работа сделана - перестань работать.
    if offline_modal_handled then return end
    -- Окно живёт секунды; за пределами окна не трогаем ничего.
    if elapsed_ms > cfg.hide_window_ms then return end
    local msg = last_requested_message()
    local boxes = find_live_messageboxes()
    local w = boxes[1]
    if msg ~= "FlsOfflineMode" or not w then
        if not offline_modal_reported then
            offline_modal_reported = true
            log("гашение ждёт: сообщение игры=%s, живых окон=%d",
                tostring(msg), #boxes)
        end
        return
    end

    -- Шаг первый: подменить текст и запомнить момент.
    if cfg.lamp_via_modal and not modal_marked_ms then
        modal_marked_ms = elapsed_ms
        local marked = 0
        for _, box in ipairs(boxes) do
            -- Писать во ВСЕ найденные: какое из них показано, мы не знаем -
            -- прочитать текст этих окон не удаётся, а лишняя запись безобидна.
            local ok = pcall(function() box[cfg.text_field]:SetText(FText(text)) end)
            if ok then marked = marked + 1 end
        end
        log("лампа: текст подменён в %d окне(ах) из %d — «%s»", marked, #boxes, text)
        return
    end

    -- Шаг второй: подержали - снимаем. Порядок доказан: сперва спрятать, потом
    -- отцепить; один RemoveFromParent оставлял окно на экране.
    if cfg.lamp_via_modal and elapsed_ms - modal_marked_ms < cfg.lamp_seconds * 1000 then
        return
    end
    local acted = 0
    for _, box in ipairs(boxes) do
        local ok = pcall(function()
            box:SetVisibility(2)
            if cfg.hide_method ~= "collapse" then box:RemoveFromParent() end
        end)
        if ok then acted = acted + 1 end
    end
    if acted > 0 and not offline_modal_handled then
        offline_modal_handled = true
        log("модалка убрана: окон %d из %d (%s)", acted, #boxes, cfg.hide_method)
    end
end

-- ------------------------------------------------------------------- ЛАМПА
-- Сама лампочка «моды сборки загружены». Собрана 09.09.2026 по добытым фактам,
-- а не по догадке: класс и поле найдены разведкой, а управление этим окном
-- доказано на живом примере - тем же вечером мод гасил им игровую модалку.
--
-- ПОЧЕМУ ИМЕННО ТАК:
--   * НЕ конструируем виджет руками - это был первый крэш 08.09;
--   * НЕ пишем в шаблон класса - это был третий крэш;
--   * создаём СВОЙ экземпляр окна игры её же средствами и пишем в его живое
--     поле. Читать при этом ничего не нужно: чтобы НАПИСАТЬ в надпись, читать
--     её не требуется, а чтение здесь как раз и не работает.
--
-- ЧТОБЫ ЭТО БЫЛА ЛАМПА, А НЕ МОДАЛКА: кнопки прячем (нажимать в нашем окне
-- нечего, а мёртвая кнопка хуже её отсутствия), окно делаем непрозрачным для
-- мыши, чтобы меню оставалось рабочим, и сами убираем его через несколько
-- секунд. Порядок снятия тот же, что доказан на игровой модалке: сперва
-- спрятать, потом отцепить.
local function make_lamp()
    local cls = find_class(cfg.class_path)
    if not cls then log("лампа: класс %s не загружен", cfg.class_path); return nil end
    local ctx = UEHelpers and UEHelpers.GetWorldContextObject()
    local pc  = UEHelpers and UEHelpers.GetPlayerController()
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not ctx then log("лампа: нет контекста мира"); return nil end
    if not lib then log("лампа: библиотека UMG не найдена"); return nil end
    local w = nil
    local ok, err = pcall(function() w = lib:Create(ctx, cls, pc) end)
    if not ok or not (w and w:IsValid()) then
        log("лампа: окно не создалось (%s)", tostring(err)); return nil
    end
    return w
end

-- Ставим текст ТРЕМЯ способами по убыванию правильности и берём первый, который
-- сработал. Порядок не случаен: сперва просим виджет сделать своё (у WBP_MapText
-- есть собственная SetText), потом пишем в текстовое свойство, и только
-- напоследок лезем в дочернюю надпись. Какой сработал - пишем в журнал, чтобы
-- следующая правка была по факту.
local function set_lamp_text(w, text)
    local how = nil
    pcall(function() w:SetText(FText(text)); how = "своя функция SetText" end)
    if not how then
        pcall(function() w[cfg.text_field] = FText(text); how = "свойство " .. cfg.text_field end)
    end
    if not how then
        pcall(function()
            w[cfg.text_field]:SetText(FText(text))
            how = "дочерняя надпись " .. cfg.text_field
        end)
    end
    return how
end

local function dress_lamp(w, text)
    local how = set_lamp_text(w, text)
    pcall(function() w:AddToViewport(cfg.viewport_z) end)
    -- HitTestInvisible: видно, но мышь проходит насквозь - меню остаётся живым.
    pcall(function() w:SetVisibility(3) end)
    log("лампа: текст поставлен через %s", how or "НИ ОДИН способ не сработал")
end

local function drop_lamp()
    if not (lamp and lamp:IsValid()) then lamp = nil; return end
    pcall(function() lamp:SetVisibility(1) end)      -- сперва спрятать
    pcall(function() lamp:RemoveFromParent() end)    -- потом отцепить
    lamp = nil
    log("лампа убрана")
end

local function show(text, elapsed_ms)
    if cfg.class_path == "" or cfg.text_field == "" then return end
    if lamp then
        if elapsed_ms - lamp_born_ms > cfg.lamp_seconds * 1000 then drop_lamp() end
        return
    end
    if lamp_born_ms then return end                  -- уже показывали, второй раз не лезем
    if elapsed_ms < cfg.lamp_at_check * cfg.check_interval_ms then return end
    local w = make_lamp()
    if not w then lamp_born_ms = elapsed_ms; return end
    lamp = w
    lamp_born_ms = elapsed_ms
    dress_lamp(w, text)
    log("лампа показана: %s", text)
end

-- -------------------------------------------------------------------- ЦИКЛ
load_config()

-- Шкала «Размер HUD вверху экрана» окна «Моды Krinik'а» (KUMM план 38, шаг 6): общий файл окна <игра>\ConanSandbox\Saved\KrinikSettings.lua,
-- ключ mpm_hud_scale (множитель; нет ключа — значение config.lua, его мод не пишет). Читается при загрузке; после «Сохранить» окно поднимает общий
-- номер KrinikSettingsVersion, а мод сверяет его на закрытии окна игры — событии, не таймере (правило дома 7) — и сразу переставляет HUD.
-- [TESTED: 2026-10-31 · живая игра: x1.25 без ключа, x1.50 после «Сохранить» и после перезапуска, сброс вернул 1.25 · KUMM testcases/reports/2026-10-31_conan-hub-mpm-page.md]
local HUD_SCALE_OWN = cfg.hud_scale
local SETTINGS_STORE = (SCRIPT_DIR:gsub("/", "\\"):match("^@?(.*)\\ConanSandbox\\Binaries\\") or "") .. "\\ConanSandbox\\Saved\\KrinikSettings.lua"
local settings_seen = nil
local function read_settings_store(why)
    local v = nil
    local chunk = loadfile(SETTINGS_STORE)
    if chunk then
        local ok, t = pcall(chunk)
        if ok and type(t) == "table" and type(t.mpm_hud_scale) == "number" then v = t.mpm_hud_scale end
    end
    cfg.hud_scale = v or HUD_SCALE_OWN
    log("масштаб HUD x%.2f (%s, %s)", cfg.hud_scale or 0, v and "окно «Моды Krinik'а»" or "config.lua", why)
end
read_settings_store("загрузка")
pcall(function()
    -- один обработчик (до вызова), как у окна настроек и камеры: пост-обработчик UE4SS здесь не доказан (EXP-0402)
    RegisterHook("/Script/ConanSandbox.GUIModuleController:ActivateModule", function(_, _, activate)
        local ok, on = pcall(function() return activate:get() end)
        if not ok or on ~= false then return end
        local okv, ver = pcall(function() return ModRef:GetSharedVariable("KrinikSettingsVersion") end)
        if not okv or ver == nil or ver == settings_seen then return end
        settings_seen = ver
        read_settings_store("номер настроек " .. tostring(ver))
        local oka, err = pcall(apply_hud_scale)
        if not oka then log("масштаб HUD упал: %s", tostring(err)) end
    end)
end)
local expected = read_modlist()
local checks = 0
local reported = nil        -- последний напечатанный вердикт: печатаем только смену

-- ⚠️ ПЕРЕСЧИТЫВАЕМ КАЖДЫЙ РАЗ, А НЕ ОДИН.
-- Первая версия читала журнал единожды и запоминала ответ. 08.09.2026 она
-- прочитала его в 19:45:50.97, а игра дописала строку про последний мод в
-- 19:45:51.04 - опоздание в семьдесят миллисекунд превратилось в приговор
-- "моды 7/8, нет: MrS_LevelAndAttributeOverhaul", хотя мод был смонтирован
-- нормально. Ложная тревога хуже молчания: владелец пошёл бы чинить исправное.
-- ГАШЕНИЕ ЭЛЕМЕНТОВ ГЛАВНОГО МЕНЮ (cfg.hide_menu_elements). [NOT-TESTED]
-- Игра пересоздаёт меню при каждом выходе из мира, поэтому работа - в тике, а не один раз.
-- Дорогой перебор всех элементов интерфейса (FindAllOf("Widget") - тысячи объектов) идёт
-- ТОЛЬКО когда появился новый экземпляр меню; в остальных тиках - две дешёвые проверки
-- видимости запомненных элементов и повторное сворачивание, если меню их вернуло.
local MENU_TRIES = 5
local menu_seen, menu_hidden, menu_tries = nil, {}, 0
local function hide_menu_elements()
    local menu = nil
    for _, m in ipairs(FindAllOf("W_MainMenu_MainMenu_C") or {}) do
        local full = ""
        pcall(function() full = m:GetFullName() end)
        -- GetFullName = "<класс> <путь>"; детей сверяем по ПУТИ: у них впереди свой класс
        -- (первая версия сверяла с классом меню и нашла 0 из 2, 09:39:44).
        local path = full:match("^%S+%s+(.+)$") or full
        if path:find("Transient", 1, true) then menu = path end
    end
    if not menu then menu_seen, menu_hidden, menu_tries = nil, {}, 0 return end
    if menu ~= menu_seen then menu_tries = 0 end
    -- Перебираем заново, пока не найдено всё: дерево меню достраивается не в тот же тик.
    -- Не больше MENU_TRIES раз на экземпляр: переименованный в патче элемент иначе стоил бы
    -- полного перебора тысяч объектов каждые две секунды всю сессию.
    if menu ~= menu_seen or (#menu_hidden < #cfg.hide_menu_elements and menu_tries < MENU_TRIES) then
        menu_seen, menu_hidden, menu_tries = menu, {}, menu_tries + 1
        local prefix = menu .. "."
        for _, w in ipairs(FindAllOf("Widget") or {}) do
            local full = ""
            pcall(function() full = w:GetFullName() end)
            if full:find(prefix, 1, true) then
                for _, name in ipairs(cfg.hide_menu_elements) do
                    if full:sub(-(#name + 1)) == "." .. name then
                        menu_hidden[#menu_hidden + 1] = w
                    end
                end
            end
        end
        log("меню: найдено элементов к гашению %d из %d (попытка %d)",
            #menu_hidden, #cfg.hide_menu_elements, menu_tries)
    end
    for _, w in ipairs(menu_hidden) do
        if w:IsValid() and w:GetVisibility() ~= 1 then w:SetVisibility(1) end
    end
end

-- Самозамер (правило дома: мод меряет себя сам): самый долгий тик — в строку «наблюдение окончено». [NOT-TESTED]
local tick_worst_ms = 0
local paks_text = nil   -- итог счёта паков, когда сошлись все

local function tick()
    local tick_t0 = os.clock()
    checks = checks + 1
    -- Журнал игры (2 МБ, 30 мс на чтение) читается, пока сборка не сошлась; сошлась — итог запомнен и
    -- больше не читается (2026-10-29, фриз главного потока — у подписок ниже). [NOT-TESTED]
    local text = paks_text
    if not text then
        local seen = mounted_paks()
        local found, missing = {}, expected
        if seen then found, missing = compare(expected, seen) end
        text = plate_text(found, missing, #expected, seen)
        if seen and #expected > 0 and #missing == 0 then paks_text = text end
    end

    if text ~= reported then
        log("%s (эталон %d модов)", text, #expected)
        reported = text
    end

    -- ⚠️ ОДНА ЦЕПОЧКА ТАЙМЕРОВ НА ВЕСЬ МОД. Два потока заданий в очередь UE4SS
    -- уронили игру 08.09 через несколько минут нормальной работы (EXP-0052),
    -- поэтому и разведка, и показ живут внутри этого тика, а не рядом с ним.
    -- Зонд интерфейса ждёт МИРА, а не тика: он срабатывает на первом опросе, где
    -- виджеты искомого мода уже есть в памяти, и дальше молчит. Живёт внутри
    -- ЭТОГО тика по тому же правилу одной цепочки таймеров.
    -- ⚠️ ОПРАШИВАЕМ РЕДКО, А НЕ КАЖДЫЙ ТИК: FindAllOf по классу не бесплатен
    -- (так записано и в моде камеры), а загрузка мира занимает десятки секунд.
    -- Раз в пять тиков после тридцатой секунды - это ~27 опросов на пять минут
    -- вместо 150, и ни одного лишнего после того, как отчёт снят.
    if (cfg.probe_widget_prefix ~= "" or #(cfg.probe_find_classes or {}) > 0)
       and checks >= 15 and checks % 5 == 0 then
        local ok, err = pcall(widget_probe)
        if not ok then log("зонд интерфейса упал: %s", tostring(err)) end
    end

    -- Масштаб HUD - в этом же тике, по правилу одной цепочки таймеров.
    -- ⚠️ ПОВТОРЯЕМ, А НЕ ДЕЛАЕМ ОДИН РАЗ: игра пересоздаёт виджеты HUD при
    -- смерти, возрождении и выходе в меню, и однократная правка пережила бы
    -- только первую из них. Запись идёт лишь при расхождении, так что в покое
    -- это чтение, а не правка.
    if cfg.hud_scale and cfg.hud_scale > 0 then
        local ok, err = pcall(apply_hud_scale)
        if not ok then log("масштаб HUD упал: %s", tostring(err)) end
    end

    -- Прибивка виджетов за кромку - в этой же цепочке и по той же причине:
    -- игра пересоздаёт HUD при смерти, возрождении и выходе в меню, и
    -- однократная правка пережила бы только первый раз.
    if type(cfg.hud_pin) == "table" and #cfg.hud_pin > 0 then
        local ok, err = pcall(apply_hud_pin)
        if not ok then log("привязка HUD упала: %s", tostring(err)) end
    end

    if cfg.mode == "probe" then
        if checks >= cfg.probe_at_check then pcall(probe) end
    elseif cfg.mode == "show" then
        local ok, err = pcall(show, text, checks * cfg.check_interval_ms)
        if not ok then log("лампа упала: %s", tostring(err)) end
    end

    if cfg.hide_offline_modal then
        local ok, err = pcall(hide_offline_modal, checks * cfg.check_interval_ms, text)
        if not ok then log("гашение модалки упало: %s", tostring(err)) end
    end

    if type(cfg.hide_menu_elements) == "table" and #cfg.hide_menu_elements > 0 then
        local ok, err = pcall(hide_menu_elements)
        if not ok then log("гашение рамки меню упало: %s", tostring(err)) end
    end

    -- ⚠️ ПРИ ВКЛЮЧЁННОМ МАСШТАБЕ HUD ЦЕПОЧКА НЕ ОСТАНАВЛИВАЕТСЯ.
    -- Наблюдение за сборкой - дело первых секунд, поэтому оно и кончалось. А
    -- масштаб надо возвращать после КАЖДОГО пересоздания виджетов (смерть,
    -- возрождение, выход в меню), то есть всю сессию.
    -- ⚠️ 2026-10-29: «цена честная и мелкая» оказалась ложью. Тик всю сессию читал журнал игры целиком
    -- (2 МБ, 30 мс) и дважды перебирал все виджеты с именами (по 26 мс): фриз главного потока 110–120 мс
    -- каждые 2,12 с (PresentMon 2026-10-29 10:4x; владелец: «есть какие-то фризы раз в 3 секунды примерно» ·
    -- «я просил писать моды уважительно к главному потоку»). Теперь цепочка живёт только первые cfg.checks
    -- тиков; пересоздание HUD и меню ловят подписки на создание виджета ниже — событие, не опрос. [NOT-TESTED]
    tick_worst_ms = math.max(tick_worst_ms, (os.clock() - tick_t0) * 1000)
    if checks < cfg.checks then
        ExecuteInGameThreadWithDelay(cfg.check_interval_ms, tick)
    else
        log("наблюдение окончено: %s · самый долгий тик %.1f мс", text, tick_worst_ms)
    end
end

-- Подписки на создание виджета: HUD Hosav пересоздаётся при смерти, возрождении и выходе в меню, главное
-- меню — при каждом выходе из мира. Работа — только в эти мгновения (образец — KrinikUIFixes, прицел
-- KrinikConanArchery). Уведомление приходит не обязательно в игровом потоке — работа уходит туда. [NOT-TESTED]
local HUD_SCALE_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_SmoothHP.W_SmoothHP_C"
local MAIN_MENU_CLASS_PATH = "/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu.W_MainMenu_MainMenu_C"
local AFTER_CREATE_MS = { 500, 2000 }               -- дерево виджета достраивается не в тот же кадр
local MENU_PASSES_MS = { 500, 1500, 3000, 6000 }    -- то же для меню: его элементы находит до MENU_TRIES проходов

local function timed(label, fn)
    local t0 = os.clock()
    local ok, err = pcall(fn)
    local ms = (os.clock() - t0) * 1000
    if not ok then log("%s упало: %s", label, tostring(err)) end
    log("%s: %.1f мс", label, ms)
end

if cfg.hud_scale and cfg.hud_scale > 0 then
    NotifyOnNewObject(HUD_SCALE_CLASS_PATH, function()
        ExecuteInGameThread(function()
            for _, ms in ipairs(AFTER_CREATE_MS) do
                ExecuteInGameThreadWithDelay(ms, function() timed("масштаб HUD по созданию", apply_hud_scale) end)
            end
        end)
    end)
end

if type(cfg.hide_menu_elements) == "table" and #cfg.hide_menu_elements > 0 then
    NotifyOnNewObject(MAIN_MENU_CLASS_PATH, function()
        ExecuteInGameThread(function()
            for _, ms in ipairs(MENU_PASSES_MS) do
                ExecuteInGameThreadWithDelay(ms, function() timed("меню по созданию", hide_menu_elements) end)
            end
        end)
    end)
end

ExecuteInGameThreadWithDelay(3000, tick)
log("загружен")
