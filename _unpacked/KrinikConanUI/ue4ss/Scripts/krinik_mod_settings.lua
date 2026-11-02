--[[
  KrinikConanUI:ModSettings — the «Моды Krinik'а» settings hub (KUMM plan 38; phase 0 skeleton 2026-10-31 19:37, phase 2 — the window by the APPROVED
  mockup 5: `[OWNER]` «макет одобрен» · 2026-10-31 19:09; operational plan KUMM plans/38_epic38_phase2_krinik_hub_window.md).

  The window W_KrinikModSettings and its module table DT_KrinikUIModule come from _config/devkit/kit-krinik-modsettings.py — the kit places the
  widgets only (head, the mod list, one page per mod with rows «label + i + hint + the game's control», the footer, the «i» plate). This section:
    1. merges our table into the game's DT_UIModuleTable ONCE, at the main menu's birth (ModController CDO MergeDataTables — phase 0, proven);
    2. when our module opens: writes every text from SETTINGS below (title, buttons, mod names, labels, «i», hints), sets the slider ranges and
       every control to the STORED value (krinik_settings — <game>\ConanSandbox\Saved\KrinikSettings.lua), selects the first live mod;
    3. routes a real left click (RegisterKeyBind — UserWidget mouse events never fire here, EXP-0399; the «ОТЗЫВ» plate's route) to the hovered
       element: a mod name → its page; «i» → the explanation plate; «Сбросить к исходным» → the page's controls to the defaults (not saved);
       «Сохранить» → the store written, the sections told (krinik_settings.on_change); «Сохранить и закрыть»; «Закрыть без сохранения» → closed,
       the store untouched (the next opening reads the store again, so an unsaved change is gone);
    4. while the window is open ONLY: a 50 ms chain for the «i» hover and the marquee of a mod name that does not fit (`[OWNER]` 19:02 «как в
       радио бекущей строкой влево вправо»). The chain stops when the window is closed — nothing runs in play (criterion 7, house rule 7).
  A mod enters the list only when its rows apply (LIVE); the others wait for their mod's reader (plan step 6).
  [TESTED: 2026-10-31 · live game, real mouse: fill, page, «i», reset, save, save-and-close, the LMB bind silent while closed · KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md]
  The fidelity pass (own slider / value / checkbox / flat buttons, 2026-11-01): [TESTED: 2026-11-01 · live game, real mouse: drag, check, save, reopen,
  reset, close, page, «i» click, four resolutions · KUMM testcases/reports/2026-11-01_conan-hub-mockup-fidelity.md]
]]

local settings = require("krinik_settings")

local MOD = "KrinikConanUI:ModSettings"
local MAIN_TABLE = "/Game/UI/Data/DataTables/DT_UIModuleTable.DT_UIModuleTable"
local OUR_TABLE = "/Game/Mods/KrinikConanUI/DT_KrinikUIModule.DT_KrinikUIModule"
local MOD_CONTROLLER_CDO = "/Script/DreamworldMods.Default__ModController"
local ROW = "KrinikModSettings"
local WINDOW_CLASS = "W_KrinikModSettings_C"
local MENU_CLASS = "/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu.W_MainMenu_MainMenu_C"
local MERGE_DELAY_MS = 500    -- the menu's birth frame; the mods' controllers merged long before (frame 211, recon §1)
local OPEN_DELAY_MS = 100     -- the window is created inside ActivateModule; its tree is built by then
local SELECT_DIRECT = 3       -- ESelectInfo::Direct: a combo box's selection set by code (it still fires the author's OnSelectionChanged)
local WATCH_MS = 50           -- the «i» hover and the marquee, only while the window is open
local MARQUEE_PX = 1.2        -- units per watch step (≈ 24 units a second)
local MARQUEE_HOLD = 20       -- watch steps the name rests at each end (1 s)
local NAME_BOX = 258          -- the kit's NAME_W (a stale 268 here stopped the marquee: «KrinikConanGraphic» stood cut, 2026-10-31 22:12)
-- The window is never shorter than mockup 5's: its panel is 448 of 540 css px (83 % of the screen), and the kit draws css px ×2 × 1240/1315 (the width
-- 660 → 1240). The height of the tallest page alone left the window at 58 % of the screen: `[OWNER]` «по высоте увеличить размер окна» · 2026-11-01 08:42.
-- At 845 the window stands between the inventory's tab row and its button bar.
-- [TESTED: 2026-11-01 · the log «window height 845 (the tallest live page 575, mockup 5 845)» and a 4K frame · KUMM testcases/reports/2026-11-01_conan-hub-height-info-dimming.md]
local MIN_HEIGHT = 448 * 2 * 1240 / 1315
-- The «i» plate stands at the mouse, as the game's own tooltips do: a hover or a click on an «i» means the cursor IS on that «i». UE4SS hands Lua an
-- empty FGeometry (all zeros, 2026-10-31 22:0x), so a widget's place cannot be read; the old fixed X covered the row's own label (seam S5).
local TIP_DX, TIP_DY = -14, 22  -- below and slightly left of the cursor, canvas units
local TIP_EDGE = 12             -- the plate keeps this far from the screen edge (Svarog UI_RULEBOOK В6)

-- Every text of the window and every row: ONE table (labels and «i» — KUMM researches/conan-mod-settings-hub/krinik-settings-inventory.md).
-- kind: check (value boolean) | slider (value number; min, max, step; scale — the factor the slider SHOWS, digits — fraction digits shown).
-- `[OWNER]` the form «Моды Krinik'а» · 2026-10-31 19:10; capitals as in mockup 5 (approved 19:09) — three parts since the fidelity pass of 2026-11-01:
-- «МОДЫ KRINIK'А» bold, a grey «·», «НАСТРОЙКИ» regular (mockup .title b / i)
local TITLE, TITLE_DOT, TITLE_SUB = "МОДЫ KRINIK'А", "·", "НАСТРОЙКИ"
-- the mockup's flat buttons (kit Brd_KrinikBtn_<key> + Txt_KrinikBtn_<key>; the game's B_Krinik* stay collapsed) — `[OWNER]` 19:06
local BUTTONS = { Close = "Закрыть без сохранения", Reset = "Сбросить к исходным", Save = "Сохранить", SaveClose = "Сохранить и закрыть",
                  PalCancel = "Отмена", PalOk = "Принять" }   -- the palette's two (`[OWNER]` 2026-11-02 07:22 «кнопка не Выбрать. а Принять»)
