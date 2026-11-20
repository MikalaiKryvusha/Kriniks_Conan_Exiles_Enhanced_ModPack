-- bow-stand.lua — KUMM stand helper (TC_conan_fp_bow_visible, plan 52): the honest bow stand of the game map «Stand gear» in one remote call.
-- Read-only by default: how many crafted bows 51401 and arrows 53612 the hero carries (quick bar · backpack). `_G.__bs = {craft = true}` — the ingredients
-- (10012 × 7, 12001 × 7, 14174 × 7) into the backpack by AddItemTemplate and the hero CRAFTS the bow (an AddItemTemplate bow cannot be wielded — game map),
-- plus 20 arrows when none. The bow lands on the quick bar; a real hot-bar key wields it (a FREE PC only, HOUSE_RULES rule 30). [NOT-TESTED]
-- !! 2026-11-16 19:18 on 3.1.0: `{craft = true}` CRASHED the game (EXCEPTION_ACCESS_VIOLATION reading 0x70, 2 s into the call) — most likely the remote CraftItems on the
-- queue the 3.1.0 patch rewrote (KUMM bugs/93). Do not run the craft branch until the call is re-read against 3.1.0; the read-only count is safe.
local cfg = _G.__bs or {}
local h = FindFirstOf('FunCombat_PlayerController_C'):K2_GetPawn()
local BOW, ARROW = 51401, 53612
local function n(inv, id)
    if not (inv and inv:IsValid()) then return -1 end
    local ok, v = pcall(function() return inv:GetNumberOfItemsByTemplate(id) end)
    return ok and v or -2
end
local out = {}
local function report(tag)
    out[#out + 1] = string.format('%s: bow %d/%d (bar/backpack) · arrows %d/%d', tag, n(h.ShortcutBarInventory, BOW), n(h.BackpackInventory, BOW),
        n(h.ShortcutBarInventory, ARROW), n(h.BackpackInventory, ARROW))
end
report('before')
if cfg.craft then
    local bp = h.BackpackInventory
    for _, id in ipairs({ 10012, 12001, 14174 }) do bp:AddItemTemplate(id, -1, nil, 7, true, 1, 0) end
    if n(h.BackpackInventory, ARROW) + n(h.ShortcutBarInventory, ARROW) <= 0 then bp:AddItemTemplate(ARROW, -1, nil, 20, true, 1, 0) end
    local rm = FindFirstOf('RecipeManager')
    local recipe = rm and rm:IsValid() and rm:GetItemByTemplateID(BOW, 0)
    if not recipe then return table.concat(out, '\n') .. '\nno recipe object for ' .. BOW end
    h.CraftingQueue:CraftItems(recipe)
    out[#out + 1] = 'craft queued (the bow 51401 takes 3 s) — read again in 5 s'
end
return table.concat(out, '\n')
