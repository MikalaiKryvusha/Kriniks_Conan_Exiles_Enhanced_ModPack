# kit-corruption-label-plate.py — KUMM bug 91 (and 86): the hover label «Оскверненные Характеристики» of an attribute row gets the owner's look V1 — a dark plate
# ABOVE the purple corruption «+», centred (`[OWNER]` 2026-11-10 13:04 «v1 оскверненная плашка над»; mockup `_config/mockups/corruption_label_mockup.py`, review
# folder 81). The label is the game's own `CorruptionLabel` (W_Attribute) in `CorruptionButtonOverlay` inside Funcom's «Danger_IDK_Why_This_Is_Here» SizeBox; the
# row's EventGraph sets it HitTestInvisible after Select (mouse enter, with a sound) and Hidden after Deselect — it drew from the diamond to the right over the
# perk column, no plate (the control: the branch is vanilla == ours).
#   TREE: a new Border `Brd_KrinikCorruptionPlate` appended to `CorruptionButtonOverlay` (on top), slot centred, render translation up by half the plate + the
#         diamond + a gap; the label moves into it (centred). The plate's brush: a rounded box, dark fill, muted bronze rim (the mockup's numbers / the widget scale).
#   GRAPH: after each of the game's two `SetVisibility(CorruptionLabel)` nodes a `SetVisibility(CorruptionLabel.GetParent())` with the SAME literal is chained —
#         the plate shows and hides with the label; the game's own logic and sound untouched.
# Idempotent: the tree part reuses the Border; the graph part is skipped when a SetVisibility already takes `GetParent` of the label. Any failure stops the run
# BEFORE the save. Run it TWICE before a build (the GUID trap of a new widget).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-corruption-label-plate.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
TREE = WIDGET + ".W_Attribute:WidgetTree"
PLATE = "Brd_KrinikCorruptionPlate"
CANVAS = "Cnv_KrinikCorruptionPlate"
SCALE = 2.094                                  # 4K px per widget unit (the viewport scale at 4K)
U = lambda px: px / SCALE                      # noqa: E731 — the mockup's 4K px → widget units
PAD_X, PAD_Y = U(22), U(12)                    # the mockup's plate padding
DIAMOND_HALF, GAP = U(34), U(22)               # the diamond's half-height with its core glow, the gap to the plate
RADIUS, RIM_W = U(8), 1.0
LINE = 1.35                                    # a text line's height per font-size unit (Noto Sans)


def lin(r, g, b, a=1.0):
    return unreal.LinearColor(*([round((c / 255.0) ** 2.2, 4) for c in (r, g, b)] + [a]))


FILL = lin(22, 21, 20, 0.9)                    # the mockup's PLATE_FILL (22, 21, 20, 230)
RIM = lin(150, 122, 80, 0.78)                  # the mockup's PLATE_RIM (150, 122, 80, 200)
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-corruption-label-plate.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
res = {"ok": False, "steps": [], "links": []}
say = res["steps"].append


def w(name):
    return unreal.find_object(None, TREE + "." + name)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ").replace(" ", "")


def out(n, name):
    p = lib.find_output_pin(n, name)
    if not p:
        raise RuntimeError("no output pin %s on %s" % (name, title(n)))
    return p


def inp(n, name):
    p = lib.find_input_pin(n, name)
    if not p:
        raise RuntimeError("no input pin %s on %s" % (name, title(n)))
    return p


def link(a, b, what):
    ok = pins.try_create_connection(a, b)
    res["links"].append((what, ok))
    if not ok:
        raise RuntimeError("link failed: %s — NOT saved" % what)


def call(ed, path):
    for p in (path, path.replace(":", ".")):
        try:
            n = ed.add_call_function_node(p)
            if n:
                return n
        except Exception as e:
            say("node %s ERR %s" % (p, str(e)[:100]))
    raise RuntimeError("cannot create %s — NOT saved" % path)


def feeders(n, pin_name):
    p = lib.find_input_pin(n, pin_name)
    return [pins.get_owning_node(q) for q in pins.list_connected_pins(p)] if p else []


def plate_brush():
    b = unreal.SlateBrush()
    b.set_editor_property("draw_as", unreal.SlateBrushDrawType.ROUNDED_BOX)
    o = unreal.SlateBrushOutlineSettings()
    o.set_editor_property("color", unreal.SlateColor(RIM))
    o.set_editor_property("width", RIM_W)
    o.set_editor_property("rounding_type", unreal.SlateBrushRoundingType.FIXED_RADIUS)
    o.set_editor_property("corner_radii", unreal.Vector4(RADIUS, RADIUS, RADIUS, RADIUS))
    b.set_editor_property("outline_settings", o)
    b.set_editor_property("tint_color", unreal.SlateColor(FILL))
    return b


