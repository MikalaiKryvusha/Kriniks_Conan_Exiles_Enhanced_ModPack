-- hub-dupes.lua — KUMM bug 84: how many live windows of each hub tab exist now, and which of them are in the viewport / visible / opaque. The game keeps one
-- window per tab (plan 48); two in the viewport is the stack of bug 84 (a trait dialog under the attribute tree, the map stuck twice).
-- Use: bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/hub-dupes.lua')"
-- Read-only: nothing is changed. Class templates (…:WidgetTree. / Default__) are skipped.
-- [NOT-TESTED]
local CLASSES = { 'W_Attributes_C', 'W_FullscreenMap_C', 'W_CharacterStatsWindow_C', 'W_FeatWindow_C', 'CraftingGUI_C' }
local out = {}
for _, c in ipairs(CLASSES) do
  local n, inv, rows = 0, 0, {}
  for _, w in ipairs(FindAllOf(c) or {}) do
    local full = ''
    pcall(function() full = w:GetFullName() end)
    if w:IsValid() and not full:find('Default__', 1, true) and not full:find(':WidgetTree.', 1, true) then
      n = n + 1
      local iv, vis, op = '?', '?', '?'
      local VN = { [0] = 'Visible', [1] = 'Collapsed', [2] = 'Hidden', [3] = 'HitTestInvisible', [4] = 'SelfHitTestInvisible' }
      pcall(function() iv = tostring(w:IsInViewport()) end)
      pcall(function() local v = w:GetVisibility(); vis = VN[v] or tostring(v) end)   -- the enum, not IsVisible: HitTestInvisible reads «visible» there
      pcall(function() op = string.format('%.2f', w:GetRenderOpacity()) end)
      if iv == 'true' then inv = inv + 1 end
      rows[#rows + 1] = w:GetFName():ToString() .. '(vp=' .. iv .. ' vis=' .. vis .. ' op=' .. op .. ')'
    end
  end
  out[#out + 1] = c .. ': ' .. n .. ' live, ' .. inv .. ' in viewport ' .. table.concat(rows, ' ')
end
return table.concat(out, ' | ')
