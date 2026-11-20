-- live-rows.lua — the LIVE value of chosen fields of chosen rows of a game data table, side by side with the same fields of one mod's own table.
-- Why (2026-11-06, KUMM plan 45 step 4): a file-level reading of two mods' rows called 17 boss rows «LOST» under Heritage, while the live table of
-- 2026-10-26 (docs/17, item 3) showed the game merging rows FIELD BY FIELD. Step 5 of the reconciliation guide (verify by the game) needs the live
-- value of every merged field in one call.
-- Every field is read as TEXT by the engine's own exporter `DataTableFunctionLibrary:GetDataTableColumnAsString(table, column)` — the same text for an
-- object, a name, an array or a soft class. Reading the row's property in Lua instead gives an opaque `TSoftObjectPtrUserdata` for soft pointers, and
-- handing that userdata to a UFunction crashed the game (2026-11-06 11:02, KUMM EXP-0459): the only parameters here are an object and a name.
--   bash _config/pult.sh "lua _G.__lr={table='/Game/Systems/SpawnTable/SpawnDataTable.SpawnDataTable', mod='/Game/Mods/BossesMyNewBesties/BMNB_SpawnDataTable.BMNB_SpawnDataTable', rows={'Keymaster'}, fields={'NPCClass'}}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/live-rows.lua')"
-- Prints one line per row and field: «row · field · live=<v> · mod=<v> · SAME|DIFF», then a summary per field. Read-only: changes nothing.
-- [NOT-TESTED]
local P = _G.__lr or {}
local function valid(o) return o ~= nil and o.IsValid and o:IsValid() end
local LIB = StaticFindObject('/Script/Engine.Default__DataTableFunctionLibrary')

-- row names in the table's order: the exporter walks the same row map, so the n-th text is the n-th row
local function names(dt)
    local out = {}
    dt:ForEachRow(function(name, _) out[#out + 1] = type(name) == "string" and name or name:ToString() end)
    return out
end

local function read(dt, want, fields)
    local rows, out = names(dt), {}
    for _, f in ipairs(fields) do
        local col = LIB:GetDataTableColumnAsString(dt, FName(f))
        local texts = {}
        local function txt(x)
            if type(x) == "string" then return x end
            local ok, v = pcall(function() return x:get() end)
            if ok and v ~= nil then x = v end
            if type(x) == "string" then return x end
            local ok2, s = pcall(function() return x:ToString() end)
            return ok2 and s or tostring(x)
        end
        -- UE4SS hands a returned TArray back as a plain Lua table (seen 2026-11-06 11:06: no ForEach on it); a TArray userdata — by ForEach
        if type(col) == "table" then
            for _, e in ipairs(col) do texts[#texts + 1] = txt(e) end
        else
            col:ForEach(function(_, e) texts[#texts + 1] = txt(e) end)
        end
        if #texts ~= #rows then return nil, ("column %s: %d texts for %d rows"):format(f, #texts, #rows) end
        for i, r in ipairs(rows) do
            if want[r] then
                out[r] = out[r] or {}
                out[r][f] = texts[i]
            end
        end
    end
    return out
end

if not valid(LIB) then return "no DataTableFunctionLibrary" end
local live = StaticFindObject(P.table)
if not valid(live) then return "no live table " .. tostring(P.table) end
local mod = P.mod and StaticFindObject(P.mod)
if P.mod and not valid(mod) then mod = LoadAsset(P.mod) end
local want = {}
for _, r in ipairs(P.rows or {}) do want[r] = true end
local fields = P.fields or {}
local L, e1 = read(live, want, fields)
if not L then return "live: " .. e1 end
local M, e2 = {}, nil
if valid(mod) then
    M, e2 = read(mod, want, fields)
    if not M then return "mod: " .. e2 end
end
local lines, same, diff = {}, {}, {}
for _, r in ipairs(P.rows or {}) do
    for _, f in ipairs(fields) do
        local lv = L[r] and L[r][f] or "<no row>"
        local mv = M[r] and M[r][f] or "<no row>"
        local eq = lv == mv
        lines[#lines + 1] = ("%s · %s · live=%s · mod=%s · %s"):format(r, f, lv, mv, eq and "SAME" or "DIFF")
        if eq then same[f] = (same[f] or 0) + 1 else diff[f] = (diff[f] or 0) + 1 end
    end
end
lines[#lines + 1] = "-- summary (live vs mod) --"
for _, f in ipairs(fields) do lines[#lines + 1] = ("%s: SAME %d · DIFF %d"):format(f, same[f] or 0, diff[f] or 0) end
lines[#lines + 1] = "mod table " .. (valid(mod) and "read" or "NOT FOUND")
return table.concat(lines, "\n")
