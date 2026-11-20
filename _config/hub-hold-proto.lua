-- hub-hold-proto.lua — PROTOTYPE of plan 48 (the owner's variant V, 2026-11-06 22:10): after a tab switch the OLD page stays on screen, the new one
-- builds invisible, and when it is complete both swap in one tick. Recon 22:13: the native switch only removes the old tab window from the viewport
-- (the object stays valid); the new window is born in the same call and ≈ 300 widgets are born over ≈ 200 ms, then none.
-- Signal «complete»: two samples in a row with no UserWidget born. Logs «[hubhold]» per switch: frames waited, ms, births.
-- Run once per game: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hub-hold-proto.lua')". [NOT-TESTED]
if _G.__hubhold_armed4 then return 'already armed' end
_G.__hubhold_armed4 = true
local TABS = { CraftingGUI_C = 1, W_FeatWindow_C = 1, W_Attributes_C = 1, W_CharacterStatsWindow_C = 1, W_NewJourneyWindow_C = 1, W_GuildView_C = 1,
    W_FollowersView_C = 1, W_FullscreenMap_C = 1, W_StoreWindow_C = 1 }
local WINDOW_Z = 40                 -- DT_UIModuleTable ZOrder of every hub tab row (kit probe 2026-11-06)
local QUIET_SAMPLES = 2             -- samples in a row with no birth = complete
local MAX_SAMPLES = 120             -- safety: show the new page anyway after this many samples
local function L(fmt, ...) print(string.format('[hubhold] ' .. fmt .. '\n', ...)) end
local cur, pending, births, sw = nil, nil, 0, 0
local function cls(w) local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end); return ok and c or '' end
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    births = births + 1
    if TABS[cls(w)] and not w:GetFullName():find('Default__', 1, true) then pending = pending or { win = w } ; pending.win = w end
end)
-- The carousel's dark backing: W_Carousel.Background, material parameter MaskOffset — 1 = no backing («Снаряжение», the world shows), 0 = backing
-- (kit probe 2026-11-06). The carousel switches it AT THE CLICK; run 6 (22:27) showed the bare world / an empty backing before the page — so the backing
-- is held in the OLD page's state and switched in the same tick as the pages.
local function set_backing(win)
    local mask = (cls(win) == 'CraftingGUI_C') and 1.0 or 0.0
    pcall(function()
        for _, c in ipairs(FindAllOf('W_Carousel_C') or {}) do
            if c:IsInViewport() then
                local bg = c:GetWidgetFromName(FName('Background'))
                bg:GetDynamicMaterial():SetScalarParameterValue(FName('MaskOffset'), mask)
            end
        end
    end)
end
local held_vis = 4                  -- SelfHitTestInvisible: what a shown tab window carries (recon 22:13: vis=4 while shown)
local function finish(old, new, k, t0, why)
    pcall(function() if old and old:IsValid() then old:RemoveFromParent() end end)
    pcall(function() if new and new:IsValid() then new:SetRenderOpacity(1.0) end end)
    set_backing(new)
    cur = new
    L('sw%d swap after %d samples, %.0f ms, births %d (%s)', sw, k, (os.clock() - t0) * 1000, births, why)
end
local function wait(old, new, k, quiet, last, t0)
    local q = (births == last) and quiet + 1 or 0
    if q >= QUIET_SAMPLES then return finish(old, new, k, t0, 'quiet') end
    if k >= MAX_SAMPLES then return finish(old, new, k, t0, 'max') end
    local b = births
    ExecuteInGameThreadWithDelay(1, function() wait(old, new, k + 1, q, b, t0) end)
end
local function on_switch()
    sw = sw + 1
    local old = cur
    local new = pending and pending.win
    pending = nil
    if not (new and new:IsValid()) or new == cur then return end   -- OnChildActivated may fire more than once per switch
    pcall(function() new:SetRenderOpacity(0.0) end)
    -- the native switch removed the old window from the viewport AND collapsed it (run 6: the bare world for 125 ms) — back, visible, as it was
    if old and old:IsValid() and old ~= new then pcall(function() old:AddToViewport(WINDOW_Z); old:SetVisibility(held_vis) end) end
    set_backing(old)
    births = 0
    wait(old, new, 0, 0, -1, os.clock())
end
for _, f in ipairs({ 'OnChildActivated' }) do   -- a mouse click goes ButtonPressed -> native SetCarouselIndex (no hook fires); OnChildActivated fires for every switch
    RegisterHook('/Script/ConanSandbox.CarouselWindow:' .. f, function() on_switch() end)
end
for c in pairs(TABS) do
    for _, w in ipairs(FindAllOf(c) or {}) do
        local n = w:GetFullName()
        if not n:find('Default__', 1, true) and not n:find(':WidgetTree.', 1, true) and w:IsInViewport() then cur = w end
    end
end
return 'armed; current: ' .. (cur and cls(cur) or 'none')
