# dw.spawn-ai — спавн NPC, территории, агрессия и оповещение

> **Создан:** 2026-09-08 · **Родитель:** docs/03-cvars-конана.md · **Статус:** черновик, ни одна строка не проверена в живой игре · **Вовне:** —

---

## Коротко: зачем сюда идти

Владелец просит «глубокую симуляцию мира, как на настоящих мультиплеерных серверах». В семье из
20 имён лежат **три разных рычага**, и они не равноценны:

1. **Сколько NPC вообще существует** — `dw.EnableAISpawning`, `dw.EnableInitialAISpawningPass`,
   территориальные спавнеры и пара `ManualSpawnersAiLodCheck`. Дорого по кадрам, но это и есть
   «плотность мира».
2. **Насколько NPC ведут себя как группа** — четыре `dw.MaxNPCsToNotify_*`. **Дёшево по кадрам,
   дорого по ощущению.** Разница между «лагерь дерётся как один организм» и «каждый бьётся сам за
   себя». Это первый кандидат к правке, и ему здесь отведён отдельный разбор.
3. **На кого NPC вообще смотрят** — `dw.NPCsTarget*`, слух, обход препятствий, сброс агро.

Плюс два имени, которые к игре владельца отношения не имеют вовсе
(`ExitWhenNPCTerritorySpawnerInitializationDone`, `TrackSelectedNPCRotations`) — это инструменты
разработчика, и честнее сказать это прямо, чем изобретать им пользу.

**Главная практическая находка раздела — не значение, а секция ini.** В трёх независимых
источниках `dw.*`-имена этой семьи пишутся не в `[SystemSettings]`, а в
**`[/Script/ConanSandbox.SystemSettings]`**. В `_config/Engine.ini` владельца такой секции сейчас
**нет вообще** (в файле только `[Core.System]` и `[SystemSettings]`). То есть любая строка `dw.*`,
положенная в `[SystemSettings]`, может просто не примениться, и это объяснит «ничего не изменилось»
раньше, чем любая гипотеза про значения. Подробности — в разделе «Как это устроено», п. 0.

---

## Как это устроено

### 0. Куда вообще пишутся `dw.*`

