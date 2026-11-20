# kit-probe-w-attribute.py — read-only map of W_Attribute for KUMM plan 49 B2 (arrows ‹ › at the row ends past 20, a page window label, the bar shifted by a page):
# the widget tree (name, class, parent, slot), the member variables, the graphs, and for UpdateView / EventGraph every node with its title and pins
# (direction, type, value, links). Writes kit-probe-w-attribute.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

# 2026-11-10 (plan 49 step 4): any widget — KIT_PROBE_WIDGET=<asset path> and KIT_PROBE_GRAPHS=<a,b,…>; the report is named after the asset
WIDGET = os.environ.get("KIT_PROBE_WIDGET", "/Game/UI/Inventory/Attributes/W_Attribute")
GRAPHS = tuple(g for g in os.environ.get("KIT_PROBE_GRAPHS", "UpdateView,EventGraph,UpdateAttributeView").split(",") if g)
_tag = WIDGET.rsplit("/", 1)[-1]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "kit-probe-w-attribute.json" if _tag == "W_Attribute" else "kit-probe-%s.json" % _tag.lower().replace("_", "-"))
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary


def pin_info(p):
    d = {}
    for key, fn in (("name", pins.get_pin_name), ("dir", pins.get_pin_direction), ("type", pins.get_pin_type_display_string), ("value", pins.get_pin_value)):
        try:
            d[key] = str(fn(p))
        except Exception as e:
            d[key] = "ERR %s" % e
    try:
        d["links"] = [str(pins.get_pin_name(q)) + "@" + str(lib.get_node_title(pins.get_owning_node(q))) for q in pins.list_connected_pins(p)]
    except Exception as e:
        d["links"] = "ERR %s" % e
    return d


res = {"ok": False, "tree": [], "vars": [], "graphs": [], "nodes": {}}
try:
    bp = unreal.load_asset(WIDGET)
    res["graphs"] = [str(g) for g in lib.list_graph_names(bp)]
    # own variables only (the inherited ones come as /Script/... paths)
    res["vars"] = [str(v) for v in lib.list_member_variable_names(bp) if not str(v).startswith("/Script/")]
    # the tree: WidgetTree.RootWidget is not exposed to Python (kit-probe-quickloot.py, 2026-10-30) — iterate every Widget inside this blueprint's
    # WidgetTree, parent by UWidget.GetParent
    prefix = WIDGET + "." + _tag + ":WidgetTree."
    for w in unreal.ObjectIterator(unreal.Widget):
        if not w.get_path_name().startswith(prefix):
            continue
        slot = w.get_editor_property("slot")
        par = w.get_parent()
        res["tree"].append({"name": w.get_name(), "class": w.get_class().get_name(), "parent": par.get_name() if par else "",
                            "slot": slot.get_class().get_name() if slot else None, "depth": 0})
    for gname in GRAPHS:
        try:
            g = lib.find_graph(bp, gname)
            # BlueprintGraphEditor is an editor OBJECT over one graph (probe 02:47: list_all_nodes needs a BlueprintGraphEditor, not an EdGraph)
            ed, how = None, []
            for name, call in (("get_graph_editor_by_name", lambda: ged.get_graph_editor_by_name(bp, gname)),
                               ("get_graph_editor", lambda: ged.get_graph_editor(g))):
                try:
                    ed = call()
                    how.append(name + " ok")
                    if ed:
                        break
                except Exception as e:
                    how.append("%s ERR %s" % (name, e))
            res["nodes"][gname + "#how"] = how
            out = []
            for n in ed.list_all_nodes():
                out.append({"title": str(lib.get_node_title(n)), "class": n.get_class().get_name(), "pos": str(lib.get_node_pos(n)),
                            "pins": [pin_info(p) for p in lib.list_all_pins(n)]})
            res["nodes"][gname] = out
        except Exception:
            res["nodes"][gname] = "ERR " + traceback.format_exc()[-400:]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
