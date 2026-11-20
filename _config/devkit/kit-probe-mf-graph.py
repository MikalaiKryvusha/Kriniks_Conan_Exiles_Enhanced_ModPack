# kit-probe-mf-graph.py — dump a material FUNCTION's graph from the Dev Kit (read-only): every expression's class, its key properties (UV index,
# parameter name, custom HLSL code, function inputs/outputs) — to learn what per-leaf data the foliage WPO reads (KUMM bug 67, the shadow-only leaf
# widening; [OWNER] 2026-11-07 15:31 «МОЖНО ЛИСТЫ ПАЛЬМ СДЕЛАТЬ ТОЛСТЫМИ»). Env KIT_FUNCS="/FLX_Materials/…/MF_FLX_UVPivot_WPO;…" (asset paths).
# Writes kit-probe-mf-graph.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

NAMES = [p for p in os.environ.get("KIT_FUNCS", "MF_FLX_UVPivot_WPO").split(";") if p]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-mf-graph.json")
KEYS = ["coordinate_index", "parameter_name", "input_name", "output_name", "code", "description", "default_value", "r", "g", "b", "a",
        "const_a", "const_b", "material_function", "texture", "sampler_type", "input_type", "preview_value", "mask_r", "mask_g", "mask_b", "mask_a",
        "description"]
res = {"ok": False, "functions": {}, "errors": []}
try:
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    for name in NAMES:
        path = name
        if not name.startswith("/"):
            hits = [a for a in reg.get_assets_by_class(unreal.TopLevelAssetPath("/Script/Engine", "MaterialFunction")) if str(a.asset_name) == name]
            if not hits:
                res["errors"].append("not found: " + name)
                continue
            path = str(hits[0].package_name)
        f = unreal.load_asset(path)
        if f is None:
            res["errors"].append("not loaded: " + path)
            continue
        exprs = []
        try:
            coll = f.get_editor_property("function_expressions") if hasattr(f, "get_editor_property") else []
        except Exception:
            coll = []
        if not coll:
            try:
                coll = unreal.MaterialEditingLibrary.get_material_function_expressions(f) if hasattr(unreal.MaterialEditingLibrary, "get_material_function_expressions") else []
            except Exception:
                coll = []
        for e in coll or []:
            d = {"class": e.get_class().get_name()}
            for k in KEYS:
                try:
                    v = e.get_editor_property(k)
                    d[k] = v.get_path_name() if hasattr(v, "get_path_name") else str(v)
                except Exception:
                    pass
            exprs.append(d)
        res["functions"][path] = {"count": len(exprs), "expressions": exprs}
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())
with open(REPORT, "w", encoding="utf-8") as fh:
    json.dump(res, fh, indent=1)