| источник | секция | что пишет |
|---|---|---|
| [Totchinuko, tips.md, рецепт «No NPC spawn on the map»](https://github.com/Totchinuko/apiconan.totchinuko.fr/blob/master/tips.md) | `[/Script/ConanSandbox.SystemSettings]` | `dw.EnableAISpawning=0`, `dw.EnableInitialAISpawningPass=0` |
| [Trebuchet, `YuuIniServerFiles.cs`, стр. 66–67](https://github.com/Totchinuko/Trebuchet/blob/master/TrebuchetLib/YuuIni/YuuIniServerFiles.cs) | `/Script/ConanSandbox.SystemSettings` | те же два имени, `NoAISpawn ? "0" : "1"` |
| [acelan, docker-conan-exiles-enhanced-server, `.env.example`, блок `-- AI / spawning --`](https://github.com/acelan/docker-conan-exiles-enhanced-server/blob/main/.env.example) | `/script/conansandbox.systemsettings` | `dw.EnableAISpawning`, `dw.EnableInitialAISpawningPass`, `dw.NPCsTargetBuildings`, `dw.AILOD1/2/3Distance`, `dw.SkeletalMeshTickRate`, `dw.nav.*`, `dw.EnableStaticRoamingPaths` |

Тот же файл acelan кладёт `dw.NetClientFloatsDuringNavWalking` в **обычную** `[SystemSettings]` —
значит обе секции в природе встречаются, и вопрос «какая работает для какого имени» открыт.
Дешёвая проверка: положить одно имя в новую секцию, зайти в мир, прочитать его консолью.

Из Trebuchet попутно вычитывается **направление шкалы**: `1` — спавн включён, `0` — выключен.
Это единственное значение во всей семье, которое мы знаем не по догадке.

### 1. Что такое NPC Territory Spawner и почему его инициализация — отдельная песня

В дампе SDK игры класс называется `ANPCTerritorySpawner_C`
([SDKHeaders, `…Systems.Spawning.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.Spawning.cs)).
Это **не точка спавна, а объём с процедурной начинкой**. Его поля читаются как список работ:

```
TerritorySpawnVolume, TerritorySpawnVolumeRadius, TerritoryHomeLocation, HomeLocation
TerritorySuperRegion, TerritorySubRegion              — где территория лежит в мире
NPCs, HumanNPCs, SpawnTotalCount, SpawnTries          — кого и сколько
RoamRadius, SpawnPointsPerNPCSlot, SpawnUnderneathRoof
RoamingPathsSampled, RoamingPathsTargetCount, RoamingPathsPerNPCSlot
StaticNavigationGenerator, StaticNavigationOverride, CachedStaticOverridePaths
HumanNPCVisuals, HumanTribeItemDataList, Hair/Head/Hands/Helmet/UpperBody/…
TerritoryInitialSpawn                                 — флаг «первый спавн сделан»
Camp
```

Ключ — компонент `StaticNavigationGenerator`. В
[`…Systems.AI.Navigation.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.Navigation.cs)
он объявлен как `UStaticNavigationGenerator_C` с параметрами:

```
JustGeneratedSpawnPoints
RoamingPathSegmentMinLength / MaxLength / MaxTurnAngle
RoamingPathMaxPointCount / MaxLength / MinRadius / MaxLoopCount
MaxFailCountperpoint
```

`MaxFailCount`, `MaxLoopCount`, `SpawnTries` — это подпись **итеративного подбора с отбраковкой**:
генератор кидает точки на навигационную сетку, проверяет их и повторяет, пока не наберёт норму или
не упрётся в лимит неудач. Такая работа делается **один раз на старте мира** и стоит дорого — и
именно поэтому у неё три собственных cvar-а:

- `dw.EnableNPCTerritorySpawnerInitialization` — делать ли эту работу вообще;
- `dw.MaxConcurrentNPCTerritorySpawnerInitializations` — **сколько спавнеров считается разом**, то
  есть предохранитель от «весь мир инициализируется в одном кадре и игра висит»;
- `dw.EnableStaticRoamingPaths` — считать маршруты патрулей заранее и класть в кэш
  (`CachedStaticOverridePaths`), либо искать путь каждый раз в рантайме.

Что маршруты действительно **предвычисляются, а потом проигрываются**, видно с другой стороны: у
задачи дерева поведения `UBTTask_Roaming_C`
([`…Systems.AI.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.cs))
есть поля `RoamingPathBBKey`, `CurrentPathPoints`, `CurrentPathPointIndex`, **`StaticNavStatus`**,
`FinalRoamPoint`, `Leashing`. NPC не «ищет, куда пойти» — он **идёт по заранее нарезанному
маршруту**. Выключение `dw.EnableStaticRoamingPaths` перекладывает эту работу на рантайм: старт
мира станет быстрее, а игра — дороже в каждом кадре. Для одиночной игры это почти наверняка
**плохой размен**.

Цепочка целиком, и она объясняет, почему тут столько выключателей:

```
ABP_MasterCampPlaceable_C (лагерь, поле AILOD)
   └── UBP_CampComponent_C
         ├── TerritorySpawners[]        ← массив территориальных спавнеров
         ├── CachedWaypoints, CachedSpawnPoints, IsSpawnPointAndWaypointCacheValid
         ├── LandClaimChecker, PlayerBuilt_Claim_Radius, DeactivatedLandClaimTimer
         ├── IsCampActive, ForceCampActive, PlayerPawnRegistry
         └── CampRespawnTime, CampRespawnExclusionRadius, RespawningActors
```
([`…Systems.Camps.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.Camps.cs))

Отсюда же становится понятен `dw.ExitWhenNPCTerritorySpawnerInitializationDone`: **выйти из
процесса, как только инициализация закончена**. Для игрока это бесполезно и опасно; это стенд
разработчика — прогнать мир, убедиться, что все территории раскладываются, и завершиться. В том же
дампе рядом лежит `ConanExilesGame.Game.Dev.SmokeTests.cs` и `AHeatmapGenerator_C` с полем
`SlackUser` — то есть у Funcom это часть автоматической приёмки билда. **Не трогать.**

### 2. Пара «ListenServers / DedicatedServers» — и почему она вообще есть

`dw.EnableManualSpawnersAiLodCheckOnListenServers` и `…OnDedicatedServers` — **это два разных
cvar-а для двух разных режимов запуска**, а не выключатель с уточнением. У владельца
`StartedListenServerSession=True` в `_config/Game.ini` — **одиночная игра Conan Exiles есть
listen-сервер внутри клиента**, значит действует **`…OnListenServers`**, а правка
`…OnDedicatedServers` не даст ничего вообще. Это та же развилка, что и в семье AI LOD, где рядом
живут `dw.NpcLOD0BehaviorTickRate` и `dw.NpcLOD0ListenServerBehaviorTickRate`.

**Почему Funcom вообще их развёл.** На выделенном сервере игроки раскиданы по карте и сервер обязан
держать мир вокруг каждого. На listen-сервере игрок один и он же клиент — мир можно смело сжать
вокруг него и сэкономить. То есть **listen-варианты по умолчанию, скорее всего, скупее**. Ровно
поэтому они и есть главный рычаг «сделать одиночную игру похожей на настоящий сервер»: их надо не
подкручивать, а **приводить к дедикейтным**.

**Что такое «manual spawner».** В том же навигационном заголовке лежит
`ABP_ManualSpawnPoint_C : AStaticSpawnPoint` с полями `WildlifeOptions`, `HumanOptions`,
`HasSpawned`, `AllowRespawn`, **`IsGuardSpot`**, **`EmoteState`**, `RespawnTimer`,
`WaitingForRespawn`. Это **поставленные руками дизайнера точки**: часовой на воротах, кузнец с
анимацией у наковальни — в противоположность территориальным спавнерам, которые раскладывают толпу
процедурно. Именно эти NPC создают лицо локации.

Значит `EnableManualSpawnersAiLodCheck…` спрашивает: **сверяться ли с уровнем AI LOD, прежде чем
спавнить/респавнить такую точку.** Проверка включена — часовой появится, только когда игрок близко;
выключена — он стоит на посту всегда. Для запроса «живой мир» это, вероятно, **самая содержательная
ручка всей семьи**, и одновременно самая дорогая: у владельца Ryzen 7 5700G, а на listen-сервере
клиент и сервер делят один игровой поток.

### 3. `dw.MaxNPCsToNotify_*` — социальный радиус, разбор

**Механизм подтверждён, а не выведен из имени.** В
[`…Systems.AI.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.cs)
есть класс:

```
UBP_CryForHelpMessage_C : UObject
    AttackTarget : ObjectProperty (AActor)   — по кому поднимают тревогу
    Context      : ByteProperty              — ЧТО именно произошло
```

Это **одно сообщение с полем-контекстом**, а не четыре разных механизма. Байт `Context` —
перечисление, и четыре суффикса cvar-ов (`CryForHelp`, `EngagingInFight`, `TargetSpotted`, `Lure`)
почти наверняка и есть его значения. То есть устройство такое:

> случилось событие → собрать соседних NPC → **отсечь список по `MaxNPCsToNotify_<контекст>`** →
> каждому разослать `CryForHelpMessage` с целью → каждый получатель переключает поведение.

Четыре числа — это **четыре разных потолка на одну и ту же рассылку**, по одному на повод. Смысл
разделения очевиден: «замечена цель» происходит постоянно и должно будить единицы, «меня бьют»
происходит редко и должно будить всех.

**Чем это отличается от `MaxAggroRange=9000`.** `MaxAggroRange` — это **дальность обнаружения**:
как далеко NPC сам видит цель. `MaxNPCsToNotify_*` — **ширина передачи по цепочке**: скольким
соседям передаётся уже сделанное открытие. Первое даёт «зоркость», второе — «сговорчивость». Для
ощущения живого лагеря второе важнее, и стоит оно несравнимо дешевле: 9000 юнитов (90 м) обнаружения
на каждого NPC — это работа восприятия каждый тик, а рассылка сообщения происходит по событию.

**Чем платим.** Не рассылкой — она копеечная. Платим **последствиями**: каждый оповещённый NPC
берёт цель, выходит из покоя, начинает искать путь и претендовать на место у цели. В дампе рядом
лежат `UBP_CharacterAttackPointAllocatorComponent_C`, `UBP_CharacterAttackPoint_C` (поле
`TacticalGroup`) и `UBP_AttackPointContestInterface_C` — то есть у цели **конечное число мест для
атаки, и за них идёт конкуренция**. Оповестить тридцать NPC об одной цели — значит запустить
тридцать поисков пути и тридцать претензий на десяток мест. Это упирается в игровой поток, а он в
UE5 плохо распараллеливается — тот же класс просадок, что уже наблюдался в соседней сборке Palworld.

**Предложения по значениям.** Оговорка обязательна и она не формальная: **умолчания неизвестны, и
пока они не прочитаны консолью, любые числа ниже — это направление, а не рецепт.** Возможно, там уже
стоит 8, и тогда «поставить 8» ничего не изменит; возможно, там 2. Поэтому порядок такой: сначала
прочитать все четыре, записать, и только потом двигать — **по одному имени за заход**.

| контекст | как часто срабатывает | куда двигать | ориентир |
|---|---|---|---|
| `CryForHelp` | редко (NPC ранен и зовёт) | **вверх сильнее всех** — ради него всё и затевается | 8–12 |
| `EngagingInFight` | редко (драка началась) | вверх | 6–10 |
| `TargetSpotted` | **часто** (цель просто замечена) | вверх осторожно — это самый горячий повод | 4–6 |
| `Lure` | по событию приманки | вверх скромно | 3–5 |

Логика ранжирования: `TargetSpotted` держим ниже остальных именно потому, что он самый частый —
если раздуть его, лагерь начнёт сбегаться на каждого пробегающего мимо, и это ударит и по кадрам, и
по игре (невозможно будет пройти мимо лагеря). А `CryForHelp` — самый редкий и самый «кинематогра-
фичный»: раненый зовёт, и сбегается весь лагерь. Ровно то, чего просит владелец.

**Если после подъёма стало плохо** — не откатывать всё, а опустить сначала `TargetSpotted`.

### 4. Слух, обход и сброс агро

- `dw.HearingUpdateInterval` + `dw.HearingUpdateIntervalOverrideEnabled` — **пара «значение +
  выключатель»**, и порядок в ней важен: пока `…OverrideEnabled` не поднят, само значение,
  вероятно, игнорируется. Правка одного интервала без флага — классический способ решить, что
  «cvar не работает». Что слух реален, а не выдуман по имени: у `AAI_Controller_NPC_C` есть
  компонент `AIPerception`
  ([`…Systems.AI.AI_Controllers.cs`](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.AI_Controllers.cs)),
  то есть игра использует штатную систему восприятия Unreal, где `AISense_Hearing` ловит события
  шума от `Report Noise Event`
  ([Epic, AI Perception](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine)).
- `dw.CustomAvoidanceConsiderationRadiusMultiplier` — слово **Custom** говорит, что у Funcom своя
  система обхода поверх движковой; рядом в конфигах видны `dw.nav.AvoidNonPawns` и
  `dw.nav.InterpolateAvoidanceResult`. Ближайший известный аналог — `collisionQueryRange` из
  Detour Crowd: «определяет, насколько близко должен быть объект столкновения, чтобы его учитывали
  в поведении рулевого управления»
  ([recastnavigation, `dtCrowdAgentParams`](https://recastnav.com/structdtCrowdAgentParams.html)).
  Множитель радиуса рассмотрения = скольких соседей каждый NPC учитывает, обходя их. Вверх — толпа
  красиво расступается и дорого считается; вниз — NPC ходят сквозь друг друга.
- `dw.CVarUseHasPartialPathToBuildGiveUpHate` — имя с приставкой `CVar` **внутри** имени: так
  обычно выглядит аварийный выключатель, добавленный к уже сделанной правке. Механизм за ним
  подтверждается: `UBP_TargetAttackStats_C` хранит `IsFailingToPath` и `PathingFailureStartTime`, а
  `UBTTask_CheckGiveUpAttackTarget_C` и `UBTTask_GiveUpCurrentTarget_C` на этом решают, бросить ли
  цель. Смысл: **если до цели строится только частичный путь — считать это провалом и сбрасывать
  ненависть.** Разбор имени неоднозначен: `HasPartialPath` → `BuildGiveUpHate` («использовать
  проверку частичного пути при построении решения») либо `HasPartialPathToBuild` → `GiveUpHate`
  («частичный путь **до постройки**») — вторая читается осмысленно рядом с `dw.NPCsTargetBuildings`.
  На практике обе ведут в один и тот же узел, и это тот случай, где догадка о грамматике не меняет
  вывода.

---

## Таблица

Пометки: **[ИСТОЧНИК]** — найдена документация/форум/конфиг, ссылка обязательна.
**[ПО ИМЕНИ]** — вывод из имени и устройства Unreal, это гипотеза.
**[АНАЛОГ]** — родственный механизм Unreal с известным поведением.

Составные пометки означают ровно то, что написано: например «[ИСТОЧНИК] класс, [ПО ИМЕНИ] cvar» —
подлежащий механизм подтверждён дампом, а привязка к этому имени cvar-а остаётся догадкой.

**Оговорка ко всей колонке «как проверить»:** консоль в Enhanced у владельца не открывается
(Insert / Tilde / F10). Пока это не починено — а первый подозреваемый
`dw.UseConsoleKeybindingsVersion` из семьи отладки, — ни одна строка ниже непроверяема. Это
блокирующая задача всего раздела. **Ввод имени БЕЗ значения печатает действующее значение** — это
единственное доказательство, что имя вообще существует.

| cvar | что делает | основание | чем платим | как проверить |
|---|---|---|---|---|
| `dw.EnableAISpawning` | Главный выключатель спавна NPC. `1` — спавн идёт, `0` — мир пустой | **[ИСТОЧНИК]** [tips.md](https://github.com/Totchinuko/apiconan.totchinuko.fr/blob/master/tips.md) (рецепт пустой карты) + [Trebuchet стр. 66](https://github.com/Totchinuko/Trebuchet/blob/master/TrebuchetLib/YuuIni/YuuIniServerFiles.cs): `NoAISpawn ? "0" : "1"` | Ничем — трогать не нужно. Выключение = мир без NPC | Ввести имя без значения. Ждём `1`. Если печатает `0` при живых NPC — имя понято неверно |
| `dw.EnableInitialAISpawningPass` | Первый проход спавна при старте мира: населить карту до прихода игрока | **[ИСТОЧНИК]** те же два: в рецепте пустой карты гасится **вместе** с `EnableAISpawning`, значит это отдельная фаза | Ничем при `1`. При `0` мир заселяется только по мере подхода игрока | Имя без значения → ждём `1`. Проверка смыслом: при `0` первый выход из пустыни должен быть заметно пустее |
| `dw.EnableStaticRoamingPaths` | Использовать заранее нарезанные маршруты патрулей вместо поиска пути в рантайме | **[ИСТОЧНИК]** [acelan .env.example](https://github.com/acelan/docker-conan-exiles-enhanced-server/blob/main/.env.example), блок «AI / spawning»: `dw.EnableStaticRoamingPaths=true`; поля `CachedStaticOverridePaths`, `StaticNavStatus` в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.Navigation.cs) | Оставить `true`: выключение ускоряет старт мира ценой поиска пути в каждом кадре. Для listen-сервера — плохой размен | Имя без значения → ждём `true`/`1`. Если `0` — вот и причина, что NPC ходят рвано |
| `dw.EnableNPCTerritorySpawnerInitialization` | Инициализировать ли территориальные спавнеры (объёмы, генерирующие лагеря и толпу) при старте | **[ИСТОЧНИК]** класс `ANPCTerritorySpawner_C` и его `StaticNavigationGenerator` в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.Spawning.cs); **[ПО ИМЕНИ]** привязка cvar-а | Ничем при `1`. При `0` территориальные лагеря, вероятно, не появятся вовсе | Имя без значения → ждём `1`. Дальше не трогать: это не ручка качества, а выключатель |
| `dw.MaxConcurrentNPCTerritorySpawnerInitializations` | Сколько территориальных спавнеров инициализируется одновременно — предохранитель от зависания на старте | **[ИСТОЧНИК]** итеративный подбор точек в `UStaticNavigationGenerator_C` (`MaxFailCountperpoint`, `RoamingPathMaxLoopCount`) объясняет, зачем нужен лимит; **[ПО ИМЕНИ]** сама шкала | Вверх — быстрее старт мира, но риск фризов на загрузке. «Concurrent» может значить не потоки ОС, а число задач в кадре — тогда подъём бьёт прямо по игровому потоку | Имя без значения → записать число. Поднять **вдвое**, замерить время от «Продолжить» до управления секундомером. Одно изменение за заход |
| `dw.ExitWhenNPCTerritorySpawnerInitializationDone` | Завершить процесс, как только инициализация закончена | **[ПО ИМЕНИ]**; косвенно **[ИСТОЧНИК]** — рядом в билде лежит `Game.Dev.SmokeTests.cs` и `AHeatmapGenerator_C` с полем `SlackUser`, то есть автоприёмка сборки у Funcom | **Не трогать.** Ожидаемое поведение при `1` — игра закроется при загрузке мира | Только прочитать значение и убедиться, что там `0`. Ставить `1` смысла нет ни при каком сценарии |
| `dw.EnableManualSpawnersAiLodCheckOnListenServers` | **Действует у владельца.** Сверять ли AI LOD, прежде чем спавнить точку, поставленную руками (часовой, NPC с эмоцией) | **[ИСТОЧНИК]** `ABP_ManualSpawnPoint_C : AStaticSpawnPoint` с `IsGuardSpot`, `EmoteState`, `AllowRespawn` в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.Navigation.cs); **[ПО ИМЕНИ]** смысл флага | Выключение проверки = ручные NPC живут независимо от близости игрока. Самый честный «живой мир» и самая дорогая правка семьи: игровой поток у 5700G один на клиент и сервер | Имя без значения → записать. Затем **инвертировать** и пройти знакомый маршрут мимо постов. Обязателен замер до/после прибором `_tools/perf-harness/`, медианы и перцентили |
| `dw.EnableManualSpawnersAiLodCheckOnDedicatedServers` | То же самое, но для выделенного сервера | **[ИСТОЧНИК]** та же пара имён в реестре cvar-ов + `StartedListenServerSession=True` в `_config/Game.ini` показывает, что у владельца режим listen | **У владельца не действует вовсе.** Плата — потраченный заход, если править по ошибке именно её | Проверить, что правка этого имени **не** меняет ничего — это заодно докажет, что режим действительно listen |
| `dw.NPCsTargetPlayers` | Берут ли NPC игрока в качестве цели | **[ПО ИМЕНИ]**; **[АНАЛОГ]** — фильтр `Detection by Affiliation` (Enemies / Neutrals / Friendlies) в [AI Perception Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine) | Ничем при `1`. При `0` мир становится декорацией. Это выключатель, а не регулятор | Имя без значения → ждём `1`. Не менять |
| `dw.NPCsTargetNPCs` | Дерутся ли NPC между собой (фракция на фракцию, хищник на травоядное) | **[ПО ИМЕНИ]**; **[АНАЛОГ]** тот же фильтр принадлежности AIPerception | Если тут `0` — это и есть причина «мир неживой»: без междоусобиц ничего не происходит без игрока. Включение = постоянная фоновая нагрузка на бои вне поля зрения | **Первым делом прочитать.** Если `0` — это находка уровня всего раздела. Проверка смыслом: сесть у водопоя и посмотреть, охотятся ли хищники сами |
| `dw.NPCsTargetBuildings` | Атакуют ли NPC постройки игрока | **[ИСТОЧНИК]** [acelan .env.example](https://github.com/acelan/docker-conan-exiles-enhanced-server/blob/main/.env.example): `dw.NPCsTargetBuildings=true` в блоке AI | Прямо связано с `CampsIgnoreLandclaim=True`: лагерь не гаснет от захвата земли **и** его обитатели ломают стены. Вместе — риск потерять базу без присмотра | Имя без значения → записать. Проверка: поставить дешёвую стену у лагеря, отойти на AI LOD и вернуться |
| `dw.MaxNPCsToNotify_CryForHelp` | Скольких соседей позовёт раненый NPC | **[ИСТОЧНИК]** `UBP_CryForHelpMessage_C` (`AttackTarget` + байт `Context`) в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.cs) — механизм рассылки подтверждён; **[ПО ИМЕНИ]** соответствие суффикса значению `Context` | Каждый оповещённый берёт цель, ищет путь и претендует на место у цели (`UBP_AttackPointContestInterface_C`). Тридцать оповещённых = тридцать поисков пути | Прочитать все четыре `MaxNPCsToNotify_*` и записать. Затем поднять **только это** до 8–12, ударить одинокого NPC в лагере и посчитать сбежавшихся |
| `dw.MaxNPCsToNotify_EngagingInFight` | Скольким сообщат, что драка началась | **[ИСТОЧНИК]** тот же `UBP_CryForHelpMessage_C`; **[ПО ИМЕНИ]** привязка суффикса | То же, что выше. Повод редкий — значит и цена редкая | Поднять до 6–10 **следующим отдельным заходом**. Наблюдение: подтягивается ли к драке второй эшелон лагеря |
| `dw.MaxNPCsToNotify_TargetSpotted` | Скольким сообщат о просто замеченной цели | **[ИСТОЧНИК]** тот же класс; **[ПО ИМЕНИ]** привязка суффикса | **Самый частый повод из четырёх.** Раздуть — лагерь будет сбегаться на каждого прохожего: и кадры, и играбельность. Держать ниже остальных трёх | Поднимать последним и скромно (4–6). Проверка: пройти мимо лагеря по краю — должна реагировать часть, а не все |
| `dw.MaxNPCsToNotify_Lure` | Скольких притянет приманка | **[ИСТОЧНИК]** тот же класс; **[ПО ИМЕНИ]** привязка суффикса **и** сам смысл «приманки» — что именно её ставит, из имени не следует | Механика редкая, цена низкая, выигрыш в ощущении тоже низкий. Правится последней | Прочитать. Менять только после того, как остальные три отработаны и результат понравился |
| `dw.HearingUpdateInterval` | Как часто обновляется слух NPC | **[АНАЛОГ]** `AISense_Hearing` из [AI Perception Unreal](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine) — шум порождается `Report Noise Event`; **[ИСТОЧНИК]** компонент `AIPerception` у `AAI_Controller_NPC_C` в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.AI_Controllers.cs) | Уменьшение интервала = NPC чаще слушают = дороже. Направление шкалы (секунды или тики) из имени не следует | **Сначала поднять `…OverrideEnabled`.** Затем имя без значения → записать, уменьшить вдвое, красться мимо лагеря и смотреть, стали ли замечать раньше |
| `dw.HearingUpdateIntervalOverrideEnabled` | Разрешает ли предыдущему имени вообще действовать | **[ПО ИМЕНИ]** — пара «значение + выключатель» встречается в `dw.*` не впервые (ср. `dw.UseThrallRelevantDistance` при `dw.ThrallMaxRelevantDistance`) | Ничем. Но без него правка интервала, вероятно, молча не работает — и это самый дешёвый способ ошибочно решить, что «cvar мёртв» | Прочитать. Если `0` — поднять в `1` **отдельным заходом**, ничего больше не меняя, и убедиться, что после этого интервал начал читаться изменённым |
| `dw.CustomAvoidanceConsiderationRadiusMultiplier` | Множитель радиуса, в котором NPC учитывает соседей при обходе | **[АНАЛОГ]** `collisionQueryRange` в [`dtCrowdAgentParams`](https://recastnav.com/structdtCrowdAgentParams.html): «насколько близко должен быть объект столкновения, чтобы его учитывали в рулевом управлении»; **[ИСТОЧНИК]** соседние `dw.nav.AvoidNonPawns`, `dw.nav.InterpolateAvoidanceResult` в [acelan .env.example](https://github.com/acelan/docker-conan-exiles-enhanced-server/blob/main/.env.example) | Вверх — толпа красиво расступается, но каждый NPC перебирает больше соседей: квадратичная по плотности цена. Вниз — NPC слипаются и ходят друг сквозь друга | Имя без значения → записать. Поднять в 1.5 раза, собрать толпу в узком проходе лагеря и смотреть на затор и на кадры одновременно |
| `dw.CVarUseHasPartialPathToBuildGiveUpHate` | Считать ли частичный путь до цели поводом сбросить ненависть | **[ИСТОЧНИК]** `UBP_TargetAttackStats_C` с `IsFailingToPath` и `PathingFailureStartTime` + задачи `UBTTask_CheckGiveUpAttackTarget_C` / `UBTTask_GiveUpCurrentTarget_C` в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.AI.cs) | Выключение = NPC не бросают цель, до которой не дойти: они будут вечно упираться в стену базы. Это не «глубже симуляция», а зависшие NPC и лишний поиск пути | Имя без значения → записать. **Не менять без нужды.** Симптом, ради которого стоило бы: NPC слишком быстро теряют интерес и уходят посреди боя |
| `dw.TrackSelectedNPCRotations` | Диагностика: следить за поворотами выбранного NPC | **[ПО ИМЕНИ]** — глагол `Track` + `Selected` выдаёт инструмент отладки, работающий по выделенному в дев-режиме объекту; косвенно подтверждается наличием `UBP_AIDebugLibrary_C` и `AFakePlayer_C` в билде | Ничем, если это вывод отладки. Но «Selected» подразумевает дев-выделение, которого у игрока нет — вероятно, просто не сработает | Прочитать значение. Включать только если понадобится ловить конкретный баг с разворотами NPC, и то после `dw.EnableDeveloperMode` |

*Строк: 20 — по числу имён в семье.*

---

## Что стоит попробовать владельцу (ранжированно)

**Нулевой шаг, без которого остальные бессмысленны: починить консоль.** Кандидат —
`dw.UseConsoleKeybindingsVersion` из семьи отладки. Пока имя нельзя ввести и прочитать, весь этот
файл — гипотезы.

1. **Прочитать, ничего не меняя.** Один заход, ноль риска, максимум пользы: ввести без значения все
   четыре `dw.MaxNPCsToNotify_*`, оба `NPCsTargetNPCs`/`NPCsTargetBuildings`,
   `EnableManualSpawnersAiLodCheckOnListenServers`, `HearingUpdateIntervalOverrideEnabled`,
   `MaxConcurrentNPCTerritorySpawnerInitializations` — и **записать результат в этот файл**. После
   этого раздел перестанет быть черновиком. Всё остальное ниже без этого шага — стрельба вслепую.
2. **Завести секцию `[/Script/ConanSandbox.SystemSettings]` в `Engine.ini`.** Сейчас её нет. Это
   объясняет провал правок `dw.*` раньше любых рассуждений о значениях. Проверяется одним именем:
   положить туда `dw.EnableStaticRoamingPaths` со значением, которое там **и так стоит**, — если
   игра не перезатрёт строку, секция рабочая.
3. **`dw.NPCsTargetNPCs`, если он окажется `0`.** Междоусобицы фракций и охота хищников — это и
   есть «мир живёт без игрока». Самая большая отдача на единицу правки во всей семье.
4. **`dw.MaxNPCsToNotify_CryForHelp` → 8–12.** Дёшево по кадрам, громко по ощущению: раненый зовёт —
   сбегается лагерь. Отдельный заход.
5. **`dw.MaxNPCsToNotify_EngagingInFight` → 6–10.** Следующий заход. Второй эшелон подтягивается к
   уже идущей драке.
6. **`dw.EnableManualSpawnersAiLodCheckOnListenServers` — инвертировать.** Самая содержательная и
   самая дорогая правка. Только с замером до/после на одном и том же маршруте.
7. **`dw.MaxNPCsToNotify_TargetSpotted` → 4–6.** Последним из четвёрки и осторожно: повод самый
   частый.
8. **`dw.MaxConcurrentNPCTerritorySpawnerInitializations` вдвое вверх.** Улучшает не игру, а время
   старта мира. Приятно, но на «живой мир» не влияет — отсюда и место в списке.
9. **`dw.HearingUpdateIntervalOverrideEnabled` → `1`, затем интервал вдвое вниз.** Строго в этом
   порядке и разными заходами.
10. **`dw.CustomAvoidanceConsiderationRadiusMultiplier` в 1.5 раза.** Косметика толпы. Трогать, когда
    всё остальное устоялось.

**Не трогать:** `dw.EnableAISpawning`, `dw.EnableInitialAISpawningPass` (выключатели, у нас в
рабочем положении), `dw.ExitWhenNPCTerritorySpawnerInitializationDone` (закроет игру),
`dw.EnableManualSpawnersAiLodCheckOnDedicatedServers` (не действует),
`dw.CVarUseHasPartialPathToBuildGiveUpHate` (выключение даёт зависших NPC у стен).

### Связь с уже стоящими настройками сервера

Значения — из ванильного слепка `_config/vanilla/ServerSettings.ini`, снятого 08.09.2026. У файла в
первой строке стоит `;METADATA=(Diff=true, UseCommands=true)` — то есть игра сама применяет эти
настройки **командами**, а команда из консоли перебивает `[SystemSettings]` (лестница приоритетов —
в `01-графика-и-DLSS.md`, раздел 5). Это ещё один довод в пользу секции
`[/Script/ConanSandbox.SystemSettings]` вместо обычной.

| настройка | у владельца | как связана с этой семьёй |
|---|---|---|
| `NPCMaxSpawnCapMultiplier` | `1` | **Множитель к полю `MaxCap`** записей спавна: в [SDK](https://github.com/Mango200/ConanExiles/blob/master/SDKHeaders/ConanExiles/ConanExilesGame.Game.Systems.Spawning.SpawnInputs.cs) у `FNPCSpawnEntry` и `FNPCHumanSpawnEntry` есть `MaxCap`, `CurrentCount`, `DayNightSpawning`, `SpawnTime`/`DespawnTime`. **[ИСТОЧНИК]** Это главный рычаг плотности, и он **не** cvar: `dw.*` решают, спавнить ли вообще, а это — сколько. Для «плотного мира» поднимать сюда, 1.5–2, а не в `dw.*`. Заодно виден `DayNightSpawning` — в игре есть дневной и ночной набор NPC |
| `MaxAggroRange` | `9000` | 90 метров **дальности обнаружения**. Не путать с `MaxNPCsToNotify_*` — это ширина рассылки. Зоркость уже щедрая; для «живого лагеря» дешевле поднять сговорчивость, чем зоркость. Рядом в SDK у `AAI_Controller_NPC_C` есть `IsLeashing`, а у `UBP_NPCBehaviorParameters_C` — `LeashRange` и `RoamRadius`: NPC ещё и привязан к дому, так что одна дальность агро картины не решает. **[ИСТОЧНИК]** класс, **[ПО ИМЕНИ]** связка |
| `AmbientLifeEnabled` | `True` | **Здесь исправление распространённой ошибки.** Официальная документация Enhanced называет её **«Living Settlements Enabled»**: «When enabled, Thralls will interact with each other and the world around them to fulfill basic needs», требует рестарта ([Inflexion, Server INI Settings](https://exiles-enhanced.inflexion.io/servers/settings/)). Это про **рабов в поселении**, а не про птичек: сторонний каталог [palisade](https://github.com/Shakes63/palisade/blob/main/apps/api/src/catalog/conan.catalog.ts) описывает её как «ambient wildlife» — и ошибается. Для запроса «живой мир» настройка уже в нужном положении. **[ИСТОЧНИК]** |
| `ThrallExclusionRadius` | `100` | Радиус вокруг раба, в котором что-то запрещено — вероятнее всего спавн NPC лагеря. В официальной документации имя присутствует, но **без описания и без умолчания** ([Inflexion](https://exiles-enhanced.inflexion.io/servers/settings/)). Если единицы — юниты Unreal, то 100 = **1 метр**, то есть механика фактически выключена. Флаг для проверки, а не вывод. **[ИСТОЧНИК]** факт наличия, **[ПО ИМЕНИ]** трактовка |
| `CampsIgnoreLandclaim` | `True` | В SDK у `UBP_CampComponent_C` есть `LandClaimChecker`, `PlayerBuilt_Claim_Radius`, `DeactivatedLandClaimTimer` — то есть лагерь **штатно гаснет**, когда рядом заявлена земля. `True` это отключает: **лагеря продолжают жить рядом с базой.** Прямо работает на «живой мир» и прямо конфликтует с покоем базы, особенно вместе с `dw.NPCsTargetBuildings`. Сторонний каталог [palisade](https://github.com/Shakes63/palisade/blob/main/apps/api/src/catalog/conan.catalog.ts) считает игровым умолчанием `false` — значит у владельца стоит **не** умолчание. **[ИСТОЧНИК]** |
| `NPCRespawnMultiplier` | `1` | Официально: «Multiplies the speed at which NPCs respawn in the world after dying», рестарт не нужен ([Inflexion](https://exiles-enhanced.inflexion.io/servers/settings/)). Бьёт в `CampRespawnTime` / `RespawnTimer` из SDK. Работает **в паре** с `dw.EnableManualSpawnersAiLodCheckOnListenServers`: если проверка LOD не даёт точке ожить, ускорение респавна ничего не даст. **[ИСТОЧНИК]** |
| `ElderThingSpawnRate` | `0.99999994` | Официальное умолчание — `1.f`, зависит от `StormEnabled` и `ElderThingsEnabled` ([Inflexion](https://exiles-enhanced.inflexion.io/servers/settings/)). `0.99999994` — это ближайшее число float32 **снизу** от 1.0, то есть след округления при записи файла, а не осознанная правка. **Фактически стоит умолчание.** Трогать незачем. **[ИСТОЧНИК]** |
| `DogsOfTheDesertSpawnWithDogs` | `False` | Лагерь фракции «Dogs of the Desert» спавнится **без** своих собак. Сторонний каталог [palisade](https://github.com/Shakes63/palisade/blob/main/apps/api/src/catalog/conan.catalog.ts) считает умолчанием `true`; в официальной документации Enhanced имени **нет вовсе**. Если каталог прав, у владельца выключен кусок населения. Дешёвый и заметный кандидат к включению ради «живого мира». **[ИСТОЧНИК]** сторонний, умолчание не подтверждено |

Ещё одна связка, которую видно только из SDK: у `AAI_Controller_NPC_C` есть поле
`PrevMindReadingMode`, а в `ServerSettings.ini` владельца стоит `NPCMindReadingMode=0`. Имя
настройки и поле контроллера совпадают — значит настройка меняет **режим осведомлённости NPC о
цели**, и она соседствует со слухом и восприятием из этой семьи. Что означают конкретные режимы —
неизвестно; это отдельная задача. **[ИСТОЧНИК]** совпадение имён, **[ПО ИМЕНИ]** трактовка.

---

## Чего мы не знаем

**Ни одного значения по умолчанию во всей семье.** Ни одного. Исключение — направление шкалы
`dw.EnableAISpawning` (`1` = включено) из кода Trebuchet. Все числа в разделе «что попробовать» —
это направления, а не рецепты: если там уже стоит нужное, правка ничего не изменит, и это тоже
результат.

**Существование имён не доказано.** Сканер читал строки бинарника, а не реестр консоли. Движок молча
глотает неизвестное имя: ни ошибки, ни эффекта, ни следа в логе. Единственное доказательство —
чтение значения в живой игре.

**Дамп SDK — от другого билда.** Все ссылки на классы (`ANPCTerritorySpawner_C`,
`UBP_CryForHelpMessage_C`, `ABP_ManualSpawnPoint_C`, `UBP_CampComponent_C`) взяты из
[Mango200/ConanExiles](https://github.com/Mango200/ConanExiles), а это дамп **эпохи UE4** (в репозитории
лежит `UE4SDKGenerator-master`). Владелец играет в Enhanced 2.1.1 на UE 5.6.1. Устройство систем
за такой переезд обычно сохраняется, но **имена полей могли поехать, а классы — быть переписаны**.
Считать это доказательством архитектуры можно; считать доказательством текущего билда — нельзя.

**Байт `Context` не расшифрован.** Что четыре суффикса `MaxNPCsToNotify_*` — это и есть значения
`UBP_CryForHelpMessage_C::Context`, выглядит убедительно, но в дампе самого перечисления нет. Могут
существовать контексты без своего cvar-а, и тогда картина шире, чем четыре ручки.

**Что такое `Lure`.** Приманка — чья? Ловушка игрока, еда для приручения, предмет-наживка? Из имени
не следует, в источниках нет. Не выдумываю.

**Единицы `dw.HearingUpdateInterval`** — секунды или тики, и направление «больше = чаще/реже».
Выясняется одним чтением.

**Смысл `MaxConcurrent…`** — потоки ОС или число задач на кадр. От ответа зависит, помогает подъём
или вредит на 8-ядерном 5700G, где игровой поток один на клиент и сервер.

**`dw.aba.*` рядом в реестре** — три имени, расшифровки аббревиатуры нет ни в одном источнике. Если
они относятся к поведению NPC, семья на самом деле шире 20 имён. **Не выдумываю.**

**Консоль не открывается.** Всё вышеперечисленное непроверяемо, пока это не решено. Это не оговорка
в конце файла, а первая задача раздела.

---

### Источники

- [Totchinuko, `tips.md` — рецепт «No NPC spawn on the map»](https://github.com/Totchinuko/apiconan.totchinuko.fr/blob/master/tips.md)
- [Totchinuko, Trebuchet — `TrebuchetLib/YuuIni/YuuIniServerFiles.cs`](https://github.com/Totchinuko/Trebuchet/blob/master/TrebuchetLib/YuuIni/YuuIniServerFiles.cs)
- [acelan, docker-conan-exiles-enhanced-server — `.env.example`](https://github.com/acelan/docker-conan-exiles-enhanced-server/blob/main/.env.example)
- [Mango200/ConanExiles — дамп SDK, `SDKHeaders/ConanExiles/`](https://github.com/Mango200/ConanExiles/tree/master/SDKHeaders/ConanExiles) (Spawning, Spawning.SpawnInputs, AI, AI.Navigation, AI.AIPerception, AI.AI_Controllers, Camps)
- [Inflexion — Conan Exiles Enhanced, Server INI Settings](https://exiles-enhanced.inflexion.io/servers/settings/)
- [Epic — AI Perception in Unreal Engine](https://dev.epicgames.com/documentation/en-us/unreal-engine/ai-perception-in-unreal-engine)
- [Epic — Environment Query System](https://dev.epicgames.com/documentation/en-us/unreal-engine/environment-query-system-in-unreal-engine)
- [recastnavigation — `dtCrowdAgentParams`](https://recastnav.com/structdtCrowdAgentParams.html)
- [Shakes63/palisade — `conan.catalog.ts`](https://github.com/Shakes63/palisade/blob/main/apps/api/src/catalog/conan.catalog.ts) (сторонний каталог, умолчания не авторитетны)
- [Acekorneya/POK_Conan_Enhanced_Docker_server — `server-settings-keys.txt`](https://github.com/Acekorneya/POK_Conan_Enhanced_Docker_server/blob/main/config/server-settings-keys.txt) (только список имён)
- Локально: `_config/vanilla/ServerSettings.ini`, `_config/Game.ini`, `_config/Engine.ini`, `_config/cvars-registered.txt`
