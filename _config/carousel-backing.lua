-- carousel-backing.lua — read (and for a test, set) the hub's dark backing: the live W_Carousel's image «Background», material M_UI_RadialBackgroundGradient,
-- whose scalar «MaskOffset» the carousel's AnimBackgroundFadeOut drives (0 — the backing on, 1 — off; our kit made the fade one tick — KrinikConanUI notes).
-- Why (2026-11-14, KUMM bug 101): switching to «Снаряжение» the backing goes off at once while our old page stays ≈ 166 ms over the bare world; switching back
-- our page shows a frame before the backing returns. The fix must know the value per tab and whether a direct write holds.
--   bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/carousel-backing.lua')"              -- read
--   bash _config/pult.sh "lua _G.__cb_set=0; return dofile('D:/work/ai_sandbox/ConanExiles/_config/carousel-backing.lua')" -- set MaskOffset 0, then read
-- Reads ONE named live widget (the carousel found by full name in the viewport) — never a brush across FindAllOf (EXP-0527: that crashed the game).
-- [NOT-TESTED]
local set = _G.__cb_set; _G.__cb_set = nil
local car = nil
for _, w in ipairs(FindAllOf('W_Carousel_C') or {}) do
    local okn, name = pcall(function() return w:GetFullName() end)   -- the name first, the properties after (EXP-0386; judge round 3)
    if okn and not name:find('Default__', 1, true) and not name:find('_C:WidgetTree', 1, true) then
        local ok, inv = pcall(function() return w:IsInViewport() end)
        if ok and inv then car = w end
    end
end
-- GetDynamicMaterial makes and installs a dynamic material when the brush holds a plain one; the carousel's own fade (a material track) already runs on
-- a dynamic one, so a read normally changes nothing — still a write in principle (judge round 3)
if not car then return 'no live W_Carousel_C (open the hub first)' end
-- not `car.Background` (nil — the image is not a blueprint variable): the widget tree by name (2026-11-14 12:4x)
local okb, bg = pcall(function() return car:GetWidgetFromName(FName('Background')) end)
if not (okb and bg and bg:IsValid()) then return 'carousel has no Background' end
local okm, mid = pcall(function() return bg:GetDynamicMaterial() end)
if not (okm and mid and mid:IsValid()) then return 'Background: no dynamic material (' .. tostring(mid) .. ')' end
if set ~= nil then mid:SetScalarParameterValue(FName('MaskOffset'), set + 0.0) end
local okv, v = pcall(function() return mid:K2_GetScalarParameterValue(FName('MaskOffset')) end)
local okc, idx = pcall(function() return car:GetCarouselIndex() end)
return string.format('MaskOffset=%s visibility=%d opacity=%.2f carousel index=%s%s', okv and string.format('%.3f', v) or ('ERR ' .. tostring(v)),
    bg:GetVisibility(), bg:GetRenderOpacity(), okc and tostring(idx) or '?', set ~= nil and (' (set ' .. set .. ')') or '')
