-- info-open.lua — one interaction prompt widget of /Game/UI/HUD/FloatingNames/ opened BY CODE over the nearest live actor of a class (KUMM bugs/83),
-- the twin of strip-open.sh for the five prompts besides the corpse strip (EXP-0394: «саму плашку кодом открывай»).
--   bash pult.sh "lua _G.__io_w='W_DialogueNPCInfo'; _G.__io_actor='HumanoidNPCCharacter'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/info-open.lua')"
-- _G.__io_w — the widget asset name; _G.__io_actor — a substring of the actor's class name (matched on the full name, no method call on a
-- non-matching object: EXP-0386/0387); _G.__io_maxd — search radius in m (default 60). The previous widget opened by this script is removed first.
-- Reads back what krinik_ui_fixes 1.5.0 must have set on the `Container` border one tick later — call again with _G.__io_read=true.
-- [TESTED: 2026-11-06 · five classes opened and read back · KUMM testcases/reports/2026-11-06_conan-interaction-prompts-perks-enemy-bar.md]
local W, ACT, MAXD = _G.__io_w, _G.__io_actor, _G.__io_maxd or 60
local function readback(w)
    local b = w:GetWidgetFromName(FName("Container"))
    if not (b and b:IsValid()) then return "no Container" end
    local t, s, c = b.RenderTransform.Translation, b.RenderTransform.Scale, b.BrushColor
    return string.format("%s inViewport=%s translation=(%.1f, %.1f) scale=%.2f brushA=%.2f", w:GetFName():ToString(), tostring(w:IsInViewport()),
        t.X, t.Y, s.X, c.A)
end
if _G.__io_read then
    _G.__io_read = nil
    local w = _G.__io_open
    if not (w and w:IsValid()) then return "nothing open" end
    return readback(w)
end
local old = _G.__io_open
if old and old:IsValid() then old:RemoveFromParent() end
_G.__io_open = nil
local p = FindFirstOf("BasePlayerChar_C")
local pc = FindFirstOf("FunCombat_PlayerController_C")
local h = p:K2_GetActorLocation()
local best, bd
for _, x in ipairs(FindAllOf("Actor") or {}) do
    local f = x:GetFullName()
    if not f:find("Default__", 1, true) and f:find(ACT, 1, true) and x ~= p then
        local ok, l = pcall(function() return x:K2_GetActorLocation() end)
        if ok and l then
            local d = math.sqrt((l.X - h.X) ^ 2 + (l.Y - h.Y) ^ 2 + (l.Z - h.Z) ^ 2) / 100
            if d <= MAXD and (not bd or d < bd) then best, bd = x, d end
        end
    end
end
local path = "/Game/UI/HUD/FloatingNames/" .. W
LoadAsset(path .. "." .. W)
local cls = StaticFindObject(path .. "." .. W .. "_C")
if not cls then return "no class " .. W end
local wbl = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
local w = wbl:Create(pc, cls, pc)
w:AddToViewport(50)
local set = "no target"
if best then
    local ok, e = pcall(function() w:SetObject(best, 0) end)
    set = ok and string.format("SetObject %s at %.1f m", best:GetFName():ToString(), bd) or ("SetObject failed: " .. tostring(e))
end
_G.__io_open = w
return W .. " opened; " .. set
