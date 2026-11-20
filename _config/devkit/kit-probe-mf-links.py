# kit-probe-mf-links.py — the CONNECTIONS of a material function graph from the Dev Kit (read-only): for every expression of the classes named in
# KIT_CLASSES, its inputs (which expression feeds each), to find where MF_FLX_UVPivot_WPO computes the per-leaf PIVOT (KUMM bug 67 — the shadow-only
# leaf enlargement around its pivot; [OWNER] 2026-11-07 15:48 «толще листья в 100 раз, не трогай точность»).
# Env KIT_FUNC (asset path), KIT_CLASSES ("RotateAboutAxis;FunctionOutput;SetMaterialAttributes"). Writes kit-probe-mf-links.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

FUNC = os.environ.get("KIT_FUNC", "/FLX_Materials/Materials/Environment/Function/MF_FLX_UVPivot_WPO")
CLASSES = [c for c in os.environ.get("KIT_CLASSES", "RotateAboutAxis;FunctionOutput;SetMaterialAttributes").split(";") if c]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-mf-links.json")
MEL = unreal.MaterialEditingLibrary


def label(e, ids):
    if e is None:
        return None
    n = e.get_class().get_name().replace("MaterialExpression", "")
    for k in ("parameter_name", "input_name", "coordinate_index", "material_function"):
        try:
            v = e.get_editor_property(k)
            n += "(%s=%s)" % (k, v.get_name() if hasattr(v, "get_name") else v)
            break
        except Exception:
            pass
    return "#%d %s" % (ids.setdefault(e.get_name(), len(ids)), n)


res = {"ok": False, "nodes": [], "errors": []}
try:
    f = unreal.load_asset(FUNC)
    # 2026-11-07 15:50: get_editor_property("function_expressions") raises on MaterialFunction — the library call works (kit-probe-mf-graph.py)
    exprs = list(MEL.get_material_function_expressions(f) or [])
    ids = {}
    for e in exprs:
        label(e, ids)
    # walk two levels up from each wanted node
    for e in exprs:
        cname = e.get_class().get_name().replace("MaterialExpression", "")
        if cname not in CLASSES:
            continue
        node = {"node": label(e, ids), "inputs": []}
        try:
            names = MEL.get_material_expression_input_names(e)
        except Exception:
            names = []
        try:
            ins = MEL.get_inputs_for_material_expression(f, e)
        except Exception as ex:
            ins = []
            node["err"] = str(ex)
        for i, src in enumerate(ins):
            item = {"pin": names[i] if i < len(names) else i, "from": label(src, ids)}
            if src is not None:
                try:
                    item["from_inputs"] = [label(s, ids) for s in MEL.get_inputs_for_material_expression(f, src)]
                except Exception:
                    pass
            node["inputs"].append(item)
        res["nodes"].append(node)
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())
with open(REPORT, "w", encoding="utf-8") as fh:
    json.dump(res, fh, indent=1)
