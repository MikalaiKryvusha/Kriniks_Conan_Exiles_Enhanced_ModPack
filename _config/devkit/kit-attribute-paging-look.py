# kit-attribute-paging-look.py — KUMM plan 49 step 2, the LOOK of mockup V8 (accepted by the owner 2026-11-10 10:27 «макет принят, делаем в игре, шикарно!»;
# the spec with numbers — plan 49 «ACCEPTED 2026-11-10 10:27 — V8»). Runs on W_Attribute AFTER kit-attribute-paging-step2.py:
#   * the arrows Btn_KrinikPagePrev / Btn_KrinikPageNext draw the diamond textures T_KrinikPageArrow{L,R}{,Hover,Dim} (made by
#     _config/branding/make-page-arrows.py from the mockup's own geometry): Normal / Hovered / Pressed / Disabled brushes, each ImageSize ARROW_BTN square;
#     their old text glyph removed (since 2026-11-14 — the button sizes by the brush, a square diamond at every resolution);
#   * Txt_KrinikPage (child 4 of Progress) becomes the RIGHT number (the segment's end), a new Txt_KrinikPageLo (child 5) the LEFT one (its start):
#     PT Serif (the game's serif with Cyrillic), bronze, a drop shadow; the left number left-aligned, the right one right-aligned by its slot (the owner 10:46);
#   * places: arrows under the scale, numbers above it — slot alignment + render translation (the row's layout is untouched);
#   * UpdateView: the right number gets (Page+1)×allot (the «lo–hi» concat unlinked), the left number Page×allot+1 and its visibility with the pager; the arrows
#     SetIsEnabled(Page > 0) / SetIsEnabled(Page < maxPage) — a disabled Button draws the Dim brush (the owner 10:13 «тусклое неактивное состояние для стрелки»).
# Tree settings are applied on every run (idempotent values); the graph part runs once (marker: a SetIsEnabled node in UpdateView). Stops before the save on any
# failed link or compile. Run it TWICE before a build (the GUID trap of the new TextBlock).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [TESTED: 2026-11-14 · the square arrows (no glyph, ImageSize 34.27²): Q4–Q8 — 55 × 54 px at 4K, ≈ 26 × 26 at 1080p; re-run idempotent after step2 · KUMM testcases/reports/2026-11-14_conan-page-arrows-square-and-journeys-refresh.md]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
TREE = WIDGET + ".W_Attribute:WidgetTree"
PREV, NEXT, HI, LO = "Btn_KrinikPagePrev", "Btn_KrinikPageNext", "Txt_KrinikPage", "Txt_KrinikPageLo"
TEX = "/Game/Mods/KrinikConanUI/T_KrinikPageArrow"
FONT = "/Game/UI/Fonts/PT_Serif/PTSerif-Regular_Font"
SCALE = 2.094                          # 4K viewport scale: widget units = 4K px / SCALE
U = lambda px: px / SCALE              # noqa: E731 — mockup px (4K frame) → widget units
ARROW_BOX = U(55)                      # the diamond's full width in the mockup (2 × 26 + rim 3)
# the arrow BUTTON's square box = the old width (the emptied glyph's min width ARROW_BOX + the button slot's default padding 4 + 4 = 34.27 units, read live
# 2026-11-14 10:0x) — the same size and centre as before, now with the height equal to the width (KUMM TC_conan_page_arrows_square_2026-11-14)
ARROW_BTN = ARROW_BOX + 8.0
NUM_SIZE = 18                          # font size ≈ the mockup's 50 px em at 4K (50 / 2.094 px ≈ 18 pt at 96 dpi)
BRONZE = unreal.LinearColor(0.578, 0.242, 0.061, 1.0)   # sRGB (200, 135, 70) → linear; was (198, 158, 102) — the owner 11:01 «и цвет больше в бронзу»
SHADOW = unreal.LinearColor(0.0, 0.0, 0.0, 0.78)
# places, tuned by frames (4K px from the mockup; x relative to Progress' left / right edge, y relative to the bar line = Progress' centre)
# first build (10:40, 4K frame vs the mockup): left items 20 / 31 px too far left, right items 28 / 30 px too far right (on the pips at 20), arrows 8 px too
# high, numbers 9 px too low — corrected below
PREV_X, NEXT_X = U(68 - 27 + 20), U(64 - 27 + 28)
ARROW_Y = U(64 + 8)
# the owner 10:46 «поля левых цифр ровняй по левому краю» · «правых - по правому»: the left number is LEFT-justified at the edge where the centred «21» began
# (box edge + 34 px), the right one RIGHT-justified where the centred «40» ended — «1» and «21» start at one x, «20» and «40» end at one x
NUM_EDGE = U(34)
LO_X, HI_X = U(68 + 18 - 55 + 31) + NUM_EDGE, U(64 - 55 + 30) + NUM_EDGE
NUM_Y = U(-58 - 9)
KM = "/Script/Engine.KismetMathLibrary:"
KT = "/Script/Engine.KismetTextLibrary:"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-attribute-paging-look.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
steps, links_ok = [], []
INDEX = {}


