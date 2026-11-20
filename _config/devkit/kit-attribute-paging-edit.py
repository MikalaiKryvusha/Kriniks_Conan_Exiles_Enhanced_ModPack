# kit-attribute-paging-edit.py — KUMM plan 49 B2, step 1: the attribute row W_Attribute pages past 20. The owner's pick 2026-11-09 19:58 (B2: arrows at the row
# ends, the window «21–40», the wheel pages by 20; verbatim in plan 49). This step adds the page itself:
#   * an int member `Page` (0 = points 1–20, 1 = 21–40, …);
#   * in UpdateView the bar's value FullValue becomes FullValue − Page × MaxAttributePointAllotment before the game's own division and Clamp(0, 1) —
#     one insertion into the game's formula (HOUSE_RULES rule 24: the cause, not a re-set after the game's work).
# Arrows, the label, the wheel and the pips of a page are the next steps (plan 49). Idempotent: a second run finds its own «int - int» node after the FullValue
# knots and changes nothing; any other node there stops the run; a failed link or compile stops it BEFORE the save.
# Run in the kit's mod mode (active mod KrinikConanUI — the edited native asset is saved into Mods/KrinikConanUI/Content/…):
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-attribute-paging-edit.json next to this file (every step, then the links read back).
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
PAGE_VAR = "Page"
MUL = "/Script/Engine.KismetMathLibrary:Multiply_IntInt"
SUB = "/Script/Engine.KismetMathLibrary:Subtract_IntInt"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-attribute-paging-edit.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
steps = []


def say(s):
    steps.append(s)


def linked(p):
    return list(pins.list_connected_pins(p))


def node_of(p):
    return pins.get_owning_node(p)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def call_node(ed, path):
    # the function path form is not documented in the kit; try the ':' form, then the '.' form, and say which one worked
    for p in (path, path.replace(":", ".")):
        try:
            n = ed.add_call_function_node(p)
            if n:
                say("call node %s via %s" % (title(n), p))
                return n
        except Exception as e:
            say("call node %s ERR %s" % (p, e))
    raise RuntimeError("cannot create " + path)


res = {"ok": False}
try:
    bp = unreal.load_asset(WIDGET)
    own = [str(v) for v in lib.list_member_variable_names(bp)]
    if PAGE_VAR not in own:
        say("add member %s: %s" % (PAGE_VAR, lib.add_member_variable(bp, PAGE_VAR, lib.get_basic_type_by_name("int"))))
    else:
        say("member %s already there" % PAGE_VAR)
    ed = ged.get_graph_editor_by_name(bp, "UpdateView")
    nodes = list(ed.list_all_nodes())
    entry = [n for n in nodes if n.get_class().get_name() == "K2Node_FunctionEntry"][0]
    # FullValue → knot → knot → To Float (Integer): walk the knots to the first non-knot input
    pin = lib.find_output_pin(entry, "FullValue")
    src = pin   # the last output in the chain before To Float — the subtraction takes its A from here
    target = None
    for _ in range(8):
        nxt = linked(src)
        if not nxt:
            break
        n = node_of(nxt[0])
        if n.get_class().get_name() == "K2Node_Knot":
            src = lib.find_output_pin(n, "OutputPin")
            continue
        target = nxt[0]
        break
    t_title, t_pin = title(node_of(target)), str(pins.get_pin_name(target))
    say("bar chain: FullValue -> %s.%s" % (t_title, t_pin))
    # the kit titles the subtraction node «int - int» (readback 02:55); anything but our node or the game's To Float — stop, do not guess (judge 2026-11-10)
    if t_title == "int - int":
        say("already shifted — nothing to do")
    elif t_title != "To Float (Integer)" or t_pin != "InInt":
        raise RuntimeError("unexpected node after the FullValue knots: %s.%s" % (t_title, t_pin))
    else:
        g_page = ed.add_get_member_variable_node(PAGE_VAR)
        g_max = ed.add_get_member_variable_node("MaxAttributePointAllotment")
        mul = call_node(ed, MUL)
        sub = call_node(ed, SUB)
        ok = []
        ok.append(pins.try_create_connection(lib.find_output_pin(g_page, PAGE_VAR), lib.find_input_pin(mul, "A")))
        ok.append(pins.try_create_connection(lib.find_output_pin(g_max, "MaxAttributePointAllotment"), lib.find_input_pin(mul, "B")))
        pins.break_single_pin_link(src, target)
        ok.append(pins.try_create_connection(src, lib.find_input_pin(sub, "A")))
        ok.append(pins.try_create_connection(lib.find_output_pin(mul, "ReturnValue"), lib.find_input_pin(sub, "B")))
        ok.append(pins.try_create_connection(lib.find_output_pin(sub, "ReturnValue"), target))
        say("links made: %s" % ok)
        # a half-wired graph must never be saved: To Float.InInt unwired reads 0 and every bar shows empty (judge 2026-11-10)
        if not all(ok):
            raise RuntimeError("a link failed %s — the asset is NOT saved" % ok)
        base = lib.get_node_pos(node_of(target))
        for i, n in enumerate((g_page, g_max, mul, sub)):
            lib.set_node_pos(n, unreal.IntPoint(base.x - 700 + 180 * i, base.y + 260))
    compiled = lib.compile_blueprint(bp)
    say("compile: %s" % compiled)
    if not compiled:
        raise RuntimeError("the blueprint does not compile — the asset is NOT saved")
    say("save: %s" % unreal.EditorAssetLibrary.save_loaded_asset(bp, False))
    # read back: what feeds To Float now
    ed2 = ged.get_graph_editor_by_name(bp, "UpdateView")
    res["readback"] = []
    for n in ed2.list_all_nodes():
        t = title(n)
        if any(k in t for k in ("Subtract", "Multiply", "Page", "To Float", "-", "*")):
            res["readback"].append({"node": t, "links": {str(pins.get_pin_name(p)): [title(node_of(q)) + "." + str(pins.get_pin_name(q)) for q in linked(p)]
                                                         for p in lib.list_all_pins(n)}})
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
