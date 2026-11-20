-- class-funcs.lua — KUMM recon helper (read-only): the UFunctions of a class and of its supers whose name matches a Lua pattern.
--   pult.sh "lua _G.__cf = {class='/Game/Characters/BasePlayerChar.BasePlayerChar_C', match={'ield', 'heath', 'quip', 'olster'}}; return dofile('…/class-funcs.lua')"
-- `match` — one plain substring or a list of them, case-insensitive (Lua patterns have no «|»). The remote's `funcs` needs an object path end; this walks the
-- class chain itself (UE4SS UClass:ForEachFunction, UStruct:GetSuperStruct). [NOT-TESTED]
local cfg = _G.__cf or {}
local cls = StaticFindObject(cfg.class or '/Game/Characters/BasePlayerChar.BasePlayerChar_C')
if not (cls and cls:IsValid()) then return 'class not found: ' .. tostring(cfg.class) end
local pats = type(cfg.match) == 'table' and cfg.match or { cfg.match or '' }
local function hit(n)
    local l = n:lower()
    for _, p in ipairs(pats) do if l:find(p:lower(), 1, true) then return true end end
    return false
end
local out, seen, depth = {}, {}, 0
while cls and cls:IsValid() and depth < 12 do
    local cname = cls:GetFName():ToString()
    cls:ForEachFunction(function(f)
        local n = f:GetFName():ToString()
        if hit(n) and not seen[n] then seen[n] = true; out[#out + 1] = cname .. ':' .. n end
    end)
    cls = cls:GetSuperStruct()
    depth = depth + 1
end
table.sort(out)
return #out .. ' functions\n' .. table.concat(out, '\n')