-- mockup 5 colours, sRGB → linear (the kit's constants): a mod name, the selected one; a button's brush under the cursor
local C_TOC = { R = 0.4704, G = 0.4479, B = 0.3998, A = 1.0 }        -- #b5b1a8
local C_TOC_ON = { R = 0.8879, G = 0.8550, B = 0.7835, A = 1.0 }     -- #f2eee5
local BTN_HOT = 1.6                                                  -- the flat button's brush ×1.6 under the cursor
local PAGES = {
    -- own: the camera keeps its values in its OWN config.lua (it also writes them from the numpad) — the window reads them from the camera's
    -- shared «KrinikCameraValues» and hands a save over as «KrinikCameraSet», never through the store (one place per fact)
    { key = "cam", name = "KrinikConanCamera", note = "камера", own = "KrinikCamera", rows = {
        -- Ranges and hints by the owner's rule (2026-11-01 14:08–14:20, plan 40.2 criterion 4a): a grey hint only where the «i» does not already say it
        -- (units and «больше — быстрее» stay); cam_zoom_min from 130 — below it the wheel cannot reach first person (game map: 30 fails, 130 works).
        { id = "cam_height", kind = "slider", default = 75, min = 0, max = 200, step = 5, hint = "в сантиметрах",
          label = "Высота камеры", info = "Насколько выше героя висит камера." },
        { id = "cam_side", kind = "slider", default = 0, min = -100, max = 100, step = 5,
          label = "Сдвиг камеры вбок", info = "При нуле камера стоит строго за спиной героя, сдвиг вправо или влево даёт вид из-за плеча." },
        { id = "cam_dist", kind = "slider", default = 315, min = 150, max = 800, step = 5, hint = "в сантиметрах",
          label = "Расстояние до героя", info = "Расстояние, которое ставят клавиши «+» и «−» цифрового блока; колесо мыши приближает и отдаляет камеру как обычно." },
        { id = "cam_pitch", kind = "slider", default = -2, min = -15, max = 15, step = 1, hint = "в градусах",
          label = "Наклон взгляда", info = "Наклоняет камеру вверх или вниз, не сдвигая её; ноль — как в игре без мода." },
        { id = "cam_zoom_min", kind = "slider", default = 130, min = 130, max = 400, step = 10,
          label = "Ближе всего к герою", info = "Самое близкое расстояние колеса мыши; ещё ближе камера переходит к виду от первого лица." },
        { id = "cam_zoom_max", kind = "slider", default = 2125, min = 500, max = 3000, step = 25,
          label = "Дальше всего от героя", info = "Самое дальнее расстояние, на которое колесо мыши отводит камеру." },
        { id = "cam_sharp", kind = "check", default = false,
          label = "Резкий зум", info = "Включено — колесо переставляет камеру сразу; выключено — камера доезжает плавно." },
        -- the number is TP_SpringArmInterpSpeed: bigger = the camera reaches the new distance sooner = a SHARPER zoom; «Плавность … больше — быстрее»
        -- read backwards (`[OWNER]` 2026-11-01 10:05 «плавность зума больше - быстрее. каким боком быстрее к плавности? может Больше - резче?»).
        -- The label became «Скорость», so the pair is «больше — быстрее»: `[OWNER]` 2026-11-01 14:30 «Раньше была Плавность. Плавность резче, а
        -- скорость - быстрее !!» — a label and its hint / «i» are ONE pair: change the noun → re-read the hint and the «i».
        { id = "cam_zoom_smooth", kind = "slider", default = 9, min = 1, max = 20, step = 1, hint = "больше — быстрее",
          label = "Скорость зума", info = "Как быстро камера доезжает до нового расстояния после щелчка колеса: чем больше число, тем быстрее." },
    } },
    { key = "ui", name = "KrinikConanUI", note = "интерфейс сборки", rows = {
        { id = "ui_fps", kind = "check", default = true,
          label = "Счётчик кадров в углу экрана", info = "Показывает в правом верхнем углу, сколько кадров в секунду рисует игра." },
        { id = "ui_blink_food", kind = "slider", default = 0.10, min = 0.05, max = 0.50, step = 0.05, scale = 100, unit = " %",
          label = "Мигание еды и воды", info = "Когда еды или воды остаётся меньше этой доли, значок начинает тускло мигать; к нулю мигание набирает полную яркость." },
        { id = "ui_blink_weight", kind = "slider", default = 0.90, min = 0.50, max = 0.95, step = 0.05, scale = 100, unit = " %",
          label = "Мигание веса", info = "Когда ноша доходит до этой доли предела, значок веса начинает мигать." },
        { id = "ui_menu_slow", kind = "slider", default = 1 / 0.03, min = 1, max = 50, step = 1, hint = "во сколько раз",
          label = "Мир замедляется в меню", info = "Пока открыты инвентарь, сундук или станция, мир идёт медленнее: голод, жажда и враги ждут героя. Шкала задаёт, во сколько раз медленнее; 1 — мир не замедляется." },
        { id = "ui_craft", kind = "check", default = true,
          label = "Крафт в меню без замедления", info = "Пока мир в меню почти стоит, вещи, которые изготавливает герой, готовятся за обычное время." },
        -- krinik_shout_fade reads it at every shout; 1 s ≈ the game's own (a line lives as long as its voice, 0.9–1.75 s). `[OWNER]` 2026-11-01 08:49
        -- «я бы в мод UI криника вынес настройку времени задержки отображения фраз на экране». [AI] the value is a MINIMUM: a longer voice keeps its line.
        { id = "ui_shout_hold", kind = "slider", default = 1.0, min = 1.0, max = 10.0, step = 0.5, hint = "в секундах",
          label = "Сколько держится фраза врага", info = "Крик врага остаётся на экране не меньше этого времени, даже когда голос уже стих; если голос звучит дольше, текст гаснет вместе с ним." },
        -- krinik_vignette: the strength (RenderOpacity) of the game's own screen-edge effects; 0 = off. Defaults — the build's shipment, `[OWNER]`
        -- 2026-11-01 13:20 «виньетки голота и жажды ВЫКЛ, виньетка нижкого здоровья тусклая, типа 10%»; labels — the 10-31 mockup rows (plan 39 D5)
        { id = "ui_vig_hunger", kind = "slider", off_at_zero = true, default = 0.0, min = 0.0, max = 1.0, step = 0.05, scale = 100, unit = " %",
          label = "Виньетка: голод", info = "Тёмная рамка по краям экрана, пока герой умирает от голода. Шкала задаёт её силу; в крайнем левом положении рамки нет совсем." },
        { id = "ui_vig_thirst", kind = "slider", off_at_zero = true, default = 0.0, min = 0.0, max = 1.0, step = 0.05, scale = 100, unit = " %",
          label = "Виньетка: жажда", info = "Тёмная рамка по краям экрана, пока герой умирает от жажды. Шкала задаёт её силу; в крайнем левом положении рамки нет совсем." },
        { id = "ui_vig_health", kind = "slider", off_at_zero = true, default = 0.25, min = 0.0, max = 1.0, step = 0.05, scale = 100, unit = " %",
          label = "Виньетка: мало здоровья", info = "Кровавые брызги по краям экрана: чем меньше у героя здоровья, тем они гуще. Шкала задаёт их силу; в крайнем левом положении брызг нет совсем." },
        -- the places of «E Взять» (krinik_pickup_prompt) and the corpse strip (krinik_ui_fixes): a shift in % of the screen (`[OWNER]` 2026-11-02 08:57 «По высоте
        -- и по горизонтали?»); «E Взять» stands by its RIGHT edge at the crosshair dot, on the dot's line — default just left of the dot (`[OWNER]` 14:22 «слишком
        -- далеко плашка от центра» · «поднять выше в одну линию с точной прицела, и правее»; was −14 / +6 from the plate's middle). [TESTED: 2026-11-02 · 4K frame N6 · KUMM testcases/reports/2026-11-02_conan-pickup-native-probe.md]
        { id = "ui_pickup_x", kind = "slider", default = -1, min = -45, max = 45, step = 1, unit = " %",
          label = "«E Взять»: по горизонтали", info = "Куда сдвинута подсказка «E Взять» от прицела: влево — меньше нуля, вправо — больше, в долях ширины экрана." },
        { id = "ui_pickup_y", kind = "slider", default = 0, min = -45, max = 45, step = 1, unit = " %",
          label = "«E Взять»: по высоте", info = "Куда сдвинута подсказка «E Взять» от прицела: вверх — меньше нуля, вниз — больше, в долях высоты экрана." },
        { id = "ui_strip_x", kind = "slider", default = -22, min = -40, max = 40, step = 1, unit = " %",
          label = "Плашка трупа: по горизонтали", info = "Куда сдвинута плашка над трупом или сундуком: влево — меньше нуля, вправо — больше. Пока открыто окно добычи, плашка стоит у левого края." },
        { id = "ui_strip_y", kind = "slider", default = 0, min = -40, max = 40, step = 1, unit = " %",
          label = "Плашка трупа: по высоте", info = "Куда сдвинута плашка над трупом или сундуком: вверх — меньше нуля, вниз — больше." },
        -- the strip's size and backing (krinik_ui_fixes): `[OWNER]` 2026-11-02 10:54 «фон 60, меньше на» · «30» · «даем это настройкой в моде UI криника». [NOT-TESTED]
        { id = "ui_strip_scale", kind = "slider", default = 0.70, min = 0.40, max = 1.20, step = 0.05, scale = 100, unit = " %",
          label = "Плашка трупа: размер", info = "Размер плашки над трупом или сундуком: 100 % — как в игре." },
        { id = "ui_strip_back", kind = "slider", off_at_zero = true, default = 0.60, min = 0.0, max = 1.0, step = 0.05, scale = 100, unit = " %",
          label = "Плашка трупа: фон", info = "Насколько плотен тёмный фон под плашкой: в крайнем левом положении фона нет, текст остаётся." },
    } },
    { key = "arc", name = "KrinikConanArchery", note = "лук и стрелы", rows = {
        { id = "arc_ballistics", kind = "check", default = true,
          label = "Полёт стрелы как в Oblivion", info = "Чем сильнее натянута тетива, тем быстрее летит стрела; поправку на дугу берёт на себя стрелок." },
        { id = "arc_nobreak", kind = "check", default = true,
          label = "Стрелы не ломаются", info = "Стрела не ломается при попадании и остаётся торчать в цели." },
        { id = "arc_fov", kind = "slider", default = 75, min = 40, max = 90, step = 1, hint = "в градусах",
          label = "Обзор при прицеливании", info = "Насколько приближается вид, когда герой целится из лука правой кнопкой мыши." },
        -- `[OWNER]` 2026-11-01 16:18 «срок жизни стрел везде, и в земле, и в трупах, и в стенах нужжжжжжжжжен 5 минут - с возможностью настроить в модах
        -- стрельбы из лука - в минутах, от 1, до 30» (KUMM bugs/73); the game's own life is 15 s (ProjectileDummyLifetime)
        { id = "arc_stuck_min", kind = "slider", default = 5, min = 1, max = 30, step = 1, hint = "в минутах",
          label = "Сколько стрела торчит в цели", info = "Сколько воткнутая стрела героя остаётся в земле, в стене или в противнике, прежде чем исчезнуть." },
        -- KrinikConanArchery CFG.ammo_list — the Arrow Quick Swap list on a draw: `[OWNER]` 2026-11-02 12:54–12:56 «выбор стрел при натяжении - хорошая фича» ·
        -- «если есть из чего выбирать - показывается, если не из чего выбирать - не показывается» · «включается или выключается целиком через настройки стрельбы
        -- мода Krinik Archery» · «если выключена - то он никогда не показывается, даже не мерцает ни чуть-чуть». Default on — `[AI]` («хорошая фича»).
        -- [TESTED: 2026-11-02 · L3, L4 · KUMM testcases/reports/2026-11-02_conan-arrow-choice-and-bow-stance.md]
        { id = "arc_ammo_list", kind = "check", default = true,
          label = "Выбор стрел при натяжении", info = "Когда у героя стрелы разных видов, при натяжении лука справа от прицела появляется их список, а колесо мыши меняет стрелу. Если вид один, списка нет." },
    } },
    { key = "mpm", name = "KrinikConanModPackManager", note = "сборка", rows = {
        { id = "mpm_hud_scale", kind = "slider", default = 1.25, min = 1.0, max = 1.5, step = 0.05, scale = 100, unit = " %",
          label = "Размер HUD вверху экрана", info = "Увеличивает блок здоровья, выносливости и запасов вверху экрана, не трогая остальной интерфейс." },
    } },
    { key = "gfx", name = "KrinikConanGraphics", note = "графика", rows = {
        { id = "gfx_blood", kind = "slider", default = 300, min = 10, max = 600, step = 10, hint = "в секундах",
          label = "Сколько лежит кровь на земле", info = "Сколько пятна крови после боя остаются на земле, прежде чем исчезнуть." },
    } },
    -- The Xevyr hub (plan 40.3 I6.1–I6.3): every value is the AUTHOR'S, read from and written to the mod itself (`author` = the adapter key below), never
    -- our store; rows, ranges and defaults — KUMM researches/conan-mod-settings-hub/xevyr-settings-recon.md §1–§5 (the mods' CDOs). Pages in the
    -- mockup's order (alphabetical) = the kit's PAGES order. Dropdown, colour and key rows come with the row kinds of I6.2 (the owner's popups of
    -- 2026-11-02 07:20–07:23). A page shows only when its adapter read the mod's values. [TESTED: 2026-11-02 · X1–X8 in the live game, real clicks, the mods read back · KUMM testcases/reports/2026-11-02_conan-hub-xevyr-four-pages.md]
    { key = "amr", hub = "xevyr", author = "amr", name = "Al-Merayah Reborn", note = "штурм Аль-Мерайи", rows = {
        { id = "amr_enabled", kind = "check", default = true, label = "Включено",
          info = "Переключает между крепостью Аль-Мерайя и старыми руинами." },
        { id = "amr_corpse", kind = "check", default = true, label = "Уборка трупов",
          info = "Быстро убирает трупы противников Аль-Мерайи, чтобы игра не начала тормозить." },
        { id = "amr_nofatality", kind = "check", default = true, label = "Без добиваний",
          info = "Отключает добивания противников Аль-Мерайи, чтобы бой с толпой шёл плавнее." },
        { id = "amr_katana", kind = "check", default = true, label = "Легендарная катана",
          info = "Размещает в крепости легендарный клинок Мусаси." },
        { id = "amr_explosives", kind = "check", default = true, label = "Взрывчатка",
          info = "Размещает в крепости взрывающиеся горшки, которые можно забрать." },
        { id = "amr_ram", kind = "check", default = true, label = "Таран",
          info = "Размещает в крепости тараны, которые можно обыскать." },
        { id = "amr_gold", kind = "slider", default = 3000, min = 10, max = 10000, step = 10, label = "Золота в куче, не больше",
          info = "Сколько золота самое большее можно получить из каждой кучи в зале босса." },
        { id = "amr_field", kind = "slider", default = 30, min = 5, max = 600, step = 0.5, hint = "в секундах", label = "Возрождение: поле боя",
          info = "Через сколько возрождаются противники за стенами крепости." },
        { id = "amr_archer", kind = "slider", default = 30, min = 5, max = 600, step = 0.5, hint = "в секундах", label = "Возрождение: лучники",
          info = "Через сколько возрождаются лучники на стенах." },
        { id = "amr_battlement", kind = "slider", default = 20, min = 5, max = 600, step = 0.5, hint = "в секундах", label = "Возрождение: стены",
          info = "Через сколько возрождаются противники внутри внешних стен." },
        { id = "amr_bailey", kind = "slider", default = 20, min = 5, max = 600, step = 0.5, hint = "в секундах", label = "Возрождение: двор цитадели",
          info = "Через сколько возрождаются противники во внутреннем дворе цитадели." },
        { id = "amr_counter_cd", kind = "slider", default = 25, min = 5, max = 600, step = 0.5, hint = "в секундах", label = "Перерыв между контратаками",
          info = "Сколько крепость ждёт между контратаками, когда игроки её повреждают." },
        { id = "amr_counter_size", kind = "slider", default = 3, min = 1, max = 10, step = 1, label = "Размер отряда контратаки",
          info = "Сколько противников приходит в отряде, который контратакует штурмующих." },
    } },
    { key = "llh", hub = "xevyr", author = "llh", name = "Lore & Loot Highlight", note = "подсветка знаний и добычи", rows = {
        { id = "llh_lore", kind = "check", default = true, label = "Подсветка знаний",
          info = "Источники знаний в мире подсвечиваются выбранным цветом." },
        { id = "llh_lore_color", kind = "color", default = { R = 1, G = 0, B = 0, A = 1 }, label = "Цвет подсветки знаний",
          info = "Каким цветом светятся источники знаний." },
        { id = "llh_loot", kind = "check", default = true, label = "Подсветка сундуков с добычей",
          info = "Сундуки с добычей подсвечиваются выбранным цветом." },
        { id = "llh_loot_color", kind = "color", default = { R = 0, G = 1, B = 0.933, A = 1 }, label = "Цвет подсветки сундуков",
          info = "Каким цветом светятся сундуки с добычей." },
        { id = "llh_intensity", kind = "slider", default = 1.0, min = 0.1, max = 1.0, step = 0.01, scale = 100, unit = " %", label = "Яркость подсветки",
          info = "Насколько ярко светятся знания и сундуки." },
    } },
    { key = "prp", hub = "xevyr", author = "prp", name = "Proximity Party", note = "группа поблизости", rows = {
        { id = "prp_enabled", kind = "check", default = true, label = "Включено",
          info = "Показывает на экране список спутников рядом с героем." },
        { id = "prp_scale", kind = "slider", default = 0.8, min = 0.5, max = 1.0, step = 0.05, scale = 100, unit = " %", label = "Масштаб",
          info = "Размер списка группы на экране." },
        { id = "prp_radius", kind = "slider", default = 4000, min = 500, max = 6000, step = 100, scale = 0.01, unit = " м", label = "Радиус отслеживания",
          info = "Как далеко от героя спутник ещё попадает в список." },
        { id = "prp_max", kind = "slider", default = 5, min = 1, max = 15, step = 1, label = "Отслеживать, не больше",
          info = "Сколько спутников список показывает самое большее." },
    } },
    { key = "sm", hub = "xevyr", author = "sm", name = "Simple Minimap", note = "миникарта", rows = {
        { id = "sm_color", kind = "color", default = { R = 0.223, G = 0, B = 0, A = 0.690 }, label = "Цвет миникарты",
          info = "Цвет оформления миникарты. Прозрачность остаётся прежней." },
        { id = "sm_rotate", kind = "check", default = false, label = "Вращать миникарту",
          info = "Миникарта поворачивается вслед за героем." },
        { id = "sm_coords", kind = "check", default = true, label = "Показывать координаты",
          info = "На миникарте видны координаты героя." },
        { id = "sm_scale", kind = "slider", default = 0.85, min = 0.5, max = 1.0, step = 0.05, scale = 100, unit = " %", label = "Масштаб",
          info = "Размер миникарты на экране." },
        { id = "sm_markers", kind = "slider", default = 250, min = 150, max = 550, step = 10, label = "Дальность видимости маркеров",
          info = "Как далеко от героя метки ещё видны на миникарте." },
        { id = "sm_time", kind = "drop", default = 0, options = { "Сервер", "Компьютер", "Игра" }, label = "Показ времени",
          info = "Какое время показывают часы под миникартой: сервера, компьютера или игровое." },
        { id = "sm_guild", kind = "check", default = true, label = "Показывать членов клана",
          info = "Соклановцы видны на миникарте." },
        { id = "sm_journey", kind = "check", default = true, label = "Сместить панель путешествия вниз",
          info = "Панель путешествия опускается ниже миникарты." },
        { id = "sm_key", kind = "key", default = "F1", label = "Клавиша вызова курсора",
          info = "Пока клавиша зажата, поверх игры виден курсор мыши: им можно щёлкать по миникарте. Клавишу, занятую игрой, выбрать нельзя." },
    } },
    { key = "dm", hub = "xevyr", author = "dm", name = "The Damage Meter", note = "счётчик урона", rows = {
        { id = "dm_scale", kind = "slider", default = 1.0, min = 0.5, max = 1.0, step = 0.05, scale = 100, unit = " %",
          label = "Масштаб", info = "Размер окна счётчика урона и журнала боя." },
        { id = "dm_theme", kind = "color", default = { R = 0.005, G = 0.012, B = 0.024, A = 0.40 },
          label = "Цвет темы", info = "Цвет фона окна счётчика урона и журнала боя." },
        { id = "dm_opacity", kind = "slider", default = 0.85, min = 0.30, max = 0.95, step = 0.05, scale = 100, unit = " %",
          label = "Непрозрачность", info = "Насколько плотен фон окна счётчика: слева мир просвечивает сквозь окно, справа почти нет." },
        { id = "dm_corner", kind = "drop", default = 0, options = { "Вверху слева", "Вверху справа", "Внизу слева", "Внизу справа" },
          label = "Сворачивать в угол", info = "В какой угол экрана уходит свёрнутый счётчик урона." },
        { id = "dm_reset_confirm", kind = "check", default = false,
          label = "Спрашивать о сбросе при входе", info = "При входе в мир счётчик спросит, обнулить ли урон прошлой игры." },
        { id = "dm_timestamp", kind = "check", default = false,
          label = "Время в журнале боя", info = "Перед каждой строкой журнала боя стоит время удара." },
        { id = "dm_float_player", kind = "check", default = true,
          label = "Цифры урона: игрок", info = "Над целью всплывают цифры урона, который нанёс герой." },
        { id = "dm_float_tracked", kind = "check", default = true,
          label = "Цифры урона: под слежкой", info = "Над целью всплывают цифры урона, который нанесли спутники под слежкой счётчика." },
        { id = "dm_player_color", kind = "color", default = { R = 0.522, G = 0.004, B = 0.0, A = 0.702 },
          label = "Цвет полосы игрока", info = "Цвет полосы урона героя в окне счётчика." },
        { id = "dm_followers", kind = "color9", default = "cdo",
          label = "Цвета полос отслеживаемых", info = "Цвета полос урона спутников под слежкой, по одному на каждого из девяти." },
        { id = "dm_refresh", kind = "slider", default = 0.2, min = 0.05, max = 1.0, step = 0.05, hint = "в секундах",
          label = "Частота обновления полос", info = "Как часто перерисовываются полосы урона в окне счётчика: меньше — живее, больше — спокойнее." },
        { id = "dm_segment", kind = "slider", default = 7, min = 5, max = 15, step = 1, hint = "в секундах",
          label = "Пауза до новой стычки", info = "Сколько секунд без ударов счётчик ждёт, прежде чем начать считать новую стычку отдельно." },
        { id = "dm_key", kind = "key", default = "F1", label = "Клавиша вызова курсора",
          info = "Пока клавиша зажата, поверх игры виден курсор мыши: им можно развернуть счётчик и подвинуть его окно. Клавишу, занятую игрой, выбрать нельзя." },
    } },
}
-- A mod's page is shown only when its values APPLY (plan step 6); the UI sections share this Lua state and read the store directly.
-- arc: KrinikConanArchery reads arc_* at load and on the shared version (per arrow, per aim); gfx: KrinikConanGraphics reads gfx_blood at load and
-- on the shared version (its main.lua); mpm: KrinikConanModPackManager reads mpm_hud_scale at load and on the shared version when a game window closes;
-- cam: set at every opening — live only while KrinikConanCamera has published its values
local LIVE = { ui = true, gfx = true, arc = true, mpm = true }
local KIND = {}   -- row id → its kind (the adapters convert the authors' values by it)
for _, p in ipairs(PAGES) do for _, r in ipairs(p.rows) do KIND[r.id] = r.kind end end

-- ONE window, several hubs (plan 40.3 I6.1; `[OWNER]` 13:40 «наши окна-хабы с настоящими строками» · 20:37 вариант А): the inventory list sets
-- `_G.__krinik_hub` («krinik» · «xevyr» · «other») right before ActivateModule(KrinikModSettings) — the list and this section share the Lua state. The window
-- shows only the pages of that hub (`hub` of a page, «krinik» when absent) and the hub's title. Xevyr's pages arrive with the kit (I6.1 kit part); until then
-- its list entry stays a sub-list of the mods' own windows. [NOT-TESTED]
local HUBS = {
    krinik = { "МОДЫ KRINIK'А", "НАСТРОЙКИ" },
    xevyr  = { "МОДЫ XEVYR'А", "НАСТРОЙКИ" },
    other  = { "ПРОЧИЕ МОДЫ", "НАСТРОЙКИ" },
}
local hub = "krinik"
-- not `shown`: that name is the slider-text table below (a function by it would be shadowed there — «attempt to call a table value»)
local function in_hub(p) return LIVE[p.key] and (p.hub or "krinik") == hub end

local function log(fmt, ...) print(("[%s] " .. fmt .. "\n"):format(MOD, ...)) end
local function valid(o) return o ~= nil and o:IsValid() end
local function str(n) return type(n) == "string" and n or (n and n.ToString and n:ToString()) or tostring(n) end

-- ---- 1. the module table merge (phase 0) ----------------------------------------------------------------------------------------------
local merged = false

local function count_rows(dt)
    local n, has = 0, false
    dt:ForEachRow(function(name, _)
        n = n + 1
        if str(name) == ROW then has = true end
    end)
    return n, has
end

local function merge(why)
    if merged then return end
    local t0 = os.clock()
    local main = StaticFindObject(MAIN_TABLE)
    if not valid(main) then log("merge (%s): %s not loaded yet", why, MAIN_TABLE); return end
    local ours = StaticFindObject(OUR_TABLE)
    if not valid(ours) then ours = LoadAsset(OUR_TABLE) end   -- the FULL object path «Pkg.Obj»: the package path alone returns nil (2026-10-31 19:30)
    if not valid(ours) then log("merge (%s): our table %s not found", why, OUR_TABLE); return end
    local mc = StaticFindObject(MOD_CONTROLLER_CDO)
    if not valid(mc) then log("merge (%s): %s not found", why, MOD_CONTROLLER_CDO); return end
    local n0, h0 = count_rows(main)
    local ok, err = pcall(function() mc:MergeDataTables(main, ours) end)
    local n1, h1 = count_rows(main)
    merged = h1
    log("merge (%s): call %s%s; rows %d -> %d; %s present %s -> %s; %.2f ms", why, ok and "ok" or "FAILED", ok and "" or (" " .. tostring(err)),
        n0, n1, ROW, tostring(h0), tostring(h1), (os.clock() - t0) * 1000)
end

NotifyOnNewObject(MENU_CLASS, function(m)
    if merged or m:GetFullName():find("Default__", 1, true) then return end
    ExecuteInGameThreadWithDelay(MERGE_DELAY_MS, function() merge("main menu") end)
end)

-- ---- 2. the open window ---------------------------------------------------------------------------------------------------------------
local win = nil          -- the live window while open; nil — the LMB bind returns at once
local page = nil         -- the selected page entry of PAGES
local tip_row = nil      -- the row whose «i» plate is shown
local tip_pinned = false -- shown by a click (stays) or by the hover (goes when the mouse leaves)
local marquee = {}       -- key → { box, overflow, offset, dir, hold }

local function child(name)
    local w = win:GetWidgetFromName(FName(name))
    return valid(w) and w or nil
end

local function set_text(name, s)
    local t = child(name)
    if t then t:SetText(FText(s)) end
    return t
end

-- The controls are the window's OWN since the fidelity pass of 2026-11-01 (mockup 5: a thin track with a small light thumb, the value as plain text, a
-- square checkbox): `Sld_Krinik_<id>` (a plain UMG Slider holding the SHOWN value) + `Txt_KrinikVal_<id>`; a checkbox is `Brd_KrinikChk_<id>` with its
-- inner square `Img_KrinikChkOn_<id>`, its state lives HERE (checks[id]). The game's rows (diamond thumb, edit box, yellow tick) stay collapsed in the kit.
local checks = {}        -- check row id → boolean
local shown = {}         -- slider row id → the value its text shows (the watch rewrites the text only on a change)

local function slider(row) return child("Sld_Krinik_" .. row.id) end

local function value_text(row, v)
    -- v is the SHOWN value (row.scale applied); whole steps print whole, others with a decimal comma («0,45»), the unit after it («10 %»)
    -- a row whose far-left position turns its effect off says so: «ВЫКЛ», not «0 %» (`[OWNER]` 2026-10-30 ≈08:25 «Крайнее левое положение ползунков - ВЫКЛ
    -- полный соответствующей виньетки» · 2026-11-02 11:22 «не 0%, а ВЫКЛ» · «уже же делали такое !!!» — the vignettes and the shock wave). [NOT-TESTED]
    if row.off_at_zero and math.abs(v) < 1e-6 then return "ВЫКЛ" end
    local q = row.step * (row.scale or 1)
    local whole = math.abs(q - math.floor(q + 0.5)) < 1e-6
    local s = whole and string.format("%d", math.floor(v + 0.5)) or (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""):gsub("%.", ","))
    return s .. (row.unit or "")
end

local function show_value(row, v)
    if shown[row.id] ~= nil and math.abs(shown[row.id] - v) < 1e-4 then return end
    shown[row.id] = v
    set_text("Txt_KrinikVal_" .. row.id, value_text(row, v))
end

local function set_check(row, on)
    checks[row.id] = on and true or false
    local img = child("Img_KrinikChkOn_" .. row.id)
    if img then img:SetVisibility(on and 3 or 2) end    -- HitTestInvisible | Hidden (the box keeps its size)
end

-- ---- colour and key rows (plan 40.3 I6.2; mockups 8–9 and the owner's 2026-11-02 07:20–07:23 decisions: the palette and the busy-key refusal are
-- POPUPS over the window — no row moves; the palette's buttons «Отмена» · «Принять»; no caption under an accepted key). [TESTED: 2026-11-02 · C1–C9 in the live game, real clicks and keys, the mods read back (the busy plate's fade not measured) · KUMM testcases/reports/2026-11-02_conan-hub-colour-key-rows.md]
-- A colour value is a LINEAR { R, G, B, A } (the authors store linear colours); «color9» — a list of nine. A key value is its name («F1»).
-- The 16 palette colours are mockup 8's set (sRGB, approximate — the owner's eye decides), stored linear; a pick keeps the row's own alpha.
-- Names ONE short word each (≤ 10 letters, «фиолетовый» the longest): the swatch box holds about that — «тёмно-коричневый» was cut to «темно-коричне»
-- (the owner's frame 2026-11-02 08:42)
local PALETTE = {
    { "7a2a22", "бордовый" }, { "a8432f", "кирпичный" }, { "c9a54a", "золото" }, { "e0cf8f", "песочный" },
    { "4f7a3a", "зелёный" }, { "2f5a46", "хвойный" }, { "3a5f7a", "голубой" }, { "2b3d63", "синий" },
    { "5a3a7a", "фиолетовый" }, { "7a3a5f", "сливовый" }, { "7a5a3a", "коричневый" }, { "4a3a2a", "бурый" },
    { "d9d6cf", "пепельный" }, { "8e8a82", "серый" }, { "4a4845", "графит" }, { "18191a", "чёрный" },
}
for _, p in ipairs(PALETTE) do
    local function ch(i) return (tonumber(p[1]:sub(i, i + 1), 16) / 255) ^ 2.2 end
    p.c = { R = ch(1), G = ch(3), B = ch(5), A = 1.0 }
end
local PAL_DX, PAL_DY = 24, 14       -- the plate's right edge just right of the cursor, its top just under it (canvas units)
local PAL_GAP = 4                   -- a chooser's plate stands this far under (or over) its field
local BUSY_FADE, BUSY_HOLD = 4, 100 -- watch steps: 0.2 s in and out, 5 s held (`[OWNER]` 07:23 «на 5 секунд» · «фейдом открывается и фейдом скрывается»)
local colours, keys, drops = {}, {}, {}   -- row id → its value in the window (not saved until «Сохранить»); a drop value is the option's index from 0
local list = nil                    -- the open option list: { row }
local LIST_ROWS = 4                 -- the kit's option rows (the longest list — the Damage Meter's four corners)
local pal = nil                     -- the open palette: { row, n, old, new, pick }
local busy = nil                    -- the busy plate: { step }
local busy_keys = nil               -- key name → true: the keys the game binds (filled at the first need)

