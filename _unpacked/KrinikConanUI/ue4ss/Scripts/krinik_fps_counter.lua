-- KrinikFpsCounter — число кадров в секунду в самом правом верхнем углу экрана, как счётчик Сварога.
-- [NOT-TESTED]
-- Место — поправки владельца 2026-10-25 вечером: «В ПРАВОМ! НАД КАРТОЙ» · «вверху справа в углу, как в сварогке». Образец —
-- `SvarogsDream/src/KrinikUIRework/FpsCounter.cs`: одно число, отступ от верха и правого края 0,005 высоты экрана, кегль
-- 2/150 × 1,62 высоты, контур и тень вниз-вправо. Здесь те же доли в точках UMG (опорная высота 1080): отступ 5, кегль 23.
-- Слово владельца 2026-10-25 ≈16:50: «счётчик кадров» — «как в нашей игре UnliminiumDigital»
-- (там `game/Ui/FpsCounter.cs`: одно число, обновление 4 раза в секунду, тень под цифрой). `stat fps` в этой сборке
-- движка вырезан (кадр 16:51), поэтому счёт — свой (KUMM plans/33, пункт 4а).
--
-- Как считает: раз в 250 мс — разница счётчика кадров движка (KismetSystemLibrary.GetFrameCount) за реальное время
-- (GameplayStatics.GetRealTimeSeconds — не игровое: пауза и замедление времени число не врут). Два вызова за 250 мс —
-- главный поток не замечает (бюджет модов Сварога 1 мс — та же мерка и здесь).
-- Где рисует: свой TextBlock на корневом холсте HUD Hosav (W_NewHealthUI_C) — HUD живёт весь заход в мир и
-- пересоздаётся после смерти; мод ловит новый экземпляр так же, как KrinikHudOutline. Шрифт — с той же обводкой 2 точки.

local HUD_CLASS = "W_NewHealthUI_C"
local REFRESH_MS = 250
-- Привязка к правому верхнему углу холста: якорь (1, 0), выравнивание (1, 0) — число растёт влево от края.
local ANCHOR = { Minimum = { X = 1.0, Y = 0.0 }, Maximum = { X = 1.0, Y = 0.0 } }
local ALIGN = { X = 1.0, Y = 0.0 }
local POS = { X = -5.0, Y = 5.0 }                        -- 0,005 × 1080, как отступ Сварога
-- Кегль и вес — поправка владельца 2026-10-25 вечером: «вес счетчика кадром меньше на 100, размер меньше на 20%».
-- 23 (кегль Сварога) − 20 % = 18. Вес: у Roboto (и у шрифтов игры — KelsonSans, NotoSans, OpenSans) нет 600, есть только
-- 300 / 400 / 700 — ближайший лёгкий шаг от Bold (700) — Regular (400); обводка 2 точки добавляет цифре веса.
-- 2026-10-26 ≈15:05 владелец: «счетчик кадров размер шрифта меньше на 10%» — 18 → 16.
local FONT_SIZE = 16
local TYPEFACE = "Regular"
local COLOR = { R = 1.0, G = 1.0, B = 1.0, A = 0.95 }
local OUTLINE = { Size = 2, Color = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 } }
local SHADOW = { Offset = { X = 1.5, Y = 1.5 }, Color = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 } }   -- на светлом небе одного контура мало (Сварог, 15.10)

local function log(s) print("[KrinikConanUI:FpsCounter] " .. s .. "\n") end

local ksl, gps = nil, nil
local hud_name, text = nil, nil
local last_frames, last_time = nil, nil

local function libs()
    if not ksl or not ksl:IsValid() then ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end
    if not gps or not gps:IsValid() then gps = StaticFindObject("/Script/Engine.Default__GameplayStatics") end
    return ksl and ksl:IsValid() and gps and gps:IsValid()
end

