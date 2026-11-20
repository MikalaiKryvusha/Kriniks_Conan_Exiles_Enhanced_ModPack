-- attr-pips-probe.lua — KUMM plan 49 B2 step 2 recon: how the C++ places a perk pip on a row's AttributeCanvas. For the first live W_Attribute_C row with a value,
-- prints the canvas size and every child: its class, slot position and size, and AttributePointsRequired when the child has it.
-- Use (the «Хар-ки» window open): bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-pips-probe.lua')"
-- 2026-11-10: _G.__pip_row = '<widget name part>' (e.g. 'A_Vitality') picks that row; only rows in the viewport (IsVisible) count — every row lives twice.
-- [NOT-TESTED]
local out = {}
local want = rawget(_G, '__pip_row')
for _, w in ipairs(FindAllOf('W_Attribute_C') or {}) do
  local ok, txt = pcall(function() return w.T_Current:GetText():ToString() end)
  local okv, vis = pcall(function() return w:IsVisible() end)
  local pick = (not want) or w:GetFName():ToString():find(want, 1, true)
  if w:IsValid() and ok and txt and txt ~= '' and pick and okv and vis then
    local c = w.AttributeCanvas
    local okg, geo = pcall(function() local s = c:GetCachedGeometry():GetLocalSize(); return string.format('%.0fx%.0f', s.X, s.Y) end)
    out[#out + 1] = 'row ' .. w:GetFName():ToString() .. ' ' .. txt .. ' canvas ' .. (okg and geo or '?')
    local okc, n = pcall(function() return c:GetChildrenCount() end)
    for i = 0, (okc and n or 0) - 1 do
      local ch = c:GetChildAt(i)
      local s = ch.Slot
      local okp, pos = pcall(function() local p = s:GetPosition(); local z = s:GetSize(); return string.format('(%.1f,%.1f) %.0fx%.0f', p.X, p.Y, z.X, z.Y) end)
      local okr, req = pcall(function() return ch.AttributePointsRequired end)
      local okv2, v = pcall(function() return ch:GetVisibility() end)
      out[#out + 1] = string.format('  %s %s req=%s vis=%s', ch:GetClass():GetFName():ToString(), okp and pos or '?', okr and tostring(req) or '-', okv2 and tostring(v) or '?')
    end
    break
  end
end
return #out > 0 and table.concat(out, ' | ') or 'no live row'
