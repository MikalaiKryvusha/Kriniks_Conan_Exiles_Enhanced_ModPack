-- Desk test of the settings store _unpacked/KrinikConanUI/ue4ss/Scripts/krinik_settings.lua (KUMM plan 38 phase 2, step 3): save → file → load
-- round trip, a saved `false` survives (the bug the first run caught, 2026-10-31 20:3x), a default deletes the key, untouched keys stay, the
-- listeners get the changes. No game: run from the pack root —  lua _config/tests/test_krinik_settings.lua  (exit 0 and «PASS»).
package.path = "_unpacked/KrinikConanUI/ue4ss/Scripts/?.lua;" .. package.path
local S = require("krinik_settings")
S.PATH = (os.getenv("TEMP") or ".") .. "/KrinikSettings_test.lua"
os.remove(S.PATH)
S.load()
local seen = {}
S.on_change(function(c) for k, v in pairs(c) do seen[#seen + 1] = k .. "=" .. tostring(v == S.DEFAULT and "DEFAULT" or v) end end)
assert(S.get("ui_fps", true) == true, "absent key -> default")
S.save({ ui_fps = false, ui_blink_food = 0.2, ui_menu_slow = 10 })
S.values = {}
S.load()
assert(S.get("ui_fps", true) == false, "bool false round trip")
assert(math.abs(S.get("ui_blink_food", 0.1) - 0.2) < 1e-9, "number round trip")
S.save({ ui_fps = S.DEFAULT, ui_menu_slow = 10 })
S.values = {}
S.load()
assert(S.get("ui_fps", true) == true, "DEFAULT removed the key")
assert(S.get("ui_menu_slow", 33) == 10, "untouched key kept")
table.sort(seen)
assert(table.concat(seen, ",") == "ui_blink_food=0.2,ui_fps=DEFAULT,ui_fps=false,ui_menu_slow=10", "listeners: " .. table.concat(seen, ","))
os.remove(S.PATH)
print("test_krinik_settings PASS")
