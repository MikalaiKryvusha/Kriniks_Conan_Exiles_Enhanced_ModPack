-- move310-checks.lua — the in-game half of KUMM plan 53 step 12 and the L6 control of TC_conan_move_3.1.0_2026-11-13.md, in one read-only remote call.
-- Why (2026-11-13): three stale vanilla copies were fixed in the pack (Storage Reach's console table and LegitReligious' stat table rebuilt on 3.1.0, EAA's
-- crafting station = the game's chunk) and checked file by file; this reads what the RUNNING game loaded. L6: is a foreign mod class loaded before our
-- code touches it — 3.1.0 loads only ModController classes at startup, so `nil` here proves the late loading our `find_loaded` answers.
--   bash _config/pult.sh "lua return dofile('D:/work/ai_sandbox/ConanExiles/_config/move310-checks.lua')"
-- Prints «name · value» lines. Read-only: changes nothing (`ForEachRow` counts, `StaticFindObject` finds — never loads).
-- The console table's live count includes other mods' merged rows (129 on 2026-11-13) — the key rows decide, not the count.
-- [TESTED: 2026-11-13 22:01 · the 3.1.0 world: FollowerPerk / SRE.show / Grimoire true, stat table 3425, the station class valid, L6 five classes valid —
--  KUMM testcases/reports/2026-11-13_conan-310-stale-vanilla-copies.md]
local out = {}
local function say(k, v) out[#out + 1] = k .. " · " .. tostring(v) end
local function valid(o) return o ~= nil and o.IsValid and o:IsValid() end

local function rows(path)
    local dt = StaticFindObject(path)
    if not valid(dt) then return nil, {} end
    local n, names = 0, {}
    dt:ForEachRow(function(name, _) n = n + 1; names[type(name) == "string" and name or name:ToString()] = true end)
    return n, names
end

-- the console command table: 3.1.0 has 26 rows (FollowerPerk new) + Storage Reach's 3
local n, names = rows('/Game/Systems/Cheats/CustomConsoleCommandsDataTable.CustomConsoleCommandsDataTable')
say('console table rows (want 29)', n)
say('  FollowerPerk (3.1.0)', names['FollowerPerk'] == true)
say('  SRE.show (the mod)', names['SRE.show'] == true)
say('  Grimoire (3.0.1, lost in the author copy)', names['Grimoire'] == true)
-- the item stat modification table: 3.1.0 has 1725 rows (merged tables of other mods may add more — at least 1725)
n = rows('/Game/Items/ItemStatModificationTable.ItemStatModificationTable')
say('item stat table rows (want >= 1725)', n)
-- the crafting station class the game loaded (EAA ships its path): present and with the 3.1.0 function BindRunningState
local cls = StaticFindObject('/Game/Systems/Building/Placeables/BP_PL_Crafting_Station.BP_PL_Crafting_Station_C')
say('crafting station class loaded', valid(cls))
say('  its BindRunningState', valid(StaticFindObject('/Game/Systems/Building/Placeables/BP_PL_Crafting_Station.BP_PL_Crafting_Station_C:BindRunningState')))
-- L6: foreign classes our UI reaches — loaded before our code? (nil = 3.1.0's late loading is real for it)
-- the paths are the ones our code reaches (`KrinikConanUI/ue4ss/Scripts/krinik_mod_settings.lua` AUTHORS table, `krinik_hub_controller.lua` SM_HELPER_CLASS)
for _, p in ipairs({
    '/Game/Mods/DamageNumber/DN_SG_SaveSettings.Default__DN_SG_SaveSettings_C',
    '/Game/Mods/ProximityParty/PrP_SAV_WindowSettings.Default__PrP_SAV_WindowSettings_C',
    '/Game/Mods/Simple_Minimap/SM_BP_SaveGame.Default__SM_BP_SaveGame_C',
    '/Game/Mods/LLHighlight/LLH_SAV_Settings.LLH_SAV_Settings_C',
    '/Game/Mods/Simple_Minimap/UI/CustomMarker/SM_UI_MapHelper.SM_UI_MapHelper_C',
}) do say('L6 ' .. p:match('[^/]+$'), valid(StaticFindObject(p))) end
return table.concat(out, "\n")
