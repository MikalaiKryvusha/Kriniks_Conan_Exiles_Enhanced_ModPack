# Страница мода на Nexus — заготовка

> **Создан:** 2026-09-10 · **Родитель:** решение владельца выложить мод на Nexus ·
> **Статус:** 🟡 черновик, ждёт вычитки владельцем · **Вовне:** публикация — действие владельца
>
> ⚠️ **Публикует владелец, не агент.** Здесь только тексты и картинки. Ни одной строки отсюда
> никуда не отправлено.

**Куда:** Nexus Mods → Conan Exiles Enhanced (`nexusmods.com/conanexilesenhanced`).
**Почему не Мастерская Steam:** там нужен аккаунт, владеющий игрой, и формат `.pak`
из Dev Kit — а наш мод это Lua под UE4SS. Разбор в чате 10.09.

**Ниша пустая, проверено:** под Enhanced нет мода, ставящего камеру строго за спиной.
Ближайший `Clean Camera Movement` — под UE4, помечен несовместимым и снят с публикации;
`Greater Camera Distance Enhanced` умеет только отдаление.

---

## Название

**Camera Behind — Third Person Camera Control**

Запасные, если занято: `True Behind Camera`, `Centered Third Person Camera`.

---

## Картинки

| файл | куда |
|---|---|
| `nexus-camera-comparison.webp` | главная картинка страницы |
| `nexus-camera-comparison.svg` | исходник, если понадобится правка |
| логотип | заказывается по промпту ниже |

Скриншоты из игры владелец делает сам — они убедительнее любой схемы.

---

# ENGLISH

## Short description

Puts the third-person camera directly behind your character instead of over the shoulder, and gives
you full control of zoom. Everything is tuned live on the numpad and saved automatically.

## Description

Conan Exiles puts the camera over your shoulder. Your character stands beside your line of sight,
his back fills half the screen, and he hides whatever is on that side.

**This mod puts the camera straight behind him.** Character, camera and crosshair line up. You see
what you aim at.

### What it does

- **Camera directly behind** — no sideways offset. One key returns to it at any time.
- **Full control of the zoom range** — set how close and how far the wheel may go. Vanilla limits
  are replaced by yours.
- **Three-band wheel step** — fine steps close to the character, normal steps in the middle, coarse
  steps far away. Scrolling out from 30 to 1000 no longer takes forty clicks, and framing a
  close-up no longer overshoots.
- **Tune it live** — every value is adjusted in game, on the numpad, and saved by itself. No
  reloading, no editing files.
- **Save your setup** — one key records the whole seating (offset, distance, pivot), another
  restores it.
- **Survives death** — the camera comes back where you had it after respawn.

### Compatibility

- **Conan Exiles Enhanced** (UE 5.6). Not for the legacy UE4 version.
- **Requires [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)** — tested on 3.0.1 build 1127.
- Singleplayer. Not tested on servers.
- **Enhanced Armory and Arsenal:** that mod ships its own "Extended Camera Zoom" and takes the
  spring arm over, which breaks the zoom limit. This mod detects it and stops just its camera
  component — the rest of EAA keeps working. Turn it off with `mute_foreign_camera = false` if you
  prefer EAA's zoom.

### Installation

1. Install UE4SS into `ConanSandbox\Binaries\Win64`.
2. Drop the `ConanCameraControl` folder into `ConanSandbox\Binaries\Win64\ue4ss\Mods\`.
3. Add `ConanCameraControl : 1` to `ue4ss\Mods\mods.txt`, or make sure `enabled.txt` is present in
   the mod folder.
4. Start the game. **Do not use UE4SS hot reload (Ctrl+R) on this mod** — it stacks its timer loop
   instead of replacing it, and the game will crash after a while. Restart the game instead.

### Controls — numpad

```
7 8 9      8 / 2  — camera back / forward
4 5 6      4 / 6  — camera left / right
1 2 3      9 / 3  — camera up / down
           7 / 1  — pivot up / down
