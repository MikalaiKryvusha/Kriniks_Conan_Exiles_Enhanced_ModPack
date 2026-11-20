-- attr-pager-look.lua — KUMM plan 49 step 2, the look pass: move our page arrows and the page number on the LIVE attribute rows by render translation, to
-- pick the places by frames before baking them into the kit (the owner 2026-11-10 10:06: arrows under the scale at its ends, the numbers above).
-- Children of the row's `Progress` (the «+»'s parent): 2 = Btn_KrinikPagePrev, 3 = Btn_KrinikPageNext, 4 = Txt_KrinikPage.
-- Use: bash _config/pult.sh "lua _G.__pl={prev={-10,30}, next={10,30}, label={20,-30}, text='40', page=1, value='26'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-pager-look.lua')"
--   prev / next / label — {X, Y} render translation in widget units; text — the label's text for the look; page / value — also set Page on the row whose
--   value is `value` and re-run its UpdateView chain via the game's signal (optional).
-- Changes only render translations, the label text and Page of live widgets; a reopen of the window resets them.
-- [NOT-TESTED]
local p = _G.__pl or {}
local out = {}
for _, row in ipairs(FindAllOf('W_Attribute_C') or {}) do
  local full = row:GetFullName()
  if row:IsValid() and not full:find(':WidgetTree.', 1, true) and not full:find('Default__', 1, true) then
    local ok = pcall(function()
      local prog = row.LevelAttributeButton:GetParent()
      local function tr(i, v)
        if v then prog:GetChildAt(i):SetRenderTranslation({ X = v[1] * 1.0, Y = v[2] * 1.0 }) end
      end
      tr(2, p.prev); tr(3, p.next); tr(4, p.label)
      if p.text then prog:GetChildAt(4):SetText(FText(p.text)) end
      local val = row.T_Current:GetText():ToString()
      if p.page and p.value and val == p.value then
        row.Page = p.page
        row:UpdateView(tonumber(p.value), tonumber(p.value), 0)
        out[#out + 1] = 'page ' .. p.page .. ' on ' .. val
      end
    end)
    out[#out + 1] = (ok and 'ok ' or 'fail ') .. row:GetFName():ToString()
  end
end
return table.concat(out, ' | ')
