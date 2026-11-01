# kit-export-textures.py — export game textures (with alpha) to TGA by asset path: env KIT_TEXTURES="/Game/…/T_A;/Game/…/T_B", KIT_PROBE_OUT=<dir>.
# Read-only on the assets. KUMM plan 36 W26: the game's logo T_UI_ConanExiles_Enhanced_Logo for the wallpaper with both logos
# (`[OWNER]` «наше лого и лого оригинальной игры (нужно найти его в ПНГ) будем накладывать на картинку-оригинал-волпейпер» · 2026-10-30 22:44).
# Writes kit-export-textures.json next to this file (size, export result per texture).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

PATHS = [p for p in os.environ.get("KIT_TEXTURES", "").split(";") if p]
OUT_DIR = os.environ.get("KIT_PROBE_OUT", "")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-export-textures.json")
res = {"ok": False, "textures": {}}
try:
    for p in PATHS:
        tex = unreal.load_asset(p)
        if tex is None:
            res["textures"][p] = "NOT FOUND"
            continue
        d = {"size": [tex.blueprint_get_size_x(), tex.blueprint_get_size_y()]}
        task = unreal.AssetExportTask()
        task.object = tex
        task.filename = os.path.join(OUT_DIR, p.rsplit("/", 1)[-1] + ".tga")
        task.automated = True
        task.prompt = False
        task.replace_identical = True
        d["exported"] = unreal.Exporter.run_asset_export_task(task)
        d["file"] = task.filename
        res["textures"][p] = d
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
