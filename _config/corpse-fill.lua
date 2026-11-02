-- corpse-fill.lua — put items into the corpse body found by corpse-face.lua (_G.__cf_body): the stand of the quick-loot cases needs ≥ 3 stacks (KUMM bug 75).
-- The call is the one KrinikConanArchery uses for arrows in a corpse (proven 2026-11-02 00:0x): ItemInventoryReplicateToAll:AddItemTemplate(id, −1, None, n,
-- true, 1, 0). Items: _G.__cf_items = { {id, n}, … } or iron arrows ×5, bone arrows ×7, a hunting bow ×1.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/corpse-fill.lua')"   [NOT-TESTED]
local b = _G.__cf_body
if not b then return "no _G.__cf_body — run corpse-face.lua first" end
local items = _G.__cf_items or { { 53612, 5 }, { 51184, 7 }, { 51405, 1 } }
local best, bd
for _, x in ipairs(FindAllOf("Corpse_C") or {}) do
    local f = x:GetFullName()
    if not f:find("Default__", 1, true) then
        local ok, l = pcall(function()
            return x:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SkeletalMeshComponent"))[1]:get():K2_GetComponentLocation()
        end)
        if ok and l then
            local d = math.abs(l.X - b.X) + math.abs(l.Y - b.Y) + math.abs(l.Z - b.Z)
            if not bd or d < bd then best, bd = x, d end
        end
    end
end
if not best or bd > 10 then return "the corpse of _G.__cf_body not found" end
local inv = best.ItemInventoryReplicateToAll
for _, it in ipairs(items) do inv:AddItemTemplate(it[1], -1, FName("None"), it[2], true, 1, 0) end
local n = 0
for _, it in ipairs(items) do n = n + inv:GetNumberOfItemsByTemplate(it[1]) end
return string.format("%s: added %d kinds, items of them now %d", best:GetFName():ToString(), #items, n)