def say(s):
    steps.append(s)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def linked(p):
    return list(pins.list_connected_pins(p))


def node_of(p):
    return pins.get_owning_node(p)


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
    links_ok.append((what, ok))
    if not ok:
        raise RuntimeError("link failed: %s — the asset is NOT saved" % what)


def literal(p, v):
    if not pins.set_pin_value(p, v):
        raise RuntimeError("literal %r refused by %s" % (v, pins.get_pin_name(p)))


def call(ed, path):
    for p in (path, path.replace(":", ".")):
        try:
            n = ed.add_call_function_node(p)
            if n:
                return n
        except Exception as e:
            say("call node %s ERR %s" % (p, e))
    raise RuntimeError("cannot create " + path)


def widget(name):
    return unreal.find_object(None, TREE + "." + name)


def translate(w, x, y):
    t = w.get_editor_property("render_transform")
    t.set_editor_property("translation", unreal.Vector2D(x, y))
    w.set_editor_property("render_transform", t)


# ---------------------------------------------------------------- the tree (every run)
def brush(tex_name):
    b = unreal.SlateBrush()
    tex = unreal.load_asset(TEX + tex_name)
    if tex is None:                                   # the glyph is removed below: a missing texture would leave an invisible, clickable arrow (judge F4)
        raise RuntimeError("texture %s%s missing — import the arrows first (make-page-arrows.py + import-logo-texture.py)" % (TEX, tex_name))
    b.set_editor_property("resource_object", tex)
    b.set_editor_property("draw_as", unreal.SlateBrushDrawType.IMAGE)
    b.set_editor_property("tint_color", unreal.SlateColor(unreal.LinearColor(1, 1, 1, 1)))
    # a Button with NO content takes its desired size from its style brush's ImageSize (SButton::ComputeDesiredSize) — the square box of the arrow
    # UE 5.x types ImageSize as FDeprecateSlateVector2D: a plain Vector2D is refused («Cannot nativize 'Vector2D' as 'DeprecateSlateVector2D'», run 1) and its
    # wrapper takes no positional arguments (run 2) — so the brush's own value is taken, its two fields set, and it is written back
    set_image_size(b, ARROW_BTN)
    return b


def set_image_size(b, side):
    v = b.get_editor_property("image_size")
    for names in (("x", "y"), ("X", "Y")):
        try:
            v.set_editor_property(names[0], side)
            v.set_editor_property(names[1], side)
            break
        except Exception as e:                         # noqa: BLE001 — the field spelling of this kit's wrapper is not known before the run
            say("image_size fields %s refused: %s" % (names, e))
    else:
        raise RuntimeError("cannot set ImageSize on the arrow brush")
    b.set_editor_property("image_size", v)
    # the struct's repr prints «{}» in this kit (judge 2026-11-14 P1) — read the two fields back, and stop if they did not take
    got = b.get_editor_property("image_size")
    gx, gy = got.get_editor_property(names[0]), got.get_editor_property(names[1])
    if abs(gx - side) > 0.01 or abs(gy - side) > 0.01:
        raise RuntimeError("ImageSize did not take: %.2f × %.2f, want %.2f" % (gx, gy, side))
    say("image_size set: %.2f × %.2f" % (gx, gy))