local function copy(c) return { R = c.R, G = c.G, B = c.B, A = c.A } end
-- a value detached from the window: a colour or a list of colours copied, anything else as it is
local function snapshot(v)
    if type(v) ~= "table" then return v end
    if v.R then return copy(v) end
    local t = {}
    for n, c in ipairs(v) do t[n] = copy(c) end
    return t
end
local function opaque(c) return { R = c.R, G = c.G, B = c.B, A = 1.0 } end
-- the nearest palette colour BY EYE: compared in sRGB, not in the linear values (linear distances named pure red «золото» and turquoise «светло-серый»,
-- frame C1 2026-11-02 08:12)
local function srgb(x) return math.max(0, x) ^ (1 / 2.2) end
local function nearest(c)
    local best, bd = 1, math.huge
    for i, p in ipairs(PALETTE) do
        local d = (srgb(p.c.R) - srgb(c.R)) ^ 2 + (srgb(p.c.G) - srgb(c.G)) ^ 2 + (srgb(p.c.B) - srgb(c.B)) ^ 2
        if d < bd then best, bd = i, d end
    end
    return best, bd
end
-- the field's caption: ONE word by the hue (the box holds ≈ 10 letters), greys by brightness. The rectangle gives ANY colour, and the sixteen muted
-- swatch names fitted almost none of them — a pure red read «свой цвет» (run R2 2026-11-02 10:17). Hue bounds in degrees, sRGB HSV. [NOT-TESTED]
local HUE_WORDS = { { 15, "красный" }, { 40, "оранжевый" }, { 65, "жёлтый" }, { 160, "зелёный" }, { 190, "бирюзовый" }, { 220, "голубой" },
    { 260, "синий" }, { 290, "фиолетовый" }, { 330, "пурпурный" }, { 345, "розовый" }, { 360, "красный" } }
