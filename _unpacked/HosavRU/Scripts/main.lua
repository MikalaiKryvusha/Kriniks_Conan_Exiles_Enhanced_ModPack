-- HosavRU - русские подписи для «Hosav's Custom UI Enhanced» поверх живых виджетов (UE4SS Lua).
--
-- ПОЧЕМУ ТАК, А НЕ .locres: 12.09.2026 загрузчик модов игры отверг пак с подменённым
-- Content/Localization/Exiles_UI/ru/Exiles_UI.locres - «Filename ... is not allowed in pak»
-- (белый список файлов платформенного пака). Штатный путь - скукованный Blueprint с
-- PolyglotDataToText - ждёт фазы 1 эпика Dev Kit (plans/06 в KUMM). Здесь - путь без кука:
-- раз в N секунд находим живые TextBlock/RichTextBlock, чьи хозяева - виджеты мода
-- (/Game/Mods/UIMod_Hosav/...), и если английский текст есть в таблице - ставим русский.
-- Таблица (Scripts/ru_table.lua) сгенерирована из принятой владельцем таблицы
-- (KUMM interviews/interview_002, 12.09.2026) прибором _config/devkit/hosav-ru-entries.py.
--
-- ПРАВИЛА, ОПЛАЧЕННЫЕ СОСЕДНИМИ МОДАМИ:
--   * ОДНА цепочка таймеров на мод (EXP-0052: два потока LoopAsync роняли игру);
--   * FindAllOf не бесплатен - опрос редкий, и только когда есть живые виджеты мода;
--   * всё в pcall: ошибка в одной надписи не должна убивать Lua-слой (EXP про зонд снаряда);
--   * ничего не создаём и не удаляем - только SetText на живом экземпляре.
-- [SUPERSEDED 2026-09-12] В игре НЕ НУЖЕН и из неё снят. Проверено с открытой панелью настроек:
-- мод увидел 199 надписей и не подменил НИ ОДНОЙ - английских строк из таблицы среди них уже не
-- было, .locres успевал раньше (журнал 14:43). Рабочая дорога - штатная цель локализации движка,
-- _config/localization/README.md. Этот файл держится как ЗАПАСНОЙ путь на случай, когда патч игры
-- положит свою цель Content/Localization/Game в пак и перебьёт нашу россыпь.
local MOD_NAME = "HosavRU"
local SCRIPT_DIR = debug.getinfo(1, "S").source:match("@?(.*[\\/])") or "./"

local function log(fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, fmt:format(...)))
end

-- ------------------------------------------------------------ НАСТРОЙКИ
local cfg = {
    interval_ms = 2000,                 -- шаг опроса
    owner_marker = "/Game/Mods/UIMod_Hosav/", -- признак виджета мода в полном имени класса-хозяина
    only_hosav = true,                  -- false = менять текст в ЛЮБОМ виджете (осторожно)
    log_first = 12,                     -- сколько первых подмен показать в журнале
}
local f = loadfile(SCRIPT_DIR .. "../config.lua")
if f then
    local ok, user = pcall(f)
    if ok and type(user) == "table" then
        for k, v in pairs(user) do cfg[k] = v end
        log("config.lua прочитан")
    else
        log("config.lua не разобран (%s), беру умолчания", tostring(user))
    end
end

-- ------------------------------------------------------------- ТАБЛИЦА
local RU = {}
do
    local tf = loadfile(SCRIPT_DIR .. "ru_table.lua")
    if tf then
        local ok, t = pcall(tf)
        if ok and type(t) == "table" then
            RU = t
            local n = 0
            for _ in pairs(RU) do n = n + 1 end
            log("таблица перевода: %d строк", n)
        else
            log("ru_table.lua не разобран: %s", tostring(t))
        end
    else
        log("ru_table.lua не найден рядом со скриптом")
    end
end

-- --------------------------------------------------------------- ЛОГИКА
-- Хозяин надписи: TextBlock -> WidgetTree -> UserWidget. Класс хозяина носит путь пакета,
-- по нему и узнаём мод. Читаем ТОЛЬКО метаданные и текст - граница EXP-0050.
local function owner_class_name(tb)
    local ok, name = pcall(function()
        local tree = tb:GetOuter()
        local w = tree and tree:GetOuter()
        return w and w:GetClass():GetFullName() or ""
    end)
    return ok and name or ""
end

local function current_text(tb)
    local ok, s = pcall(function() return tb:GetText():ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

local replaced_total, logged = 0, 0
local seen_unreadable = 0
local stats_reported = false

local function sweep_class(cname)
    local list = nil
    if not pcall(function() list = FindAllOf(cname) end) or not list then return 0, 0 end
    local ours, replaced = 0, 0
    for _, tb in ipairs(list) do
        if tb:IsValid() then
            local owner = owner_class_name(tb)
            if (not cfg.only_hosav) or owner:find(cfg.owner_marker, 1, true) then
                ours = ours + 1
                local s = current_text(tb)
                if s == nil then
                    seen_unreadable = seen_unreadable + 1
                else
                    local ru = RU[s]
                    if ru and ru ~= s then
                        local ok = pcall(function() tb:SetText(FText(ru)) end)
                        if ok then
                            replaced = replaced + 1
                            if logged < cfg.log_first then
                                logged = logged + 1
                                log("«%s» -> «%s» (%s)", s, ru, owner:match("([^%.]+)$") or owner)
                            end
                        end
                    end
                end
            end
        end
    end
    return ours, replaced
end

local ticks = 0
local function tick()
    ticks = ticks + 1
    local ours1, r1 = sweep_class("TextBlock")
    local ours2, r2 = sweep_class("RichTextBlock")
    local ours, r = ours1 + ours2, r1 + r2
    replaced_total = replaced_total + r
    if r > 0 then
        log("тик %d: надписей мода %d, подменено %d (всего %d)", ticks, ours, r, replaced_total)
    elseif not stats_reported and ours > 0 then
        stats_reported = true
        log("тик %d: надписей мода в памяти %d, английских из таблицы среди них нет (нечитаемых %d)",
            ticks, ours, seen_unreadable)
    end
end

log("старт: опрос каждые %d мс, хозяин виджета содержит «%s»", cfg.interval_ms, cfg.owner_marker)
LoopAsync(cfg.interval_ms, function()
    local ok, err = pcall(tick)
    if not ok then log("тик упал: %s", tostring(err)) end
    return false -- продолжать
end)
