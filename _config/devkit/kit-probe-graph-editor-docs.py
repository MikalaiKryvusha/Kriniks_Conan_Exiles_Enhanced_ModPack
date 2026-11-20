# kit-probe-graph-editor-docs.py — the docstrings (signatures) of the kit's Blueprint graph-editing API, so the plan 49 edit script calls them right.
# Read-only. Writes kit-probe-graph-editor-docs.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-graph-editor-docs.json")
WANT = {
    "BlueprintGraphEditor": ["get_graph_editor_by_name", "add_call_function_node", "add_get_member_variable_node", "add_set_member_variable_node",
                             "add_member_variable", "add_branch_node", "add_custom_event_node", "add_component_bound_event_node", "create_node_from_name",
                             "list_available_nodes", "remove_nodes", "find_event_node", "add_node_pin"],
    "BlueprintEditorLibrary": ["add_member_variable", "get_basic_type_by_name", "find_input_pin", "find_output_pin", "compile_blueprint", "add_function_override",
                               "add_event_override", "set_node_pos", "list_all_pins"],
    "BlueprintGraphPinLibrary": ["try_create_connection", "break_pin_links", "break_single_pin_link", "set_pin_value", "list_connected_pins"],
    "EditorAssetLibrary": ["save_loaded_asset"],
}
res = {"ok": False, "docs": {}}
try:
    for cls, names in WANT.items():
        c = getattr(unreal, cls)
        res["docs"][cls] = {n: (getattr(c, n).__doc__ or "") if hasattr(c, n) else "absent" for n in names}
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
