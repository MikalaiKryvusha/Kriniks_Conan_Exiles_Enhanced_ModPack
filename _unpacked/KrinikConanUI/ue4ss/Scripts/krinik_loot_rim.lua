--[==[===========================================================================
  krinik_loot_rim 0.1.0 — the quick-loot selection rim stays on its place when an item is taken with F (KUMM bugs/75).
  The owner's word: `[OWNER]` «при заборе предмета выделенного в окне квик лута по F на мгновение контур выбора перемещается в последнюю нижнюю
  правую клетку - некрасиво, он прыгает туда сюда» · 2026-11-02 09:10; the way: `[OWNER]` «мерцает рамка переносом в нижнюю правую - можно нахуй просто её
  делать невидимой на время мерцания?» · 2026-11-03 21:26.

  WHAT THE GAME DOES (KUMM bug 75, «The cause», trace `_config/quickloot-rim-trace.lua` 2026-11-03 21:16). The rim is each cell's own `SelectIndicator`
  (a Border, visibility HitTestInvisible) whose opacity the cell's widget animation `AnimSelect` (0.3 s) drives. One F take rebuilds the grid natively
  (`QuickLootPanel:SlotItemAddedOrRemoved` twice, the selection walked over the cells in between, all in one frame); the cells are pooled
  `InventoryGridSlotView_C` children of the CanvasPanel `ItemGrid`, re-placed by the rebuild. For ≈ 250 ms after it the walk's LAST cell keeps a full
  rim (its animation «plays» at 0.300) while the right cell has none; then the rim lands on the right cell — the item that slid into the taken place.
  The walk is C++ (no blueprint in `W_QuickLootPanel`), so it cannot be edited at its source.

  WHAT THIS DOES. The place of the rim (row, column) is read one game-thread tick after every selection change (`SlotItemSelectionChanged` — the wheel,
  the window's first selection), never inside a take: at the take's first slot call the walk has already lit the last cell. On a take every OTHER cell's
  rim is made invisible (Border visibility Hidden) at both slot calls and one tick later, for HOLD_MS — the animation's length and a frame — and given back;
  then the place is read again (the kept place, or the previous item when the last one was taken). The right cell is not touched, so its rim lights where
  it was before the take. Only the window on screen is touched (every panel bound to the same corpse inventory gets the slot); panels are compared by
  object address — a UE4SS wrapper is a new Lua value on every call (EXP-0453). Events only: no timer while the window is idle, no scene search. A param of
  a slot is never read (EXP-0452: an object param read in the selection slot crashed the game). Self-measured: the sum and the worst handler time, logged
  at most once a minute.
  [TESTED: 2026-11-03 · cases B3–B5 (a middle cell, the last item, after a normal start), 120 fps clips, control B2 — KUMM
   testcases/reports/2026-11-03_conan-quick-loot-rim-hold.md]
===========================================================================]==]

local MOD = "KrinikConanUI:LootRim"
local LOOT_EVENT = "/Script/ConanSandbox.QuickLootPanel:SlotItemAddedOrRemoved"
local SELECT_EVENT = "/Script/ConanSandbox.QuickLootPanel:SlotItemSelectionChanged"
local HOLD_MS = 350          -- AnimSelect is 0.3 s; the stuck rim was seen 250 ms (trace) / 3–4 frames of 50 ms (120 fps clip)
local VIS_HIDDEN = 2         -- ESlateVisibility: 0 Visible, 1 Collapsed, 2 Hidden, 3 HitTestInvisible, 4 SelfHitTestInvisible
local VIS_RIM = 3            -- the rim Border's own visibility in the game (read live 2026-11-03 21:10)
local LIT = 0.5              -- a rim drawn at more than half opacity is «the» rim
local CELL = 100             -- canvas units between cells (positions 0, 100, … 500 read live)
local SUMMARY_S = 60

local stats = { takes = 0, hidden = 0, sum = 0.0, worst = 0.0, last = os.clock() }
local take = nil             -- { panel, row, col, hid = {cell → true} } while a take is held

local function log(fmt, ...)
    print(string.format("[%s] " .. fmt .. "\n", MOD, ...))
end

-- SizeBox → ScrollBox → InventoryBox → ItemGrid (the grid's own tree, read live 2026-11-03 21:09).
local function cells(panel)
    local cv = panel.InventoryGridView.WidgetTree.RootWidget:GetChildAt(0):GetChildAt(0):GetChildAt(0)
    local out = {}
    for i = 0, cv:GetChildrenCount() - 1 do out[#out + 1] = cv:GetChildAt(i) end
    return out
end

local function place(cell)
    local p = cell.Slot:GetPosition()
    return math.floor(p.Y / CELL + 0.5), math.floor(p.X / CELL + 0.5)
end

local function on_screen(panel)
    local ci = panel:GetOuter():GetOuter()      -- the panel's WidgetTree → WBP_ContainerInfo
    return ci and ci:IsValid() and ci:IsInViewport()
end

local function hide_others(t)
    for _, c in ipairs(cells(t.panel)) do
        local r, k = place(c)
        local rim = c.SelectIndicator
        if (r ~= t.row or k ~= t.col) and rim:GetVisibility() == VIS_RIM then
            rim:SetVisibility(VIS_HIDDEN)
            t.hid[c] = true
        end
    end
end

local function give_back(t)
    local n = 0
    for c in pairs(t.hid) do
        if c:IsValid() then c.SelectIndicator:SetVisibility(VIS_RIM); n = n + 1 end
    end
    stats.hidden = stats.hidden + n
end

-- Where the rim stands BETWEEN takes: read one game-thread tick after every selection change (the wheel, the window's first selection), never inside
-- a take. Read at the take's first slot call it is already too late — the walk has lit the last cell by then (log 21:31:45: «row 3, column 6»).
local kept = nil             -- { panel, row, col }
_G.__krinik_loot_rim_seen = _G.__krinik_loot_rim_seen or { selections = 0, reads = 0, last = "none" }   -- what the remote reads to check this section
local seen = _G.__krinik_loot_rim_seen
local function remember(panel)
    if take or not (panel:IsValid() and on_screen(panel)) then return end
    seen.reads = seen.reads + 1
    for _, c in ipairs(cells(panel)) do
        if c.SelectIndicator:GetRenderOpacity() > LIT then
            local row, col = place(c)
            kept = { panel = panel, addr = panel:GetAddress(), row = row, col = col }
            seen.last = string.format("row %d, column %d", row + 1, col + 1)
            return
        end
    end
    seen.last = "no lit cell"
end
local function on_selection(ctx)
    seen.selections = seen.selections + 1
    if take then return end
    local panel = ctx:get()                     -- the panel itself; the slot's Item param is never touched (EXP-0452)
    ExecuteInGameThread(function() pcall(remember, panel) end)
end

local function on_slot(ctx)
    local t0 = os.clock()
    local panel = ctx:get()
    if not (panel and panel:IsValid() and on_screen(panel)) then return end
    if not take then
        if not (kept and kept.addr == panel:GetAddress()) then return end   -- no rim seen on this window yet — nothing to keep
        take = { panel = panel, addr = kept.addr, row = kept.row, col = kept.col, hid = {} }
        stats.takes = stats.takes + 1
        log("take: the rim kept at row %d, column %d", take.row + 1, take.col + 1)
        local t = take
        -- one tick later once more: a rebuild that runs after the second slot call re-places the cells again
        ExecuteInGameThread(function() pcall(hide_others, t) end)
        ExecuteInGameThreadWithDelay(HOLD_MS, function()
            pcall(give_back, t)
            if take == t then take = nil end
            -- where the game's own rim stands now (the walk's selection reads were skipped during the take): the kept place, or the previous
            -- item when the last one was taken
            pcall(remember, t.panel)
        end)
    end
    if take.addr == panel:GetAddress() then hide_others(take) end
    local dt = (os.clock() - t0) * 1000.0
    stats.sum = stats.sum + dt
    if dt > stats.worst then stats.worst = dt end
    if os.clock() - stats.last >= SUMMARY_S and stats.takes > 0 then
        log("takes %d, rims hidden %d, handler sum %.3f ms, worst %.3f ms (last %d s)", stats.takes, stats.hidden, stats.sum, stats.worst, SUMMARY_S)
        stats.takes, stats.hidden, stats.sum, stats.worst, stats.last = 0, 0, 0.0, 0.0, os.clock()
    end
end

-- Global references, so that a reload (the agent's remote, a mod restart) does not double the handling (EXP-0348).
_G.__krinik_loot_rim_fn = on_slot
_G.__krinik_loot_rim_sel_fn = on_selection
local function hook(fname, key)
    local ok, err = pcall(function()
        RegisterHook(fname, function(ctx)
            local fn = _G[key]
            if fn then
                local ok2, e2 = pcall(fn, ctx)
                if not ok2 then log("error: %s", tostring(e2)) end
            end
        end)
    end)
    log(ok and "hook %s set" or "hook %s failed: %s", fname, tostring(err))
end
if not _G.__krinik_loot_rim_hooked then
    _G.__krinik_loot_rim_hooked = true
    hook(LOOT_EVENT, "__krinik_loot_rim_fn")
end
if not _G.__krinik_loot_rim_sel_hooked then
    _G.__krinik_loot_rim_sel_hooked = true
    hook(SELECT_EVENT, "__krinik_loot_rim_sel_fn")
end
log("loaded 0.1.0")
return "loot rim 0.1.0"
