-- plus-tint-probe.lua — KUMM plan 49 G1: does Slate clamp a button brush tint above 1.0? Sets the Normal tint of every live attribute row's «+»
-- (LevelAttributeButton) to the given linear RGB, so a frame can compare (live only; a reopen of the window or a new game session brings the asset's back).
-- Use: bash _config/pult.sh "lua _G.__pt={1.0, 0.987, 0.454}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/plus-tint-probe.lua')"
-- Prints the tint read back per row. Answered 2026-11-14 00:5x: yes — R 1.5623 and 1.0 drew the same pixels, R 0.3 differed.
-- [TESTED: 2026-11-14 · the clamp A-B of case K5 · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
local t = _G.__pt
_G.__pt = nil                                   -- a later run without arguments must not reuse this run's values
if type(t) ~= 'table' or type(t[1]) ~= 'number' or type(t[2]) ~= 'number' or type(t[3]) ~= 'number' then   -- three numbers or nothing (round 3, 7)
  return 'usage: _G.__pt={R, G, B} — three numbers (the asset now draws our texture at tint 1.0 — no default is right)'
end
local out = {}
for _, w in ipairs(FindAllOf('W_Attribute_C') or {}) do
  local okn, f = pcall(function() return w:IsValid() and w:GetFullName() or nil end)
  if okn and f and not f:find(':WidgetTree.', 1, true) and not f:find('Default__', 1, true) then
    local ok, err = pcall(function()
      local b = w.LevelAttributeButton
      local st = b.WidgetStyle
      st.Normal.TintColor.SpecifiedColor = { R = t[1], G = t[2], B = t[3], A = 1.0 }
      b:SetStyle(st)
      local x = b.WidgetStyle.Normal.TintColor.SpecifiedColor
      out[#out + 1] = string.format('%.3f,%.3f,%.3f', x.R, x.G, x.B)
    end)
    if not ok then out[#out + 1] = 'ERR ' .. tostring(err) end
  end
end
return #out > 0 and table.concat(out, ' ') or 'no live row'