def style_arrow(name, side, halign, x):
    b = widget(name)
    st = b.get_editor_property("widget_style")
    for field, suffix in (("normal", ""), ("hovered", "Hover"), ("pressed", "Hover"), ("disabled", "Dim")):
        st.set_editor_property(field, brush(side + suffix))
    st.set_editor_property("normal_padding", unreal.Margin(0, 0, 0, 0))
    st.set_editor_property("pressed_padding", unreal.Margin(0, 0, 0, 0))
    b.set_editor_property("widget_style", st)
    # The old «‹ ›» TextBlock is REMOVED from the button (2026-11-14). Emptied, it sized the button: the width by its min width (26.27 + 8), the HEIGHT by
    # its font's line height (35.08 at size 19 + 4) — the square texture drew 34.27 × 39.08 and the diamond came out 12 % taller than wide (the owner
    # 2026-11-14 09:55 «наши стрелки листания проверь чтобы ромбы были ровными, не сплющенными»; native 4K frame: 55 × 61 px vs the game's «+» 70 × 70).
    # A font size fitted to the width snaps to device pixels (live: sizes 16 / 17 / 18 / 19 → 29.99 / 31.12 / 32.82 / 35.08) — off by a pixel at 1080p;
    # without content the button takes the brush's ImageSize, exact at every resolution (live 10:0x: 34.27 × 34.27 on visible and hidden rows).
    # No graph node reaches the TextBlock (the graph finds the arrows by Progress' child index); the saved asset keeps no trace of it (judge 2026-11-14 P3).
    # `remove_child` skips the editor's delete bookkeeping: the first run after the removal logs a handled ensure «Variable [Txt_Btn_KrinikPage…] was deleted
    # but still has a GUID referenced» (WidgetBlueprintCompiler.cpp:815) and the editor exits 1 while this report says ok — one-time, the GUID entries are
    # dropped on that save (judge P2). kit-attribute-paging-step2.py no longer re-adds a glyph to a button that already draws our diamond (its `arrow()`).
    glyph = b.get_content()
    if glyph:
        b.remove_child(glyph)
        say("arrow %s: glyph %s removed — the button sizes by its brush %.2f × %.2f" % (name, glyph.get_name(), ARROW_BTN, ARROW_BTN))
    s = b.get_editor_property("slot")
    s.set_editor_property("horizontal_alignment", halign)
    s.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
    s.set_editor_property("padding", unreal.Margin(x, 0, 0, 0) if halign == unreal.HorizontalAlignment.H_ALIGN_LEFT else unreal.Margin(0, 0, x, 0))
    translate(b, 0, ARROW_Y)
    say("arrow %s styled" % name)


def style_number(t, halign, x):
    f = t.get_editor_property("font")
    f.set_editor_property("font_object", unreal.load_asset(FONT))
    f.set_editor_property("typeface_font_name", "Regular")
    f.size = NUM_SIZE
    # PT Serif has no bold face in the game; the 1-unit outline made it too heavy — the owner 11:00 «шрифт не очень, слишком тяжелый вес, на -200 бы»:
    # the plain Regular face, no outline (an outline is whole units — none thinner than 1)
    o = f.get_editor_property("outline_settings")
    o.set_editor_property("outline_size", 0)
    o.set_editor_property("outline_color", BRONZE)
    f.set_editor_property("outline_settings", o)
    t.set_editor_property("font", f)
    t.set_editor_property("color_and_opacity", unreal.SlateColor(BRONZE))
    t.set_editor_property("shadow_offset", unreal.Vector2D(1.0, 1.5))
    t.set_editor_property("shadow_color_and_opacity", SHADOW)
    t.set_editor_property("min_desired_width", 0.0)
    t.set_editor_property("justification", unreal.TextJustify.LEFT if halign == unreal.HorizontalAlignment.H_ALIGN_LEFT else unreal.TextJustify.RIGHT)
    s = t.get_editor_property("slot")
    s.set_editor_property("horizontal_alignment", halign)
    s.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
    s.set_editor_property("padding", unreal.Margin(x, 0, 0, 0) if halign == unreal.HorizontalAlignment.H_ALIGN_LEFT else unreal.Margin(0, 0, x, 0))
    translate(t, 0, NUM_Y)


def build_tree():
    tree = unreal.find_object(None, TREE)
    progress = widget("Progress")
    for n in (PREV, NEXT, HI):
        if not widget(n):
            raise RuntimeError("%s missing — run kit-attribute-paging-step2.py first" % n)
    style_arrow(PREV, "L", unreal.HorizontalAlignment.H_ALIGN_LEFT, PREV_X)
    style_arrow(NEXT, "R", unreal.HorizontalAlignment.H_ALIGN_RIGHT, NEXT_X)
    lo = widget(LO)
    if not lo:
        lo = unreal.new_object(unreal.TextBlock, outer=tree, name=LO)
        lo.set_text(unreal.Text("21"))
        lo.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)
        progress.add_child_to_overlay(lo)
        say("tree: %s created" % LO)
    style_number(widget(HI), unreal.HorizontalAlignment.H_ALIGN_RIGHT, HI_X)
    style_number(lo, unreal.HorizontalAlignment.H_ALIGN_LEFT, LO_X)
    for n in (PREV, NEXT, HI, LO):
        INDEX[n] = progress.get_child_index(widget(n))
    if INDEX[PREV] != 2 or INDEX[NEXT] != 3 or INDEX[HI] != 4 or INDEX[LO] < 5:
        raise RuntimeError("unexpected child order %s" % INDEX)
    say("children: %s" % INDEX)


