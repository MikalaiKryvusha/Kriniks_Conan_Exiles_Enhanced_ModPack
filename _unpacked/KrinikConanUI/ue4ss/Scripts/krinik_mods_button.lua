--[[
  KrinikConanUI:ModsButton — кнопка «Настройки модов» в нижней панели инвентаря и её выпадающий список (KUMM plans/40_epic40_phase3_inventory_button_list.md).

  Слово владельца 2026-10-31 19:09 «в окне персонажа внизу кнопка Настройки модов - клик по ней открывает вертикальный скролящсок-дроп-даун» · 19:10
  «кликаешь по Моды Krinik'а - открывается его окно-хаб» · 19:14 «если у автора один мод - ему отдельную кнопку не делаем, а объединяем их в Прочее» ·
  19:16 «рыбалка над прочим, прочее всегда внизу» · 2026-11-01 15:49 «она там одна должна остаться» · «настройки рыбалки и настройки интерфейса оттуда
  уходят» · «красная справа вертикальная по модам ксавьера - тоже уходит».

  Ступень 2 (2026-11-01): список «Моды Krinik'а · Моды Xevyr'а · Рыбалка · Прочее». «Моды Xevyr'а» и «Прочее» пока — подсписки модов, каждый пункт
  открывает родное окно настроек мода (модуль DT_UIModuleTable). Решение владельца 13:40 — их окна должны стать нашими хабами с настоящими строками
  («не в его кривых косых окнах, а в нашем красивом»); это следующая ступень плана 40.3, а подсписки держат доступ к окнам, пока кнопки Hosav,
  рыбалки и боковая вкладка Xevyr убраны (одним шагом, чтобы игрок не потерял окна).

  Как устроено (пробы 2026-11-01 16:3x, пультом и настоящей мышью):
  - кнопка и пункты — ванильная кнопка игры WBP_ButtonBase (WidgetBlueprintLibrary:Create + SetLabel); IsHovered видит настоящий курсор;
  - список — VerticalBox, созданный в WidgetTree окна инвентаря (StaticConstructObject, как зеркало фраз в krinik_shout_fade) и положенный в тот же
    Overlay_0, где лежит нижняя панель: влево-вниз, над панелью (отступ снизу — желаемая высота панели), по ширине самого длинного пункта;
  - клик — RegisterKeyBind(LMB) → игровой поток → IsHovered (события мыши UserWidget из Lua не приходят, EXP-0399); клик мимо списка и кнопки
    закрывает список;
  - боковая вкладка Xevyr (XCS_W_Container — его быстрая панель: те же четыре мода, что в нашем подсписке) сворачивается при рождении
    своего окна (ниже); её модуль XCS_Panel живёт — по нему раздел паузы узнаёт «Снаряжение». Ассет общий для пяти паков Xevyr — правка в Lua,
    раз на рождение окна, без опроса;
  - одно окно за раз: перед открытием пункта закрываются (ActivateModule false) все окна из списка, что открыты.
  Стоимость: без открытого инвентаря LMB возвращается на одной проверке флага; поиски по сцене — только на событии и на клике в инвентаре.
  [NOT-TESTED]
]]

local MOD = "KrinikConanUI:ModsButton"
local LABEL = "Настройки модов"
local BACK = "‹ Назад"
local BAR_GAP = 20.0                   -- поле слева у кнопки и у списка, единицы интерфейса (кадр 2026-11-01 15:47, как у «Закрыть» справа)
local BAR_HEIGHT_FALLBACK = 78.0       -- высота нижней панели, если желаемый размер не прочитан (кадр 16:3x: низ списка над верхом панели)
local VIS_VISIBLE, VIS_COLLAPSED, VIS_SELF_HIT_TEST_INVISIBLE = 0, 1, 4

