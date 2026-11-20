# kit-attribute-paging-step2.py — KUMM plan 49 B2, step 2: the arrows ‹ › at the ends of an attribute row past one page, the window label «21–40», and the
# perk pips hidden on pages past the first (the game has no perks there yet). The owner's pick 2026-11-09 19:58 (B2, verbatim in plan 49). Step 1
# (kit-attribute-paging-edit.py) gave W_Attribute the int member `Page` and the shift FullValue − Page × MaxAttributePointAllotment in UpdateView.
# A page is MaxAttributePointAllotment points wide (20 in the game; every formula here reads the member).
#
# The shape (one place for the logic — UpdateView, the game's own function every refresh passes through):
#   * tree: Btn_KrinikPagePrev (right of the «+», which sits H_ALIGN_LEFT in `Progress`) and Btn_KrinikPageNext (the right end), each with a TextBlock ‹ / ›,
#     and Txt_KrinikPage (the label, right, inside the bar) — children 2, 3, 4 of `Progress`;
#   * UpdateView prefix: Page = Clamp(Page, 0, max(0, (FullValue − 1) / allot)); arrows + label shown only when that max > 0, the label «Page×allot+1–(Page+1)×allot»;
#     the pips' canvas `AttributeCanvas` shown only on page 0;
#   * Construct: «Bind Event to On Clicked» with our named custom events KrinikPagePrevClicked / KrinikPageNextClicked; each sets Page ∓ 1 and flows into the
#     game's own «Call Signal Request Attribute View Update» node after PostPipsPlacedOnCanvas — the window re-reads the stats and calls UpdateView, so the bar,
#     the value and the corruption bar stay the game's (HOUSE_RULES rule 24);
#   * the wheel (`wheel()`, behind KIT_TRY_WHEEL=1) is NOT built: the kit returns no «Call On Clicked» node in a function graph (runs 7–8).
# The graphs reach our widgets as `<BP variable>.GetParent().GetChildAt(<index>)`; the indices are read from the tree at edit time and baked into the graph —
# a rebuilt `Progress` (a game update replacing the asset) needs this script re-run on the new asset, never a hand edit.
# Idempotent per part (a part already present is skipped and said so); any failed link or compile stops the run BEFORE the save. Run it TWICE before a build
# (the GUID trap of new widgets — KrinikConanUI.md «Kit Python traps»).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-attribute-paging-step2.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
TREE = WIDGET + ".W_Attribute:WidgetTree"
PAGE_VAR = "Page"
ALLOT = "MaxAttributePointAllotment"
PREV, NEXT, LABEL = "Btn_KrinikPagePrev", "Btn_KrinikPageNext", "Txt_KrinikPage"
PIPS = "AttributeCanvas"
PLUS_GAP = 56          # the Prev arrow stands this far right of the bar's LEFT edge — the «+» (LevelAttributeButton) is H_ALIGN_LEFT there (run 1); tuned by a frame
ARROW_SIZE = 26        # the arrows' font size; the label is LABEL_SIZE
LABEL_SIZE = 16
LABEL_GAP = 40         # the label's right padding — left of the Next arrow
DASH = "\u2013"        # «21–40»
KM = "/Script/Engine.KismetMathLibrary:"
KS = "/Script/Engine.KismetStringLibrary:"
KT = "/Script/Engine.KismetTextLibrary:"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-attribute-paging-step2.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
steps = []
links_ok = []


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


CATALOG = {}   # graph name -> the node names the kit offers there (one list_available_nodes per graph; 60 000 names)


def action(ed, graph, words, pick=None):
    # a node by its catalog name (the kit's palette is localized — matched by the Latin parts); `pick` narrows the hits; exactly one or the run stops
    if graph not in CATALOG:
        CATALOG[graph] = [str(n) for n in ed.list_available_nodes([])]
    def norm(t):
        return t.replace(" ", "").lower()   # the catalog spells some names with spaces («Signal Request …», run 5) and some without («AssignOnClicked»)
    found = sorted(set(n for n in CATALOG[graph] if all(norm(w) in norm(n) for w in words)))
    hits = [h for h in found if pick(h)] if pick else found
    if len(hits) != 1:
        raise RuntimeError("catalog %s %s -> %d of %d: %s" % (graph, words, len(hits), len(found), found[:30]))
    return hits[0]


