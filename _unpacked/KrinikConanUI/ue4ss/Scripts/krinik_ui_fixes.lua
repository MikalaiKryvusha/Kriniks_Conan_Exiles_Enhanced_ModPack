--[==[===========================================================================
  KrinikUIFixes (Lua half) 1.3.0 — the corpse strip follows the quick-loot window; button key glyphs keep their width from the first frame.
  KUMM bugs/64 items 32 and 35. The owner's ask: `[OWNER]` «если открывается этот виджет быстрого лута, то подсказку над трупом -
  нужно на экране двигать левее» (2026-10-27).

  WHY LUA. `WBP_ContainerInfo` puts the strip (`OverlaySlot_5`) and the quick-loot window (`OverlaySlot_3`) into one overlay that spans
  the whole screen; the window is hidden by native code with Hidden (it keeps no say in the layout, the overlay is full-width anyway).
  A layout constant cannot tell "window shown" from "window hidden": Left pins the strip to the screen edge on every corpse without
  loot (cases P1–P5 and the kappa frame of KUMM testcases/TC_conan_loot_panel_hidden_and_hold_prompt_2026-10-28.md). The pak keeps the
  vanilla Center; this script sets Left while the window shows loot and Center otherwise (`HOUSE_RULES.md` rule 8: Lua only when the
  asset will not yield — once, no polling).

  EVENTS. Two post-hooks: the blueprint `WBP_ContainerInfo_C:SetObject` (a new target; registered when the widget is first created) and
  the native `QuickLootPanel:SlotItemAddedOrRemoved` (loot changed; registered at load). The second was found by counters on nine
  candidates around a REAL Q hold (2026-10-29 00:2x): only it fired; the blueprint `HandleInventoryChanged` /
  `HandleLootContainerInventoryChanged` stay silent on a corpse. Each event re-reads the window's visibility on the spot and once more
  one game-thread tick later (native code may hide the window after the slot). No timers, no scene searches.

  COST. Self-measured: the sum and the worst handler time, logged at most once a minute, only when events happened.
  Off switch — delete enabled.txt.
  [NOT-TESTED]
===========================================================================]==]

local MOD = "KrinikConanUI:UIFixes"   -- until 2026-10-30 the separate mod KrinikUIFixes
local WIDGET_CLASS = "/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo.WBP_ContainerInfo_C"
local WIDGET_EVENT = WIDGET_CLASS .. ":SetObject"
local LOOT_EVENT = "/Script/ConanSandbox.QuickLootPanel:SlotItemAddedOrRemoved"
local STRIP = "Border_Underlay"      -- content of OverlaySlot_5 (name, «Труп», action tutorial)
local PANEL = "W_QuickLootPanel"     -- content of OverlaySlot_3
-- EHorizontalAlignment values as UMG stores them: HAlign_Fill 0, HAlign_Left 1, HAlign_Center 2, HAlign_Right 3 (the pult set 2 → centred,
-- 2026-10-29 00:05; the kit report printed H_ALIGN_LEFT: 1).
local ALIGN = { left = 1, center = 2 }
local SHOWN = { [0] = true, [3] = true, [4] = true }   -- Visible, HitTestInvisible, SelfHitTestInvisible
local RECHECK_MS = 50                 -- one game-thread tick later: native code may update the window after the blueprint handler
local SUMMARY_S = 60

local stats = { n = 0, sum = 0.0, worst = 0.0, last = os.clock(), changes = 0 }

local function log(fmt, ...)
    print(string.format("[%s] " .. fmt .. "\n", MOD, ...))
end

