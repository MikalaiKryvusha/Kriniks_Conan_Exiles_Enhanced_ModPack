# kit-export-t3d.py — export assets from the Dev Kit as T3D text (read-only): a material function's T3D carries every expression WITH its input links
# (the Python MaterialEditingLibrary reads links of Materials only). KUMM bug 67 — find the per-leaf pivot and axis used by the foliage wind
# (MF_LeafShimmer) for the shadow-only leaf thickening ([OWNER] 2026-11-07 15:48 «толще листья в 100 раз»).
# Env KIT_ASSETS="/FLX_Materials/…/MF_LeafShimmer;…", KIT_OUT=<folder>. Writes <out>/<name>.t3d and <out>/t3d.json.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSETS = [p for p in os.environ.get("KIT_ASSETS", "").split(";") if p]
OUT = os.environ.get("KIT_OUT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "_t3d"))
os.makedirs(OUT, exist_ok=True)
res = {"ok": False, "written": [], "errors": []}
try:
    for path in ASSETS:
        a = unreal.load_asset(path)
        if a is None:
            res["errors"].append("not loaded: " + path)
            continue
        name = path.rsplit("/", 1)[-1]
        task = unreal.AssetExportTask()
        task.object = a
        task.filename = os.path.join(OUT, name + ".t3d")
        task.automated = True
        task.prompt = False
        task.replace_identical = True
        task.exporter = unreal.ObjectExporterT3D()
        ok = bool(unreal.Exporter.run_asset_export_task(task))
        res["written"].append({"path": path, "ok": ok, "size": os.path.getsize(task.filename) if os.path.exists(task.filename) else 0})
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())
with open(os.path.join(OUT, "t3d.json"), "w", encoding="utf-8") as fh:
    json.dump(res, fh, indent=1)