VIS = {"VISIBLE": "Visible", "COLLAPSED": "Collapsed", "HIDDEN": "Hidden", "HIT_TEST_INVISIBLE": "HitTestInvisible",
       "SELF_HIT_TEST_INVISIBLE": "SelfHitTestInvisible"}   # the Python enum name -> the pin's literal


def pos(n, x, y):
    lib.set_node_pos(n, unreal.IntPoint(x, y))


def widget(name):
    return unreal.find_object(None, TREE + "." + name)


# ---------------------------------------------------------------- part A: the widgets
def as_variable(w):
    # bIsVariable is editor-only and not reflected to Python in this kit (run 1, 09:17) — a widget made by new_object is a variable by the UWidget default;
    # the graphs' member getters below prove it (a getter of a non-variable widget fails and stops the run before the save)
    try:
        w.set_editor_property("is_variable", True)
    except Exception:
        say("is_variable not settable on %s — relying on the default" % w.get_name())


def text_block(tree, name, text, size, base_font):
    tb = widget(name)
    if tb:
        say("tree: %s reused" % name)
        return tb
    tb = unreal.new_object(unreal.TextBlock, outer=tree, name=name)
    f = base_font
    f.size = size
    tb.set_editor_property("font", f)
    tb.set_text(unreal.Text(text))
    tb.set_editor_property("color_and_opacity", unreal.SlateColor(unreal.LinearColor(1.0, 1.0, 1.0, 1.0)))
    tb.set_editor_property("shadow_offset", unreal.Vector2D(1.0, 1.0))
    tb.set_editor_property("shadow_color_and_opacity", unreal.LinearColor(0.0, 0.0, 0.0, 0.85))
    say("tree: %s created" % name)
    return tb


def arrow(tree, pager, name, glyph, base_font, halign, pad):
    b = widget(name)
    if not b:
        b = unreal.new_object(unreal.Button, outer=tree, name=name)
        style = b.get_editor_property("widget_style")
        for field, alpha in (("normal", 0.0), ("hovered", 0.18), ("pressed", 0.30)):
            br = unreal.SlateBrush()
            br.draw_as = unreal.SlateBrushDrawType.NO_DRAW_TYPE if alpha == 0.0 else unreal.SlateBrushDrawType.ROUNDED_BOX
            br.tint_color = unreal.SlateColor(unreal.LinearColor(1.0, 1.0, 1.0, alpha))
            style.set_editor_property(field, br)
        style.set_editor_property("normal_padding", unreal.Margin(6, 0, 6, 0))
        style.set_editor_property("pressed_padding", unreal.Margin(6, 0, 6, 0))
        b.set_editor_property("widget_style", style)
        b.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)   # UpdateView shows it past 20
        as_variable(b)
        slot = pager.add_child_to_overlay(b)
        slot.set_editor_property("horizontal_alignment", halign)
        slot.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
        slot.set_editor_property("padding", pad)
        say("tree: %s created" % name)
    else:
        say("tree: %s reused" % name)
    # Since 2026-11-14 kit-attribute-paging-look.py REMOVES this glyph: the button draws our diamond and sizes itself by the brush (a square at every
    # resolution). Re-adding a glyph here would bring back a white «‹ ›» over the diamond and a non-square button (judge 2026-11-14 P3) — so a button whose
    # normal brush already draws a T_KrinikPageArrow texture stays without content.
    normal = b.get_editor_property("widget_style").get_editor_property("normal").get_editor_property("resource_object")
    looked = normal is not None and normal.get_name().startswith("T_KrinikPageArrow")
    if not b.get_content() and not looked:
        b.set_content(text_block(tree, "Txt_" + name, glyph, ARROW_SIZE, base_font))
    elif looked:
        say("tree: %s draws the diamond — no glyph added (the look pass owns the content)" % name)
    return b


