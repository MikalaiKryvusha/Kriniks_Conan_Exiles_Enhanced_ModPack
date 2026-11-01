-- KrinikHudOutline — чёрная обводка текста HUD Hosav, чтобы цифры читались на ярком небе и песке.
-- [TESTED: 2026-10-25 · игра 3.0.1, вход в мир: «обводка 2 точки поставлена 50 полям», второй проход «уже стояла у 50»,
--  кадр HUD = выбранный владельцем вариант; без мода — простой текст · KUMM testcases/reports/2026-10-25_conan-3.0.1-severe-weather-fog-dlss.md]
-- Слово владельца 2026-10-25: «в моде HUD хочется небольшую тонировку фона - или больше тени под текст - что-нибудь,
-- что сделало бы текста лучше читаемыми на фоне яркого неба и песка». Из пяти вариантов, снятых пультом в полдень
-- в пустыне (тень 3 точки, обводка поверх тени, обводка 2 точки, тонкая обводка с тенью, мягкий ореол), владелец
-- выбрал обводку: «чёрная обводка 2 точки супер!» (KUMM plans/33, пункт 4а; лист «НА ОТСМОТР НИКОЛАЕМ\2 HUD читаемость»).
--
-- Как: HUD Hosav — виджет W_NewHealthUI_C; его текстовые поля (здоровье, выносливость, опыт, броня, урон, вес,
-- компас, часы) — TextBlock внутри. Мод ждёт новый экземпляр HUD (он создаётся при входе в мир и после смерти) и
-- ставит каждому TextBlock обводку шрифта. Свойство шрифта живёт в самом виджете: ставится один раз, кадр не трогает.
-- Опрос — раз в 2 с одним FindFirstOf (дёшево); полный проход по TextBlock — только на новом HUD, дважды: сразу
-- и через 5 с (часть полей Hosav достраивает позже).

-- точки; выбор владельца: 2 (25.10) → 1 — «обводку в текстах худа 1 пкс делаем» (2026-10-26)
local OUTLINE_SIZE = 1
-- Сплошная: при 0.85 обводка в 1 точку просвечивала. Владелец 2026-10-26 ≈14:44: «обводки в 1 пкс … не хватает. Или этот 1 пкс какой-то
-- прозрачный, или нужно - скорее я за этот вариант, повысить на 100 вес шрифтов и на 10% размер шрифтов».
local OUTLINE_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 }
-- Кегль ×1.1 от авторского. Вес: у Roboto игры только Light/Regular/Bold (живой CompositeFont, 2026-10-26), Medium (+100) нет —
-- следующая ступень после Regular — Bold; кадры Regular ×1.1 и Bold ×1.1 на одном месте — «НА ОТСМОТР НИКОЛАЕМ\6 HUD жирнее».
-- Шрифт Kelson Sans (8 полей) начертаний не имеет — ему только кегль. [NOT-TESTED]
local FONT_SCALE = 1.1
local ROBOTO_TYPEFACE = "Bold"
local HUD_CLASS = "W_NewHealthUI_C"
local SECOND_PASS_MS = 5000

local function log(s) print("[KrinikConanUI:HudOutline] " .. s .. "\n") end

local last_hud = nil
local done = {}   -- поля текущего HUD, которым шрифт уже поставлен (кегль множится один раз, второй проход берёт только новые)

local function apply(hud_name)
    local n, skipped = 0, 0
    for _, w in ipairs(FindAllOf("TextBlock") or {}) do
        local full = ""
        pcall(function() full = w:GetFullName() end)
        if full:find(hud_name, 1, true) then
            if done[full] then
                skipped = skipped + 1
            else
                local ok = pcall(function()
                    local f = w.Font
                    f.OutlineSettings.OutlineSize = OUTLINE_SIZE
                    f.OutlineSettings.OutlineColor = OUTLINE_COLOR
                    f.Size = math.floor(f.Size * FONT_SCALE + 0.5)
                    local fo = f.FontObject
                    if fo and fo:IsValid() and fo:GetFName():ToString() == "Roboto" then f.TypefaceFontName = FName(ROBOTO_TYPEFACE) end
                    w:SetFont(f)
                    done[full] = true
                    n = n + 1
                end)
                if not ok then log("не смог поставить шрифт: " .. full) end
            end
        end
    end
    log(("HUD %s: обводка %d, кегль x%.2f, Roboto %s — поставлено %d полям, уже стояло у %d"):format(
        hud_name, OUTLINE_SIZE, FONT_SCALE, ROBOTO_TYPEFACE, n, skipped))
end

