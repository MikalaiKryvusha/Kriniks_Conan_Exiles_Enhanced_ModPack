<!-- krinik-game: 3.1.1 CL-383549 -->
<!--
  The first line is the launcher's marker: it matches this release to the game (modpack.json launcher.gameVersion 3.1.1, builtFor CL-383549). Keep it the FIRST line.
  This file is the body of the GitHub release page: a paragraph is ONE line (GitHub Releases keeps single line breaks).
  Check before publishing: no two non-empty lines in a row outside lists and tables.
  2026-11-20 16:2x: «What's new» rebuilt by large features after the owner's reading of the published RC1 page (KUMM PROJECT_HISTORY entries 2026-11-20 16:19 and
  16:23–16:25): every big work with its facts and numbers, private details folded into their feature. Sources of the numbers: KUMM testcases/reports
  2026-11-09_conan-quickwin-n1-async-navmesh.md (−48 % hitches, −43 % worst frame, 1 % low +12 %), 2026-11-09_conan-quickwins-shaders-on-load.md (−31 %),
  2026-11-06_conan-quickwin-chaos-queue.md (−28 %), 2026-11-09_conan-water-fps-after-ram-tuning.md (+4.7 %), 2026-11-07_conan-palm-shadow-wpo-bound-fix.md
  (12–16 % → 0.06–0.44 %), 2026-11-09_conan-water-reflections-five-scenes.md (≈ −1.5 %); researches/conan-hitch-profiler (≈ 24 % of the game thread).
  The release date line is added at publication. Once the volumes are built, make_release.sh step 4b fills {{ARCHIVE_SIZE}} (the RU half) and
  {{ARCHIVE_SIZE_EN}} (the EN half) with the total size of the parts in a copy of these notes; this draft keeps both placeholders for the next RC.
  While the public main stays at the 0.9.0 tree, the logo is that tree's _config/branding/ path and the README links point to the README top;
  the 0.9.1 tree moves the logo to art/logos/ (pack commit 6240a47). The cover of 0.9.1 (V2 «Реализм», _config/release/draft_0_9_1/nexus_media/cover_0_9_1.webp)
  is wired in place of the logo once its public path is fixed (KUMM plans/55 D-art).
  The launcher KrinikConanLauncher.exe and the parts Krinik_Mod_Pack_0_9_1_RC1.zip.001 … are assets of this release (KUMM plans/55 criterion 8, R7).
-->

<p align="center">
  <img src="https://raw.githubusercontent.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/main/art/logos/krinik-modpack-logo.webp" alt="Krinik Mod Pack" width="560">
</p>

<h3 align="center"><em>Krinik Mod Pack 0.9.1-RC1 · Conan Exiles Enhanced 3.1.1</em></h3>

> **Тестовая сборка / Test build**

<a name="русский"></a>
## Русский · [English](#english)

**Коротко.** Krinik Mod Pack 0.9.1-RC1 — это тестовая версия сборки 0.9.1 для Conan Exiles Enhanced 3.1.1 (билд CL-383549). Автор выпускает её перед версией 0.9.1, чтобы проверить установку сборки от начала до конца. Если при установке или в игре что-то пошло не так, сообщите об этом автору сборки, как описано в разделе «Отзывы» ниже.

Главное в версии 0.9.1:

- Лаунчер 1.0.0 сам находит игру на компьютере, скачивает сборку с GitHub и устанавливает её.
- Новый мод KrinikConanEngineTweaks устраняет три причины, по которым игра замирала на миг.
- Тени от листвы больше не мерцают, и солнце движется по небу плавно.
- Вода отражает дальний берег, скалы и арки.
- Атрибуты героя прокачиваются без предела.
- С новым модом KrinikConanLocomotion герой отталкивается прыжком от стен и бежит спринтом с натянутым луком.

Ниже перечислено только то, что изменилось с версии 0.9.0. Возможности сборки, её состав, авторы модов и правообладатели описаны в [README](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack). Руководство пользователя `Krinik-Conan-3.1.1-guide.pdf` приложено к выпуску и лежит в архиве сборки.

---

### ✨ Что нового в 0.9.1

**Игра 3.1.1**

Сборка перешла на Conan Exiles Enhanced 3.1.1 (билд CL-383549).

**Лаунчер 1.0.0**