def build_tree():
    tree = unreal.find_object(None, TREE)
    progress = widget("Progress")
    plus = widget("LevelAttributeButton")
    t_current = widget("T_Current")
    if not (tree and progress and plus and t_current):
        raise RuntimeError("tree pieces missing: tree %s progress %s plus %s T_Current %s" % (bool(tree), bool(progress), bool(plus), bool(t_current)))
    ps = plus.get_editor_property("slot")
    say("the «+» slot: halign %s valign %s padding %s" % (ps.get_editor_property("horizontal_alignment"), ps.get_editor_property("vertical_alignment"),
                                                      ps.get_editor_property("padding")))
    # our three widgets go straight into the row's `Progress` overlay (the \u00ab+\u00bb is its child too); the graphs reach them as children of the \u00ab+\u00bb's
    # parent by index \u2014 the kit takes no FName literal on GetWidgetFromName (run 3, 09:23) and new widgets are no variables (run 2)
    base = t_current.get_editor_property("font")
    arrow(tree, progress, PREV, "\u2039", base, unreal.HorizontalAlignment.H_ALIGN_LEFT, unreal.Margin(PLUS_GAP, 0, 0, 0))
    arrow(tree, progress, NEXT, "\u203a", t_current.get_editor_property("font"), unreal.HorizontalAlignment.H_ALIGN_RIGHT, unreal.Margin(0, 0, 0, 0))
    lbl = widget(LABEL)
    if not lbl:
        lbl = text_block(tree, LABEL, "21" + DASH + "40", LABEL_SIZE, t_current.get_editor_property("font"))
        as_variable(lbl)
        lbl.set_editor_property("visibility", unreal.SlateVisibility.COLLAPSED)
        s = progress.add_child_to_overlay(lbl)
        s.set_editor_property("horizontal_alignment", unreal.HorizontalAlignment.H_ALIGN_RIGHT)
        s.set_editor_property("vertical_alignment", unreal.VerticalAlignment.V_ALIGN_CENTER)
        s.set_editor_property("padding", unreal.Margin(0, 0, LABEL_GAP, 0))
    for name in (PREV, NEXT, LABEL):
        INDEX[name] = progress.get_child_index(widget(name))
        if INDEX[name] < 0:
            raise RuntimeError("%s is not a child of Progress" % name)
    if plus.get_parent() != progress:   # the graphs reach Progress as the «+»'s parent (judge 2026-11-10)
        raise RuntimeError("LevelAttributeButton's parent is not Progress")
    pips = widget(PIPS)
    bar = widget("IPB_ProgressBar")
    if not pips or not bar or bar.get_parent() != pips.get_parent():
        raise RuntimeError("AttributeCanvas and IPB_ProgressBar do not share a parent")
    INDEX[PIPS] = pips.get_parent().get_child_index(pips)
    say("children: %s" % INDEX)
    v = pips.get_editor_property("visibility")
    say("pips canvas visibility (vanilla): %s" % v)
    return VIS[str(v).split(".")[-1].split(":")[0].strip("<> ").upper()]


# ---------------------------------------------------------------- part B: UpdateView — clamp, pager, label, pips
INDEX = {}   # our widget -> its child index in `Progress` (filled by build_tree)