-- Поставить TextBlock на корневой холст HUD. Возвращает виджет или nil (и пишет в журнал, почему).
local function attach(hud)
    local root = hud.WidgetTree.RootWidget
    if not root or not root:IsValid() then log("у HUD нет корневого виджета") return nil end
    local cls = root:GetClass():GetFName():ToString()
    if cls ~= "CanvasPanel" then log("корень HUD не холст, а " .. cls .. " — счётчик не поставлен") return nil end
    local tb = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), hud.WidgetTree, FName("KrinikFpsText"))
    local f = tb.Font
    f.Size = FONT_SIZE
    f.TypefaceFontName = FName(TYPEFACE)
    f.OutlineSettings.OutlineSize = OUTLINE.Size
    f.OutlineSettings.OutlineColor = OUTLINE.Color
    tb:SetFont(f)
    tb:SetColorAndOpacity({ SpecifiedColor = COLOR, ColorUseRule = 0 })
    tb:SetShadowOffset(SHADOW.Offset)
    tb:SetShadowColorAndOpacity(SHADOW.Color)
    tb:SetJustification(2)                               -- ETextJustify::Right: число прижато к краю при любой ширине
    -- ESlateVisibility::HitTestInvisible: в том же углу у Simple Minimap скрытая кнопка «спрятать карту» (по F1) —
    -- число мышь не ловит и кнопку не заслоняет.
    tb:SetVisibility(3)
    tb:SetText(FText("--"))
    local slot = root:AddChildToCanvas(tb)
    slot:SetAutoSize(true)
    slot:SetAnchors(ANCHOR)
    slot:SetAlignment(ALIGN)
    slot:SetPosition(POS)
    slot:SetZOrder(1000)
    return tb
end

-- 2026-10-29 (KUMM plans/34, W16: опросы → события, «да, но аккуратно … ретестировать»): раньше каждые 250 мс — FindFirstOf HUD и
-- FindFirstOf PlayerController. Теперь HUD приходит событием создания виджета (как у KrinikHudOutline), контроллер запоминается и
-- ищется заново, только когда умер вместе с миром; раз в 250 мс остаётся сам пересчёт числа. [NOT-TESTED]
-- Выключатель — строка «Счётчик кадров в углу экрана» хаба «Моды Krinik'а» (ключ ui_fps; KUMM план 38 этап 2). Со слиянием модов у счётчика пропал
-- свой enabled.txt (заметки KrinikConanUI.md, «Open»). Выключен — число скрыто (Collapsed) и не пересчитывается; «Сохранить» в хабе показывает
-- или прячет его сразу, без нового HUD. [TESTED: 2026-10-31 · the corner without the number and «70» back after the hub's save · KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md]
local settings = require("krinik_settings")
local HIT_TEST_INVISIBLE, COLLAPSED = 3, 1
local function show(on)
    if text and text:IsValid() then text:SetVisibility(on and HIT_TEST_INVISIBLE or COLLAPSED) end
end
settings.on_change(function(changed)
    if changed.ui_fps ~= nil then
        local on = settings.get("ui_fps", true)
        show(on)
        last_frames = nil
        log("счётчик " .. (on and "включён" or "выключен") .. " (хаб)")
    end
end)

local HUD_CLASS_PATH = "/Game/Mods/UIMod_Hosav/W_NewHealthUI.W_NewHealthUI_C"
local ATTACH_DELAY_MS = 500   -- дерево виджета достраивается не в тот же кадр, что создание (KrinikHudOutline, 2026-10-29)
local pc_obj = nil

local function player_controller()
    if pc_obj and pc_obj:IsValid() then return pc_obj end
    pc_obj = FindFirstOf("PlayerController")
    if pc_obj and pc_obj:IsValid() then return pc_obj end
    pc_obj = nil
    return nil
end

NotifyOnNewObject(HUD_CLASS_PATH, function(hud)
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(ATTACH_DELAY_MS, function() pcall(function()
            if not hud:IsValid() then return end
            local name = hud:GetFName():ToString()
            if name:find("Default__", 1, true) or name == hud_name then return end
            hud_name = name
            last_frames = nil
            local ok, tb = pcall(attach, hud)
            text = ok and tb or nil
            show(settings.get("ui_fps", true))   -- новый HUD (после смерти, заход в мир) — по выключателю хаба
            if not ok then log("не смог поставить счётчик: " .. tostring(tb)) end
            if text then log("счётчик поставлен на HUD " .. name .. " (событие создания)") end
        end) end)
    end)
end)

LoopInGameThreadWithDelay(REFRESH_MS, function() pcall(function()   -- ошибка тела не останавливает цикл игрового потока
    if not text or not text:IsValid() or not libs() then return end
    if not settings.get("ui_fps", true) then return end
    local pc = player_controller()
    if not pc then return end
    local frames = ksl:GetFrameCount()
    local now = gps:GetRealTimeSeconds(pc)
    if last_frames and now > last_time then
        text:SetText(FText(("%d"):format(math.floor((frames - last_frames) / (now - last_time) + 0.5))))
    end
    last_frames, last_time = frames, now
end) end)
log(("загружен: жду %s событием создания, обновление числа раз в %d мс"):format(HUD_CLASS, REFRESH_MS))
