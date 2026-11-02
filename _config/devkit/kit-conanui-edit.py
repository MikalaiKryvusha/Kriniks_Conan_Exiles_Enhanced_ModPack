# kit-conanui-edit.py — правка родного интерфейса в ките для мода KrinikConanUI (до 2026-10-30 — KrinikUIFixes и kit-uifixes-edit.py; KUMM bugs/64
# п. 32, план 36 W31). Запуск в режиме модов кита (`-ModDevKit`, активный мод KrinikConanUI по active.txt): изменённый родной ассет кит сам сохраняет
# в Mods/KrinikConanUI/Content/….
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<этот файл> -EnablePlugins=PythonScriptPlugin -ModDevKit
#
# Плашка над трупом и окно быстрого лута — один виджет WBP_ContainerInfo: Overlay_Main → OverlaySlot_5 (плашка Border_Underlay: имя,
# «Труп», «…нажмите E, чтобы забрать предметы») и OverlaySlot_3 (W_QuickLootPanel, отступ слева 500). У обоих слотов выравнивание по
# центру: плашка всегда в центре оверлея, окно лута — справа от центра. Русская строка подсказки шире английской, и плашка уходит под окно.
# Правка — только плашка: выравнивание Left, отступы слева и справа равные. Окно лута не трогаем: при выравнивании по центру с отступом
# слева 500 его место на экране не зависит от ширины оверлея (центр окна = центр оверлея + 250).
#   окно лута показано → оверлей шире плашки, плашка прижимается к его левому краю — левее окна;
#   окна нет → оверлей шириной в плашку, плашка по центру, как раньше.
# Сборка 1 давала окну Right — оно уехало вправо на ≈ 88 точек кадра: `[OWNER]` «а квик лут - ты сдвинул вправо?» · «может не стоило?»
# (2026-10-28 20:31). Окну возвращено родное Center.
# Это слово владельца: «если открывается этот виджет быстрого лута, то подсказку над трупом - нужно на экране двигать левее»
# (2026-10-27 00:2x). Имён HAlign_Left/HAlign_Right нет в таблице имён ассета игры — поэтому кит, а не правка готового ассета (EXP-0338).
# Отчёт kit-conanui-edit.json рядом. [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo"
SLOTS = {   # слот → выравнивание по горизонтали
    "OverlaySlot_5": unreal.HorizontalAlignment.H_ALIGN_CENTER,  # strip: vanilla Center; the Lua half sets Left while the loot window shows (item 35)
    "OverlaySlot_3": unreal.HorizontalAlignment.H_ALIGN_CENTER,  # окно быстрого лута — родное (сборка 1 ставила Right)
}
# Отступы плашки слева и справа (родные 20): с 20 плашка при открытом луте вставала почти к краю экрана (кадр F2 2026-10-28: текст с 35-й
# точки из 2000, зазор до окна ≈ 270), 120 сдвигает её к центру на 100 единиц, зазор ≈ 50 точек кадра. Отступы равные — без окна лута
# плашка по-прежнему по центру.
STRIP_PAD = 120.0
QL_WIDGET = "/Game/UI/HUD/FloatingNames/W_QuickLootPanel"
QL_GRID_PAD = 35.0   # родное 10; правый край окна лута на кромке панели квеста (замер по кадру, см. ниже)
QL_TIPS_PAD = 20.0   # отступы ряда подсказок слева и справа, родные 35: ряд действий не шире сетки (см. ниже)
QL_TAKEALL_GAP = 20.0  # «Забрать все» → значок Esc: родное 0 (на кадре «Забрать всеEsc»), 20 — как у прочих подписей ряда
QL_HOLD_ICONS = ("W_HotkeyIcon_3", "W_HotkeyIcon_4")          # QuickLootNavTakeAll icons of the action row and the navigation row
QL_TAKEALL_LABELS = ("LootButtonLabel_1", "LootButtonLabel_2")  # «Забрать все» next to those icons
QL_TAKEALL_TEXT = "Забрать все (удерж.)"   # «длинное (удерживайте) можно и нужно сократить до (удерж.)» (владелец, 2026-10-30 08:32; W10a)
QL_HOLD_HIDDEN = 1   # HotkeyHoldPromptVisibility value that hid the prompt live (pult, 2026-10-28 23:55)
TT_WIDGET = "/Game/UI/Inventory/W_ItemIconTooltipView"   # the item hover tooltip (item 17, class A — see below)
PERK_WIDGET = "/Game/UI/Inventory/Attributes/W_AttributeInfoEntry_PerkView"   # one perk row of the «Хар-ки» info column (item 46)
PERK_TEXT_PAD = 10.0   # PerkDescription slot padding top and bottom, native Top 2 / Bottom 5 (see below)
LINE1_NAME = "T_CorpseText1"   # our line above the action row in the corpse strip (W6 centred, see below); krinik_ui_fixes.lua fills it
LINE1_ENABLED = True   # ON again 21:1x (the strip opened by code works on the vanilla-reset build; bug 70). Before: 20:4x OFF on a FALSE inference: after 19:58 the stand stopped showing the strip on EVERY build, the vanilla-reset one included (the «class not loaded» probe reads false on a good build too); the line build of 20:19 cooked clean and is not proven bad. The kit asset was reset from vanilla (the old one kept in the session scratchpad broken-wbp/). To turn on again: True + the override row ON — a fresh widget gets a GUID; never remove a widget that has one (cook: «was deleted but still has a GUID referenced»).
LINE1_OLD_NAMES = ("T_PromptLine1", "T_CorpseLine1")   # tries 1 and 2 of 2026-10-30 (see below) — taken out of the strip
LINE1_LINEAR = tuple(round((c / 255.0) ** 2.2, 4) for c in (233, 213, 193)) + (1.0,)   # the prompt row ink, sRGB measured
STRIP_SIDE_PAD = 140.0   # [AI] Content padding left/right (vanilla 12) ≈ the side fade width below: the line ends sit where the backing is ≥ 90 % dark
UNDERLAY_SIDE_MARGIN = 0.40   # [AI] Box margin left/right of the backing brush (vanilla 0): the texture's alpha is ≥ 90 % of its peak from 40 % to 60 %
                              # of its width, so the sides 0..0.40 / 0.60..1 are the fade at a FIXED width (0.40 × ImageSize.X 356 ≈ 142 units)
                              # and only the dark middle stretches with the text (probe kit-probe-underlay.py, 2026-10-30 22:0x)
