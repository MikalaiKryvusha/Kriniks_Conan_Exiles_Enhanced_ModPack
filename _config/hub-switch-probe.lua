-- hub-switch-probe.lua — what happens to the hub's pages around one tab switch (KUMM plan 48 step 1; bug 64 items 15/17). Read-only.
-- Arms once: hooks CarouselWindow Next/Prev/SetCarouselIndex (post) and NotifyOnNewObject on UserWidget; after a switch, for 40 samples ≈ 5 ms apart
-- (ExecuteInGameThreadWithDelay chain — about one per frame) logs: the old page window (the tab window alive before the switch) — valid? in viewport? visible?;
-- the new page window — born when, its desired size; the count of UserWidgets born since the switch. Times — the UE4SS log's own timestamps (wall clock).
-- Run: bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hub-switch-probe.lua')"; then switch tabs; read UE4SS.log «[hubprobe]».
-- [NOT-TESTED]
if _G.__hubprobe_armed then return 'already armed' end
_G.__hubprobe_armed = true
local TAB_CLASSES = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C',
    'W_FollowersView_C', 'W_FullscreenMap_C', 'W_StoreWindow_C' }
local function tabclass(n) for _, c in ipairs(TAB_CLASSES) do if n:find(c, 1, true) then return c end end end
local function L(fmt, ...) print(string.format('[hubprobe] ' .. fmt .. '\n', ...)) end
local cur, sw, births = nil, 0, 0          -- the current tab window (UE4SS object), switch number, births since the switch
local newwin = nil
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    local n = w:GetFullName()
    if n:find('Default__', 1, true) or n:find(':WidgetTree.', 1, true) and not n:find('WidgetTree_', 1, true) then return end
    births = births + 1
    local c = tabclass(n)
    if c then newwin = w; L('sw%d birth #%d TAB WINDOW %s', sw, births, c) end
end)
local function desired(w)
    local ok, s = pcall(function() w:ForceLayoutPrepass(); return w:GetDesiredSize() end)
    if ok and s then return string.format('%.0fx%.0f', s.X, s.Y) end
    return '?'
end
local function state(w)
    if not w then return 'nil' end
    local ok, v = pcall(function() return w:IsValid() end)
    if not (ok and v) then return 'INVALID' end
    local a, inv = pcall(function() return w:IsInViewport() end)
    local b, vis = pcall(function() return w:GetVisibility() end)
    return string.format('valid inVP=%s vis=%s', a and tostring(inv) or '?', b and tostring(vis) or '?')
end
local function sample(k, old)
    L('sw%d s%02d births=%d old[%s] new[%s %s]', sw, k, births, state(old), newwin and 'born' or 'none', newwin and desired(newwin) or '-')
    if k < 40 then ExecuteInGameThreadWithDelay(5, function() sample(k + 1, old) end) else cur = newwin end
end
local function on_switch(name)
    sw = sw + 1
    local old = cur or newwin
    births = 0
    newwin = nil
    L('sw%d %s called; old %s', sw, name, state(old))
    sample(0, old)
end
for _, f in ipairs({ 'NextCarouselWindow', 'PrevCarouselWindow', 'SetCarouselIndex' }) do
    RegisterHook('/Script/ConanSandbox.CarouselWindow:' .. f, function() on_switch(f) end)
end
-- the window shown now = the newest live tab window
for _, c in ipairs(TAB_CLASSES) do
    for _, w in ipairs(FindAllOf(c) or {}) do
        local n = w:GetFullName()
        if not n:find('Default__', 1, true) and not n:find(':WidgetTree.', 1, true) then cur = w end
    end
end
return 'armed; current tab window: ' .. (cur and cur:GetFullName() or 'none')