```

| key | action |
|---|---|
| **5** | centre it — zero the sideways offset |
| **0** | restore the saved setup |
| **/** | save the current setup |
| **+** / **−** | distance |
| **Ctrl + 8/2, 4/6, 9/3** | move the **pivot** instead of the camera |
| **Ctrl + 5** | reset the pivot |
| **Ctrl + 0** | re-acquire the camera component (emergency) |

NumLock must be on. `*` is left free — the game uses it for chat.

### Camera offset vs pivot

`SocketOffset` moves **the camera** and rides along when you turn — the character keeps its place
on screen. `TargetOffset` moves **the orbit centre** in world space — the character sits lower in
frame, which is how the classic Oblivion framing is built. Neither turns the camera: aim always
follows the mouse.

### Credits

Built by Krinik with Claude (Anthropic). Free to use and to learn from.

---

# РУССКИЙ

## Короткое описание

Ставит камеру от третьего лица строго за спину персонажа вместо вида из-за плеча и отдаёт вам
управление зумом. Всё настраивается прямо в игре, с цифрового блока, и сохраняется само.

## Описание

Conan Exiles держит камеру из-за плеча. Персонаж стоит сбоку от линии взгляда, его спина занимает
половину экрана, и он закрывает всё, что с этой стороны.

**Этот мод ставит камеру ровно за ним.** Персонаж, камера и перекрестье выстраиваются в одну
линию. Вы видите то, во что целитесь.

### Что делает

- **Камера строго за спиной** — никакого бокового смещения. Одна клавиша возвращает к нему в любой
  момент.
- **Полное управление пределами зума** — задайте, насколько близко и насколько далеко пускать
  колесо. Игровые пределы заменяются вашими.
- **Шаг колеса тремя полосами** — мелкий у персонажа, обычный в середине, крупный вдали. Отъехать
  с 30 до 1000 больше не сорок щелчков, а подвести камеру вплотную — не проскочить мимо.
- **Настройка живьём** — каждое значение крутится в игре, на цифровом блоке, и сохраняется само.
  Ни перезапусков, ни правки файлов.
- **Запись посадки** — одна клавиша запоминает всё разом (смещение, дистанцию, ось), другая
  возвращает.
- **Переживает смерть** — после возрождения камера возвращается туда, где была.

### Совместимость

- **Conan Exiles Enhanced** (UE 5.6). Для старой версии на UE4 не подходит.
- **Нужен [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS)** — проверено на 3.0.1 сборка 1127.
- Одиночная игра. На серверах не проверялся.
- **Enhanced Armory and Arsenal:** тот мод везёт свою функцию «Extended Camera Zoom» и забирает
  пружинную штангу себе, из-за чего предел отдаления перестаёт соблюдаться. Наш мод это замечает и
  останавливает только его камерный компонент — всё остальное в EAA работает. Выключается ключом
  `mute_foreign_camera = false`, если зум EAA вам нужнее.

### Установка

1. Поставьте UE4SS в `ConanSandbox\Binaries\Win64`.
2. Положите папку `ConanCameraControl` в `ConanSandbox\Binaries\Win64\ue4ss\Mods\`.
3. Допишите `ConanCameraControl : 1` в `ue4ss\Mods\mods.txt` — или убедитесь, что в папке мода
   лежит `enabled.txt`.
4. Запустите игру. **Горячая перезагрузка UE4SS (Ctrl+R) этому моду противопоказана** — она не
   заменяет его цикл таймеров, а добавляет ещё один, и через некоторое время игра оборвётся.
   Перезапускайте игру.

### Управление — цифровой блок

```
7 8 9      8 / 2  — камера назад / вперёд
4 5 6      4 / 6  — камера влево / вправо
1 2 3      9 / 3  — камера выше / ниже
           7 / 1  — ось выше / ниже
```

| клавиша | действие |
|---|---|
| **5** | строго за спиной — обнулить боковое смещение |
| **0** | применить записанную посадку |
| **/** | записать нынешнюю посадку |
| **+** / **−** | дистанция |
| **Ctrl + 8/2, 4/6, 9/3** | двигают **ось**, а не камеру |
| **Ctrl + 5** | обнулить ось |
| **Ctrl + 0** | пересобрать поиск камеры (аварийная) |

NumLock должен быть включён. `*` намеренно свободна — на ней чат игры.

### Смещение камеры и ось — в чём разница

`SocketOffset` двигает **камеру** и едет вместе с поворотом — персонаж остаётся на том же месте
экрана. `TargetOffset` двигает **центр орбиты** в мировых координатах — персонаж оказывается ниже
в кадре, и именно так собран классический обливионский вид. Направление взгляда не меняет ни то,
ни другое: прицел всегда идёт за мышью.

### Благодарности

Сделано Криником вместе с Claude (Anthropic). Пользуйтесь свободно.

---

# Промпт для логотипа — отдать в ChatGPT

> Design a mod logo icon for a Conan Exiles third-person camera mod called **"Camera Behind"**.
>
> **Concept:** a single silhouette of a muscular barbarian warrior seen strictly **from behind**,
> shoulders and back filling the lower half, viewed straight down the spine — the exact framing the
> mod gives you. Behind and above him, a **thin geometric camera frame** (four corner brackets, like
> a viewfinder) aligned perfectly with his centre line, plus a small crosshair directly above his
> head where the frame's centre falls. The alignment is the whole point: warrior, crosshair and
> frame centre share one vertical axis.
>
> **Style:** flat vector, bold clean shapes, minimal detail, no text. Heavy contrast, readable at
> 64×64 pixels. Weathered dark bronze and deep charcoal silhouette against a warm sand-and-ember
> background; a single hot amber accent on the crosshair. Slight rough, hand-carved edge quality —
> Hyborian, sun-bleached, not sci-fi and not glossy.
>
> **Composition:** square, centred, generous margins, subtle vignette. No lettering, no logos,
> no watermark, no photorealism, no face — he is seen from behind.
>
> **Output:** 1024×1024 PNG, transparent background if possible.

**Если ChatGPT попросит уточнить:** ключевое — вид СЗАДИ и вертикальное совпадение «воин —
перекрестье — центр рамки». Всё остальное можно двигать.
