-- Experiment (2026-10-29): «Настройка рыбалки» as a second Hosav button, both in the bar's left container. Guards first (EXP-0372).
local function valid(o) return o ~= nil and o:IsValid() end
local gmc = FindFirstOf('GUIModuleController')
if not valid(gmc) then return 'no module controller' end
if not gmc:IsModuleActive(FName('XCS_Panel')) then return 'not on «Снаряжение»' end
local eft, right
for _, e in ipairs(FindAllOf('W_EFT_AdminButton_C') or {}) do
  if valid(e) then local p = e:GetParent(); if valid(p) then eft, right = e, p end end
end
if not valid(eft) then return 'no fishing button with a parent' end
if not valid(right) then return 'fishing button has no parent' end
local bar = right:GetOuter() and right:GetOuter():GetOuter()
if not valid(bar) then return 'no bar' end
local left = bar:GetWidgetFromName(FName('ButtonContainerLeft'))
if not valid(left) then return 'no left container' end
local hosav = FindFirstOf('W_UI_SettingsButton_C')
if not valid(hosav) then return 'no Hosav widget' end
local hb = hosav.WBP_ButtonBase
if not valid(hb) then return 'no Hosav button' end

FISHBTN = FISHBTN or {}
local F = FISHBTN
if not valid(F.clone) then
  local wbl = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
  local pc = FindFirstOf('PlayerController')
  F.clone = wbl:Create(pc, hosav:GetClass(), pc)
  if not valid(F.clone) then return 'clone not created' end
end
if not F.clone:IsInViewport() and not F.constructed then
  F.constructed = true
  F.clone:AddToViewport(0)   -- Construct of the root widget sets its button up (the original got it from Hosav's own AddToViewport)
end
local fb = F.clone.WBP_ButtonBase
if not valid(fb) then return 'clone has no button' end
fb:SetLabel(FText('Настройка рыбалки'))

if not F.hooked then
  F.hooked = true
  RegisterHook('/Game/Mods/UIMod_Hosav/W_UI_SettingsButton.W_UI_SettingsButton_C:BndEvt__W_UI_SettingsButton_WBP_ButtonBase_K2Node_ComponentBoundEvent_1_SignalClicked__DelegateSignature',
    function(ctx) print('[fishbtn] pre ' .. ctx:get():GetFName():ToString() .. ' hosavActive=' .. tostring(FindFirstOf('GUIModuleController'):IsModuleActive(FName('HosavUIsettings')))) end,
    function(ctx) print('[fishbtn] post ' .. ctx:get():GetFName():ToString() .. ' hosavActive=' .. tostring(FindFirstOf('GUIModuleController'):IsModuleActive(FName('HosavUIsettings')))) end)
end

hb:RemoveFromParent(); left:AddChildToHorizontalBox(hb)
fb:RemoveFromParent(); left:AddChildToHorizontalBox(fb)
hb:SetVisibility(4); fb:SetVisibility(4)
eft:SetVisibility(1)
return 'row: left children ' .. left:GetChildrenCount() .. '; clone ' .. F.clone:GetFName():ToString()
