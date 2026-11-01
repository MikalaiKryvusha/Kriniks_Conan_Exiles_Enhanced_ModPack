--[[
  KrinikConanUI:ModSettings — the «Моды Krinik'а» settings hub (KUMM plan 38; phase 0 skeleton 2026-10-31 19:37, phase 2 — the window by the APPROVED
  mockup 5: `[OWNER]` «макет одобрен» · 2026-10-31 19:09; operational plan KUMM plans/38_epic38_phase2_krinik_hub_window.md).

  The window W_KrinikModSettings and its module table DT_KrinikUIModule come from _config/devkit/kit-krinik-modsettings.py — the kit places the
  widgets only (head, the mod list, one page per mod with rows «label + i + hint + the game's control», the footer, the «i» plate). This section:
    1. merges our table into the game's DT_UIModuleTable ONCE, at the main menu's birth (ModController CDO MergeDataTables — phase 0, proven);
    2. when our module opens: writes every text from SETTINGS below (title, buttons, mod names, labels, «i», hints), sets the slider ranges and
       every control to the STORED value (krinik_settings — <game>\ConanSandbox\Saved\KrinikSettings.lua), selects the first live mod;
    3. routes a real left click (RegisterKeyBind — UserWidget mouse events never fire here, EXP-0399; the «ОТЗЫВ» plate's route) to the hovered
       element: a mod name → its page; «i» → the explanation plate; «Сбросить к исходным» → the page's controls to the defaults (not saved);
       «Сохранить» → the store written, the sections told (krinik_settings.on_change); «Сохранить и закрыть»; «Закрыть без сохранения» → closed,
       the store untouched (the next opening reads the store again, so an unsaved change is gone);
    4. while the window is open ONLY: a 50 ms chain for the «i» hover and the marquee of a mod name that does not fit (`[OWNER]` 19:02 «как в
       радио бекущей строкой влево вправо»). The chain stops when the window is closed — nothing runs in play (criterion 7, house rule 7).
  A mod enters the list only when its rows apply (LIVE); the others wait for their mod's reader (plan step 6).
  [TESTED: 2026-10-31 · live game, real mouse: fill, page, «i», reset, save, save-and-close, the LMB bind silent while closed · KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md]
]]

local settings = require("krinik_settings")

local MOD = "KrinikConanUI:ModSettings"
local MAIN_TABLE = "/Game/UI/Data/DataTables/DT_UIModuleTable.DT_UIModuleTable"
local OUR_TABLE = "/Game/Mods/KrinikConanUI/DT_KrinikUIModule.DT_KrinikUIModule"
local MOD_CONTROLLER_CDO = "/Script/DreamworldMods.Default__ModController"
local ROW = "KrinikModSettings"
local WINDOW_CLASS = "W_KrinikModSettings_C"
local MENU_CLASS = "/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu.W_MainMenu_MainMenu_C"
local MERGE_DELAY_MS = 500    -- the menu's birth frame; the mods' controllers merged long before (frame 211, recon §1)
local OPEN_DELAY_MS = 100     -- the window is created inside ActivateModule; its tree is built by then
local WATCH_MS = 50           -- the «i» hover and the marquee, only while the window is open
local MARQUEE_PX = 1.2        -- units per watch step (≈ 24 units a second)
local MARQUEE_HOLD = 20       -- watch steps the name rests at each end (1 s)
local NAME_BOX = 258          -- the kit's NAME_W (a stale 268 here stopped the marquee: «KrinikConanGraphic» stood cut, 2026-10-31 22:12)
local SLIDER_BOX_W = 290      -- the slider control with its value box = the kit's CONTROL_SLIDER_W (340 squeezed the widest row's value to «3», 2026-10-31 22:01)
-- The «i» plate stands at the mouse, as the game's own tooltips do: a hover or a click on an «i» means the cursor IS on that «i». UE4SS hands Lua an
-- empty FGeometry (all zeros, 2026-10-31 22:0x), so a widget's place cannot be read; the old fixed X covered the row's own label (seam S5).
local TIP_DX, TIP_DY = -14, 22  -- below and slightly left of the cursor, canvas units
local TIP_EDGE = 12             -- the plate keeps this far from the screen edge (Svarog UI_RULEBOOK В6)

