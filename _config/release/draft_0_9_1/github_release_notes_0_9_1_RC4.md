<!-- krinik-game: 3.1.1 CL-383549 -->
<!--
  The first line is the launcher's marker: it matches this release to the game (modpack.json launcher.gameVersion 3.1.1, builtFor CL-383549). Keep it the FIRST line.
  The notes of 0.9.1-RC4 follow the RC2 / RC3 form: ONLY what RC4 changed against RC3 and a link to the RC1 release for everything else (the owner
  2026-11-20 21:09–21:10 on the RC2 notes). RC4 changes four Krinik mods (KrinikConanCamera, KrinikConanUI, KrinikConanLocomotion, KrinikConanArchery) and the
  launcher (1.1.1); the RC4 scope is the owner's word 2026-11-22 15:07 and 15:16 (KUMM PROJECT_HISTORY entry «2026-11-22 21:1x — STATUS bonsai trim, part 17»).
  Sources: issues #4, #13, #21, #43, #48, #49, #51; KUMM testcases/reports/2026-11-22_conan-fp-shadow-always-owner-no-see.md, bugs/79, bugs/110 (the plaque:
  76–83 ms per later open before, 10.9–14.0 ms after, ≈ 100 ms the first open), bugs/118. Rewritten whole after the clean-instance read of 2026-11-22 21:37.
  The update size of the last paragraph is the «download» number of make_manifest.py against published_0_9_1-RC3/manifest.json, filled after the build.
  A paragraph is ONE line (GitHub Releases keeps single line breaks).
-->

<h3 align="center"><em>Krinik Mod Pack 0.9.1-RC4 · Conan Exiles Enhanced 3.1.1</em></h3>

<a name="русский"></a>
## Русский · [English](#english)

RC4 исправляет четыре мода сборки (KrinikConanCamera, KrinikConanUI, KrinikConanLocomotion и KrinikConanArchery) и обновляет лаунчер до версии 1.1.1. Полное описание версии 0.9.1, установка и известные проблемы приведены на странице выпуска [0.9.1-RC1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC1).

- Исправлен баг тени в виде от первого лица: у тени героя не было головы. Теперь тень героя целая, с головой.
- Исправлен баг вида от первого лица: лук за спиной героя попадал в кадр. Теперь оружие за спиной героя в кадр не попадает, и тень оружия по-прежнему падает на землю.
- Исправлен баг паузы: сборка принимала экран загрузки при входе в подземелье и при выходе из него за открытое меню и ставила игру на паузу. После такого экрана загрузки мир замирал. Теперь после экрана загрузки мир идёт с обычной скоростью.
- Исправлен баг журнала UE4SS: пока герой был мёртв, моды движения и лука писали в журнал ошибки. Теперь, пока герой мёртв, эти моды ошибок не пишут.
- Лаунчер 1.1.1 быстрее открывает табличку «Как прислать отзыв или отчёт о падении» по кнопке «Отзыв». Раньше при каждом следующем нажатии табличка открывалась примерно за 0,08 секунды. Теперь она открывается примерно за 0,01 секунды. В первый раз после запуска лаунчера табличка по-прежнему открывается примерно за 0,1 секунды.

Лаунчер прежних выпусков покажет плашку «Вышел лаунчер 1.1.1». Нажмите на плашке кнопку «Обновить лаунчер». Когда лаунчер обновится, нажмите кнопку «Обновить сборку».

<a name="english"></a>
## English · [Русский](#русский)

RC4 fixes four mods in the pack (KrinikConanCamera, KrinikConanUI, KrinikConanLocomotion and KrinikConanArchery) and updates the launcher to version 1.1.1. The full description of 0.9.1, installation and known issues are on the [0.9.1-RC1](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/releases/tag/v0.9.1-RC1) release page.

- Fixed a bug with the shadow in first-person view: the hero’s shadow had no head. The hero now casts a whole shadow, head included.
- Fixed a bug in first-person view: the bow on the hero’s back showed up in the frame. A weapon on the hero’s back now stays out of the frame, and it still casts its shadow on the ground.
- Fixed a bug with the pause: the mod pack mistook the loading screen on entering or leaving a dungeon for an open menu and paused the game. After such a loading screen the world froze. The world now runs at its normal pace after a loading screen.
- Fixed a UE4SS log bug: while the hero was dead, the movement and archery mods wrote errors to the log. They no longer write errors while the hero is dead.
- Launcher 1.1.1 opens the “How to send feedback or a crash report” panel faster when you click “Feedback”. Each later click used to open it in about 0.08 seconds; it now opens in about 0.01 seconds. The first time after the launcher starts, the panel still opens in about 0.1 seconds.

A launcher from an earlier release shows the notice “Launcher 1.1.1 is out”. Click “Update launcher” on the notice. When the launcher has updated, click “Update mod pack”.
