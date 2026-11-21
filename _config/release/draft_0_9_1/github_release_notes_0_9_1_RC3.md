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

- Исправлен баг обновления сборки: лаунчер скачивал весь архив сборки, даже когда изменились несколько файлов. Теперь лаунчер 1.1.0 сверяет файлы в папке игры со списком файлов выпуска и скачивает только изменившиеся файлы. Игрок, который пропустил несколько выпусков, обновляется до последнего одним нажатием.
- Лаунчер 1.1.0 ставит сборку с нуля по тем же файлам выпуска. Перед скачиванием лаунчер называет размер, а остановленная установка продолжается с того же места.
- Исправлен баг удаления сборки: если окно удаления закрыть крестиком, лаунчер по-прежнему показывал сборку установленной. Теперь лаунчер показывает чистую игру и кнопку «Установить сборку».
- Обновление с RC2 до RC3 ещё один раз скачает сторонние паки целиком, около 13 ГБ, так как паки RC2 упакованы прежним способом. Начиная с RC3 обновление скачивает только изменившиеся файлы.
- Лаунчер RC1 и RC2 покажет плашку «Вышел лаунчер 1.1.0». Нажмите на ней «Обновить лаунчер», потом «Обновить сборку».

<a name="english"></a>
## English · [Русский](#русский)

RC3 changes the build's launcher; the mods are the same. The full description of 0.9.1, installation and known issues are on the [0.9.1-RC1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC1) release page.

- Fixed a bug of the build update: the launcher downloaded the whole build archive even when only a few files had changed. Launcher 1.1.0 now compares the files in the game folder with the release's file list and downloads only the changed files. A player who skipped several releases updates to the latest one in one press.
- Launcher 1.1.0 installs the build from scratch from the same release files. Before the download it names the size, and a stopped installation continues from the same place.
- Fixed a bug of the build removal: if the removal window was closed by its X, the launcher still showed the build as installed. The launcher now shows the clean game and the «Install mod pack» button.
- The update from RC2 to RC3 downloads the third-party paks whole one more time, about 13 GB, because the RC2 paks were packed the old way. From RC3 on, an update downloads only the changed files.
- The RC1 and RC2 launcher shows the plate «Launcher 1.1.0 is out». Press «Update launcher» on it, then «Update mod pack».