Лаунчер KrinikConanLauncher обновлён до версии 1.0.0 и ставит сборку сам, от начала до конца. Он находит игру на компьютере, скачивает части архива сборки с GitHub, проверяет их и устанавливает сборку. Пока идут скачивание и установка, лаунчер показывает, сколько процентов готово, скорость, сколько времени прошло и сколько осталось. Если скачивание прервалось, лаунчер продолжит его с того места, где оно остановилось.

Когда выходит новая версия сборки или самого лаунчера, лаунчер показывает это в своём окне, и новая версия ставится одной кнопкой: «Обновить сборку» или «Обновить лаунчер». Настройки и сохранения игрока после обновления сборки остаются на месте. Кнопка «Что нового» под версией игры открывает новость об обновлении игры в Steam, а кнопка под версией сборки открывает описание последнего выпуска сборки на GitHub. Если игра упала, лаунчер при следующем запуске предлагает собрать отчёт и открывает на GitHub форму нового сообщения в разделе Issues.

Лаунчер поддерживает мультиязычность: в поле «Язык окна» можно выбрать русский или английский язык.

**Производительность**

Автор сборки проследил профилировщиком, чем занят движок в те мгновения, когда игра замирает, и нашёл три причины таких замираний. Все три устраняет новый мод сборки KrinikConanEngineTweaks: он меняет настройки движка в файле `Engine.ini`. Каждую правку автор проверял отдельно: облетал мир по одному маршруту несколько раз, попеременно с правкой и без неё. Замиранием в этих замерах считается кадр дольше 50 мс.

- Данные о местности, по которым NPC ищут путь, движок теперь собирает в фоновых потоках. В игре без сборки этим занят игровой поток, и в полёте над миром сбор отнимает у него около четверти времени. С правкой замираний стало на 48 % меньше, а самый долгий кадр сократился на 43 %. Показатель 1 % low (средняя частота самых медленных кадров) вырос на 12 %.
- Шейдеры визуальных эффектов Niagara движок теперь готовит заранее, когда загружает эффект. Замираний стало на 31 % меньше.
- Когда в мир подгружается много объектов, физический движок Chaos теперь перестраивает свою структуру поиска столкновений по частям за несколько кадров. В игре без сборки он перестраивает её целиком за один кадр, как только в очереди набирается больше 1000 изменений. Замираний стало на 28 % меньше.

Сборка снижает дальность прорисовки с 2,0 до 1,5. Кадров в секунду стало примерно на 5 % больше, а картинка почти не изменилась.

**Тени и движение солнца**

В Conan Exiles Enhanced тени от листьев пальм и другой листвы мерцают, когда солнце движется по небу. В сборке 0.9.0 солнце сдвигалось редкими шагами, чтобы тени не мерцали, и раз в несколько секунд тени скачком меняли положение. Автор сборки нашёл причину мерцания в материале листвы самой игры. В материале не задано, насколько далеко ветер отклоняет листья, и в части кадров отклонённые ветром листья пропадают из тени. Мод KrinikConanGraphics исправляет материал листвы. Теперь солнце и тени движутся плавно, без скачков, и мерцания больше нет. Под пальмой на ветру мерцало от 12 % до 16 % точек тени на земле, а после правки мерцает меньше 0,5 %.

**Отражения в воде**

Сборка строит отражения в воде программным Lumen, системой освещения Unreal Engine 5, и увеличивает дальность его лучей. Вода отражает дальний берег, скалы и арки, и отражение не рвётся за стволами пальм. Аппаратная трассировка лучей для таких отражений не нужна, а частота кадров с ними снижается примерно на 1,5 %.

**Прыжки и бег с луком**

Новый мод автора сборки KrinikConanLocomotion учит героя новым движениям. Герой бьёт оружием ближнего боя в прыжке и бежит спринтом с натянутым луком. Со стены, на которую он лезет, герой отталкивается прыжком и в полёте после такого прыжка стреляет из лука. Пока герой висит на стене, он понемногу тратит запас сил.

**Развитие героя**

Атрибуты героя теперь прокачиваются без предела: в каждый можно вложить больше 20 очков. Шкала атрибута показывает очки страницами по 20 и листается стрелками под шкалой или колесом мыши. Для каждого уровня герою нужно вдвое больше опыта, чем в версии 0.9.0. Сборка ослабила черту Проворства «Верная рука»: с ней стрелы и метательное оружие летят на 20 % быстрее, а в игре без сборки вдвое быстрее.

