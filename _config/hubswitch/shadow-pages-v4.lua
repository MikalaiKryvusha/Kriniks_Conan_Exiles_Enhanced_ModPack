-- shadow-pages-v4.lua — plan 48 controller core from the code that SURVIVED bisect 3 (2026-11-07 00:25): our 9 pages created at once (extra-pages-switch.lua),
-- hidden ones HitTestInvisible at opacity 0; the hook: opacity inside the native switch, visibility the next tick. No lazy chain, no prints in callbacks
-- (the v3 script crashed; its differences are left out). Run after the hub is open. Log via _G counters only. [NOT-TESTED]
dofile('D:/work/ai_sandbox/ConanExiles/_config/hubswitch/extra-pages-switch.lua')
local IDX = { CraftingGUI_C = 1, W_FeatWindow_C = 2, W_Attributes_C = 3, W_CharacterStatsWindow_C = 4, W_NewJourneyWindow_C = 5, W_GuildView_C = 6,
    W_FollowersView_C = 7, W_FullscreenMap_C = 8, W_StoreWindow_C = 9 }
for _, w in ipairs(_G.__ep) do w:SetVisibility(3) end
_G.__v4 = { switches = 0, shown = nil }
NotifyOnNewObject('/Script/UMG.UserWidget', function(w)
    local ok, c = pcall(function() return w:GetClass():GetFName():ToString() end)
    if ok and IDX[c] then _G.__v4nb = { IDX[c], w } end
end)
RegisterHook('/Script/ConanSandbox.CarouselWindow:OnChildActivated', function()
    local nb = _G.__v4nb
    _G.__v4nb = nil
    if not nb then return end
    local ours, prev, gw = _G.__ep[nb[1]], _G.__v4.shown, nb[2]
    if not ours then return end
    pcall(function() gw:SetRenderOpacity(0.0) end)
    if prev then pcall(function() prev:SetRenderOpacity(0.0) end) end
    pcall(function() ours:SetRenderOpacity(1.0) end)
    _G.__v4.shown = ours
    ExecuteInGameThreadWithDelay(1, function()
        pcall(function() gw:SetVisibility(3) end)
        if prev then pcall(function() prev:SetVisibility(3) end) end
        pcall(function() ours:SetVisibility(4) end)
        _G.__v4.switches = _G.__v4.switches + 1
    end)
end)
return 'v4 armed, pages ' .. #_G.__ep
