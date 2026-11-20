# kit-krinik-perks.py — KUMM plan 49 step 2 (the owner's order 2026-11-10 10:28: placeholder perks for 21–40 in one attribute, so the pages past 20, their pips
# and the right perk column are proven to take future perks). Creates Local/DT_KrinikPerks in the KrinikConanUI kit: row struct PerksTableRow (the vanilla
# /Game/Systems/Perks/PerksTable's, read by kit-probe-perks-table.py 2026-11-10 11:33 — 48 rows, TargetIntStat is the attribute's stat enum name), FOUR rows for
# Живучесть (AttributeHealth) at 25 / 30 / 35 / 40. The table reaches the game's PerksTable by a merge at runtime (Lua section krinik_mod_settings →
# ModController.MergeDataTables, the same native path as DT_KrinikUIModule). A placeholder has no effect by construction: the effects live in blueprints that ask
# HasPerk(<vanilla row name>) — no blueprint knows our row names.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Idempotent: the table is reused and refilled. Writes kit-krinik-perks.json next to this file. Needs the CookInfo line
# FilesToCook=Mods/KrinikConanUI/Local/DT_KrinikPerks.uasset (the kit cooks only listed assets).
# [NOT-TESTED]
import json
import os
import traceback

import unreal

PKG = "/Game/Mods/KrinikConanUI"
DT = "DT_KrinikPerks"
STRUCT = "/Script/ConanSandbox.PerksTableRow"
VANILLA = "/Game/Systems/Perks/PerksTable"
ICONS = "/Script/Engine.Texture2D'/Game/UI/Textures/GUIs/Inventory/PerkIcons/%s.%s'"
STAT = "AttributeHealth"          # Живучесть — its right column is already the one cut at the bottom (plan 49, the owner's 2026-11-07 22:02 frame): the scroll shows there
# [AI] the placeholder texts (plan 49 step 2: «a neutral name and a placeholder description»); one icon per level from the vanilla set
PERKS = [
    (25, "T_PerkIcon_01"),
    (30, "T_PerkIcon_02_a"),
    (35, "T_PerkIcon_03"),
    (40, "T_PerkIcon_03_a"),
]
NAME = "Перк %d-го уровня (заглушка)"
DESC = "Место для будущего перка сборки. Пока перк ничего не даёт."
ROW = "Krinik_Vitality_%d"        # our prefix: a future vanilla «Vitality_25» never collides with a placeholder
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-krinik-perks.json")

res = {"steps": []}
step = res["steps"].append
try:
    lib = unreal.EditorAssetLibrary
    tools = unreal.AssetToolsHelpers.get_asset_tools()
    dfl = unreal.DataTableFunctionLibrary
    rs = unreal.load_object(None, STRUCT)
    if rs is None:
        raise RuntimeError("row struct %s not found" % STRUCT)
    dpath = "%s/%s" % (PKG, DT)
    if lib.does_asset_exist(dpath):
        dt = unreal.load_asset(dpath)
        have = dt.get_editor_property("row_struct")
        if have != rs:   # a table of another struct would take the rows wrongly (judge round 1)
            raise RuntimeError("table %s has row struct %s, not %s — NOT saved" % (dpath, have.get_path_name() if have else None, STRUCT))
        step("table reused " + dt.get_path_name())
    else:
        df = unreal.DataTableFactory()
        df.set_editor_property("struct", rs)
        dt = tools.create_asset(DT, PKG, unreal.DataTable, df)
        if dt is None:
            raise RuntimeError("table not created")
        step("table created " + dt.get_path_name())
    rows = [{"Name": ROW % req, "PerkName": NAME % req, "PerkDescription": DESC, "Icon": ICONS % (icon, icon),
             "TargetIntStat": STAT, "AttributePointsRequired": req} for req, icon in PERKS]
    step("fill_data_table_from_json_string -> %s" % dfl.fill_data_table_from_json_string(dt, json.dumps(rows, ensure_ascii=False)))
    names = [str(n) for n in dfl.get_data_table_row_names(dt)]
    res["rows"] = names
    cols = {}
    for c in ("PerkName", "PerkDescription", "Icon", "TargetIntStat", "AttributePointsRequired"):
        cols[c] = [str(v) for v in dfl.get_data_table_column_as_string(dt, c)]
    res["columns"] = cols
    # the same columns of one vanilla row, side by side (format check: an enum or a reference read back differently is a format error)
    van = unreal.load_asset(VANILLA)
    vn = [str(n) for n in dfl.get_data_table_row_names(van)]
    if "Vitality_15" in vn:   # a side-by-side only — its absence never stops the run (judge round 3)
        i = vn.index("Vitality_15")
        res["vanilla_Vitality_15"] = {c: str(dfl.get_data_table_column_as_string(van, c)[i]) for c in cols}
    ok_rows = names == [ROW % req for req, _ in PERKS]
    ok_stat = all(v == STAT for v in cols["TargetIntStat"])
    # the icon must EXIST, not only read as a path (a misspelled name shows an empty icon — judge round 3)
    ok_icon = all(lib.does_asset_exist("/Game/UI/Textures/GUIs/Inventory/PerkIcons/" + icon) for _, icon in PERKS) and \
        all("PerkIcons" in v for v in cols["Icon"])
    ok_req = cols["AttributePointsRequired"] == [str(req) for req, _ in PERKS]   # the column that places the pips (judge round 2)
    res["checks"] = {"rows": ok_rows, "stat": ok_stat, "icon": ok_icon, "req": ok_req}
    if not (ok_rows and ok_stat and ok_icon and ok_req):
        raise RuntimeError("table read back wrong — not saved: %s" % res["checks"])
    res["saved"] = lib.save_loaded_asset(dt, False)
    res["ok"] = bool(res["saved"])
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