LINE1_GAP = 2.0                # [AI] units between the two prompt lines; the row's own line spacing is the font's
STRIP_SCALE = 0.70             # the corpse strip drawn 30 % smaller: `[OWNER]` 08:54 «сделать меньше на 25%» → after review folder 59, 10:54 «фон 60, меньше на» · «30»
STRIP_BACKING_ALPHA = 0.6      # the backing's brush colour alpha (vanilla 0.8): `[OWNER]` 2026-11-02 10:54 «фон 60» (review folder 59: variants 0.8 / 0.55 / 0.35)
AT_WIDGET = "/Game/UI/HUD/Notifications/W_ActionTutorial"   # the shared action-prompt row «PreText · Icon · PostText» (plan 36 W6, see below)
AT_ICON_PAD_BOTTOM = 1.0   # icon centre on its text line as VAlign Center had it: plate-edge measure, text-ink centre minus plate centre = 4.5 px vanilla (B1), 6.75 px with pad 2, 19 px with pad 8 -> 2.04 px per unit at 4K -> pad ≈ 0.9 (frames 2026-10-30 18:35 / 18:51 / 19:19). The first «12.5 px low» was a detector catching the background
MENUS = (   # W26: (widget path, name, the overlay holding the game's Image_Logo, where ours goes, our max width in units or 0,
            #       our logo's height vs the game logo's visible height, the gap between the logos — share of that height)
    # main menu: «потом в меню главном наш логотим сделй меньше и правее» (the owner, 2026-10-31 00:11) — [AI] 0.92 → 0.78, gap 0.12 → 0.40
    ("/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu", "W_MainMenu_MainMenu", "Overlay_Main", "right", 0.0, 0.78, 0.40),
    # Esc menu: Simple Modlist's panel (680 wide, KUMM SimpleModlist.md) ends ≈ 729 units from the left at 1080p, the game's logo starts ≈ 1172 —
    # at full height ours (561 wide) ran over the panel's right edge (frame 2026-10-30 ≈23:07); it is capped to the free span
    ("/Game/UI/HUD/W_IngameMenu", "W_IngameMenu", "Overlay_1", "left", 400.0, 0.92, 0.12),
)
# Bug 71 (KUMM bugs/71): the kit has no /Game/Movies — the main menu's backdrop arrays BackgroundMovies / BackgroundMovieTextures point there,
# so a kit save of W_MainMenu_MainMenu wrote them EMPTY and Image_BinkPlayer drew its bare white brush («все белое», the owner 2026-10-31 00:10).
# Placeholders of the same class at the same paths make the save keep the references; they are NOT in CookInfo, so the pak carries none of
# them and the game resolves the paths to its own movies. Order and classes — the vanilla asset (retoc to-legacy + uaj tojson, 2026-10-31 00:3x).
# The check of the whole class — kit-missing-refs.py (a vanilla widget's /Game refs the kit lacks). [NOT-TESTED]
# W37 the «ОТЗЫВ» button: `[OWNER]` «высота 40 принята» · 2026-10-31 01:03 (the Б1 plate, centred under «1.0.0», review folder 20) · «и на меню паузы
# ESC тоже нужна будет кнопка отзыва» · 01:04. A plain Image (Visible — it takes the hover and the click); the click and the hover texture swap are the
# Lua section krinik_feedback (events of the menu widget, no poll). Textures: _config/branding/mock-feedback-button.py --textures → import-logo-texture.py.
FEEDBACK_TEX = "/Game/Mods/KrinikConanUI/T_KrinikFeedback"
FEEDBACK_H = 40.0            # units — the accepted height
FEEDBACK_BELOW_VERSION = 44.0   # units from the top of our version line to the plate: ≈ 24 the line + 20 the gap. Was 34 (mock-up round 5);
                                # `[OWNER]` «можно кнопку отзыва чуть ниже» · «10 пикселей» · 2026-10-31 07:47 (seen at 1080p, where 1 unit = 1 px)
MENU_MOVIES = ("Claws", "Icefield", "Jungle", "UnnamedCity", "Volcano", "WineCellar")
MENU_MOVIE_PATH = "/Game/Movies"                 # TitleScreen_<X>      — BinkMediaPlayer
MENU_MOVIE_TEX_PATH = "/Game/Movies/MediaTextures"   # TitleScreen_<X>_Tex — BinkMediaTexture
LOGO_TEX = "/Game/Mods/KrinikConanUI/T_KrinikModpackLogo"   # import-logo-texture.py (trimmed to its alpha box, 1024×388)
GAME_VIS = (21 / 1024.0, 18 / 512.0, 999 / 1024.0, 462 / 512.0)   # the visible box of T_UI_ConanExiles_Enhanced_Logo: left, top, width, height shares
OUR_VIS = (39 / 1024.0, 35 / 388.0, 971 / 1024.0, 324 / 388.0)    # the SOLID box (alpha >= 64) of T_KrinikModpackLogo: a soft shadow lies outside it (2026-10-30 23:2x)
VERSION_GAP = 2.0         # [AI] units between a logo and its version line
VERSION_FONT_SIZE = 18    # [AI] small: «но в игре текст меньше» (the owner 22:51); 14 read tinier than the game's own «Версия» line (frame 23:07)
GAME_VERSION = "3.0.1"
PACK_VERSION = "0.9.0"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-conanui-edit.json")

