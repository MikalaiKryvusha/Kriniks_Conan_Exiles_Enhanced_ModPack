-- page-census.lua — plan 48: how many instances of each hub page class are ALIVE and how many are in the viewport, WITHOUT touching our own Lua refs
-- (_G.__ep). Born 2026-11-07 06:3x: the F2 step crashed on `SetRenderOpacity` over _G.__ep 36 s after the pages were created — one of our pages was
-- freed (GC) while Lua still held its raw pointer. FindAllOf returns live objects only, so the census is safe where a stale ref is not. [NOT-TESTED]
local CL = { 'CraftingGUI_C', 'W_FeatWindow_C', 'W_Attributes_C', 'W_CharacterStatsWindow_C', 'W_NewJourneyWindow_C', 'W_GuildView_C', 'W_FollowersView_C',
  'W_FullscreenMap_C', 'W_StoreWindow_C' }
local out = {}
for _, c in ipairs(CL) do
  local n, vp = 0, 0
  for _, w in ipairs(FindAllOf(c) or {}) do
    local okn, name = pcall(function() return w:GetFullName() end)
    if okn and not name:find('Default__', 1, true) then
      n = n + 1
      local ok, v = pcall(function() return w:IsInViewport() end)
      if ok and v then vp = vp + 1 end
    end
  end
  out[#out + 1] = c:gsub('_C$', ''):gsub('^W_', '') .. ' ' .. n .. '/' .. vp
end
return table.concat(out, ' · ')
