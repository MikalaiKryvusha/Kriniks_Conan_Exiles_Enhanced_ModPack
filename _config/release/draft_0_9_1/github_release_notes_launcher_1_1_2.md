<!--
  The notes of the launcher release launcher-v1.1.2 (tag prefix «launcher-v» — KrinikConanUpdates.cs LAUNCHER_PREFIX). The launchers 1.0.0 (0.9.1-RC1,
  0.9.1-RC2), 1.1.0 (0.9.1-RC3) and 1.1.1 (0.9.1-RC4) find this release in the feed and offer «Обновить лаунчер» (the self-update takes the highest
  launcher-v number); the release is published with --latest=false, so «Latest» stays on a build release (HOUSE_RULES 25.2; LatestBuildPage relies on it).
  No krinik-game marker: a launcher release serves every game version. The change line states the facts of the 0.9.1 notes' launcher lines in the «Исправлен баг …» form of a release page (HOUSE_RULES 42).
  A paragraph is ONE line. Sources: draft_0_9_1/github_release_notes_0_9_1.md; issue #47 (#15); the plaque (#43) stays a known issue — the owner saw its first open still slow 2026-11-23 14:27; KUMM testcases/reports/2026-11-23_conan-rc5-fixes.md.
-->

<h3 align="center"><em>Krinik Mod Pack · лаунчер 1.1.2 / launcher 1.1.2</em></h3>

<a name="русский"></a>
## Русский · [English](#english)

Лаунчер 1.1.2 исправляет строку «Моды» при установке. Лаунчер прежних версий сам находит эту версию и показывает плашку «Вышел лаунчер 1.1.2». Нажмите на плашке кнопку «Обновить лаунчер». Когда лаунчер обновится, нажмите кнопку «Обновить сборку».

- Исправлен баг строки «Моды»: к концу установки строка останавливалась на «72 из 74», хотя все 74 мода были установлены. Лаунчер не узнавал два мода с длинным тире в названии, «MSCasaDesFlores — Weapons & Armors» и «MSCasaDesFlores — Nails Station». Теперь строка «Моды» доходит до «74 из 74».

Лаунчер 1.1.2 вышел вместе со сборкой [0.9.1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1). На странице выпуска 0.9.1 описаны изменения сборки и лежат её файлы.

<a name="english"></a>
## English · [Русский](#русский)

Launcher 1.1.2 fixes the “Mods” line during an install. A launcher of an earlier version finds this version on its own and shows the notice “Launcher 1.1.2 is out”. Click “Update launcher” on the notice. When the launcher has updated, click “Update mod pack”.

- Fixed a launcher bug: the “Mods” line stopped at “72 of 74” at the end of an install, although the installer had installed every mod. The launcher did not recognise two mods with a long dash in their names, “MSCasaDesFlores — Weapons & Armors” and “MSCasaDesFlores — Nails Station”. The “Mods” line now reaches “74 of 74”.

Launcher 1.1.2 was released together with mod pack [0.9.1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1). The 0.9.1 release page describes the mod pack’s changes and holds its files.
