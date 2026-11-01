# kit-probe-arrow-mesh.py — read-only: the bounding boxes of the game's arrow static meshes (KUMM plan 36 W13: the stuck copy's origin vs the arrow
# tip — a push to the hit bone's depth hit the 60 cm cap on a humanoid, so the origin lies far behind the tip). For every StaticMesh asset whose name
# holds "Arrow" or "Bolt": the bounds origin and box extent in cm (local space), the min/max along X, Y, Z. Writes kit-probe-arrow-mesh.json here.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-arrow-mesh.json")
KEYS = ("arrow", "bolt")
LIMIT = 40

res = {"ok": False, "meshes": []}
try:
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    found = [a for a in reg.get_assets_by_class(unreal.TopLevelAssetPath("/Script/Engine", "StaticMesh"), True)
             if any(k in str(a.asset_name).lower() for k in KEYS)]
    for a in found[:LIMIT]:
        path = str(a.package_name)
        try:
            m = unreal.load_asset(path)
            b = m.get_bounds()
            o, e = b.origin, b.box_extent
            res["meshes"].append({"path": path, "origin": [o.x, o.y, o.z], "extent": [e.x, e.y, e.z],
                                  "min": [o.x - e.x, o.y - e.y, o.z - e.z], "max": [o.x + e.x, o.y + e.y, o.z + e.z]})
        except Exception as ex:
            res["meshes"].append({"path": path, "error": str(ex)})
    res["count"] = len(found)
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
