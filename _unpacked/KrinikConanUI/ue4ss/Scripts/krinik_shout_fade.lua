--[[
  KrinikConanUI:ShoutFade — крики врагов (игровые субтитры) появляются сразу на месте, проявляются за 0.2 с и за 0.2 с гаснут (KUMM план 36 W29).

  Слово владельца 2026-10-31 08:56: «должна сразу на месте появляться,можно с фейдом небольшим, типа 200мс, и такой же фейд на скрытие» ·
  «без всяких перемещений по экрану».

  Как устроено в игре (разведка 2026-10-31 09:1x, пульт; карта игры KUMM games/ConanExiles/GAME_ARCHITECTURE_INTERNAL_MAP.md):
  W_SubtitleRenderer_C (родной SubtitleRenderer): Overlay_0 → SizeBoxEntryListContainer (снизу по центру, ширина 1000, отступ снизу 140) →
  EntryListView (VerticalBox). На КАЖДУЮ фразу родной код создаёт новый W_SubtitleEntryView_C, в том же кадре зовёт его событие SetText, позже —
  SetTextActive(true); первый кадр новой строки рисуется со старой раскладкой списка — ниже места (владелец видел «приезжает снизу»). Убирает строку
  родной код без события (перехват Destruct молчит), срок — длина озвучки (0.9–1.75 с), конец заранее не прочитать.

  Поэтому строку показывает ЗЕРКАЛО: свой SizeBox в Overlay_0 рендерера с той же раскладкой, что у контейнера игры, в нём свой
  W_SubtitleEntryView_C (тот же шрифт и выравнивание). Игровая строка рождается с RenderOpacity 0 и такой остаётся. На SetTextActive(true) зеркало
  получает её текст и плавно проявляется; пока строка игры жива, раз в WATCH_MS проверяется, стоит ли она ещё в списке; ушла и новой нет —
  зеркало плавно гаснет. Зеркало не добавляется и не убирается на каждую фразу — раскладке нечего пересчитывать, прыжка нет.
  [AI] Проверка раз в WATCH_MS — только пока строка жива (≈ 1–2 с на крик): события «строку убрали» у игры нет, конец не известен заранее.
  Самозамер: сумма и худший вызов раз в минуту, только если были крики.
  [TESTED: 2026-10-31 · живая игра, крики босса оазиса, запись 60 к/с: «Чтоб тебя!» проявляется ≈ 10 кадров и гаснет ≈ 10 кадров на одном месте,
   «Не на того напал!» — с верной формой глагола · KUMM testcases/reports/2026-10-31_conan-shout-fade-in.md]
]]

local MOD = "KrinikConanUI:ShoutFade"
local ENTRY_NATIVE = "/Script/ConanSandbox.SubtitleEntryView"
local ENTRY_BP = "/Game/UI/HUD/W_SubtitleEntryView.W_SubtitleEntryView_C"
local SIZEBOX_CLASS = "/Script/UMG.SizeBox"
local WBL = "/Script/UMG.Default__WidgetBlueprintLibrary"
local FADE_S = 0.20                  -- «типа 200мс» — и появление, и скрытие
local STEP_MS = 15                   -- шаг прозрачности: ≈ кадр на 60 Гц; значение берётся по часам, не по числу шагов
local WATCH_MS = 50                  -- как часто проверять, стоит ли строка игры в списке (запаздывание начала скрытия ≤ 50 мс)
local SUMMARY_S = 60
-- Сколько фраза держится на экране самое меньшее, с: шкала «Сколько держится фраза врага» хаба (ключ ui_shout_hold); голос длиннее — строка живёт
-- до его конца. 1 с ≈ как в игре (голос 0.9–1.75 с). `[OWNER]` 2026-11-01 08:49 «я бы в мод UI криника вынес настройку времени задержки отображения
-- фраз на экране». Хранилище читается на каждом крике — поиск в таблице без цены.
-- [TESTED: 2026-11-01 · живая игра, крики босса оазиса: 1 с — 1.01–1.99 (длина голоса), 4 с — 4.00–4.01, 9.5 с — 9.50–9.51 и смена фразы на месте ·
--  KUMM testcases/reports/2026-11-01_conan-shout-hold-slider.md]
local settings = require("krinik_settings")
local HOLD_DEFAULT = 1.0

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local stats = { n = 0, sum = 0.0, worst = 0.0, shouts = 0, last = os.clock() }
local hooked = false
local mirrors = {}                   -- полное имя контейнера игры → { box, view, slot, op, target, tweening, current }

local function measure(t0)
    local dt = (os.clock() - t0) * 1000.0
    stats.n = stats.n + 1; stats.sum = stats.sum + dt; if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S then
        if stats.shouts > 0 then
            log("минута: криков %d, вызовов %d, всего %.3f мс, худший %.3f мс", stats.shouts, stats.n, stats.sum, stats.worst)
        end
        stats.n, stats.sum, stats.worst, stats.shouts, stats.last = 0, 0.0, 0.0, 0, os.clock()
    end
end

