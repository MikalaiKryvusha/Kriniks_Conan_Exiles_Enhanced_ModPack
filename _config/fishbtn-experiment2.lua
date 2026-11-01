-- Experiment 2 (2026-10-29): the fishing button keeps its OWN click (EFT Btn_Open → CustomEvent → ActivateModule('ExilesFishingTuning')) and wears a
-- vanilla WBP_ButtonBase as its content; it moves next to Hosav's button in the bar's left container. Guards first (EXP-0372). Remote only.
local function valid(o) return o ~= nil and o:IsValid() end
local gmc = FindFirstOf('GUIModuleController')
if not (valid(gmc) and gmc:IsModuleActive(FName('XCS_Panel'))) then return 'not on «Снаряжение»' end
local eft, right
for _, e in ipairs(FindAllOf('W_EFT_AdminButton_C') or {}) do
  if valid(e) then local p = e:GetParent(); if valid(p) then eft, right = e, p end end
end
if not valid(eft) then return 'no fishing button with a parent' end
local bar = right:GetOuter() and right:GetOuter():GetOuter()
local left = valid(bar) and bar:GetWidgetFromName(FName('ButtonContainerLeft'))
if not valid(left) then return 'no left container' end
-- remove experiment 1's clone button from the row, if any
if FISHBTN and valid(FISHBTN.clone) and valid(FISHBTN.clone.WBP_ButtonBase) then FISHBTN.clone.WBP_ButtonBase:RemoveFromParent() end

local function part(n) local w = eft:GetWidgetFromName(FName(n)); if valid(w) then return w end; return nil end
local btn, size, pad = part('Btn_Open'), part('Size_Btn_Open'), part('Pad')
if not (valid(btn) and valid(size) and valid(pad)) then return 'EFT parts missing' end
local pc = FindFirstOf('PlayerController')
local wbl = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
local cls = StaticFindObject('/Game/UI/Widgets/Buttons/WBP_ButtonBase.WBP_ButtonBase_C')
if not valid(cls) then return 'no WBP_ButtonBase class' end
local look = wbl:Create(pc, cls, pc)
if not valid(look) then return 'look not created' end
look:SetLabel(FText('Настройка рыбалки'))
look:SetVisibility(3)                                    -- HitTestInvisible: the click and hover stay with Btn_Open
btn:SetContent(look)
btn:SetBackgroundColor({R = 0.0, G = 0.0, B = 0.0, A = 0.0})   -- the plain plate disappears, the content stays
size.bOverride_WidthOverride = false
pad:SetPadding({Left = 0.0, Top = 0.0, Right = 0.0, Bottom = 0.0})
eft:RemoveFromParent()
local slot = left:AddChildToHorizontalBox(eft)
slot:SetPadding({Left = 15.0, Top = 15.0, Right = 15.0, Bottom = 15.0})
eft:SetVisibility(4)
return 'fishing in the row: left children ' .. left:GetChildrenCount() .. ', look ' .. string.format('%.1fx%.1f', look:GetDesiredSize().X, look:GetDesiredSize().Y)
