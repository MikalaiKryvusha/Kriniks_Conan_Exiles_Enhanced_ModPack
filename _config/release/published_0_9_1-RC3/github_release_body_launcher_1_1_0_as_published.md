<!--
  The notes of the launcher release launcher-v1.1.0 (tag prefix «launcher-v» — KrinikConanUpdates.cs LAUNCHER_PREFIX). The launcher 1.0.0 of 0.9.1-RC1 and
  0.9.1-RC2 finds this release in the feed and offers «Обновить лаунчер»; the release is published with --latest=false, so «Latest» stays on a build
  release (HOUSE_RULES 25.2; LatestBuildPage relies on it). No krinik-game marker: a launcher release serves every game version.
  The three change lines are the RC3 notes' lines as corrected by the clean read of 2026-11-21 20:09 (agreement, tense, comma splice, one verb for one
  action); the same correction goes into the RC3 notes (one text feeds every place — HOUSE_RULES 42). A paragraph is ONE line.
  Sources: published_0_9_1-RC3/github_release_notes_0_9_1_RC3.md; KrinikConanText.cs plate.launcher, btn.update.launcher, btn.update, btn.install,
  u.stopped.install (the same strings in 1.0.0); testcases/reports/2026-11-21_conan-rc3-real-update.md.
-->

<h3 align="center"><em>Krinik Mod Pack · лаунчер 1.1.0 / launcher 1.1.0</em></h3>

<a name="русский"></a>
## Русский · [English](#english)

Лаунчер 1.1.0 устанавливает и обновляет сборку Krinik Mod Pack по отдельным файлам выпуска. Лаунчер 1.0.0 из выпусков 0.9.1-RC1 и 0.9.1-RC2 сам находит эту версию и показывает плашку «Вышел лаунчер 1.1.0». Нажмите на плашке кнопку «Обновить лаунчер». Когда лаунчер обновится, нажмите кнопку «Обновить сборку».

- Исправлен баг обновления сборки: лаунчер скачивал весь архив сборки, даже когда изменилось лишь несколько файлов. Теперь лаунчер 1.1.0 сверяет файлы в папке игры со списком файлов выпуска и скачивает только изменившиеся файлы. Игрок, который пропустил несколько выпусков, обновит сборку до последнего выпуска одним нажатием.
- Лаунчер 1.1.0 устанавливает сборку с нуля по файлам выпуска. Перед скачиванием лаунчер показывает, сколько гигабайт нужно скачать. Если установка остановилась, ещё раз нажмите «Установить сборку»: лаунчер продолжит её с того места, где она прервалась.
- Исправлен баг удаления сборки: когда удаление заканчивалось и окно удаления закрывали крестиком, лаунчер всё ещё показывал, что сборка установлена. Теперь лаунчер видит игру без сборки и показывает кнопку «Установить сборку».

Лаунчер 1.1.0 вышел вместе со сборкой [0.9.1-RC3](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC3). На странице выпуска 0.9.1-RC3 описаны изменения сборки и лежат её файлы.

<a name="english"></a>
## English · [Русский](#русский)

Launcher 1.1.0 installs and updates the Krinik Mod Pack file by file from the release. Launcher 1.0.0 from the 0.9.1-RC1 and 0.9.1-RC2 releases finds this version on its own and shows the notice “Launcher 1.1.0 is out”. Click “Update launcher” on the notice. When the launcher has updated, click “Update mod pack”.

- Fixed a bug in mod pack updates: the launcher downloaded the whole mod pack archive even when only a few files had changed. Launcher 1.1.0 now compares the files in the game folder with the release’s file list and downloads only the changed files. A player who skipped several releases brings the mod pack up to the latest release with a single click.
- Launcher 1.1.0 installs the mod pack from scratch from the release files. Before downloading, it shows the download size in gigabytes. An interrupted installation resumes where it left off when you click “Install mod pack” again.
- Fixed a bug in mod pack removal: after the removal finished and its window was closed with the X button, the launcher still showed the mod pack as installed. The launcher now detects that the mod pack is gone and shows the “Install mod pack” button.

Launcher 1.1.0 was released together with mod pack [0.9.1-RC3](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC3). The 0.9.1-RC3 release page describes the mod pack’s changes and holds its files.

