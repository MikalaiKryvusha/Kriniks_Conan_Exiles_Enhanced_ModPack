-- attr-page-probe.lua — KUMM plan 49 B2 step 1: set the new `Page` of the attribute rows showing a value and re-run their UpdateView, so a frame shows the bar
-- of that page (TC_conan_attribute_paging_step1_2026-11-10 P1–P4). Rows are the live W_Attribute_C widgets with a non-empty T_Current (templates skipped).
-- Use: bash _config/pult.sh "lua _G.__pp={page=1, value='25'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-page-probe.lua')"
--   page — the page to set; value — only rows whose T_Current reads this text (nil — every row); prints «<row value>:<page>» per row touched.
-- [NOT-TESTED]
local a = _G.__pp or {}
local page = a.page or 0
local out = {}
for _, w in ipairs(FindAllOf('W_Attribute_C') or {}) do
  if w:IsValid() then
    local ok, txt = pcall(function() return w.T_Current:GetText():ToString() end)
    if ok and txt and txt ~= '' and (a.value == nil or txt == a.value) then
      -- the value from the row's own text (grouping stripped); CorruptionValue 0 — a corrupted row's purple bar empties until the game redraws it (judge 2026-11-10)
      local n = tonumber((txt:gsub('[^%d]', ''))) or 0
      local ok2, err = pcall(function() w.Page = page; w:UpdateView(n, n, 0) end)
      out[#out + 1] = txt .. ':' .. tostring(w.Page) .. (ok2 and '' or (' ERR ' .. tostring(err)))
    end
  end
end
return #out > 0 and table.concat(out, ' ') or 'no live row matched'
