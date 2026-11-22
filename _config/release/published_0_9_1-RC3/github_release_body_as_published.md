<!-- krinik-game: 3.1.1 CL-383549 -->
<!--
  The first line is the launcher's marker: it matches this release to the game (modpack.json launcher.gameVersion 3.1.1, builtFor CL-383549). Keep it the FIRST line.
  The notes of 0.9.1-RC3 are short, as the RC2 notes: ONLY what RC3 changed against RC2 and a link to the RC1 release for everything else (the owner
  2026-11-20 21:09–21:10 on the RC2 notes). RC3 changes only the launcher (1.1.0) and the uninstaller; no mod changed (the owner 2026-11-21 17:41).
  Sources: KUMM plans/57 phase 6, testcases/reports/2026-11-21_conan-launcher-delta-update-stand.md, 2026-11-21_conan-launcher-uninstall-x-close.md;
  issues #45, #46. A paragraph is ONE line (GitHub Releases keeps single line breaks).
-->

<h3 align="center"><em>Krinik Mod Pack 0.9.1-RC3 · Conan Exiles Enhanced 3.1.1</em></h3>

<a name="русский"></a>
## Русский · [English](#english)

RC3 меняет лаунчер сборки, моды остались прежними. Полное описание версии 0.9.1, установка и известные проблемы приведены на странице выпуска [0.9.1-RC1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC1).

- Исправлен баг обновления сборки: лаунчер скачивал весь архив сборки, даже когда изменилось лишь несколько файлов. Теперь лаунчер 1.1.0 сверяет файлы в папке игры со списком файлов выпуска и скачивает только изменившиеся файлы. Игрок, который пропустил несколько выпусков, обновит сборку до последнего выпуска одним нажатием.
- Лаунчер 1.1.0 устанавливает сборку с нуля по файлам выпуска. Перед скачиванием лаунчер показывает, сколько гигабайт нужно скачать. Если установка остановилась, ещё раз нажмите «Установить сборку»: лаунчер продолжит её с того места, где она прервалась.
- Исправлен баг удаления сборки: когда удаление заканчивалось и окно удаления закрывали крестиком, лаунчер всё ещё показывал, что сборка установлена. Теперь лаунчер видит игру без сборки и показывает кнопку «Установить сборку».
- Обновление с RC2 до RC3 ещё один раз скачает сторонние паки целиком, около 13 ГБ, так как паки RC2 упакованы прежним способом. Начиная с RC3 обновление скачивает только изменившиеся файлы.
- Лаунчер RC1 и RC2 покажет плашку «Вышел лаунчер 1.1.0». Нажмите на плашке кнопку «Обновить лаунчер». Когда лаунчер обновится, нажмите кнопку «Обновить сборку».

<a name="english"></a>
## English · [Русский](#русский)

RC3 changes the mod pack’s launcher; the mods are the same. The full description of 0.9.1, installation and known issues are on the [0.9.1-RC1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC1) release page.

- Fixed a bug in mod pack updates: the launcher downloaded the whole mod pack archive even when only a few files had changed. Launcher 1.1.0 now compares the files in the game folder with the release’s file list and downloads only the changed files. A player who skipped several releases brings the mod pack up to the latest release with a single click.
- Launcher 1.1.0 installs the mod pack from scratch from the release files. Before downloading, it shows the download size in gigabytes. An interrupted installation resumes where it left off when you click “Install mod pack” again.
- Fixed a bug in mod pack removal: after the removal finished and its window was closed with the X button, the launcher still showed the mod pack as installed. The launcher now detects that the mod pack is gone and shows the “Install mod pack” button.
- The update from RC2 to RC3 downloads the third-party paks whole one more time, about 13 GB, because the RC2 paks were packed the old way. From RC3 on, an update downloads only the changed files.
- The RC1 and RC2 launcher shows the notice “Launcher 1.1.0 is out”. Click “Update launcher” on the notice. When the launcher has updated, click “Update mod pack”.

