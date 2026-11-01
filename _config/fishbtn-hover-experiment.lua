-- fishbtn-hover-experiment.lua — remote experiment (not a shipped mod), 2026-10-30: the gold hover outline of «Настройка рыбалки».
-- The vanilla look (WBP_ButtonBase, native FLXButtonBase) lights up only when IT gets the mouse: its ImgFrame / ImgBackground materials get
-- PercentHover = 1. Hit-testable, it also eats the click (the panel did not open, 00:21). So: Btn_Open (UMG Button, the mod's click) goes ON TOP
-- of the look in an Overlay; its Normal brush draws nothing, its Hovered / Pressed brush is a new instance of the frame material with
-- PercentHover = 1 — Slate swaps it on hover by itself, no event, no polling. The look keeps its normal frame (PercentHover 0).
-- Run: pult.sh "lua <this file's body>" — one call, with IsModuleActive + IsValid checks (EXP-0372).
local function live(o) return o ~= nil and o:IsValid() end
local g = FindFirstOf("GUIModuleController")
if not (live(g) and g:IsModuleActive(FName("CharacterInventory"))) then return "hub closed" end
local eft
for _, e in ipairs(FindAllOf("W_EFT_AdminButton_C") or {}) do if live(e) and live(e:GetParent()) then eft = e end end
if not eft then return "no fishing button" end
local btn, size = eft:GetWidgetFromName(FName("Btn_Open")), eft:GetWidgetFromName(FName("Size_Btn_Open"))
local look = live(btn) and btn:GetContent() or nil
if not (live(btn) and live(size) and live(look)) then return "parts missing" end
local frame = look:GetWidgetFromName(FName("ImgFrame"))
local mid = frame.Brush.ResourceObject
local pc = FindFirstOf("PlayerController")
local kml = StaticFindObject("/Script/Engine.Default__KismetMaterialLibrary")
local hot = kml:CreateDynamicMaterialInstance(pc, mid.Parent, FName("None"), 0)
if not live(hot) then return "no MID" end
hot:SetScalarParameterValue(FName("PercentHover"), 1.0)
look:SetVisibility(3)        -- HitTestInvisible: click and hover belong to Btn_Open
frame:SetVisibility(4)       -- the normal (dim) frame, as on Hosav's button at rest
local ov = StaticConstructObject(StaticFindObject("/Script/UMG.Overlay"), eft.WidgetTree)
if not live(ov) then return "no Overlay" end
size:SetContent(ov)
local s1 = ov:AddChildToOverlay(look); s1:SetHorizontalAlignment(0); s1:SetVerticalAlignment(0)
local s2 = ov:AddChildToOverlay(btn); s2:SetHorizontalAlignment(0); s2:SetVerticalAlignment(0)
local st = btn.WidgetStyle
local fb = frame.Brush
local hover = { ResourceObject = hot, ImageSize = fb.ImageSize, DrawAs = fb.DrawAs, Margin = fb.Margin, Tiling = fb.Tiling,
                TintColor = { SpecifiedColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 } } }
st.Hovered = hover
st.Pressed = hover
st.Normal = { DrawAs = 0 }   -- NoDrawType
btn:SetStyle(st)
btn:SetBackgroundColor({ R = 1.0, G = 1.0, B = 1.0, A = 1.0 })
return "overlay set: look under, Btn_Open on top; DrawAs=" .. tostring(fb.DrawAs)
