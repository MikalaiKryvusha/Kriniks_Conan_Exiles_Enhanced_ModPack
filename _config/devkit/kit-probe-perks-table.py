# kit-probe-perks-table.py — KUMM plan 49 step 2 (placeholder perks 21–40), READ-ONLY probe: nothing is saved.
# Reads the vanilla /Game/Systems/Perks/PerksTable (row struct PerksTableRow): every row name and its columns as strings, plus the struct's
# property names — the shape our own DT_KrinikPerks must copy so ModController.MergeDataTables takes it.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-probe-perks-table.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

TABLE = "/Game/Systems/Perks/PerksTable"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-perks-table.json")
COLS = ("PerkName", "PerkDescription", "Icon", "TargetIntStat", "AttributePointsRequired")

res = {"table": TABLE}
try:
    dt = unreal.load_asset(TABLE)
    if dt is None:
        raise RuntimeError("table not found")
    dfl = unreal.DataTableFunctionLibrary
    res["class"] = dt.get_class().get_name()
    try:
        rs = dt.get_editor_property("row_struct")
        res["row_struct"] = rs.get_path_name() if rs else None
    except Exception as e:
        res["row_struct"] = "ERR %s" % str(e)[:160]
    names = [str(n) for n in dfl.get_data_table_row_names(dt)]
    res["row_count"] = len(names)
    cols = {}
    for c in COLS:
        try:
            cols[c] = [str(v) for v in dfl.get_data_table_column_as_string(dt, c)]
        except Exception as e:
            cols[c] = "ERR %s" % str(e)[:160]
    rows = []
    for i, n in enumerate(names):
        r = {"Name": n}
        for c in COLS:
            v = cols[c]
            r[c] = v[i] if isinstance(v, list) and i < len(v) else v
        rows.append(r)
    res["rows"] = rows
    # every column the struct carries (a column we do not know about would be left default in our rows)
    try:
        res["export_text_head"] = dt.export_text()[:4000] if hasattr(dt, "export_text") else None
    except Exception as e:
        res["export_text_head"] = "ERR %s" % str(e)[:160]
    try:
        res["json_head"] = dfl.export_data_table_to_json_string(dt)[:6000] if hasattr(dfl, "export_data_table_to_json_string") else None
    except Exception as e:
        res["json_head"] = "ERR %s" % str(e)[:160]
    # who references the table (the readers that list an attribute's perks)
    try:
        reg = unreal.AssetRegistryHelpers.get_asset_registry()
        opts = unreal.AssetRegistryDependencyOptions(include_soft_package_references=True, include_hard_package_references=True)
        res["referencers"] = [str(p) for p in reg.get_referencers("/Game/Systems/Perks/PerksTable", opts)]
    except Exception as e:
        res["referencers"] = "ERR %s" % str(e)[:200]
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