**Интерфейс, перевод и обои**

- Подсказки, которые появляются у собеседника, постройки, раба и раненого союзника, стали меньше, сдвинулись левее героя и получили более прозрачный фон, как подсказка у трупа.
- Значки голода, жажды и веса мигают в одном ритме.
- Мод ModControlPanel убран из сборки. Настройки Less Building Placement Restrictions теперь открываются из пункта «Прочее» списка «Настройки модов».
- В загоне для животных Emberlight, на панели администратора Ironlight-Settlements и в настройках Pickup+ на русский язык переведены надписи, которые оставались английскими. В окне зачарования и в меню администратора Enhanced Armory and Arsenal, в окне новой метки Simple Minimap и в настройках возрождения Al-Merayah Reborn русский текст теперь помещается в свои кнопки и поля.
- В архиве лежат новые обои для рабочего стола: V2 «Тёплый», V2 «Реализм», V2 female beta «Реализм» и V2 female beta «Тёплый». Каждый вариант есть в разрешениях 4K, 2K и 1080p.

**Исправлено**

- Сборка устранила причину, по которой игра изредка падала, когда игрок щёлкал мышью или нажимал Esc в окне мода сборки, а также когда герой убивал врага из лука.
- Крафт, начатый в открытом хабе, после закрытия хаба идёт с обычной скоростью. В версии 0.9.0 вся очередь крафта заканчивалась мгновенно.
- Вкладка «Путешествие» в хабе обновляется каждый раз, когда появляется на экране, и сразу показывает только что открытые путешествия.
- Семь боссов вновь можно оглушить и взять в рабы: раньше этому мешал конфликт модов.
- От первого лица видно, как герой держит лук, когда смотрит вниз.
- Полоска здоровья над врагом больше не закрывает его самого и поднята чуть выше значка черепа.
- Над трупом в кустах теперь видна одна подсказка, без второй подсказки «E Взять».
- Описания черт на вкладке «Хар-ки» больше не наползают друг на друга и прокручиваются колесом мыши.
- При переключении вкладок хаба по экрану больше не пробегает тёмная волна. Когда игрок переходит на вкладку «Снаряжение» или уходит с неё, сквозь страницу хаба больше не виден игровой мир.

---

### ⚠️ Известные проблемы

- В сумерках свет и небо иногда меняются скачком.
- При переключении между вкладками «Параметры» и «Снаряжение» хаб примерно на десятую долю секунды показывает тёмный фон, пока игра готовит новую вкладку.
- Текст на вкладках меню слегка дрожит при переключении.
- Когда герой забирает предмет клавишей F, рамка выбора в окне быстрой добычи иногда прыгает в последнюю клетку.
- В окнах настроек некоторых модов русский текст местами не помещается в кнопки и поля, например в окне «Система аксессуаров».
- Названия и описания классов на карточках Enhanced Armory and Arsenal остались английскими: текст нарисован прямо на картинках.
- В обучении маркерам Simple Minimap строки появляются с большой задержкой, а место под слайды остаётся чёрным.

### 🗺️ Планы на 1.0.0

- Исправить каждую проблему из списка выше.
- Сделать так, чтобы пункт «Моды Xevyr'а» в списке «Настройки модов» открывал общее окно с настройками всех модов Xevyr'а.
- Проверить каждое окно сборки в разрешениях 720p, 1080p, 2K и 4K.
- Замерить, насколько моды сборки нагружают игру в бою и в пути.
- Проверить, что долгая игра идёт без вылетов.

---

### 📦 Установка

1. Убедитесь, что установлена игра Conan Exiles Enhanced 3.1.1 (билд CL-383549).
2. Скачайте из списка **Assets** внизу страницы лаунчер `KrinikConanLauncher.exe` и запустите его. Лаунчер сам найдёт игру на компьютере.
3. Нажмите «Установить сборку». Лаунчер скачает части архива сборки, проверит их и установит сборку.
4. Нажмите «Играть».