-- Every text of the window and every row: ONE table (labels and «i» — KUMM researches/conan-mod-settings-hub/krinik-settings-inventory.md).
-- kind: check (value boolean) | slider (value number; min, max, step; scale — the factor the slider SHOWS, digits — fraction digits shown).
local TITLE = "МОДЫ KRINIK'А · НАСТРОЙКИ"   -- `[OWNER]` the form «Моды Krinik'а» · 2026-10-31 19:10; capitals as in mockup 5 (approved 19:09)
local BUTTONS = { B_KrinikClose = "Закрыть без сохранения", B_KrinikReset = "Сбросить к исходным", B_KrinikSave = "Сохранить",
                  B_KrinikSaveClose = "Сохранить и закрыть" }   -- `[OWNER]` 19:06
local PAGES = {
    -- own: the camera keeps its values in its OWN config.lua (it also writes them from the numpad) — the window reads them from the camera's
    -- shared «KrinikCameraValues» and hands a save over as «KrinikCameraSet», never through the store (one place per fact)
    { key = "cam", name = "KrinikConanCamera", note = "камера", own = "KrinikCamera", rows = {
        { id = "cam_height", kind = "slider", default = 75, min = 0, max = 200, step = 5, hint = "в сантиметрах",
          label = "Высота камеры", info = "Насколько выше героя висит камера." },
        { id = "cam_side", kind = "slider", default = 0, min = -100, max = 100, step = 5, hint = "вправо или влево",
          label = "Сдвиг камеры вбок", info = "При нуле камера стоит строго за спиной героя, сдвиг вправо или влево даёт вид из-за плеча." },
        { id = "cam_dist", kind = "slider", default = 315, min = 150, max = 800, step = 5, hint = "в сантиметрах",
          label = "Расстояние до героя", info = "Расстояние, которое ставят клавиши «+» и «−» цифрового блока; колесо мыши приближает и отдаляет камеру как обычно." },
        { id = "cam_pitch", kind = "slider", default = -2, min = -15, max = 15, step = 1, hint = "в градусах",
          label = "Наклон взгляда", info = "Наклоняет камеру вверх или вниз, не сдвигая её; ноль — как в игре без мода." },
        { id = "cam_zoom_min", kind = "slider", default = 130, min = 30, max = 400, step = 10, hint = "колесо мыши",
          label = "Ближе всего к герою", info = "Самое близкое расстояние колеса мыши; ещё ближе камера переходит к виду от первого лица." },
        { id = "cam_zoom_max", kind = "slider", default = 2125, min = 500, max = 3000, step = 25, hint = "колесо мыши",
          label = "Дальше всего от героя", info = "Самое дальнее расстояние, на которое колесо мыши отводит камеру." },
        { id = "cam_sharp", kind = "check", default = false,
          label = "Резкий зум", info = "Включено — колесо переставляет камеру сразу; выключено — камера доезжает плавно." },
        { id = "cam_zoom_smooth", kind = "slider", default = 9, min = 1, max = 20, step = 1, hint = "больше — быстрее",
          label = "Плавность зума", info = "Как быстро камера доезжает до нового расстояния после щелчка колеса." },
    } },
    { key = "ui", name = "KrinikConanUI", note = "интерфейс сборки", rows = {
        { id = "ui_fps", kind = "check", default = true,
          label = "Счётчик кадров в углу экрана", info = "Показывает в правом верхнем углу, сколько кадров в секунду рисует игра." },
        { id = "ui_blink_food", kind = "slider", default = 0.10, min = 0.05, max = 0.50, step = 0.05, scale = 100, unit = " %", hint = "с какого запаса",
          label = "Мигание еды и воды", info = "Когда еды или воды остаётся меньше этой доли, значок начинает тускло мигать; к нулю мигание набирает полную яркость." },
        { id = "ui_blink_weight", kind = "slider", default = 0.90, min = 0.50, max = 0.95, step = 0.05, scale = 100, unit = " %", hint = "с какой нагрузки",
          label = "Мигание веса", info = "Когда ноша доходит до этой доли предела, значок веса начинает мигать." },
        { id = "ui_menu_slow", kind = "slider", default = 1 / 0.03, min = 1, max = 50, step = 1, hint = "во сколько раз",
          label = "Мир замедляется в меню", info = "Пока открыты инвентарь, сундук или станция, мир идёт медленнее: голод, жажда и враги ждут героя. Шкала задаёт, во сколько раз медленнее; 1 — мир не замедляется." },
        { id = "ui_craft", kind = "check", default = true,
          label = "Крафт в меню без замедления", info = "Пока мир в меню почти стоит, вещи, которые изготавливает герой, готовятся за обычное время." },
    } },
    { key = "arc", name = "KrinikConanArchery", note = "лук и стрелы", rows = {
        { id = "arc_ballistics", kind = "check", default = true,
          label = "Полёт стрелы как в Oblivion", info = "Чем сильнее натянута тетива, тем быстрее летит стрела; поправку на дугу берёт на себя стрелок." },
        { id = "arc_nobreak", kind = "check", default = true,
          label = "Стрелы не ломаются", info = "Стрела не ломается при попадании и остаётся торчать в цели." },
        { id = "arc_fov", kind = "slider", default = 75, min = 40, max = 90, step = 1, hint = "в градусах",
          label = "Обзор при прицеливании", info = "Насколько приближается вид, когда герой целится из лука правой кнопкой мыши." },
    } },
    { key = "mpm", name = "KrinikConanModPackManager", note = "сборка", rows = {
        { id = "mpm_hud_scale", kind = "slider", default = 1.25, min = 1.0, max = 1.5, step = 0.05, scale = 100, unit = " %", hint = "в процентах",
          label = "Размер HUD вверху экрана", info = "Увеличивает блок здоровья, выносливости и запасов вверху экрана, не трогая остальной интерфейс." },
    } },
    { key = "gfx", name = "KrinikConanGraphics", note = "графика", rows = {
        { id = "gfx_blood", kind = "slider", default = 300, min = 10, max = 600, step = 10, hint = "в секундах",
          label = "Сколько лежит кровь на земле", info = "Сколько пятна крови после боя остаются на земле, прежде чем исчезнуть." },
    } },
}
-- A mod's page is shown only when its values APPLY (plan step 6); the UI sections share this Lua state and read the store directly.
-- arc: KrinikConanArchery reads arc_* at load and on the shared version (per arrow, per aim); gfx: KrinikConanGraphics reads gfx_blood at load and
-- on the shared version (its main.lua); mpm: KrinikConanModPackManager reads mpm_hud_scale at load and on the shared version when a game window closes;
-- cam: set at every opening — live only while KrinikConanCamera has published its values
local LIVE = { ui = true, gfx = true, arc = true, mpm = true }

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end
local function str(n) return type(n) == "string" and n or (n and n.ToString and n:ToString()) or tostring(n) end

