# kit-export-palm-mesh.py — export the oasis palm meshes from the Dev Kit to OBJ (read-only) to MEASURE the leaf thickness (KUMM bug 67;
# [OWNER] 2026-11-07 15:32 «УЗНАТЬ ТЕКУЩУЮ ТОЛЩИНУ ЛИСТА»). Env KIT_MESHES="/Game/…/GFL_AfricanOilPalm01;…", KIT_OUT=<folder> (default: this folder/_palm_obj).
# Writes <out>/<mesh>.obj (LOD0) and <out>/export.json (what was written, the material slots, errors).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

MESHES = [p for p in os.environ.get("KIT_MESHES", "/Game/Environment/Foliage/Meshes/FLX/GFL_AfricanOilPalm01").split(";") if p]
OUT = os.environ.get("KIT_OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "_palm_obj"))
os.makedirs(OUT, exist_ok=True)
res = {"ok": False, "written": [], "errors": []}
try:
    for path in MESHES:
        mesh = unreal.load_asset(path)
        if mesh is None:
            res["errors"].append("not loaded: " + path)
            continue
        name = path.rsplit("/", 1)[-1]
        entry = {"path": path, "materials": []}
        try:
            for sm in mesh.get_editor_property("static_materials"):
                mi = sm.get_editor_property("material_interface")
                entry["materials"].append(mi.get_path_name() if mi else None)
        except Exception as e:
            entry["materials_err"] = str(e)
        try:
            entry["bounds"] = str(mesh.get_bounding_box())
        except Exception as e:
            entry["bounds_err"] = str(e)
        task = unreal.AssetExportTask()
        task.object = mesh
        task.filename = os.path.join(OUT, name + ".obj")
        task.automated = True
        task.prompt = False
        task.replace_identical = True
        task.exporter = unreal.StaticMeshExporterOBJ()
        entry["exported"] = bool(unreal.Exporter.run_asset_export_task(task))
        entry["file"] = task.filename
        entry["size"] = os.path.getsize(task.filename) if os.path.exists(task.filename) else 0
        res["written"].append(entry)
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())
with open(os.path.join(OUT, "export.json"), "w", encoding="utf-8") as f:
    json.dump(res, f, indent=1)
