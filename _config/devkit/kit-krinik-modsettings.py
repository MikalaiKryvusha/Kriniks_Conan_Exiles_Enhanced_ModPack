# kit-krinik-modsettings.py — the «Моды Krinik'а» mod-settings hub, SKELETON: a native module window of our own in the KrinikConanUI kit pak
# (KUMM plan 38 phase 0, route 2026-10-31 19:11: researches/conan-mod-settings-hub/mod-ui-module-registration.md §5).
#   Local/W_KrinikModSettings — a Widget Blueprint whose parent is the game's native WindowRoot (as the three mod settings windows of the build:
#                               Damage Meter, Hosav, fishing); in ITS OWN WidgetTree: the game's settings heading (WBP_Settings_Subheader), ONE
#                               game settings row WBP_Setting_Checkbox, the game's WBP_ButtonBase «Закрыть» with KeyShortcutName Escape.
#   Local/DT_KrinikUIModule   — a module table (row struct UIModuleTableRow), ONE row KrinikModSettings = the fishing settings row's values
#                               (ExilesFishingTuning: Modal, CloseOnESC, CloseOnEndPlay, ZOrder 100) with WidgetClass → our window.
# The table reaches the game's DT_UIModuleTable by a merge at runtime (Lua section krinik_mod_settings → ModController.MergeDataTables).
# Why a kit window: a WBP_Setting_Checkbox created from Lua (outer = GameInstance) never took a real click — S6/S11 of KUMM
# testcases/TC_conan_settings_hub_spike_2026-10-30.md; 48 of 49 live FLX buttons that click live in some window's WidgetTree.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Run it TWICE before a build: the first run after adding widgets logs «Widget [X] was added but did not get a GUID» and exits 1; the compile
# assigns the GUIDs and the save keeps them (kit-conanui-edit.py, W26 note). Widgets are reused on a re-run, never removed (cook GUID trap).
# Writes kit-krinik-modsettings.json next to this file (steps, the probed property names of the game widgets, the table's columns).
# [TESTED: 2026-10-31 · runs 3-4 (0 errors on the second), cooked, the window and its checkbox live in game · KUMM testcases/reports/2026-10-31_conan-hub-kit-window.md]
#
# PHASE 2 (KUMM plans/38_epic38_phase2_krinik_hub_window.md, step 4): the window by the APPROVED mockup 5 (`[OWNER]` «макет одобрен» · 2026-10-31 19:09;
# pack _config/settings_hub/mockups/mockups.html?v=5, review folder 34): a head (title + «Закрыть без сохранения» top right, 19:06), a body (left — the
# mods' names in clipped horizontal scroll boxes for the marquee, 19:02; right — the selected mod's name and note, a WidgetSwitcher with ONE page per mod,
# a row = our label + an «i» (19:03) + a grey hint + the game's control with an empty label), a footer («Сбросить к исходным» left, «Сохранить» and
# «Сохранить и закрыть» right, 19:06) and the «i» plate (collapsed, over the canvas). The kit places widgets only: every text, the slider ranges and the
# selection colours are set by the Lua section krinik_mod_settings from ONE table — a wording change needs no kit rebuild.
# The phase-0 widgets are reused, never removed: Chk_KrinikFps — the FPS row's control; B_KrinikClose — «Закрыть без сохранения»; Hdr_KrinikTitle and
# Sp_KrinikFill — collapsed. [TESTED: 2026-10-31 · two runs, 0 errors, cooked, the tree seen in game by mockup 5 · KUMM testcases/reports/2026-10-31_conan-hub-phase2-first-batch.md]
# THE FIDELITY PASS (2026-11-01, constants block below): [TESTED: 2026-11-01 · runs 3–8 exit 0, 0 GUID errors, cooked, P1–P11 and F1–F10 in the live
# game · KUMM testcases/reports/2026-11-01_conan-hub-mockup-fidelity.md]
import json
import os
import traceback

import unreal

PKG = "/Game/Mods/KrinikConanUI"          # → kit UE4/Content/Mods/KrinikConanUI/Local/ (import-logo-texture.py, 2026-10-30 22:57)
WIN = "W_KrinikModSettings"
DT = "DT_KrinikUIModule"
ROW = "KrinikModSettings"
WIN_CLASS = "%s/%s.%s_C" % (PKG, WIN, WIN)
TITLE = "Моды Krinik'а · Настройки"      # `[OWNER]` the title form «Моды Krinik'а» · 2026-10-31 19:10
ROW_LABEL = "Счётчик кадров в углу экрана"
CLOSE_LABEL = "Закрыть"
CHECKBOX = "/Game/UI/Widgets/MainMenu/Settings/WBP_Setting_Checkbox.WBP_Setting_Checkbox_C"
SUBHEADER = "/Game/UI/Widgets/MainMenu/Settings/WBP_Settings_Subheader.WBP_Settings_Subheader_C"
BUTTON = "/Game/UI/Widgets/Buttons/WBP_ButtonBase.WBP_ButtonBase_C"
BG_TEX = "/Game/UI/Textures/Backgrounds/T_UI_GeneralWindow_Background"         # the fishing panel's frame textures (recon §3)
BORDER_TEX = "/Game/UI/Textures/Widgets/GeneralWindow/T_UI_GeneralWindow_Border"
SLIDER = "/Game/UI/Framework/W_EditableLabeledSlider.W_EditableLabeledSlider_C"     # the game's sound-settings slider (probe W_Settings_Audio, 2026-10-31)
# Mockup 5 measured on its 4K frame (variant_05_final.webp, 1920-wide CSS screen ×2): the window 1315 × 894 units at 1080p, the head 99, the list 313 wide,
# the footer 88. Units are the game's canvas units — the game's DPI curve scales them (house rule 17; at 4K the viewport scale is 2.094, the canvas 1834 wide).
# The look pass of 2026-10-31 22:0x (`[OWNER]` 21:41 «хаб настроек модов какой-то огромный» · «кривые кнопки инфо» · «большие расстояния между опциями» ·
# «странный жирный шрифт» · «некрасивый поп-ап при ховере»; seams — KUMM testcases/TC_conan_hub_look_2026-10-31.md): the width fits the widest row (the
# «Сколько лежит кровь на земле» row, 487 units of text, measured live), the HEIGHT is left to the content — the Lua section sets it to the tallest live page.
WIN_W = 1240.0
# THE FIDELITY PASS (2026-11-01, `[OWNER]` «из этого кадра явно видно, что макет красивый, а реализация в игре - нет» · 04:40; cases KUMM
# testcases/TC_conan_hub_mockup_fidelity_2026-11-01.md P1–P11). Every number below is mockup 5's CSS ×2 (its 960 screen → 1080p) × K = 1240 / 1315
# (the window here vs the mockup's 1315 units — the size the owner already accepted); colours are the CSS sRGB → LINEAR ((c/255)^2.2, EXP-0415).
K = 1240.0 / 1315.0
def u(css_px):
    return round(css_px * 2.0 * K, 1)
CONTENT_PAD_X, CONTENT_PAD_Y = u(20), u(16)
LIST_W = 290.0                            # the left list: every name but «KrinikConanModPackManager» (364) fits whole
NAME_W = 258.0                            # a mod name's clip box (= the Lua section's NAME_BOX); a longer name slides (the marquee)
CONTROL_SLIDER_W = 290.0                  # (the game slider's box, collapsed since the fidelity pass)
CONTROL_CHECK_W = 120.0
CONTROL_H = 48.0
ROW_H = u(20)                             # .row height 20
SLIDER_W, SLIDER_GAP, VALUE_W = 180.0, u(10), 76.0        # .slider 120 / .val 44 of the mockup, cut to the real widest row (≈ 800 units in a 833 column)
SLIDER_BAR, THUMB_W, THUMB_H = u(2), u(4), u(10)          # track 2, thumb 4×10
CHECK_D, CHECK_INSET, CHECK_RIGHT = u(12), u(2), u(32)    # .check 12, ::after inset 2, margin-right 32
BTN_H, BTN_PAD = u(22), u(12)             # .btn height 22, padding 0 12
ITEM_PAD_Y, ITEM_PAD_X, ITEM_BAR = u(5), u(8), u(2)       # .toc div 26 high (text ≈ 16), padding 0 8, inset 2 px bar
ROW_GAP = 0.0
# mockup 8–9 (2026-11-02): .sw / .key 120 × 18, padding 0 4, the swatch 26 × 10 with a .5 light rim, gap 6; the nine follower swatches share the box
# (gap 2); the palette .pal 236 wide, padding 10 12, a grid of 8 × 2 swatches 22 × 16 with gap 5, «было → станет» swatches 40 × 14
SW_BOX_W, SW_BOX_H, SW_PAD, SW_W, SW_H, SW_GAP, SW_GAP9, SW_RIGHT = u(120), u(18), u(4), u(26), u(10), u(6), u(2), 0.0
PAL_PAD_X, PAL_PAD_Y, PAL_SW_W, PAL_SW_H, PAL_GAP, PAL_CMP_W, PAL_CMP_H, PAL_SEL = u(12), u(10), u(22), u(16), u(5), u(40), u(14), u(2)
PAL_COLOURS = 16
PAL_RECT_W, PAL_RECT_H, PAL_MARK = u(212), u(106), u(6)    # the colour rectangle (2:1 like its texture) and its click mark (owner 2026-11-02 08:45)
RULE = 2.0                                # 1 px of the 960 screen
TIP_W = u(250) - 2 * u(12)                # .pop width 250, padding 12
# The font: the GAME's own PT Serif (`/Game/UI/Fonts/PT_Serif/PTSerif-Regular_Font`, cooked in pakchunk1110 of 3.0.1 — `retoc list`, 2026-11-01) — a serif
# WITH Cyrillic, as mockup 5's Cambria / Georgia; Cardo and Crimson Pro have none (EXP-0415), and the 10-31 probe listed only fonts LOADED in the world, so
# PT Serif was missed. Only the Regular face exists: «bold» (the title, the values) is the same face with a 1-unit outline in the text colour.
# An import of our own TTF is impossible here: the font factory asserts on a missing SlateApplication in UnrealEditor-Cmd (2026-11-01, both with and
# without -NullRHI).
FONT_SERIF = "/Game/UI/Fonts/PT_Serif/PTSerif-Regular_Font"
FONT_SANS = "/Game/Fonts/NotoSans"
FACE, FACE_BOLD = "Normal", "Bold"        # the sans fallback's faces; for the serif both become its one typeface (read from the font at run)
FAUX_BOLD = 1                             # outline size of the «bold» serif text
# Text: the mockup's RATIOS at the 10-31 label size 19 — the mockup's own 21.7 overflowed the real rows (longer labels and hints than its sample: «2125»
# cut to «212», the side-offset slider pushed out — frame 2026-11-01 05:10) and made every mod name a marquee
TS = 19.0 / 11.5
def t(css_px):
    return round(css_px * TS, 1)