-- ---- 1. the module table merge (phase 0) ----------------------------------------------------------------------------------------------
local merged = false

local function count_rows(dt)
    local n, has = 0, false
    dt:ForEachRow(function(name, _)
        n = n + 1
        if str(name) == ROW then has = true end
    end)
    return n, has
end

local function merge(why)
    if merged then return end
    local t0 = os.clock()
    local main = StaticFindObject(MAIN_TABLE)
    if not valid(main) then log("merge (%s): %s not loaded yet", why, MAIN_TABLE); return end
    local ours = StaticFindObject(OUR_TABLE)
    if not valid(ours) then ours = LoadAsset(OUR_TABLE) end   -- the FULL object path «Pkg.Obj»: the package path alone returns nil (2026-10-31 19:30)
    if not valid(ours) then log("merge (%s): our table %s not found", why, OUR_TABLE); return end
    local mc = StaticFindObject(MOD_CONTROLLER_CDO)
    if not valid(mc) then log("merge (%s): %s not found", why, MOD_CONTROLLER_CDO); return end
    local n0, h0 = count_rows(main)
    local ok, err = pcall(function() mc:MergeDataTables(main, ours) end)
    local n1, h1 = count_rows(main)
    merged = h1
    log("merge (%s): call %s%s; rows %d -> %d; %s present %s -> %s; %.2f ms", why, ok and "ok" or "FAILED", ok and "" or (" " .. tostring(err)),
        n0, n1, ROW, tostring(h0), tostring(h1), (os.clock() - t0) * 1000)