-- Подпись «F1» у кнопки свёрнутого счётчика урона (The Damage Meter): владелец 2026-10-26 ≈14:57 — «рядом с кнопочкой свернутого DPS
-- можно писать F1? чтобы пользователи понимали, что по кнопке F1 открывается курсор, которым можно это нажать». В кнопке мода только
-- картинка (RestoreWindow → RestoreBtn → Image), текстового поля для правки ассета нет. Поэтому один раз, на новом HUD: кнопка
-- переносится в строку «кнопка + F1» внутри той же рамки — подпись прячется и появляется вместе с рамкой сама, без опроса.
-- [TESTED: 2026-10-26 · пультом в игре: «— F1» в углу; Restore → рамка скрыта вместе с подписью, окно открыто; Minimize → подпись снова ·
--  KUMM testcases/reports/2026-10-26_conan-3.0.1-session-1406-guide-hud.md, кейс H5]
-- Владелец ≈15:01: «ф1 можно писать без подкладки черной, и не курсивом, а прямо» — тёмная плашка рамки переезжает во внутреннюю рамку
-- под одной кнопкой (та же кисть и отступ), внешняя рамка становится прозрачной; подпись — шрифтом HUD (Roboto Bold) с той же обводкой.
-- ≈15:06 владелец: «11 кегль, отступ 2» (было 13 и 5)
local F1_FONT_SIZE = 11
local F1_GAP = 2
local function f1_label()
    local m = FindFirstOf("DN_UI_DmgWidget_C")
    if not m or not m:IsValid() then return end
    local border, btn = m.RestoreWindow, m.RestoreBtn
    local cur = border:GetContent()
    if cur and cur:IsValid() and cur:GetClass():GetFName():ToString() == "HorizontalBox" then return end
    local tree = m.WidgetTree
    local hbox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"), tree, FName("KrinikF1Box"))
    local plate = StaticConstructObject(StaticFindObject("/Script/UMG.Border"), tree, FName("KrinikF1Plate"))
    local txt = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), tree, FName("KrinikF1Label"))
    plate:SetBrush(border.Background)
    plate:SetBrushColor(border.BrushColor)
    plate:SetPadding(border.Padding)
    border:SetBrushColor({ R = 0, G = 0, B = 0, A = 0 })
    border:SetPadding({ Left = 0, Top = 0, Right = 0, Bottom = 0 })
    local f = m.lbl_HotkeyHelp.Font
    local roboto = StaticFindObject("/Engine/EngineFonts/Roboto.Roboto")
    if roboto and roboto:IsValid() then
        f.FontObject = roboto
        f.TypefaceFontName = FName(ROBOTO_TYPEFACE)
    end
    f.Size = F1_FONT_SIZE
    f.OutlineSettings.OutlineSize = OUTLINE_SIZE
    f.OutlineSettings.OutlineColor = OUTLINE_COLOR
    txt:SetFont(f)
    txt:SetText(FText("F1"))
    txt:SetColorAndOpacity(m.lbl_HotkeyHelp.ColorAndOpacity)
    border:SetContent(hbox)
    hbox:AddChildToHorizontalBox(plate)
    plate:SetContent(btn)
    local s = hbox:AddChildToHorizontalBox(txt)
    s:SetVerticalAlignment(2)
    s:SetPadding({ Left = F1_GAP, Top = 0, Right = 2, Bottom = 0 })
    log("подпись F1 у свёрнутого счётчика урона поставлена")
end

-- Новый HUD — событием создания виджета, а не опросом раз в 2 с (план 34, владелец 2026-10-29: «да, но аккуратно. чтобы не сломать...
-- нужно будет ретестировать после рефакторинга их»). Шаблоны класса (Default__…) пропускаются; дерево виджета достраивается не в тот же
-- кадр — первый проход через FIRST_PASS_MS, второй — через SECOND_PASS_MS, как и раньше. [NOT-TESTED]
local HUD_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_NewHealthUI.W_NewHealthUI_C"
local FIRST_PASS_MS = 500
NotifyOnNewObject(HUD_CLASS_PATH, function(hud)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(FIRST_PASS_MS, function() pcall(function()
            if not hud:IsValid() then return end
            local name = hud:GetFName():ToString()
            if name:find("Default__", 1, true) or name == last_hud then return end
            last_hud = name
            done = {}
            log("новый HUD: " .. name)
            apply(name)
            pcall(f1_label)
            ExecuteInGameThreadWithDelay(SECOND_PASS_MS, function() pcall(function() apply(name); pcall(f1_label) end) end)
        end) end)
    end)