try:
    bp = unreal.load_asset(WIDGET)
    label, overlay = w("CorruptionLabel"), w("CorruptionButtonOverlay")
    if not label or not overlay:
        raise RuntimeError("CorruptionLabel / CorruptionButtonOverlay not found — NOT saved")
    # ---- the tree
    plate = w(PLATE)
    if not plate:
        plate = unreal.new_object(unreal.Border, outer=unreal.find_object(None, TREE), name=PLATE)
        say("plate created")
    if label.get_parent() != plate:
        if label.get_parent() != overlay:
            raise RuntimeError("the label's parent is %s, not the overlay — NOT saved" % label.get_parent())
        overlay.remove_child(label)
        overlay.add_child_to_overlay(plate)
        plate.set_content(label)
        say("label moved into the plate (overlay children: %s)" % [overlay.get_child_at(i).get_name() for i in range(overlay.get_children_count())])
    # build 2 (2026-11-10 13:3x, frame pl1): in the overlay of the narrow «Danger_IDK» SizeBox the Border was CLAMPED to the overlay's width — the plate covered
    # «Оскверненн» only and stood left of centre. So the plate sits on a zero-layout CanvasPanel spanning the overlay: a canvas child takes its OWN desired size
    # (auto size), anchored at the overlay's centre (= the diamond), aligned (0.5, 1) and lifted above the diamond. The canvas is HitTestInvisible — it never
    # takes the «+» click.
    canvas = w(CANVAS)
    if not canvas:
        canvas = unreal.new_object(unreal.CanvasPanel, outer=unreal.find_object(None, TREE), name=CANVAS)
        say("canvas created")
    if plate.get_parent() != canvas:
        if plate.get_parent() == overlay:
            overlay.remove_child(plate)
        if canvas.get_parent() != overlay:
            overlay.add_child_to_overlay(canvas)
        canvas.add_child_to_canvas(plate)
        say("plate moved onto the canvas (overlay children: %s)" % [overlay.get_child_at(i).get_name() for i in range(overlay.get_children_count())])
    canvas.set_editor_property("visibility", unreal.SlateVisibility.HIT_TEST_INVISIBLE)
    cs_ = canvas.get_editor_property("slot")
    cs_.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_FILL)
    cs_.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_FILL)
    font_size = label.get_editor_property("font").get_editor_property("size")
    say("label font size %s; the plate's bottom %.1f units above the diamond's centre" % (font_size, DIAMOND_HALF + GAP))
    plate.set_editor_property("background", plate_brush())
    plate.set_editor_property("padding", unreal.Margin(PAD_X, PAD_Y, PAD_X, PAD_Y))
    plate.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)          # hidden until the game shows the label
    s = plate.get_editor_property("slot")                                              # CanvasPanelSlot
    anchors = unreal.Anchors()                     # the slot's layout is set by its methods (no editor properties on CanvasPanelSlot — run 13:4x)
    anchors.set_editor_property("minimum", unreal.Vector2D(0.5, 0.5))
    anchors.set_editor_property("maximum", unreal.Vector2D(0.5, 0.5))
    s.set_anchors(anchors)
    s.set_alignment(unreal.Vector2D(0.5, 1.0))
    s.set_auto_size(True)
    s.set_position(unreal.Vector2D(0, -(DIAMOND_HALF + GAP)))
    t = plate.get_editor_property("render_transform")
    t.set_editor_property("translation", unreal.Vector2D(0, 0))                       # build 1's lift is now the canvas position
    plate.set_editor_property("render_transform", t)
    ls = label.get_editor_property("slot")
    ls.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_CENTER)
    ls.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
    ls.set_editor_property("padding", unreal.Margin(0, 0, 0, 0))
    # ---- the graph
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    nodes = list(ed.list_all_nodes())
    sv = [n for n in nodes if title(n).startswith("SetVisibility")]
    def from_label(n):
        return any("CorruptionLabel" in title(f) for f in feeders(n, "self"))
    def from_label_parent(n):
        return any(title(f).startswith("GetParent") and any("CorruptionLabel" in title(g) for g in feeders(f, "self")) for f in feeders(n, "self"))
    originals = [n for n in sv if from_label(n)]
    if any(from_label_parent(n) for n in sv):
        say("graph: the plate's SetVisibility nodes are there — skipped")
    else:
        if len(originals) != 2:
            raise RuntimeError("expected the game's 2 SetVisibility(CorruptionLabel), got %d — NOT saved" % len(originals))
        for n in originals:
            value = str(pins.get_pin_value(inp(n, "InVisibility")))
            getter = ed.add_get_member_variable_node("CorruptionLabel")
            par = call(ed, "/Script/UMG.Widget:GetParent")
            link(out(getter, "CorruptionLabel"), inp(par, "self"), "label -> GetParent")
            ours = call(ed, "/Script/UMG.Widget:SetVisibility")
            link(out(par, "ReturnValue"), inp(ours, "self"), "GetParent -> SetVisibility.self")
            if not pins.set_pin_value(inp(ours, "InVisibility"), value):
                raise RuntimeError("literal %s refused — NOT saved" % value)
            then = out(n, "then")
            nxt = list(pins.list_connected_pins(then))
            for q in nxt:
                pins.break_single_pin_link(then, q)
            link(then, inp(ours, "execute"), "game SetVisibility(%s) -> plate" % value)
            for q in nxt:
                link(out(ours, "then"), q, "plate -> the game's next node")
            say("plate follows the label: %s" % value)
    ok = lib.compile_blueprint(bp)
    say("compile: %s" % ok)
    if not ok:
        raise RuntimeError("compile failed — NOT saved (LogBlueprint: Error in the editor log)")
    res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    res["ok"] = bool(res["saved"])
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