local function colour_name(c)
    local r, g, b = srgb(c.R), srgb(c.G), srgb(c.B)
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if mx < 0.15 then return "чёрный" end
    local s = (mx - mn) / mx
    if s < 0.15 then return mx > 0.85 and "белый" or "серый" end
    local d, h = mx - mn, 0
    if mx == r then h = ((g - b) / d) % 6 elseif mx == g then h = (b - r) / d + 2 else h = (r - g) / d + 4 end
    h = h * 60
    if mx < 0.6 and h >= 10 and h < 50 then return "коричневый" end                       -- a dark orange / red-orange
    if (h < 15 or h >= 330) and s < 0.55 and mx > 0.75 then return "розовый" end           -- a pale red
    if h >= 190 and h < 220 and mx < 0.6 then return "синий" end                          -- «голубой» is a LIGHT blue (the DM theme navy)
    for _, w in ipairs(HUE_WORDS) do if h < w[1] then return w[2] end end
    return "красный"
end

local function show_colours(row)
    local v = colours[row.id]
    if not v then return end
    local list = row.kind == "color9" and v or { v }
    for n, c in ipairs(list) do
        local sw = child(("Brd_KrinikSwC_%s_%d"):format(row.id, n - 1))
        if sw then sw:SetBrushColor(opaque(c)) end
    end
    if row.kind == "color" then set_text("Txt_KrinikSwName_" .. row.id, colour_name(v)) end
end

local function key_name(chord)
    local ok, s = pcall(function() return chord.Key.KeyName:ToString() end)
    return ok and s or nil
end
local function chord(name) return { Key = { KeyName = FName(name) }, bShift = false, bCtrl = false, bAlt = false, bCmd = false } end

local function set_control(row, v)
    if row.kind == "check" then set_check(row, v); return end
    if row.kind == "color" or row.kind == "color9" then
        if row.kind == "color9" then
            local list = {}
            for n, c in ipairs(v or {}) do list[n] = copy(c) end
            colours[row.id] = list
        else
            colours[row.id] = v and copy(v) or nil
        end
        show_colours(row)
        return
    end
    if row.kind == "key" then
        keys[row.id] = v
        local ks = child("Ks_Krinik_" .. row.id)
        if ks and v then ks:SetSelectedKey(chord(v)) end
        return
    end
    if row.kind == "drop" then
        drops[row.id] = v
        set_text("Txt_KrinikDrop_" .. row.id, row.options[(v or 0) + 1] or "")
        -- the kit's «▾» is not in PT Serif (drawn as «?», frame D5 08:42): a «›», which the font has, turned to point down
        local arrow = set_text("Txt_KrinikDropArrow_" .. row.id, "›")
        if arrow then pcall(function() arrow:SetRenderTransformAngle(90) end) end
        return
    end
    local c = slider(row)
    if not c then log("row %s: slider not found", row.id); return end
    local s = row.scale or 1
    c:SetMinValue(row.min * s)
    c:SetMaxValue(row.max * s)
    c:SetStepSize(row.step * s)
    c:SetValue(v * s)
    shown[row.id] = nil
    show_value(row, c:GetValue())
end

local function read_control(row)
    if row.kind == "check" then return checks[row.id] end
    if row.kind == "color" or row.kind == "color9" then return colours[row.id] end
    if row.kind == "key" then return keys[row.id] end
    if row.kind == "drop" then return drops[row.id] end
    local c = slider(row)
    if not c then return nil end
    -- on the row's step: a slider hands back float noise (120 came as 120.00000762939 into the camera's config.lua, 2026-10-31 22:30)
    local s = row.scale or 1
    local q = row.step * s
    return math.floor(c:GetValue() / q + 0.5) * q / s
end

-- the switcher shows a page by its OWN widget, not by the position in PAGES: the kit appends a page it creates after the reused ones, and an index
-- would then show another mod's rows (the four Xevyr pages were added before «dm», 2026-11-02). [TESTED: 2026-11-02 · X1–X8 in the live game, real clicks, the mods read back · KUMM testcases/reports/2026-11-02_conan-hub-xevyr-four-pages.md]
local function show_page(sw, p, i)
    local w = child("VB_KrinikPage_" .. p.key)
    if w then sw:SetActiveWidget(w) else sw:SetActiveWidgetIndex(i - 1) end
end

