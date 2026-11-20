# kit-probe-material-wpo.py — does a base material move its vertices (World Position Offset), read from the Dev Kit (read-only). KUMM bug 67:
# kit-probe-palms said «WPO not connected» for M_Foliage — that is wrong for a material built on Material Attributes, so this probe reads the
# attributes input, the expression list and the usage flags. Env KIT_MATERIALS="/Game/Environment/Foliage/Materials/M_Foliage;…".
# Writes kit-probe-material-wpo.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

PATHS = [p for p in os.environ.get("KIT_MATERIALS", "/Game/Environment/Foliage/Materials/M_Foliage").split(";") if p]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-material-wpo.json")
PROPS = ["use_material_attributes", "blend_mode", "two_sided", "always_evaluate_world_position_offset", "max_world_position_offset_displacement",
         "used_with_instanced_static_meshes", "used_with_nanite", "dithered_lod_transition", "is_masked"]
MP = ["MP_WORLD_POSITION_OFFSET", "MP_MATERIAL_ATTRIBUTES", "MP_OPACITY_MASK"]

res = {"ok": False, "materials": {}, "errors": []}
try:
    mel = unreal.MaterialEditingLibrary
    for path in PATHS:
        m = unreal.load_asset(path)
        e = {"class": m.get_class().get_name(), "props": {}, "inputs": {}, "expressions": []}
        for p in PROPS:
            try:
                e["props"][p] = str(m.get_editor_property(p))
            except Exception:
                e["props"][p] = "n/a"
        for mp in MP:
            try:
                node = mel.get_material_property_input_node(m, getattr(unreal.MaterialProperty, mp))
                e["inputs"][mp] = node.get_class().get_name() if node else None
            except Exception as ex:
                e["inputs"][mp] = "ERR %s" % ex
        try:
            exprs = m.get_editor_property("expressions") if hasattr(m, "get_editor_property") else []
        except Exception:
            exprs = []
        if not exprs:
            try:
                exprs = mel.get_material_expressions(m)  # newer API names, tried in turn
            except Exception:
                exprs = []
        names = {}
        for x in exprs or []:
            n = x.get_class().get_name()
            if n == "MaterialExpressionMaterialFunctionCall":
                try:
                    f = x.get_editor_property("material_function")
                    n = "Func:" + (f.get_name() if f else "None")
                except Exception:
                    pass
            names[n] = names.get(n, 0) + 1
        e["expressions"] = sorted(names.items())
        try:
            e["usage_wpo_in_shaders"] = str(mel.get_material_usage(m)) if hasattr(mel, "get_material_usage") else "n/a"
        except Exception:
            pass
        res["materials"][path] = e
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())

with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
unreal.log("kit-probe-material-wpo: wrote %s" % REPORT)