-- The strip's place on screen — the hub rows «Плашка трупа: по горизонтали / по высоте», a SHIFT in % of the screen from the game's own place, by
-- default left of the hero in third person (`[OWNER]` 2026-11-02 08:57 «дать настройку их положения на экране через наши настройки модов? По высоте и
-- по горизонтали?» · «по умолчанию сделать их в левой части экрана, чтобы в виде от третьего лица они не поверх героя были, а левее героя»). A RENDER
-- translation: the layout and the Left-while-loot alignment above stay as they are; the horizontal shift applies only while the strip is centred
-- (with the loot window it already stands at the left edge). [NOT-TESTED]
local settings = require("krinik_settings")
local STRIP_X_DEFAULT, STRIP_Y_DEFAULT = -22, 0   -- % of the screen width / height (−15 left the strip over the hero's head, frame s2f 10:40); the hub's defaults are the same numbers
local STRIP_SCALE_DEFAULT, STRIP_BACK_DEFAULT = 0.70, 0.60   -- the owner 10:54: 30 % smaller, backing 60 %
local function place_strip(ci, strip, centred)
    local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    local vp, sc = wll:GetViewportSize(ci), wll:GetViewportScale(ci)
    if not (sc and sc > 0) then return end
    local x = centred and settings.get("ui_strip_x", STRIP_X_DEFAULT) or 0
    local y = settings.get("ui_strip_y", STRIP_Y_DEFAULT)
    local want = { X = x / 100 * vp.X / sc, Y = y / 100 * vp.Y / sc }
    local t = strip.RenderTransform.Translation
    if math.abs(t.X - want.X) > 0.5 or math.abs(t.Y - want.Y) > 0.5 then strip:SetRenderTranslation(want) end
    -- size and backing: the hub rows «Плашка трупа: размер / фон» (`[OWNER]` 2026-11-02 10:54 «фон 60, меньше на» · «30» · «даем это настройкой в моде UI
    -- криника»); the kit pak ships the same defaults (kit-conanui-edit.py STRIP_SCALE / STRIP_BACKING_ALPHA), these apply the player's choice. [NOT-TESTED]
    local k = settings.get("ui_strip_scale", STRIP_SCALE_DEFAULT)
    local s = strip.RenderTransform.Scale
    if math.abs(s.X - k) > 0.001 then strip:SetRenderScale({ X = k, Y = k }) end
    local a = settings.get("ui_strip_back", STRIP_BACK_DEFAULT)
    local bc = strip.BrushColor
    if math.abs(bc.A - a) > 0.001 then strip:SetBrushColor({ R = bc.R, G = bc.G, B = bc.B, A = a }) end
end

-- 1.5.0 — EVERY interaction prompt stands and looks like the corpse strip (KUMM bugs/83; `[OWNER]` 2026-11-03 23:30 «я просил все виджеты интеракици - влево,
-- меньше, прозрачнее фон» · «как ты сделал для трупов»). The game's prompts for an NPC to talk to, a building, a simple object, a thrall and a downed ally are
-- five sibling widgets of /Game/UI/HUD/FloatingNames/ with ONE shape (kit probe kit-probe-tree.json, 2026-11-06): root Overlay → SizeBox centred →
-- Border `Container` (the dark backing) → texts + W_ActionTutorial. The SAME hub rows drive them (one setting for all, the owner's «все виджеты»); the kit
-- pak ships scale and backing, this applies the shift and the player's choice. Applied at a widget's birth (one tick later — the module fills it after
-- construction) and on a hub save; instances are remembered at birth, never searched. [NOT-TESTED]
local INFO_CLASSES = {
    "/Game/UI/HUD/FloatingNames/W_DialogueNPCInfo.W_DialogueNPCInfo_C",
    "/Game/UI/HUD/FloatingNames/W_PlaceableInfo.W_PlaceableInfo_C",
    "/Game/UI/HUD/FloatingNames/W_SimpleInfo.W_SimpleInfo_C",
    "/Game/UI/HUD/FloatingNames/W_ThrallInfo.W_ThrallInfo_C",
    "/Game/UI/HUD/FloatingNames/W_DBNORevive.W_DBNORevive_C",
}
local INFO_BACKING = "Container"
local infos = {}   -- full name → widget (UE4SS wrappers are new values per call: key by name, EXP-0453)
local function place_info(w)
    if not (w and w:IsValid()) then return false end
    local b = w:GetWidgetFromName(FName(INFO_BACKING))
    if not (b and b:IsValid()) then return false end
    place_strip(w, b, true)
    return true
end
_G.__krinik_uifixes_info_fn = function(w)
    local name = w:GetFullName()
    if name:find("Default__", 1, true) then return end   -- the class default
    infos[name] = w
    ExecuteInGameThreadWithDelay(RECHECK_MS, function()
        local ok, done = pcall(place_info, w)
        stats.infos = (stats.infos or 0) + ((ok and done) and 1 or 0)
        log("info prompt born: %s — %s", name:match("[^%.]+$") or name, ok and (done and "placed" or "no backing") or ("error " .. tostring(done)))
    end)
end
if not _G.__krinik_uifixes_info_armed then
    _G.__krinik_uifixes_info_armed = true
    for _, cls in ipairs(INFO_CLASSES) do
        NotifyOnNewObject(cls, function(w) local fn = _G.__krinik_uifixes_info_fn; if fn then pcall(fn, w) end end)
    end
end
settings.on_change(function()
    for k, w in pairs(infos) do
        if not (w and w:IsValid()) then infos[k] = nil else pcall(place_info, w) end
    end
end)

-- 1.4.0 — the journey tracker («Выживший · Потратьте очки характеристик…», `WBP_JourneyTracker_C`, a viewport widget of the game instance) is not drawn
-- while the quick-loot window shows: the window stands over it and its see-through grid let the tracker's text through (KUMM bugs/81; way A of three, chosen
-- `[AI]` by mandate — `[OWNER]` 2026-11-03 22:39 «аналогичный вопрос про автономность работы»; way B, a darker tint of the window's tile, did not help — the
-- see-through is the texture's own alpha). RENDER opacity, not visibility: the game switches the tracker's visibility itself, and never its render opacity.
-- The tracker is remembered at its birth (no search); hidden from `align` (the same events). The window closes WITHOUT an event when the view leaves the
-- corpse, so while the tracker is hidden — and only then — a watch every TRACKER_WATCH_MS gives it back once the window is no longer on screen. [NOT-TESTED]
local TRACKER_CLASS = "/Game/UI/Widgets/HUD/Journey/WBP_JourneyTracker.WBP_JourneyTracker_C"
local TRACKER_WATCH_MS = 250
local tracker, tracker_watch = nil, false
NotifyOnNewObject(TRACKER_CLASS, function(w) tracker = w end)
local function loot_on_screen(ci)
    if not (ci and ci:IsValid() and ci:IsInViewport() and ci:IsVisible()) then return false end
    local panel = ci:GetWidgetFromName(FName(PANEL))
    return panel and panel:IsValid() and SHOWN[panel:GetVisibility()] or false
end
local function tracker_under_loot(ci, loot_shown)
    if not (tracker and tracker:IsValid()) then
        tracker = nil
        for _, w in ipairs(FindAllOf("WBP_JourneyTracker_C") or {}) do   -- once, when the mod loaded after the tracker's birth (a reload)
            if w:GetFullName():find("Transient", 1, true) then tracker = w end
        end
        if not tracker then return end
    end
    local want = loot_shown and 0.0 or 1.0
    if math.abs(tracker:GetRenderOpacity() - want) > 0.001 then tracker:SetRenderOpacity(want) end
    if loot_shown and not tracker_watch then
        tracker_watch = true
        local function watch()
            local ok, on = pcall(loot_on_screen, ci)
            if ok and on then ExecuteInGameThreadWithDelay(TRACKER_WATCH_MS, watch); return end
            tracker_watch = false
            if tracker and tracker:IsValid() then tracker:SetRenderOpacity(1.0) end
        end
        ExecuteInGameThreadWithDelay(TRACKER_WATCH_MS, watch)
    end
end

-- Left while the window shows loot, Center otherwise; touches the slot only when the value changes.
local function align(ci)
    if not (ci and ci:IsValid()) then return end
    local strip = ci:GetWidgetFromName(FName(STRIP))
    local panel = ci:GetWidgetFromName(FName(PANEL))
    if not (strip and strip:IsValid() and panel and panel:IsValid()) then return end
    local slot = strip.Slot
    if not (slot and slot:IsValid()) then return end
    local want = SHOWN[panel:GetVisibility()] and ALIGN.left or ALIGN.center
    if slot.HorizontalAlignment ~= want then
        slot:SetHorizontalAlignment(want)
        stats.changes = stats.changes + 1
    end
    place_strip(ci, strip, want == ALIGN.center)
    tracker_under_loot(ci, want == ALIGN.left)
end

-- 1.3.0 — the corpse prompt on two CENTRED lines (KUMM plan 36 W6; `[OWNER]` «центрируй» · «строчки центрируй» · 2026-10-30 19:48–19:50,
-- his «да, верно» on the mock-up 19:56). The row W_ActionTutorial lays out PreText · key icon · PostText and cannot centre two lines (the
-- icon stands right of PreText's whole box). The kit pak adds our centred line T_CorpseText1 (a TextBlock dressed from the row's style asset FS_Text_Heading_6) above the
-- row, collapsed. The translation gives the corpse row only line 2 («или нажмите {0}, чтобы забрать предметы», vanilla-override row of key
-- DA4E821B…); here, when the row's PreText starts with LINE2_HEAD, our line shows LINE1_TEXT — the first half of the same vanilla
-- sentence — otherwise it is collapsed (chests and the rest). Writing PreText from Lua did not reach the screen (frame 19:58: the game
-- keeps its own text), so the row is never touched. On the same events as the alignment, no polling. [NOT-TESTED]
local LINE1 = "T_CorpseText1"
local ROW = "ActionTutorial"
local LINE1_TEXT = "Разделайте труп и получите ресурсы"
local LINE2_HEAD = "или нажмите"
local VIS = { collapsed = 1, self_hit_test_invisible = 4 }

local function split_prompt(ci)
    if not (ci and ci:IsValid()) then return end
    local line1 = ci:GetWidgetFromName(FName(LINE1))
    local row = ci:GetWidgetFromName(FName(ROW))
    if not (line1 and line1:IsValid() and row and row:IsValid()) then return end
    local pre = row.PreText
    if not (pre and pre:IsValid()) then return end
    local corpse = pre:GetText():ToString():sub(1, #LINE2_HEAD) == LINE2_HEAD
    local want = corpse and VIS.self_hit_test_invisible or VIS.collapsed
    if corpse and line1:GetText():ToString() ~= LINE1_TEXT then line1:SetText(FText(LINE1_TEXT)) end
    if line1:GetVisibility() ~= want then
        line1:SetVisibility(want)
        if corpse then stats.splits = (stats.splits or 0) + 1 end
    end
end

-- The container of a quick-loot panel: panel → its WidgetTree → the WBP_ContainerInfo instance (outer chain, no search).
local function container_of(panel)
    local tree = panel and panel:IsValid() and panel:GetOuter()
    local ci = tree and tree:IsValid() and tree:GetOuter()
    if ci and ci:IsValid() and ci:GetClass():GetFName():ToString() == "WBP_ContainerInfo_C" then return ci end
    return nil
end

-- ctx is either the container (SetObject) or its quick-loot panel (SlotItemAddedOrRemoved).
local function on_event(ctx, from_panel)
    local t0 = os.clock()
    local ci = ctx:get()
    if from_panel then ci = container_of(ci) end
    if not ci then return end
    align(ci)
    split_prompt(ci)
    ExecuteInGameThreadWithDelay(RECHECK_MS, function() pcall(align, ci); pcall(split_prompt, ci) end)
    local dt = (os.clock() - t0) * 1000.0
    stats.n, stats.sum = stats.n + 1, stats.sum + dt
    if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S then
        log("events %d, alignment changes %d, prompt splits %d, info prompts placed %d, handler sum %.3f ms, worst %.3f ms (last %d s)",
            stats.n, stats.changes, stats.splits or 0, stats.infos or 0, stats.sum, stats.worst, SUMMARY_S)
        stats.n, stats.sum, stats.worst, stats.changes, stats.splits, stats.infos, stats.last = 0, 0.0, 0.0, 0, 0, 0, os.clock()
    end
end

-- A global reference, so that a reload of the mod does not double the handling (EXP-0348).
_G.__krinik_uifixes_fn = on_event
local function hook(fname, from_panel)
    local ok, err = pcall(function()
        RegisterHook(fname, function(ctx)
            local fn = _G.__krinik_uifixes_fn
            if fn then
                local ok2, e2 = pcall(fn, ctx, from_panel)
                if not ok2 then log("error in %s: %s", fname, tostring(e2)) end
            end
        end)
    end)
    log(ok and "hook %s set" or "hook %s failed: %s", fname, tostring(err))
end

-- The native panel class exists from the start: its hook is set at load.
if not _G.__krinik_uifixes_loot_hooked then
    _G.__krinik_uifixes_loot_hooked = true
    hook(LOOT_EVENT, true)
end
-- The blueprint hook is set INSIDE the creation callback, not deferred: the module system creates the widget and calls SetObject in the
-- same frame, and a deferred registration (ExecuteInGameThread) missed that first SetObject — the first corpse kept the strip centred
-- under the window (frame `l3_strip.webp`, 2026-10-29 00:18). The new widget is also aligned once, one tick later.
NotifyOnNewObject(WIDGET_CLASS, function(widget)
    if not _G.__krinik_uifixes_hooked then
        _G.__krinik_uifixes_hooked = true
        hook(WIDGET_EVENT, false)
    end
    ExecuteInGameThreadWithDelay(RECHECK_MS, function() pcall(align, widget) end)
end)

-- 1.2.0 — the key glyph of a button keeps its width from the first frame (KUMM bugs/64 item 17, class A; `[OWNER]` «книзу кнопки прыгают» ·
-- 2026-10-29 21:38). A button's `W_HotkeyIcon` puts the glyph (texture 128×96 or 96×96) into `ScaleBoxPrimaryIcon` inside `SizeBoxPrimaryIcon`
-- with height 32 and NO width override; a ScaleBox scales by the previous frame's geometry, so a new button's glyph is 128 wide on its first
-- frame and 42.7 after — the hub bar is rebuilt on every tab and its buttons jump by ≈ 85 units (probe and strips: KUMM
-- testcases/TC_conan_hub_bottom_bar_width_jump_2026-10-29.md). A `MaxDesiredWidth` of 32 × 128/96 on that SizeBox removes the first-frame
-- 128; the native `HotkeyIcon` code never touches it. Not on the class template: the action tutorial prompts are width-free too, at height 38
-- (settled 50.7) — only icons whose owner is a `WBP_ButtonBase`. Set at the SizeBox's birth (it survives the archetype copy: 34 of 34 in the
-- remote experiment 2026-10-29 21:5x); once per birth, no polling, the owner found by the outer chain, no search. [NOT-TESTED] in the mod.
local GLYPH_BOX = "SizeBoxPrimaryIcon"
local GLYPH_MAX_W = 32 * 128 / 96     -- button glyph height 32 × the widest glyph seen (128×96)
local BUTTON_CLASS = "WBP_ButtonBase_C"
local glyph = { births = 0, capped = 0, sum = 0.0, worst = 0.0, last = os.clock() }

local function on_sizebox(box)
    local t0 = os.clock()
    if box:GetFName():ToString() ~= GLYPH_BOX then return end
    glyph.births = glyph.births + 1
    -- SizeBox → icon's WidgetTree → W_HotkeyIcon → button's WidgetTree → the button
    local o = box
    for _ = 1, 4 do
        o = o:GetOuter()
        if not (o and o:IsValid()) then return end
    end
    if o:GetClass():GetFName():ToString() ~= BUTTON_CLASS then return end
    box.bOverride_MaxDesiredWidth = true
    box.MaxDesiredWidth = GLYPH_MAX_W
    glyph.capped = glyph.capped + 1
    local dt = (os.clock() - t0) * 1000.0
    glyph.sum = glyph.sum + dt
    if dt > glyph.worst then glyph.worst = dt end
    if os.clock() - glyph.last >= SUMMARY_S then
        log("glyph boxes born %d, capped %d, handler sum %.3f ms, worst %.3f ms (last %d s)",
            glyph.births, glyph.capped, glyph.sum, glyph.worst, SUMMARY_S)
        glyph.births, glyph.capped, glyph.sum, glyph.worst, glyph.last = 0, 0, 0.0, 0.0, os.clock()
    end
end
_G.__krinik_uifixes_glyph_fn = on_sizebox
if not _G.__krinik_uifixes_glyph_armed then
    _G.__krinik_uifixes_glyph_armed = true
    NotifyOnNewObject("/Script/UMG.SizeBox", function(box)
        local fn = _G.__krinik_uifixes_glyph_fn
        if fn then
            local ok, e = pcall(fn, box)
            if not ok then log("glyph cap error: %s", tostring(e)) end
        end
    end)
end
-- ===================== 1.6.0 (2026-11-07): the hub's «Снаряжение» no longer dances when another item is selected =====================
-- `[OWNER]` 2026-11-07 10:52 «интерфейс Пляшет при выделении разных предметов - это баг, его нужно будет пофиксить. Не должен плясать интерфейс на одном и том
-- же экране при выборе разных предметов» · 10:53 «ВЕСЬ ЭКРАН СНИМА!». Cause (remote, 10:5x): the three columns of `CraftingGUI_C` sit in a `ScaleBox`
-- (Stretch ScaleToFit) whose content height is the TALLEST column — the left one, whose height follows the selected item's description (1080.8 for the
-- stone sword, 1079.0 for the Sword of Crom): the scale changed with the item and the whole middle moved 2–3 px at 4K. Fix at the window's birth: the left
-- column's `SizeBox_2` gets a fixed height (the bag grid inside absorbs a longer description), the right one may not grow past it; one set per window, no
-- polling. A copy of the whole `CraftingGUI` in our kit pak was not taken: it is the game's central inventory window, mods inject into it at run time,
-- and a copy would freeze it at the kit's version for one value. Live A/B 10:5x: the middle's shift 2–3 px → 0 on every measured place. [NOT-TESTED] as code
local HUB_COLUMN_HEIGHT = 1082.0          -- the column height the ScaleBox fits (seen 1079–1081 for ordinary items)
local CRAFTING_GUI = "/Game/UI/Inventory/CraftingGUI.CraftingGUI_C"
local function fix_hub_columns(w)
    if not (w and w:IsValid()) or w:GetFullName():find("Default__", 1, true) then return end
    local left, right = w:GetWidgetFromName(FName("SizeBox_2")), w:GetWidgetFromName(FName("SizeBox_0"))
    if left and left:IsValid() then left:SetHeightOverride(HUB_COLUMN_HEIGHT) end
    if right and right:IsValid() then right:SetMaxDesiredHeight(HUB_COLUMN_HEIGHT) end
end
_G.__krinik_uifixes_columns_fn = fix_hub_columns
NotifyOnNewObject(CRAFTING_GUI, function(w)
    -- born inside CreateWidget: the tree is there on the next game-thread pass
    ExecuteInGameThread(function() local fn = _G.__krinik_uifixes_columns_fn; if fn then pcall(fn, w) end end)
end)

-- ===================== 1.7.0 (2026-11-07): Inventory Compactor's two buttons get the game's tooltip look =====================
-- `[OWNER]` 2026-11-07 10:58 (his frame of «Выберите стопку и нажмите, чтобы отделить нужное количество»): «эти поп-апы тоже перевести в вид как у игры».
-- The mod's `btn_Split` / `btn_Compact` (in `IC_UI_CompactButton2_C`) carry a plain ToolTipText — Slate's default light-grey box. The game's own tooltip is
-- `W_TooltipWidget_C` (field `Text_Content`; `RootWidget.TooltipWidgetClass` of the game's buttons). At the mod widget's birth + one tick each button gets
-- SetToolTip(<a W_TooltipWidget with the button's own text>) — once per widget, no polling. A tooltip WIDGET cannot be stored in the mod's asset (only a
-- binding function or run time sets it), hence Lua (HOUSE_RULES rule 8). Seen live 12:2x by a real hover (KUMM games/ConanExiles/mods/InventoryCompactor.md).
-- [NOT-TESTED] as code
local COMPACT_BUTTONS = "/Game/Mods/Inventory_compactor/IC_UI_CompactButton2.IC_UI_CompactButton2_C"
local GAME_TOOLTIP = "/Game/UI/Framework/W_TooltipWidget.W_TooltipWidget_C"
local function game_tooltips(m)
    if not (m and m:IsValid()) or m:GetFullName():find("Default__", 1, true) then return end
    local cls = StaticFindObject(GAME_TOOLTIP)
    local pc = FindFirstOf("PlayerController")
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    if not (cls and cls:IsValid() and pc and pc:IsValid()) then return end
    local n = 0
    for _, bn in ipairs({ "btn_Split", "btn_Compact" }) do
        local b = m:GetWidgetFromName(FName(bn))
        if b and b:IsValid() then
            local tw = lib:Create(pc, cls, pc)
            tw.Text_Content:SetText(b.ToolTipText)
            b:SetToolTip(tw)
            n = n + 1
        end
    end
    log("Inventory Compactor: game tooltips on %d buttons", n)
end
_G.__krinik_uifixes_compactor_fn = game_tooltips
NotifyOnNewObject(COMPACT_BUTTONS, function(m)
    ExecuteInGameThread(function() local fn = _G.__krinik_uifixes_compactor_fn; if fn then pcall(fn, m) end end)
end)

log("loaded 1.7.0")
