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
CONTENT_PAD = 42.0
BORDER_MARGIN = 0.25                      # [AI] Box nine-slice of the border texture
LIST_W = 290.0                            # the left list: every name but «KrinikConanModPackManager» (364) fits whole
NAME_W = 258.0                            # a mod name's clip box (= the Lua section's NAME_BOX); a longer name slides (the marquee)
CONTROL_SLIDER_W = 290.0                  # the slider control with its value box: bar + a 3-digit value; the Lua section's SLIDER_BOX_W is the same number
CONTROL_CHECK_W = 120.0                   # the checkbox control
CONTROL_H = 48.0                          # the game controls' own height was ≈ 60 — rows 75 apart against the mockup's ≈ 40 (seam S2)
ROW_GAP = 1.0
RULE = 2.0                                # the thin rules of mockup 5
TIP_W = 470.0                             # the «i» plate
# The font: the GAME's Noto Sans, regular. The kit's settings row carried the ENGINE's Roboto Bold (the bold the owner saw, seam S3); the game's serifs
# (Cardo, Crimson Pro) have NO Cyrillic — Russian letters fell back to a sans beside serif Latin (frames t1, t2 of 2026-10-31 21:56–21:57).
FONT = "/Game/Fonts/NotoSans"
FACE, FACE_BOLD = "Normal", "Bold"
SIZE_TITLE, SIZE_NAME, SIZE_MOD_TITLE, SIZE_LABEL, SIZE_SMALL, SIZE_INFO, SIZE_TIP_TITLE, SIZE_TIP = 26, 19, 22, 19, 15, 14, 18, 17
INFO_D = 26.3                             # the «i» circle: the line height of Noto Sans 14 (measured live) — a square box draws a circle, not a lens (seam S4)
# Colours are LINEAR (UE): 0.06 renders as sRGB ≈ 69 — the «dark» plate was grey-brown (seam S5)
TEXT = (0.69, 0.67, 0.62, 1.0)            # ≈ sRGB #d9d6cf, mockup 5's text
GREY = (0.25, 0.24, 0.22, 1.0)            # ≈ sRGB #8a8680, hints and the mod note (was 0.55 ≈ sRGB 194, near white — seam S6)
PLATE = (0.012, 0.011, 0.009, 1.0)        # the «i» plate, ≈ sRGB #1c1b18, opaque
RIM = (0.55, 0.40, 0.16, 1.0)             # its thin old-gold rim
# The pages and their rows — ids only; labels, «i» texts and ranges live in the Lua section (krinik_mod_settings.lua, SETTINGS).
# Row order inside a page = the mockup's order. Inventory: KUMM researches/conan-mod-settings-hub/krinik-settings-inventory.md (A*, C*).
PAGES = [
    ("cam", [("cam_height", "slider"), ("cam_side", "slider"), ("cam_dist", "slider"), ("cam_pitch", "slider"),
             ("cam_zoom_min", "slider"), ("cam_zoom_max", "slider"), ("cam_sharp", "check"), ("cam_zoom_smooth", "slider")]),
    ("ui", [("ui_fps", "check"), ("ui_blink_food", "slider"), ("ui_blink_weight", "slider"), ("ui_menu_slow", "slider"), ("ui_craft", "check")]),
    ("arc", [("arc_ballistics", "check"), ("arc_nobreak", "check"), ("arc_fov", "slider")]),
    ("mpm", [("mpm_hud_scale", "slider")]),
    ("gfx", [("gfx_blood", "slider")]),
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
    ov, _ = widget(unreal.Overlay, "OV_KrinikFrame", frame, frame.add_child)
    bg, bslot = widget(unreal.Image, "Img_KrinikBackground", ov, ov.add_child_to_overlay)
    bg.set_brush_from_texture(unreal.load_asset(BG_TEX), False)
    bslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    bslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    bd, bdslot = widget(unreal.Image, "Img_KrinikBorder", ov, ov.add_child_to_overlay)
    br = unreal.SlateBrush()
    br.set_editor_property("resource_object", unreal.load_asset(BORDER_TEX))
    br.set_editor_property("draw_as", unreal.SlateBrushDrawType.BOX)
    br.set_editor_property("margin", unreal.Margin(BORDER_MARGIN, BORDER_MARGIN, BORDER_MARGIN, BORDER_MARGIN))
    bd.set_editor_property("brush", br)
    bdslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    bdslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    vb, vslot = widget(unreal.VerticalBox, "VB_KrinikContent", ov, ov.add_child_to_overlay)
    vslot.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    vslot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    vslot.set_editor_property("padding", unreal.Margin(CONTENT_PAD, CONTENT_PAD * 0.6, CONTENT_PAD, CONTENT_PAD * 0.6))

    H_FILL, V_FILL = unreal.HorizontalAlignment.H_ALIGN_FILL, unreal.VerticalAlignment.V_ALIGN_FILL
    V_CENTER, H_RIGHT = unreal.VerticalAlignment.V_ALIGN_CENTER, unreal.HorizontalAlignment.H_ALIGN_RIGHT
    COLLAPSED, VISIBLE = unreal.SlateVisibility.COLLAPSED, unreal.SlateVisibility.VISIBLE
    FILL, AUTO = unreal.SlateChildSize(1.0, unreal.SlateSizeRule.FILL), unreal.SlateChildSize(1.0, unreal.SlateSizeRule.AUTOMATIC)

    font_obj = unreal.load_asset(FONT)
    step("font %s: %s" % (FONT, font_obj is not None))
    if font_obj is None:
        raise RuntimeError("the game font %s not found" % FONT)

    def text(name, parent, add, size, bold=False, grey=False):
        t, slot = widget(unreal.TextBlock, name, parent, add)
        t.set_editor_property("font", unreal.SlateFontInfo(font_object=font_obj, typeface_font_name=FACE_BOLD if bold else FACE, size=size))
        t.set_editor_property("color_and_opacity", unreal.SlateColor(unreal.LinearColor(*(GREY if grey else TEXT))))
        return t, slot

    def rule(name, parent, add, vertical=False):
        # a thin line: an Image inside a SizeBox of RULE thickness (the brush's image_size is a DeprecateSlateVector2D in this kit — Python's
        # Vector2D does not convert, run 2026-10-31 20:33)
        box, slot = widget(unreal.SizeBox, name + "_Box", parent, add)
        box.set_editor_property("width_override" if vertical else "height_override", RULE)
        box.set_editor_property("override_width_override" if vertical else "override_height_override", True)
        img, _ = widget(unreal.Image, name, box, box.add_child)
        img.set_editor_property("color_and_opacity", unreal.LinearColor(0.42, 0.38, 0.32, 0.55))
        return img, slot

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
    title, ts = text("Txt_KrinikTitle", head, head.add_child_to_horizontal_box, SIZE_TITLE, bold=True)
    ts.set_editor_property("size", FILL)
    ts.set_editor_property("vertical_alignment", V_CENTER)
    close, cs = game_button("B_KrinikClose", head, head.add_child_to_horizontal_box)
    try_set(close, "key_shortcut_name", unreal.Name("Escape"), "B_KrinikClose")
    cs.set_editor_property("vertical_alignment", V_CENTER)
    r1, r1s = rule("Img_KrinikRuleTop", vb, vb.add_child_to_vertical_box)
    r1s.set_editor_property("padding", unreal.Margin(0, 16, 0, 16))

    # ---- body: the list | the selected mod's page -------------------------------------------------------------------------------
    body, bs = widget(unreal.HorizontalBox, "HB_KrinikBody", vb, vb.add_child_to_vertical_box)
    bs.set_editor_property("size", FILL)
    lbox, lbs = widget(unreal.SizeBox, "SB_KrinikList", body, body.add_child_to_horizontal_box)
    lbox.set_editor_property("width_override", LIST_W)
    lbox.set_editor_property("override_width_override", True)
    mods, _ = widget(unreal.ScrollBox, "SC_KrinikMods", lbox, lbox.add_child)
    for i, (key, _) in enumerate(PAGES):
        item, its = border("Brd_KrinikMod_%s" % key, mods, mods.add_child, (1, 1, 1, 0))
        item.set_editor_property("padding", unreal.Margin(14, 9, 14, 9))
        clip, _ = widget(unreal.ScrollBox, "SC_KrinikModName_%s" % key, item, item.add_child)
        clip.set_editor_property("orientation", unreal.Orientation.ORIENT_HORIZONTAL)
        clip.set_editor_property("scroll_bar_visibility", COLLAPSED)
        clip.set_editor_property("consume_mouse_wheel", unreal.ConsumeMouseWheel.NEVER)
        clip.set_editor_property("visibility", unreal.SlateVisibility.HIT_TEST_INVISIBLE)
        text("Txt_KrinikModName_%s" % key, clip, clip.add_child, SIZE_NAME)
    rv, rvs = rule("Img_KrinikRuleMid", body, body.add_child_to_horizontal_box, vertical=True)
    rvs.set_editor_property("padding", unreal.Margin(0, 0, 28, 0))
    rvs.set_editor_property("vertical_alignment", V_FILL)
    right, rs = widget(unreal.VerticalBox, "VB_KrinikRight", body, body.add_child_to_horizontal_box)
    rs.set_editor_property("size", FILL)
    mhead, _ = widget(unreal.HorizontalBox, "HB_KrinikModHead", right, right.add_child_to_vertical_box)
    mt, mts = text("Txt_KrinikModTitle", mhead, mhead.add_child_to_horizontal_box, SIZE_MOD_TITLE)
    mts.set_editor_property("size", FILL)
    mn, mns = text("Txt_KrinikModNote", mhead, mhead.add_child_to_horizontal_box, SIZE_SMALL, grey=True)
    mns.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_BOTTOM)
    r2, r2s = rule("Img_KrinikRuleMod", right, right.add_child_to_vertical_box)
    r2s.set_editor_property("padding", unreal.Margin(0, 8, 0, 12))
    rows, rows_s = widget(unreal.ScrollBox, "SC_KrinikRows", right, right.add_child_to_vertical_box)
    rows_s.set_editor_property("size", FILL)
    pages, _ = widget(unreal.WidgetSwitcher, "WS_KrinikPages", rows, rows.add_child)
    for key, items in PAGES:
        page, _ = widget(unreal.VerticalBox, "VB_KrinikPage_%s" % key, pages, pages.add_child)
        for rid, kind in items:
            row, rws = widget(unreal.HorizontalBox, "HB_KrinikRow_%s" % rid, page, page.add_child_to_vertical_box)
            rws.set_editor_property("padding", unreal.Margin(0, ROW_GAP, 0, ROW_GAP))
            lbl, ls = text("Txt_KrinikLbl_%s" % rid, row, row.add_child_to_horizontal_box, SIZE_LABEL)
            ls.set_editor_property("vertical_alignment", V_CENTER)
            info, ins = border("Brd_KrinikInfo_%s" % rid, row, row.add_child_to_horizontal_box)
            ins.set_editor_property("vertical_alignment", V_CENTER)
            ins.set_editor_property("padding", unreal.Margin(10, 0, 8, 0))
            info.set_editor_property("padding", unreal.Margin(0, 0, 0, 0))
            ib = unreal.SlateBrush()
            try:
                # a round outline like the mockup's «i» (UE5 rounded box): fill transparent, outline in the label colour; HALF_HEIGHT_RADIUS on a SQUARE
                # box is a circle — the box is square because the «i» text is as wide as its line is high (INFO_D)
                ib.set_editor_property("draw_as", unreal.SlateBrushDrawType.ROUNDED_BOX)
                ob = unreal.SlateBrushOutlineSettings()
                ob.set_editor_property("color", unreal.SlateColor(unreal.LinearColor(*TEXT)))
                ob.set_editor_property("width", 1.5)
                ob.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.HALF_HEIGHT_RADIUS)
                ib.set_editor_property("outline_settings", ob)
                ib.set_editor_property("tint_color", unreal.SlateColor(unreal.LinearColor(0, 0, 0, 0)))
                info.set_editor_property("background", ib)
            except Exception as e:
                step("info %s rounded brush not set: %s" % (rid, str(e)[:160]))
            it, _ = text("Txt_KrinikInfo_%s" % rid, info, info.add_child, SIZE_INFO)
            it.set_editor_property("justification", unreal.TextJustify.CENTER)
            it.set_editor_property("min_desired_width", INFO_D)
            hint, hs2 = text("Txt_KrinikHint_%s" % rid, row, row.add_child_to_horizontal_box, SIZE_SMALL, grey=True)
            hs2.set_editor_property("vertical_alignment", V_CENTER)
            fill, fs = widget(unreal.Spacer, "Sp_KrinikRow_%s" % rid, row, row.add_child_to_horizontal_box)
            fs.set_editor_property("size", FILL)
            cbox, cbs = widget(unreal.SizeBox, "SB_KrinikCtl_%s" % rid, row, row.add_child_to_horizontal_box)
            cbs.set_editor_property("vertical_alignment", V_CENTER)
            cbox.set_editor_property("width_override", CONTROL_SLIDER_W if kind == "slider" else CONTROL_CHECK_W)
            cbox.set_editor_property("override_width_override", True)
            cbox.set_editor_property("height_override", CONTROL_H)
            cbox.set_editor_property("override_height_override", True)
            cname = REUSED_CONTROL.get(rid) or ("%s_Krinik_%s" % ("Sl" if kind == "slider" else "Chk", rid))
            ctl, _ = widget(sld_cls if kind == "slider" else chk_cls, cname, cbox, cbox.add_child)
            if kind == "slider" and "slider" not in res["probe"]:
                res["probe"]["slider"] = members(ctl, unreal.UserWidget)
            if kind == "check" and "checkbox" not in res["probe"]:
                res["probe"]["checkbox"] = members(ctl, unreal.UserWidget)
    r3, r3s = rule("Img_KrinikRuleBottom", vb, vb.add_child_to_vertical_box)
    r3s.set_editor_property("padding", unreal.Margin(0, 14, 0, 14))

    # ---- footer -------------------------------------------------------------------------------------------------------------
    foot, _ = widget(unreal.HorizontalBox, "HB_KrinikFoot", vb, vb.add_child_to_vertical_box)
    game_button("B_KrinikReset", foot, foot.add_child_to_horizontal_box)
    ff, ffs = widget(unreal.Spacer, "Sp_KrinikFoot", foot, foot.add_child_to_horizontal_box)
    ffs.set_editor_property("size", FILL)
    game_button("B_KrinikSave", foot, foot.add_child_to_horizontal_box)
    sc, scs = game_button("B_KrinikSaveClose", foot, foot.add_child_to_horizontal_box)
    scs.set_editor_property("padding", unreal.Margin(12, 0, 0, 0))

    # ---- the «i» plate: collapsed, over everything; Lua fills and places it -------------------------------------------------
    # a dark opaque plate with a thin old-gold rim and small rounded corners (Svarog UI_RULEBOOK К6: one dark plate, an old-gold rim, at the element)
    tip, tps = border("Brd_KrinikTip", root, root.add_child_to_canvas, PLATE)
    tb_brush = unreal.SlateBrush()
    try:
        tb_brush.set_editor_property("draw_as", unreal.SlateBrushDrawType.ROUNDED_BOX)
        tob = unreal.SlateBrushOutlineSettings()
        tob.set_editor_property("color", unreal.SlateColor(unreal.LinearColor(*RIM)))
        tob.set_editor_property("width", 1.5)
        tob.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.FIXED_RADIUS)
        tob.set_editor_property("corner_radii", unreal.Vector4(4.0, 4.0, 4.0, 4.0))
        tb_brush.set_editor_property("outline_settings", tob)
        tip.set_editor_property("background", tb_brush)
    except Exception as e:
        step("tip rounded brush not set: %s" % str(e)[:160])
    tip.set_editor_property("visibility", COLLAPSED)
    tip.set_editor_property("padding", unreal.Margin(22, 16, 22, 18))
    tps.set_auto_size(True)
    tps.set_z_order(10)
    tvb, _ = widget(unreal.VerticalBox, "VB_KrinikTip", tip, tip.add_child)
    tt, tts = text("Txt_KrinikTipTitle", tvb, tvb.add_child_to_vertical_box, SIZE_TIP_TITLE, bold=True)
    tts.set_editor_property("padding", unreal.Margin(0, 0, 0, 8))
    tb, _ = text("Txt_KrinikTipBody", tvb, tvb.add_child_to_vertical_box, SIZE_TIP)
    tb.set_editor_property("auto_wrap_text", True)
    tb.set_editor_property("wrap_text_at", TIP_W)

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