def widget_ref(ed, name, x, y):
    # our widget = Progress.GetChildAt(INDEX), Progress = the «+» button's parent. The widgets made by new_object are no blueprint variables
    # (bIsVariable is not reflected to the kit's Python; run 2, 09:20) and GetWidgetFromName takes no FName literal here (run 3, 09:23);
    # the «+» `LevelAttributeButton` IS a variable (the game binds its OnClicked). AttributeCanvas is the native parent's property, not readable by a
    # blueprint (run 9 compile error) — it is reached as a child of `Overlay_3` = the parent of the BP variable `IPB_ProgressBar`.
    anchor = "IPB_ProgressBar" if name == PIPS else "LevelAttributeButton"
    plus = ed.add_get_member_variable_node(anchor)
    parent = call(ed, "/Script/UMG.Widget:GetParent")
    link(out(plus, anchor), inp(parent, "self"), "%s -> GetParent" % anchor)
    child = call(ed, "/Script/UMG.PanelWidget:GetChildAt")
    link(out(parent, "ReturnValue"), inp(child, "self"), "Progress -> GetChildAt")
    literal(inp(child, "Index"), str(INDEX[name]))
    pos(plus, x - 400, y)
    pos(parent, x - 250, y)
    pos(child, x - 100, y)
    return out(child, "ReturnValue")


def cast_to(ed, graph, klass, obj_pin, x, y):
    # an exec «Cast To <klass>» node fed by obj_pin; returns (node, its typed output pin)
    n = ed.create_node_from_name(action(ed, graph, ["Castto" + klass], lambda h: h.split("|")[-1].lower() == ("castto" + klass).lower()),
                                 unreal.Vector2D(x, y), [])
    if not n:
        raise RuntimeError("no Cast To %s node" % klass)
    obj = [p for p in lib.list_all_pins(n) if str(pins.get_pin_name(p)) == "Object"]
    # the typed output is «As<display name>» — «AsText» for TextBlock (run 4, 09:27), so match the prefix, not the class name
    typed = [p for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_OUTPUT) if str(pins.get_pin_name(p)).startswith("As")]
    if not obj or not typed:
        raise RuntimeError("Cast To %s pins: %s" % (klass, [str(pins.get_pin_name(p)) for p in lib.list_all_pins(n)]))
    link(obj_pin, obj[0], "-> Cast To %s" % klass)
    return n, typed[0]


def vis_node(ed, member, value, x, y):
    n = call(ed, "/Script/UMG.Widget:SetVisibility")
    link(widget_ref(ed, member, x, y + 160), inp(n, "self"), "%s -> SetVisibility.self" % member)
    literal(inp(n, "InVisibility"), value)
    pos(n, x + 260, y)
    return n


