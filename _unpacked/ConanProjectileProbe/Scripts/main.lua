--[[============================================================================
  ConanProjectileProbe — разведка снаряда лука для Conan Exiles Enhanced
  ============================================================================

  ЗАЧЕМ. Владелец просит баллистику лука как в Обливионе: стрела по параболе.
  Разведка 09.09.2026 (docs/08-мастерская-steam.md) показала: за девять лет в
  Конане этого не сделал НИКТО. Ни один мод — ни на Nexus (все 40 Enhanced),
  ни в Мастерской (5 735 модов, поиск по bow/arrow/archery/projectile) — не
  трогает скорость снаряда, гравитацию, дугу и время полёта. Все правят
  таблицы предметов: урон, вес, стак, эффекты.

  Это не совпадение, а указание. Таблицы Dev Kit отдаёт как ДАННЫЕ, а дуга
  живёт внутри блюпринта снаряда — через .pak до неё не дотянуться без
  пересборки самого блюпринта. У нас путь другой: UE4SS достаёт живой объект.

  ИМЕНА КЛАССОВ ДОБЫТЫ ЗАРАНЕЕ И ОФФЛАЙН, а не перебором в памяти
  (researches/ue5-iostore-index/ — индекс IoStore, 138 424 ассета с диска):
      Content/Items/Weapons/Bow/BP_Visual_BowProjectileBase   <- летящий снаряд
      Content/Items/Weapons/Bow/BP_Item_BowProjectileBase
      Content/Items/Weapons/Crossbow/BP_Visual_CrossbowProjectileBase
  Путь ассета Content/X соответствует объектному пути /Game/X — это и
  проверяется первым делом.

  ВОПРОС, НА КОТОРЫЙ ОТВЕЧАЕТ ЭТОТ ФАЙЛ, РОВНО ОДИН:
      есть ли внутри снаряда штатный движковый ProjectileMovementComponent?
  Если да — у него есть ProjectileGravityScale (штатно 1.0) и InitialSpeed, и
  обливионская дуга становится вопросом двух чисел. Если нет — Funcom считает
  полёт сам, и разговор совсем другой.

  ⚠️ ПРАВИЛО ЭТОГО ФАЙЛА, ОПЛАЧЕННОЕ ТРЕМЯ ПАДЕНИЯМИ ИГРЫ 08.09.2026:
  ПЕРЕБОР ЗНАЧЕНИЙ ЧУЖИХ СВОЙСТВ РОНЯЕТ ИГРУ. Поэтому две стадии:
      Numpad *  — стадия 1: ТОЛЬКО ИМЕНА. Ничего не читаем, ничего не пишем.
      Numpad /  — стадия 2: чтение ТРЁХ ИЗВЕСТНЫХ движковых полей, каждое в
                  своём pcall. Отдельная клавиша = осознанное согласие.
  Ни одного вечного цикла: в моде камеры такой цикл 09.09 накопился в 38 штук
  за сессию и оборвал игру (EXP-0062). Здесь всё только по нажатию.

  ⚠️ ПРАВКИ ПОДХВАТЫВАТЬ ПЕРЕЗАПУСКОМ ИГРЫ, НЕ Ctrl+R — по той же причине.
============================================================================]]

local MOD_NAME = "ConanProjectileProbe"

local function log(fmt, ...)
    local ok, s = pcall(string.format, fmt, ...)
    print(("[%s] %s\n"):format(MOD_NAME, ok and s or tostring(fmt)))
end

-- Сырые коды клавиш, НЕ таблица Key: в этой сборке UE4SS Key.NUM_ZERO
-- указывает на 0x69, то есть на девятку (баг разобран в моде камеры).
-- Нумпад 0-9, плюс и минус заняты камерой; свободны только эти три.
local VK_MULTIPLY = 0x6A   -- Numpad *
local VK_DIVIDE   = 0x6F   -- Numpad /

-- Кандидаты. Первым идёт снаряд лука — то, ради чего всё.
local CLASS_PATHS = {
    "/Game/Items/Weapons/Bow/BP_Visual_BowProjectileBase.BP_Visual_BowProjectileBase_C",
    "/Game/Items/Weapons/Bow/BP_Item_BowProjectileBase.BP_Item_BowProjectileBase_C",
    "/Game/Items/Weapons/Crossbow/BP_Visual_CrossbowProjectileBase.BP_Visual_CrossbowProjectileBase_C",
}

