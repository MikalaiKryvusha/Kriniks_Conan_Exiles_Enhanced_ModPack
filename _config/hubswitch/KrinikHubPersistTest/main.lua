-- KrinikHubPersistTest - DEV EXPERIMENT (KUMM plan 48, 2026-11-06): the 9 hub tab rows of DT_UIModuleTable get IsPersistent = true
-- BEFORE GUIModuleController reads them (a live edit at the main menu was too late). Not in the build; removed after the test. [NOT-TESTED]
local T = { CharacterInventory = 1, FeatWindow = 1, Attributes = 1, CharacterStatsWindow = 1, ExilesJourney = 1, Guild = 1, Followers = 1,
    FullscreenMap = 1, Stores = 1 }
local function L(m) print('[KrinikHubPersistTest] ' .. m .. '\n') end
local function edit(why)
    local dt = StaticFindObject('/Game/UI/Data/DataTables/DT_UIModuleTable.DT_UIModuleTable')
    if not (dt and dt:IsValid()) then L(why .. ': table not loaded'); return false end
    local n = 0
    dt:ForEachRow(function(name, row) if T[tostring(name)] then row.IsPersistent = true; n = n + 1 end end)
    L(why .. ': IsPersistent set on ' .. n .. ' rows')
    return true
end
edit('script load')
NotifyOnNewObject('/Script/ConanSandbox.GUIModuleController', function(c)
    edit('GUIModuleController born ' .. c:GetFullName())
end)
NotifyOnNewObject('/Script/Engine.DataTable', function(t)
    if t:GetFullName():find('DT_UIModuleTable', 1, true) then ExecuteInGameThread(function() edit('table born') end) end
end)