def update_view(bp, pips_on):
    ed = ged.get_graph_editor_by_name(bp, "UpdateView")
    nodes = list(ed.list_all_nodes())
    if any(cls(n) == "K2Node_VariableSet" and PAGE_VAR in title(n) for n in nodes):
        say("UpdateView: the prefix is already there — skipped")
        return
    entry = [n for n in nodes if cls(n) == "K2Node_FunctionEntry"][0]
    then = out(entry, "then")
    first = linked(then)
    if len(first) != 1 or title(node_of(first[0])) != "SetText (Text)":
        raise RuntimeError("UpdateView: unexpected first node %s" % [title(node_of(p)) for p in first])
    first = first[0]
    x0, y0 = -688, -900
    full = out(entry, "FullValue")
    allot = ed.add_get_member_variable_node(ALLOT)
    sub1 = call(ed, KM + "Subtract_IntInt")
    link(full, inp(sub1, "A"), "FullValue -> (FullValue - 1)")
    literal(inp(sub1, "B"), "1")
    div = call(ed, KM + "Divide_IntInt")
    link(out(sub1, "ReturnValue"), inp(div, "A"), "-> / allot")
    link(out(allot, ALLOT), inp(div, "B"), "allot -> /")
    mx = call(ed, KM + "Max")
    link(out(div, "ReturnValue"), inp(mx, "A"), "-> max(.,0)")
    literal(inp(mx, "B"), "0")
    g_page = ed.add_get_member_variable_node(PAGE_VAR)
    clamp = call(ed, KM + "Clamp")
    link(out(g_page, PAGE_VAR), inp(clamp, "Value"), "Page -> Clamp")
    literal(inp(clamp, "Min"), "0")
    link(out(mx, "ReturnValue"), inp(clamp, "Max"), "maxPage -> Clamp.Max")
    set_page = ed.add_set_member_variable_node(PAGE_VAR)
    link(out(clamp, "ReturnValue"), inp(set_page, PAGE_VAR), "Clamp -> Set Page")
    pins.break_single_pin_link(then, first)
    link(then, inp(set_page, "execute"), "entry -> Set Page")
    # the pager: shown only when the attribute has a page past 1–20
    gt = call(ed, KM + "Greater_IntInt")
    link(out(mx, "ReturnValue"), inp(gt, "A"), "maxPage -> > 0")
    literal(inp(gt, "B"), "0")
    br_pager = ed.add_branch_node()
    link(out(set_page, "then"), inp(br_pager, "execute"), "Set Page -> branch pager")
    link(out(gt, "ReturnValue"), inp(br_pager, "Condition"), "> 0 -> branch")
    # the pager = the two arrows and the label, each its own SetVisibility (Visible for the clickable arrows, SelfHitTestInvisible for the label)
    on_chain = [vis_node(ed, PREV, "Visible", x0 + 1400, y0), vis_node(ed, NEXT, "Visible", x0 + 1700, y0),
                vis_node(ed, LABEL, "SelfHitTestInvisible", x0 + 2000, y0)]
    off_chain = [vis_node(ed, nm, "Collapsed", x0 + 1400 + 300 * k, y0 + 300) for k, nm in enumerate((PREV, NEXT, LABEL))]
    for chain in (on_chain, off_chain):
        for a, b in zip(chain, chain[1:]):
            link(out(a, "then"), inp(b, "execute"), "pager chain")
    link(out(br_pager, "then"), inp(on_chain[0], "execute"), "branch true -> pager on")
    link(out(br_pager, "else"), inp(off_chain[0], "execute"), "branch false -> pager off")
    pager_on, pager_off = on_chain[-1], off_chain[-1]
    # the label «lo–hi», lo = Page × allot + 1, hi = (Page + 1) × allot — Page read after the Set (a pure getter is evaluated at its consumer)
    g_p2 = ed.add_get_member_variable_node(PAGE_VAR)
    g_a2 = ed.add_get_member_variable_node(ALLOT)
    mul = call(ed, KM + "Multiply_IntInt")
    link(out(g_p2, PAGE_VAR), inp(mul, "A"), "Page -> *")
    link(out(g_a2, ALLOT), inp(mul, "B"), "allot -> *")
    lo = call(ed, KM + "Add_IntInt")
    link(out(mul, "ReturnValue"), inp(lo, "A"), "* -> lo")
    literal(inp(lo, "B"), "1")
    hi = call(ed, KM + "Add_IntInt")
    link(out(mul, "ReturnValue"), inp(hi, "A"), "* -> hi")
    link(out(g_a2, ALLOT), inp(hi, "B"), "allot -> hi")
    s_lo = call(ed, KS + "Conv_IntToString")
    link(out(lo, "ReturnValue"), inp(s_lo, "InInt"), "lo -> str")
    s_hi = call(ed, KS + "Conv_IntToString")
    link(out(hi, "ReturnValue"), inp(s_hi, "InInt"), "hi -> str")
    c1 = call(ed, KS + "Concat_StrStr")
    link(out(s_lo, "ReturnValue"), inp(c1, "A"), "lo str -> concat")
    literal(inp(c1, "B"), DASH)
    c2 = call(ed, KS + "Concat_StrStr")
    link(out(c1, "ReturnValue"), inp(c2, "A"), "concat -> concat")
    link(out(s_hi, "ReturnValue"), inp(c2, "B"), "hi str -> concat")
    txt = call(ed, KT + "Conv_StringToText")
    link(out(c2, "ReturnValue"), inp(txt, "InString"), "str -> text")
    cast_lbl, as_tb = cast_to(ed, "UpdateView", "TextBlock", widget_ref(ed, LABEL, x0 + 1700, y0 - 300), x0 + 1900, y0)
    link(out(pager_on, "then"), inp(cast_lbl, "execute"), "pager on -> cast label")
    set_txt = call(ed, "/Script/UMG.TextBlock:SetText")
    link(as_tb, inp(set_txt, "self"), "label -> SetText.self")
    link(out(txt, "ReturnValue"), inp(set_txt, "InText"), "text -> SetText")
    link(out(cast_lbl, "then"), inp(set_txt, "execute"), "cast label -> SetText")
    # the pips: only on page 0 (the game has no perks past 20; future perks past 20 will need their own placement — plan 49)
    g_p3 = ed.add_get_member_variable_node(PAGE_VAR)
    eq = call(ed, KM + "EqualEqual_IntInt")
    link(out(g_p3, PAGE_VAR), inp(eq, "A"), "Page -> == 0")
    literal(inp(eq, "B"), "0")
    br_pips = ed.add_branch_node()
    link(out(set_txt, "then"), inp(br_pips, "execute"), "label -> branch pips")
    link(out(cast_lbl, "CastFailed"), inp(br_pips, "execute"), "cast label failed -> branch pips")
    link(out(pager_off, "then"), inp(br_pips, "execute"), "pager off -> branch pips")
    link(out(eq, "ReturnValue"), inp(br_pips, "Condition"), "== 0 -> branch pips")
    pips_show = vis_node(ed, PIPS, pips_on, x0 + 3000, y0)
    pips_hide = vis_node(ed, PIPS, "Hidden", x0 + 3000, y0 + 300)
    link(out(br_pips, "then"), inp(pips_show, "execute"), "page 0 -> pips on")
    link(out(br_pips, "else"), inp(pips_hide, "execute"), "page > 0 -> pips hidden")
    link(out(pips_show, "then"), first, "pips on -> the game's SetText")
    link(out(pips_hide, "then"), first, "pips hidden -> the game's SetText")
    for i, n in enumerate((allot, sub1, div, mx, g_page, clamp, set_page, gt, br_pager)):
        pos(n, x0 + 160 * i, y0 - 400)
    for i, n in enumerate((g_p2, g_a2, mul, lo, hi, s_lo, s_hi, c1, c2, txt, set_txt, g_p3, eq, br_pips)):
        pos(n, x0 + 1700 + 160 * i, y0 - 700)
    say("UpdateView: prefix built")


