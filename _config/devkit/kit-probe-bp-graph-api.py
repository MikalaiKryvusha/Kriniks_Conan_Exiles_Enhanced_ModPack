# kit-probe-bp-graph-api.py — what the kit's Python can do to a Blueprint GRAPH (KUMM plan 49 B2: the attribute row needs new logic — a page variable,
# the bar shift in UpdateView, arrows, the wheel). Read-only: lists the methods of the blueprint-editing libraries and every unreal class whose name
# says it creates or wires graph nodes; loads W_Attribute and lists its graphs. Writes kit-probe-bp-graph-api.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-bp-graph-api.json")
WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
LIBS = ("BlueprintEditorLibrary", "EditorAssetLibrary", "KismetEditorUtilities", "EdGraphSchema_K2", "BlueprintGraphLibrary", "K2NodeLibrary",
        "BlueprintGraphEditor", "BlueprintGraphPinLibrary", "BlueprintGraphPin", "EdGraph", "EdGraphNode", "K2Node_CallFunction", "K2Node_VariableGet")
WORDS = ("K2Node", "EdGraph", "GraphNode", "BlueprintNode", "NodeSpawner", "BlueprintGraph", "Kismet")

res = {"ok": False, "libs": {}, "classes": [], "widget": {}}
try:
    for name in LIBS:
        cls = getattr(unreal, name, None)
        res["libs"][name] = sorted(m for m in dir(cls) if not m.startswith("_")) if cls else "absent"
    res["classes"] = sorted(n for n in dir(unreal) if any(w in n for w in WORDS))
    bp = unreal.load_asset(WIDGET)
    res["widget"]["class"] = bp.get_class().get_name() if bp else "not loaded"
    lib = getattr(unreal, "BlueprintEditorLibrary", None)
    if bp and lib and hasattr(lib, "find_graph"):
        for g in ("EventGraph", "UpdateView", "PostPipsPlacedOnCanvas"):
            try:
                gr = lib.find_graph(bp, g)
                res["widget"][g] = gr.get_name() if gr else None
            except Exception as e:
                res["widget"][g] = "ERR %s" % e
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
