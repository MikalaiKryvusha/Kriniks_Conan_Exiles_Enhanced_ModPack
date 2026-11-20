# kit-probe-bound-event.py — KUMM plan 49 B2 step 2, the first probe: does BlueprintGraphEditor.add_component_bound_event_node accept a WIDGET (a Button of a
# widget blueprint) though its doc types ActorComponent? Tries it in memory on W_Attribute's existing «+» button (`LevelAttributeButton`, event OnHovered)
# and NEVER saves the asset. Writes kit-probe-bound-event.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-bound-event.json")
res = {"ok": False, "tries": []}
try:
    bp = unreal.load_asset(WIDGET)
    ed = unreal.BlueprintGraphEditor.get_graph_editor_by_name(bp, "EventGraph")
    btn = unreal.find_object(None, WIDGET + ".W_Attribute:WidgetTree.LevelAttributeButton")
    res["button"] = btn.get_class().get_name() if btn else None
    for name, call in (("widget object", lambda: ed.add_component_bound_event_node(btn, "OnHovered")),):
        try:
            n = call()
            res["tries"].append({name: (n.get_class().get_name() + " · " + str(unreal.BlueprintEditorLibrary.get_node_title(n))) if n else "None"})
        except Exception as e:
            res["tries"].append({name: "ERR %s" % e})
    res["ok"] = True   # nothing is saved: the asset in memory dies with the process
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