# ---------------------------------------------------------------- part C: clicks and wheel → Page ∓ 1 → the game's refresh signal
def game_signal_node(nodes):
    # the game's own «Call Signal Request Attribute View Update» after PostPipsPlacedOnCanvas — a node with nothing after it; our clicks flow INTO it.
    # The kit's catalog offers no call of this dispatcher (runs 5–6: 0 names), and an exec input takes any number of links, so the existing node is reused.
    for n in nodes:
        if cls(n) == "K2Node_CallDelegate" and "Signal Request Attribute View Update" in title(n) and not linked(out(n, "then")):
            src = [title(node_of(p)) for p in linked(inp(n, "execute"))]
            if any("PostPipsPlacedOnCanvas" in t for t in src):
                return n
    raise RuntimeError("the game's PostPips signal node is not found")


def page_step(ed, after_exec, delta_literal, sig, x, y):
    # Set Page = Page + delta → the game's refresh signal (the window re-reads the stats and calls UpdateView, which clamps Page)
    g = ed.add_get_member_variable_node(PAGE_VAR)
    add = call(ed, KM + "Add_IntInt")
    link(out(g, PAGE_VAR), inp(add, "A"), "Page -> +")
    literal(inp(add, "B"), delta_literal)
    s = ed.add_set_member_variable_node(PAGE_VAR)
    link(out(add, "ReturnValue"), inp(s, PAGE_VAR), "+ -> Set Page")
    link(after_exec, inp(s, "execute"), "event -> Set Page")
    link(out(s, "then"), inp(sig, "execute"), "Set Page -> the game's signal")
    pos(g, x, y + 120)
    pos(add, x + 150, y + 120)
    pos(s, x + 350, y)


