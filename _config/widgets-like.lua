-- widgets-like.lua — list live UserWidgets whose class name matches any of _G.__wl (a list of plain substrings): class, visible, render opacity,
-- in the viewport — one per line (KUMM bug 84: which page / dialog / tutorial is alive and how it is shown).
--   bash pult.sh "lua _G.__wl={'Perk','Trait','Attribute','Tutorial'}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/widgets-like.lua')"
-- [TESTED: 2026-11-07 19:5x - listed the live perk / attribute widgets in the owner session (two W_Attributes_C found, KUMM bug 84)]
local pats = _G.__wl or { 'Perk' }
local out = {}
for _, w in ipairs(FindAllOf('UserWidget') or {}) do
    if w:IsValid() then
        local n = w:GetClass():GetFName():ToString()
        for _, p in ipairs(pats) do
            if n:find(p, 1, true) then
                out[#out + 1] = string.format('%s %s op%.2f vp%s', n, w:IsVisible() and 'VIS' or 'hid', w:GetRenderOpacity(), tostring(w:IsInViewport()))
                break
            end
        end
    end
end
table.sort(out)
return #out .. ' widgets\n' .. table.concat(out, '\n')