end)
-- Цвет строки температуры (KUMM план 36 W27): `[OWNER]` «при высоких температурах красить в красный, при низких - в зелёный. Норм - белые» ·
-- 2026-10-30 10:58. Зоны — ступени самой игры, по которым Hosav выбирает значок (`W_SmoothHP::Get_TempImage`, байткод 3.0.1): энергия типа 1
-- приёмника героя ≥ 20 — «тепло» и выше, ≤ −20 — «холод» и ниже, между — «комфорт» (значок сердца). На экране Hosav пишет другие градусы
-- (энергия 21,1 → «32 °C»), поэтому зона считается по энергии, как у значка: цвет и значок меняются вместе.
-- Событие, не опрос: BPEnergyReceiver::EnergyReceived — ≈1 раз в секунду (замер пультом 2026-10-30 11:1x: 6 вызовов за ≈5 с); цвет ставится
-- только при смене зоны или на новых полях. Поля — TextBlock_TempText в двух раскладках Hosav (W_SmoothHP, W_SmoothHP_Cernter) и
-- TextBlock_Temp в W_TestHudOverlay; перебор TextBlock — только когда кэш пуст или поле умерло (новый HUD). Привязки цвета у этих полей нет —
-- поставленный цвет держится. Цвета — [AI] до взгляда владельца.
-- [TESTED: 2026-10-30 · кейсы T1–T7: жара 20,1 красная, норма белая, холод −20,5 зелёная, без мигания на границе · KUMM testcases/reports/2026-10-30_conan-hud-temperature-colour.md]
local TEMP_HOT, TEMP_COLD, TEMP_HYST = 20.0, -20.0, 1.0
local TEMP_COLORS = {
    hot  = { SpecifiedColor = { R = 1.0, G = 0.22, B = 0.18, A = 1.0 }, ColorUseRule = 0 },
    cold = { SpecifiedColor = { R = 0.30, G = 1.0, B = 0.35, A = 1.0 }, ColorUseRule = 0 },
    norm = { SpecifiedColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }, ColorUseRule = 0 },
}
local TEMP_FIELDS = { TextBlock_TempText = true, TextBlock_Temp = true }
local temp_blocks, temp_zone = {}, nil

local function temp_fields_alive()
    if #temp_blocks == 0 then return false end
    for _, tb in ipairs(temp_blocks) do if not tb:IsValid() then return false end end
    return true
end

local function on_energy(ctx)
    local recv = ctx:get()
    local pc = FindFirstOf("PlayerController")
    local pawn = pc and pc:IsValid() and pc.Pawn
    if not pawn or not pawn:IsValid() then return end
    local mine = pawn.BPEnergyReceiver
    if not mine or not mine:IsValid() or mine:GetAddress() ~= recv:GetAddress() then return end   -- только приёмник героя
    local e = recv:GetEnergy(1)
    -- Гистерезис: на границе энергия ходит 20,1 → 19,7 за 2 с (прогон 11:12) — без него текст мигал бы красным/белым. Вход в зону —
    -- по ступени игры, выход — на TEMP_HYST дальше.
    local zone
    if temp_zone == "hot" and e > TEMP_HOT - TEMP_HYST then zone = "hot"
    elseif temp_zone == "cold" and e < TEMP_COLD + TEMP_HYST then zone = "cold"
    else zone = e >= TEMP_HOT and "hot" or (e <= TEMP_COLD and "cold" or "norm") end
    local fresh = false
    if not temp_fields_alive() then
        temp_blocks = {}
        for _, tb in ipairs(FindAllOf("TextBlock") or {}) do
            if tb:IsValid() and TEMP_FIELDS[tb:GetFName():ToString()] and not tb:GetFullName():find("Default__", 1, true) then
                temp_blocks[#temp_blocks + 1] = tb
            end
        end
        fresh = #temp_blocks > 0
    end
    if zone == temp_zone and not fresh then return end
    temp_zone = zone
    for _, tb in ipairs(temp_blocks) do tb:SetColorAndOpacity(TEMP_COLORS[zone]) end
    log(("температура: энергия %.1f → зона %s, полей %d%s"):format(e, zone, #temp_blocks, fresh and " (новые)" or ""))
end

_G.__krinik_temp_fn = on_energy
if not _G.__krinik_temp_hooked then
    _G.__krinik_temp_hooked = true
    NotifyOnNewObject("/Game/Systems/BPEnergyReceiver.BPEnergyReceiver_C", function()
        ExecuteInGameThread(function()
            if _G.__krinik_temp_set then return end
            _G.__krinik_temp_set = true
            local ok, err = pcall(function()
                RegisterHook("/Game/Systems/BPEnergyReceiver.BPEnergyReceiver_C:EnergyReceived", function(ctx)
                    local f = _G.__krinik_temp_fn
                    if f then pcall(f, ctx) end
                end)
            end)
            log(ok and "температура: перехват EnergyReceived поставлен" or ("температура: перехват не встал — " .. tostring(err)))
        end)
    end)
end

log(("загружен: жду %s, обводка %d точки, кегль x%.2f, Roboto %s"):format(HUD_CLASS, OUTLINE_SIZE, FONT_SCALE, ROBOTO_TYPEFACE))