SIZE_TITLE, SIZE_NAME, SIZE_MOD_TITLE, SIZE_LABEL, SIZE_SMALL, SIZE_INFO, SIZE_TIP_TITLE, SIZE_TIP = t(17), t(11.5), t(12.5), t(11.5), t(10), t(8.5), t(11), t(10.5)
SIZE_VALUE, SIZE_BTN, SIZE_NOTE = t(11.5), t(11.5), t(9.5)
SPACING_TITLE, SPACING_TIP = 80, 80       # letter-spacing .08em (UE: 1/1000 em)
INFO_D = u(12)                            # the «i» circle 12
def lin(r, g, b, a=1.0):
    return tuple([round((c / 255.0) ** 2.2, 4) for c in (r, g, b)] + [a])
PANEL = lin(30, 31, 33, 0.94)             # .panel background
LIGHT = (200, 196, 186)                   # every thin rim and rule — rgba(200,196,186,α)
FRAME_RIM = lin(*LIGHT, a=0.38)
RULE_C, RULE_LIST = lin(*LIGHT, a=0.22), lin(*LIGHT, a=0.16)
TEXT = lin(217, 214, 207)                 # #d9d6cf
BRIGHT = lin(236, 232, 223)               # #ece8df — the title, the values
DOT = lin(154, 150, 141)                  # #9a968d — the title's «·»
GREY = lin(142, 138, 130)                 # #8e8a82 — hints, the mod note, the «i» rim
TOC = lin(181, 177, 168)                  # #b5b1a8 — a mod name
TRACK = lin(109, 106, 100)                # #6d6a64 — the slider track
THUMB = lin(232, 228, 218)                # #e8e4da — the thumb, the checkbox's inner square
CHECK_RIM = lin(189, 185, 176)            # #bdb9b0 — the checkbox rim, the «i» letter
DARK = lin(24, 25, 26)                    # #18191a — buttons, the selected mod
BTN_RIM = lin(*LIGHT, a=0.18)
BTN_TEXT = lin(230, 226, 216)             # #e6e2d8
PLATE = lin(18, 19, 20, 1.0)              # .pop background — OPAQUE: at the mockup's .98 a dark-red swatch under the option list drew as a black block
                                          # (run R5 2026-11-02 10:21; the live alpha 1 removed it, a green swatch never showed it)
RIM = lin(*LIGHT, a=0.45)                 # .pop rim (light, not gold — the mockup)
SW_RIM = lin(232, 228, 218, 0.5)          # mockup 8 .sw i — a swatch's thin rim
BUSY_RIM, BUSY_TEXT = lin(215, 154, 138, 0.6), lin(227, 178, 165)     # mockup 9 .refuse — the busy-key plate
# The pages and their rows — ids only; labels, «i» texts and ranges live in the Lua section (krinik_mod_settings.lua, SETTINGS).
# Row order inside a page = the mockup's order. Inventory: KUMM researches/conan-mod-settings-hub/krinik-settings-inventory.md (A*, C*).
PAGES = [
    ("cam", [("cam_height", "slider"), ("cam_side", "slider"), ("cam_dist", "slider"), ("cam_pitch", "slider"),
             ("cam_zoom_min", "slider"), ("cam_zoom_max", "slider"), ("cam_sharp", "check"), ("cam_zoom_smooth", "slider")]),
    ("ui", [("ui_fps", "check"), ("ui_blink_food", "slider"), ("ui_blink_weight", "slider"), ("ui_menu_slow", "slider"), ("ui_craft", "check"),
            ("ui_shout_hold", "slider"), ("ui_vig_hunger", "slider"), ("ui_vig_thirst", "slider"),
            ("ui_vig_health", "slider"), ("ui_pickup_x", "slider"), ("ui_pickup_y", "slider"), ("ui_strip_x", "slider"), ("ui_strip_y", "slider"), ("ui_strip_scale", "slider"), ("ui_strip_back", "slider")]),
    ("arc", [("arc_ballistics", "check"), ("arc_nobreak", "check"), ("arc_fov", "slider"), ("arc_stuck_min", "slider"), ("arc_ammo_list", "check")]),
    ("mpm", [("mpm_hud_scale", "slider")]),
    ("gfx", [("gfx_blood", "slider")]),
    # The Xevyr hub (plan 40.3 I6.1; the same window, `hub` in the Lua PAGES), pages in the mockup's order (alphabetical) — the Lua PAGES order is the
    # SAME (the page switcher's index). The slider and check rows of recon §1–§5 in the authors' order; dropdown, colour and key rows come with the new
    # row kinds of I6.2. A page is hidden in game until its adapter (I6.3) read the mod. [TESTED: 2026-11-02 · X1–X8 in the live game, real clicks, the mods read back · KUMM testcases/reports/2026-11-02_conan-hub-xevyr-four-pages.md]
    ("amr", [("amr_enabled", "check"), ("amr_corpse", "check"), ("amr_nofatality", "check"), ("amr_katana", "check"), ("amr_explosives", "check"),
             ("amr_ram", "check"), ("amr_gold", "slider"), ("amr_field", "slider"), ("amr_archer", "slider"), ("amr_battlement", "slider"),
             ("amr_bailey", "slider"), ("amr_counter_cd", "slider"), ("amr_counter_size", "slider")]),
    ("llh", [("llh_lore", "check"), ("llh_lore_color", "color"), ("llh_loot", "check"), ("llh_loot_color", "color"), ("llh_intensity", "slider")]),
    ("prp", [("prp_enabled", "check"), ("prp_scale", "slider"), ("prp_radius", "slider"), ("prp_max", "slider")]),
    ("sm", [("sm_color", "color"), ("sm_rotate", "check"), ("sm_coords", "check"), ("sm_scale", "slider"), ("sm_markers", "slider"),
            ("sm_time", "drop"), ("sm_guild", "check"), ("sm_journey", "check"), ("sm_key", "key")]),
    # the colour and key rows (I6.2, 2026-11-02) stand in the author's order; keep_order puts the reused rows around them on the second pass
    ("dm", [("dm_scale", "slider"), ("dm_theme", "color"), ("dm_opacity", "slider"), ("dm_corner", "drop"), ("dm_reset_confirm", "check"), ("dm_timestamp", "check"),
            ("dm_float_player", "check"), ("dm_float_tracked", "check"), ("dm_player_color", "color"), ("dm_followers", "color9"),
            ("dm_refresh", "slider"), ("dm_segment", "slider"), ("dm_key", "key")]),
]
REUSED_CONTROL = {"ui_fps": "Chk_KrinikFps"}   # the phase-0 checkbox (its GUID kept)
# The fishing settings row ExilesFishingTuning (recon §2, DT_Fishing_UIModule.rows.txt); ZOrder 101 — over the fishing panel's 100 and the hub
ROW_VALUES = {
    "WidgetClass": WIN_CLASS,
    "ToggleActionName": "None",
    "BlocksToggleActions": False,
    "MustBeBasePlayerChar": False,
    "CloseOnShortcutRelease": False,
    "CloseOnESC": True,
    "CloseOnEndPlay": True,
    "PreloadOnStartup": False,
    "NonBlockingLoad": False,
    "IsPersistent": False,
    "Category": "Modal",
    "FullscreenGUIAction": "None",
    "ZOrder": 101,
    # False as the vanilla InventorySettingsPopup: with True the window VANISHED after ≈ 2 min without input — the game's idle «vanity» camera hides
    # such modules (seen 2026-10-31 21:58:24; GUIModuleController:EnableVanityCameraMode(false) brought it back)
    "bHiddenDuringVanityMode": False,
    "bHiddenDuringEmotes": False,
    "bForceHideShortcutBar": False,
    "HiddenByPopups": False,
    "ForceHideModules": [],
    "AutoshownInStates": [],
    "ShowInStartupState": False,
    "ShowInMainMenuState": False,
    "ShowInLoadingScreenState": False,
    "ShowInPlayingState": True,
    "ShowInCharacterCreationState": False,
    "ShowWhenDead": False,
    "ShowSelect": False,
    "ShowBack": False,
    "ShowQuickMove": False,
    "OtherHotkeys": [],
    "DisableShortcutWhenPlayerInputBlocked": False,
    "TieToBasePlayerCharInput": False,
}
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-krinik-modsettings.json")

