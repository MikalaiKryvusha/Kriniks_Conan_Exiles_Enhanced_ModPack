-- native-on-kept.lua — what the NATIVE tab switch costs when every kept page is held in the viewport, collapsed (KUMM plan 48, the fork «take the
-- switch or keep the controller»). Needs the KrinikHubPersistTest dev mod. After each CarouselWindow:OnChildActivated: births counted for 600 ms
-- (the native activation of the new page), then every kept tab window NOT in the viewport is added back collapsed (its Construct births logged apart).
-- Log «[nok] swN …». [NOT-TESTED]
if _G.__nok then return 'already armed' end
_G.__nok = true
local TABS = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C',
    'W_FollowersView_C', 'W_FullscreenMap_C', 'W_StoreWindow_C' }
local function L(m) print('[nok] ' .. m .. string.char(10)) end
local births, sw, busy = 0, 0, false
NotifyOnNewObject('/Script/UMG.UserWidget', function() births = births + 1 end)
local function kept()
    local out = {}
    for _, c in ipairs(TABS) do
        for _, w in ipairs(FindAllOf(c) or {}) do
            local n = w:GetFullName()
            if not n:find('Default__', 1, true) and not n:find(':WidgetTree.', 1, true) then out[#out + 1] = { c, w } end
        end
    end
    return out
end
RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    if busy then return end
    busy = true
    sw = sw + 1
    local n = sw
    births = 0
    ExecuteInGameThreadWithDelay(600, function()
        local nat = births
        births = 0
        local readded = {}
        for _, kw in ipairs(kept()) do
            local ok, inv = pcall(function() return kw[2]:IsInViewport() end)
            if ok and not inv then pcall(function() kw[2]:AddToViewport(40); kw[2]:SetVisibility(1) end); readded[#readded + 1] = kw[1] end
        end
        ExecuteInGameThreadWithDelay(600, function()
            L(string.format('sw%d native show births %d · re-added %s · their births %d', n, nat, table.concat(readded, ','), births))
            busy = false
        end)
    end)
end)
return 'armed'
