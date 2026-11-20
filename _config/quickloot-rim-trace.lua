-- quickloot-rim-trace.lua — what the selection rim of every quick-loot cell does, frame by frame, after an F take (KUMM bug 75).
-- The rim is the cell's own `SelectIndicator` (a Border) driven by its widget animation `AnimSelect` (0.3 s); the cells are 18 pooled
-- `InventoryGridSlotView_C` children of the grid's CanvasPanel `ItemGrid`. A post-hook on `QuickLootPanel:SlotItemAddedOrRemoved` (reads NO
-- param object — EXP-0452) arms a chain of game-thread steps (~every 5 ms, 40 steps); each step logs «[QLR] <ms> <cell>:<opacity>:<anim time>
-- <playing>» for every cell whose rim is not fully transparent or whose animation plays. Read-only: no call that changes the game.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/quickloot-rim-trace.lua')"   then a real F; grep '\[QLR\]' UE4SS.log
-- [NOT-TESTED]
local STEPS, STEP_MS = 40, 5
local function cells(panel)
    local g = panel.InventoryGridView
    local cv = g.WidgetTree.RootWidget:GetChildAt(0):GetChildAt(0):GetChildAt(0)   -- SizeBox → ScrollBox → InventoryBox → ItemGrid
    local out = {}
    for i = 0, cv:GetChildrenCount() - 1 do out[#out + 1] = cv:GetChildAt(i) end
    return out
end
local function snap(panel, t0)
    local ok, list = pcall(cells, panel)
    if not ok then print("[QLR] cells failed: " .. tostring(list) .. "\n"); return end
    local parts = {}
    for i, c in ipairs(list) do
        local op = c.SelectIndicator:GetRenderOpacity()
        local an = c.AnimSelect
        local playing = c:IsAnimationPlaying(an)
        if op > 0.001 or playing then
            local pos = c.Slot:GetPosition()    -- the cell's place on screen: pooled cells change their canvas order on a rebuild
            local dir = playing and (c:IsAnimationPlayingForward(an) and "F" or "R") or ""   -- F = being selected, R = being deselected
            local iv = c.iconView
            local item = (iv and iv:IsValid() and iv:GetVisibility() == 0) and "i" or "e"   -- a cell with an item or an empty one
            parts[#parts + 1] = string.format("r%dc%d%s:%.2f:%.3f%s", pos.Y // 100, pos.X // 100, item, op, c:GetAnimationCurrentTime(an), dir)
        end
    end
    print(string.format("[QLR] %6.1f ms %s\n", (os.clock() - t0) * 1000.0, #parts > 0 and table.concat(parts, " ") or "-"))
end
-- Only the panel on screen: every panel bound to the same corpse inventory gets the slot (2026-11-03 21:13 — a code-opened strip, removed but
-- not yet collected, fired first and the trace read its rimless grid).
local function on_screen(panel)
    local ci = panel:GetOuter():GetOuter()
    return ci and ci:IsValid() and ci:IsInViewport()
end
_G.__qlr_fn = function(panel)
    if not on_screen(panel) or _G.__qlr_live_busy then return end
    _G.__qlr_live_busy = true                  -- one chain per take: the slot fires twice in the same frame
    ExecuteInGameThreadWithDelay(300, function() _G.__qlr_live_busy = false end)
    local t0 = os.clock()
    print("[QLR] take\n")
    local n = 0
    local function step()
        n = n + 1
        pcall(snap, panel, t0)
        -- experiment _G.__qlr_exp = 'speed': every playing AnimSelect ×30 faster after the first snapshot — does the 0.3 s animation hold the old rim?
        if n == 1 and _G.__qlr_exp == "speed" then
            local ok, list = pcall(cells, panel)
            if ok then for _, c in ipairs(list) do if c:IsAnimationPlaying(c.AnimSelect) then c:SetPlaybackSpeed(c.AnimSelect, 30.0) end end end
            print("[QLR] exp speed x30\n")
        end
        if n < STEPS then ExecuteInGameThreadWithDelay(STEP_MS, step) end
    end
    ExecuteInGameThreadWithDelay(STEP_MS, step)
end
if _G.__qlr_hooked then return "already hooked; the step function replaced" end
_G.__qlr_hooked = true
RegisterHook("/Script/ConanSandbox.QuickLootPanel:SlotItemAddedOrRemoved", function(ctx)
    pcall(_G.__qlr_fn, ctx:get())
end)
RegisterHook("/Script/ConanSandbox.QuickLootPanel:SetActor", function() print("[QLR] SetActor\n") end)
return "hooked"
