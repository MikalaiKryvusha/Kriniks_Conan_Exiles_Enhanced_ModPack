# kit-foliage-wpo.py — set the WPO displacement bound of the shared foliage material in the kit (KUMM bug 67, root cause 2026-11-07 18:54).
# Why: M_Foliage.MaxWorldPositionOffsetDisplacement = 0 (read live in the game; the palm MIs do not override it) — Nanite pads no wind into the
# leaf cluster bounds, so a turning sun re-culls wind-displaced leaflets on some frames and keeps them on others (the shadow blinks; the hero,
# trunks and rocks without WPO never blink). A real bound pads the cluster bounds for culling.
#   UnrealEditor-Cmd ConanSandbox.uproject -run=PythonScript -Script=<this> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Env KRINIK_WPO_BOUND (cm, default 100). Report: kit-foliage-wpo.json next to this file. The kit asset is backed up in kit_asset_backups/.
# [NOT-TESTED]
import json
import os

import unreal

OUT = r"D:\work\ai_sandbox\ConanExiles\_config\devkit\kit-foliage-wpo.json"
PATH = "/FLX_Materials/Materials/Environment/Core/M_Foliage"
BOUND = float(os.environ.get("KRINIK_WPO_BOUND", "100"))
rep = {"path": PATH, "bound": BOUND}
try:
    m = unreal.load_asset(PATH)
    rep["before"] = m.get_editor_property("max_world_position_offset_displacement")
    m.set_editor_property("max_world_position_offset_displacement", BOUND)
    rep["after"] = m.get_editor_property("max_world_position_offset_displacement")
    rep["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(m, False)
except Exception as e:
    rep["error"] = repr(e)
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(rep, f, indent=1)