Если лаунчер не нашёл игру, нажмите «Указать папку игры» и выберите папку, где лежит `ConanSandbox.exe`. Части архива `Krinik_Mod_Pack_0_9_1_RC1.zip.001`, `Krinik_Mod_Pack_0_9_1_RC1.zip.002` и следующие, всего {{ARCHIVE_SIZE}}, можно скачать и самому. Положите их в ту же папку, где лежит лаунчер, и лаунчер установит сборку из них, ничего не скачивая.

Сборку можно поставить и прямо из архива. Проводник Windows не открывает архив, разбитый на части. Откройте первую часть, `Krinik_Mod_Pack_0_9_1_RC1.zip.001`, в 7-Zip или WinRAR и распакуйте сборку в папку игры, где лежит `ConanSandbox.exe`. Затем запустите `KrinikConanLauncher.exe` из папки сборки `Krinik_Mod_Pack_0_9_1_RC1`, которая появится в папке игры, и нажмите «Установить сборку».

Чтобы удалить сборку, закройте игру, запустите `KrinikConanLauncher.exe`, нажмите «Удалить сборку» и подтвердите удаление. Игра вернётся в то состояние, в котором была до установки сборки.

### 💬 Отзывы

Отзывы, вопросы, сообщения о сбоях и предложения присылайте автору сборки по электронной почте [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru) или сообщением в разделе [Issues](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/issues) репозитория сборки. Если игра вылетела, зависла или мод в ней работает неправильно, приложите к сообщению отчёт. Чтобы собрать отчёт, нажмите кнопку «Отзыв» в главном меню игры или в меню Esc и дождитесь, пока на рабочем столе появится файл `Conan-report-<дата>_<время>.zip`. Если игра упала, лаунчер при следующем запуске сам предложит собрать отчёт и откроет новое сообщение в разделе Issues.

### 🔗 Ссылки