end

NotifyOnNewObject(MENU_CLASS, function(m)
    if merged or m:GetFullName():find("Default__", 1, true) then return end
    ExecuteInGameThreadWithDelay(MERGE_DELAY_MS, function() merge("main menu") end)
end)

-- ---- 2. the open window ---------------------------------------------------------------------------------------------------------------
local win = nil          -- the live window while open; nil — the LMB bind returns at once
local page = nil         -- the selected page entry of PAGES
local tip_row = nil      -- the row whose «i» plate is shown
local tip_pinned = false -- shown by a click (stays) or by the hover (goes when the mouse leaves)
local marquee = {}       -- key → { box, overflow, offset, dir, hold }

local function child(name)
    local w = win:GetWidgetFromName(FName(name))
    return valid(w) and w or nil
end

local function set_text(name, s)
    local t = child(name)
    if t then t:SetText(FText(s)) end
    return t
end

local function control(row)
    return child(row.id == "ui_fps" and "Chk_KrinikFps" or ((row.kind == "slider" and "Sl_Krinik_" or "Chk_Krinik_") .. row.id))
end

local function shown_value(row, v)
    return v * (row.scale or 1)
end

local function set_control(row, v)
    local c = control(row)
    if not c then log("row %s: control not found", row.id); return end
    -- native signatures read live 2026-10-31 20:44: SetIsToggledOn(NewIsToggledOn, ShouldBroadcast, IsInstantTransition), SetValue(RealValue, IsInitializing)
    -- the game row's own label box (SizeBoxSettingName, 350 wide) took the row's width and squeezed the control to a dot (frame 2026-10-31 20:47):
    -- our label stands left of the row, so the game's box is collapsed
    if c.SizeBoxSettingName and c.SizeBoxSettingName:IsValid() then c.SizeBoxSettingName:SetVisibility(1) end
    if row.kind == "check" then
        c:SetIsToggledOn(v and true or false, false, true)
    else
        local s = row.scale or 1
        local whole = math.abs(row.step * s - math.floor(row.step * s + 0.5)) < 1e-6
        c.MinFractionalDigits, c.MaxFractionalDigits = 0, whole and 0 or 2   -- «10», not «10,00»
        c.MinValue, c.MaxValue, c.StepValue = row.min * s, row.max * s, row.step * s
        pcall(function() c:UpdateSliderStepSize() end)
        c:SetValue(shown_value(row, v), true)
    end
end

local function read_control(row)
    local c = control(row)
    if not c then return nil end
    if row.kind == "check" then return c:GetIsToggledOn() and true or false end
    -- on the row's step: the game slider hands back float noise (120 came as 120.00000762939 into the camera's config.lua, 2026-10-31 22:30)
    local s = row.scale or 1
    local q = row.step * s
    return math.floor(c:GetValue() / q + 0.5) * q / s
end

local function select_page(p)
    page = p
    for i, q in ipairs(PAGES) do
        local item = child("Brd_KrinikMod_" .. q.key)
        if item then item:SetBrushColor({ R = 1.0, G = 1.0, B = 1.0, A = (q == p) and 0.07 or 0.0 }) end
        if q == p then
            local sw = child("WS_KrinikPages")
            if sw then sw:SetActiveWidgetIndex(i - 1) end
        end
    end
    set_text("Txt_KrinikModTitle", p.name)
    set_text("Txt_KrinikModNote", p.note)
    log("page %s", p.key)
