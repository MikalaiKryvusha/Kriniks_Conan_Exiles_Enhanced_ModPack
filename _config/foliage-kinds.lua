-- foliage-kinds.lua — list the foliage instanced meshes loaded around the hero (mesh name, instance count, the first instance's location, its parent
-- material) so a frame check can visit foliage other than the oasis palms (KUMM bug 67 follow-up: every M_Foliage child got the 100 cm WPO bound).
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/foliage-kinds.lua')"
-- [TESTED: 2026-11-07 19:21 · 134 kinds listed at the oasis, all with parent M_Foliage; an olive tree at the listed spot rendered by frame]
local out, seen = {}, {}
for _, c in ipairs(FindAllOf('FoliageInstancedStaticMeshComponent') or {}) do
    if c:IsValid() then
        local sm = c.StaticMesh
        local name = (sm and sm:IsValid()) and sm:GetFName():ToString() or '?'
        if not seen[name] then
            seen[name] = true
            local mat = c:GetMaterial(0)
            local parent = '?'
            if mat and mat:IsValid() then
                local m = mat
                for _ = 1, 6 do
                    if m.Parent and m.Parent:IsValid() then m = m.Parent else break end
                end
                parent = m:GetFName():ToString()
            end
            local n = c:GetInstanceCount()
            local loc = '?'
            if n > 0 then
                local t = {}
                if c:GetInstanceTransform(0, t, true) and t.Translation then
                    loc = string.format('%.0f %.0f %.0f', t.Translation.X, t.Translation.Y, t.Translation.Z)
                end
            end
            out[#out + 1] = string.format('%s x%d [%s] @ %s', name, n, parent, loc)
        end
    end
end
table.sort(out)
return #out .. ' kinds: ' .. table.concat(out, ' | ')