-- Пункты списка. Имена модов в подсписках — как в списке модов сборки и в руководстве (собственные имена модов); порядок — по алфавиту.
-- Модуль — строка живой DT_UIModuleTable (обход окон 2026-11-01 16:4x: каждое открылось поверх инвентаря). Не вошли: ModControlPanel («Нет доступных
-- виджетов»), Pickup+_Settings (окно рисуется обрывками), IdeaPoet_EdAp_W_UI_MainMenu (редактор внешности — не настройки), PRMainMenu (ронял игру).
local TOP = {
    { label = "Моды Krinik'а", module = "KrinikModSettings", hub = "krinik" },   -- hub: какой хаб покажет наше окно (krinik_mod_settings, план 40.3 I6.1)
    { label = "Моды Xevyr'а", sub = "xevyr" },
    { label = "Рыбалка", module = "ExilesFishingTuning" },
    { label = "Прочее", sub = "other" },
}
local SUB = {
    xevyr = {
        { label = "Al-Merayah Reborn", module = "AMR_Settings" },
        { label = "Lore & Loot Highlight", module = "LLH_Settings" },
        { label = "Proximity Party", module = "PrP_Settings" },
        { label = "Simple Minimap", module = "SM_UI_Settings" },
        { label = "The Damage Meter", module = "DN_UI_Settings" },
    },
    other = {
        { label = "Emberlight", module = "EmberlightMasterConfig" },
        { label = "Enhanced Armory and Arsenal", module = "EAA_Armorsettings" },
        { label = "Hosav's Custom UI", module = "HosavUIsettings" },
        { label = "Night Terrors", module = "NightTerrorsSettings" },
        { label = "Player Ignores Follower Collision", module = "PIFC_Settings" },
    },
}
local SLOTS = 6                        -- самый длинный показ: подсписок из пяти + «Назад»

