<p align="center">
  <img src="art/logos/krinik-modpack-logo.webp" alt="Krinik Mod Pack" width="640">
</p>

<a id="russian"></a>

# Krinik's Conan Exiles Enhanced ModPack

<h3 align="center"><em>Сборка модов Krinik Mod Pack 0.9.1-RC1 для Conan Exiles Enhanced 3.1.1</em></h3>

<p align="center">
  <a href="#russian"><img src="https://img.shields.io/badge/Русский-C0392B?style=for-the-badge" alt="Русский"></a>
  &nbsp;
  <a href="#english"><img src="https://img.shields.io/badge/English-2C7BE5?style=for-the-badge" alt="English"></a>
</p>

[![Лицензия: MIT](https://img.shields.io/badge/Лицензия-MIT-FF1A8C.svg?style=flat-square)](LICENSE)
[![Версия сборки](https://img.shields.io/badge/Версия_сборки-0.9.1--RC1-FF1A8C.svg?style=flat-square)](#1-общие-сведения)
[![Игра](https://img.shields.io/badge/Conan_Exiles_Enhanced-3.1.1-brightgreen.svg?style=flat-square)](#3-установка)
[![Моды](https://img.shields.io/badge/Модов-9_+_63-8E44AD.svg?style=flat-square)](#2-состав-сборки)

<p align="center">
  <a href="#1-общие-сведения">Общие сведения</a> · <a href="#2-состав-сборки">Состав</a> · <a href="#3-установка">Установка</a> · <a href="#4-удаление">Удаление</a> · <a href="#5-отзывы-и-обратная-связь">Отзывы</a> · <a href="#6-ссылки">Ссылки</a> · <a href="#7-правообладатели-и-отказ-от-ответственности">Правообладатели</a> · <a href="#8-лицензия">Лицензия</a>
</p>

**Сборка модов Krinik Mod Pack для Conan Exiles Enhanced 3.1.1 объединяет 9 модов автора сборки, 63 мода других авторов из Мастерской Steam и с Nexus Mods, загрузчик UE4SS и лаунчер, и все моды в ней переведены на русский язык.**

Установить сборку, обновить её, запустить с ней игру и удалить сборку можно в одном окне лаунчера. Лаунчер находит игру на компьютере и может скачать сборку с GitHub. О новой версии сборки лаунчер сообщает сам, а себя обновляет отдельно от сборки. Отчёт для автора сборки игрок собирает прямо из меню игры.

## 1. Общие сведения

### 1.1. О сборке

1. Версия сборки 0.9.1-RC1 собрана для Conan Exiles Enhanced 3.1.1 (билд CL-383549). Номер с окончанием RC и цифрой носит тестовая сборка: например, сборка 0.9.1-RC1 выходит перед версией 0.9.1, чтобы автор мог проверить весь путь установки. Версия 0.9.0 от 2 ноября 2026 года стала первым выпуском сборки для Conan Exiles Enhanced 3.0.1 (билд CL-379176). Затем сборка перешла на версию игры 3.1.0, а 17 ноября 2026 года на 3.1.1. Раньше автор готовил сборку под версии игры 2.1.1 и 2.2.3. Номер 1.0.0 у сборки встречается дважды: так называлась ранняя бета-версия для игры 2.2.3, и так будет называться первый полноценный выпуск сборки. Что в сборке ещё не доделано и что автор собирается сделать к этому выпуску, перечислено в главе «Известные проблемы и планы на 1.0.0» руководства пользователя.
2. Состав сборки и порядок загрузки модов задаёт манифест `modpack.json`. Файлы сборки по папке игры раскладывает движок [KUMM](https://github.com/MikalaiKryvusha/kumm).
3. Все моды сборки переведены на русский язык, и термины для перевода взяты из русской версии игры.
4. Руководство пользователя лежит в файле [docs/guide/Krinik-Conan-3.1.1-guide.pdf](docs/guide/Krinik-Conan-3.1.1-guide.pdf). В нём описаны возможности сборки, клавиши, состав и история версий.

### 1.2. Содержимое репозитория

| Путь | Содержимое |
|---|---|
| `modpack.json` | манифест сборки: моды в порядке загрузки, их источники и версии |
| `_unpacked/` | исходники модов автора сборки и загрузчик UE4SS |
| `_config/` | конфиги игры, лаунчер, деинсталлятор, файлы перевода, инструменты сборки |
| `docs/guide/` | руководство пользователя: PDF и его HTML-исходник |
| `docs/` | заметки по игре, модам и их совместимости |
| `art/` | логотипы, значки, снимки экрана и обои сборки вместе с исходниками обоев |

Архивы модов других авторов в репозитории не хранятся: автор сборки берёт их из Мастерской Steam и с Nexus Mods, когда собирает выпуск. Игрок получает все моды готовыми в архиве сборки и ничего не скачивает отдельно.

## 2. Состав сборки

В сборку входят 9 модов её автора, загрузчик UE4SS и 63 мода других авторов. Тексты модов других авторов переводит на русский язык мод KrinikConanRussianTranslation. Пометку **KRINIK MODIFIED** носит мод другого автора, в файлах которого автор сборки сам что-то изменил: перевёл тексты, до которых общий перевод не доходит, поправил интерфейс или исправил ошибки.

Таблица 1 — Моды сборки

| № | Мод | Автор | Что делает |
|---|---|---|---|
| 1 | [KrinikConanCamera](_unpacked/KrinikConanCamera) | Кот Криник | Камера от третьего лица стоит строго за спиной героя. Клавишами цифрового блока игрок меняет расстояние до камеры, её высоту, боковое смещение и наклон взгляда, сохраняет положение камеры, возвращает его и сбрасывает камеру в положение по умолчанию. |
| 2 | [KrinikConanArchery](_unpacked/KrinikConanArchery) | Кот Криник | Стрела летит по дуге в точку прицела, и её скорость задаёт сила натяжения лука, как в The Elder Scrolls IV: Oblivion. В виде от первого лица видно лук в руках героя. |
| 3 | [KrinikConanGameplay](_unpacked/KrinikConanGameplay) | Кот Криник | Прокачка героя до 10 000 уровня, атрибуты без предела. |
| 4 | [KrinikConanLocomotion](_unpacked/KrinikConanLocomotion) | Кот Криник | В прыжке герой стреляет из лука и бьёт оружием ближнего боя, а с натянутым луком бежит спринтом. Герой отталкивается прыжком от стены, по которой лезет, и стреляет из лука в полёте после такого прыжка. Пока герой висит на стене, он понемногу тратит запас сил. За каждое очко Проворства герой быстрее бегает и выше прыгает. |
| 5 | [KrinikConanUI](_unpacked/KrinikConanUI) | Кот Криник | Пока открыт инвентарь или хаб, игра стоит на паузе. HUD Hosav переработан, чтобы его было легче читать. В правом верхнем углу экрана стоит счётчик кадров, а в главном меню и в меню Esc появилась кнопка «Отзыв». |
| 6 | [KrinikConanGraphics](_unpacked/KrinikConanGraphics) | Кот Криник | Солнце и тени движутся плавно, без скачков. Тени от листьев пальм и другой листвы не мерцают: мод исправляет материал листвы самой игры. Вода отражает дальний берег, скалы и арки. Пятна крови лежат на земле до пяти минут и плавно гаснут. В мод входят настройки графики, подобранные для сборки: дальность прорисовки, тени, туман и DLSS. |
| 7 | [KrinikConanEngineTweaks](_unpacked/KrinikConanEngineTweaks) | Кот Криник | Три правки движка убирают причины, по которым игра замирает на миг в путешествии по миру. Данные о местности для поиска пути NPC движок собирает в фоновых потоках, шейдеры визуальных эффектов Niagara готовит заранее при загрузке эффекта, а структуру поиска столкновений после подгрузки новых мест перестраивает по частям за несколько кадров. В полёте над миром каждая правка сократила число замираний дольше 50 мс: на 48 %, на 31 % и на 28 %. |
| 8 | [KrinikConanRussianTranslation](_config/localization) | Кот Криник | Русский перевод текстов всех модов сборки. |
| 9 | [KrinikConanModPackManager](_unpacked/KrinikConanModPackManager) | Кот Криник | Заставка на всё время загрузки игры и строка состояния сборки в главном меню: сколько модов сборки загрузила игра. |
| 10 | [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) | Narknon, UE4SS-RE | Загрузчик Lua-модов для Unreal Engine. На нём работают Lua-моды сборки. |
| 11 | [Hosav's Custom UI](https://steamcommunity.com/sharedfiles/filedetails/?id=3748867573)<br><sub>KRINIK MODIFIED</sub> | Hosav | Интерфейс игры заменён настраиваемым HUD, у которого больше 50 параметров. |
| 12 | [Simple Minimap](https://steamcommunity.com/sharedfiles/filedetails/?id=3719513784)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Мини-карта с метками мест и пятью ступенями приближения. |
| 13 | [Simple Modlist](https://steamcommunity.com/sharedfiles/filedetails/?id=3719546290)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Список включённых модов с версиями в меню Esc. |
| 14 | [The Damage Meter](https://steamcommunity.com/sharedfiles/filedetails/?id=3719585133)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Счётчик в реальном времени показывает, сколько урона наносят герой, спутники и другие игроки, всего и в секунду. |
| 15 | [Proximity Party](https://steamcommunity.com/sharedfiles/filedetails/?id=3718878457)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Полоски здоровья ближних спутников и соклановцев, до 15 одновременно. |
| 16 | [Lore & Loot Highlight](https://steamcommunity.com/sharedfiles/filedetails/?id=3718655125)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Подсветка контуром всего, с чем можно взаимодействовать, и отдельный цвет для сундуков с добычей. |
| 17 | [Pickup+](https://steamcommunity.com/sharedfiles/filedetails/?id=864199675) | nO Pa!N | Возврат любой поставленной вещи в инвентарь. |
| 18 | [PackRat Helper](https://steamcommunity.com/sharedfiles/filedetails/?id=2596031352) | thelich | Раскладка рюкзака по сундукам и станциям, где уже лежат такие же вещи. |
| 19 | [Inventory Compactor](https://steamcommunity.com/sharedfiles/filedetails/?id=3718614759) | Xevyr | Кнопка уплотнения инвентаря: уборка пустых ячеек и объединение стопок. |
| 20 | [Organizer Sorting Chest](https://steamcommunity.com/sharedfiles/filedetails/?id=3723101055) | Mikey | Сундук-сортировщик: положенная в него добыча расходится по сундукам вокруг, где лежат такие же вещи. |
| 21 | [Chest Labels](https://steamcommunity.com/sharedfiles/filedetails/?id=3735258746) | Xevyr | Надписи с именем сундука или шкафа на самой мебели. |
| 22 | [Storage Reach Expanded](https://steamcommunity.com/sharedfiles/filedetails/?id=3733835102)<br><sub>KRINIK MODIFIED</sub> | Seriihn | Строительство и крафт из сундуков всей базы. |
| 23 | [Double Storage Space](https://steamcommunity.com/sharedfiles/filedetails/?id=3803465771) | Dog Patch 06 | Удвоена вместимость хранилищ. |
| 24 | [Less Building Placement Restrictions](https://steamcommunity.com/sharedfiles/filedetails/?id=3755091710)<br><sub>KRINIK MODIFIED</sub> | Multigun | Сняты запреты игры, которые мешали ставить постройки на свободном месте. Настройки открываются из списка «Настройки модов» → «Прочее». |
| 25 | [Beyond Decor: Rustic Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=3729154757) | Cateyes | Более 3 000 предметов деревенского убранства: спальня, кухня и столовая, гостиная, сад, рынок и лавки. |
| 26 | [Ancient Civilization](https://steamcommunity.com/sharedfiles/filedetails/?id=3721996090) | Asghaard | Постройки древней подгорной цивилизации с собственной цепочкой производства. |
| 27 | [Emberlight](https://steamcommunity.com/sharedfiles/filedetails/?id=3741684658)<br><sub>KRINIK MODIFIED</sub> | Emberlight | Стойла и разведение животных, поля, пивоварение, святилища, таверны с артистами и купальни. |
| 28 | [Ironlight-Settlements](https://steamcommunity.com/sharedfiles/filedetails/?id=3741725671)<br><sub>KRINIK MODIFIED</sub> | Ca\$hfire | Поселение с распорядком дня рабов: сон, еда, работа, тренировки, торговля и патрули. |
| 29 | [Ironlight-Settlements-RPG](https://steamcommunity.com/sharedfiles/filedetails/?id=3780656133) | Ca\$hfire | Гигиена рабов и профессия артиста. |
| 30 | [Faster Elevator](https://steamcommunity.com/sharedfiles/filedetails/?id=3729885653) | Fritzli | Ускорены вертикальные и горизонтальные лифты. |
| 31 | [Highmane's Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3721926604) | Dracula | Более 2 000 предметов: сотни видов оружия с собственными связками ударов и более 500 украшений. |
| 32 | [Enhanced Armory and Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3718199031)<br><sub>KRINIK MODIFIED</sub> | Solvita | Более 700 видов оружия и более 350 видов брони, классы с собственным опытом, руны и система славы. |
| 33 | [Era of Trials](https://steamcommunity.com/sharedfiles/filedetails/?id=3744562094)<br><sub>KRINIK MODIFIED</sub> | Orero | Комплекты брони и оружие для каждой из семи религий, пять видов магического урона, волны верующих после убийства жреца. |
| 34 | [LegitReligious](https://steamcommunity.com/sharedfiles/filedetails/?id=3720748663)<br><sub>KRINIK MODIFIED</sub> | wyrm-x | Эпическая броня и оружие у религиозных алтарей. |
| 35 | [MSCasaDesFlores — Weapons & Armors](https://steamcommunity.com/sharedfiles/filedetails/?id=3734522624) | La Sombra MesSiinaa | Мечи, топоры, копья, кинжалы, луки, стрелы, щиты и броня для героев с 55 по 120 уровень. |
| 36 | [More Katanas](https://steamcommunity.com/sharedfiles/filedetails/?id=3741906845) | Hazelberry | Новые ступени катан, одноручные катаны и вакидзаси для левой руки. |
| 37 | [Immersive Warriors Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3742373178)<br><sub>KRINIK MODIFIED</sub> | BAMB | Атаки и комбинации ударов для катаны, меча, двуручного оружия и рукопашного боя; анимации усталости, еды и питья. |
| 38 | [TDI_LegendaryRepair](https://steamcommunity.com/sharedfiles/filedetails/?id=3723127994) | TiktaalikDreaming | Ремонтные наборы для легендарных и уникальных вещей. |
| 39 | [Arrow Quick Swap](https://steamcommunity.com/sharedfiles/filedetails/?id=3724971404)<br><sub>KRINIK MODIFIED</sub> | Grey Fox | Смена вида стрел в прицеле и переход на следующий вид, когда стрелы кончаются. |
| 40 | [Corpse Stripper](https://www.nexusmods.com/conanexilesenhanced/mods/14) | xtrekiller | С убитых неигровых персонажей и боссов выпадает всё надетое снаряжение. |
| 41 | [My Absolutely Unnecessary Thrall Army](https://www.nexusmods.com/conanexilesenhanced/mods/22) | xtrekiller | Отряд героя расширен до 100 спутников. |
| 42 | [Bosses My New Besties](https://www.nexusmods.com/conanexilesenhanced/mods/18) | xtrekiller | Боссов, минибоссов и уникальных неигровых персонажей можно оглушить и взять в рабы. |
| 43 | [EAA Lv50 Thralls](https://steamcommunity.com/sharedfiles/filedetails/?id=3725707777) | Solvita | Потолок уровня рабов поднят до 50. На 10, 15, 20, 35 и 50 уровнях раб получает черту. |
| 44 | [Extended Thrall Stats](https://steamcommunity.com/sharedfiles/filedetails/?id=3720737911) | Grandpa Who | Панель раба и питомца: множители урона, здоровье за очко живучести, настоящее имя. |
| 45 | [Thrall Inventory x2](https://steamcommunity.com/sharedfiles/filedetails/?id=3733163336) | Wyrd-Oh | Удвоен инвентарь рабов. |
| 46 | [Riding Thralls](https://steamcommunity.com/sharedfiles/filedetails/?id=3803149679) | Sunhildr | Рабы едут верхом рядом с героем. |
| 47 | [Rideable Pets](https://steamcommunity.com/sharedfiles/filedetails/?id=3817969576) | WickedVixen | Почти пятьдесят ездовых зверей. |
| 48 | [Player Ignores Follower Collision](https://steamcommunity.com/sharedfiles/filedetails/?id=3720753923)<br><sub>KRINIK MODIFIED</sub> | Deadlayn | Герой проходит сквозь своих спутников в дверях, на лестницах и в бою. |
| 49 | [Thrall_Peeper](https://steamcommunity.com/sharedfiles/filedetails/?id=3723820003) | Tater | Имя раба при наведении на него прицела. |
| 50 | [Diverse Barkeeps](https://steamcommunity.com/sharedfiles/filedetails/?id=3722887659) | DeviouSaint | В клетках тюремщика с равным шансом появляются трактирщики девяти народов. |
| 51 | [Better Tavern PATRONS](https://steamcommunity.com/sharedfiles/filedetails/?id=3729932396) | Wyrd-Oh | Посетителем таверны героя может стать почти любой раб игры. |
| 52 | [Exiles Fishing](https://steamcommunity.com/sharedfiles/filedetails/?id=3718368769)<br><sub>KRINIK MODIFIED</sub> | Jaar F Love | Рыбалка: заброс, слежение за рыбой и вываживание; 60 видов рыбы в четырёх биомах. |
| 53 | [Automatic Fish Trap](https://steamcommunity.com/sharedfiles/filedetails/?id=3720452046) | Fritzli | Ловушки для рыбы и моллюсков, в том числе глубоководная. |
| 54 | [Caverns of Set](https://steamcommunity.com/sharedfiles/filedetails/?id=3722525736)<br><sub>KRINIK MODIFIED</sub> | PNutt | Пещеры с поселением Akhlut Outpost между Логовом, Безымянным городом и Разбитыми источниками. В сундуках пещер лежит добыча высокого уровня. |
| 55 | [Shemite City State](https://steamcommunity.com/sharedfiles/filedetails/?id=3755371705) | PNutt | Город-государство за стенами на западе саванны: подземелье и свои неигровые персонажи. |
| 56 | [Ymir's Respite](https://steamcommunity.com/sharedfiles/filedetails/?id=3730427175) | PNutt | Пещерное подземелье с ареной босса на севере. |
| 57 | [Al-Merayah Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=3718036277)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Мод возвращает разрушаемую крепость, которую разработчик Funcom вырезал из игры. Крепость обороняют неигровые персонажи, и герой может её осадить. |
| 58 | [Waystones Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3813660690) | Red | Путевые камни: герой переносится от камня к камню по всей карте мира. |
| 59 | [Ragnar's New Factions](https://steamcommunity.com/sharedfiles/filedetails/?id=3717969878)<br><sub>KRINIK MODIFIED</sub> | Ragnar Random | Среди фракций самой игры по миру расселено более 700 новых неигровых персонажей. |
| 60 | [RNF NPC Distribution](https://steamcommunity.com/sharedfiles/filedetails/?id=3819183152) | Ragnar Random | Этот мод дополняет Ragnar's New Factions и вместе с ним расселяет новых персонажей по миру. |
| 61 | [Night Terrors](https://steamcommunity.com/sharedfiles/filedetails/?id=3723538551) | DeviouSaint | Ночные встречи с демонами и нежитью вне базы с 10 уровня. |
| 62 | [PvE Plus Ambush](https://steamcommunity.com/sharedfiles/filedetails/?id=3721274811) | Multigun | Засады на героя с 9 уровня. |
| 63 | [Severe Weather Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3721071602)<br><sub>KRINIK MODIFIED</sub> | drachenfeles | Температура по климату, своя погода и бури, тёмные подземелья. |
| 64 | [Resource Stimulus Package](https://www.nexusmods.com/conanexilesenhanced/mods/34) | xtrekiller | Железо, кристалл и сера добываются из камней, кристалл и лёд из железных жил; с трупов добычи больше. |
| 65 | [Reliable Meteor Showers](https://steamcommunity.com/sharedfiles/filedetails/?id=3723073788) | Xevyr | Досрочный метеоритный дождь, когда на карте остаётся пять узлов звёздного металла или меньше. |
| 66 | [Edit Appearance](https://steamcommunity.com/sharedfiles/filedetails/?id=3751947496) | IdeaPoet | Редактор внешности героя в самой игре. |
| 67 | [Heritage](https://steamcommunity.com/sharedfiles/filedetails/?id=3726392245) | Dread Swoop | Расы мира по описаниям народов в книгах Роберта Говарда; постоянные лица для 162 именных персонажей. |
| 68 | [Female New Faces](https://steamcommunity.com/sharedfiles/filedetails/?id=3753757942) | mr.weaz | Новые женские лица, глаза, брови и причёски в создании героя. |
| 69 | [Ostavar: Salon](https://steamcommunity.com/sharedfiles/filedetails/?id=3734199233) | Dani | Около 60 женских и 50 мужских причёсок, часть из них с физикой волос. |
| 70 | [Hair We Go](https://steamcommunity.com/sharedfiles/filedetails/?id=3731128190) | dame.en.noir | Набор причёсок. |
| 71 | [True (Hair) Colors](https://steamcommunity.com/sharedfiles/filedetails/?id=3731099424) | Dread Swoop | Насыщенная палитра цветов волос и бород. |
| 72 | [MSCasaDesFlores — Nails Station](https://steamcommunity.com/sharedfiles/filedetails/?id=3723318347) | La Sombra MesSiinaa | 58 вариантов ногтей на руках и ногах, раскраски и причёски. |
| 73 | [No-Intro-Splash](https://www.nexusmods.com/conanexilesenhanced/mods/1) | Gametism | Отключены вступительные ролики при запуске игры. |

## 3. Установка

Установить сборку можно двумя способами: лаунчером, который сам скачает архив сборки, или из архива, скачанного заранее.

### 3.1. Установка лаунчером

1. Убедитесь, что установлена игра Conan Exiles Enhanced 3.1.1 (билд CL-383549).
2. Скачайте со страницы выпуска сборки на GitHub файл `KrinikConanLauncher.exe` и запустите его из любой папки. Лаунчер сам найдёт игру на компьютере.
3. Нажмите «Установить сборку». Лаунчер скачает части архива сборки, проверит их и установит сборку.
4. Нажмите «Играть».

Если лаунчер не нашёл игру, нажмите «Указать папку игры» и выберите папку, где лежит `ConanSandbox.exe`. Если связь оборвётся, нажмите «Продолжить скачивание», и лаунчер докачает остальное. Части архива можно скачать и самому: положите их в ту же папку, где лежит лаунчер, и лаунчер установит сборку из них, ничего не скачивая.

### 3.2. Установка из архива

1. Убедитесь, что установлена игра Conan Exiles Enhanced 3.1.1 (билд CL-383549).
2. Скачайте в одну папку все части архива сборки со страницы выпуска сборки на GitHub: файлы с окончаниями `.zip.001`, `.zip.002` и следующие, всего 12,8 ГБ.
3. Откройте первую часть, файл с окончанием `.zip.001`, в 7-Zip или WinRAR и распакуйте сборку в папку игры, где лежит `ConanSandbox.exe`. Проводник Windows части такого архива не открывает. В папке игры появится папка сборки: её имя начинается с `Krinik_Mod_Pack_` и кончается номером версии.
4. Запустите `KrinikConanLauncher.exe` из папки сборки и нажмите «Установить сборку». Лаунчер находит игру по папке, в которой лежит сборка.
5. Нажмите «Играть».

Сборка переключает игру на русский язык.

Сборку можно установить и без лаунчера: запустите файл `install.cmd` в папке сборки.

В архиве сборки лежат обои для рабочего стола: V1, V2 «Тёплый», V2 «Реализм», V2 female beta «Реализм» и V2 female beta «Тёплый». Каждый вариант обоев есть в разрешениях 4K, 2K и 1080p.

## 4. Удаление

1. Закройте игру.
2. Запустите `KrinikConanLauncher.exe` и нажмите «Удалить сборку».
3. Подтвердите удаление в появившемся окне.

После удаления сборки игра вернётся в то состояние, в котором была до установки. Сборку можно удалить и без лаунчера: запустите файл `uninstall_krinik_build.cmd` в папке игры.

## 5. Отзывы и обратная связь

Отзыв, вопрос, сообщение о сбое или предложение, как улучшить сборку, присылайте её автору по электронной почте или сообщением в разделе Issues этого репозитория. Если игра вылетела, зависла или мод в ней работает неправильно, приложите к сообщению отчёт. Соберите и отправьте его так:

1. Нажмите кнопку «Отзыв» в главном меню игры или в меню Esc. Если игра закрыта, запустите `KrinikConanLauncher.exe`, нажмите «Отзыв», затем «Собрать отчёт».
2. Дождитесь, пока на рабочем столе появится файл `Conan-report-<дата>_<время>.zip`.
3. Отправьте файл автору сборки по электронной почте на адрес kotkrinik@yandex.ru или приложите его к сообщению в разделе [Issues](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/issues). Опишите, что происходило в игре перед сбоем и повторяется ли сбой.

Если игра упала, при следующем запуске лаунчер покажет окно «Отчёт о падении игры» и предложит собрать отчёт для автора сборки. Нажмите в этом окне «Да»: файл отчёта появится на рабочем столе, а в браузере откроется новое сообщение в разделе Issues. Приложите к сообщению файл отчёта и напишите, что происходило в игре перед падением.

В отчёт входят журналы игры, журнал Lua-модов и сведения о вылетах (без дампов памяти). Имя компьютера, путь к профилю, идентификаторы машины и аккаунта в отчёт не попадают. Если вы пишете с вопросом или предложением, отчёт не нужен.

## 6. Ссылки

- Почта: [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru)
- Страница сборки на Nexus Mods: [nexusmods.com/conanexilesenhanced/mods/65](https://www.nexusmods.com/conanexilesenhanced/mods/65)
- Публичный репозиторий сборки на GitHub: [github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack)

## 7. Правообладатели и отказ от ответственности

1. Моды других авторов принадлежат своим законным правообладателям — авторам модов в Мастерской Steam и на Nexus Mods. Авторы и страницы модов названы в таблице 1.
2. Мод с пометкой KRINIK MODIFIED остаётся собственностью автора мода. Доработки для сборки не передают автору сборки прав на мод.
3. Игра Conan Exiles и её версия Conan Exiles Enhanced принадлежат Funcom и законным правообладателям. Названия, товарные знаки и материалы игры принадлежат соответствующим владельцам.
4. Автор сборки, Николай Кривуша (Кот Криник), не претендует на материалы, права на которые ему не принадлежат. В сборке ему принадлежат подбор модов и порядок их загрузки, настройки, перевод, доработки модов с пометкой KRINIK MODIFIED, собственные моды Krinik и лаунчер.
5. Сборка предназначена для ознакомления и работает поверх установленной игры Conan Exiles Enhanced.
6. Сборка предоставляется «как есть» (as is), без каких-либо гарантий, явных или подразумеваемых. Автор сборки не несёт ответственности за любой ущерб, потерю сохранений или данных и иные последствия установки и использования сборки.

## 8. Лицензия

Лицензия [MIT](LICENSE). © 2026 **Mikalai Kryvusha** aka **KOT KRINIK** · Николай Кривуша aka Кот Криник.

Сборка выпущена под лицензией MIT и открыта для ознакомления всему человечеству. Лицензия MIT распространяется на работу автора сборки: моды Krinik, лаунчер, конфиги, скрипты и тексты этого репозитория. Файлы других правообладателей в репозитории остаются под своими лицензиями: у загрузчика UE4SS лицензия MIT © Narknon (`_unpacked/UE4SS/ue4ss/LICENSE`), у шрифтов лицензия SIL Open Font License (`_config/branding/fonts/`).

Спасибо и приятной игры!

---

<a id="english"></a>

# Krinik's Conan Exiles Enhanced ModPack

<h3 align="center"><em>Krinik Mod Pack 0.9.1-RC1 for Conan Exiles Enhanced 3.1.1</em></h3>

<p align="center">
  <a href="#russian"><img src="https://img.shields.io/badge/Русский-C0392B?style=for-the-badge" alt="Русский"></a>
  &nbsp;
  <a href="#english"><img src="https://img.shields.io/badge/English-2C7BE5?style=for-the-badge" alt="English"></a>
</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-FF1A8C.svg?style=flat-square)](LICENSE)
[![Pack version](https://img.shields.io/badge/Pack_version-0.9.1--RC1-FF1A8C.svg?style=flat-square)](#1-general)
[![Game](https://img.shields.io/badge/Conan_Exiles_Enhanced-3.1.1-brightgreen.svg?style=flat-square)](#3-installation)
[![Mods](https://img.shields.io/badge/Mods-9_+_63-8E44AD.svg?style=flat-square)](#2-contents-of-the-pack)

<p align="center">
  <a href="#1-general">General</a> · <a href="#2-contents-of-the-pack">Contents</a> · <a href="#3-installation">Installation</a> · <a href="#4-removal">Removal</a> · <a href="#5-feedback">Feedback</a> · <a href="#6-links">Links</a> · <a href="#7-rights-holders-and-disclaimer">Rights holders</a> · <a href="#8-license">License</a>
</p>

**Krinik Mod Pack is a mod pack for Conan Exiles Enhanced 3.1.1: 9 mods by the pack author, 63 mods by other authors from the Steam Workshop and Nexus Mods, the UE4SS loader and a launcher. Every mod of the pack is translated into Russian.**

From a single launcher window you can install, update and remove the pack and start the game with it. The launcher finds the game on your computer and can download the pack from GitHub. It tells you when a new version of the pack is out, and it updates itself separately from the pack. You can collect a report for the pack author right from the game menu.

## 1. General

### 1.1. About the pack

1. Pack version 0.9.1-RC1 is built for Conan Exiles Enhanced 3.1.1 (build CL-383549). A version number that ends in RC and a digit marks a test build: 0.9.1-RC1, for example, comes out before version 0.9.1 so that the author can test the whole installation path. Version 0.9.0, released on 2 November 2026, was the first release of the pack for Conan Exiles Enhanced 3.0.1 (build CL-379176); the pack then moved to game version 3.1.0 and, on 17 November 2026, to 3.1.1. Before that, the author built the pack for game versions 2.1.1 and 2.2.3. The number 1.0.0 appears twice in the pack's history: the early beta for game version 2.2.3 was released as 1.0.0, and the first full release of the pack will carry that number too. The user guide's chapter “Известные проблемы и планы на 1.0.0” (Known issues and plans for 1.0.0) lists what is not finished yet and what the author plans for that release.
2. The manifest `modpack.json` defines what the pack contains and the order in which the mods load. The [KUMM](https://github.com/MikalaiKryvusha/kumm) engine deploys the pack into the game folder.
3. Every mod in the pack is translated into Russian using the terminology of the game's Russian version.
4. The user guide, [docs/guide/Krinik-Conan-3.1.1-guide.pdf](docs/guide/Krinik-Conan-3.1.1-guide.pdf) (in Russian), covers the pack's features, keys, contents and version history.

### 1.2. Contents of the repository

| Path | Contents |
|---|---|
| `modpack.json` | the pack manifest: the mods in load order, their sources and versions |
| `_unpacked/` | the sources of the pack author's mods and the UE4SS loader |
| `_config/` | game configs, the launcher, the uninstaller, translation files, pack-building tools |
| `docs/guide/` | the user guide: the PDF and its HTML source |
| `docs/` | notes on the game, the mods and their compatibility |
| `art/` | the pack's logos, icons, screenshots and wallpapers, with the wallpaper sources |

Archives of other authors' mods are not stored in the repository: the pack author takes them from the Steam Workshop and Nexus Mods when making a release. Players get every mod ready-made in the pack archive and download nothing separately.

## 2. Contents of the pack

The pack holds 9 mods by its author, the UE4SS loader and 63 mods by other authors. The KrinikConanRussianTranslation mod translates the texts of the other authors' mods into Russian. **KRINIK MODIFIED** marks a mod by another author whose own files the pack author has changed: translated texts that the shared translation cannot reach, fixed its interface or fixed its bugs.

Table 1 — Mods of the pack

| No. | Mod | Author | What it does |
|---|---|---|---|
| 1 | [KrinikConanCamera](_unpacked/KrinikConanCamera) | KOT KRINIK | The third-person camera stands strictly behind the hero. With the numeric keypad the player changes the camera's distance, height, side offset and view pitch, saves the camera position, returns to it and resets the camera to its default position. |
| 2 | [KrinikConanArchery](_unpacked/KrinikConanArchery) | KOT KRINIK | The arrow flies in an arc to the aim point, and the draw strength sets its speed, as in The Elder Scrolls IV: Oblivion. In first-person view the bow is visible in the hero's hands. |
| 3 | [KrinikConanGameplay](_unpacked/KrinikConanGameplay) | KOT KRINIK | The hero can reach level 10,000, and attributes have no cap. |
| 4 | [KrinikConanLocomotion](_unpacked/KrinikConanLocomotion) | KOT KRINIK | The hero can shoot the bow and strike with a melee weapon mid-jump, and can sprint with a drawn bow. The hero pushes off a wall while climbing it and can shoot the bow in mid-air after that jump. Hanging on a wall slowly drains the hero's stamina. Every point of Agility makes the hero run faster and jump higher. |
| 5 | [KrinikConanUI](_unpacked/KrinikConanUI) | KOT KRINIK | The game pauses while the inventory or the hub is open. The Hosav HUD is reworked to be easier to read. A frame counter sits in the top right corner of the screen, and the main menu and the Esc menu have a “Отзыв” (Feedback) button. |
| 6 | [KrinikConanGraphics](_unpacked/KrinikConanGraphics) | KOT KRINIK | The sun and the shadows move smoothly, without jumps. The shadows of palm leaves and other foliage do not flicker: the mod fixes the game's own foliage material. The water reflects the far shore, the cliffs and the arches. Blood stains stay on the ground for up to five minutes and fade out smoothly. The mod also carries graphics settings tuned for the pack: draw distance, shadows, fog and DLSS. |
| 7 | [KrinikConanEngineTweaks](_unpacked/KrinikConanEngineTweaks) | KOT KRINIK | Three engine fixes remove the causes of the brief freezes while traveling the world. The engine gathers the terrain data that NPCs use to find their path on background threads, prepares the shaders of Niagara visual effects in advance when it loads an effect, and rebuilds its collision search structure in parts over several frames after new areas stream in. In a flight over the world each fix cut the number of freezes longer than 50 ms: by 48, 31 and 28 percent. |
| 8 | [KrinikConanRussianTranslation](_config/localization) | KOT KRINIK | Russian translation of the texts of every mod in the pack. |
| 9 | [KrinikConanModPackManager](_unpacked/KrinikConanModPackManager) | KOT KRINIK | A splash screen for the whole game load and a pack status line in the main menu: how many mods of the pack the game has loaded. |
| 10 | [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) | Narknon, UE4SS-RE | Lua mod loader for Unreal Engine. The Lua mods of the pack run on it. |
| 11 | [Hosav's Custom UI](https://steamcommunity.com/sharedfiles/filedetails/?id=3748867573)<br><sub>KRINIK MODIFIED</sub> | Hosav | The game interface is replaced by a customizable HUD with more than 50 settings. |
| 12 | [Simple Minimap](https://steamcommunity.com/sharedfiles/filedetails/?id=3719513784)<br><sub>KRINIK MODIFIED</sub> | Xevyr | A minimap with place markers and five zoom steps. |
| 13 | [Simple Modlist](https://steamcommunity.com/sharedfiles/filedetails/?id=3719546290)<br><sub>KRINIK MODIFIED</sub> | Xevyr | The list of enabled mods with their versions in the Esc menu. |
| 14 | [The Damage Meter](https://steamcommunity.com/sharedfiles/filedetails/?id=3719585133)<br><sub>KRINIK MODIFIED</sub> | Xevyr | A real-time meter shows how much damage the hero, the followers and other players deal, in total and per second. |
| 15 | [Proximity Party](https://steamcommunity.com/sharedfiles/filedetails/?id=3718878457)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Health bars of nearby followers and clanmates, up to 15 at a time. |
| 16 | [Lore & Loot Highlight](https://steamcommunity.com/sharedfiles/filedetails/?id=3718655125)<br><sub>KRINIK MODIFIED</sub> | Xevyr | An outline on everything the hero can interact with, and a separate color for loot chests. |
| 17 | [Pickup+](https://steamcommunity.com/sharedfiles/filedetails/?id=864199675) | nO Pa!N | Any placed item can be picked back up into the inventory. |
| 18 | [PackRat Helper](https://steamcommunity.com/sharedfiles/filedetails/?id=2596031352) | thelich | Sorts the backpack into the chests and stations that already hold the same items. |
| 19 | [Inventory Compactor](https://steamcommunity.com/sharedfiles/filedetails/?id=3718614759) | Xevyr | An inventory compaction button: empty slots are removed, stacks are merged. |
| 20 | [Organizer Sorting Chest](https://steamcommunity.com/sharedfiles/filedetails/?id=3723101055) | Mikey | A sorting chest: loot put into it goes to the nearby chests that hold the same items. |
| 21 | [Chest Labels](https://steamcommunity.com/sharedfiles/filedetails/?id=3735258746) | Xevyr | The name of a chest or cabinet written on the furniture itself. |
| 22 | [Storage Reach Expanded](https://steamcommunity.com/sharedfiles/filedetails/?id=3733835102)<br><sub>KRINIK MODIFIED</sub> | Seriihn | Building and crafting from the chests of the whole base. |
| 23 | [Double Storage Space](https://steamcommunity.com/sharedfiles/filedetails/?id=3803465771) | Dog Patch 06 | Storage capacity is doubled. |
| 24 | [Less Building Placement Restrictions](https://steamcommunity.com/sharedfiles/filedetails/?id=3755091710)<br><sub>KRINIK MODIFIED</sub> | Multigun | The game no longer forbids placing buildings in open space. The mod's settings open from “Настройки модов” (Mod settings) → “Прочее” (Other). |
| 25 | [Beyond Decor: Rustic Edition](https://steamcommunity.com/sharedfiles/filedetails/?id=3729154757) | Cateyes | Over 3,000 rustic decor items: bedroom, kitchen and dining room, living room, garden, market and shops. |
| 26 | [Ancient Civilization](https://steamcommunity.com/sharedfiles/filedetails/?id=3721996090) | Asghaard | Buildings of an ancient under-mountain civilization with their own production chain. |
| 27 | [Emberlight](https://steamcommunity.com/sharedfiles/filedetails/?id=3741684658)<br><sub>KRINIK MODIFIED</sub> | Emberlight | Stables and animal breeding, fields, brewing, shrines, taverns with entertainers and bathhouses. |
| 28 | [Ironlight-Settlements](https://steamcommunity.com/sharedfiles/filedetails/?id=3741725671)<br><sub>KRINIK MODIFIED</sub> | Ca\$hfire | A settlement with a daily routine for thralls: sleep, meals, work, training, trade and patrols. |
| 29 | [Ironlight-Settlements-RPG](https://steamcommunity.com/sharedfiles/filedetails/?id=3780656133) | Ca\$hfire | Thrall hygiene and the entertainer profession. |
| 30 | [Faster Elevator](https://steamcommunity.com/sharedfiles/filedetails/?id=3729885653) | Fritzli | Vertical and horizontal lifts run faster. |
| 31 | [Highmane's Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3721926604) | Dracula | Over 2,000 items: hundreds of weapons with their own combos and over 500 accessories. |
| 32 | [Enhanced Armory and Arsenal](https://steamcommunity.com/sharedfiles/filedetails/?id=3718199031)<br><sub>KRINIK MODIFIED</sub> | Solvita | Over 700 weapons and over 350 armor pieces, classes with their own experience, runes and a renown system. |
| 33 | [Era of Trials](https://steamcommunity.com/sharedfiles/filedetails/?id=3744562094)<br><sub>KRINIK MODIFIED</sub> | Orero | Armor sets and weapons for each of the seven religions, five kinds of magic damage, waves of believers after a priest is killed. |
| 34 | [LegitReligious](https://steamcommunity.com/sharedfiles/filedetails/?id=3720748663)<br><sub>KRINIK MODIFIED</sub> | wyrm-x | Epic armor and weapons at the religious altars. |
| 35 | [MSCasaDesFlores — Weapons & Armors](https://steamcommunity.com/sharedfiles/filedetails/?id=3734522624) | La Sombra MesSiinaa | Swords, axes, spears, daggers, bows, arrows, shields and armor for heroes of levels 55 to 120. |
| 36 | [More Katanas](https://steamcommunity.com/sharedfiles/filedetails/?id=3741906845) | Hazelberry | New katana tiers, one-handed katanas and a wakizashi for the off hand. |
| 37 | [Immersive Warriors Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3742373178)<br><sub>KRINIK MODIFIED</sub> | BAMB | Attacks and combos for the katana, the sword, two-handed weapons and unarmed combat; animations of fatigue, eating and drinking. |
| 38 | [TDI_LegendaryRepair](https://steamcommunity.com/sharedfiles/filedetails/?id=3723127994) | TiktaalikDreaming | Repair kits for legendary and unique items. |
| 39 | [Arrow Quick Swap](https://steamcommunity.com/sharedfiles/filedetails/?id=3724971404)<br><sub>KRINIK MODIFIED</sub> | Grey Fox | Switching the arrow type while aiming, and moving on to the next type when the arrows run out. |
| 40 | [Corpse Stripper](https://www.nexusmods.com/conanexilesenhanced/mods/14) | xtrekiller | Killed NPCs and bosses drop all the gear they wear. |
| 41 | [My Absolutely Unnecessary Thrall Army](https://www.nexusmods.com/conanexilesenhanced/mods/22) | xtrekiller | The party of the hero grows to 100 followers. |
| 42 | [Bosses My New Besties](https://www.nexusmods.com/conanexilesenhanced/mods/18) | xtrekiller | Bosses, minibosses and unique NPCs can be knocked out and taken as thralls. |
| 43 | [EAA Lv50 Thralls](https://steamcommunity.com/sharedfiles/filedetails/?id=3725707777) | Solvita | Thralls level up to 50 and gain a perk at levels 10, 15, 20, 35 and 50. |
| 44 | [Extended Thrall Stats](https://steamcommunity.com/sharedfiles/filedetails/?id=3720737911) | Grandpa Who | A thrall and pet panel: damage multipliers, health per point of vitality, the true name. |
| 45 | [Thrall Inventory x2](https://steamcommunity.com/sharedfiles/filedetails/?id=3733163336) | Wyrd-Oh | Thrall inventory is doubled. |
| 46 | [Riding Thralls](https://steamcommunity.com/sharedfiles/filedetails/?id=3803149679) | Sunhildr | Thralls ride on horseback alongside the hero. |
| 47 | [Rideable Pets](https://steamcommunity.com/sharedfiles/filedetails/?id=3817969576) | WickedVixen | Almost fifty rideable animals. |
| 48 | [Player Ignores Follower Collision](https://steamcommunity.com/sharedfiles/filedetails/?id=3720753923)<br><sub>KRINIK MODIFIED</sub> | Deadlayn | The hero passes through followers in doorways, on stairs and in combat. |
| 49 | [Thrall_Peeper](https://steamcommunity.com/sharedfiles/filedetails/?id=3723820003) | Tater | The name of a thrall shown under the crosshair. |
| 50 | [Diverse Barkeeps](https://steamcommunity.com/sharedfiles/filedetails/?id=3722887659) | DeviouSaint | Barkeeps of nine peoples appear in the jailer cages, each with an equal chance. |
| 51 | [Better Tavern PATRONS](https://steamcommunity.com/sharedfiles/filedetails/?id=3729932396) | Wyrd-Oh | Almost any thrall of the game can become a patron of the hero's tavern. |
| 52 | [Exiles Fishing](https://steamcommunity.com/sharedfiles/filedetails/?id=3718368769)<br><sub>KRINIK MODIFIED</sub> | Jaar F Love | Fishing: casting, tracking the fish and reeling in; 60 kinds of fish in four biomes. |
| 53 | [Automatic Fish Trap](https://steamcommunity.com/sharedfiles/filedetails/?id=3720452046) | Fritzli | Traps for fish and shellfish, a deep-sea one among them. |
| 54 | [Caverns of Set](https://steamcommunity.com/sharedfiles/filedetails/?id=3722525736)<br><sub>KRINIK MODIFIED</sub> | PNutt | Caves with the Akhlut Outpost settlement between the Den, the Unnamed City and the Shattered Springs. The chests of the caves hold high-tier loot. |
| 55 | [Shemite City State](https://steamcommunity.com/sharedfiles/filedetails/?id=3755371705) | PNutt | A walled city state in the west of the savannah, with a dungeon and its own NPCs. |
| 56 | [Ymir's Respite](https://steamcommunity.com/sharedfiles/filedetails/?id=3730427175) | PNutt | A cave dungeon with a boss arena in the north. |
| 57 | [Al-Merayah Reborn](https://steamcommunity.com/sharedfiles/filedetails/?id=3718036277)<br><sub>KRINIK MODIFIED</sub> | Xevyr | Brings back the destructible fortress that Funcom cut from the game: NPCs defend it, and the hero can lay siege to it. |
| 58 | [Waystones Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3813660690) | Red | Waystones that carry the hero from stone to stone across the whole world map. |
| 59 | [Ragnar's New Factions](https://steamcommunity.com/sharedfiles/filedetails/?id=3717969878)<br><sub>KRINIK MODIFIED</sub> | Ragnar Random | Over 700 new NPCs settled across the world among the game's own factions. |
| 60 | [RNF NPC Distribution](https://steamcommunity.com/sharedfiles/filedetails/?id=3819183152) | Ragnar Random | This add-on to Ragnar's New Factions works with it to spread the new NPCs across the world. |
| 61 | [Night Terrors](https://steamcommunity.com/sharedfiles/filedetails/?id=3723538551) | DeviouSaint | Night encounters with demons and undead outside the base from level 10. |
| 62 | [PvE Plus Ambush](https://steamcommunity.com/sharedfiles/filedetails/?id=3721274811) | Multigun | Ambushes on the hero from level 9. |
| 63 | [Severe Weather Enhanced](https://steamcommunity.com/sharedfiles/filedetails/?id=3721071602)<br><sub>KRINIK MODIFIED</sub> | drachenfeles | Temperature by climate, its own weather and storms, dark dungeons. |
| 64 | [Resource Stimulus Package](https://www.nexusmods.com/conanexilesenhanced/mods/34) | xtrekiller | Iron, crystal and brimstone come out of stone, crystal and ice out of iron veins; corpses give more loot. |
| 65 | [Reliable Meteor Showers](https://steamcommunity.com/sharedfiles/filedetails/?id=3723073788) | Xevyr | An early meteor shower when five star metal nodes or fewer are left on the map. |
| 66 | [Edit Appearance](https://steamcommunity.com/sharedfiles/filedetails/?id=3751947496) | IdeaPoet | An in-game editor of the hero's appearance. |
| 67 | [Heritage](https://steamcommunity.com/sharedfiles/filedetails/?id=3726392245) | Dread Swoop | The races of the world after the peoples of Robert E. Howard's books; fixed faces for 162 named characters. |
| 68 | [Female New Faces](https://steamcommunity.com/sharedfiles/filedetails/?id=3753757942) | mr.weaz | New female faces, eyes, eyebrows and hairstyles in character creation. |
| 69 | [Ostavar: Salon](https://steamcommunity.com/sharedfiles/filedetails/?id=3734199233) | Dani | About 60 female and 50 male hairstyles, some with hair physics. |
| 70 | [Hair We Go](https://steamcommunity.com/sharedfiles/filedetails/?id=3731128190) | dame.en.noir | A set of hairstyles. |
| 71 | [True (Hair) Colors](https://steamcommunity.com/sharedfiles/filedetails/?id=3731099424) | Dread Swoop | A rich palette of hair and beard colors. |
| 72 | [MSCasaDesFlores — Nails Station](https://steamcommunity.com/sharedfiles/filedetails/?id=3723318347) | La Sombra MesSiinaa | 58 variants of fingernails and toenails, paints and hairstyles. |
| 73 | [No-Intro-Splash](https://www.nexusmods.com/conanexilesenhanced/mods/1) | Gametism | The intro videos at game start are switched off. |

## 3. Installation

There are two ways to install the pack: with the launcher, which downloads the pack archive for you, or from an archive you have downloaded yourself.

### 3.1. Installing with the launcher

1. Make sure Conan Exiles Enhanced 3.1.1 (build CL-383549) is installed.
2. Download `KrinikConanLauncher.exe` from the pack's release page on GitHub and run it from any folder. The launcher finds the game on your computer by itself.
3. Press “Install mod pack” (“Установить сборку” in the Russian window). The launcher downloads the pack archive parts, verifies them and installs the pack.
4. Press “Play”.

If the launcher cannot find the game, press “Choose game folder” and pick the folder that contains `ConanSandbox.exe`. If the connection drops, press “Resume download”, and the launcher downloads the rest. You can also download the archive parts yourself: put them in the same folder as the launcher, and the launcher installs the pack from them without downloading anything.

### 3.2. Installing from the archive

1. Make sure Conan Exiles Enhanced 3.1.1 (build CL-383549) is installed.
2. Download all parts of the pack archive from the pack's release page on GitHub into one folder: the files ending in `.zip.001`, `.zip.002` and so on, 12.8 GB in total.
3. Open the first part, the file ending in `.zip.001`, in 7-Zip or WinRAR and extract the pack into the game folder, the one that contains `ConanSandbox.exe`. Windows Explorer cannot open the parts of this archive. A pack folder appears in the game folder; its name starts with `Krinik_Mod_Pack_` and ends with the version number.
4. Run `KrinikConanLauncher.exe` from the pack folder and press “Install mod pack”. The launcher finds the game through the folder the pack was extracted into.
5. Press “Play”.

The pack switches the game to Russian.

You can also install the pack without the launcher: run `install.cmd` in the pack folder.

The pack archive also contains desktop wallpapers: V1, V2 “Тёплый” (Warm), V2 “Реализм” (Realism), V2 female beta “Реализм” (Realism) and V2 female beta “Тёплый” (Warm), each in 4K, 2K and 1080p.

## 4. Removal

1. Close the game.
2. Run `KrinikConanLauncher.exe` and press “Remove mod pack”.
3. Confirm the removal in the dialog that opens.

The game returns to the state it was in before the pack was installed. You can also remove the pack without the launcher: run `uninstall_krinik_build.cmd` in the game folder.

## 5. Feedback

Send feedback, questions, crash reports and suggestions to the pack author by email or as an issue in this repository. Attach a report to any message about a crash, a freeze or a mod that misbehaves.

1. Press the “Отзыв” (Feedback) button in the game's main menu or in the Esc menu. If the game is closed, run `KrinikConanLauncher.exe`, press “Feedback”, then “Collect report”.
2. Wait until `Conan-report-<date>_<time>.zip` appears on the desktop.
3. Send the file to the pack author by email to kotkrinik@yandex.ru or attach it to a message in the repository's [Issues](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack/issues) section. Describe what happened in the game before the crash and whether it happens again.

If the game crashes, the next time the launcher starts it shows the “Game crash report” window and offers to collect a report for the pack author. Press “Yes” in that window: the report file appears on the desktop, and the browser opens a new issue on GitHub. Attach the report file to it and describe what was happening in the game before the crash.

The report holds the game logs, crash records without memory dumps and the Lua mod log. Machine and account identifiers, the computer name and the profile path stay out of it. A question about the pack or an improvement request goes the same way and needs no report.

## 6. Links

- Email: [kotkrinik@yandex.ru](mailto:kotkrinik@yandex.ru)
- Pack page on Nexus Mods: [nexusmods.com/conanexilesenhanced/mods/65](https://www.nexusmods.com/conanexilesenhanced/mods/65)
- Public repository of the pack on GitHub: [github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack](https://github.com/MikalaiKryvusha/Kriniks_Conan_Exiles_Enhanced_ModPack)

## 7. Rights holders and disclaimer

1. Mods by other authors belong to their lawful rights holders, the mod authors on the Steam Workshop and Nexus Mods. Table 1 names the authors and the mod pages.
2. A mod marked KRINIK MODIFIED stays the property of its author. Changes made for the pack give the pack author no rights to the mod.
3. Conan Exiles and its Conan Exiles Enhanced edition belong to Funcom and to their lawful rights holders. The names, trademarks and materials of the game belong to their respective owners.
4. The pack author, Mikalai Kryvusha (KOT KRINIK), lays no claim to material he holds no rights to. His work in the pack is the choice of mods and their load order, the settings, the translation, the changes to the mods marked KRINIK MODIFIED, his own Krinik mods and the launcher.
5. The pack is intended for informational purposes and runs on top of an existing Conan Exiles Enhanced installation.
6. The pack is provided “as is”, without warranty of any kind, express or implied. The pack author is not liable for any damage, loss of saves or data, or other consequences of installing and using the pack.

## 8. License

License [MIT](LICENSE). © 2026 **Mikalai Kryvusha** aka **KOT KRINIK** · Николай Кривуша aka Кот Криник.

The pack is released under the MIT license and is open for anyone to study. The MIT license covers the work of the pack author: the Krinik mods, the launcher, the configs, the scripts and the texts of this repository. Files of other rights holders in the repository keep their own licenses: the UE4SS loader is MIT © Narknon (`_unpacked/UE4SS/ue4ss/LICENSE`), the fonts are under the SIL Open Font License (`_config/branding/fonts/`).

Thank you, and enjoy the game!
