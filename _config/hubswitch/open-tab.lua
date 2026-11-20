-- open the hub (if closed) and switch every live CarouselWindow to tab _G.__tab (0 Снаряжение, 1 Таланты, 2 Хар-ки, 3 Параметры, 4 Путешествие …)
local tab = _G.__tab or 4; _G.__tab = nil
local gc = FindFirstOf('GUIModuleController')
if not gc or not gc:IsValid() then return 'no GUIModuleController' end
gc:ActivateModule(FName('Inventory'), true, false)
ExecuteInGameThreadWithDelay(400, function()   -- game thread: ExecuteWithDelay runs on a worker thread (the bug 66 crash class)
  do
    local n = 0
    for _, c in ipairs(FindAllOf('CarouselWindow') or {}) do
      if c:IsValid() and not c:GetFullName():find('Default__', 1, true) and pcall(function() c:SetCarouselIndex(tab) end) then n = n + 1 end
    end
    _G.__open_tab = 'tab ' .. tab .. ' on ' .. n
  end
end)
return 'activated; tab ' .. tab .. ' in 400 ms'
