-- carousel-mode.lua — KUMM bug 84: is the open carousel the HUB (tab row shown) or a standalone module (the map by M — no tab row)? Prints, per live
-- W_Carousel_C: viewport, its own visibility, the tab row `TabButtonBox` / `SizeBox_0` visibility and the native fields the controller could read.
-- Use: bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/carousel-mode.lua')"   (read-only)
-- [NOT-TESTED]
local out = {}
for _, w in ipairs(FindAllOf('W_Carousel_C') or {}) do
  local full = w:GetFullName()
  if not full:find('Default__', 1, true) and not full:find(':WidgetTree.', 1, true) then
    local r = { w:GetFName():ToString(), 'vp=' .. tostring(w:IsInViewport()), 'vis=' .. tostring(w:GetVisibility()) }
    for _, f in ipairs({ 'TabButtonBox', 'SizeBox_0', 'VerticalBox_3', 'ImageLeft', 'ImageRight' }) do
      local ok, v = pcall(function() return w[f]:GetVisibility() end)
      r[#r + 1] = f .. '=' .. (ok and tostring(v) or 'n/a')
    end
    for _, f in ipairs({ 'CurrentIndex', 'CarouselIndex', 'ActiveIndex', 'bShowTabs', 'IsSingleWindow' }) do
      local ok, v = pcall(function() return w[f] end)
      if ok and v ~= nil then r[#r + 1] = f .. '=' .. tostring(v) end
    end
    local ok, n = pcall(function() return #w.CarouselWindowNames end)
    r[#r + 1] = 'names=' .. (ok and tostring(n) or 'n/a')
    out[#out + 1] = table.concat(r, ' ')
  end
end
return 'carousels ' .. #out .. ': ' .. table.concat(out, ' | ')
