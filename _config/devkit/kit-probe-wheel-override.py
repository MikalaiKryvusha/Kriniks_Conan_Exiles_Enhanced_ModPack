# kit-probe-wheel-override.py — KUMM plan 49 step 2: can the kit's Python override W_Attribute's OnMouseWheel (the wheel pages a row by 20)? Tries
# BlueprintEditorLibrary.add_function_override(bp, "OnMouseWheel") IN MEMORY and lists the new graph's nodes and pins; never saves. Writes kit-probe-wheel-override.json.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-wheel-override.json")
lib = unreal.BlueprintEditorLibrary
res = {"ok": False}
try:
    bp = unreal.load_asset(WIDGET)
    g = lib.add_function_override(bp, "OnMouseWheel")
    res["graph"] = g.get_name() if g else None
    if g:
        ed = unreal.BlueprintGraphEditor.get_graph_editor_by_name(bp, g.get_name())
        res["nodes"] = [{"title": str(lib.get_node_title(n)), "pins": [str(unreal.BlueprintGraphPinLibrary.get_pin_name(p)) + ":" +
                                                                       str(unreal.BlueprintGraphPinLibrary.get_pin_type_display_string(p)) for p in lib.list_all_pins(n)]}
                        for n in ed.list_all_nodes()]
    res["ok"] = True   # nothing saved
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
