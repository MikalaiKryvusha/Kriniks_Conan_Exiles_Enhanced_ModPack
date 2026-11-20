--[[
  KrinikConanUI · hub_controller — our own controller of the hub's pages (KUMM plans/48, 2026-11-07).

  The owner's design (2026-11-06 22:10 · 23:07 · 23:48, verbatim in plan 48): «клик выполнен, визуального переключения не происходит, пока новая страница
  полностью не соберётся … новая мгновенно одним кадром открывается»; «ленивую сборку … в фоне лениво собираются все остальные страницы в направлении от
  текущей вправо и влево»; «свой контроллер хаба АДЕКВАТНЫЙ» · «встройки модов привязываю к нему напрямую. через интерфейсы».

  How it works (prototypes v5–v10 in the pack's `_config/hubswitch/`, run report KUMM testcases/reports/2026-11-07_conan-hub-controller-shadow-pages.md):
  * OUR pages for Таланты, Хар-ки, Клан, Спутники, Базар (Путешествие and Карта until 2026-11-20) — one instance each, built lazily (one per tick, nearest
    tab first, right and left), kept in the viewport, shown the tick after the game's native switch; the game's own newborn page of that tab is hidden.
  * The GAME's pages (GAME_PAGE) for Снаряжение and Параметры — the game tolerates no second inventory or stats window (a second one closes the hub or is
    killed) — and since 2026-11-20 for Путешествие and Карта (our copies were never the game's modules: dead journey start, misplaced map markers): the
    newborn is held at opacity 0 until no widget is born for QUIET_SAMPLES ticks, then shown; the previous page stays on screen meanwhile.
  * INACTIVE since 2026-11-20 (judge round 1): REFRESH (tab 5) and the Simple Minimap adapter (tab 8) serve only OUR copies of those tabs, which are game
    pages now. Kept until case N3 (every button of the five other copies) decides whether the copy design stays for any tab; removed with that decision.
  * A widget is kept by its NAME and found alive through FindAllOf before every touch — a Lua ref is a raw pointer and the game destroys extra pages
    (the 2026-11-07 06:29 crash). Inside the native switch only the newborn's opacity is touched (SetVisibility there crashes — KUMM EXP-0474).
  * Closed hub = the game's page of the current tab left the viewport; checked after every ActivateModule (Esc and Tab closes pass through it — bug 85
    recon R2, 2026-11-18) — no timer, no key bind (HOUSE_RULES rule 7).
    On close our pages are Collapsed; the next switch (the reopening) brings them back.
  * Mods' embeds on OUR pages (adapters): Simple Minimap's helper row on «Карта» (`SM_UI_MapHelper`) — inactive since 2026-11-20, the game's own map page
    carries the mod's row itself (case N2 of KUMM testcases/TC_conan_hub_game_pages_map_journey_2026-11-20.md).
  Known gap (since 2026-11-20 likely on every switch between two GAME pages — Параметры ↔ Путешествие is an ordinary Q / E step now; case N1 owed, judge
  rounds 1–2): a direct switch between Снаряжение and Параметры shows ≈ 120–150 ms of the dark backing with no page (both are the game's pages: the old one
  leaves inside the native switch, the newborn is held until built); since 2026-11-14 (bug 101 item 5) Параметры → Снаряжение no longer shows the bare world
  (fix5.mp4 at 42 fps; a one-tick bare frame in the native switch tick at 144 fps is not checked).
  [TESTED: 2026-11-07 07:35–07:48 · as a section in the build, background game, the remote's switches: one page per tick on every probed transition, 2 open/close cycles, 0 errors · KUMM testcases/reports/2026-11-07_conan-hub-controller-shadow-pages.md — the player's mouse / Esc / Tab path NOT run]
]]

local PREFIX = "[KrinikConanUI:HubController] "
local function log(fmt, ...) print(PREFIX .. string.format(fmt, ...) .. "\n") end

local CL = { '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C', '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C', '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
  '/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C', '/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C',
  '/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C', '/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C',
  '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C', '/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C' }