end

local function hide_tip()
    local tip = child("Brd_KrinikTip")
    if tip then tip:SetVisibility(1) end   -- Collapsed
    tip_row, tip_pinned = nil, false
end

local function show_tip(row, index)
    local tip = child("Brd_KrinikTip")
    if not tip then return end
    set_text("Txt_KrinikTipTitle", row.label)
    set_text("Txt_KrinikTipBody", row.info)
    local slot = tip.Slot
    if valid(slot) then pcall(function()
        -- the cursor in canvas units (GetMousePositionOnViewport divides by the DPI scale); the plate's size after a prepass, kept on screen
        local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local m = wll:GetMousePositionOnViewport(win)
        local vp, sc = wll:GetViewportSize(win), wll:GetViewportScale(win)
        tip:ForceLayoutPrepass()
        local sz = tip:GetDesiredSize()
        local x = math.max(TIP_EDGE, math.min(m.X + TIP_DX, vp.X / sc - sz.X - TIP_EDGE))
        local y = m.Y + TIP_DY
        if y + sz.Y > vp.Y / sc - TIP_EDGE then y = m.Y - TIP_DY - sz.Y end   -- no room below: above the cursor
        slot:SetPosition({ X = x, Y = y })
    end) end
    tip:SetVisibility(3)   -- HitTestInvisible: the plate never takes the click meant for what is under it
    tip_row = row
end

