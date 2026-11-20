# kit-attribute-paging-wheel.py — KUMM plan 49 B2: the mouse wheel over an attribute row pages it (the owner's B2 of 2026-11-09 19:58: «колесо над рядом
# листает по 20»). Step 2 left the wheel unbuilt: in the OnMouseWheel function graph the kit returns no «Call On Clicked» node (runs 7–8). This route calls
# OUR custom events KrinikPageNextClicked / KrinikPagePrevClicked (made by kit-attribute-paging-step2.py; each sets Page ± 1 and flows into the game's refresh)
# as functions of the generated class — one place for the page step, as for the arrows' clicks:
#   OnMouseWheel(MyGeometry, MouseEvent): delta = GetWheelDelta(MouseEvent); delta < 0 → KrinikPageNextClicked else KrinikPagePrevClicked; return Handled.
# Idempotent: an OnMouseWheel graph that already calls our KrinikPage* events is left alone. Any failed node, link or compile stops the run BEFORE the save.
# Known risk (judge 2026-11-10, not observed): a zero delta would take the «else» branch (Prev); the clamp keeps Page ≥ 0. A high-resolution wheel turns a page
# per event. Handled is returned on every row (the rows panel does not scroll — all six rows fit at 720p).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-attribute-paging-wheel.json next to this file.
# [TESTED: 2026-11-10 · built, cooked, W1–W4 by a real wheel · KUMM testcases/TC_conan_attribute_paging_step2_2026-11-10.md]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
GEN = WIDGET + ".W_Attribute_C"
EVENTS = ("KrinikPageNextClicked", "KrinikPagePrevClicked")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-attribute-paging-wheel.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
res = {"ok": False, "steps": [], "links": []}
say = res["steps"].append


def cls(n):
    return n.get_class().get_name()


def out(n, name):
    p = lib.find_output_pin(n, name)
    if not p:
        raise RuntimeError("no output pin %s on %s" % (name, lib.get_node_title(n)))
    return p


def inp(n, name):
    p = lib.find_input_pin(n, name)
    if not p:
        raise RuntimeError("no input pin %s on %s" % (name, lib.get_node_title(n)))
    return p


def link(a, b, what):
    ok = pins.try_create_connection(a, b)
    res["links"].append((what, ok))
    if not ok:
        raise RuntimeError("link failed: %s — NOT saved" % what)


def call(ed, *paths):
    for path in paths:
        for p in (path, path.replace(":", ".")):
            try:
                n = ed.add_call_function_node(p)
                if n:
                    say("node %s" % p)
                    return n
            except Exception as e:
                say("node %s ERR %s" % (p, str(e)[:120]))
    raise RuntimeError("cannot create any of %s — NOT saved" % (paths,))


try:
    bp = unreal.load_asset(WIDGET)
    g = lib.add_function_override(bp, "OnMouseWheel")
    if not g:
        raise RuntimeError("OnMouseWheel override refused")
    ed = ged.get_graph_editor_by_name(bp, g.get_name())
    nodes = list(ed.list_all_nodes())
    ours = [n for n in nodes if "KrinikPage" in str(lib.get_node_title(n)).replace(" ", "")]
    if ours:   # recognised by OUR calls, not by a node count (a foreign override with nodes would pass a count — judge 2026-11-10)
        say("OnMouseWheel: already calls %d KrinikPage* events — skipped" % len(ours))
    elif len(nodes) > 2:
        raise RuntimeError("OnMouseWheel already has %d nodes of someone else's — NOT touched, NOT saved" % len(nodes))
    else:
        entry = [n for n in nodes if cls(n) == "K2Node_FunctionEntry"][0]
        ret = [n for n in nodes if cls(n) == "K2Node_FunctionResult"][0]
        then = out(entry, "then")
        for p in list(pins.list_connected_pins(then)):
            pins.break_single_pin_link(then, p)
        delta = call(ed, "/Script/Engine.KismetInputLibrary:PointerEvent_GetWheelDelta")
        link(out(entry, "MouseEvent"), inp(delta, "Input"), "MouseEvent -> wheel delta")
        less = call(ed, "/Script/Engine.KismetMathLibrary:Less_DoubleDouble", "/Script/Engine.KismetMathLibrary:Less_FloatFloat")
        link(out(delta, "ReturnValue"), inp(less, "A"), "delta -> A")
        if not pins.set_pin_value(inp(less, "B"), "0.0"):
            raise RuntimeError("literal 0.0 refused — NOT saved")
        br = ed.add_branch_node()
        link(then, inp(br, "execute"), "entry -> branch")
        link(out(less, "ReturnValue"), inp(br, "Condition"), "delta < 0 -> branch")
        handled = call(ed, "/Script/UMG.WidgetBlueprintLibrary:Handled")
        for ev, branch_pin in zip(EVENTS, ("then", "else")):
            n = call(ed, GEN + ":" + ev)
            link(out(br, branch_pin), inp(n, "execute"), "branch %s -> %s" % (branch_pin, ev))
            link(out(n, "then"), inp(ret, "execute"), "%s -> return" % ev)
        link(out(handled, "ReturnValue"), inp(ret, "ReturnValue"), "Handled -> return value")
    ok = lib.compile_blueprint(bp)
    say("compile: %s" % ok)
    if not ok:   # as step 2 (judge 2026-11-10): a None from the binding is a stop too
        raise RuntimeError("compile failed — NOT saved (LogBlueprint: Error in the editor log)")
    res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    res["ok"] = bool(res["saved"])
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