def clicks(bp):
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    nodes = list(ed.list_all_nodes())
    # our click events are custom events named Krinik…Clicked (the game's «+» is a component-bound event)
    if any(cls(n) == "K2Node_CustomEvent" and "Krinik" in title(n) for n in nodes):
        say("EventGraph: the arrow clicks are already there — skipped")
        return
    sig = game_signal_node(nodes)
    # exactly Construct — «Pre Construct» contains the word too (judge 2026-11-10); the kit titles it «Событие Construct»
    construct = [n for n in nodes if cls(n) == "K2Node_Event" and title(n).split()[-1] == "Construct" and "Pre" not in title(n)]
    if len(construct) != 1:
        raise RuntimeError("Construct events: %s" % [title(n) for n in construct])
    construct = construct[0]
    c_then = out(construct, "then")
    target = linked(c_then)
    if len(target) != 1:
        raise RuntimeError("Construct: %d links from then" % len(target))
    target = target[0]
    pins.break_single_pin_link(c_then, target)
    pending = [c_then]   # exec outputs that flow into the next node of the chain (a failed cast flows on too)
    x, y = -2200, 3400
    for name, delta in ((PREV, "-1"), (NEXT, "1")):
        cast, as_btn = cast_to(ed, "EventGraph", "Button", widget_ref(ed, name, x - 300, y), x, y)
        for p in pending:
            link(p, inp(cast, "execute"), "Construct chain -> cast %s" % name)
        # «Bind Event to On Clicked» + OUR named custom event: «Assign On Clicked» named both events OnClicked_событие and the compile refused the
        # duplicate function name (run 9)
        ev = ed.add_custom_event_node(name.replace("Btn_", "") + "Clicked")
        if not ev:
            raise RuntimeError("custom event for %s not created" % name)
        bn = action(ed, "EventGraph", ["Кнопка", "BindEventtoOnClicked"])
        try:
            bind = ed.create_node_from_name(bn, unreal.Vector2D(x + 250, y), [as_btn], unreal.Button)
        except Exception as e:
            say("bind with declaring class failed (%s) — without it" % e)
            bind = ed.create_node_from_name(bn, unreal.Vector2D(x + 250, y), [as_btn])
        if not bind:
            raise RuntimeError("bind %s: no node" % name)
        say("bind %s pins: %s" % (name, [str(pins.get_pin_name(p)) for p in lib.list_all_pins(bind)]))
        if not linked(inp(bind, "self")):
            link(as_btn, inp(bind, "self"), "%s -> bind.self" % name)
        link(out(ev, "OutputDelegate"), inp(bind, "Delegate"), "%s event -> bind" % name)   # the bind's pins: execute, self, Delegate, then (run 10)
        link(out(cast, "then"), inp(bind, "execute"), "cast -> bind %s" % name)
        pending = [out(bind, "then"), out(cast, "CastFailed")]
        pos(ev, x, y + 300)
        page_step(ed, out(ev, "then"), delta, sig, x + 300, y + 300)
        y += 700
    for p in pending:
        link(p, target, "assigns -> the game's Construct chain")
    say("EventGraph: clicks built")