-- все модули окон списка — для «одно окно за раз» и для Esc раздела паузы
local MODULES = {}
for _, e in ipairs(TOP) do if e.module then MODULES[#MODULES + 1] = e.module end end
for _, key in ipairs({ "xevyr", "other" }) do for _, e in ipairs(SUB[key]) do MODULES[#MODULES + 1] = e.module end end

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local btn = nil          -- кнопка в панели
local menu = nil         -- { vb, buttons = {}, bar } — список текущего окна инвентаря
local shown = false      -- кнопка видна (вкладка «Снаряжение» открыта); LMB без него возвращается сразу
local open_list = nil    -- nil — список закрыт; иначе таблица пунктов, что сейчас в нём

local function visible_hub()
    for _, w in ipairs(FindAllOf("CraftingGUI_C") or {}) do
        if valid(w) and w:IsVisible() then return w end
    end
    return nil
end

-- Шрифт надписи. Кнопка игры пишет Cardo-SC-Bold 18 — в нём нет кириллицы: русские буквы падали в запасной рубленый шрифт, а латиница оставалась
-- капителью с засечками («Моды Krinik'а» — два шрифта в одном слове, кадр 2026-11-01 16:38). Запасной шрифт игры для кириллицы — Noto Sans Normal
-- (кадр 4K 16:41: надписи совпали с «Настройки модов» буква в букву). Шрифт меняется ПОЛЯМИ структуры Font (как в krinik_hud_outline): таблица,
-- собранная заново с FontMaterial старого шрифта, уронила игру в UE4SS (16:39, ACCESS_VIOLATION).
local FONT_PATH, FONT_FACE = "/Game/Fonts/NotoSans.NotoSans", "Normal"

-- Надпись — своим сеттером кнопки (поле TxtLabel — GeneralText внутри, его SetText кнопка перекрывает; проба 15:46), шрифт — после неё, на КАЖДОМ показе:
-- шрифт, поставленный сразу после Create, не дожил до показа (кадр 4K 16:58 — капитель снова), а поставленный на уже показанной кнопке держится и после
-- SetLabel (живая проба 16:41). Сбрасывает, видимо, построение кнопки при входе в дерево (AddChild) — потому ставим на показе списка.
local function set_label(b, text)
    b:SetLabel(FText(text))
    local fo = StaticFindObject(FONT_PATH)
    local t = b:GetWidgetFromName(FName("TxtLabel"))
    if valid(fo) and valid(t) then
        local f = t.Font
        f.FontObject = fo
        f.TypefaceFontName = FName(FONT_FACE)
        t:SetFont(f)
    end
end

local function new_button(text)
    local ref = FindFirstOf("WBP_ButtonBase_C")
    local pc = FindFirstOf("PlayerController")
    local b = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary"):Create(pc, ref:GetClass(), pc)
    set_label(b, text)
    return b
end

-- ---------- список ----------
local function close_list()
    open_list = nil
    if menu and valid(menu.vb) then menu.vb:SetVisibility(VIS_COLLAPSED) end
end

local function build_menu(cg)
    local bar = cg.ButtonBar
    if menu and valid(menu.vb) and valid(menu.bar) and menu.bar:GetFullName() == bar:GetFullName() then return menu end
    local overlay = bar:GetParent()
    local vb = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"), bar:GetOuter(), FName("VB_KrinikModsMenu"))
    -- Список не уже своей кнопки (кадр 4K 17:00: четыре пункта были уже «Настройки модов» — шов): SizeBox с наименьшей шириной кнопки;
    -- сам SizeBox мышь не ловит, пустой (список свёрнут) места не занимает.
    local box = StaticConstructObject(StaticFindObject("/Script/UMG.SizeBox"), bar:GetOuter(), FName("SB_KrinikModsMenu"))
    pcall(function() btn:ForceLayoutPrepass(); local w = btn:GetDesiredSize().X; if w and w > 1 then box:SetMinDesiredWidth(w) end end)
    box:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
    box:SetContent(vb)
    local slot = overlay:AddChildToOverlay(box)
    local h = BAR_HEIGHT_FALLBACK
    pcall(function() bar:ForceLayoutPrepass(); local y = bar:GetDesiredSize().Y; if y and y > 1 then h = y end end)
    slot:SetHorizontalAlignment(1)     -- Left
    slot:SetVerticalAlignment(3)       -- Bottom
    slot:SetPadding({ Left = BAR_GAP, Top = 0.0, Right = 0.0, Bottom = h })
    local buttons = {}
    for i = 1, SLOTS do
        local b = new_button("")
        vb:AddChildToVerticalBox(b):SetHorizontalAlignment(0)   -- Fill: все пункты — по ширине самого длинного
        buttons[i] = b
    end
    vb:SetVisibility(VIS_COLLAPSED)
    menu = { vb = vb, buttons = buttons, bar = bar }
    log("список построен в окне инвентаря (%s), над панелью %.1f", cg:GetFName():ToString(), h)
    return menu
end

local function show_list(items)
    local cg = visible_hub()
    if not cg then return end
    local m = build_menu(cg)
    for i, b in ipairs(m.buttons) do
        local e = items[i]
        if e then set_label(b, e.label); b:SetVisibility(VIS_VISIBLE) else b:SetVisibility(VIS_COLLAPSED) end
    end
    m.vb:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
    open_list = items
end

local function sub_items(key)
    local items = { { label = BACK, back = true } }
    for _, e in ipairs(SUB[key]) do items[#items + 1] = e end
    return items
end

local function close_mod_windows(gmc)
    local n = 0
    for _, m in ipairs(MODULES) do
        if gmc:IsModuleActive(FName(m)) then gmc:ActivateModule(FName(m), false, false); n = n + 1 end
    end
    return n
end

local function choose(e)
    if e.back then show_list(TOP); return end
    if e.sub then show_list(sub_items(e.sub)); return end
    close_list()
    local gmc = FindFirstOf("GUIModuleController")
    if not valid(gmc) then return end
    local closed = close_mod_windows(gmc)
    _G.__krinik_hub = e.hub            -- наше окно читает его при заполнении и сбрасывает; nil у чужих окон ничего не значит
    gmc:ActivateModule(FName(e.module), true, false)
    log("пункт «%s» — открыто окно %s (закрыто других окон: %d)", e.label, e.module, closed)
end

-- ---------- кнопка ----------
local function place()
    local cg = visible_hub()
    if not cg then return end
    local left = cg.ButtonBar.ButtonContainerLeft
    if valid(btn) then
        local par = btn:GetParent()
        if valid(par) and par:GetFullName() == left:GetFullName() then btn:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE); return end   -- та же панель: только показать
    end
    if not valid(FindFirstOf("WBP_ButtonBase_C")) then log("класс WBP_ButtonBase_C не найден"); return end
    btn = new_button(LABEL)
    local slot = left:AddChild(btn)
    pcall(function()
        slot:SetVerticalAlignment(2)
        slot:SetPadding({ Left = BAR_GAP, Top = 0.0, Right = 0.0, Bottom = 0.0 })
    end)
    log("кнопка «%s» поставлена в нижнюю панель инвентаря (%s)", LABEL, cg:GetFName():ToString())
end

-- Боковая вкладка Xevyr сворачивается в КОНСТРУКТОРЕ своего окна: модуль XCS_Panel создаёт новое окно XCS_W_Container на каждом входе на
-- «Снаряжение», ПОСЛЕ события модуля. Пройденные пути: поиск по событию находил окно только повтором через 250 мс (журнал 17:07: «повторов 1» каждый
-- раз); рождение (NotifyOnNewObject) + ближайший заход игрового потока опаздывал на кадры — видео 60 к/с 17:13 показало язычок на возврате с
-- «Талантов». Теперь — перехват после функции блюпринта окна Construct: тот же кадр, до отрисовки. Перехват ставится при первом рождении окна
-- (класс грузится вместе с модом Xevyr, не раньше); первое окно сворачивается отложенно.
-- Сворачивается СОДЕРЖИМОЕ окна — MenuContainer (язычок и выезжающая панель), не корень: корень — окно WindowRoot, и игра делает его видимым при
-- открытии (17:04: свёрнутый корень после Q → E → Q снова виден). Видимость детей открытие не трогает; пустой корень (CanvasPanel
-- SelfHitTestInvisible) мышь не ловит.
local XEVYR_PANEL_CLASS = "/Game/ModsShared/Xevyr_Shared/CommonSettings/XCS_W_Container.XCS_W_Container_C"
local xevyr_hidden = 0
local function hide_xevyr_panel(c, how)
    if not valid(c) then return end
    local full = c:GetFullName()
    if full:find(":WidgetTree.", 1, true) or full:find("Default__", 1, true) then return end
    local inner = c:GetWidgetFromName(FName("MenuContainer"))
    if valid(inner) then
        inner:SetVisibility(VIS_COLLAPSED)
        xevyr_hidden = xevyr_hidden + 1
        log("боковая вкладка «Моды Xevyr» свёрнута (%s, %d с загрузки)", how, xevyr_hidden)
    end
end
local construct_hooked = false
local xev_ok, xev_err = pcall(function()
    NotifyOnNewObject(XEVYR_PANEL_CLASS, function(c)
        if construct_hooked then return end
        construct_hooked = true
        ExecuteInGameThread(function()
            pcall(hide_xevyr_panel, c, "первое окно, отложенно")
            local ok, e = pcall(function()
                RegisterHook(XEVYR_PANEL_CLASS .. ":Construct", function(ctx) pcall(hide_xevyr_panel, ctx:get(), "в Construct") end)
            end)
            log("перехват Construct окна Xevyr: %s", ok and "встал" or ("НЕ встал: " .. tostring(e)))
        end)
    end)
end)
log("рождение окна Xevyr: слежка %s", xev_ok and "встала" or ("НЕ встала: " .. tostring(xev_err)))

-- Зовёт раздел паузы: событие вкладки «Снаряжение» (XCS_Panel), уход с неё по карусели, закрытие инвентаря.
_G.__krinik_mods_button = function(show)
    local ok, e = pcall(function()
        shown = show and true or false
        if show then
            place()
        else
            close_list()
            if valid(btn) then btn:SetVisibility(VIS_COLLAPSED) end
        end
    end)
    if not ok then log("ошибка: %s", tostring(e)) end
end

-- Esc раздела паузы: закрыть верхнее окно списка (у части окон модов нет своей кнопки с Escape). true — закрыто.
_G.__krinik_mods_menu_esc = function()
    local gmc = FindFirstOf("GUIModuleController")
    if not valid(gmc) then return false end
    for _, m in ipairs(MODULES) do
        if gmc:IsModuleActive(FName(m)) then
            gmc:ActivateModule(FName(m), false, false)
            log("Esc: окно %s закрыто, инвентарь остаётся", m)
            return true
        end
    end
    return false
end

local function on_click()
    if not valid(btn) or not btn:IsVisible() then return end
    if open_list and menu then
        for i, b in ipairs(menu.buttons) do
            if open_list[i] and valid(b) and b:IsHovered() then choose(open_list[i]); return end
        end
    end
    if btn:IsHovered() then
        if open_list then close_list() else show_list(TOP) end
        return
    end
    if open_list then close_list() end   -- клик мимо списка и кнопки
end

RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
    if not shown then return end
    ExecuteInGameThread(function()
        local ok, e = pcall(on_click)
        if not ok then log("клик: ошибка %s", tostring(e)) end
    end)
end)

log("загружен: кнопка «%s» и её список (%d окон)", LABEL, #MODULES)