local function select_page(p)
    page = p
    for i, q in ipairs(PAGES) do
        -- mockup .toc .on: the dark box, the light bar at the left, the brighter name (the kit draws the box #18191a; alpha 0 hides it)
        local item = child("Brd_KrinikMod_" .. q.key)
        if item then item:SetBrushColor({ R = 1.0, G = 1.0, B = 1.0, A = (q == p) and 1.0 or 0.0 }) end
        local bar = child("Img_KrinikModBar_" .. q.key)
        if bar then bar:SetVisibility((q == p) and 3 or 2) end
        local name = child("Txt_KrinikModName_" .. q.key)
        if name then name:SetColorAndOpacity({ SpecifiedColor = (q == p) and C_TOC_ON or C_TOC, ColorUseRule = 0 }) end
        if q == p then
            local sw = child("WS_KrinikPages")
            if sw then show_page(sw, q, i) end
        end
    end
    set_text("Txt_KrinikModTitle", p.name)
    set_text("Txt_KrinikModNote", p.note)
    log("page %s", p.key)
end

local function hide_tip()
    local tip = child("Brd_KrinikTip")
    if tip then tip:SetVisibility(1) end   -- Collapsed
    tip_row, tip_pinned = nil, false
end

local function show_tip(row, index)
    local tip = child("Brd_KrinikTip")
    if not tip then return end
    -- mockup .pop b: the title in capitals (Lua's upper() does not know Cyrillic — the engine's TextToUpper does)
    local title = row.label
    pcall(function() title = StaticFindObject("/Script/Engine.Default__KismetTextLibrary"):TextToUpper(FText(row.label)):ToString() end)
    set_text("Txt_KrinikTipTitle", title)
    set_text("Txt_KrinikTipBody", row.info)
    local slot = tip.Slot
    if valid(slot) then pcall(function()
        -- the cursor in canvas units (GetMousePositionOnViewport divides by the DPI scale); the plate's size after a prepass, kept on screen
        local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local m = wll:GetMousePositionOnViewport(win)
        local vp, sc = wll:GetViewportSize(win), wll:GetViewportScale(win)
        tip:ForceLayoutPrepass()
        local sz = tip:GetDesiredSize()
        local x = math.max(TIP_EDGE, math.min(m.X + TIP_DX, vp.X / sc - sz.X - TIP_EDGE))
        local y = m.Y + TIP_DY
        if y + sz.Y > vp.Y / sc - TIP_EDGE then y = m.Y - TIP_DY - sz.Y end   -- no room below: above the cursor
        slot:SetPosition({ X = x, Y = y })
    end) end
    tip:SetVisibility(3)   -- HitTestInvisible: the plate never takes the click meant for what is under it
    tip_row = row
end

-- ---- the palette plate and the busy-key plate: over the window at the cursor (UE4SS gives Lua no widget geometry — the «i» plate's way) -------
local function place_at_cursor(w)
    local slot = w.Slot
    if not valid(slot) then return end
    pcall(function()
        local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local m = wll:GetMousePositionOnViewport(win)
        local vp, sc = wll:GetViewportSize(win), wll:GetViewportScale(win)
        w:ForceLayoutPrepass()
        local sz = w:GetDesiredSize()
        local x = math.max(TIP_EDGE, math.min(m.X + PAL_DX - sz.X, vp.X / sc - sz.X - TIP_EDGE))
        local y = m.Y + PAL_DY
        if y + sz.Y > vp.Y / sc - TIP_EDGE then y = m.Y - PAL_DY - sz.Y end   -- no room below: above the cursor
        slot:SetPosition({ X = x, Y = y })
    end)
end

-- A chooser's plate opens AT ITS FIELD, always the same place: under the field, or over it when there is no room below (`[OWNER]` 2026-11-02 08:44
-- «дроп-даун меняет место выпада в зависимости от положения курсора - пхоло. Дроп-даун - такой элемент, который всегда вниз или вверх в одном месте
-- открывается от своего родителя»). UE4SS gives Lua no widget geometry, so the field's place is ADDED UP from the layout: the window is centred on the
-- canvas, and every box above the row (the head, the rules, the mod head, the rows before it) has a desired size and a slot padding. [NOT-TESTED]
local function pad(w)
    local ok, p = pcall(function() return w.Slot.Padding end)
    if ok and p then return p.Top or 0, p.Bottom or 0, p.Left or 0, p.Right or 0 end
    return 0, 0, 0, 0
end
local function stack_height_before(box, stop)   -- the heights of a vertical box's visible children before `stop`
    local y = 0
    for i = 0, box:GetChildrenCount() - 1 do
        local c = box:GetChildAt(i)
        if c:GetFullName() == stop:GetFullName() then break end
        if c:GetVisibility() ~= 1 then
            local t, b = pad(c)
            y = y + t + b + c:GetDesiredSize().Y
        end
    end
    return y
end
local function field_rect(row)   -- the row's control box in canvas units: left, top, right, bottom
    local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
    local vp, sc = wll:GetViewportSize(win), wll:GetViewportScale(win)
    local frame, content, right = child("SB_KrinikWindow"), child("VB_KrinikContent"), child("VB_KrinikRight")
    local body, rows, pg, line = child("HB_KrinikBody"), child("SC_KrinikRows"), child("VB_KrinikPage_" .. page.key), child("HB_KrinikRow_" .. row.id)
    frame:ForceLayoutPrepass()
    local ws = frame:GetDesiredSize()
    local left, top = (vp.X / sc - ws.X) / 2, (vp.Y / sc - ws.Y) / 2
    local ct, _, _, cr = pad(content)
    local bt, rtp = pad(body), pad(right)
    local y = top + ct + stack_height_before(content, body) + bt + rtp + stack_height_before(right, rows) + stack_height_before(pg, line)
    pcall(function() y = y - rows:GetScrollOffset() end)
    local rt = pad(line)
    local rh = line:GetDesiredSize().Y
    local box = child("SB_KrinikSwBox_" .. row.id) or child("SB_KrinikDrop_" .. row.id) or child("SB_KrinikKey_" .. row.id)
    local bs = box and box:GetDesiredSize() or { X = 0, Y = rh }
    local r = left + ws.X - cr
    local cy = y + rt + rh / 2
    return r - bs.X, cy - bs.Y / 2, r, cy + bs.Y / 2
end
local plate_pos = nil   -- where place_at_field put the last plate (canvas units) — the colour rectangle's click is measured from it
local function place_at_field(w, row)
    plate_pos = nil
    local ok = pcall(function()
        local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local vp, sc = wll:GetViewportSize(win), wll:GetViewportScale(win)
        local l, t, r, b = field_rect(row)
        w:ForceLayoutPrepass()
        local sz = w:GetDesiredSize()
        local x = math.max(TIP_EDGE, math.min(r - sz.X, vp.X / sc - sz.X - TIP_EDGE))   -- right edges in line with the field's
        local y = b + PAL_GAP
        if y + sz.Y > vp.Y / sc - TIP_EDGE then y = t - PAL_GAP - sz.Y end           -- no room below: over the field
        w.Slot:SetPosition({ X = x, Y = y })
        plate_pos = { X = x, Y = y }
    end)
    if not ok then place_at_cursor(w) end   -- the layout could not be read: at least near the click
end

-- the colour rectangle (`[OWNER]` 2026-11-02 08:45): the SAME mapping as _config/devkit/make-palette-texture.py `colour(x, y)` — change both together.
-- x across: the hue; down: white → the pure hue → black; the right GREY_FROM..1 — a grey column. Returns a LINEAR colour (the authors store linear). [NOT-TESTED]
local GREY_FROM = 0.92
local function hsv(h, s, v)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    local r, g, b
    if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
    return r, g, b
end
local function palette_colour(x, y)
    local r, g, b
    if x >= GREY_FROM then
        r = 1 - y; g, b = r, r
    elseif y <= 0.5 then
        r, g, b = hsv(x / GREY_FROM, 2 * y, 1)
    else
        r, g, b = hsv(x / GREY_FROM, 1, 2 - 2 * y)
    end
    return { R = r ^ 2.2, G = g ^ 2.2, B = b ^ 2.2, A = 1.0 }
end

local function close_palette()
    local p = child("Brd_KrinikPal")
    if p then p:SetVisibility(1) end      -- Collapsed
    pal = nil
end

local function mark_palette(i)
    -- the chosen cell's light rim: the cell brush is drawn (RoundedBox, 4) only on the chosen one — a transparent BrushColor did not hide the
    -- outline (all sixteen rimmed, frame C2 2026-11-02 08:13); the way the hub hides a border brush already (`DrawAs = 0`, KrinikConanUI notes)
    for k = 1, #PALETTE do
        local cell = child("Brd_KrinikPalC_" .. (k - 1))
        if cell then pcall(function()
            local br = cell.Background
            br.DrawAs = (k == i) and 4 or 0
            cell:SetBrush(br)
            cell:SetBrushColor({ R = 1, G = 1, B = 1, A = 1 })
        end) end
    end
end

local function pick_palette(i)
    pal.pick, pal.new = i, PALETTE[i].c
    mark_palette(i)
    local im = child("Img_KrinikPalNew")
    if im then im:SetColorAndOpacity(opaque(pal.new)) end
end

local function open_palette(row, n)
    hide_tip()
    local v = colours[row.id]
    if not v then return end
    local cur = row.kind == "color9" and v[n] or v
    if not cur then return end
    pal = { row = row, n = n, old = copy(cur), new = copy(cur), pick = nearest(cur) }
    set_text("Txt_KrinikPalTitle", row.kind == "color9" and ("%s · %d"):format(row.label, n) or row.label)
    for k, p in ipairs(PALETTE) do
        local im = child("Img_KrinikPalC_" .. (k - 1))
        if im then im:SetColorAndOpacity(p.c) end
    end
    for _, name in ipairs({ "Img_KrinikPalOld", "Img_KrinikPalNew" }) do
        local im = child(name)
        if im then im:SetColorAndOpacity(opaque(cur)) end
    end
    mark_palette(pal.pick)
    local mk = child("Brd_KrinikPalMark")
    if mk then mk:SetVisibility(2) end      -- Hidden until a point is clicked
    local p = child("Brd_KrinikPal")
    if p then p:SetVisibility(0); place_at_field(p, row) end    -- Visible: its swatches and buttons take the clicks; at its field (owner 08:44)
    log("palette: %s %d open (nearest %s)", row.id, n, PALETTE[pal.pick][2])
end

-- a click on the colour rectangle: the point from the plate's own place (ours) + its padding + the title + the rectangle's top padding; the mark moves there
local function pick_point()
    local ok, err = pcall(function()
        local wll = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary")
        local m = wll:GetMousePositionOnViewport(win)
        local plate, title, rect = child("Brd_KrinikPal"), child("Txt_KrinikPalTitle"), child("SB_KrinikPalRect")
        local pp = plate.Padding
        local x0 = plate_pos.X + pp.Left
        local y0 = plate_pos.Y + pp.Top + title:GetDesiredSize().Y + pad(rect)
        local rs = rect:GetDesiredSize()
        local fx = math.max(0, math.min(1, (m.X - x0) / rs.X))
        local fy = math.max(0, math.min(1, (m.Y - y0) / rs.Y))
        pal.new = palette_colour(fx, fy)
        pal.pick = nearest(pal.new)
        local im = child("Img_KrinikPalNew")
        if im then im:SetColorAndOpacity(opaque(pal.new)) end
        local mk = child("Brd_KrinikPalMark")
        if mk then
            local half = mk:GetDesiredSize().X / 2
            mk.Slot:SetPadding({ Left = fx * rs.X - half, Top = fy * rs.Y - half, Right = 0, Bottom = 0 })
            mk:SetVisibility(3)
        end
        log("palette: point %.2f, %.2f → %s", fx, fy, colour_name(pal.new))
    end)
    if not ok then log("palette: the point could not be read: %s", tostring(err)) end
end

local function accept_palette()
    local row, c = pal.row, copy(pal.new)
    local v = colours[row.id]
    if row.kind == "color9" then c.A = v[pal.n].A; v[pal.n] = c else c.A = v.A; colours[row.id] = c end   -- the row's own alpha kept
    show_colours(row)
    log("palette: %s %d → %s (not saved)", row.id, pal.n, colour_name(c))
    close_palette()
end

-- the option list of a «drop» row: one plate over the window at the cursor, by the owner's rule for every popup (07:20 «поп=апом поверх окна, не жвигая
-- другие пункты»); the chosen option keeps the light rim (the palette's way) [NOT-TESTED]
local function close_list()
    local p = child("Brd_KrinikList")
    if p then p:SetVisibility(1) end
    list = nil
end

local function open_list(row)
    hide_tip()
    list = { row = row }
    for i = 1, LIST_ROWS do
        local o, opt = child("Brd_KrinikListO_" .. (i - 1)), row.options[i]
        if o then
            o:SetVisibility(opt and 0 or 1)
            pcall(function()
                local br = o.Background
                br.DrawAs = ((i - 1) == drops[row.id]) and 4 or 0
                o:SetBrush(br)
            end)
        end
        if opt then set_text("Txt_KrinikListO_" .. (i - 1), opt) end
    end
    local p = child("Brd_KrinikList")
    if p then p:SetVisibility(0); place_at_field(p, row) end
    log("list: %s open", row.id)
end

local function game_keys()
    if busy_keys then return busy_keys end
    busy_keys = { Escape = true }
    pcall(function()
        local is = StaticFindObject("/Script/Engine.Default__InputSettings")
        for _, f in ipairs({ "ActionMappings", "AxisMappings" }) do
            is[f]:ForEach(function(_, m)
                local n = key_name(m:get())
                if n then busy_keys[n] = true end
            end)
        end
    end)
    local n = 0
    for _ in pairs(busy_keys) do n = n + 1 end
    log("keys the game binds: %d", n)
    return busy_keys
end

local function show_busy()
    local b = child("Brd_KrinikKeyBusy")
    if not b then return end
    set_text("Txt_KrinikKeyBusy", "Эта клавиша уже занята")
    b:SetRenderOpacity(0)
    b:SetVisibility(3)                     -- HitTestInvisible: it never takes a click
    place_at_cursor(b)
    busy = { step = 0 }
end

local function busy_step()
    if not busy then return end
    busy.step = busy.step + 1
    local s, b = busy.step, child("Brd_KrinikKeyBusy")
    local o
    if s <= BUSY_FADE then o = s / BUSY_FADE
    elseif s <= BUSY_FADE + BUSY_HOLD then o = 1
    else o = 1 - (s - BUSY_FADE - BUSY_HOLD) / BUSY_FADE end
    if not b then busy = nil; return end
    if o <= 0 then b:SetVisibility(1); busy = nil else b:SetRenderOpacity(o) end
end

local function watch_keys()
    for _, row in ipairs(page and page.rows or {}) do
        if row.kind == "key" then
            local ks = child("Ks_Krinik_" .. row.id)
            local n = ks and key_name(ks.SelectedKey)
            if n and n ~= "None" and n ~= keys[row.id] then
                if game_keys()[n] then
                    ks:SetSelectedKey(chord(keys[row.id] or row.default))
                    show_busy()
                    log("key %s: %s refused — the game binds it", row.id, n)
                else
                    keys[row.id] = n
                    log("key %s → %s (not saved)", row.id, n)
                end
            end
        end
    end
end

-- the camera's published values «cam_height=75.0;cam_side=0.0;…» → { cam_height = 75, … }; nil when the camera has published nothing
local function camera_values()
    local ok, s = pcall(function() return ModRef:GetSharedVariable("KrinikCameraValues") end)
    if not ok or type(s) ~= "string" or s == "" then return nil end
    local t = {}
    for id, v in s:gmatch("([%w_]+)=([^;]+)") do
        if v == "true" or v == "false" then t[id] = (v == "true") else t[id] = tonumber(v) end
    end
    return t
end

-- ---- the Xevyr adapters (plan 40.3 I6.3; recon xevyr-settings-recon.md §1–§5) — the authors' values, never our store ------------------------
-- Two ways, by what each mod offers (recon «Hard to bind» item 3):
--   window — read the mod's SaveGame slot (its CDO when the player never saved); write through the AUTHOR'S OWN window: open its module, set its
--            controls by the author's slider maths (and the window fields its save reads instead of a slider), call its save function(s), close
--            its module (it stayed open behind ours otherwise — frame 2026-11-02 00:25). The Damage Meter (D1, D2 seen), Proximity Party, Simple Minimap.
--   call   — the mod's own entry: Lore & Loot `LLH_AC_PlayerComp_C.UpdateSettings` + its slot «LLH_Settings» written here; Al-Merayah's server RPC
--            `AMR_AC_PlayerCont_C.ServerSaveSettings` (13 arguments), read from its controller actor.
-- A page is written only when a row differs from what was read at the opening — a save never opens an author's window for nothing; the author
-- windows of one save open one after another, never together. [TESTED: 2026-11-02 · X1–X8 in the live game, real clicks, the mods read back · KUMM testcases/reports/2026-11-02_conan-hub-xevyr-four-pages.md]
local function inst(class)   -- the live instance of a class: not its CDO, not a widget template in another widget's tree
    for _, x in ipairs(FindAllOf(class) or {}) do
        local n = x:GetFullName()
        if x:IsValid() and not n:find("Default__", 1, true) and not n:find(":WidgetTree.", 1, true) then return x end
    end
end
local function statics() return StaticFindObject("/Script/Engine.Default__GameplayStatics") end
-- an author's value as the window holds it: a colour → a plain { R, G, B, A }, an array of colours → a list, an input chord → its key's name
local function from_ue(kind, x)
    if x == nil then return nil end
    if kind == "color" then return { R = x.R, G = x.G, B = x.B, A = x.A } end
    if kind == "color9" then
        local t = {}
        x:ForEach(function(_, e)
            local c = e:get()
            t[#t + 1] = { R = c.R, G = c.G, B = c.B, A = c.A }
        end)
        return t
    end
    if kind == "key" then return key_name(x) end
    return x
end

local AUTHORS = {
    -- fields: row id → { the SaveGame field, the author's control, slider position from the value (none = a checkbox), the window field its save reads }
    dm = { slot = "DamageMeter", cdo = "/Game/Mods/DamageNumber/DN_SG_SaveSettings.Default__DN_SG_SaveSettings_C",
           module = "DN_UI_Settings", window = "DN_UI_SettingsWindow_C", save = { "SaveSettings" }, fields = {
        dm_scale         = { "UIScale",                 "UIScaleSlider",       function(v) return (v - 0.5) * 2 end },
        dm_opacity       = { "w_Opacity",               "SLD_Opacity",         function(v) return (v - 0.30) / 0.65 end },
        dm_reset_confirm = { "resetConfirm",            "resetConfirmChk" },
        dm_timestamp     = { "bTimeStampLog",           "ChkTimeStamp" },
        dm_float_player  = { "floatingNumbers",         "chk_FloatingN" },
        dm_float_tracked = { "FloatingFollowerNumbers", "chk_FloatingTracked" },
        dm_refresh       = { "refreshTimer",            "refreshSlider",       function(v) return (v - 0.05) / 0.95 end },
        dm_segment       = { "segmentTimer",            "segmentSlider",       function(v) return (v - 5) / 10 end },
        -- I6.2: the author's SaveSettings reads each colour button's `Color` (R, G, B; it sets the alpha itself — theme 0.4, bars 0.7) and the
        -- key selector's chord (recon trace of SaveSettings, 2026-11-01 — `dn_trace.txt`)
        dm_theme         = { "ThemeColor",              "ThemeColor_Selector" },
        dm_player_color  = { "PlayerBarColor",          "PlayerColor_Selector" },
        dm_followers     = { "FollowerColors",          { "Follower1_Selector", "Follower2_Selector", "Follower3_Selector", "Follower4_Selector",
                                                          "Follower5_Selector", "Follower6_Selector", "Follower7_Selector", "Follower8_Selector",
                                                          "Follower9_Selector" } },
        dm_key           = { "MouseKey",                "key_MouseKey" },
        dm_corner        = { "RestoreAnchor",           "DDL_Anchor" },        -- its save reads GetAnchorIndex(the selected option), 0–3
    } },
    -- its only button «Закрыть» → SaveSetting (writes the four fields, the slot, the player's component) — recon §2
    prp = { slot = "ProximityParty", cdo = "/Game/Mods/ProximityParty/PrP_SAV_WindowSettings.Default__PrP_SAV_WindowSettings_C",
            module = "PrP_Settings", window = "PrP_UI_Settings_C", save = { "SaveSetting" }, fields = {
        prp_enabled = { "IsEnabled",   "IsEnabled" },
        prp_scale   = { "UIScale",     "ScaleSlider",  function(v) return (v - 0.5) / 0.5 end },
        prp_radius  = { "trackRadius", "RadiusSlider", function(v) return (v - 500) / 5500 end },
        prp_max     = { "maxChars",    "widgetCount",  function(v) return (v - 1) / 14 end },
    } },
    -- «Сохранить» → SaveSettings → EnableSettings (recon §3); its save takes the scale and the marker range from the window's own fields, which only
    -- its slider handlers write — so those fields are set too
    sm = { slot = "SimpleMinimap", cdo = "/Game/Mods/Simple_Minimap/SM_BP_SaveGame.Default__SM_BP_SaveGame_C",
           module = "SM_UI_Settings", window = "SM_UI_Settings_C", save = { "SaveSettings", "EnableSettings" }, fields = {
        sm_rotate  = { "bRotate",          "hRotate" },
        sm_coords  = { "bShowCoordinates", "ChkCoordinate" },
        sm_scale   = { "UIScale",          "scaleSlider", function(v) return (v - 0.5) / 0.5 end,   "UIScale" },
        sm_markers = { "markerClampR",     "clampSlider", function(v) return (v - 150) / 400 end,   "clampRange" },
        sm_guild   = { "guildTracking",    "showGuild" },
        sm_journey = { "bMoveJourney",     "chkJourney" },
        sm_key     = { "mouseHotkey",      "keySel_MouseHotkey" },
        -- its save copies the window's field `color` (linear) into literalColor, and its time selector's handler writes the int `timeDisplay` (recon trace of
        -- SaveSettings, 2026-11-01 — `sm_trace.txt`): the field is set directly, the selector too (its handler keeps the field in step)
        sm_color   = { "literalColor",     nil,                nil,                                    "color" },
        sm_time    = { "TimetoShow",       "timeSelector",     nil,                                    "timeDisplay" },
    } },
    -- the player's component holds the five values (loaded at begin play) and applies them by UpdateSettings(lore, loot, intensity, loreColour,
    -- lootColour) — recon §4; the colours are kept as they are
    llh = { comp = "LLH_AC_PlayerComp_C", slot = "LLH_Settings", class = "/Game/Mods/LLHighlight/LLH_SAV_Settings.LLH_SAV_Settings_C", fields = {
        llh_lore = "LoreHighlightEnabled", llh_loot = "LootHighlightEnabled", llh_intensity = "HighlightIntensity",
        llh_lore_color = "LoreHighlightColor", llh_loot_color = "LootHighlightColor",
    },
        read = function(a)
            local c = inst(a.comp)
            if not c then return nil end
            local t = {}
            for id, f in pairs(a.fields) do t[id] = from_ue(KIND[id], c[f]) end
            return t
        end,
        write = function(a, v)
            local c = inst(a.comp)
            if not c then log("llh: the player's component not found — not saved"); return end
            c:UpdateSettings(v.llh_lore, v.llh_loot, v.llh_intensity, copy(v.llh_lore_color), copy(v.llh_loot_color))
            local s = statics()
            local sg = s:LoadGameFromSlot(a.slot, 0)
            -- a new slot (the player never pressed the author's «Подтвердить») starts from the class defaults — its colours are the component's then too
            if not valid(sg) then sg = s:CreateSaveGameObject(StaticFindObject(a.class)) end
            for id, f in pairs(a.fields) do sg[f] = v[id] end
            local ok = s:SaveGameToSlot(sg, a.slot, 0)
            log("llh: applied by UpdateSettings, slot %s saved: %s", a.slot, tostring(ok))
        end },
    -- the mod controller actor holds the values; «ОК» sends the server RPC with 13 arguments in this order (recon §5; the battlement / bailey wiring
    -- is taken from the parameter names — the run reads the controller back)
    amr = { mc = "AMR_MC_AlmerayahReborn_C", pc = "AMR_AC_PlayerCont_C", fields = {
        amr_enabled = "isFortActive", amr_corpse = "corpseCleanup", amr_nofatality = "disableFatalities", amr_katana = "spawnKatana",
        amr_explosives = "spawnExplosives", amr_ram = "spawnBatteringRam", amr_gold = "maxGoldPerPile", amr_field = "FieldRespawnCD",
        amr_archer = "ArcherRespawnCD", amr_battlement = "BattlementRespawnCD", amr_bailey = "BaileyRespawnCD", amr_counter_cd = "CounterAttackCD",
        amr_counter_size = "CounterAttackSize",
    },
        read = function(a)
            local mc = inst(a.mc)
            if not mc then return nil end
            local t, missing = {}, {}
            for id, f in pairs(a.fields) do
                local ok, v = pcall(function() return mc[f] end)
                if ok and (type(v) == "number" or type(v) == "boolean") then t[id] = v else missing[#missing + 1] = f end
            end
            if #missing > 0 then log("amr: controller fields not read (defaults shown): %s", table.concat(missing, ", ")) end
            return t
        end,
        write = function(a, v)
            local pc = inst(a.pc)
            if not pc then log("amr: the player's controller component not found — not saved"); return end
            local function int(x) return math.floor(x + 0.5) end
            pc:ServerSaveSettings(v.amr_enabled, v.amr_nofatality, v.amr_corpse, v.amr_field, v.amr_archer, v.amr_battlement, v.amr_bailey,
                v.amr_counter_cd, int(v.amr_counter_size), v.amr_katana, v.amr_explosives, v.amr_ram, int(v.amr_gold))
            log("amr: ServerSaveSettings sent")
        end },
}
local author_vals = {}   -- adapter key → the values read at the opening (or written by the last save)
local author_cdo = {}    -- adapter key → the mod's class defaults (slot authors)
-- a row's «Сбросить к исходным» value: its own default, or the mod's class default when it says «cdo»
local function default_of(row, p)
    if row.default ~= "cdo" then return row.default end
    return p and p.author and author_cdo[p.author] and author_cdo[p.author][row.id]
end
-- two values of one row equal? (the save writes a mod only when a row differs from what was read)
local function same_value(row, a, b)
    if a == nil or b == nil then return a == b end
    if row.kind == "check" or row.kind == "key" or row.kind == "drop" then return a == b end
    if row.kind == "color" then return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 1e-3 end
    if row.kind == "color9" then
        if #a ~= #b then return false end
        for n = 1, #a do
            if not same_value({ kind = "color" }, a[n], b[n]) then return false end
        end
        return true
    end
    return math.abs(a - b) < row.step * 0.5
end

local function read_slot(a)
    local s = statics()
    local sg = s:LoadGameFromSlot(a.slot, 0)
    if not valid(sg) then sg = StaticFindObject(a.cdo) end
    if not valid(sg) then return nil end
    local t = {}
    for id, f in pairs(a.fields) do t[id] = from_ue(KIND[id], sg[f[1]]) end
    return t
end
-- the class defaults of a slot author (the «Сбросить к исходным» value of a row whose default is «cdo» — the Damage Meter's nine bar colours)
local function read_cdo(a)
    local sg = StaticFindObject(a.cdo)
    if not valid(sg) then return nil end
    local t = {}
    for id, f in pairs(a.fields) do t[id] = from_ue(KIND[id], sg[f[1]]) end
    return t
end

local function write_window(key, a, values, done)
    local gmc = FindFirstOf("GUIModuleController")
    if not valid(gmc) then done(); return end
    gmc:ActivateModule(FName(a.module), true, false)
    ExecuteInGameThreadWithDelay(OPEN_DELAY_MS, function()
        local ok, err = pcall(function()
            local w = nil
            for _, x in ipairs(FindAllOf(a.window) or {}) do if x:IsVisible() then w = x end end
            if not w then log("%s: the author's window did not open — not saved", key); return end
            for id, f in pairs(a.fields) do
                local v, kind = values[id], KIND[id]
                if v ~= nil and kind == "color9" then
                    for n, sel in ipairs(f[2]) do
                        local s = w:GetWidgetFromName(FName(sel))
                        if valid(s) and v[n] then s.Color = copy(v[n]) end
                    end
                elseif v ~= nil then
                    local c = f[2] and w:GetWidgetFromName(FName(f[2]))
                    if valid(c) then
                        if kind == "color" then c.Color = copy(v)
                        elseif kind == "key" then c:SetSelectedKey(chord(v))
                        elseif kind == "drop" then c:SetSelectedIndex(v, SELECT_DIRECT)   -- (Index, SelectInfo): both, or UE4SS refuses (run D7 10:24)
                        elseif f[3] then c:SetValue(f[3](v))
                        else c:SetIsChecked(v) end
                    end
                    if f[4] then w[f[4]] = (kind == "color") and copy(v) or v end    -- a window field its save reads (sm: no colour control at all)
                end
            end
            for _, fn in ipairs(a.save) do w[fn](w) end
            gmc:ActivateModule(FName(a.module), false, false)
            log("%s: saved through the author's window", key)
        end)
        if not ok then
            log("%s write failed: %s", key, tostring(err))
            pcall(function() gmc:ActivateModule(FName(a.module), false, false) end)   -- a failed write left the author's window open (run D7 10:24)
        end
        done()
    end)
end

-- the pages to write, one after another: { key, values }
local function write_authors(queue, i)
    i = i or 1
    local item = queue[i]
    if not item then return end
    local key, values = item[1], item[2]
    local a = AUTHORS[key]
    if a.write then
        local ok, err = pcall(a.write, a, values)
        if not ok then log("%s write failed: %s", key, tostring(err)) end
        write_authors(queue, i + 1)
    else
        write_window(key, a, values, function() write_authors(queue, i + 1) end)
    end
end

local function fill_window()
    local cam = camera_values()
    LIVE.cam = cam ~= nil
    for key, a in pairs(AUTHORS) do
        local ok, t = pcall(a.read or read_slot, a)
        if not ok then log("%s read failed: %s", key, tostring(t)); t = nil end
        author_vals[key] = t
        LIVE[key] = t ~= nil
        if a.cdo then
            local okc, d = pcall(read_cdo, a)
            author_cdo[key] = okc and d or nil
        end
    end
    close_palette()
    close_list()
    busy = nil
    local bp = child("Brd_KrinikKeyBusy")
    if bp then bp:SetVisibility(1) end
    set_text("Txt_KrinikPalWas", "было")
    set_text("Txt_KrinikPalNow", "станет")
    -- the hub: the list's `_G.__krinik_hub` (same Lua state) or the shared variable «KrinikHubRequest» (another mod — the agent's remote; each UE4SS
    -- mod has its own Lua state, EXP-0438); both are cleared here: one opening — one hub, a later opening falls back to Krinik's
    local req = _G.__krinik_hub
    if not req then pcall(function() req = ModRef:GetSharedVariable("KrinikHubRequest") end) end
    pcall(function() ModRef:SetSharedVariable("KrinikHubRequest", "") end)
    hub = HUBS[req] and req or "krinik"
    _G.__krinik_hub = nil
    set_text("Txt_KrinikTitle", hub == "krinik" and TITLE or HUBS[hub][1])
    set_text("Txt_KrinikTitleDot", TITLE_DOT)
    set_text("Txt_KrinikTitleSub", hub == "krinik" and TITLE_SUB or HUBS[hub][2])
    for key, label in pairs(BUTTONS) do set_text("Txt_KrinikBtn_" .. key, label) end
    marquee = {}
    local first = nil
    for _, p in ipairs(PAGES) do
        local item = child("Brd_KrinikMod_" .. p.key)
        if item then item:SetVisibility(in_hub(p) and 0 or 1) end   -- Visible (hit-testable) | Collapsed
        -- the WHOLE list row goes too: a collapsed border alone left its row with the bar box (the hidden bar Image keeps its 32-unit height), so
        -- the Xevyr hub's one name stood under five empty Krinik rows — mid-height (case L0 2026-11-02 07:3x: list desired 214 → 54 after this)
        local line = child("HB_KrinikModItem_" .. p.key)
        if line then line:SetVisibility(in_hub(p) and 4 or 1) end   -- SelfHitTestInvisible (the kit's own) | Collapsed
        local name = set_text("Txt_KrinikModName_" .. p.key, p.name)
        if in_hub(p) then
            first = first or p
            local box = child("SC_KrinikModName_" .. p.key)
            if box and name then marquee[p.key] = { box = box, text = name, offset = 0, dir = 1, hold = MARQUEE_HOLD } end
        end
        -- a page that is not live is not filled (its rows may not exist in the kit yet — the Damage Meter page before its kit rebuild logged
        -- «slider not found» ×4, 2026-11-01 23:15); save() walks the live pages only, so nothing reads the unfilled controls
        for _, row in ipairs(LIVE[p.key] and p.rows or {}) do
            set_text("Txt_KrinikLbl_" .. row.id, row.label)
            set_text("Txt_KrinikInfo_" .. row.id, "i")
            set_text("Txt_KrinikHint_" .. row.id, row.hint or "")
            local v
            if p.own == "KrinikCamera" then
                v = cam and cam[row.id]
                if v == nil then v = row.default end
            elseif p.author then
                v = author_vals[p.author] and author_vals[p.author][row.id]
                if v == nil then v = default_of(row, p) end
            else
                v = settings.get(row.id, row.default)
            end
            set_control(row, v)
        end
    end
    hide_tip()
    -- the window's height = the tallest LIVE page (the kit leaves the height to the content): a page switch never resizes the window, and a short
    -- list leaves no empty half (seam S1, the owner 21:41 «огромный»; Svarog UI_RULEBOOK В2 and К2). A widget switcher measures only its active page.
    local frame, sw = child("SB_KrinikWindow"), child("WS_KrinikPages")
    if frame and sw then
        frame:ClearHeightOverride()
        local tallest = 0
        for i, p in ipairs(PAGES) do
            if in_hub(p) then
                show_page(sw, p, i)
                frame:ForceLayoutPrepass()
                tallest = math.max(tallest, frame:GetDesiredSize().Y)
            end
        end
        -- the window never grows past the mockup's height: a longer page SCROLLS in SC_KrinikRows, whose scroll bar shows only when the page does not
        -- fit (`[OWNER]` 2026-11-02 10:57 «в окне настроек Криника - лист с опциями, это скролящийся список. КОгда много пунктов - появляется скрол бар»;
        -- until then the height followed the tallest page — 17 rows on the KrinikConanUI page would have run past the screen). [NOT-TESTED]
        local height = MIN_HEIGHT
        if tallest > 0 then frame:SetHeightOverride(height) end
        log("window height %.0f (the tallest live page %.0f, mockup 5 %.0f)", height, tallest, MIN_HEIGHT)
    end
    if first then select_page(first) end
end

-- ---- 3. clicks --------------------------------------------------------------------------------------------------------------------------
local function close_window(why)
    hide_tip()          -- before win = nil: hide_tip reads the window (run 4, 20:56 — «attempt to index a nil value (upvalue 'win')», the window stayed open)
    close_palette()
    close_list()
    busy = nil
    local w = win
    win = nil
    if valid(w) then
        local ok = pcall(function() w:TryCloseWindow() end)
        log("closed (%s)%s", why, ok and "" or " — TryCloseWindow failed")
        -- The camera and the pack manager (their own Lua states) take a saved set in a pre-hook of GUIModuleController:ActivateModule(…, false);
        -- TryCloseWindow closes the module NATIVELY and that hook never fires — the set waited for the next window the game closed (the inventory):
        -- run 2026-11-01 14:40, «camera set handed over», nothing applied until Tab. Closing through the UFunction from Lua goes by ProcessEvent,
        -- so every mod's hook sees it at once. [TESTED: see KUMM testcases/TC_conan_hub_rows_audit_2026-11-01.md H1–H8]
        local ok2 = pcall(function()
            local gmc = FindFirstOf("GUIModuleController")
            if gmc and gmc:IsValid() then gmc:ActivateModule(FName(ROW), false, false) end
        end)
        if not ok2 then log("ActivateModule(false) after the close failed") end
    end
end

local function save()
    local changes, authors = {}, {}
    for _, p in ipairs(PAGES) do
        if LIVE[p.key] and p.own == "KrinikCamera" then
            -- the whole camera page as one set; the camera takes it when a game window closes (its main.lua, hub_take_set) and writes its config.lua.
            -- Only when a camera row differs from the camera's own values: a save on another page must not rewrite the camera's file (it did, 22:45).
            local parts, now, differs = {}, camera_values() or {}, false
            for _, row in ipairs(p.rows) do
                local v = read_control(row)
                if v ~= nil then
                    parts[#parts + 1] = row.id .. "=" .. tostring(v)
                    local c = now[row.id]
                    if row.kind == "check" then
                        if v ~= c then differs = true end
                    elseif type(c) ~= "number" or math.abs(v - c) >= (row.step or 1) * 0.5 then
                        differs = true
                    end
                end
            end
            local set = differs and table.concat(parts, ";") or ""
            pcall(function() ModRef:SetSharedVariable("KrinikCameraSet", set) end)
            log(differs and "camera set handed over: %s" or "camera page unchanged — nothing handed over%s", set)
        elseif p.author then
            -- only from its own hub (a save in Krinik's hub must not open an author's window — the page is live there too, just hidden), and only
            -- when a row differs from what the mod held at the opening
            if in_hub(p) then
                local values, before, differs = {}, author_vals[p.author] or {}, false
                for _, row in ipairs(p.rows) do
                    -- a SNAPSHOT, never the window's live table: author_vals keeps these values, and a later «Принять» on a nine-colour row edits the
                    -- window's list in place — with a shared table the next save saw no change («dm unchanged», case C6 2026-11-02 08:15)
                    local v = snapshot(read_control(row))
                    values[row.id] = v
                    local b = before[row.id]
                    if b == nil then b = default_of(row, p) end
                    if v ~= nil and not same_value(row, v, b) then differs = true end
                end
                if differs then
                    authors[#authors + 1] = { p.author, values }
                    author_vals[p.author] = values
                else
                    log("%s unchanged — the mod is not written", p.author)
                end
            end
        elseif LIVE[p.key] then
            for _, row in ipairs(p.rows) do
                local v = read_control(row)
                if v ~= nil then
                    -- the default is not written: the file keeps only what the player changed (a mod update with a new default still reaches him)
                    -- if/else, not `a and b or c`: with b == false Lua takes c — a check row fell into the slider arithmetic (run 2, 20:51)
                    local same
                    if row.kind == "check" then same = (v == row.default)
                    else same = math.abs(v - row.default) < (row.step or 1) * 0.5 end
                    changes[row.id] = same and settings.DEFAULT or v
                end
            end
        end
    end
    settings.save(changes)
    write_authors(authors)
end

local function reset_page()
    for _, row in ipairs(page and page.rows or {}) do
        local d = default_of(row, page)
        if d ~= nil then set_control(row, d) end
    end
    log("page %s reset to defaults (not saved)", page and page.key or "?")
end

local function hovered(name)
    local w = child(name)
    return w ~= nil and w:IsHovered()
end

local function on_click()
    if not win then return end
    if not valid(win) or not win:IsVisible() then win = nil; return end
    -- the option list, while open, takes every click: an option sets the row and closes it, a click outside closes it unchanged
    if list then
        for i = 1, #list.row.options do
            if hovered("Brd_KrinikListO_" .. (i - 1)) then
                set_control(list.row, i - 1)
                log("list: %s → %s (not saved)", list.row.id, list.row.options[i])
                close_list()
                return
            end
        end
        if not hovered("Brd_KrinikList") then log("list closed unchanged") end
        close_list()
        return
    end
    -- the palette, while open, takes every click: a swatch picks, «Принять» writes the row, «Отмена» or a click outside closes it unchanged
    if pal then
        if hovered("Img_KrinikPalRect") then pick_point(); return end
        for k = 1, #PALETTE do
            if hovered("Brd_KrinikPalC_" .. (k - 1)) then pick_palette(k); return end
        end
        if hovered("Brd_KrinikBtn_PalOk") then accept_palette(); return end
        if hovered("Brd_KrinikBtn_PalCancel") or not hovered("Brd_KrinikPal") then log("palette closed unchanged"); close_palette() end
        return
    end
    for _, row in ipairs(page and page.rows or {}) do
        if row.kind == "drop" and hovered("Brd_KrinikDrop_" .. row.id) then open_list(row); return end
        if row.kind == "color" or row.kind == "color9" then
            for c = 1, (row.kind == "color9" and 9 or 1) do
                if hovered(("Brd_KrinikSwC_%s_%d"):format(row.id, c - 1)) then open_palette(row, c); return end
            end
            if row.kind == "color" and hovered("Brd_KrinikSw_" .. row.id) then open_palette(row, 1); return end
        end
    end
    if hovered("Brd_KrinikBtn_Close") then close_window("без сохранения"); return end
    if hovered("Brd_KrinikBtn_Save") then save(); return end
    if hovered("Brd_KrinikBtn_SaveClose") then save(); close_window("сохранено"); return end
    if hovered("Brd_KrinikBtn_Reset") then reset_page(); return end
    for _, row in ipairs(page and page.rows or {}) do
        if row.kind == "check" and hovered("Brd_KrinikChk_" .. row.id) then
            set_check(row, not checks[row.id])
            log("click: check %s → %s", row.id, tostring(checks[row.id]))
            return
        end
    end
    for _, p in ipairs(PAGES) do
        if in_hub(p) and p ~= page and hovered("Brd_KrinikMod_" .. p.key) then hide_tip(); select_page(p); return end
    end
    for i, row in ipairs(page and page.rows or {}) do
        if hovered("Brd_KrinikInfo_" .. row.id) then
            -- a click pins the plate (it stays when the mouse leaves); a click on a pinned plate's «i» unpins and hides it
            if tip_row == row and tip_pinned then hide_tip() else show_tip(row, i - 1); tip_pinned = true end
            log("click: «i» %s %s", row.id, tip_pinned and "pinned" or "hidden")
            return
        end
    end
end
RegisterKeyBind(Key.LEFT_MOUSE_BUTTON, function()
    if not win then return end            -- play: one boolean (criterion 7)
    -- the evidence line: a click on «Сохранить» did not route in run 1 (2026-10-31 20:48) though the button reads hovered — does the bind fire at all?
    log("LMB (window open)")
    ExecuteInGameThread(function()
        local ok, err = pcall(on_click)
        if not ok then log("click failed: %s", tostring(err)) end
    end)
end)

-- ---- 4. while open: the «i» hover and the marquee -------------------------------------------------------------------------------------
local function watch(w)
    ExecuteInGameThreadWithDelay(WATCH_MS, function()
        if win ~= w or not valid(w) or not w:IsVisible() then
            if win == w then win = nil end
            log("watch stopped (window closed)")
            return
        end
        pcall(function()
            -- «i»: hover shows, leaving hides (a click pins and unpins the same plate)
            local over = nil
            for i, row in ipairs(page and page.rows or {}) do
                if hovered("Brd_KrinikInfo_" .. row.id) then over = { row, i - 1 }; break end
            end
            if over and tip_row ~= over[1] then show_tip(over[1], over[2]); tip_pinned = false
            elseif not over and tip_row and not tip_pinned then hide_tip() end
            -- a dragged thumb: its value text follows (only on a change); a flat button lights up under the cursor
            for _, row in ipairs(page and page.rows or {}) do
                if row.kind == "slider" then
                    local c = slider(row)
                    if c then show_value(row, c:GetValue()) end
                end
            end
            watch_keys()     -- a key the selector caught: taken, or refused with the busy plate
            busy_step()      -- the busy plate's fade in, hold and fade out
            for key in pairs(BUTTONS) do
                local b = child("Brd_KrinikBtn_" .. key)
                if b then
                    local k = b:IsHovered() and BTN_HOT or 1.0
                    b:SetBrushColor({ R = k, G = k, B = k, A = 1.0 })
                end
            end
            -- the marquee: a name wider than its box slides to its end and back, resting a second at each end
            for _, m in pairs(marquee) do
                local width = m.text:GetDesiredSize().X
                local span = width - NAME_BOX
                if span > 1 then
                    if m.hold > 0 then m.hold = m.hold - 1
                    else
                        m.offset = m.offset + m.dir * MARQUEE_PX
                        if m.offset >= span then m.offset, m.dir, m.hold = span, -1, MARQUEE_HOLD
                        elseif m.offset <= 0 then m.offset, m.dir, m.hold = 0, 1, MARQUEE_HOLD end
                        m.box:SetScrollOffset(m.offset)
                    end
                end
            end
        end)
        watch(w)
    end)
end

RegisterHook("/Script/ConanSandbox.GUIModuleController:ActivateModule", function(_, name, activate)
    local ok, n, on = pcall(function() return str(name:get()), activate:get() end)
    if not ok or n ~= ROW or not on then return end
    ExecuteInGameThreadWithDelay(OPEN_DELAY_MS, function()
        for _, w in ipairs(FindAllOf(WINDOW_CLASS) or {}) do
            if valid(w) and not w:GetFullName():find("Default__", 1, true) and w:IsVisible() then
                win = w
                local t0 = os.clock()
                local okf, err = pcall(fill_window)
                log("window %s opened: filled %s%s in %.2f ms", w:GetFName():ToString(), okf and "ok" or "FAILED ", okf and "" or tostring(err),
                    (os.clock() - t0) * 1000)
                watch(w)
                return
            end
        end
        log("module opened, but no visible %s found", WINDOW_CLASS)
    end)
end)

log("loaded: merge at the main menu, window filled at opening from %s, LMB routed only while open", settings.PATH)
