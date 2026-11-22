-- map_count.lua — bug 84 M1/M2 (2026-11-22 20:4x): the live W_FullscreenMap_C instances in the viewport (opacity, visibility) and the hub / map modules.
-- A one-shot read; returns one line.
local out = {}
for _, w in ipairs(FindAllOf("W_FullscreenMap_C") or {}) do
    local okn, fn = pcall(function() return w:GetFullName() end)
    if okn and fn and not fn:find("Default__", 1, true) and not fn:find(":WidgetTree.", 1, true) then
        local up, op, vis = "?", "?", "?"
        pcall(function() up = tostring(w:IsInViewport()) end)
        pcall(function() op = ("%.2f"):format(w:GetRenderOpacity()) end)
        pcall(function() vis = tostring(w:GetVisibility()) end)
        out[#out + 1] = ("map %s vp=%s op=%s vis=%s"):format(fn:match("[^.]+$"), up, op, vis)
    end
end
local gmc = FindFirstOf("GUIModuleController")
local fs = "?"
pcall(function() fs = tostring(gmc:IsFullscreenGUIActive()) end)
local pc = FindFirstOf("FunCombat_PlayerController_C")
local ign = "?"
pcall(function() ign = tostring(pc:IsMoveInputIgnored()) end)
return ("maps %d · fs=%s · move ignored=%s · %s"):format(#out, fs, ign, table.concat(out, " | "))
