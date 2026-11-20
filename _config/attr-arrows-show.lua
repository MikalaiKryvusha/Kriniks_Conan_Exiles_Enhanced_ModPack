-- attr-arrows-show.lua — make the page arrows of the live attribute rows that show a given value visible for a frame (KUMM plan 49 / the 3.1.0 kit session
-- 2026-11-14, case K7): the kit's own Btn_KrinikPagePrev / Btn_KrinikPageNext (children 2 / 3 of the row's `Progress`, attr-pager-look.lua), with their real
-- brushes — the look of the textures without giving the hero points past 20. Prev disabled (the Dim brush), Next enabled (normal). Live only; a reopen of
-- «Хар-ки» redraws the truth.
-- Use: bash _config/pult.sh "lua _G.__as={value='1'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-arrows-show.lua')"
--   value — every live row whose shown value reads this text: the hub controller keeps a second set of pages, so the FIRST match in FindAllOf order may be a
--   hidden copy (seen 2026-11-14 01:0x — a row «changed» by the remote while the screen kept the old one); all matches are changed.
-- [TESTED: 2026-11-14 · K7 of TC_conan_kit_310_our_mods: the arrows drawn on the visible «Сила» row · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
local args = _G.__as
_G.__as = nil                                   -- cleared FIRST: a bad argument must not stick for later bare runs (round 3, 6)
local want = tostring(type(args) == 'table' and args.value or '1')   -- a number given (value=1) still matches the row's text
local out = {}
for _, w in ipairs(FindAllOf('W_Attribute_C') or {}) do
  local okn, f = pcall(function() return w:IsValid() and w:GetFullName() or nil end)
  if okn and f and not f:find(':WidgetTree.', 1, true) and not f:find('Default__', 1, true) then
    local ok, txt = pcall(function() return w.T_Current:GetText():ToString() end)
    if ok and txt == want then
      local ok2, err = pcall(function()
        local prog = w.LevelAttributeButton:GetParent()
        local prev, nxt = prog:GetChildAt(2), prog:GetChildAt(3)
        -- only our kit's buttons are touched: an older UI pak may hold other widgets there (judge 2026-11-14 round 2, D4)
        if prev:GetFName():ToString() ~= 'Btn_KrinikPagePrev' or nxt:GetFName():ToString() ~= 'Btn_KrinikPageNext' then
          error('children 2/3 are not our page arrows: ' .. prev:GetFName():ToString() .. ' / ' .. nxt:GetFName():ToString())
        end
        prev:SetVisibility(0); nxt:SetVisibility(0)
        prev:SetIsEnabled(false); nxt:SetIsEnabled(true)
        out[#out + 1] = prev:GetFName():ToString() .. '/' .. nxt:GetFName():ToString() .. ' next=' .. nxt.WidgetStyle.Normal.ResourceObject:GetFName():ToString()
          .. ' prevDim=' .. prev.WidgetStyle.Disabled.ResourceObject:GetFName():ToString()
      end)
      if not ok2 then out[#out + 1] = 'ERR ' .. tostring(err) end
    end
  end
end
return #out > 0 and table.concat(out, ' | ') or ('no live row reads ' .. want)
