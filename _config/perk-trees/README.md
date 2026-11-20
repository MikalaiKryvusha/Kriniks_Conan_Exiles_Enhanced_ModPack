# perk-trees — the owner's page «Перки и параметры героя» (two tabs: perk trees · hero variables)

Born 2026-11-14 for the owner's reading before he designs perks past level 20 (KUMM plan 49). The perks, the attribute labels and descriptions, the «Параметры»
labels and the stat numbers are read from the game 3.1.0, the kit and the build's translation. Typed by hand: the Russian glosses of the code names
(`stat_meanings.json`, the page says so), the three corrupted-branch names (taken from the perks' own texts — «оскверненного авторитета» …), the group headings
of the «Параметры» labels and the page's prose. A Russian text is used only when its locres entry carries the hash of the same English source (otherwise the
game shows English, and so does the page). `make_page.py` stops when a game row is not drawn exactly once; `collect.py` stops when the kit probe is not ok.
Our placeholder perks are not drawn: they are off in the game since 2026-11-10.

## Rebuild (data in `PERK_WORK`, default `KUMM/.work/perks`; tools: `_tools/retoc-5.8`, `_tools/repak`, `_tools/src/uaj`, the kit)

1. Assets from the live target's paks view (`_paksview-<target>`, `game_target.py`):
   `retoc-5.8/retoc.exe to-legacy --version UE5_7 --no-shaders --filter <Name> <paksview> <PERK_WORK>/legacy` for `PerksTable` (the game's + EAA's),
   `AttributeDisplayData`, `W_CharacterStatsPanel`; then `uaj tojson <asset> <json> VER_UE5_8` → `vanilla.json`, `eaa.json`, `add.json`, `sp.json`. (`W_Attributes` — each
   row's `MyAttribute` — was read once for the game map's stat ids; the scripts do not need it.)
2. The game's Russian: `repak get <game>/ConanSandbox/Content/Paks/pakchunk0-Windows.pak ConanSandbox/Content/Localization/<T>/ru/<T>.locres > ru_<T>.locres`
   for `Exiles_UI` (perks, attributes, the «Параметры» labels), `Exiles_Code`, `Exiles_Items`. The build's loose `Game.locres` is read in place and wins (our
   overrides of vanilla strings, e.g. Dead Shot).
3. Perk icons and the stat enums — one headless kit run: `_config/devkit/kit-probe-hero-stats.py` (env `KIT_ENUMS`, `KIT_TEXTURES`, `KIT_PROBE_OUT=<PERK_WORK>/icons`),
   under the machine lock; writes `_config/devkit/kit-probe-hero-stats.json`.
4. `python -I -X utf8 perk_data.py` → `perks.json` · `python -I -X utf8 collect.py` → `page_data.json` · `C:/Python314/python.exe -X utf8 make_page.py <out.html>`
   (Pillow for the icons — the PATH Python has none).

## Traps paid

- The perk and attribute texts are in `Exiles_UI` inside the pak, not in the loose `Game.locres` (that one is the build's).
- UE's Python drops the leading «E» of a C++ enum: `ECharIntStatID` is `unreal.CharIntStatID`, members in UPPER_SNAKE.
- `PerksTable` lists `Grit_15` among the Agility rows and `Agility_15` among the Grit rows (order only — each name matches its `TargetIntStat`) — group by the stat.
- The build's text overrides keep the vanilla key AND source hash (Dead Shot passes the hash check) — a page that skipped the check would show a stale override.
- The enum's count member is `E_CHAR_INT_STAT_ID_MAX`; `HEALTH_MAX`, `STAMINA_MAX` are real stats (the first page draft dropped four rows by a `_MAX` filter).