-- Прозрачность зеркала идёт к target со скоростью «полный ход за FADE_S»; цикл живёт, только пока не дошла.
local function tween(m)
    if m.tweening then return end
    m.tweening = true
    local prev = os.clock()
    local function step()
        local t0 = os.clock()
        local ok = pcall(function()
            if not valid(m.view) then m.tweening = false; return end
            local now = os.clock()
            local d = (now - prev) / FADE_S
            prev = now
            if m.op < m.target then m.op = math.min(m.target, m.op + d) else m.op = math.max(m.target, m.op - d) end
            m.view:SetRenderOpacity(m.op)
            if m.op == m.target then m.tweening = false; return end
            ExecuteInGameThreadWithDelay(STEP_MS, step)
        end)
        if not ok then m.tweening = false end
        measure(t0)
    end
    step()
end

-- Зеркало для рендерера, в чей контейнер встала строка игры: свой SizeBox рядом с контейнером, та же ширина и тот же слот.
local function mirror_for(container)
    local key = container:GetFullName()
    local m = mirrors[key]
    if m and valid(m.box) and valid(m.view) then return m end
    local overlay = container:GetParent()
    local outer = container:GetOuter()                -- WidgetTree рендерера
    local box = StaticConstructObject(StaticFindObject(SIZEBOX_CLASS), outer, FName("SizeBox_KrinikShoutMirror"))
    box:SetWidthOverride(container.WidthOverride)
    local slot = overlay:AddChildToOverlay(box)
    local pc = FindFirstOf("PlayerController")
    local view = StaticFindObject(WBL):Create(pc, StaticFindObject(ENTRY_BP), pc)
    box:SetContent(view)
    view:SetRenderOpacity(0.0)
    m = { box = box, view = view, slot = slot, op = 0.0, target = 0.0, tweening = false, current = nil }
    mirrors[key] = m
    log("зеркало построено: %s", box:GetFullName())
    return m
end

-- Раскладка зеркала = раскладка контейнера игры в этот момент (UpdateEntryListPosition рендерера может её менять).
local function sync_layout(m, container)
    local s = container.Slot
    local p = s.Padding
    m.slot:SetPadding({ Left = p.Left, Top = p.Top, Right = p.Right, Bottom = p.Bottom })
    m.slot:SetHorizontalAlignment(s.HorizontalAlignment)
    m.slot:SetVerticalAlignment(s.VerticalAlignment)
end

local function hide(m, line)
    if m.current ~= line then return end
    m.current = nil
    m.target = 0.0
    tween(m)
    log("фраза снята через %.2f с", os.clock() - m.shown)
end

local function hide_later(m, line, left)
    ExecuteInGameThreadWithDelay(math.floor(left * 1000 + 0.5), function()
        local t0 = os.clock()
        pcall(hide, m, line)
        measure(t0)
    end)
end

local function watch(m, line)
    ExecuteInGameThreadWithDelay(WATCH_MS, function()
        local t0 = os.clock()
        pcall(function()
            if m.current ~= line then return end    -- пришла новая строка — за ней следит её собственная проверка
            local alive = valid(line) and valid(line:GetParent())
            if alive then watch(m, line); return end
            -- голос смолк раньше срока шкалы — строка ждёт остаток; новая строка за это время сменит m.current, и это скрытие ничего не сделает
            local left = settings.get("ui_shout_hold", HOLD_DEFAULT) - (os.clock() - m.shown)
            if left > 0.02 then hide_later(m, line, left); return end
            hide(m, line)
        end)
        measure(t0)
    end)
end

local function on_active(line)
    local list = line:GetParent()                      -- EntryListView
    if not valid(list) then return end
    local container = list:GetParent()                 -- SizeBoxEntryListContainer
    if not valid(container) then return end
    local m = mirror_for(container)
    sync_layout(m, container)
    m.view:SetText(FText(line.TextView:GetText():ToString()))
    m.current = line
    m.shown = os.clock()
    m.target = 1.0
    stats.shouts = stats.shouts + 1
    tween(m)
    watch(m, line)
end

-- Перехват SetTextActive ставится на первой рождённой строке: класс W_SubtitleEntryView_C тогда точно загружен.
local function hook_once()
    if hooked then return end
    hooked = true
    local ok, err = pcall(RegisterHook, ENTRY_BP .. ":SetTextActive", function(ctx, active)
        local t0 = os.clock()
        local ok2, err2 = pcall(function()
            local line = ctx:get()
            if not active:get() then return end
            for _, m in pairs(mirrors) do if m.view == line then return end end   -- наше зеркало зовёт то же событие
            on_active(line)
        end)
        if not ok2 then log("ошибка: %s", tostring(err2)) end
        measure(t0)
    end)
    log("перехват SetTextActive: %s", ok and "стоит" or ("ОШИБКА " .. tostring(err)))
end

NotifyOnNewObject(ENTRY_NATIVE, function(entry)
    local t0 = os.clock()
    pcall(function()
        if not entry:GetFullName():find("Default__", 1, true) then
            entry.RenderOpacity = 0.0       -- строку игры не видно никогда: текст показывает зеркало
        end
    end)
    hook_once()
    measure(t0)
end)

log("загружен: крик на месте, проявление и скрытие по %.2f с, зеркальная строка", FADE_S)