# ---------------------------------------------------------------- the graph (once)
def child_ref(ed, i, x, y):
    plus = ed.add_get_member_variable_node("LevelAttributeButton")
    parent = call(ed, "/Script/UMG.Widget:GetParent")
    link(out(plus, "LevelAttributeButton"), inp(parent, "self"), "+ -> GetParent")
    child = call(ed, "/Script/UMG.PanelWidget:GetChildAt")
    link(out(parent, "ReturnValue"), inp(child, "self"), "Progress -> GetChildAt")
    literal(inp(child, "Index"), str(i))
    for k, n in enumerate((plus, parent, child)):
        lib.set_node_pos(n, unreal.IntPoint(x + 160 * k, y))
    return out(child, "ReturnValue")


def graph(bp):
    ed = ged.get_graph_editor_by_name(bp, "UpdateView")
    nodes = list(ed.list_all_nodes())
    if any("IsEnabled" in title(n) or "Is Enabled" in title(n) for n in nodes):
        say("UpdateView: the look part is already there — skipped")
        return
    # our label SetText = the «SetText (Text)» whose self comes from a Cast node
    lbl = [n for n in nodes if title(n) == "SetText (Text)" and any(cls(node_of(p)) == "K2Node_DynamicCast" for p in linked(inp(n, "self")))]
    if len(lbl) != 1:
        raise RuntimeError("label SetText nodes: %d" % len(lbl))
    lbl = lbl[0]
    txt = node_of(linked(inp(lbl, "InText"))[0])                 # Conv_StringToText
    c2 = node_of(linked(inp(txt, "InString"))[0])                # Concat(c1, s_hi)
    s_hi = linked(inp(c2, "B"))[0]
    c1 = node_of(linked(inp(c2, "A"))[0])                        # Concat(s_lo, «–»)
    s_lo = linked(inp(c1, "A"))[0]
    pins.break_single_pin_link(out(c2, "ReturnValue"), inp(txt, "InString"))
    link(s_hi, inp(txt, "InString"), "hi string -> the right number")
    br_pips = [node_of(p) for p in linked(out(lbl, "then"))]
    if len(br_pips) != 1 or cls(br_pips[0]) != "K2Node_IfThenElse":
        raise RuntimeError("after the label: %s" % [title(n) for n in br_pips])
    br_pips = br_pips[0]
    feeders = linked(inp(br_pips, "execute"))
    pager_off = [p for p in feeders if title(node_of(p)) == "SetVisibility"]
    if len(pager_off) != 1:
        raise RuntimeError("pager-off feeders: %s" % [title(node_of(p)) for p in feeders])
    pager_off = pager_off[0]
    # maxPage by its links, not its title (the kit titles it otherwise — run 1): Set Page ← Clamp ← its Max input
    sets = [n for n in nodes if cls(n) == "K2Node_VariableSet" and "Page" in title(n)]
    if len(sets) != 1:
        raise RuntimeError("Set Page nodes: %d" % len(sets))
    clamp = node_of(linked(inp(sets[0], "Page"))[0])
    mx_pin = linked(inp(clamp, "Max"))[0]
    x0, y0 = 2400, -1600
    # on: label → Lo visible → cast Lo → SetText(Lo) → SetIsEnabled(Prev) → SetIsEnabled(Next) → the pips branch
    pins.break_single_pin_link(out(lbl, "then"), inp(br_pips, "execute"))
    vis_on = call(ed, "/Script/UMG.Widget:SetVisibility")
    link(child_ref(ed, INDEX[LO], x0, y0 + 160), inp(vis_on, "self"), "Lo -> SetVisibility")
    literal(inp(vis_on, "InVisibility"), "SelfHitTestInvisible")
    link(out(lbl, "then"), inp(vis_on, "execute"), "label -> Lo visible")
    names = [n for n in [str(s) for s in ed.list_available_nodes([])] if n.split("|")[-1].replace(" ", "").lower() == "casttotextblock"]
    if not names:
        raise RuntimeError("no Cast To TextBlock in the catalog")
    cast = ed.create_node_from_name(names[0], unreal.Vector2D(x0 + 500, y0), [])
    if not cast:
        raise RuntimeError("Cast To TextBlock not created")
    obj = [p for p in lib.list_all_pins(cast) if str(pins.get_pin_name(p)) == "Object"][0]
    as_t = [p for p in lib.list_all_pins(cast, unreal.EdGraphPinDirection.EGPD_OUTPUT) if str(pins.get_pin_name(p)).startswith("As")][0]
    link(child_ref(ed, INDEX[LO], x0 + 300, y0 + 320), obj, "Lo -> cast")
    link(out(vis_on, "then"), inp(cast, "execute"), "Lo visible -> cast")
    set_lo = call(ed, "/Script/UMG.TextBlock:SetText")
    link(as_t, inp(set_lo, "self"), "cast -> SetText(Lo)")
    lo_txt = call(ed, KT + "Conv_StringToText")
    link(s_lo, inp(lo_txt, "InString"), "lo string -> text")
    link(out(lo_txt, "ReturnValue"), inp(set_lo, "InText"), "text -> SetText(Lo)")
    link(out(cast, "then"), inp(set_lo, "execute"), "cast -> SetText(Lo)")
    g_page = ed.add_get_member_variable_node("Page")
    en_prev = call(ed, "/Script/UMG.Widget:SetIsEnabled")
    link(child_ref(ed, INDEX[PREV], x0 + 900, y0 + 160), inp(en_prev, "self"), "Prev -> SetIsEnabled")
    gt = call(ed, KM + "Greater_IntInt")
    link(out(g_page, "Page"), inp(gt, "A"), "Page -> > 0")
    literal(inp(gt, "B"), "0")
    link(out(gt, "ReturnValue"), inp(en_prev, "bInIsEnabled"), "> 0 -> Prev enabled")
    link(out(set_lo, "then"), inp(en_prev, "execute"), "SetText(Lo) -> Prev enabled")
    link(out(cast, "CastFailed"), inp(en_prev, "execute"), "cast failed -> Prev enabled")
    en_next = call(ed, "/Script/UMG.Widget:SetIsEnabled")
    link(child_ref(ed, INDEX[NEXT], x0 + 1300, y0 + 160), inp(en_next, "self"), "Next -> SetIsEnabled")
    lt = call(ed, KM + "Less_IntInt")
    link(out(g_page, "Page"), inp(lt, "A"), "Page -> < max")
    link(mx_pin, inp(lt, "B"), "maxPage -> < max")
    link(out(lt, "ReturnValue"), inp(en_next, "bInIsEnabled"), "< max -> Next enabled")
    link(out(en_prev, "then"), inp(en_next, "execute"), "Prev -> Next enabled")
    link(out(en_next, "then"), inp(br_pips, "execute"), "Next enabled -> the pips branch")
    # off: the pager-off chain → Lo collapsed → the pips branch
    pins.break_single_pin_link(pager_off, inp(br_pips, "execute"))
    vis_off = call(ed, "/Script/UMG.Widget:SetVisibility")
    link(child_ref(ed, INDEX[LO], x0, y0 + 700), inp(vis_off, "self"), "Lo -> SetVisibility(off)")
    literal(inp(vis_off, "InVisibility"), "Collapsed")
    link(pager_off, inp(vis_off, "execute"), "pager off -> Lo collapsed")
    link(out(vis_off, "then"), inp(br_pips, "execute"), "Lo collapsed -> the pips branch")
    for k, n in enumerate((vis_on, cast, set_lo, lo_txt, g_page, en_prev, gt, en_next, lt, vis_off)):
        lib.set_node_pos(n, unreal.IntPoint(x0 + 200 * k, y0 - 300))
    say("UpdateView: the look part built")


res = {"ok": False}
try:
    bp = unreal.load_asset(WIDGET)
    build_tree()
    say("compile after the tree: %s" % lib.compile_blueprint(bp))
    graph(bp)
    compiled = lib.compile_blueprint(bp)
    say("compile: %s" % compiled)
    if not compiled:
        raise RuntimeError("the blueprint does not compile — the asset is NOT saved (LogBlueprint: Error in the editor log)")
    say("save: %s" % unreal.EditorAssetLibrary.save_loaded_asset(bp, False))
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
res["links"] = links_ok
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
