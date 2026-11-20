-- wind.lua — foliage wind off / back on by the remote (KUMM bug 67: the second factor of the palm-leaf shadow flicker, `[OWNER]` 2026-11-07 17:16
-- «и еще колебания листов на ветру»). The palms sway by `MPC_BiomeSettings` scalars `WindIntensity`, `Wind Speed`, `Wind Strength` (live 0.1 each) and the
-- level's WindDirectionalSource components (strength 0.1, speed 3.482) — game map, «foliage sway». First call remembers the live values in _G.__wind_live.
--   bash pult.sh "lua _G.__wind=0; return dofile('D:/work/ai_sandbox/ConanExiles/_config/wind.lua')"   -- all 0 = still palms
--   bash pult.sh "lua _G.__wind=1; return dofile('D:/work/ai_sandbox/ConanExiles/_config/wind.lua')"   -- back to the remembered live values
-- [TESTED: 2026-11-07 17:17 · off → all three scalars and three sources 0; on → the remembered live values back (WindIntensity 0.195, sources 0.1, src3 speed 3.902);
--  17:33 `read` → «WindIntensity=0.167 … src3 0.100/3.343» (the weather moves WindIntensity and the source speed), nothing set]
--   bash pult.sh "lua _G.__wind='read'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/wind.lua')" -- read only (the weather changes the wind)
local mode = _G.__wind or 0
local on = mode ~= 0
local pc = FindFirstOf('FunCombat_PlayerController_C')
local KML = StaticFindObject('/Script/Engine.Default__KismetMaterialLibrary')
local NAMES = { 'WindIntensity', 'Wind Speed', 'Wind Strength' }
local mpc
for _, o in ipairs(FindAllOf('MaterialParameterCollection') or {}) do
    if o:GetFName():ToString() == 'MPC_BiomeSettings' then mpc = o end
end
if not mpc then return 'MPC_BiomeSettings not found' end
local srcs = FindAllOf('WindDirectionalSourceComponent') or {}
if mode == 'read' then
    local r = {}
    for _, n in ipairs(NAMES) do r[#r + 1] = n .. '=' .. string.format('%.3f', KML:GetScalarParameterValue(pc, mpc, FName(n))) end
    for i, c in ipairs(srcs) do r[#r + 1] = string.format('src%d %.3f/%.3f', i, c.Strength, c.Speed) end
    return 'wind now: ' .. table.concat(r, ' ')
end
if not _G.__wind_live then
    local live = { mpc = {}, src = {} }
    for _, n in ipairs(NAMES) do live.mpc[n] = KML:GetScalarParameterValue(pc, mpc, FName(n)) end
    for i, c in ipairs(srcs) do live.src[i] = { c.Strength, c.Speed } end
    _G.__wind_live = live
end
local live, out = _G.__wind_live, {}
for _, n in ipairs(NAMES) do
    local v = on and live.mpc[n] or 0.0
    KML:SetScalarParameterValue(pc, mpc, FName(n), v)
    out[#out + 1] = n .. '=' .. string.format('%.3f', KML:GetScalarParameterValue(pc, mpc, FName(n)))
end
for i, c in ipairs(srcs) do
    local s = live.src[i] or { 0.1, 3.482 }
    c:SetStrength(on and s[1] or 0.0)
    c:SetSpeed(on and s[2] or 0.0)
    out[#out + 1] = string.format('src%d %.3f/%.3f', i, c.Strength, c.Speed)
end
return (on and 'wind ON: ' or 'wind OFF: ') .. table.concat(out, ' ')
