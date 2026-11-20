-- palm-material-probe.lua — which mesh and material the palms near the hero use, and the leaf material's opacity-mask clip value (KUMM bug 67, lever 2:
-- «сделать листья плотнее, чтобы они не игнорировались в отрисовщике теней» — the owner, 2026-11-07 14:54). Read-only.
--   bash pult.sh "lua _G.__pm_radius=25; return dofile('D:/work/ai_sandbox/ConanExiles/_config/palm-material-probe.lua')"
-- Per distinct mesh whose name holds «palm» (any case) within the radius: the component class, the mesh, every material slot with its parent chain,
-- the base material's BlendMode, OpacityMaskClipValue and two-sided flag, and the instance's clip override if it has one.
-- [NOT-TESTED]
local R = (_G.__pm_radius or 25) * 100
local hero = FindFirstOf('BasePlayerChar_C')
local h = hero:K2_GetActorLocation()
local seen, out = {}, {}
local function mat_line(m)
    local s = m:GetFullName():match('^%S+%s+(.+)$') or m:GetFullName()
    local ok, ov = pcall(function() local o = m.BasePropertyOverrides; return o.bOverride_OpacityMaskClipValue and o.OpacityMaskClipValue or nil end)
    if ok and ov then s = s .. ' [override clip ' .. tostring(ov) .. ']' end
    local base = m
    for _ = 1, 8 do
        local okp, p = pcall(function() return base.Parent end)
        if not (okp and p and p:IsValid()) then break end
        base = p
    end
    local okb, b = pcall(function() return string.format(' | base %s blend %s clip %s twosided %s', base:GetFName():ToString(), tostring(base.BlendMode),
        tostring(base.OpacityMaskClipValue), tostring(base.TwoSided)) end)
    return s .. (okb and b or '')
end
for _, cls in ipairs({ 'InstancedStaticMeshComponent', 'HierarchicalInstancedStaticMeshComponent', 'StaticMeshComponent', 'FoliageInstancedStaticMeshComponent' }) do
    for _, c in ipairs(FindAllOf(cls) or {}) do
        -- 2026-11-07 15:01: the first version read c.StaticMesh on every component and crashed the game inside UE4SS.dll (ACCESS_VIOLATION 0x18) —
        -- templates and dead components are skipped, and the mesh is read only when it is itself a valid object
        local ok, name = pcall(function()
            if not c:IsValid() then return nil end
            local f = c:GetFullName()
            if f:find('Default__', 1, true) or f:find('/Script/', 1, true) then return nil end
            local m = c.StaticMesh
            if not (m and m:IsValid()) then return nil end
            return m:GetFName():ToString()
        end)
        if ok and name and name:lower():find('palm') and not seen[name] then
            local okl, l = pcall(function() return c:K2_GetComponentLocation() end)
            local near = okl and l and math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2) <= R
            if near or cls ~= 'StaticMeshComponent' then
                seen[name] = true
                local lines = { string.format('%s %s', cls, name) }
                local okn, n = pcall(function() return c:GetNumMaterials() end)
                for i = 0, (okn and n or 0) - 1 do
                    local okm, m = pcall(function() return c:GetMaterial(i) end)
                    if okm and m and m:IsValid() then lines[#lines + 1] = '   slot ' .. i .. ': ' .. mat_line(m) end
                end
                out[#out + 1] = table.concat(lines, '\n')
            end
        end
    end
end
return #out > 0 and table.concat(out, '\n') or 'no palm meshes found'