-- the camera's published values «cam_height=75.0;cam_side=0.0;…» → { cam_height = 75, … }; nil when the camera has published nothing
local function camera_values()
    local ok, s = pcall(function() return ModRef:GetSharedVariable("KrinikCameraValues") end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local t = {}
    for id, v in s:gmatch("([%w_]+)=([^;]+)") do
        if v == "true" or v == "false" then t[id] = (v == "true") else t[id] = tonumber(v) end
    end
    return t
end

local function fill_window()
    local cam = camera_values()
    LIVE.cam = cam ~= nil
    set_text("Txt_KrinikTitle", TITLE)
    for name, label in pairs(BUTTONS) do
        local b = child(name)
        if b then pcall(function() b:SetLabel(FText(label)) end) end
    end
    marquee = {}
    local first = nil
    for _, p in ipairs(PAGES) do
        local item = child("Brd_KrinikMod_" .. p.key)
        if item then item:SetVisibility(LIVE[p.key] and 0 or 1) end   -- Visible (hit-testable) | Collapsed
        local name = set_text("Txt_KrinikModName_" .. p.key, p.name)
        if LIVE[p.key] then
            first = first or p
            local box = child("SC_KrinikModName_" .. p.key)
            if box and name then marquee[p.key] = { box = box, text = name, offset = 0, dir = 1, hold = MARQUEE_HOLD } end
        end
        for _, row in ipairs(p.rows) do
            set_text("Txt_KrinikLbl_" .. row.id, row.label)
            set_text("Txt_KrinikInfo_" .. row.id, "i")
            set_text("Txt_KrinikHint_" .. row.id, row.hint or "")
            -- the kit's 420 overflowed the longest row («Мир замедляется в меню» + hint): the value box was cut to «3» of «33» (frame 20:55)
            local box = child("SB_KrinikCtl_" .. row.id)
            if box and row.kind == "slider" then box:SetWidthOverride(SLIDER_BOX_W) end
            local c = control(row)
            if c and c.TextSettingName and valid(c.TextSettingName) then c.TextSettingName:SetText(FText("")) end
            local v
            if p.own == "KrinikCamera" then
                v = cam and cam[row.id]
                if v == nil then v = row.default end
            else
                v = settings.get(row.id, row.default)
            end
            set_control(row, v)
        end
    end
    hide_tip()
    -- the window's height = the tallest LIVE page (the kit leaves the height to the content): a page switch never resizes the window, and a short
    -- list leaves no empty half (seam S1, the owner 21:41 «огромный»; Svarog UI_RULEBOOK В2 and К2). A widget switcher measures only its active page.
    local frame, sw = child("SB_KrinikWindow"), child("WS_KrinikPages")
    if frame and sw then
        frame:ClearHeightOverride()
        local tallest = 0
        for i, p in ipairs(PAGES) do
            if LIVE[p.key] then
                sw:SetActiveWidgetIndex(i - 1)
                frame:ForceLayoutPrepass()
                tallest = math.max(tallest, frame:GetDesiredSize().Y)
            end
        end
        if tallest > 0 then frame:SetHeightOverride(tallest) end
        log("window height %.0f (the tallest live page)", tallest)
    end
    if first then select_page(first) end
end

-- ---- 3. clicks --------------------------------------------------------------------------------------------------------------------------
local function close_window(why)
    hide_tip()          -- before win = nil: hide_tip reads the window (run 4, 20:56 — «attempt to index a nil value (upvalue 'win')», the window stayed open)
    local w = win
    win = nil
    if valid(w) then
        local ok = pcall(function() w:TryCloseWindow() end)
        log("closed (%s)%s", why, ok and "" or " — TryCloseWindow failed")
    end
end

local function save()
    local changes = {}
    for _, p in ipairs(PAGES) do
        if LIVE[p.key] and p.own == "KrinikCamera" then
            -- the whole camera page as one set; the camera takes it when a game window closes (its main.lua, hub_take_set) and writes its config.lua.
            -- Only when a camera row differs from the camera's own values: a save on another page must not rewrite the camera's file (it did, 22:45).
            local parts, now, differs = {}, camera_values() or {}, false
            for _, row in ipairs(p.rows) do
                local v = read_control(row)
                if v ~= nil then
                    parts[#parts + 1] = row.id .. "=" .. tostring(v)
                    local c = now[row.id]
                    if row.kind == "check" then
                        if v ~= c then differs = true end
                    elseif type(c) ~= "number" or math.abs(v - c) >= (row.step or 1) * 0.5 then
                        differs = true
                    end
                end
            end
            local set = differs and table.concat(parts, ";") or ""
            pcall(function() ModRef:SetSharedVariable("KrinikCameraSet", set) end)
            log(differs and "camera set handed over: %s" or "camera page unchanged — nothing handed over%s", set)
        elseif LIVE[p.key] then
            for _, row in ipairs(p.rows) do
                local v = read_control(row)
                if v ~= nil then
                    -- the default is not written: the file keeps only what the player changed (a mod update with a new default still reaches him)
                    -- if/else, not `a and b or c`: with b == false Lua takes c — a check row fell into the slider arithmetic (run 2, 20:51)
                    local same
                    if row.kind == "check" then same = (v == row.default)
                    else same = math.abs(v - row.default) < (row.step or 1) * 0.5 end
                    changes[row.id] = same and settings.DEFAULT or v
                end
            end
        end
    end
    settings.save(changes)
end

local function reset_page()
    for _, row in ipairs(page and page.rows or {}) do set_control(row, row.default) end
    log("page %s reset to defaults (not saved)", page and page.key or "?")
end

local function hovered(name)
    local w = child(name)
    return w ~= nil and w:IsHovered()
end

local function on_click()
    if not win then return end
    if not valid(win) or not win:IsVisible() then win = nil; return end
    if hovered("B_KrinikClose") then close_window("без сохранения"); return end
    if hovered("B_KrinikSave") then save(); return end
    if hovered("B_KrinikSaveClose") then save(); close_window("сохранено"); return end
    if hovered("B_KrinikReset") then reset_page(); return end
    for _, p in ipairs(PAGES) do
        if LIVE[p.key] and p ~= page and hovered("Brd_KrinikMod_" .. p.key) then hide_tip(); select_page(p); return end
    end
    for i, row in ipairs(page and page.rows or {}) do
        if hovered("Brd_KrinikInfo_" .. row.id) then
            -- a click pins the plate (it stays when the mouse leaves); a click on a pinned plate's «i» unpins and hides it
            if tip_row == row and tip_pinned then hide_tip() else show_tip(row, i - 1); tip_pinned = true end
            log("click: «i» %s %s", row.id, tip_pinned and "pinned" or "hidden")
            return
        end
    end
end
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
    if not win then return end            -- play: one boolean (criterion 7)
    -- the evidence line: a click on «Сохранить» did not route in run 1 (2026-10-31 20:48) though the button reads hovered — does the bind fire at all?
    log("LMB (window open)")
    ExecuteInGameThread(function()
        local ok, err = pcall(on_click)
        if not ok then log("click failed: %s", tostring(err)) end
    end)
end)

-- ---- 4. while open: the «i» hover and the marquee -------------------------------------------------------------------------------------
local function watch(w)
    ExecuteInGameThreadWithDelay(WATCH_MS, function()
        if win ~= w or not valid(w) or not w:IsVisible() then
            if win == w then win = nil end
            log("watch stopped (window closed)")
            return
        end
        pcall(function()
            -- «i»: hover shows, leaving hides (a click pins and unpins the same plate)
            local over = nil
            for i, row in ipairs(page and page.rows or {}) do
                if hovered("Brd_KrinikInfo_" .. row.id) then over = { row, i - 1 }; break end
            end
            if over and tip_row ~= over[1] then show_tip(over[1], over[2]); tip_pinned = false
            elseif not over and tip_row and not tip_pinned then hide_tip() end
            -- the marquee: a name wider than its box slides to its end and back, resting a second at each end
            for _, m in pairs(marquee) do
                local width = m.text:GetDesiredSize().X
                local span = width - NAME_BOX
                if span > 1 then
                    if m.hold > 0 then m.hold = m.hold - 1
                    else
                        m.offset = m.offset + m.dir * MARQUEE_PX
                        if m.offset >= span then m.offset, m.dir, m.hold = span, -1, MARQUEE_HOLD
                        elseif m.offset <= 0 then m.offset, m.dir, m.hold = 0, 1, MARQUEE_HOLD end
                        m.box:SetScrollOffset(m.offset)
                    end
                end
            end
        end)
        watch(w)
    end)
end

RegisterHook("/Script/ConanSandbox.GUIModuleController:ActivateModule", function(_, name, activate)
    local ok, n, on = pcall(function() return str(name:get()), activate:get() end)
    if not ok or n ~= ROW or not on then return end
    ExecuteInGameThreadWithDelay(OPEN_DELAY_MS, function()
        for _, w in ipairs(FindAllOf(WINDOW_CLASS) or {}) do
            if valid(w) and not w:GetFullName():find("Default__", 1, true) and w:IsVisible() then
                win = w
                local t0 = os.clock()
                local okf, err = pcall(fill_window)
                log("window %s opened: filled %s%s in %.2f ms", w:GetFName():ToString(), okf and "ok" or "FAILED ", okf and "" or tostring(err),
                    (os.clock() - t0) * 1000)
                watch(w)
                return
            end
        end
        log("module opened, but no visible %s found", WINDOW_CLASS)
    end)
end)

-- every toggle of a settings checkbox inside our window — the evidence a real click reached the game's row (phase 0's proof, kept for the tests)
RegisterHook("/Script/ConanSandbox.SettingsCheckboxWidgetBase:HandleCheckboxToggled", function() end, function(self)
    local w = self:get()
    if not valid(w) or not w:GetFullName():find("W_KrinikModSettings", 1, true) then return end
    log("checkbox %s toggled → %s", w:GetFName():ToString(), tostring(w:GetIsToggledOn()))
end)

log("loaded: merge at the main menu, window filled at opening from %s, LMB routed only while open", settings.PATH)
