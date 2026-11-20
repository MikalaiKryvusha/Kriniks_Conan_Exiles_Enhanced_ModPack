-- blink-phase.lua — one sample of the HUD blink phase of food, water and weight (KUMM TC_conan_hud_blink_one_bus_2026-11-03): k = how red each icon is
-- right now (food/water: 1 − G^(1/2.2) of the border's content colour — the section paints G = (1 − k)^2.2; weight: alpha of Image_Weight_Blinking),
-- plus whether Hosav's native animation of the icon plays. Read in ONE call, so the three k are of the same frame.
--   bash pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/blink-phase.lua')"
-- The live W_SmoothHP — from the live HUD (UIMod_Hosav notes: FindFirstOf('W_SmoothHP_C') returns the class TEMPLATE). [NOT-TESTED]
local hud
for _, h in ipairs(FindAllOf("W_NewHealthUI_C") or {}) do
    if not h:GetFullName():find("WidgetTree", 1, true) and not h:GetFullName():find("Default__", 1, true) then hud = h end
end
if not hud then return "no HUD" end
local s = hud.W_SmoothHP
local function kc(border)
    local c = border.ContentColorAndOpacity
    return 1.0 - math.max(0.0, c.G) ^ (1.0 / 2.2)
end
local w = s.Image_Weight_Blinking.ColorAndOpacity
return string.format("food %.2f%s water %.2f%s weight %.2f%s", kc(s.Border_EatImage), s:IsAnimationPlaying(s.NoFood) and "*" or "",
    kc(s.Border_WaterImage), s:IsAnimationPlaying(s.NoWater) and "*" or "", w.A, s:IsAnimationPlaying(s.OverEncumbered_Weight) and "*" or "")
