-- attr-cap-probe.lua — the attribute cap past 20, read and pushed by the remote (KUMM plans/49, TC_conan_attributes_uncapped_and_dead_shot A1–A2).
-- Use: bash _config/pult.sh "lua _G.__attr={stat=19, target=21}; return dofile('D:/work/ai_sandbox/ConanExiles/_config/attr-cap-probe.lua')"
--   stat 19 = AttributeAthleticism (Agility), 14 = AttributeHealth (Vitality); target — raise the stat by ServerGiveAttribute up to it (nil — read only).
-- Prints: cap (BP_ProgressionSystem.MaxAttributePointsSpent), the stat before and after, free points.
-- [TESTED: 2026-11-08 23:27 · read-only on the shipped build: «cap=20 before=25 free=53» — the vanilla cap read; push mode — A2 of the TC]
local a = _G.__attr or {}
local stat = a.stat or 19
local hero = FindFirstOf('BasePlayerChar_C')
local ps = FindFirstOf('BP_ProgressionSystem_C')
if not hero or not hero:IsValid() or not ps or not ps:IsValid() then return 'no hero or progression system' end
local function cur() return hero:GetIntStat(stat, 1) end
local out = { 'cap=' .. tostring(ps.MaxAttributePointsSpent), 'before=' .. tostring(cur()), 'free=' .. tostring(ps.AttributePointsUndistributed) }
if a.target then
  local n = 0
  while cur() < a.target and n < 60 do ps:ServerGiveAttribute(stat); n = n + 1 end
  out[#out + 1] = 'calls=' .. n
  out[#out + 1] = 'after=' .. tostring(cur())
  out[#out + 1] = 'free=' .. tostring(ps.AttributePointsUndistributed)
end
-- «+» itself is judged by a frame of the attribute screen (CanGiveAttribute's out-params do not come back through the remote: «err nil», 2026-11-08 23:27)
return table.concat(out, ' ')
