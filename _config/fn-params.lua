-- fn-params.lua — the parameters of a native or blueprint UFunction, read live by the remote. Read-only.
-- WHY: UE4SS refuses a call that does not pass EVERY parameter («UFunction expected 2 parameters, received 1»), and this engine's signatures differ
-- from the UE docs: `ComboBoxString:SetSelectedIndex(Index, SelectInfo)`, the game's `SetIsToggledOn(NewIsToggledOn, ShouldBroadcast, IsInstantTransition)`,
-- `SetValue(RealValue, IsInitializing)` — three runs paid for guessing (KUMM EXP-0441). Before a Lua call into a function not called before — print it:
--   bash pult.sh "lua _G.__fp='/Script/UMG.ComboBoxString:SetSelectedIndex'; return dofile('D:/work/ai_sandbox/ConanExiles/_config/fn-params.lua')"
-- [TESTED: 2026-11-02 · printed «Index : IntProperty, SelectInfo : ByteProperty» and the SetSelectedOption pair in the live game · KUMM testcases/reports/2026-11-02_conan-hub-rectangle-and-batch.md]
local f = StaticFindObject(_G.__fp)
if not (f and f:IsValid()) then return tostring(_G.__fp) .. " NOT FOUND (full path: /Script/<Module>.<Class>:<Function> or /Game/…/<BP>.<BP>_C:<Function>)" end
local out = { f:GetFullName() }
f:ForEachProperty(function(p)
    out[#out + 1] = "  " .. p:GetFName():ToString() .. " : " .. p:GetClass():GetFName():ToString()
end)
return table.concat(out, "\n")