res = {"ok": False, "steps": [], "probe": {}}
tools = unreal.AssetToolsHelpers.get_asset_tools()
lib = unreal.EditorAssetLibrary


def step(s):
    res["steps"].append(s)


def members(obj, base_cls):
    # names Python sees on obj that its base class does not have — how the kit names a game widget's own properties
    base = set(dir(base_cls))
    return sorted(n for n in dir(obj) if not n.startswith("_") and n not in base)


def try_set(obj, prop, value, tag):
    try:
        obj.set_editor_property(prop, value)
        step("%s.%s = %s" % (tag, prop, str(obj.get_editor_property(prop))[:120]))
        return True
    except Exception as e:
        step("%s.%s NOT set: %s" % (tag, prop, str(e)[:200]))
        return False


try:
    # ---- 1. the window: Widget Blueprint, parent WindowRoot -------------------------------------------------------------------------
    wr = unreal.load_class(None, "/Script/ConanSandbox.WindowRoot")
    if wr is None:
        raise RuntimeError("native class WindowRoot not found")
    wpath = "%s/%s" % (PKG, WIN)
    # This kit's Python reaches neither WidgetTree.RootWidget nor the factory's root class (run 1, 2026-10-31 19:18): a new blueprint takes
    # its root from the UMG editor settings' default root widget class — set on the settings CDO to CanvasPanel for this session only (no
    # config write; the class is not wrapped by name, only by load_class; run 3 got the root CanvasPanel_0).
    res["probe"]["unreal_names"] = [n for n in dir(unreal) if ("UMG" in n and "Setting" in n) or "RootWidget" in n]
    try:
        ues = unreal.get_default_object(unreal.load_class(None, "/Script/UMGEditor.UMGEditorProjectSettings"))
        res["probe"]["umg_settings_root_props"] = [n for n in dir(ues) if "root" in n.lower()]
        for prop in ("default_root_widget", "DefaultRootWidget"):
            try:
                ues.set_editor_property(prop, unreal.CanvasPanel)
                step("UMGEditorProjectSettings.%s = %s" % (prop, ues.get_editor_property(prop)))
                break
            except Exception as e:
                step("UMGEditorProjectSettings.%s not set: %s" % (prop, str(e)[:160]))
    except Exception as e:
        step("UMGEditorProjectSettings not reachable: %s" % str(e)[:200])

    def find(name):
        return unreal.find_object(None, "%s.%s:WidgetTree.%s" % (wpath, WIN, name))

    def root_of():
        # the root = a canvas of the tree with no parent panel (RootWidget itself is not visible to Python)
        t = unreal.find_object(None, "%s.%s:WidgetTree" % (wpath, WIN))
        for n in ("CanvasPanel_0", "CanvasPanel_1", "RootCanvas", "CanvasPanel", "Canvas_KrinikRoot"):
            w = find(n)
            if w is not None and w.get_parent() is None:
                return t, w
        return t, None

    bp = unreal.load_asset(wpath) if lib.does_asset_exist(wpath) else None
    if bp is not None and root_of()[1] is None:
        step("existing window has no root - deleted: %s" % lib.delete_asset(wpath))
        bp = None
    if bp is None:
        f = unreal.WidgetBlueprintFactory()
        res["probe"]["factory"] = [n for n in dir(f) if not n.startswith("_") and n not in dir(unreal.Factory)]
        f.set_editor_property("parent_class", wr)
        bp = tools.create_asset(WIN, PKG, unreal.WidgetBlueprint, f)
        if bp is None:
            raise RuntimeError("window blueprint not created")
        step("window created " + bp.get_path_name())
    else:
        step("window reused " + bp.get_path_name())
    tree, root = root_of()
    if tree is None:
        raise RuntimeError("WidgetTree not found")
    res["probe"]["tree"] = [n for n in dir(tree) if not n.startswith("_") and n not in dir(unreal.Object)]
    step("root widget: %s" % (root.get_path_name() if root else None))
    if root is None:
        raise RuntimeError("the new window has no root panel")

    def widget(cls, name, parent, add):
        # reuse by name (GUID kept), else create in OUR tree and attach
        w = find(name)
        if w is None:
            w = unreal.new_object(cls, outer=tree, name=name)
            step("new %s %s" % (getattr(cls, "__name__", str(cls)), name))
        if w.get_parent() != parent:
            add(w)
        return w, w.get_editor_property("slot")

    frame, cslot = widget(unreal.SizeBox, "SB_KrinikWindow", root, root.add_child_to_canvas)
    cslot.set_anchors(unreal.Anchors(minimum=unreal.Vector2D(0.5, 0.5), maximum=unreal.Vector2D(0.5, 0.5)))
    cslot.set_alignment(unreal.Vector2D(0.5, 0.5))
    cslot.set_position(unreal.Vector2D(0.0, 0.0))
    cslot.set_auto_size(True)             # the window takes its content's size (seam S1); the Lua section fixes the height to the tallest live page
    frame.set_editor_property("width_override", WIN_W)
    frame.set_editor_property("override_width_override", True)
    frame.set_editor_property("override_height_override", False)
    def flat(rgba):
        # a solid brush: no texture, the colour in the tint (P1)
        b = unreal.SlateBrush()
        b.set_editor_property("draw_as", unreal.SlateBrushDrawType.IMAGE)
        b.set_editor_property("tint_color", unreal.SlateColor(unreal.LinearColor(*rgba)))
        return b

    def rimmed(fill, rim, width=RULE, radius=None):
        # a box with a thin outline (UE5 rounded box; FIXED_RADIUS 0 = square corners): the frame, the buttons, the checkbox, the plate
        b = unreal.SlateBrush()
        b.set_editor_property("draw_as", unreal.SlateBrushDrawType.ROUNDED_BOX)
        o = unreal.SlateBrushOutlineSettings()
        o.set_editor_property("color", unreal.SlateColor(unreal.LinearColor(*rim)))
        o.set_editor_property("width", width)
        if radius == "half":
            o.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.HALF_HEIGHT_RADIUS)
        else:
            o.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.FIXED_RADIUS)
            o.set_editor_property("corner_radii", unreal.Vector4(0.0, 0.0, 0.0, 0.0))
        b.set_editor_property("outline_settings", o)
        b.set_editor_property("tint_color", unreal.SlateColor(unreal.LinearColor(*fill)))
        return b

    ov, _ = widget(unreal.Overlay, "OV_KrinikFrame", frame, frame.add_child)
    bg, bslot = widget(unreal.Image, "Img_KrinikBackground", ov, ov.add_child_to_overlay)
    bg.set_editor_property("brush", flat(PANEL))          # was the game's blue-grey window texture (P1)
    bslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    bslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    bd, bdslot = widget(unreal.Image, "Img_KrinikBorder", ov, ov.add_child_to_overlay)
    bd.set_editor_property("brush", rimmed((0, 0, 0, 0), FRAME_RIM))
    bdslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    bdslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    vb, vslot = widget(unreal.VerticalBox, "VB_KrinikContent", ov, ov.add_child_to_overlay)
    vslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    vslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    vslot.set_editor_property("padding", unreal.Margin(CONTENT_PAD_X, CONTENT_PAD_Y, CONTENT_PAD_X, u(12)))

    H_FILL, V_FILL = unreal.HorizontalAlignment.H_ALIGN_FILL, unreal.VerticalAlignment.V_ALIGN_FILL
    V_CENTER, H_RIGHT = unreal.VerticalAlignment.V_ALIGN_CENTER, unreal.HorizontalAlignment.H_ALIGN_RIGHT
    COLLAPSED, VISIBLE = unreal.SlateVisibility.COLLAPSED, unreal.SlateVisibility.VISIBLE
    FILL, AUTO = unreal.SlateChildSize(1.0, unreal.SlateSizeRule.FILL), unreal.SlateChildSize(1.0, unreal.SlateSizeRule.AUTOMATIC)

    font_obj = unreal.load_asset(FONT_SERIF)
    serif = font_obj is not None
    res["font"] = FONT_SERIF if serif else FONT_SANS
    if serif:
        try:
            ent = list(font_obj.get_editor_property("composite_font").get_editor_property("default_typeface").get_editor_property("fonts"))
            faces = [str(e.get_editor_property("name")) for e in ent]
        except Exception as e:
            faces = []
            step("serif typefaces unreadable: %s" % str(e)[:160])
        res["serif_faces"] = faces
        # Python sees no typeface entries of this font (an empty list, 2026-11-01); an EMPTY name is the engine's «the first entry» (FSlateFontInfo)
        FACE = FACE_BOLD = faces[0] if faces else ""
    else:
        font_obj = unreal.load_asset(FONT_SANS)
    step("font %s: %s, faces %s / %s" % (res["font"], font_obj is not None, FACE, FACE_BOLD))
    if font_obj is None:
        raise RuntimeError("no font")

    # the «i» glyph: the game's Noto Sans Bold, upright — variant 5 of eight shown in game on one frame (`[OWNER]` «(i) - 5» · 2026-11-01 09:13, review folder
    # 42_hub_knopka_i_i_vysota; the serif «i» thickened by an outline was «все еще некрасивая», 08:43)
    # [TESTED: 2026-11-01 · the rebuilt pak in game, all eight camera rows show the sans-bold «i» · KUMM testcases/reports/2026-11-01_conan-hub-height-info-dimming.md]
    info_font = unreal.load_asset(FONT_SANS)

    def text(name, parent, add, size, bold=False, grey=False, color=None, spacing=0, sans_bold=False):
        t, slot = widget(unreal.TextBlock, name, parent, add)
        if sans_bold and info_font is not None:
            fi = unreal.SlateFontInfo(font_object=info_font, typeface_font_name="Bold", size=size)
        else:
            fi = unreal.SlateFontInfo(font_object=font_obj, typeface_font_name=FACE_BOLD if bold else FACE, size=size)
        if bold and serif and not sans_bold:
            try:
                os_ = unreal.FontOutlineSettings()
                os_.set_editor_property("outline_size", FAUX_BOLD)
                os_.set_editor_property("outline_color", unreal.LinearColor(*(color or TEXT)))
                fi.set_editor_property("outline_settings", os_)
            except Exception as e:
                step("%s faux bold NOT set: %s" % (name, str(e)[:120]))
        if spacing:
            try:
                fi.set_editor_property("letter_spacing", spacing)
            except Exception as e:
                step("%s letter_spacing NOT set: %s" % (name, str(e)[:120]))
        t.set_editor_property("font", fi)
        t.set_editor_property("color_and_opacity", unreal.SlateColor(unreal.LinearColor(*(color or (GREY if grey else TEXT)))))
        return t, slot

    def rule(name, parent, add, vertical=False, rgba=RULE_C):
        # a thin line: an Image inside a SizeBox of RULE thickness (the brush's image_size is a DeprecateSlateVector2D in this kit — Python's
        # Vector2D does not convert, run 2026-10-31 20:33)
        box, slot = widget(unreal.SizeBox, name + "_Box", parent, add)
        box.set_editor_property("width_override" if vertical else "height_override", RULE)
        box.set_editor_property("override_width_override" if vertical else "override_height_override", True)
        img, _ = widget(unreal.Image, name, box, box.add_child)
        img.set_editor_property("color_and_opacity", unreal.LinearColor(*rgba))
        return img, slot

    def sized(name, parent, add, w=None, h=None):
        box, slot = widget(unreal.SizeBox, name, parent, add)
        if w is not None:
            box.set_editor_property("width_override", w)
            box.set_editor_property("override_width_override", True)
        if h is not None:
            box.set_editor_property("height_override", h)
            box.set_editor_property("override_height_override", True)
        return box, slot

    def flat_button(key, parent, add):
        # mockup .btn: a flat dark box with a thin light rim and light text, no key glyph (P9); the click — the Lua LMB route (IsHovered)
        b, slot = border("Brd_KrinikBtn_" + key, parent, add)
        b.set_editor_property("background", rimmed(DARK, BTN_RIM))
        b.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
        b.set_editor_property("padding", unreal.Margin(BTN_PAD, 0, BTN_PAD, 0))
        b.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_CENTER)
        b.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
        box, _ = sized("SB_KrinikBtn_" + key, b, b.add_child, h=BTN_H)
        t, ts = text("Txt_KrinikBtn_" + key, box, box.add_child, SIZE_BTN, color=BTN_TEXT)
        ts.set_editor_property("vertical_alignment", V_CENTER)
        return b, slot

    def border(name, parent, add, rgba=(0, 0, 0, 0)):
        b, slot = widget(unreal.Border, name, parent, add)
        b.set_editor_property("brush_color", unreal.LinearColor(*rgba))
        b.set_editor_property("visibility", VISIBLE)       # hit-testable: the Lua LMB route asks IsHovered()
        return b, slot

    btn_cls = unreal.load_class(None, BUTTON)
    chk_cls = unreal.load_class(None, CHECKBOX)
    sld_cls = unreal.load_class(None, SLIDER)

    def game_button(name, parent, add):
        btn, slot = widget(btn_cls, name, parent, add)
        res["probe"]["button"] = members(btn, unreal.UserWidget)
        return btn, slot

    # the phase-0 heading and filler stay in the tree, collapsed (GUID trap: never removed)
    hdr_cls = unreal.load_class(None, SUBHEADER)
    hdr, _ = widget(hdr_cls, "Hdr_KrinikTitle", vb, vb.add_child_to_vertical_box)
    hdr.set_editor_property("visibility", COLLAPSED)
    sp, _ = widget(unreal.Spacer, "Sp_KrinikFill", vb, vb.add_child_to_vertical_box)
    sp.set_editor_property("visibility", COLLAPSED)

    # ---- head: the title + «Закрыть без сохранения» -----------------------------------------------------------------------------
    head, hs = widget(unreal.HorizontalBox, "HB_KrinikHead", vb, vb.add_child_to_vertical_box)
    # mockup .title: «<b>Моды Krinik'а</b><i>·</i>Настройки», caps, .08em; the dot grey with 8 px each side (P3)
    title, ts = text("Txt_KrinikTitle", head, head.add_child_to_horizontal_box, SIZE_TITLE, bold=True, color=BRIGHT, spacing=SPACING_TITLE)
    ts.set_editor_property("size", AUTO)
    ts.set_editor_property("vertical_alignment", V_CENTER)
    tdot, tds = text("Txt_KrinikTitleDot", head, head.add_child_to_horizontal_box, SIZE_TITLE, color=DOT)
    tds.set_editor_property("vertical_alignment", V_CENTER)
    tds.set_editor_property("padding", unreal.Margin(u(8), 0, u(8), 0))
    tsub, tss = text("Txt_KrinikTitleSub", head, head.add_child_to_horizontal_box, SIZE_TITLE, color=BRIGHT, spacing=SPACING_TITLE)
    tss.set_editor_property("size", FILL)
    tss.set_editor_property("vertical_alignment", V_CENTER)
    close, cs = game_button("B_KrinikClose", head, head.add_child_to_horizontal_box)
    try_set(close, "key_shortcut_name", unreal.Name("Escape"), "B_KrinikClose")
    close.set_editor_property("visibility", COLLAPSED)     # the game's textured button → the mockup's flat one (P9)
    fclose, fcs = flat_button("Close", head, head.add_child_to_horizontal_box)
    fcs.set_editor_property("vertical_alignment", V_CENTER)
    r1, r1s = rule("Img_KrinikRuleTop", vb, vb.add_child_to_vertical_box)
    r1s.set_editor_property("padding", unreal.Margin(0, u(9), 0, u(10)))

    # ---- body: the list | the selected mod's page -------------------------------------------------------------------------------
    body, bs = widget(unreal.HorizontalBox, "HB_KrinikBody", vb, vb.add_child_to_vertical_box)
    bs.set_editor_property("size", FILL)
    lbox, lbs = widget(unreal.SizeBox, "SB_KrinikList", body, body.add_child_to_horizontal_box)
    lbox.set_editor_property("width_override", LIST_W)
    lbox.set_editor_property("override_width_override", True)
    mods, _ = widget(unreal.ScrollBox, "SC_KrinikMods", lbox, lbox.add_child)

    def keep_order(box, names):
        # Pages (and rows) added in the MIDDLE of PAGES (the four Xevyr pages before «dm», 2026-11-02; the colour rows inside a page) would be appended
        # after the reused ones: the kit has no ShiftChild. A box whose children stand out of the script's order is emptied — its widgets stay in the
        # tree — and the widget() calls below re-add every child in that order before the save (no orphan → no GUID trap), the same way the rows' «i»
        # re-order works. Effective on the SECOND pass (the first creates the new widgets after the reused ones). [TESTED: 2026-11-02 · X1–X8 in the live game, real clicks, the mods read back · KUMM testcases/reports/2026-11-02_conan-hub-xevyr-four-pages.md]
        have = [box.get_child_at(i).get_name() for i in range(box.get_children_count())]
        want = [n for n in names if n in have]
        if have != want:
            box.clear_children()
            step("%s: re-ordered to the script (%s)" % (box.get_name(), ", ".join(have)))

    keep_order(mods, ["HB_KrinikModItem_" + k for k, _ in PAGES])
    for i, (key, _) in enumerate(PAGES):
        # mockup .toc .on: background #18191a, text #f2eee5, an inset 2 px light bar at the left (P5) — the bar is an Image the Lua section shows
        hb_item, _ = widget(unreal.HorizontalBox, "HB_KrinikModItem_%s" % key, mods, mods.add_child)
        bar_box, bbs = sized("SB_KrinikModBar_%s" % key, hb_item, hb_item.add_child_to_horizontal_box, w=ITEM_BAR)
        bbs.set_editor_property("vertical_alignment", V_FILL)
        bar, _ = widget(unreal.Image, "Img_KrinikModBar_%s" % key, bar_box, bar_box.add_child)
        bar.set_editor_property("color_and_opacity", unreal.LinearColor(*TEXT))
        bar.set_editor_property("visibility", unreal.SlateVisibility.HIDDEN)
        item, its = border("Brd_KrinikMod_%s" % key, hb_item, hb_item.add_child_to_horizontal_box, (1, 1, 1, 0))
        its.set_editor_property("size", FILL)
        item.set_editor_property("background", flat(DARK))
        item.set_editor_property("padding", unreal.Margin(ITEM_PAD_X, ITEM_PAD_Y, ITEM_PAD_X, ITEM_PAD_Y))
        clip, _ = widget(unreal.ScrollBox, "SC_KrinikModName_%s" % key, item, item.add_child)
        clip.set_editor_property("orientation", unreal.Orientation.ORIENT_HORIZONTAL)
        clip.set_editor_property("scroll_bar_visibility", COLLAPSED)
        clip.set_editor_property("consume_mouse_wheel", unreal.ConsumeMouseWheel.NEVER)
        clip.set_editor_property("visibility", unreal.SlateVisibility.HIT_TEST_INVISIBLE)
        text("Txt_KrinikModName_%s" % key, clip, clip.add_child, SIZE_NAME, color=TOC)
    rv, rvs = rule("Img_KrinikRuleMid", body, body.add_child_to_horizontal_box, vertical=True, rgba=RULE_LIST)
    rvs.set_editor_property("padding", unreal.Margin(u(10), 0, u(16), 0))
    rvs.set_editor_property("vertical_alignment", V_FILL)
    right, rs = widget(unreal.VerticalBox, "VB_KrinikRight", body, body.add_child_to_horizontal_box)
    rs.set_editor_property("size", FILL)
    mhead, _ = widget(unreal.HorizontalBox, "HB_KrinikModHead", right, right.add_child_to_vertical_box)
    mt, mts = text("Txt_KrinikModTitle", mhead, mhead.add_child_to_horizontal_box, SIZE_MOD_TITLE)
    mts.set_editor_property("size", FILL)
    mn, mns = text("Txt_KrinikModNote", mhead, mhead.add_child_to_horizontal_box, SIZE_NOTE, grey=True)
    mns.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_BOTTOM)
    r2, r2s = rule("Img_KrinikRuleMod", right, right.add_child_to_vertical_box)
    r2s.set_editor_property("padding", unreal.Margin(0, u(3), 0, u(6)))
    rows, rows_s = widget(unreal.ScrollBox, "SC_KrinikRows", right, right.add_child_to_vertical_box)
    rows_s.set_editor_property("size", FILL)
    pages, _ = widget(unreal.WidgetSwitcher, "WS_KrinikPages", rows, rows.add_child)
    keep_order(pages, ["VB_KrinikPage_" + k for k, _ in PAGES])
    for key, items in PAGES:
        page, _ = widget(unreal.VerticalBox, "VB_KrinikPage_%s" % key, pages, pages.add_child)
        keep_order(page, ["HB_KrinikRow_" + rid for rid, _ in items])
        for rid, kind in items:
            row, rws = widget(unreal.HorizontalBox, "HB_KrinikRow_%s" % rid, page, page.add_child_to_vertical_box)
            rws.set_editor_property("padding", unreal.Margin(0, ROW_GAP, 0, ROW_GAP))
            # the «i» stands FIRST, one column left of the labels: «(i) Название опции, пояснение» (`[OWNER]` «давай (i) перенесем в одну колонку слева
            # от настроек, тогда будет более органичная и красивая структура» · 2026-11-01 09:33). The kit's Python has no ShiftChild: a row built in
            # the old order is emptied (its widgets stay in the tree) and every widget() call below adds its child back IN THIS ORDER before the save —
            # nothing is left without a parent (the GUID trap); the slots are set after the re-add.
            # [TESTED: 2026-11-01 · run 1 re-ordered 18 rows, run 2 none; five pages in game show «(i) label hint» · KUMM TC_conan_hub_no_dimming_2026-11-01 C1]
            if row.get_children_count() > 0 and row.get_child_at(0).get_name() != "Brd_KrinikInfo_%s" % rid:
                row.clear_children()
                step("row %s: re-ordered, «i» first" % rid)
            info, ins = border("Brd_KrinikInfo_%s" % rid, row, row.add_child_to_horizontal_box)
            ins.set_editor_property("vertical_alignment", V_CENTER)
            ins.set_editor_property("padding", unreal.Margin(0, 0, u(8), 0))
            info.set_editor_property("padding", unreal.Margin(0, 0, 0, 0))
            # mockup .info: a 12 px circle, rim #8e8a82, the letter #bdb9b0 (P10); HALF_HEIGHT_RADIUS on a SQUARE box is a circle
            info.set_editor_property("background", rimmed((0, 0, 0, 0), GREY, radius="half"))
            info.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
            # the «i» text sits in a SQUARE SizeBox INFO_D × INFO_D inside the border: the text alone is 22.6 × 27.3 (its line is taller than
            # INFO_D), and HALF_HEIGHT_RADIUS on that box draws a lemon, not a circle — rows built after the box left this script (ui_shout_hold,
            # ui_vig_*) showed it, rows built before kept their box (remote 2026-11-01: SB_KrinikInfo_ui_fps 22.6/22.6, ui_vig_hunger — TextBlock
            # directly, 22.6 × 27.3; `[OWNER]` «(i) искажены в строках, где много теста»). A border has ONE child: set_content REPLACES the text
            # with the box (add_child into a full border failed on 2026-11-01 and orphaned both — the GUID trap), then the text goes into the box.
            ibox, _ = sized("SB_KrinikInfo_%s" % rid, info, info.set_content, w=INFO_D, h=INFO_D)
            it, _ = text("Txt_KrinikInfo_%s" % rid, ibox, ibox.add_child, SIZE_INFO, bold=True, color=CHECK_RIM, sans_bold=True)
            it.set_editor_property("justification", unreal.TextJustify.CENTER)
            it.set_editor_property("min_desired_width", INFO_D)
            lbl, ls = text("Txt_KrinikLbl_%s" % rid, row, row.add_child_to_horizontal_box, SIZE_LABEL)
            ls.set_editor_property("vertical_alignment", V_CENTER)
            hint, hs2 = text("Txt_KrinikHint_%s" % rid, row, row.add_child_to_horizontal_box, SIZE_SMALL, grey=True)
            hs2.set_editor_property("vertical_alignment", V_CENTER)
            hs2.set_editor_property("padding", unreal.Margin(u(6), 0, 0, 0))   # the gap after the label that the «i» gave before 09:33
            fill, fs = widget(unreal.Spacer, "Sp_KrinikRow_%s" % rid, row, row.add_child_to_horizontal_box)
            fs.set_editor_property("size", FILL)
            # the game's control stays in the tree (GUID trap) but collapsed: its diamond thumb, edit box and yellow tick are not the mockup (P6–P8);
            # the colour and key rows (2026-11-02) never had one
            if kind in ("slider", "check"):
                cbox, cbs = widget(unreal.SizeBox, "SB_KrinikCtl_%s" % rid, row, row.add_child_to_horizontal_box)
                cbox.set_editor_property("visibility", COLLAPSED)
                cname = REUSED_CONTROL.get(rid) or ("%s_Krinik_%s" % ("Sl" if kind == "slider" else "Chk", rid))
                widget(sld_cls if kind == "slider" else chk_cls, cname, cbox, cbox.add_child)
            own, ows = widget(unreal.HorizontalBox, "HB_KrinikCtl_%s" % rid, row, row.add_child_to_horizontal_box)
            ows.set_editor_property("vertical_alignment", V_CENTER)
            if kind.startswith("color"):
                # mockup 8 .sw: a dark box 120 × 18 with a thin rim, the swatch(es) and the colour's name; a click on a swatch opens THE palette plate
                # (one for every colour row, built below) — `[OWNER]` 2026-11-02 07:20 «выбор цвета открывать поп=апом поверх окна, не жвигая другие пункты».
                # «color9» — the Damage Meter's nine follower bars: nine small swatches, each opens the palette for its own bar. [TESTED: 2026-11-02 · C1–C9 in the live game, real clicks and keys, the mods read back (the busy plate's fade not measured) · KUMM testcases/reports/2026-11-02_conan-hub-colour-key-rows.md]
                n = 9 if kind == "color9" else 1
                ows.set_editor_property("padding", unreal.Margin(0, 0, SW_RIGHT, 0))
                swbox, _ = sized("SB_KrinikSwBox_%s" % rid, own, own.add_child_to_horizontal_box, w=SW_BOX_W, h=SW_BOX_H)
                swb, _ = border("Brd_KrinikSw_%s" % rid, swbox, swbox.add_child)
                swb.set_editor_property("background", rimmed(DARK, BTN_RIM))
                swb.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
                # mockup .sw padding 0 4 (sides only) and align-items: center — the swatch 10 high in the middle (frame C1 08:12: with padding on all sides
                # the name's line overflowed the box and sat on its bottom edge)
                swb.set_editor_property("padding", unreal.Margin(SW_PAD, 0, SW_PAD, 0))
                swb.set_editor_property("vertical_alignment", V_CENTER)
                swh, _ = widget(unreal.HorizontalBox, "HB_KrinikSw_%s" % rid, swb, swb.add_child)
                gap = SW_GAP if n == 1 else SW_GAP9
                cw = SW_W if n == 1 else (SW_BOX_W - 2 * SW_PAD - (n - 1) * gap) / n
                for c in range(n):
                    cbx, cbxs = sized("SB_KrinikSwC_%s_%d" % (rid, c), swh, swh.add_child_to_horizontal_box, w=cw, h=SW_H)
                    cbxs.set_editor_property("vertical_alignment", V_CENTER)
                    if c:
                        cbxs.set_editor_property("padding", unreal.Margin(gap, 0, 0, 0))
                    sw_, _ = border("Brd_KrinikSwC_%s_%d" % (rid, c), cbx, cbx.add_child)
                    sw_.set_editor_property("background", rimmed((1, 1, 1, 1), SW_RIM))     # the Lua section tints it by SetBrushColor
                    sw_.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
                if n == 1:
                    nm, nms = text("Txt_KrinikSwName_%s" % rid, swh, swh.add_child_to_horizontal_box, SIZE_SMALL, color=CHECK_RIM)
                    nms.set_editor_property("vertical_alignment", V_CENTER)
                    nms.set_editor_property("padding", unreal.Margin(SW_GAP, 0, 0, 0))
            elif kind == "drop":
                # a box like .key with the chosen option and a «▾»; a click opens THE option list plate (built below) over the window at the cursor — the
                # owner's popup rule of 2026-11-02 07:20 for every chooser (the Damage Meter's corner, Simple Minimap's time display). [NOT-TESTED]
                ows.set_editor_property("padding", unreal.Margin(0, 0, SW_RIGHT, 0))
                dbx, _ = sized("SB_KrinikDrop_%s" % rid, own, own.add_child_to_horizontal_box, w=SW_BOX_W, h=SW_BOX_H)
                db, _ = border("Brd_KrinikDrop_%s" % rid, dbx, dbx.add_child)
                db.set_editor_property("background", rimmed(DARK, BTN_RIM))
                db.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
                db.set_editor_property("padding", unreal.Margin(SW_PAD * 2, 0, SW_PAD * 2, 0))
                db.set_editor_property("vertical_alignment", V_CENTER)
                dh, _ = widget(unreal.HorizontalBox, "HB_KrinikDrop_%s" % rid, db, db.add_child)
                dt_, dts = text("Txt_KrinikDrop_%s" % rid, dh, dh.add_child_to_horizontal_box, SIZE_SMALL, color=BRIGHT)
                dts.set_editor_property("size", FILL)
                dts.set_editor_property("vertical_alignment", V_CENTER)
                da, das = text("Txt_KrinikDropArrow_%s" % rid, dh, dh.add_child_to_horizontal_box, SIZE_SMALL, grey=True)
                da.set_editor_property("text", unreal.Text("▾"))
                das.set_editor_property("vertical_alignment", V_CENTER)
            elif kind == "key":
                # mockup 9 .key: a dark box 120 × 18 with the key's name; the ENGINE's own key selector waits for the next key («Нажмите клавишу…»), the Lua
                # section refuses a key the game owns with a 5 s fading plate (`[OWNER]` 2026-11-02 07:23). [TESTED: 2026-11-02 · C1–C9 in the live game, real clicks and keys, the mods read back (the busy plate's fade not measured) · KUMM testcases/reports/2026-11-02_conan-hub-colour-key-rows.md]
                ows.set_editor_property("padding", unreal.Margin(0, 0, SW_RIGHT, 0))
                kbx, _ = sized("SB_KrinikKey_%s" % rid, own, own.add_child_to_horizontal_box, w=SW_BOX_W, h=SW_BOX_H)
                ks, _ = widget(unreal.InputKeySelector, "Ks_Krinik_%s" % rid, kbx, kbx.add_child)
                bst = unreal.ButtonStyle()
                for prop, fill in (("normal", DARK), ("hovered", lin(40, 41, 43)), ("pressed", DARK)):
                    try_set(bst, prop, rimmed(fill, BTN_RIM if prop != "hovered" else RIM), "KeyStyle %s %s" % (rid, prop))
                try_set(ks, "widget_style", bst, "Ks_" + rid)
                tst = unreal.TextBlockStyle()
                try_set(tst, "font", unreal.SlateFontInfo(font_object=font_obj, typeface_font_name=FACE, size=SIZE_SMALL), "KeyText " + rid)
                try_set(tst, "color_and_opacity", unreal.SlateColor(unreal.LinearColor(*BRIGHT)), "KeyText color " + rid)
                try_set(ks, "text_style", tst, "Ks_" + rid)
                try_set(ks, "key_selection_text", unreal.Text("Нажмите клавишу…"), "Ks_" + rid)
                try_set(ks, "no_key_specified_text", unreal.Text("—"), "Ks_" + rid)
                try_set(ks, "allow_modifier_keys", False, "Ks_" + rid)
                try_set(ks, "allow_gamepad_keys", False, "Ks_" + rid)
                try_set(ks, "margin", unreal.Margin(0, 0, 0, 0), "Ks_" + rid)
            elif kind == "slider":
                # mockup .slider: track 2 px #6d6a64, thumb 4×10 #e8e4da, 120 wide + margin 10; .val: 44 wide, right, bold #ece8df (P6, P7)
                sbox, _ = sized("SB_KrinikSld_%s" % rid, own, own.add_child_to_horizontal_box, w=SLIDER_W, h=ROW_H)
                sld, sls = widget(unreal.Slider, "Sld_Krinik_%s" % rid, sbox, sbox.add_child)
                sls.set_editor_property("vertical_alignment", V_CENTER)
                style = unreal.SliderStyle()
                for prop in ("normal_bar_image", "hovered_bar_image", "disabled_bar_image"):
                    style.set_editor_property(prop, flat(TRACK))
                for prop in ("normal_thumb_image", "hovered_thumb_image", "disabled_thumb_image"):
                    tb_ = flat(THUMB if prop != "hovered_thumb_image" else BRIGHT)
                    try:
                        # DeprecateSlateVector2D takes no constructor arguments here (run 2026-11-01 05:0x) — fill its fields
                        vs = unreal.DeprecateSlateVector2D()
                        for f, val in (("x", THUMB_W), ("y", THUMB_H)):
                            try:
                                vs.set_editor_property(f, val)
                            except Exception:
                                setattr(vs, f, val)
                        tb_.set_editor_property("image_size", vs)
                        res["probe"]["thumb_size"] = str(tb_.get_editor_property("image_size"))
                    except Exception as e:
                        res["probe"]["thumb_size"] = "not set: %s · fields %s" % (str(e)[:160], [n for n in dir(unreal.DeprecateSlateVector2D()) if not n.startswith("_")][:20])
                    style.set_editor_property(prop, tb_)
                try_set(style, "bar_thickness", SLIDER_BAR, "SliderStyle " + rid)
                sld.set_editor_property("widget_style", style)
                sld.set_editor_property("slider_bar_color", unreal.LinearColor(1, 1, 1, 1))
                sld.set_editor_property("slider_handle_color", unreal.LinearColor(1, 1, 1, 1))
                try_set(sld, "mouse_uses_step", True, "Sld_" + rid)
                sld.set_editor_property("indent_handle", False)
                vbox, vbs = sized("SB_KrinikVal_%s" % rid, own, own.add_child_to_horizontal_box, w=VALUE_W + SLIDER_GAP)
                vbs.set_editor_property("vertical_alignment", V_CENTER)
                vt, vts = text("Txt_KrinikVal_%s" % rid, vbox, vbox.add_child, SIZE_VALUE, bold=True, color=BRIGHT)
                vt.set_editor_property("justification", unreal.TextJustify.RIGHT)
                vts.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
                vts.set_editor_property("vertical_alignment", V_CENTER)
            else:
                # mockup .check: 12 px square, rim #bdb9b0; ON — an inner square #e8e4da inset 2; margin-right 32 (P8). The Lua section shows the inner one.
                ows.set_editor_property("padding", unreal.Margin(0, 0, CHECK_RIGHT, 0))
                kbox, _ = sized("SB_KrinikChk_%s" % rid, own, own.add_child_to_horizontal_box, w=CHECK_D, h=CHECK_D)
                kb, _ = border("Brd_KrinikChk_%s" % rid, kbox, kbox.add_child)
                kb.set_editor_property("background", rimmed((0, 0, 0, 0), CHECK_RIM))
                kb.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
                kb.set_editor_property("padding", unreal.Margin(CHECK_INSET + RULE, CHECK_INSET + RULE, CHECK_INSET + RULE, CHECK_INSET + RULE))
                on, ons = widget(unreal.Image, "Img_KrinikChkOn_%s" % rid, kb, kb.add_child)
                on.set_editor_property("brush", flat(THUMB))
                on.set_editor_property("visibility", unreal.SlateVisibility.HIT_TEST_INVISIBLE)
                ons.set_editor_property("horizontal_alignment", H_FILL)
                ons.set_editor_property("vertical_alignment", V_FILL)
            # the row's height — mockup .row 20 (the label column alone is shorter)
            hbox, _ = sized("SB_KrinikRowH_%s" % rid, row, row.add_child_to_horizontal_box, w=0.0, h=ROW_H)
    r3, r3s = rule("Img_KrinikRuleBottom", vb, vb.add_child_to_vertical_box)
    r3s.set_editor_property("padding", unreal.Margin(0, u(8), 0, u(8)))

    # ---- footer -------------------------------------------------------------------------------------------------------------
    foot, _ = widget(unreal.HorizontalBox, "HB_KrinikFoot", vb, vb.add_child_to_vertical_box)
    for gb in ("B_KrinikReset", "B_KrinikSave", "B_KrinikSaveClose"):
        # the game's textured buttons stay in the tree (GUID trap), collapsed; the mockup's flat ones stand beside them (P9)
        g, _ = game_button(gb, foot, foot.add_child_to_horizontal_box)
        g.set_editor_property("visibility", COLLAPSED)
    flat_button("Reset", foot, foot.add_child_to_horizontal_box)
    ff, ffs = widget(unreal.Spacer, "Sp_KrinikFoot", foot, foot.add_child_to_horizontal_box)
    ffs.set_editor_property("size", FILL)
    sv, _ = flat_button("Save", foot, foot.add_child_to_horizontal_box)
    sc, scs = flat_button("SaveClose", foot, foot.add_child_to_horizontal_box)
    # the order of mockup .foot: «Сбросить» | spacer | «Сохранить» «Сохранить и закрыть» — the reused spacer kept its old place before the new buttons
    # (frame 05:10: «Сбросить» stood at the right), so the spacer and the two buttons are taken out and put back after «Сбросить»
    for w in (ff, sv, sc):
        foot.remove_child(w)
        foot.add_child_to_horizontal_box(w)
    ff.get_editor_property("slot").set_editor_property("size", FILL)
    sc.get_editor_property("slot").set_editor_property("padding", unreal.Margin(u(6), 0, 0, 0))
    step("foot order: %s" % [foot.get_child_at(i).get_name() for i in range(foot.get_children_count())])

    # ---- the «i» plate: collapsed, over everything; Lua fills and places it -------------------------------------------------
    # a dark opaque plate with a thin old-gold rim and small rounded corners (Svarog UI_RULEBOOK К6: one dark plate, an old-gold rim, at the element)
    tip, tps = border("Brd_KrinikTip", root, root.add_child_to_canvas, PLATE)
    tb_brush = unreal.SlateBrush()
    try:
        tb_brush.set_editor_property("draw_as", unreal.SlateBrushDrawType.ROUNDED_BOX)
        tob = unreal.SlateBrushOutlineSettings()
        tob.set_editor_property("color", unreal.SlateColor(unreal.LinearColor(*RIM)))
        tob.set_editor_property("width", RULE)
        tob.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.FIXED_RADIUS)
        tob.set_editor_property("corner_radii", unreal.Vector4(0.0, 0.0, 0.0, 0.0))   # mockup .pop: square, a light rim (P11)
        tb_brush.set_editor_property("outline_settings", tob)
        tip.set_editor_property("background", tb_brush)
    except Exception as e:
        step("tip rounded brush not set: %s" % str(e)[:160])
    tip.set_editor_property("visibility", COLLAPSED)
    tip.set_editor_property("padding", unreal.Margin(u(12), u(10), u(12), u(10)))
    tps.set_auto_size(True)
    tps.set_z_order(10)
    tvb, _ = widget(unreal.VerticalBox, "VB_KrinikTip", tip, tip.add_child)
    tt, tts = text("Txt_KrinikTipTitle", tvb, tvb.add_child_to_vertical_box, SIZE_TIP_TITLE, bold=True, color=BRIGHT, spacing=SPACING_TIP)
    tts.set_editor_property("padding", unreal.Margin(0, 0, 0, u(4)))
    tb, _ = text("Txt_KrinikTipBody", tvb, tvb.add_child_to_vertical_box, SIZE_TIP)
    tb.set_editor_property("auto_wrap_text", True)
    tb.set_editor_property("wrap_text_at", TIP_W)

    # ---- the palette plate (mockup 8, plan 40.3 I6.2): collapsed, over everything; Lua places it at the clicked swatch, tints the swatches ----------
    # `[OWNER]` 2026-11-02 07:20 «выбор цвета открывать поп=апом поверх окна, не жвигая другие пункты» · 07:22 «кнопка не Выбрать. а Принять». [TESTED: 2026-11-02 · C1–C9 in the live game, real clicks and keys, the mods read back (the busy plate's fade not measured) · KUMM testcases/reports/2026-11-02_conan-hub-colour-key-rows.md]
    pal, pls = border("Brd_KrinikPal", root, root.add_child_to_canvas, (1, 1, 1, 1))
    pal.set_editor_property("background", rimmed(PLATE, RIM))
    pal.set_editor_property("visibility", COLLAPSED)
    pal.set_editor_property("padding", unreal.Margin(PAL_PAD_X, PAL_PAD_Y, PAL_PAD_X, PAL_PAD_Y))
    pls.set_auto_size(True)
    pls.set_z_order(11)
    pvb, _ = widget(unreal.VerticalBox, "VB_KrinikPal", pal, pal.add_child)
    keep_order(pvb, ["Txt_KrinikPalTitle", "SB_KrinikPalRect", "HB_KrinikPalRow0", "HB_KrinikPalRow1", "HB_KrinikPalCmp", "HB_KrinikPalBtns"])
    text("Txt_KrinikPalTitle", pvb, pvb.add_child_to_vertical_box, SIZE_SMALL, color=CHECK_RIM)
    # THE COLOUR RECTANGLE (`[OWNER]` 2026-11-02 08:45 «вместо квадратиков фиксированных цветов, нужно дать прямоугольник палитры»): the texture of
    # make-palette-texture.py (hue across, white → the pure hue → black down, a grey column at the right); a click picks any colour — the Lua section maps
    # the point by the same formula and moves the small rim `Brd_KrinikPalMark` there (its slot padding). The 16 cells below stay in the tree COLLAPSED (GUID
    # trap). [NOT-TESTED]
    prect, prcs = sized("SB_KrinikPalRect", pvb, pvb.add_child_to_vertical_box, w=PAL_RECT_W, h=PAL_RECT_H)
    prcs.set_editor_property("padding", unreal.Margin(0, PAL_GAP, 0, 0))
    pov2, _ = widget(unreal.Overlay, "OV_KrinikPalRect", prect, prect.add_child)
    rimg, ris = widget(unreal.Image, "Img_KrinikPalRect", pov2, pov2.add_child_to_overlay)
    rb = unreal.SlateBrush()
    rb.set_editor_property("draw_as", unreal.SlateBrushDrawType.IMAGE)
    ptex = unreal.load_asset(PKG + "/T_KrinikPalette")
    if ptex is not None:
        rb.set_editor_property("resource_object", ptex)
    step("palette texture: %s" % (ptex.get_path_name() if ptex else "MISSING — run import-logo-texture.py with KIT_TEX_NAME=T_KrinikPalette"))
    rimg.set_editor_property("brush", rb)
    ris.set_editor_property("horizontal_alignment", H_FILL)
    ris.set_editor_property("vertical_alignment", V_FILL)
    mark, mks = border("Brd_KrinikPalMark", pov2, pov2.add_child_to_overlay)
    mark.set_editor_property("background", rimmed((0, 0, 0, 0), BRIGHT))
    mark.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
    mark.set_editor_property("visibility", unreal.SlateVisibility.HIT_TEST_INVISIBLE)
    mks.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_LEFT)
    mks.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_TOP)
    sized("SB_KrinikPalMark", mark, mark.add_child, w=PAL_MARK, h=PAL_MARK)
    for r in range(2):
        prow, prs = widget(unreal.HorizontalBox, "HB_KrinikPalRow%d" % r, pvb, pvb.add_child_to_vertical_box)
        prow.set_editor_property("visibility", COLLAPSED)
        prs.set_editor_property("padding", unreal.Margin(0, PAL_GAP + (PAL_SEL if r == 0 else 0), 0, 0))
        for c in range(PAL_COLOURS // 2):
            i = r * (PAL_COLOURS // 2) + c
            # the click target (transparent, hit-testable) → an overlay: the colour + the «chosen» rim (hidden; Lua shows it on the chosen one)
            cell, cs_ = border("Brd_KrinikPalC_%d" % i, prow, prow.add_child_to_horizontal_box)
            cs_.set_editor_property("padding", unreal.Margin(0 if c == 0 else PAL_GAP, 0, 0, 0))
            cell.set_editor_property("padding", unreal.Margin(PAL_SEL, PAL_SEL, PAL_SEL, PAL_SEL))
            cbox_, _ = sized("SB_KrinikPalC_%d" % i, cell, cell.add_child, w=PAL_SW_W, h=PAL_SW_H)
            pov, _ = widget(unreal.Overlay, "OV_KrinikPalC_%d" % i, cbox_, cbox_.add_child)
            sw_img, swis = widget(unreal.Image, "Img_KrinikPalC_%d" % i, pov, pov.add_child_to_overlay)
            sw_img.set_editor_property("brush", rimmed((1, 1, 1, 1), lin(232, 228, 218, 0.25)))
            swis.set_editor_property("horizontal_alignment", H_FILL)
            swis.set_editor_property("vertical_alignment", V_FILL)
            sel = cell   # the chosen rim is the cell's own brush (Lua sets its colour: bright on the chosen, transparent elsewhere)
            sel.set_editor_property("background", rimmed((0, 0, 0, 0), BRIGHT))
            sel.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 0))
    pcmp, pcs = widget(unreal.HorizontalBox, "HB_KrinikPalCmp", pvb, pvb.add_child_to_vertical_box)
    pcs.set_editor_property("padding", unreal.Margin(0, u(8), 0, u(8)))
    for key, label_name in (("Old", "Txt_KrinikPalWas"), ("New", "Txt_KrinikPalNow")):
        lt, lts = text(label_name, pcmp, pcmp.add_child_to_horizontal_box, SIZE_SMALL, color=CHECK_RIM)
        lts.set_editor_property("vertical_alignment", V_CENTER)
        lts.set_editor_property("padding", unreal.Margin(0 if key == "Old" else u(12), 0, u(8), 0))
        ib, ibs = sized("SB_KrinikPal%s" % key, pcmp, pcmp.add_child_to_horizontal_box, w=PAL_CMP_W, h=PAL_CMP_H)
        ibs.set_editor_property("vertical_alignment", V_CENTER)
        im, _ = widget(unreal.Image, "Img_KrinikPal%s" % key, ib, ib.add_child)
        im.set_editor_property("brush", rimmed((1, 1, 1, 1), lin(232, 228, 218, 0.4)))
    pbtn, _ = widget(unreal.HorizontalBox, "HB_KrinikPalBtns", pvb, pvb.add_child_to_vertical_box)
    pfill, pfs = widget(unreal.Spacer, "Sp_KrinikPalBtns", pbtn, pbtn.add_child_to_horizontal_box)
    pfs.set_editor_property("size", FILL)
    flat_button("PalCancel", pbtn, pbtn.add_child_to_horizontal_box)
    pok, poks = flat_button("PalOk", pbtn, pbtn.add_child_to_horizontal_box)
    poks.set_editor_property("padding", unreal.Margin(u(6), 0, 0, 0))

    # ---- the option list plate of a «drop» row: collapsed; Lua fills up to four options, shows the chosen one's rim, places it at the cursor [NOT-TESTED]
    lst, lss = border("Brd_KrinikList", root, root.add_child_to_canvas, (1, 1, 1, 1))
    lst.set_editor_property("background", rimmed(PLATE, RIM))
    lst.set_editor_property("visibility", COLLAPSED)
    lst.set_editor_property("padding", unreal.Margin(u(4), u(4), u(4), u(4)))
    lss.set_auto_size(True)
    lss.set_z_order(11)
    lvb, _ = widget(unreal.VerticalBox, "VB_KrinikList", lst, lst.add_child)
    for i in range(4):
        lo, los = border("Brd_KrinikListO_%d" % i, lvb, lvb.add_child_to_vertical_box)
        lo.set_editor_property("background", rimmed((0, 0, 0, 0), BRIGHT))
        lo.set_editor_property("brush_color", unreal.LinearColor(1, 1, 1, 1))
        lo.set_editor_property("padding", unreal.Margin(SW_PAD * 2, u(3), SW_PAD * 2, u(3)))
        lbx, _ = sized("SB_KrinikListO_%d" % i, lo, lo.add_child, w=SW_BOX_W - 2 * SW_PAD * 2)
        text("Txt_KrinikListO_%d" % i, lbx, lbx.add_child, SIZE_SMALL, color=BRIGHT)

    # ---- the busy-key plate (mockup 9): collapsed; Lua shows it at the key box, fades it in, holds 5 s, fades it out (`[OWNER]` 07:23) --------
    busy, bus = border("Brd_KrinikKeyBusy", root, root.add_child_to_canvas, (1, 1, 1, 1))
    busy.set_editor_property("background", rimmed(PLATE, BUSY_RIM))
    busy.set_editor_property("visibility", COLLAPSED)
    busy.set_editor_property("padding", unreal.Margin(u(10), u(6), u(10), u(6)))
    bus.set_auto_size(True)
    bus.set_z_order(12)
    text("Txt_KrinikKeyBusy", busy, busy.add_child, SIZE_SMALL, color=BUSY_TEXT)

    unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    cdo = unreal.get_default_object(bp.generated_class())
    res["probe"]["window_cdo"] = members(cdo, unreal.UserWidget)
    for prop in ("need_mouse_input", "NeedMouseInput", "b_need_mouse_input"):
        try:
            res["probe"]["window_" + prop] = str(cdo.get_editor_property(prop))
        except Exception:
            pass
    res["saved_window"] = lib.save_loaded_asset(bp, False)
    step("window tree: %s" % [vb.get_child_at(i).get_name() for i in range(vb.get_children_count())])

    # ---- 2. the module table -------------------------------------------------------------------------------------------------------
    rs = unreal.load_object(None, "/Script/ConanSandbox.UIModuleTableRow")
    if rs is None:
        raise RuntimeError("row struct UIModuleTableRow not found")
    dpath = "%s/%s" % (PKG, DT)
    if lib.does_asset_exist(dpath):
        dt = unreal.load_asset(dpath)
        step("table reused " + dt.get_path_name())
    else:
        df = unreal.DataTableFactory()
        df.set_editor_property("struct", rs)
        dt = tools.create_asset(DT, PKG, unreal.DataTable, df)
        if dt is None:
            raise RuntimeError("table not created")
        step("table created " + dt.get_path_name())
    row = dict(ROW_VALUES)
    row["Name"] = ROW
    filled = unreal.DataTableFunctionLibrary.fill_data_table_from_json_string(dt, json.dumps([row]))
    step("fill_data_table_from_json_string -> %s" % filled)
    dfl = unreal.DataTableFunctionLibrary
    res["table_rows"] = [str(n) for n in dfl.get_data_table_row_names(dt)]
    cols = {}
    for c in ("WidgetClass", "Category", "FullscreenGUIAction", "ZOrder", "CloseOnESC", "CloseOnEndPlay", "ShowInPlayingState",
              "MustBeBasePlayerChar", "bHiddenDuringVanityMode"):
        try:
            cols[c] = [str(v) for v in dfl.get_data_table_column_as_string(dt, c)]
        except Exception as e:
            cols[c] = "ERR %s" % str(e)[:120]
    res["table_columns"] = cols
    # the vanilla table's columns for the fishing-like vanilla popup, side by side (format check)
    van = unreal.load_asset("/Game/UI/Data/DataTables/DT_UIModuleTable")
    vnames = [str(n) for n in dfl.get_data_table_row_names(van)]
    res["vanilla_rows"] = len(vnames)
    if "InventorySettingsPopup" in vnames:
        i = vnames.index("InventorySettingsPopup")
        res["vanilla_InventorySettingsPopup"] = {c: str(dfl.get_data_table_column_as_string(van, c)[i]) for c in cols}
    res["saved_table"] = lib.save_loaded_asset(dt, False)
    res["ok"] = bool(res["saved_window"]) and bool(res["saved_table"]) and res["table_rows"] == [ROW]
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