res = {"ok": False, "steps": []}
try:
    bp = unreal.load_asset(WIDGET)
    res["steps"].append("loaded %s" % bp.get_path_name())
    for name, align in SLOTS.items():
        slot = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.Overlay_Main.%s" % (WIDGET, name))
        if slot is None:
            raise RuntimeError("slot not found: " + name)
        before = slot.get_editor_property("horizontal_alignment")
        slot.set_editor_property("horizontal_alignment", align)
        res["steps"].append("%s: %s -> %s, padding %s" % (name, before, slot.get_editor_property("horizontal_alignment"),
                                                         slot.get_editor_property("padding")))
    strip = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.Overlay_Main.OverlaySlot_5" % WIDGET)
    pad = strip.get_editor_property("padding")
    pad.left, pad.right = STRIP_PAD, STRIP_PAD
    strip.set_editor_property("padding", pad)
    res["steps"].append("OverlaySlot_5 padding -> %s" % strip.get_editor_property("padding"))
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    # Окно быстрого лута (W_QuickLootPanel): ширину давал ряд подсказок внизу (WidgetSwitcherTooltips меряется по активному ряду), и при выборе
    # предмета колесом ряд менялся — окно дёргалось и меняло ширину (`[OWNER]` «при первом открытии - окно квик лута одного размера, а когда
    # колесико кручу … окно дергается»). Отступы сетки предметов 10 → QL_GRID_PAD: ширину задаёт сетка, ряды подсказок её не меняют, а правый
    # край окна — по кромке панели квеста (`[OWNER]` «правый край окна вкик лута был четко выровнен с правым краем описания квеста» · «всегда был
    # зафиксирован на этом месте»).
    # Сборка 3 (отступ 23) дала окну меньше, чем считала: замер 2026-10-28 22:05 по столбцам рамки на кадрах 4K — при открытии 2236–3697, после
    # прокрутки 2205–3727 (центр 2966,5 в обоих), кромка квеста 3717–3722. Масштаб интерфейса 2,09 px на единицу (GetViewportScale), не 4,2.
    # Сетке нужно +25 px на сторону → +12 единиц → 35: правый край ≈ 3722. Ряд действий (пульт, ширина по содержимому): 650,4 единицы + 2 × 35 —
    # шире сетки, и окно росло при прокрутке; с зазором QL_TAKEALL_GAP и отступами QL_TIPS_PAD — 690,4 против ≈ 715 у сетки. [NOT-TESTED]
    ql = unreal.load_asset(QL_WIDGET)
    grid = unreal.find_object(None, "%s.W_QuickLootPanel:WidgetTree.VerticalBox_1.VerticalBoxSlot_2" % QL_WIDGET)
    if grid is None:
        raise RuntimeError("quick-loot grid slot not found")
    gpad = grid.get_editor_property("padding")
    before = (gpad.left, gpad.right)
    gpad.left, gpad.right = QL_GRID_PAD, QL_GRID_PAD
    grid.set_editor_property("padding", gpad)
    res["steps"].append("W_QuickLootPanel grid padding %s -> %s" % (before, grid.get_editor_property("padding")))
    for name, edit in (("WidgetSwitcherTooltips", lambda p: (setattr(p, "left", QL_TIPS_PAD), setattr(p, "right", QL_TIPS_PAD))),
                       ("LootButtonLabel_1", lambda p: setattr(p, "right", QL_TAKEALL_GAP))):
        w = unreal.find_object(None, "%s.W_QuickLootPanel:WidgetTree.%s" % (QL_WIDGET, name))
        if w is None:
            raise RuntimeError("quick-loot widget not found: " + name)
        slot = w.get_editor_property("slot")
        p = slot.get_editor_property("padding")
        before = (p.left, p.right)
        edit(p)
        slot.set_editor_property("padding", p)
        res["steps"].append("W_QuickLootPanel %s padding %s -> %s" % (name, before, slot.get_editor_property("padding")))
    # Item 34 (KUMM bugs/64): «Q (удерживайте) Забрать все» → «Q Забрать все (удерживайте)» (`[OWNER]` «у окна квик лута нужно местами
    # поменять текста "Забрать всё" и "Удерж."»). The hold words live in the shared W_HotkeyIcon (TextBlockHoldPrompt, switched natively by
    # the action's long-press flag); the native per-instance property HoldPromptVisibility hides them on the two take-all icons only, and the
    # label carries them instead. A plain (invariant) text: the build is Russian-only. Checked live by the pult 2026-10-28 23:55 (case P4 of
    # KUMM testcases/TC_conan_loot_panel_hidden_and_hold_prompt_2026-10-28.md). [NOT-TESTED] in the built pak.
    # The property is the game's own enum HotkeyHoldPromptVisibility (not SlateVisibility — the first kit run failed on that, 2026-10-28
    # 23:5x); the live pult value 1 hid the prompt, so the member with value QL_HOLD_HIDDEN is taken, and every member is logged.
    hold_enum = unreal.HotkeyHoldPromptVisibility
    members = {m: getattr(hold_enum, m) for m in dir(hold_enum) if m.isupper()}
    res["steps"].append("HotkeyHoldPromptVisibility members %s" % {k: int(v.value) for k, v in members.items()})
    hidden = [v for v in members.values() if int(v.value) == QL_HOLD_HIDDEN]
    if len(hidden) != 1:
        raise RuntimeError("no single HotkeyHoldPromptVisibility member with value %d" % QL_HOLD_HIDDEN)
    for name in QL_HOLD_ICONS:
        w = unreal.find_object(None, "%s.W_QuickLootPanel:WidgetTree.%s" % (QL_WIDGET, name))
        if w is None:
            raise RuntimeError("quick-loot hotkey icon not found: " + name)
        w.set_editor_property("hold_prompt_visibility", hidden[0])
        res["steps"].append("W_QuickLootPanel %s hold_prompt_visibility -> %s" % (name, w.get_editor_property("hold_prompt_visibility")))
    for name in QL_TAKEALL_LABELS:
        w = unreal.find_object(None, "%s.W_QuickLootPanel:WidgetTree.%s" % (QL_WIDGET, name))
        if w is None:
            raise RuntimeError("quick-loot label not found: " + name)
        w.set_editor_property("text", unreal.Text(QL_TAKEALL_TEXT))
        res["steps"].append("W_QuickLootPanel %s text -> %s" % (name, w.get_editor_property("text")))
    unreal.BlueprintEditorLibrary.compile_blueprint(ql)
    res["saved_ql"] = unreal.EditorAssetLibrary.save_loaded_asset(ql, False)
    # Item 17, class A (KUMM bugs/64): the item hover tooltip opens with its frame sized for one line and the text already in two, and a frame
    # later the frame jumps to two lines (`[OWNER]` «Открываются в одну строку, а затем становятся в две» · 2026-10-29 18:0x). Text_Content
    # auto-wraps at the width the PREVIOUS frame allotted, and nothing gives the tooltip a width — so the text collapses word by word. With
    # AutoWrapText off it wraps only at its own WrapTextAt 800 and keeps one layout from the first frame: measured live 2026-10-29 (remote on
    # the class template, cases T1–T3 of KUMM testcases/TC_conan_item_tooltip_first_frame_wrap_2026-10-29.md: 405×127 → 274×165 before,
    # 405×107 steady after, 3 of 3 each). No build mod overrides this widget (mod-overrides.py over 67 paks, 2026-10-29). [NOT-TESTED] in the pak.
    tt = unreal.load_asset(TT_WIDGET)
    text = unreal.find_object(None, "%s.W_ItemIconTooltipView:WidgetTree.Text_Content" % TT_WIDGET)
    if text is None:
        raise RuntimeError("tooltip Text_Content not found")
    before = (text.get_editor_property("auto_wrap_text"), text.get_editor_property("wrap_text_at"))
    text.set_editor_property("auto_wrap_text", False)
    res["steps"].append("W_ItemIconTooltipView Text_Content auto_wrap_text/wrap_text_at %s -> %s" % (
        before, (text.get_editor_property("auto_wrap_text"), text.get_editor_property("wrap_text_at"))))
    unreal.BlueprintEditorLibrary.compile_blueprint(tt)
    res["saved_tt"] = unreal.EditorAssetLibrary.save_loaded_asset(tt, False)
    # Item 46 (KUMM bugs/64): on the hub tab «Хар-ки» the perk descriptions of «Сила» run into each other — «Берсерк» into «Кровожадный
    # берсерк», that into «Сокрушительные удары» (frame stats.jpg 2026-10-29 21:38). Read from the 3.0.1 assets: a perk row
    # (W_AttributeInfoEntry_PerkView) is a HorizontalBox of the pip and PerkDescription (slot Fill, VAlign Center, padding Top 2 / Bottom 5);
    # the pip's brushes are set to 120×120 by SetupFromPerkPip, so a row is max(120, text + 7) tall. The rows DO grow with the text, but
    # with no air: W_AttributeInfo.ConstructInfoWidgets gives every entry (W_AtrributeInfoEntry) a widget padding Top −4 / Bottom −4 (the
    # entries overlap by 8), and the two views of a linked pair overlap by 4 (slot paddings −2 / −2). Gap between two descriptions =
    # 5 + 2 − 8 = −1 unit across entries, 5 + 2 − 4 = 3 inside a pair, while a line of this text is ≈ 28 units. English descriptions are
    # one–two lines and sit in a 120-tall row with air; ours run to four–five lines (> 113 units), so the row is the text and the next
    # description starts at the line pitch. Fix: padding PERK_TEXT_PAD top and bottom → gaps 12 across entries, 16 inside a pair; rows of
    # up to three lines keep the native 120 (text + 20 ≤ 120), only rows of four and more lines grow (+13 units each).
    # The link icon (W_AtrributeInfoEntry.PerkIconLink, VAlign Fill, Top/Bottom 82, drawn under the pips) stays hidden behind the pip
    # discs while each row of a pair is 110…218 units tall — up to ≈ 6.9 lines with this padding. Auto-wrap is left native: the row's
    # text width is constant (585 − 120 = 465), so the previous-frame width is the right one after the first frame. [NOT-TESTED]
    perk = unreal.load_asset(PERK_WIDGET)
    text = unreal.find_object(None, "%s.W_AttributeInfoEntry_PerkView:WidgetTree.PerkDescription" % PERK_WIDGET)
    if text is None:
        raise RuntimeError("perk PerkDescription not found")
    slot = text.get_editor_property("slot")
    p = slot.get_editor_property("padding")
    before = (p.top, p.bottom)
    p.top, p.bottom = PERK_TEXT_PAD, PERK_TEXT_PAD
    slot.set_editor_property("padding", p)
    res["steps"].append("W_AttributeInfoEntry_PerkView PerkDescription padding top/bottom %s -> %s" % (before, slot.get_editor_property("padding")))
    unreal.BlueprintEditorLibrary.compile_blueprint(perk)
    res["saved_perk"] = unreal.EditorAssetLibrary.save_loaded_asset(perk, False)
    # Plan 36 W6 (bugs/64 item 36): the corpse prompt on two lines. The row W_ActionTutorial lays out PreText (justify RIGHT) · Icon · PostText,
    # all slots VAlign CENTER (kit probe kit-probe-action-tutorial.json, 2026-10-30 18:3x); the game cuts the localized string at {0}. A line
    # break inside PreText (the vanilla-override row «…ресурсы\nили нажмите {0}…») made PreText two lines tall and the centred icon and PostText
    # hung BETWEEN the lines (T1 fail 2026-10-28). Icon and PostText go to the BOTTOM: they stand on PreText's last line, which ends at the icon
    # (justify RIGHT), so line 2 reads «или нажмите [E], чтобы забрать предметы». A one-line prompt: the texts are one line tall and
    # the icon (≈20 units, shorter than the line) sits at the bottom raised by AT_ICON_PAD_BOTTOM — the place VAlign Center gave it (measured
    # by frames, see the constant). Shared by every action prompt of the game; no build mod overrides it (mod-overrides.py over the Mods folder,
    # 2026-10-30 18:2x). The kit cooks only what Local/CookInfo.ini lists: the widget's FilesToCook line was added there (a first build without
    # it silently shipped the old four widgets). Two lines seen in game 2026-10-30 18:51 with pad 2.0 (KUMM TC_conan_corpse_prompt_two_lines, P1).
    at = unreal.load_asset(AT_WIDGET)
    for name, pad_bottom in (("Icon", AT_ICON_PAD_BOTTOM), ("PostText", None)):
        w = unreal.find_object(None, "%s.W_ActionTutorial:WidgetTree.%s" % (AT_WIDGET, name))
        if w is None:
            raise RuntimeError("W_ActionTutorial %s not found" % name)
        slot = w.get_editor_property("slot")
        before = (slot.get_editor_property("vertical_alignment"), slot.get_editor_property("padding"))
        slot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_BOTTOM)
        if pad_bottom is not None:
            p = slot.get_editor_property("padding")
            p.bottom = pad_bottom
            slot.set_editor_property("padding", p)
        res["steps"].append("W_ActionTutorial %s valign/padding %s -> %s" % (name, before, (
            slot.get_editor_property("vertical_alignment"), slot.get_editor_property("padding"))))
    unreal.BlueprintEditorLibrary.compile_blueprint(at)
    res["saved_at"] = unreal.EditorAssetLibrary.save_loaded_asset(at, False)
    # W6, centred (`[OWNER]` «центрируй» · «строчки центрируй» · 2026-10-30 19:48–19:50, after the right-aligned staircase frame): the row
    # PreText · Icon · PostText cannot centre two lines — the icon stands right of PreText's whole box. A line of our own goes into the strip
    # ABOVE the row: T_PromptLine1, centred, the row's font, collapsed by default. The Lua section krinik_ui_fixes moves the part of PreText
    # before a line break into it (the override row «…ресурсы\nили нажмите {0}…» keeps the Russian in the translation). A VerticalBox
    # only appends, so the children from the row on are taken out and put back after the new line with their slot paddings. [NOT-TESTED]
    content = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.Content" % WIDGET)
    tutorial = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.ActionTutorial" % WIDGET)
    tree = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree" % WIDGET)
    if content is None or tutorial is None or tree is None:
        raise RuntimeError("WBP_ContainerInfo Content / ActionTutorial / WidgetTree not found")
    # Tries of 2026-10-30: (1) a plain TextBlock with PreText's font field — cooked, but rendered in another face (the game's GeneralText
    # takes its look from a style asset, text_style_asset_class FS_Text_Heading_6, kit-probe-generaltext.json); (2) a GeneralText — the cook
    # failed: a widget added from Python gets no WidgetVariableNameToGuidMap entry («Widget [T_CorpseLine1] was added but did not get a
    # GUID», WidgetBlueprintCompiler.cpp:781, 89 errors), and neither that map nor bIsVariable is reachable from Python. (3) — this: a plain
    # TextBlock (cooks: bIsVariable false by default) dressed from the style asset's default object. Earlier tries are taken out of the strip.
    for old_name in LINE1_OLD_NAMES + (() if LINE1_ENABLED else (LINE1_NAME,)):
        old = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.%s" % (WIDGET, old_name))
        if old is not None and content.get_child_index(old) >= 0:
            content.remove_child(old)
            res["steps"].append("WBP_ContainerInfo %s removed" % old_name)
    if not LINE1_ENABLED:
        res["steps"].append("line1 disabled")
    elif (unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.%s" % (WIDGET, LINE1_NAME)) is None
          or content.get_child_index(unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.%s" % (WIDGET, LINE1_NAME))) < 0):
        # new, or detached by an earlier run (20:2x) — its GUID stays in the blueprint, so the same object goes back into the strip
        pre = unreal.find_object(None, "%s.W_ActionTutorial:WidgetTree.PreText" % AT_WIDGET)
        line1 = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.%s" % (WIDGET, LINE1_NAME))
        if line1 is None:
            line1 = unreal.new_object(unreal.TextBlock, outer=tree, name=LINE1_NAME)
        style = unreal.get_default_object(pre.get_editor_property("text_style_asset_class"))
        sp = {}
        for n in dir(style):
            if not n.startswith("_"):
                try:
                    sp[n] = style.get_editor_property(n)
                except Exception:
                    pass
        res["style_props"] = {k: str(v)[:200] for k, v in sp.items()}
        for src, dst in (("font", "font"), ("color", "color_and_opacity"), ("shadow_offset", "shadow_offset"),
                         ("shadow_color", "shadow_color_and_opacity"), ("line_height_percentage", "line_height_percentage")):
            if src in sp:
                try:
                    line1.set_editor_property(dst, sp[src])
                    res["steps"].append("line1 %s <- style %s" % (dst, src))
                except Exception as e:
                    res["steps"].append("line1 %s not set: %s" % (dst, e))
        line1.set_editor_property("justification", unreal.TextJustify.CENTER)
        line1.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)
        idx = content.get_child_index(tutorial)
        order = [content.get_child_at(i) for i in range(content.get_children_count())]
        kept = []
        for w in order[idx:]:
            s = w.get_editor_property("slot")
            kept.append((w, s.get_editor_property("padding"), s.get_editor_property("horizontal_alignment"),
                         s.get_editor_property("vertical_alignment")))
            content.remove_child(w)
        s1 = content.add_child_to_vertical_box(line1)
        s1.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_CENTER)
        s1.set_editor_property("padding", unreal.Margin(0.0, 0.0, 0.0, LINE1_GAP))
        for w, pad, ha, va in kept:
            s = content.add_child_to_vertical_box(w)
            s.set_editor_property("padding", pad)
            s.set_editor_property("horizontal_alignment", ha)
            s.set_editor_property("vertical_alignment", va)
    else:
        res["steps"].append("WBP_ContainerInfo %s already present" % LINE1_NAME)
    # The style asset's default object carries only font_data and line_height (run 2026-10-30 20:1x); colour and shadow come from PreText.
    line1 = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.%s" % (WIDGET, LINE1_NAME)) if LINE1_ENABLED else None
    pre = unreal.find_object(None, "%s.W_ActionTutorial:WidgetTree.PreText" % AT_WIDGET)
    style = unreal.get_default_object(pre.get_editor_property("text_style_asset_class"))
    if line1 is not None:
        line1.set_editor_property("font", style.get_editor_property("font_data"))
        line1.set_editor_property("line_height_percentage", style.get_editor_property("line_height"))
        for prop in ("shadow_offset", "shadow_color_and_opacity"):
            line1.set_editor_property(prop, pre.get_editor_property(prop))
        # The row's colour comes from its style, not from PreText's field (that copy drew pure white): the row's ink measured on the 4K frame
        # 2026-10-30 21:22 is sRGB (233, 213, 193) → linear below.
        line1.set_editor_property("color_and_opacity", unreal.SlateColor(specified_color=unreal.LinearColor(*LINE1_LINEAR)))
        f = line1.get_editor_property("font")
        res["steps"].append("line1 font %s size %s" % (f.font_object.get_name() if f.font_object else None, f.size))
    # The dark backing (Border_Underlay) is as wide as its content + the Content slot padding (vanilla 12); its image fades out at the sides,
    # so the two long prompt lines ran into the fade: `[OWNER]` «темную подложку нужно расширить, чтобы края строк покрывало» · 2026-10-30 21:40.
    cslot = content.get_editor_property("slot")
    cp = cslot.get_editor_property("padding")
    before_cp = (cp.left, cp.right)
    cp.left, cp.right = STRIP_SIDE_PAD, STRIP_SIDE_PAD
    cslot.set_editor_property("padding", cp)
    res["steps"].append("Content padding L/R %s -> %s" % (before_cp, (cp.left, cp.right)))
    # Padding alone cannot do it: the brush had no side margins, so the soft gradient of its texture stretched over the whole width and the
    # fade grew with the strip (21:4x: padding 70, the ends still on ≈ 37 % darkness). Nine-slice sides: the fade keeps a fixed width, the dark
    # middle follows the text. ImageSize X/Y are invisible to Python — the brush is logged through its T3D text.
    ub = unreal.find_object(None, "%s.WBP_ContainerInfo:WidgetTree.Border_Underlay" % WIDGET)
    # The game applies the Border's OWN Padding (vanilla 12/12/12/8), not the slot field set above: set_editor_property bypasses the setter
    # that keeps the two in step. Frames 2026-10-30 22:2x: the kit build with slot 140 drew the same box as padding 12 to the pixel (the
    # 21:4x «padding 70 did not help» was this), a live BorderSlot:SetPadding(140) widened it.
    bp_pad = ub.get_editor_property("padding")
    before_bp = (bp_pad.left, bp_pad.right)
    bp_pad.left, bp_pad.right = STRIP_SIDE_PAD, STRIP_SIDE_PAD
    ub.set_editor_property("padding", bp_pad)
    res["steps"].append("Border_Underlay own padding L/R %s -> %s" % (before_bp, (bp_pad.left, bp_pad.right)))
    brush = ub.get_editor_property("background")
    before_bt = brush.export_text()
    m = brush.get_editor_property("margin")
    m.left, m.right = UNDERLAY_SIDE_MARGIN, UNDERLAY_SIDE_MARGIN
    brush.set_editor_property("margin", m)
    ub.set_editor_property("background", brush)
    after_bt = ub.get_editor_property("background").export_text()
    res["steps"].append("Border_Underlay brush %s -> %s" % (before_bt[before_bt.find("ImageSize"):before_bt.find(",ResourceObject")],
                                                            after_bt[after_bt.find("ImageSize"):after_bt.find(",ResourceObject")]))
    # Smaller and a lighter backing (the owner 08:54): a RENDER scale about the centre — the text, the E key and the backing shrink together and the
    # layout (the Lua half's Left while the loot window shows) is untouched; seen live 2026-11-02 10:2x (review folder 59). The alpha multiplies the
    # backing only, the text keeps its own colour. [NOT-TESTED]
    ub.set_editor_property("render_transform", unreal.WidgetTransform(translation=unreal.Vector2D(0, 0), scale=unreal.Vector2D(STRIP_SCALE, STRIP_SCALE),
                                                                     shear=unreal.Vector2D(0, 0), angle=0.0))
    bc = ub.get_editor_property("brush_color")
    ub.set_editor_property("brush_color", unreal.LinearColor(bc.r, bc.g, bc.b, STRIP_BACKING_ALPHA))
    res["steps"].append("Border_Underlay render scale %s, brush colour alpha %s -> %s" % (STRIP_SCALE, bc.a, STRIP_BACKING_ALPHA))
    res["steps"].append("WBP_ContainerInfo Content order: %s" % [content.get_child_at(i).get_name()
                                                                for i in range(content.get_children_count())])
    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    res["saved_line1"] = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)

    # W26 — the build's logo in the menus: `[OWNER]` «нужно в главном меню наш логотип поставить» · «под логотипом оригинальнм - пишем версию
    # игры 3.0.1, под нашим логотипом сборку будет наша версия сборку 1.0.0» · «в меню по ESC наше лого будет слева от оригинального, в главном
    # меню - справа» · «но в игре текст меньше» · 2026-10-30 22:39–22:51. Every number derives from the game's Image_Logo (slot padding, brush
    # ImageSize) and the visible box of its texture; only plain SizeBox / Image / TextBlock are added (a Python-added widget with bIsVariable
    # breaks the cook — see the GeneralText note above) and reused on a re-run, never removed (GUID trap). The FIRST run after adding a widget
    # logs «Widget [X] was added but did not get a GUID» for each and exits 1 — the compiler assigns the GUID right there and the save keeps it;
    # run the script a SECOND time before the build: «Success - 0 error(s)» (2026-10-30 23:00 / 23:02).
    logo_tex = unreal.load_asset(LOGO_TEX)
    style = unreal.get_default_object(pre.get_editor_property("text_style_asset_class"))
    tools = unreal.AssetToolsHelpers.get_asset_tools()

    def placeholder(folder, name, cls, factory_name):
        # an existing asset is reused (a re-run); otherwise created — by the plugin's factory when the kit has one, else bare
        p = "%s/%s" % (folder, name)
        if unreal.EditorAssetLibrary.does_asset_exist(p):
            return unreal.load_asset(p)
        factory = getattr(unreal, factory_name, None)
        a = tools.create_asset(name, folder, cls, factory() if factory else None)
        if a is None:
            raise RuntimeError("placeholder not created: " + p)
        unreal.EditorAssetLibrary.save_loaded_asset(a, False)
        return a

    for wpath, wname, overlay_name, side, max_w, h_share, gap_share in MENUS:
        mbp = unreal.load_asset(wpath)
        if wname == "W_MainMenu_MainMenu":   # bug 71: the backdrop arrays, vanilla order
            movies = [placeholder(MENU_MOVIE_PATH, "TitleScreen_" + m, unreal.BinkMediaPlayer, "BinkMediaPlayerFactoryNew") for m in MENU_MOVIES]
            texes = [placeholder(MENU_MOVIE_TEX_PATH, "TitleScreen_%s_Tex" % m, unreal.BinkMediaTexture, "BinkMediaTextureFactoryNew")
                     for m in MENU_MOVIES]
            mcdo = unreal.get_default_object(mbp.generated_class())
            mcdo.set_editor_property("BackgroundMovies", movies)
            mcdo.set_editor_property("BackgroundMovieTextures", texes)
        mtree = unreal.find_object(None, "%s.%s:WidgetTree" % (wpath, wname))
        ov = unreal.find_object(None, "%s.%s:WidgetTree.%s" % (wpath, wname, overlay_name))
        glogo = unreal.find_object(None, "%s.%s:WidgetTree.Image_Logo" % (wpath, wname))
        gs = glogo.get_editor_property("slot")
        gpad = gs.get_editor_property("padding")
        bt = glogo.get_editor_property("brush").export_text()
        isx, isy = [float(v) for v in bt[bt.find("ImageSize=(X=") + 13:bt.find(")", bt.find("ImageSize="))].split(",Y=")]
        vis_w, vis_h = isx * GAME_VIS[2], isy * GAME_VIS[3]
        vis_l, vis_t, vis_r = isx * GAME_VIS[0], isy * GAME_VIS[1], isx * (1.0 - GAME_VIS[0] - GAME_VIS[2])
        # Ours is laid out by its SOLID box (OUR_VIS): the texture carries a soft shadow above and below the solid logo (frame 23:21 —
        # «1.0.0» stood farther from MOD PACK than «3.0.1» from ENHANCED, the box bottom was the shadow's).
        aspect = logo_tex.blueprint_get_size_x() / logo_tex.blueprint_get_size_y()
        o_vis_h = vis_h * h_share   # [AI] per menu (MENUS): a partner, not a rival
        our_h = o_vis_h / OUR_VIS[3]
        our_w = our_h * aspect
        if max_w and our_w * OUR_VIS[2] > max_w:
            our_w = max_w / OUR_VIS[2]
            our_h, o_vis_h = our_w / aspect, our_w / aspect * OUR_VIS[3]
        o_vis_w = our_w * OUR_VIS[2]
        o_off_l, o_off_t, o_off_r = our_w * OUR_VIS[0], our_h * OUR_VIS[1], our_w * (1.0 - OUR_VIS[0] - OUR_VIS[2])
        gap = vis_h * gap_share
        our_t = gpad.top + vis_t + (vis_h - o_vis_h) / 2.0 - o_off_t
        # each version right under ITS logo, one gap from each SOLID bottom: `[OWNER]` «Версию сборки ближе к лого» · «стараться чтобы отступ
        # был одинаковый от лого в обоих версиях» · «не версии ровнять на одну высоту» · 2026-10-30 23:15
        g_ver_t, o_ver_t = gpad.top + vis_t + vis_h + VERSION_GAP, our_t + o_off_t + o_vis_h + VERSION_GAP
        if side == "right":   # the game's logo is Left-aligned: ours to its right
            halign = unreal.HorizontalAlignment.H_ALIGN_LEFT
            our_pad = unreal.Margin(gpad.left + vis_l + vis_w + gap - o_off_l, our_t, 0.0, 0.0)
            g_text_pad = unreal.Margin(gpad.left + vis_l, g_ver_t, 0.0, 0.0)
            o_text_pad = unreal.Margin(our_pad.left + o_off_l, o_ver_t, 0.0, 0.0)
        else:                 # the game's logo is Right-aligned: ours to its left
            halign = unreal.HorizontalAlignment.H_ALIGN_RIGHT
            our_pad = unreal.Margin(0.0, our_t, gpad.right + vis_r + vis_w + gap - o_off_r, 0.0)
            g_text_pad = unreal.Margin(0.0, g_ver_t, gpad.right + vis_r, 0.0)
            o_text_pad = unreal.Margin(0.0, o_ver_t, our_pad.right + o_off_r, 0.0)

        def box(name, w, h):
            sb = unreal.find_object(None, "%s.%s:WidgetTree.%s" % (wpath, wname, name))
            if sb is None:
                sb = unreal.new_object(unreal.SizeBox, outer=mtree, name=name)
                ov.add_child_to_overlay(sb)
            sb.set_editor_property("width_override", w)
            sb.set_editor_property("override_width_override", True)
            if h:
                sb.set_editor_property("height_override", h)
                sb.set_editor_property("override_height_override", True)
            return sb

        def place(sb, pad):
            s = sb.get_editor_property("slot")
            s.set_editor_property("padding", pad)
            s.set_editor_property("horizontal_alignment", halign)
            s.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_TOP)

        def child(sb, cls, name):
            w = unreal.find_object(None, "%s.%s:WidgetTree.%s" % (wpath, wname, name))
            if w is None:
                w = unreal.new_object(cls, outer=mtree, name=name)
                sb.add_child(w)
            return w

        def version(name, text, width, pad):
            sb = box(name + "Box", width, 0.0)
            place(sb, pad)
            t = child(sb, unreal.TextBlock, name)
            f = style.get_editor_property("font_data")
            f.size = VERSION_FONT_SIZE
            t.set_editor_property("font", f)
            t.set_editor_property("color_and_opacity", unreal.SlateColor(specified_color=unreal.LinearColor(*LINE1_LINEAR)))
            t.set_editor_property("shadow_offset", unreal.Vector2D(1.0, 1.0))
            t.set_editor_property("shadow_color_and_opacity", unreal.LinearColor(0.0, 0.0, 0.0, 0.8))
            t.set_editor_property("justification", unreal.TextJustify.CENTER)
            t.set_editor_property("text", text)

        lb = box("SB_KrinikLogo", our_w, our_h)
        place(lb, our_pad)
        img = child(lb, unreal.Image, "Img_KrinikLogo")
        img.set_brush_from_texture(logo_tex, False)
        version("T_KrinikGameVersion", GAME_VERSION, vis_w, g_text_pad)
        version("T_KrinikPackVersion", PACK_VERSION, o_vis_w, o_text_pad)
        # W37: the «ОТЗЫВ» plate centred under our logo's solid box, under our version line
        fb_tex = unreal.load_asset(FEEDBACK_TEX)
        fb_w = FEEDBACK_H * fb_tex.blueprint_get_size_x() / fb_tex.blueprint_get_size_y()
        fb_t = o_ver_t + FEEDBACK_BELOW_VERSION
        if side == "right":
            fb_pad = unreal.Margin(our_pad.left + o_off_l + (o_vis_w - fb_w) / 2.0, fb_t, 0.0, 0.0)
        else:
            fb_pad = unreal.Margin(0.0, fb_t, our_pad.right + o_off_r + (o_vis_w - fb_w) / 2.0, 0.0)
        # The first build (01:15) had a plain Image: the UserWidget mouse-event hooks never fired (UE4SS log 01:16) — a Button draws its own hover
        # and pressed look, and the click is the Lua section's LMB key bind. The Image stays COLLAPSED: a widget with a GUID is never removed (cook trap).
        fsb = box("SB_KrinikFeedback", fb_w, FEEDBACK_H)
        place(fsb, fb_pad)
        fimg = child(fsb, unreal.Image, "Img_KrinikFeedback")
        fimg.set_brush_from_texture(fb_tex, False)
        fsb.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)
        bsb = box("SB_KrinikFeedbackBtn", fb_w, FEEDBACK_H)
        place(bsb, fb_pad)
        btn = child(bsb, unreal.Button, "Btn_KrinikFeedback")
        bstyle = btn.get_editor_property("widget_style")
        for prop, tex_path in (("normal", FEEDBACK_TEX), ("hovered", FEEDBACK_TEX + "Hover"), ("pressed", FEEDBACK_TEX + "Hover")):
            br = unreal.SlateBrush()
            br.set_editor_property("resource_object", unreal.load_asset(tex_path))
            br.set_editor_property("draw_as", unreal.SlateBrushDrawType.IMAGE)
            bstyle.set_editor_property(prop, br)
        bstyle.set_editor_property("normal_padding", unreal.Margin(0.0, 0.0, 0.0, 0.0))
        bstyle.set_editor_property("pressed_padding", unreal.Margin(0.0, 0.0, 0.0, 0.0))
        btn.set_editor_property("widget_style", bstyle)
        res["steps"].append("%s: feedback %.0fx%.0f at %s" % (wname, fb_w, FEEDBACK_H, (fb_pad.left, fb_pad.top, fb_pad.right)))
        unreal.BlueprintEditorLibrary.compile_blueprint(mbp)
        if wname == "W_MainMenu_MainMenu":   # bug 71: read the arrays back AFTER the compile — the save keeps what stands here
            mcdo = unreal.get_default_object(mbp.generated_class())
            res["menu_backdrop"] = {k: [o.get_path_name() if o else None for o in mcdo.get_editor_property(k)]
                                    for k in ("BackgroundMovies", "BackgroundMovieTextures")}
        res["saved_" + wname] = unreal.EditorAssetLibrary.save_loaded_asset(mbp, False)
        res["steps"].append("%s: game logo %s pad %s; ours %.0fx%.0f at %s (%s); versions under both" % (
            wname, (isx, isy), (gpad.left, gpad.top, gpad.right), our_w, our_h, (our_pad.left, our_pad.top, our_pad.right), side))
    res["ok"] = bool(res["saved"]) and bool(res["saved_ql"]) and bool(res["saved_tt"]) and bool(res["saved_perk"]) and bool(res["saved_at"])
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
