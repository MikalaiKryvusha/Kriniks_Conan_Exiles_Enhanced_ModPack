--[[
  KrinikConanGameplay (Lua half) — the build's gameplay as one mod: the pak KrinikConanGameplay.pak (10 000 levels, the three progression
  tables replaced; until 2026-10-30 the pak KrinikLevelUncapped) plus this folder (until 2026-10-30 the Lua mod KrinikOblivionLocomotion).
  The owner's word (KUMM plans/36 W32): «KrinikOblivionLocomotion · KrinikLevelUncapped · Идет в мод KrinikConanGameplay» · 2026-10-30 ≈13:0x.

  The same section pattern as KrinikConanUI: each part is a file in Scripts/, loaded by require; a section keeps its own hooks and log
  prefix «[KrinikConanGameplay:<section>]»; a section that fails to load is logged and the others still load.
  [TESTED: 2026-10-30 · the section loaded in the live game and set the hero speed from Agility; the same save shows the same XP threshold · KUMM testcases/reports/2026-10-30_conan-krinik-conan-gameplay-merge.md]
]]

local SECTIONS = {
    "krinik_oblivion_locomotion",  -- every Agility point adds 3 cm/s to run, sprint and jump (was KrinikOblivionLocomotion 0.3.0)
}

for _, name in ipairs(SECTIONS) do
    local ok, err = pcall(require, name)
    print(("[KrinikConanGameplay] section %s: %s\n"):format(name, ok and "loaded" or ("FAILED " .. tostring(err))))
end
