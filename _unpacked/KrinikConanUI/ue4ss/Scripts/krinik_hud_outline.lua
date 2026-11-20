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
    for _, w in ipairs(FindAllOf("TextBlock") or {}) do   -- templates-ok: kept by the LIVE HUD's instance name (`W_NewHealthUI_C_<n>`), templates lack it
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
local DPS_FILL = { R = 0.0, G = 0.0, B = 0.0, A = 0.20 }   -- фон кнопки свёрнутого счётчика: виден на 20 % (вариант 5, папка 49)
local DPS_RIM = { R = 1.0, G = 1.0, B = 1.0, A = 0.25 }    -- белый контур, виден на 25 %
local DPS_RIM_WIDTH = 1.0
local DPS_CORNER = 3.0
local function live_meter()
    for _, w in ipairs(FindAllOf("DN_UI_DmgWidget_C") or {}) do
        if w and w:IsValid() and not w:GetFName():ToString():find("Default__", 1, true) and w:IsInViewport() then return w end
    end
    return nil
end
local function f1_label(m)
    m = m or live_meter()
    if not m or not m:IsValid() then return end
    local border, btn = m.RestoreWindow, m.RestoreBtn
    local cur = border:GetContent()
    if cur and cur:IsValid() and cur:GetClass():GetFName():ToString() == "HorizontalBox" then return end
    local tree = m.WidgetTree
    local hbox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"), tree, FName("KrinikF1Box"))
    local plate = StaticConstructObject(StaticFindObject("/Script/UMG.Border"), tree, FName("KrinikF1Plate"))
    local txt = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), tree, FName("KrinikF1Label"))
    -- Вид кнопки: тёмный фон виден на 20 %, тонкий белый контур на 25 %, минус и «F1» — без прозрачности (`[OWNER]` 2026-11-01 15:2x–15:34
    -- «в свернутом состоянии dps мод нужно сделать прозрачным, оставить полоску, и дать белый контур» · «минус нужно сделать без прозрачности» ·
    -- «а контур и фон с прозрачностью» · «вот второй слека вкрасиво» — вариант 5 папки отсмотра 49). Своя кисть RoundedBox вместо тёмной
    -- текстуры мода; контур RenderOpacity не слушает — его прозрачность в собственном цвете (конспект KUMM DamageNumber.md).
    local br = border.Background
    br.DrawAs = 4                                                                      -- ESlateBrushDrawType::RoundedBox
    br.TintColor = { SpecifiedColor = DPS_FILL, ColorUseRule = 0 }
    br.OutlineSettings.Width = DPS_RIM_WIDTH
    br.OutlineSettings.Color = { SpecifiedColor = DPS_RIM, ColorUseRule = 0 }
    br.OutlineSettings.RoundingType = 0                                                -- FixedRadius
    br.OutlineSettings.CornerRadii = { X = DPS_CORNER, Y = DPS_CORNER, Z = DPS_CORNER, W = DPS_CORNER }
    plate:SetBrush(br)
    plate:SetBrushColor(border.BrushColor)
    plate:SetPadding(border.Padding)
    -- `border.Background` пришёл ССЫЛКОЙ: правка выше дала контур и внешней рамке — вторая рамка вокруг «— F1» (кадр 15:36). Внешняя
    -- не рисуется вовсе (DrawAs 0 — NoDrawType; прозрачный BrushColor контур не гасит).
    local ob = border.Background
    ob.DrawAs = 0
    border:SetBrush(ob)
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
-- Окно счётчика урона рождается заново после экрана загрузки в мире (телепорт, путевой камень, возрождение), а HUD Hosav — нет: подпись F1
-- и прозрачный вид оставались на старом окне, новое показывало голую тёмную кнопку (KUMM plan 44 шаг 1, 2026-11-03: после TeleportPlayer —
-- два окна, у нового в RestoreWindow кнопка вместо KrinikF1Box). Поэтому вид ставится и на рождение самого окна. Шаблон класса пропускается;
-- дерево окна достраивается не в тот же кадр — через FIRST_PASS_MS. [NOT-TESTED]
local METER_CLASS_PATH = "/Game/Mods/DamageNumber/UI/DN_UI_DmgWidget.DN_UI_DmgWidget_C"
NotifyOnNewObject(METER_CLASS_PATH, function(m)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(FIRST_PASS_MS, function() pcall(function()
            if not m:IsValid() or m:GetFName():ToString():find("Default__", 1, true) then return end
            f1_label(m)
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
-- 2026-11-01: `[OWNER]` «в виджете ХУДа температура 37, и белая» · «баг» · «все что на пороге и выше этого порога - красным» · «а все, что на пороге
-- и ниже порога сильного холода - синим» (10:10). Ступени игры в Get_TempImage Hosav (байткод 3.0.1, 2026-11-01): жара 20 · 30 · 40 · 55, холод
-- −20 · −30 · −40 · −55. «Сильный» порог — вторая ступень, ±30: по примеру владельца 37 °C (энергия ≈ 30) уже красное; «тепло» 20–30 — белое. [AI]
-- Белое при красном свойстве (кадр 10:14) — причина найдена 10:19: поиск по имени поля брал ШАБЛОНЫ классов (`…W_SmoothHP_C:WidgetTree.TextBlock_TempText`,
-- шаблон оверлея — «Default__» в их имени нет) и красил их, а живые поля на экране оставались белыми; шаблоны не умирают, и новые поля не искались.
-- Живое поле — в дереве экземпляра: в полном имени `WidgetTree_<число>.` (урок KUMM EXP-0385 — FindFirstOf/FindAllOf отдают и шаблон).
-- [TESTED: 2026-11-01 · жара 33 — красное на кадрах +5 с и +60 с (до правки белое), «тепло» 21 — белое, переход в холод ровно на −30,0 по журналу;
--  синий кадром в холоде не снят · KUMM testcases/TC_conan_hud_temperature_thresholds_2026-11-01.md]
-- 2026-11-01 10:47, уточнение владельца: `[OWNER]` «я заказывал синий, красный - с плавными переводами от белого к полностью насыщенному для холода
-- и жары, и белый - для диапазона нормальных температур». Поэтому: норма (−20 … 20) белая; от края нормы до сильного порога цвет плавно идёт от
-- белого к полному (20 → 30 к красному, −20 → −30 к синему); за сильным порогом — полный цвет. [AI] — границы «нормы» и «сильного» по ступеням игры.
-- Плавный цвет не мигает на границе — гистерезис не нужен.
-- [TESTED: 2026-11-01 · остывание 33,9 → 18,4 на пляже: полный красный, плавно к белому, норма белая — кадры глазом; холод кадром не снят ·
--  KUMM testcases/TC_conan_hud_temperature_thresholds_2026-11-01.md R1]
local TEMP_NORM_HOT, TEMP_STRONG_HOT = 20.0, 30.0
local TEMP_NORM_COLD, TEMP_STRONG_COLD = -20.0, -30.0
local TEMP_RED = { R = 1.0, G = 0.22, B = 0.18 }
local TEMP_BLUE = { R = 0.25, G = 0.55, B = 1.0 }
local TEMP_STEPS = 20          -- цвет меняется ступенями по 5 % перехода: глаз мельче не различит, а вызовов меньше
-- 2026-11-01 13:15, владелец: `[OWNER]` «почему то до сих пор температура в худ белая на высоких значениях» · «внизу возле панели быстрых действий
-- ванильный индикатор перегрева висит, то есть механика игры понимает, что герою жарко» · «но твой мод худа цифру держит белой при этом». Было:
-- на пороге 20 — белый, и смесь в ЛИНЕЙНЫХ значениях UMG — энергия 23 (33 °C, значок перегрева игры горит) давала (1.00, 0.81, 0.80) — на глаз белый.
-- Теперь: с первой ступени перегрева игры цвет сразу TEMP_MIN_TINT пути к полному и густеет к сильному порогу; смесь — в sRGB (как видит глаз),
-- в UMG уходит линейное значение. [AI] 0.7 — на глаз владельца.
local TEMP_MIN_TINT = 0.7
local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
local function to_srgb(x) return x ^ (1 / 2.2) end
local function to_lin(x) return x ^ 2.2 end
local function mix(to, t)
    local function ch(c) return to_lin(1 + (to_srgb(c) - 1) * t) end
    return { SpecifiedColor = { R = ch(to.R), G = ch(to.G), B = ch(to.B), A = 1.0 }, ColorUseRule = 0 }
end
-- ступень −STEPS … +STEPS: знак — холод или жара, величина — доля пути от белого к полному цвету; 0 — только в норме
local function temp_step(e)
    if e >= TEMP_NORM_HOT then
        return math.max(1, math.floor(clamp01((e - TEMP_NORM_HOT) / (TEMP_STRONG_HOT - TEMP_NORM_HOT)) * TEMP_STEPS + 0.5))
    end
    if e <= TEMP_NORM_COLD then
        return -math.max(1, math.floor(clamp01((TEMP_NORM_COLD - e) / (TEMP_NORM_COLD - TEMP_STRONG_COLD)) * TEMP_STEPS + 0.5))
    end
    return 0
end
local function tint(k) return TEMP_MIN_TINT + (1 - TEMP_MIN_TINT) * k / TEMP_STEPS end
local function step_color(k)
    if k > 0 then return mix(TEMP_RED, tint(k)) end
    if k < 0 then return mix(TEMP_BLUE, tint(-k)) end
    return mix(TEMP_RED, 0)
end
local TEMP_FIELDS = { TextBlock_TempText = true, TextBlock_Temp = true }
local temp_blocks, temp_zone = {}, nil   -- temp_zone — ступень цвета, поставленная полям последней

-- Цвет — по ступени САМОЙ ИГРЫ (2026-11-01 13:2x): значок перегрева у быстрой панели — дебафф героя BP_AC_Buff_Heat_Stage<1…4> (холод —
-- BP_AC_Buff_Cold_Stage<1…4>, /Game/Systems/Buffs/TemperatureBuffs/); при энергии 23 на герое висел Heat_Stage2, а значок горел и при ≈ 17,6
-- (кадр 12:45, «30 °C» с сердцем Hosav) — пороги Hosav (±20) у игры не те. Ступень 1 — TEMP_MIN_TINT пути к полному цвету, ступень 4 — полный.
-- Цена: обход 165 компонентов героя — 1,7 мс (замер пультом), поэтому спрашиваются только восемь классов ступеней (классы — кэш; ещё не
-- загруженный класс ищется заново не чаще раза в 10 с), и только когда сменилась ступень энергии или пропал запомненный компонент дебаффа;
-- в остальные секунды — одна проверка IsValid.
local STAGE_BASE = "/Game/Systems/Buffs/TemperatureBuffs/BP_AC_Buff_"
local STAGE_RETRY_S = 10.0
local stage_cls, stage_miss_at = {}, {}
local stage_comp, stage_k, stage_energy_step = nil, 0, nil
local function stage_class(kind, s)
    local key = kind .. s
    local c = stage_cls[key]
    if c then return c end
    if stage_miss_at[key] and os.clock() - stage_miss_at[key] < STAGE_RETRY_S then return nil end
    local name = "BP_AC_Buff_" .. kind .. "_Stage" .. s
    c = StaticFindObject(STAGE_BASE .. kind .. "_Stage" .. s .. "." .. name .. "_C")
    if c and c:IsValid() then stage_cls[key] = c; return c end
    stage_miss_at[key] = os.clock()
    return nil
end
local function game_stage(pawn, energy_step)
    if stage_comp and stage_comp:IsValid() and energy_step == stage_energy_step then return stage_k end
    stage_energy_step = energy_step
    stage_comp, stage_k = nil, 0
    for _, kind in ipairs({ "Heat", "Cold" }) do
        for s = 1, 4 do
            local c = stage_class(kind, s)
            if c then
                local a = pawn:K2_GetComponentsByClass(c)
                if #a > 0 then
                    stage_comp = a[1]:get()
                    stage_k = kind == "Heat" and s or -s
                    return stage_k
                end
            end
        end
    end
    return 0
end
local function stage_color(k)
    if k == 0 then return mix(TEMP_RED, 0) end
    local t = TEMP_MIN_TINT + (1 - TEMP_MIN_TINT) * (math.abs(k) - 1) / 3
    return mix(k > 0 and TEMP_RED or TEMP_BLUE, t)
end

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
    local zone = game_stage(pawn, temp_step(e))
    local fresh = false
    if not temp_fields_alive() then
        temp_blocks = {}
        for _, tb in ipairs(FindAllOf("TextBlock") or {}) do
            if tb:IsValid() and TEMP_FIELDS[tb:GetFName():ToString()] and tb:GetFullName():find("WidgetTree_%d+%.") then
                temp_blocks[#temp_blocks + 1] = tb
            end
        end
        fresh = #temp_blocks > 0
    end
    if zone == temp_zone and not fresh then return end
    temp_zone = zone
    local c = stage_color(zone)
    for _, tb in ipairs(temp_blocks) do tb:SetColorAndOpacity(c) end
    log(("температура: энергия %.1f → ступень игры %d (жара +, холод −), полей %d%s"):format(e, zone, #temp_blocks, fresh and " (новые)" or ""))
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