def wheel(bp):
    g = lib.add_function_override(bp, "OnMouseWheel")
    if not g:
        raise RuntimeError("OnMouseWheel override refused")
    ed = ged.get_graph_editor_by_name(bp, g.get_name())
    nodes = list(ed.list_all_nodes())
    if len(nodes) > 2:
        say("OnMouseWheel: already built (%d nodes) — skipped" % len(nodes))
        return
    entry = [n for n in nodes if cls(n) == "K2Node_FunctionEntry"][0]
    ret = [n for n in nodes if cls(n) == "K2Node_FunctionResult"][0]
    then = out(entry, "then")
    for p in linked(then):
        pins.break_single_pin_link(then, p)
    # the wheel presses an arrow: down (delta < 0) = Next, up = Prev — `Call On Clicked` of that button runs our click event (one place for the page step)
    delta = call(ed, "/Script/Engine.KismetInputLibrary:PointerEvent_GetWheelDelta")
    link(out(entry, "MouseEvent"), inp(delta, "Input"), "MouseEvent -> wheel delta")
    less = None
    for fn in ("Less_DoubleDouble", "Less_FloatFloat"):
        try:
            less = call(ed, KM + fn)
            break
        except RuntimeError:
            pass
    if not less:
        raise RuntimeError("no float < node")
    link(out(delta, "ReturnValue"), inp(less, "A"), "delta -> < 0")
    literal(inp(less, "B"), "0.0")
    br = ed.add_branch_node()
    link(then, inp(br, "execute"), "entry -> branch")
    link(out(less, "ReturnValue"), inp(br, "Condition"), "< 0 -> branch")
    gname = g.get_name()
    for k, (name, branch_pin) in enumerate(((NEXT, "then"), (PREV, "else"))):
        cast, as_btn = cast_to(ed, gname, "Button", widget_ref(ed, name, 300, 300 + 400 * k), 500, 300 + 400 * k)
        link(out(br, branch_pin), inp(cast, "execute"), "branch -> cast %s" % name)
        cn = action(ed, gname, ["Кнопка", "CallOnClicked"])
        click = None
        for extra in ((unreal.Button,), ()):   # without the declaring class the node came back None (run 7, 09:35)
            try:
                click = ed.create_node_from_name(cn, unreal.Vector2D(800, 300 + 400 * k), [as_btn], *extra)
            except Exception as e:
                say("CallOnClicked %s %s: %s" % (name, extra, e))
            if click:
                break
        if not click:
            raise RuntimeError("no Call On Clicked node for %s" % name)
        if not linked(inp(click, "self")):
            link(as_btn, inp(click, "self"), "%s -> CallOnClicked.self" % name)
        link(out(cast, "then"), inp(click, "execute"), "cast -> click %s" % name)
        link(out(click, "then"), inp(ret, "execute"), "click -> return")
        link(out(cast, "CastFailed"), inp(ret, "execute"), "cast failed -> return")
    handled = call(ed, "/Script/UMG.WidgetBlueprintLibrary:Handled")
    link(out(handled, "ReturnValue"), inp(ret, "ReturnValue"), "Handled -> return")
    for i, n in enumerate((delta, less, br, handled)):
        pos(n, 160 * i, 0)
    pos(ret, 1400, 0)
    say("OnMouseWheel: built")


res = {"ok": False}
try:
    bp = unreal.load_asset(WIDGET)
    if PAGE_VAR not in [str(v) for v in lib.list_member_variable_names(bp)]:
        raise RuntimeError("step 1 is missing (no member Page) — run kit-attribute-paging-edit.py first")
    pips_on = build_tree()
    say("compile after the tree: %s" % lib.compile_blueprint(bp))   # the new widgets become members before the graphs read them
    update_view(bp, pips_on)
    clicks(bp)
    # the wheel is NOT built in this step: in the OnMouseWheel function graph the kit returns no «Call On Clicked» node (runs 7–8, with and without the
    # declaring class) and offers no call of the refresh dispatcher (runs 5–6); a half-built override must never be compiled in. Next route — plan 49.
    if os.environ.get("KIT_TRY_WHEEL") == "1":
        wheel(bp)
    compiled = lib.compile_blueprint(bp)
    say("compile: %s" % compiled)
    if not compiled:
        raise RuntimeError("the blueprint does not compile — the asset is NOT saved")
    say("save: %s" % unreal.EditorAssetLibrary.save_loaded_asset(bp, False))
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
res["links"] = links_ok
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
