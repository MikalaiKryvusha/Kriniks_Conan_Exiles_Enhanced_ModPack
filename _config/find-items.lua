-- find-items.lua — ids and names of the game's items whose Name contains _G.__fi (plain substring), read from the live ItemTable (no guessing ids).
--   bash pult.sh "lua _G.__fi='Bow'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/find-items.lua')"
-- [NOT-TESTED]
local pat = _G.__fi or 'Bow'
local DTL = StaticFindObject('/Script/Engine.Default__DataTableFunctionLibrary')
local tbl
for _, t in ipairs(FindAllOf('DataTable') or {}) do
    if t:GetFName():ToString() == 'ItemTable' then tbl = t break end
end
if not tbl then return 'ItemTable not loaded' end
local names = DTL:GetDataTableColumnAsString(tbl, FName('Name'))
local rows = {}
DTL:GetDataTableRowNames(tbl, rows)
local out = {}
for i = 1, #names do
    local n = names[i]
    if type(n) ~= 'string' then n = (n.ToString and n:ToString()) or tostring(n) end
    if n:find(pat, 1, true) then
        local r = rows[i]
        if r ~= nil and type(r) ~= 'string' then r = (r.ToString and r:ToString()) or tostring(r) end
        out[#out + 1] = tostring(r) .. ' ' .. n
    end
end
return #out .. ' items: ' .. table.concat(out, ' | ')
