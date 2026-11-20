-- extra-pages-switch.lua - bisect of the 00:00 / 00:08 crashes (KUMM plan 48): OUR extra page instances only, NO hooks; the caller then does one
-- native switch. Creates one instance of each of the 9 page classes (opacity 0, collapsed). [NOT-TESTED]
local CL = { '/Game/UI/Inventory/CraftingGUI.CraftingGUI_C', '/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C', '/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C',
  '/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C', '/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C',
  '/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C', '/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C',
  '/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C', '/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C' }
local only = _G.__ep_only
local pc = FindFirstOf('PlayerController')
local lib = StaticFindObject('/Script/UMG.Default__WidgetBlueprintLibrary')
local n = 0
_G.__ep = _G.__ep or {}
for i, p in ipairs(CL) do
  if not only or only == i then
    local c = StaticFindObject(p)
    if not (c and c:IsValid()) then pcall(function() LoadAsset(p) end); c = StaticFindObject(p) end
    if c and c:IsValid() then local w = lib:Create(pc, c, pc); w:SetRenderOpacity(0.0); w:AddToViewport(41); w:SetVisibility(1); _G.__ep[#_G.__ep + 1] = w; n = n + 1 end
  end
end
return 'created ' .. n
