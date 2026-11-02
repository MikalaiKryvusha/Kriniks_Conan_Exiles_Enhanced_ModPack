--[[
  KrinikConanUI:MinimapCoords — координаты мини-карты Simple Minimap внутри круга, на простой тёмной подложке (KUMM план 36 W4, баг 64 пункт 31).

  Слово владельца 2026-10-27 ≈00:1x, со снимком: «в миникарте коардинаты нужно будет переместить внутрь круга, сделать им подложку».
  Выбор вида 2026-10-31 09:54 (папка на отсмотр 26, варианты А и Б): «простая демная подложка, шрифт коардинат больше, плашку выше».

  Как устроено у мода (пульт, 2026-10-31 09:4x; конспект KUMM games/ConanExiles/mods/Simple_Minimap.md): SM_UI_Minimap_C → MinimapScale →
  MinimapOverlay; в нём Coordinates (TextBlock, кегль 10, слот по центру сверху, отступ 0) — строка висит над красным кольцом, без подложки.
  Подложку правкой свойств пака не добавить (новый виджет в дереве), поэтому — раз при рождении карты, без опроса: свой Border с тёмной
  полупрозрачной заливкой → Coordinates кеглем часов (ServerTime, 15); слот — по центру снизу, BOTTOM_INSET от низа круга (с 2026-11-01 15:2x).
  Если мод прячет координаты (bShowCoordinates), подложка прячется вместе с ними — видимость берётся у Coordinates при сборке.
  [NOT-TESTED]
]]

local MOD = "KrinikConanUI:MinimapCoords"
local MINIMAP = "/Game/Mods/Simple_Minimap/UI/SM_UI_Minimap.SM_UI_Minimap_C"
local BORDER = "/Script/UMG.Border"
local ATTACH_DELAY_MS = 600          -- дерево виджета достраивается не в тот же кадр, что создание (как у раздела обводки HUD)
-- ВНИЗУ круга, рядом с часами и кнопками зума (`[OWNER]` 2026-11-01 15:18 «давай в миникарте виджет коардинат вниз сдвинем, там и так время, кнопки
-- зума - там им место»); до этого плашка стояла сверху, отступ 46 (вкус 2026-10-31 10:07). Отступ — от низа круга вверх, над плашкой часов.
local BOTTOM_INSET = 52.0               -- 46 касался плашки часов и кольца (кадр 15:23, 4K) → 60; `[OWNER]` 2026-11-01 20:46 «коардинаты на миникарте ниже» → 52 (зазор до часов ≈ 30 → ≈ 14 px на 4K)
local BACKING = { R = 0.0, G = 0.0, B = 0.0, A = 0.55 }   -- «простая демная подложка» — вариант А папки 26
local PAD = { Left = 4.0, Top = 0.0, Right = 4.0, Bottom = 0.0 }   -- «чтобы текст коардинат был тесно в плашке» (10:00)
local FONT_SIZE = 13                 -- «шрифт коардинат больше» (10 → 15), «меньше шрифт» (09:59) → 12, «чуть больше … на один пункт» (10:07) → 13
local CORNER = 6.0                   -- радиус скругления плашки, единицы виджета (кадр 09:58 при 1080p)
-- «и карту я просил выше и правее» · «засунуть ее плотнее в угол» (10:01). Место слота мод считает сам (LoadSettings: половина размера × 0.52 от
-- угла), а слот, вылезший за край экрана, рисуется СЖАТЫМ (опыт 09:51 и 09:58) — поэтому сдвиг только отрисовкой: RenderTranslation не трогает
-- раскладку. Кадр 10:01 при 1080p: (22, −20) по замеру 10:1x было 2–3 px справа и 5 сверху — «вплотную»; ниже — 4 px.
-- «типа 4 пекселя от верха и от права» (10:13), затем «может увеличить до 8 пкс» (10:25): (16, −16.3) — 1080p, кольцо ровно в 8 px от верха и от правого края
-- (замер 10:2x); `[OWNER]` 2026-11-01 20:48 «миникарту чуть-чуть дальше от правого края и от верха» → на 6 единиц дальше: 14 px при 1080p. Единицы
-- интерфейса — на 4K отступ вдвое больше в пикселях. [TESTED: 2026-11-01 21:03 · кадр 4K: сверху 48, справа 44 px · KUMM testcases/reports/2026-11-01_conan-logo-tone-minimap.md]
local CORNER_SHIFT = { X = 10.0, Y = -10.3 }

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end

local function rebuild(map)
    local t0 = os.clock()
    local coords = map.Coordinates
    if not valid(coords) then log("Coordinates не найден"); return end
    if valid(map.MinimapScale) then map.MinimapScale:SetRenderTranslation(CORNER_SHIFT) end
    local overlay = coords:GetParent()
    if not valid(overlay) or overlay:GetFName():ToString() ~= "MinimapOverlay" then return end   -- уже перенесены
    local backing = StaticConstructObject(StaticFindObject(BORDER), map.WidgetTree, FName("Border_KrinikCoords"))
    local brush = backing.Background                  -- «можешь углы скруглить у плашки» (09:58): RoundedBox, радиус CORNER
    brush.DrawAs = 4                                  -- ESlateBrushDrawType::RoundedBox
    brush.OutlineSettings.CornerRadii = { X = CORNER, Y = CORNER, Z = CORNER, W = CORNER }
    brush.OutlineSettings.RoundingType = 0            -- FixedRadius
    backing:SetBrush(brush)
    backing:SetBrushColor(BACKING)
    backing:SetPadding(PAD)
    local vis = coords:GetVisibility()
    coords:RemoveFromParent()
    local slot = overlay:AddChildToOverlay(backing)
    slot:SetHorizontalAlignment(2)                    -- по центру
    slot:SetVerticalAlignment(3)                      -- снизу (EVerticalAlignment: 1 сверху, 3 снизу)
    slot:SetPadding({ Left = 0.0, Top = 0.0, Right = 0.0, Bottom = BOTTOM_INSET })
    backing:SetContent(coords)
    local f = coords.Font
    f.Size = FONT_SIZE
    coords:SetFont(f)
    if vis == 1 or vis == 2 then backing:SetVisibility(vis) end
    log("координаты внутри круга снизу, на тёмной подложке (%.3f мс)", (os.clock() - t0) * 1000.0)
end

NotifyOnNewObject(MINIMAP, function(map)
    if map:GetFullName():find("Default__", 1, true) then return end
    ExecuteInGameThread(function()
        ExecuteInGameThreadWithDelay(ATTACH_DELAY_MS, function()
            local ok, err = pcall(rebuild, map)
            if not ok then log("ошибка: %s", tostring(err)) end
        end)
    end)
end)

log("загружен: координаты мини-карты внутри круга снизу, отступ %.0f, кегль %d", BOTTOM_INSET, FONT_SIZE)