- Почта: [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru)
- Страница сборки на Nexus Mods: [nexusmods.com/conanexilesenhanced/mods/65](https://www.nexusmods.com/conanexilesenhanced/mods/65)
- Публичный репозиторий сборки на GitHub: [github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack)

---

<a name="english"></a>
## English · [Русский](#русский)

**In short.** Krinik Mod Pack 0.9.1-RC1 is a test build of version 0.9.1 for Conan Exiles Enhanced 3.1.1 (build CL-383549). It comes out ahead of 0.9.1 so that the whole installation path of the pack can be tested. If anything goes wrong during installation or in the game, please let the pack author know: the Feedback section below explains how.

The highlights of 0.9.1:

- Launcher 1.0.0 finds the game on your computer, downloads the pack from GitHub and installs it.
- The new mod KrinikConanEngineTweaks fixes three causes of the brief freezes in the game's engine.
- Foliage shadows no longer flicker, and the sun moves smoothly across the sky.
- The water reflects the far shore, the cliffs and the arches.
- Hero attributes have no cap.
- With the new mod KrinikConanLocomotion the hero pushes off walls with a jump and sprints with a drawn bow.

Only the changes since 0.9.0 are listed below. The [README](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack) describes what the pack does and what it contains, and names the mod authors and the rights holders. The user guide `Krinik-Conan-3.1.1-guide.pdf` (in Russian) is attached to this release and is also included in the pack archive.

---

### ✨ What's new in 0.9.1

**Game 3.1.1**

The pack now runs on Conan Exiles Enhanced 3.1.1 (build CL-383549).

**Launcher 1.0.0**

The launcher, KrinikConanLauncher, has been updated to version 1.0.0 and installs the pack on its own from start to finish. It finds the game on your computer, downloads the pack archive parts from GitHub, verifies them and installs the pack. It shows the download and installation progress as a percentage together with the speed, the time left and the time elapsed. An interrupted download resumes where it left off.

When a new version of the pack or of the launcher itself is out, the launcher tells you, and each one installs with a single button: “Update mod pack” or “Update launcher”. Your settings and saves stay in place after a pack update. The “What's new” buttons under the game and pack versions open the game update's news post on Steam and the description of the latest pack release on GitHub. If the game crashes, the launcher offers to collect a report the next time it starts and opens a new issue on GitHub.

The launcher supports several languages: pick Russian or English in the “Window language” field.

**Performance**

The pack author recorded a profile of the engine's work in the frames where the game freezes for a moment and found three causes of these freezes. The new mod KrinikConanEngineTweaks removes all three by changing engine settings in `Engine.ini`. The author tested each fix on its own, on the same flight route over the world, comparing the game with and without the fix over several alternating flights. A freeze here is a frame longer than 50 ms.

- The engine now gathers the terrain data that NPCs use to find their path on background threads. In the game without the pack this gathering runs on the game thread and takes about a quarter of its time during a flight over the world. With the fix there are 48 percent fewer freezes, the longest frame is 43 percent shorter, and the 1 % low frame rate (the frame rate over the slowest 1 % of frames) is 12 percent higher.
- The engine now prepares the shaders of Niagara visual effects in advance, when it loads an effect. There are 31 percent fewer freezes.
- When many objects stream into the world, the Chaos physics engine now rebuilds its collision search structure in parts over several frames. In the game without the pack it rebuilds the whole structure in a single frame as soon as more than 1000 changes are queued. There are 28 percent fewer freezes.

The draw distance is lowered from 2.0 to 1.5. The game shows about 5 percent more frames per second, and the picture looks almost the same.

**Shadows and the sun**

In Conan Exiles Enhanced the shadows of palm leaves and other foliage flicker while the sun moves across the sky. Pack 0.9.0 moved the sun in rare steps to hide the flicker, so the shadows jumped after the sun every few seconds. The pack author found the cause of the flicker in the game's own foliage material. The material does not tell the engine how far the wind bends the leaves, and on some frames the engine drops the bent leaves from the shadow. The KrinikConanGraphics mod fixes the foliage material. The sun and the shadows now move smoothly, without jumps, and the foliage shadows no longer flicker. Under a palm in the wind, 12–16 percent of the shadow's pixels on the ground used to flicker; after the fix, fewer than 0.5 percent do.

**Water reflections**

Water reflections are now computed by software Lumen, the lighting system of Unreal Engine 5, with a longer ray reach. The water reflects the far shore, the cliffs and the arches, and the reflection does not break behind palm trunks. These reflections need no hardware ray tracing and lower the frame rate by about 1.5 percent.

**Jumps and running with a bow**

KrinikConanLocomotion, a new mod by the pack author, gives the hero new moves. The hero strikes with a melee weapon mid-jump, sprints with a drawn bow, jumps off a wall while climbing it and can shoot the bow in mid-air after that jump. Hanging on a wall slowly drains the hero's stamina.

**Hero progression**

Hero attributes have no cap: each attribute can take more than 20 points. An attribute bar shows the points in pages of 20, and you page it with the arrows under the bar or with the mouse wheel. Each level now takes twice as much experience as in 0.9.0. The pack weakens the Agility perk “Верная рука” (Dead Shot): with it, arrows and thrown weapons fly 20 percent faster, while in the game without the pack they fly twice as fast.

**Interface, translation and wallpapers**

- The interaction prompts for a person to talk to, a building, a thrall and a downed ally are smaller, sit to the left of the hero and have a more transparent background, like the corpse prompt.
- The hunger, thirst and weight icons blink in sync.
- The ModControlPanel mod has been removed from the pack. The settings of Less Building Placement Restrictions now open from “Прочее” (Other) in the “Настройки модов” (Mod settings) list.
- Labels that were still in English are now in Russian in the Emberlight animal pen, on the Ironlight-Settlements admin panel and in the Pickup+ settings. The Russian text now fits its buttons and fields in the enchanting window and the admin menu of Enhanced Armory and Arsenal, in the new-marker window of Simple Minimap and in the respawn settings of Al-Merayah Reborn.
- New desktop wallpapers: V2 “Тёплый” (Warm), V2 “Реализм” (Realism), V2 female beta “Реализм” (Realism) and V2 female beta “Тёплый” (Warm). The archive has each of them in 4K, 2K and 1080p.

**Fixed**

- Removed the cause of a rare game crash that could happen when you clicked or pressed Esc in a mod window of the pack, or when the hero killed an enemy with a bow.
- Crafting started while the hub is open keeps its normal speed after the hub is closed. In 0.9.0 the whole crafting queue finished instantly.
- The “Путешествие” (Journey) tab of the hub refreshes every time it is shown and lists newly unlocked journeys right away.
- Seven bosses can once again be knocked out and taken as thralls; a mod conflict had taken this away.
- In first-person view the bow is visible in the hero's hands when the hero holds it and looks down.
- An enemy's health bar no longer covers the enemy and sits slightly above the skull icon.
- Over a corpse in bushes, only the corpse prompt appears, without a second “E Взять” (E Take) prompt.
- Perk descriptions on the “Хар-ки” (Attributes) tab no longer overlap and scroll with the mouse wheel.
- Switching hub tabs no longer sends a dark wave across the screen. Switching to or from the “Снаряжение” (Equipment) tab no longer lets the game world show through the hub page.

---

### ⚠️ Known issues

- At dusk the light and the sky sometimes change abruptly.
- Switching between the “Параметры” (Character) and “Снаряжение” (Equipment) hub tabs shows a dark background for about a tenth of a second while the game builds the new tab.
- The text on the menu tabs jitters slightly while switching.
- When the hero takes an item with F, the selection frame in the quick loot window sometimes jumps to the last cell.
- In the settings windows of some mods the Russian text does not always fit the buttons and fields, for example in the “Система аксессуаров” (Accessory system) window.
- Class names and descriptions on the Enhanced Armory and Arsenal cards are still in English: the text is baked into the images.
- In the Simple Minimap marker tutorial the lines appear with a long delay, and the slide area stays black.

### 🗺️ Plans for 1.0.0

- Fix every issue in the list above.
- Make the “Моды Xevyr'а” (Xevyr's mods) entry in the “Настройки модов” (Mod settings) list open one window with the settings of all of Xevyr's mods.
- Check every window of the pack at 720p, 1080p, 2K and 4K.
- Measure the performance cost of the pack's mods in combat and while traveling.
- Check that a long play session runs without crashes.