-- Снаряжение, Параметры: the game's own (one inventory / one stats window only).
-- Путешествие (5) and Карта (8) — the game's own since 2026-11-20 (KUMM bugs 112, 113; issues #11, #12, #33): our copies are standalone widgets the game never
-- activated as its modules — on our «Карта» the first marker landed away from the click, no second marker, the reset dead (the owner's play of 0.9.1-RC1).
-- [TESTED: 2026-11-20 · J1 «Начать путешествие» starts the journey, M1 two markers at the clicks and the reset, N2 Simple Minimap's row — real input on the owner's
--  game · KUMM testcases/reports/2026-11-20_conan-hub-game-pages-map-journey.md — N1, N3, M2 not run]
local GAME_PAGE = { [1] = true, [4] = true, [5] = true, [8] = true }
local MAP_PAGE = 8
-- A kept page shows the data of ITS birth: the game's own page is born at every switch and reads the data then, ours was built once (KUMM bug 97 — the
-- owner 2026-11-13 16:01: right after the tutorial every journey but fishing «под замком»). Proven 2026-11-14 10:3x (case J1b of
-- TC_conan_journeys_stale_hub_page_2026-11-14): a feat learned with the hub open (`ServerPurchaseFeat(9)`, the knowledge window's own call) → the game's newborn
-- page showed «Кожевник» open, our kept page still locked; the page's native `RefreshGrid(bHideCompletedJourneys)` (17 ms) brought it to the truth.
-- So a page that has a native refresh gets it every time OUR page of its tab is shown. The other kept tabs — the twin list in bug 97.
-- [TESTED: 2026-11-14 · tab 5 only: J2 (a feat between two switches), J3 (a real close, 40 / 40 cards = the game's page), fast-burst 6 / 6, «ошибок 0» · KUMM testcases/reports/2026-11-14_conan-page-arrows-square-and-journeys-refresh.md]
local REFRESH = {
    [5] = function(page) page:RefreshGrid(page:GetHideCompletedJourneys()) end,   -- Путешествие (W_NewJourneyWindow → NewJourneyWindowBase)
}
-- Our pages sit at the GAME's own layer: every hub tab module AND the modal trait dialog `PerkSelection` are ZOrder 40 in DT_UIModuleTable (read live
-- 2026-11-10 09:48, live-rows.lua). At 41 our «Хар-ки» page drew its tree OVER the game's «Выберите Черту» dialog (KUMM bug 84, reproduced by ten real «+»
-- clicks 09:46; with our page hidden the dialog was clean). At 40 a later-added modal draws on top, as with the game's own pages.
-- KUMM bug 101 (2026-11-14, real clicks at 144 fps): the hub's dark backing — W_Carousel's image «Background», its material scalar «MaskOffset» (0 on,
-- 1 off; off ONLY on «Снаряжение», read live 12:47 by _config/carousel-backing.lua) — is switched by the NATIVE tab switch, while our page shows a tick later
-- (ours) or after the hold (the game's pages): for 34–166 ms a page stood over the bare world. Now the backing follows what is SHOWN: it is written in the
-- same tick a page is shown, and during a hold the backing of what is on screen. [TESTED: 2026-11-14 · fix3.mp4 by real clicks — every switch to / from
-- «Снаряжение» one frame; 13:3x the opening onto «Снаряжение» and «Параметры» after it read live · KUMM testcases/reports/2026-11-14_conan-hub-backing-owned.md]
local SEE_THROUGH = { [1] = true }                  -- Снаряжение: the game draws no backing behind the inventory
local MASK_PARAM = 'MaskOffset'
local BACK = { sets = 0, misses = 0, fails = 0, err = '' }    -- counted into the close line: a write that never lands must be seen (the first fix of 13:00 did nothing)
local function set_backing(on)
    local done = false
    for _, c in ipairs(FindAllOf('W_Carousel_C') or {}) do
        local ok, e = pcall(function()
            if not c:GetFullName():find('Default__', 1, true) then
                local bg = c:GetWidgetFromName(FName('Background'))
                if bg and bg:IsValid() then bg:GetDynamicMaterial():SetScalarParameterValue(FName(MASK_PARAM), on and 0.0 or 1.0); done = true end
            end
        end)
        if not ok then BACK.err = tostring(e); BACK.fails = BACK.fails + 1 end
    end
    if done then BACK.sets = BACK.sets + 1 else BACK.misses = BACK.misses + 1 end
end
-- The game wrote the backing AFTER our switch tick (13:07 log: our writes landed, the recording still showed the bare world — the carousel's fade is played
-- later than OnChildActivated). Since 13:2x the fade is a no-op in our kit (kit-conanui-edit.py CAROUSEL_NOOP) and this controller alone owns MaskOffset;
-- the wanted state is still re-asserted every tick of a hold and for BACKING_TICKS ticks after a page is shown (assert_backing, below `timed`).
local BACKING_TICKS = 8
local Z_ORDER = 40
local QUIET_SAMPLES = 2
local HOLD_MAX_SAMPLES = 60
local LAZY_STEP_MS = 1                              -- ExecuteInGameThreadWithDelay counts MILLISECONDS; 1 = the next tick
local CLOSE_RECHECK_MS = { 1, 100, 300 }
local SM_HELPER_CLASS = '/Game/Mods/Simple_Minimap/UI/CustomMarker/SM_UI_MapHelper.SM_UI_MapHelper_C'
local SM_HELPER_HALIGN, SM_HELPER_VALIGN = 1, 2       -- EHorizontalAlignment Left, EVerticalAlignment Center — as the mod places it on the game's map
local VIS_COLLAPSED, VIS_HIT_TEST_INVISIBLE, VIS_SELF_HIT_TEST_INVISIBLE = 1, 3, 4

local SHORT, IDX = {}, {}
for i, p in ipairs(CL) do SHORT[i] = p:match('%.([%w_]+)$'); IDX[SHORT[i]] = i end

local S = { names = {}, display = nil, game_name = nil, closed = true, opening = false, gen = 0, lazy_busy = false,
  switches = 0, holds = 0, hold_max = 0, hold_timeouts = 0, builds = 0, build_ms_max = 0, closes = 0, lost = 0, helper = 0, refreshes = 0,
  worst_ms = 0, sum_ms = 0, errors = 0, last_err = '' }
_G.__krinik_hub_ctl = S                              -- read by the agent's remote; never written from outside
local births = 0

local function err(e) S.errors = S.errors + 1; S.last_err = tostring(e) end
local function timed(f)                              -- self-measurement of every handler (HOUSE_RULES rule 7)
    local t0 = os.clock()
    local ok, e = pcall(f)
    local ms = (os.clock() - t0) * 1000
    S.sum_ms = S.sum_ms + ms
    if ms > S.worst_ms then S.worst_ms = ms end
    if not ok then err(e) end
end
-- bug 101: the backing state re-asserted for n ticks (the game's later fade would overwrite one write); a newer switch (S.gen) stops the chain
local function assert_backing(on, n, gen)
    if n <= 0 or gen ~= S.gen then return end
    set_backing(on)
    ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function() timed(function() assert_backing(on, n - 1, gen) end) end)
end

local function find_by_name(i, name)
    if not name then return nil end
    for _, w in ipairs(FindAllOf(SHORT[i]) or {}) do
        local ok, n = pcall(function() return w:GetFullName() end)
        if ok and n == name then return w end
    end
    return nil
end

local function is_ours(w)
    local ok, n = pcall(function() return w:GetFullName() end)
    if not ok then return false end
    for _, name in pairs(S.names) do if name == n then return true end end
    return false
end

-- adapter: Simple Minimap's helper row into OUR map page's bottom bar (the mod puts it only into the game's page)
local function add_minimap_helper(page, pc, lib)
    local hc = StaticFindObject(SM_HELPER_CLASS)
    -- Since 3.1.0 the game loads only ModController classes at startup (Funcom's notes 2026-11-12; KUMM researches/conan_patch_3_1_0 §3 A.1), and
    -- StaticFindObject never loads: the helper class may be absent while the mod IS installed. Load it by its full path first (the pattern of build()).
    -- [NOT-TESTED]
    if not (hc and hc:IsValid()) then pcall(function() LoadAsset(SM_HELPER_CLASS) end); hc = StaticFindObject(SM_HELPER_CLASS) end
    if not (hc and hc:IsValid()) then return end      -- the mod is not installed
    local page_name = page:GetFullName()
    local bar = nil
    for _, w in ipairs(FindAllOf('SizeBox') or {}) do
        if w:GetFName():ToString() == 'sb_ButtonBar' then
            local ok, o = pcall(function() return w:GetOuter():GetOuter():GetFullName() end)
            if ok and o == page_name then bar = w end
        end
    end
    if not bar then return end
    local overlay = bar:GetChildAt(0)
    local helper = lib:Create(pc, hc, pc)
    local slot = overlay:AddChild(helper)
    -- the mod's own placement in the game's map page, read live 2026-11-07 10:3x (OverlaySlot: HAlign Left, VAlign Center, padding 0). Copied from «the
    -- last live helper» until then — at our page's lazy build that was a helper the mod had not placed yet (VAlign Top): the row stood high on our map
    -- (`[OWNER]` 2026-11-07 10:23 «и тут кнопки поехали вверх, нужно ниже их», his frame).
    pcall(function()
        slot:SetHorizontalAlignment(SM_HELPER_HALIGN)
        slot:SetVerticalAlignment(SM_HELPER_VALIGN)
        slot:SetPadding({ Left = 0.0, Top = 0.0, Right = 0.0, Bottom = 0.0 })
    end)
    S.helper = S.helper + 1
end

local function build(i)
    local pc = FindFirstOf('PlayerController')
    if not (pc and pc:IsValid()) then return nil end
    local lib = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
    local c = StaticFindObject(CL[i])
    if not (c and c:IsValid()) then pcall(function() LoadAsset(CL[i]) end); c = StaticFindObject(CL[i]) end
    if not (c and c:IsValid()) then return nil end
    local t0 = os.clock()
    S.building = true                                -- our own page's birth is not the game's newborn (it was left in __krinik_hub_newborn)
    local okc, w = pcall(function() return lib:Create(pc, c, pc) end)
    S.building = false
    if not (okc and w) then return nil end
    w:SetRenderOpacity(0.0)
    w:AddToViewport(Z_ORDER)
    w:SetVisibility(S.closed and VIS_COLLAPSED or VIS_HIT_TEST_INVISIBLE)
    S.names[i] = w:GetFullName()
    if i == MAP_PAGE then pcall(add_minimap_helper, w, pc, lib) end
    local ms = (os.clock() - t0) * 1000
    S.builds = S.builds + 1
    if ms > S.build_ms_max then S.build_ms_max = ms end
    return w
end

local function ours(i)
    local w = find_by_name(i, S.names[i])
    if not w then if S.names[i] then S.lost = S.lost + 1 end; return build(i) end
    if not w:IsInViewport() then w:AddToViewport(Z_ORDER) end
    return w
end

local function hide_display(except_name)
    local d = S.display
    if not d or d[2] == except_name then return end
    local w = find_by_name(d[1], d[2])
    if w then pcall(function() w:SetRenderOpacity(0.0); w:SetVisibility(VIS_HIT_TEST_INVISIBLE) end) end
end

-- lazy build: nearest tab first, alternating right and left (the carousel wraps)
local function lazy_order(from)
    local order, seen = {}, {}
    for d = 1, #CL - 1 do
        for _, k in ipairs({ ((from - 1 + d) % #CL) + 1, ((from - 1 - d) % #CL) + 1 }) do
            if not seen[k] and not GAME_PAGE[k] then seen[k] = true; order[#order + 1] = k end
        end
    end
    return order
end
local function lazy_build(order, n)
    if n > #order or S.closed then S.lazy_busy = false; return end
    ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function()
        timed(function() local k = order[n]; if not find_by_name(k, S.names[k]) then build(k) end end)
        lazy_build(order, n + 1)
    end)
end
local function start_lazy(from)
    if S.lazy_busy then return end
    S.lazy_busy = true
    lazy_build(lazy_order(from), 1)
end

local function hold_until_quiet(gen, i, name, quiet, samples, last)
    ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function()
        timed(function()
            if gen ~= S.gen then return end
            if S.hold_want ~= nil then set_backing(S.hold_want) end   -- bug 101: every tick of the hold, the backing of what is on screen
            quiet = (births == last) and quiet + 1 or 0
            samples = samples + 1
            if quiet < QUIET_SAMPLES and samples < HOLD_MAX_SAMPLES then hold_until_quiet(gen, i, name, quiet, samples, births); return end
            if samples >= HOLD_MAX_SAMPLES then S.hold_timeouts = S.hold_timeouts + 1 end
            if samples > S.hold_max then S.hold_max = samples end
            local w = find_by_name(i, name)
            if w then w:SetRenderOpacity(1.0) end
            S.hold_want = nil
            assert_backing(not SEE_THROUGH[i], BACKING_TICKS, gen)   -- bug 101: the backing changes in the same tick as the page, and stays
            hide_display(name)
            S.display = { i, name }
        end)
    end)
end

-- Every UserWidget birth of the whole game passes here (damage numbers, prompts in combat): while the hub is CLOSED the handler returns at once, no
-- class read (HOUSE_RULES rule 7, the 1 ms budget of gameplay frames); the hub's opening is caught by OnChildActivated and a one-time scan instead.
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    if S.closed then return end
    births = births + 1
    if S.building then return end
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    if ok and IDX[c] then _G.__krinik_hub_newborn = { IDX[c], w } end
end)

local on_switch

-- the hub OPENED (the births were not watched while closed): the game's page now in the viewport is the newborn; it shows natively this time
local function open_scan()
    S.opening = false
    for k = 1, #CL do
        for _, w in ipairs(FindAllOf(SHORT[k]) or {}) do
            local ok, live = pcall(function() return (not is_ours(w)) and w:IsInViewport() and w:GetVisibility() ~= VIS_COLLAPSED end)
            if ok and live then
                local name = w:GetFullName()
                if not name:find('Default__', 1, true) then on_switch(k, name); return end
            end
        end
    end
end

RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local nb = _G.__krinik_hub_newborn
    _G.__krinik_hub_newborn = nil
    if not nb then                                   -- fires twice per switch (the first call takes the newborn) — or the hub just opened
        if S.closed and not S.opening then S.opening = true; ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function() timed(open_scan) end) end
        return
    end
    pcall(function() nb[2]:SetRenderOpacity(0.0) end)  -- inside the native call: the newborn only, opacity only
    local name = nil
    pcall(function() name = nb[2]:GetFullName() end)
    S.gen = S.gen + 1                                -- at once: a hold still waiting for the previous switch is cancelled now
    local gen = S.gen
    ExecuteInGameThreadWithDelay(LAZY_STEP_MS, function() timed(function() on_switch(nb[1], name, gen) end) end)
end)

-- one switch, the tick after the native one; the newborn is passed by NAME only (its raw ref may be dead by now — the stale-ref rule)
on_switch = function(i, name, gen)
    local opening = (gen == nil)                     -- only open_scan calls without a generation: the hub's newborn is shown natively then
    if not gen then S.gen = S.gen + 1; gen = S.gen end
        timed(function()
            if gen ~= S.gen or not name then return end
            local live = find_by_name(i, name)
            if not live or is_ours(live) then return end
            S.switches = S.switches + 1
            S.game_name = { i, name }
            if S.closed then
                S.closed = false
                for k = 1, #CL do local w = find_by_name(k, S.names[k]); if w then pcall(function() w:SetVisibility(VIS_HIT_TEST_INVISIBLE) end) end end
            end
            start_lazy(i)
            if GAME_PAGE[i] then
                -- bug 101: while the newborn is held, what is ON SCREEN decides the backing (judge 13:3x):
                --   OUR old page stays through the hold → its backing;
                --   the hub opening (open_scan) — the game's newborn shows natively → the newborn's own backing;
                --   anything else — an old GAME page (it leaves inside the native switch) or no displayed page yet (a switch while the opening hold
                --   still runs, our page failed to build) — leaves NO page on screen → the backing stays on, and goes off in the tick the newborn shows.
                -- Item 5 (2026-11-14, background window capture `stat2.mp4`): with «the newborn's backing» after an old game page, Параметры → Снаряжение
                -- showed the dark backing, then the BARE WORLD for two frames, then the inventory; `fix5.mp4` — dark backing → inventory.
                -- [TESTED: 2026-11-14 · fix5.mp4 (42 fps, remote switches), fast-burst 6 / 6 · KUMM testcases/reports/2026-11-14_conan-hub-game-pages-backing-and-feat-card.md — the
                --  «switch during the opening hold» branch (judge round 3) not staged]
                if S.display and not GAME_PAGE[S.display[1]] then S.hold_want = not SEE_THROUGH[S.display[1]]
                elseif opening and not S.display then S.hold_want = not SEE_THROUGH[i]
                else S.hold_want = true end
                set_backing(S.hold_want)
                S.holds = S.holds + 1; hold_until_quiet(gen, i, name, 0, 0, births); return
            end
            local built_before = S.builds
            local page = ours(i)
            local gw = find_by_name(i, name)
            if gw then pcall(function() gw:SetRenderOpacity(0.0); gw:SetVisibility(VIS_HIT_TEST_INVISIBLE) end) end
            if page then
                -- a page built in THIS call (the first opening straight onto its tab) was just filled by its construct — no refresh (judge round 2 F1)
                if REFRESH[i] and S.builds == built_before then
                    local ok, e = pcall(REFRESH[i], page)
                    if ok then S.refreshes = S.refreshes + 1 else err(e) end
                end
                page:SetRenderOpacity(1.0); page:SetVisibility(VIS_SELF_HIT_TEST_INVISIBLE)
                S.hold_want = nil
                assert_backing(not SEE_THROUGH[i], BACKING_TICKS, gen)   -- bug 101: our page and its backing in one tick
                hide_display(S.names[i])
                S.display = { i, S.names[i] }
            end
        end)
end

-- Is ANY game page of the 9 tabs in the viewport? The close test asks this, never «is the LAST page we saw still there»: a native switch removes the old
-- page and adds the newborn in one call, but `on_switch` records the newborn only a tick later — a close check landing in that tick (ActivateModule fires
-- during switches) read the old page as gone and «closed» an open hub: our pages collapsed, the pending switch cancelled, the newborn left at opacity 0 —
-- the empty hub of the owner's fast clicks (2026-11-07 10:18, fast-burst: 2 of 6 bursts empty, 8 false «хаб закрыт» lines).
local function game_page_in_viewport()
    for k = 1, #CL do
        for _, w in ipairs(FindAllOf(SHORT[k]) or {}) do
            local ok, live = pcall(function() return w:IsInViewport() and not w:GetFullName():find('Default__', 1, true) end)
            if ok and live and not is_ours(w) then return true end
        end
    end
    return false
end

local function check_closed()
    if S.closed or not S.game_name then return end
    if game_page_in_viewport() then return end
    S.closed = true; S.closes = S.closes + 1; S.gen = S.gen + 1; S.display = nil
    for k = 1, #CL do
        local w = find_by_name(k, S.names[k])
        if w then pcall(function() w:SetRenderOpacity(0.0); w:SetVisibility(VIS_COLLAPSED) end) end
    end
    log("хаб закрыт: переключений %d, удержаний %d (худшее %d тиков, срывов %d), построено страниц %d (худшая %.1f мс), обновлено страниц %d, потеряно %d, " ..
        "строка миникарты %d, подложка: записей %d, промахов %d, сбоев %d%s, обработчики: худший %.1f мс, всего %.1f мс, ошибок %d %s", S.switches, S.holds,
        S.hold_max, S.hold_timeouts, S.builds, S.build_ms_max, S.refreshes, S.lost, S.helper, BACK.sets, BACK.misses, BACK.fails,
        BACK.err ~= '' and (' (' .. BACK.err .. ')') or '', S.worst_ms, S.sum_ms, S.errors + BACK.fails, S.errors > 0 and S.last_err or "")
    BACK.err = ''                                    -- an old backing error is not repeated on the next close line (judge 13:3x)
end
local function check_soon()
    for _, ms in ipairs(CLOSE_RECHECK_MS) do ExecuteInGameThreadWithDelay(ms, function() timed(check_closed) end) end
end
-- The hub's close is seen by the ActivateModule post-hook alone (bug 85 recon R2, 2026-11-18 19:3x: a posted Esc ran WindowRoot:Close on CraftingGUI_C and
-- then ActivateModule; a posted Tab ran ActivateModule — both on the game thread). The ESCAPE / TAB key binds that stood here ran Lua on UE4SS's
-- event-loop thread — the crash class of bug 85 — and are removed. [NOT-TESTED]
local ok_am, e_am = pcall(RegisterHook, '/Script/ConanSandbox.GUIModuleController:ActivateModule', function() ExecuteInGameThread(check_soon) end)
if not ok_am then log("перехват ActivateModule не встал: %s", tostring(e_am)) end

log("взведён: свои страницы — 5 вкладок (лениво), страницы игры — Снаряжение, Параметры, Путешествие и Карта (удержание до готовности)")
