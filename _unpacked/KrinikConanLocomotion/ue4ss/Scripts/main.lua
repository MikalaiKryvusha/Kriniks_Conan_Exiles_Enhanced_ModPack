--[[
  KrinikConanLocomotion — how the hero moves: combat in a jump (the bow, melee weapons) and the run and jump growing with the hero.
  The owner's word 2026-11-07 10:39 (KUMM HOUSE_RULES rule 19, verbatim in games/ConanExiles/mods/KrinikConanLocomotion.md): «ДОбавляем мод
  KrinikConanLocomotion. В него входят: - прыжки при стрельбе - прыжки при махании холодным оружием - развитие прыжка при прокачке - развития ьега при прокачке
  - ПЛАН: прыжки от карабкания по стенам».
  The same section pattern as KrinikConanUI / KrinikConanGameplay: each part is a file in Scripts/, loaded by require; a section keeps its own hooks and log
  prefix «[KrinikConanLocomotion:<section>]»; a section that fails to load is logged and the others still load.
  [NOT-TESTED]
]]

local SECTIONS = {
    "krinik_oblivion_locomotion",  -- every Agility point adds 3 cm/s to run, sprint and jump (from KrinikConanGameplay, 2026-11-07)
    "krinik_air_combat",           -- the bow fires and a melee weapon swings in the air; a jump mid-draw takes off (the bow part from KrinikConanArchery)
    "krinik_bow_sprint",           -- sprint with the bow drawn and shoot on the run (2026-11-10)
    "krinik_wall_jump",            -- Jump while climbing pushes the hero off the wall, a little along its normal and up (the PLAN row, 2026-11-14)
}

for _, name in ipairs(SECTIONS) do
    local ok, err = pcall(require, name)
    print(("[KrinikConanLocomotion] section %s: %s\n"):format(name, ok and "loaded" or ("FAILED " .. tostring(err))))
end