---

### 📦 Installation

1. Make sure Conan Exiles Enhanced 3.1.1 (build CL-383549) is installed.
2. Download the launcher `KrinikConanLauncher.exe` from the **Assets** list at the bottom of this page and run it. The launcher finds the game on your computer by itself.
3. Press “Install mod pack”. The launcher downloads the pack archive parts, verifies them and installs the pack.
4. Press “Play”.

If the launcher cannot find the game, press “Choose game folder” and pick the folder that contains `ConanSandbox.exe`. You can also download the archive parts `Krinik_Mod_Pack_0_9_1_RC1.zip.001`, `Krinik_Mod_Pack_0_9_1_RC1.zip.002` and the rest ({{ARCHIVE_SIZE_EN}} in total) manually: put them in the same folder as the launcher, and the launcher installs the pack from them without downloading anything.

You can also install the pack straight from the archive. Windows Explorer cannot open the parts of this archive, so open the first part, `Krinik_Mod_Pack_0_9_1_RC1.zip.001`, in 7-Zip or WinRAR and extract the pack into the game folder, the one that contains `ConanSandbox.exe`. Then run `KrinikConanLauncher.exe` from the pack folder `Krinik_Mod_Pack_0_9_1_RC1` that appears in the game folder, and press “Install mod pack”.

To remove the pack, close the game, run `KrinikConanLauncher.exe`, press “Remove mod pack” and confirm. The game returns to the state it was in before the pack was installed.

### 💬 Feedback

Send feedback, questions, crash reports and suggestions to the pack author by email at [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru) or as an issue in the [Issues](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/issues) section of the pack repository. If the game crashes or freezes, or a mod misbehaves, attach a report to your message. To collect a report, press the “Отзыв” (Feedback) button in the game's main menu or in the Esc menu and wait until `Conan-report-<date>_<time>.zip` appears on your desktop. If the game crashes, the launcher offers to collect a report the next time it starts and opens a new issue for you.

### 🔗 Links

- Email: [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru)
- Pack page on Nexus Mods: [nexusmods.com/conanexilesenhanced/mods/65](https://www.nexusmods.com/conanexilesenhanced/mods/65)
- Public repository of the pack on GitHub: [github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack)

---

<p align="center"><sub>Лицензия MIT, © 2026 <b>Mikalai Kryvusha</b> aka <b>KOT KRINIK</b> · Николай Кривуша aka Кот Криник. Моды других авторов принадлежат своим правообладателям, которые названы в <a href="https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack">README</a>.</sub></p>

<p align="center"><sub>MIT license, © 2026 <b>Mikalai Kryvusha</b> aka <b>KOT KRINIK</b>. Mods by other authors belong to their rights holders, who are named in the <a href="https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack">README</a>.</sub></p>
