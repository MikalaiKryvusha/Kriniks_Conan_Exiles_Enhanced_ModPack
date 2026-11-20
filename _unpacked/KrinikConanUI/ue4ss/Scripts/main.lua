--[[
  KrinikConanUI (Lua half) — the build's interface as one mod: the kit pak KrinikConanUI.pak (vanilla widget layout fixes) plus this
  folder. Until 2026-10-30 these were five mods: KrinikUIFixes (pak + Lua), KrinikFpsCounter, KrinikHudOutline, KrinikPauseGameInMenu.
  The owner's word (KUMM plans/36 W31, W34): «KrinikUIFixes - переименовать в KrinikConanUI» · «KrinikFpsCounter - идет в мод UI» ·
  the approved set of five shipped Krinik mods, 2026-10-30 ≈13:0x.

  Each former mod is a section — its own file in Scripts/, loaded by require (UE4SS puts the mod's Scripts folder on package.path,
  as ConsoleCommandsMod does). A section keeps its own locals, hooks, self-measurement and log prefix «[KrinikConanUI:<section>]»;
  a section that fails to load is logged and the others still load.
  [TESTED: 2026-10-30 · four sections loaded in the live game, counter, outline, inventory pause read · KUMM testcases/reports/2026-10-30_conan-krinik-conan-ui-merge.md]
]]

local SECTIONS = {
    "krinik_ui_fixes",       -- corpse strip vs quick-loot window, button glyph width (was KrinikUIFixes Lua 1.2.0)
    "krinik_fps_counter",    -- frames per second in the top right corner (was KrinikFpsCounter 0.2.0)
    "krinik_hud_outline",    -- outline of the Hosav HUD text (was KrinikHudOutline 0.2.0)
    "krinik_pause_in_menu",  -- the world nearly stops while a menu is open (was KrinikPauseGameInMenu 0.13.0)
    "krinik_hud_blink",      -- food/water/weight blink early: dim at the threshold, full at the limit (2026-10-30, plan 36 W36)
    "krinik_feedback",       -- the «ОТЗЫВ» plate in the main and Esc menus: zip of logs + a mail to the author (2026-10-31, plan 36 W37)
    "krinik_shout_fade",     -- enemy shouts (game subtitles) appear in place, fade in and out 0.2 s via a mirror line (2026-10-31, plan 36 W29)
    "krinik_minimap_coords", -- Simple Minimap coordinates inside the ring on a clock-style plate (2026-10-31, plan 36 W4)
    "krinik_mod_settings",   -- the «Моды Krinik'а» settings hub skeleton: our module table merged, our kit window's rows (2026-10-31, plan 38)
    "krinik_vignette",       -- strength of the screen-edge vignettes (hunger, thirst, low health), 0 = off (2026-11-01, plan 40 phase 1)
    "krinik_mods_button",    -- «Настройки модов» in the inventory's bottom bar opens «Моды Krinik'а» (2026-11-01, plan 40 phase 3, step 1)
    "krinik_pickup_prompt",  -- a light «E Взять» over sticks, stones, fibre, berries… (foliage pickups), checked once a second (2026-11-01, plan 42)
    -- "krinik_loot_rim" OFF since 2026-11-07: the kit makes the cell's AnimSelect instant (the rim no longer lingers on the walk's last cell), and the
    -- owner's word 10:57 «не нужно её прятать даже на короткий момент» — the section hid the other rims 350 ms after a take. The file stays for the record.
    "krinik_hub_controller", -- our hub page controller: the old page until the new one is complete, lazy pages, minimap row on our map (2026-11-07, KUMM plan 48)
    "krinik_attr_pips",      -- the perk pips of an attribute row follow its page (1–20, 21–40 …): placeholder perks past 20 (2026-11-10, KUMM plan 49 step 3)
}

for _, name in ipairs(SECTIONS) do
    local ok, err = pcall(require, name)
    print(("[KrinikConanUI] section %s: %s\n"):format(name, ok and "loaded" or ("FAILED " .. tostring(err))))
end
