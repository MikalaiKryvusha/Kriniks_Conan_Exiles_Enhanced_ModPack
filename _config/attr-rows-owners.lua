-- attr-rows-owners.lua — KUMM bug 84 recon: the live W_Attribute_C rows of «Хар-ки» come in two sets; for each row print its value, IsVisible and the
-- full name of its outer chain (which window / page owns it). Use: bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-rows-owners.lua')"
-- [NOT-TESTED]
local out = {}
for _, w in ipairs(FindAllOf('W_Attribute_C') or {}) do
  local ok, txt = pcall(function() return w.T_Current:GetText():ToString() end)
  if w:IsValid() and ok and txt and txt ~= '' then
    local vis = pcall(function() return w:IsVisible() end) and tostring(w:IsVisible()) or '?'
    local owner = '?'
    pcall(function() owner = w:GetOuter():GetOuter():GetFName():ToString() end)
    out[#out + 1] = txt .. ' vis=' .. vis .. ' outer2=' .. owner .. ' ' .. w:GetFName():ToString()
  end
end
return table.concat(out, ' | ')