local SHORT_NAMES = {
    "BP_Visual_BowProjectileBase_C",
    "BP_Item_BowProjectileBase_C",
    "ProjectileMovementComponent",
}

-- Три движковых поля, документированных Epic. Больше не читаем НИЧЕГО.
local KNOWN_FIELDS = { "ProjectileGravityScale", "InitialSpeed", "MaxSpeed" }

local function name_of(obj)
    local n
    if pcall(function() n = obj:GetFullName() end) and n then return n end
    if pcall(function() n = obj:GetFName():ToString() end) and n then return n end
    return "(имя не прочиталось)"
end

-- ---------------------------------------------------------------- стадия 1
-- Только имена. Ничего не читаем из чужих свойств.
local function probe_names()
    log("---- СТАДИЯ 1: ТОЛЬКО ИМЕНА ----")

    -- 1. Существует ли класс по оффлайн-пути. Это проверка самой гипотезы
    --    «Content/X == /Game/X», и она бесплатна.
    if type(StaticFindObject) == "function" then
        for _, path in ipairs(CLASS_PATHS) do
            local obj
            local ok = pcall(function() obj = StaticFindObject(path) end)
            local alive = false
            if ok and obj then pcall(function() alive = obj:IsValid() end) end
            log("  класс %s -> %s", path:match("([^/.]+)_C$") or path,
                alive and "НАЙДЕН" or "нет (не загружен или путь другой)")
        end
    else
        log("  StaticFindObject в этой сборке UE4SS нет — пропускаю проверку путей")
    end

    -- 2. Что живёт в памяти прямо сейчас. Стрелу видно только в полёте:
    --    выстрелить и нажать клавишу, пока она летит.
    for _, cls in ipairs(SHORT_NAMES) do
        local list
        if not pcall(function() list = FindAllOf(cls) end) then list = nil end
        local n = 0
        if list then pcall(function() n = #list end) end
        log("  FindAllOf(%s): %d", cls, n)
        if list and n > 0 then
            for i = 1, math.min(n, 5) do
                local el
                if pcall(function() el = list[i] end) and el then
                    log("    [%d] %s", i, name_of(el))
                end
            end
        end
    end

    log("---- КОНЕЦ СТАДИИ 1. Если снарядов ноль — выстрелить и нажать ещё раз,")
    log("     пока стрела в воздухе. Значения — Numpad / (стадия 2). ----")
end

-- ---------------------------------------------------------------- стадия 2
-- Читаем ТРИ известных движковых поля. Каждое в своём pcall, без перебора.
local function probe_values()
    log("---- СТАДИЯ 2: ТРИ ИЗВЕСТНЫХ ПОЛЯ ----")

    local comps
    if not pcall(function() comps = FindAllOf("ProjectileMovementComponent") end) then
        comps = nil
    end
    local n = 0
    if comps then pcall(function() n = #comps end) end

    if n == 0 then
        log("  ProjectileMovementComponent в памяти НЕТ.")
        log("  Читается это так: либо стрелы сейчас не в полёте (выстрелить и")
        log("  повторить), либо Funcom считает полёт САМ, без движкового")
        log("  компонента — и тогда дуга лежит не здесь. Стадию 1 в помощь.")
        log("---- КОНЕЦ СТАДИИ 2 ----")
        return
    end

    log("  найдено компонентов: %d", n)
    for i = 1, math.min(n, 5) do
        local el
        if pcall(function() el = comps[i] end) and el then
            log("  [%d] %s", i, name_of(el))
            for _, f in ipairs(KNOWN_FIELDS) do
                local v
                if pcall(function() v = el[f] end) and v ~= nil then
                    log("      %s = %s", f, tostring(v))
                else
                    log("      %s — нет такого поля", f)
                end
            end
        end
    end
    log("---- КОНЕЦ СТАДИИ 2. ProjectileGravityScale штатно 1.0; больше = круче")
    log("     падение. Ничего не записано: этот мод только читает. ----")
end

-- ------------------------------------------------------------------- вход
RegisterKeyBind(VK_MULTIPLY, function() ExecuteInGameThread(function()
    pcall(probe_names)
end) end)

RegisterKeyBind(VK_DIVIDE, function() ExecuteInGameThread(function()
    pcall(probe_values)
end) end)

log("загружен. Numpad * — имена (безопасно), Numpad / — три известных поля.")
log("Мод только ЧИТАЕТ. Ни одного цикла, ни одной записи.")
