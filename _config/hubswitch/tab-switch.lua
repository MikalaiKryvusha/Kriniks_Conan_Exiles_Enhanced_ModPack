-- tab-switch.lua — switch every live hub carousel to tab _G.__tab (carousel index: 0 Снаряжение, 1 Таланты, 2 Хар-ки, 3 Параметры, 4 Путешествие, 5 Клан,
-- 6 Спутники, 7 Карта, 8 Базар) by the native `CarouselWindow:SetCarouselIndex` — the function a tab click reaches. The hub must be open (open-tab.lua).
-- KUMM bug 101 item 3 (2026-11-14): the background twin of a real tab click for window-capture recordings. [NOT-TESTED]
local tab = _G.__tab
_G.__tab = nil
if type(tab) ~= 'number' then return 'set _G.__tab first' end
local n = 0
for _, c in ipairs(FindAllOf('CarouselWindow') or {}) do
    local ok, live = pcall(function() return c:IsValid() and not c:GetFullName():find('Default__', 1, true) and c:IsInViewport() end)
    if ok and live and pcall(function() c:SetCarouselIndex(tab) end) then n = n + 1 end   -- count only a switch that ran (judge 15:43)
end
return 'tab ' .. tab .. ' on ' .. n
