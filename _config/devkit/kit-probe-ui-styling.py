# kit-probe-ui-styling.py — READ-ONLY (nothing saved): Funcom's own UI style system of Conan Exiles 3.0.1 — every /Game/UI/Styling/**/FS_* blueprint (buttons,
# texts, sliders, dropdowns, editable texts) dumped from its class default object by export_text(), and the rich-text table DT_RichTextStyles as JSON. For the
# owner's word 2026-11-10 13:19 «у конана есть конкретная цветовая дизайн схемма» · «давай-ка ты ещё нагуглишь и напишешь себе конспукт» — the palette is read
# from the game, not guessed (KUMM researches/conan-ui-color-scheme/).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-probe-ui-styling.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ROOT = "/Game/UI/Styling"
RICH = "/Game/UI/Data/DataTables/DT_RichTextStyles"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-ui-styling.json")
res = {"ok": False, "styles": {}, "errors": {}}
try:
    lib = unreal.EditorAssetLibrary
    for path in sorted(lib.list_assets(ROOT, recursive=True, include_folder=False)):
        pkg = path.split(".")[0]
        name = pkg.rsplit("/", 1)[-1]
        try:
            cls = unreal.load_class(None, "%s.%s_C" % (pkg, name))
            if cls is None:
                res["errors"][name] = "no class"
                continue
            cdo = unreal.get_default_object(cls)
            res["styles"][pkg.replace(ROOT + "/", "")] = {"parent": cls.get_super_class().get_name() if hasattr(cls, "get_super_class") else None,
                                                         "text": cdo.export_text()[:6000]}
        except Exception as e:
            res["errors"][name] = str(e)[:200]
    try:
        dt = unreal.load_asset(RICH)
        res["rich_text_styles"] = unreal.DataTableFunctionLibrary.export_data_table_to_json_string(dt)[:40000]
    except Exception as e:
        res["errors"]["DT_RichTextStyles"] = str(e)[:200]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
