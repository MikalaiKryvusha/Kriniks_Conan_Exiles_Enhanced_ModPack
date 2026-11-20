# kit-probe-ab-children.py — KUMM bug 95 (read-only): every anim blueprint of the GAME (the kit's asset registry) whose parent chain reaches AB_human_male_C.
# Why: overriding AB_human_male alone stood the heroine in the bind pose (2026-11-13 15:14, ConanSandbox.log «Anim BP 'AB_human_female_C' has inconsistent folded node
# data … a parent/root anim BP was over[ridden]») — every child must be re-cooked with the parent. Writes kit-probe-ab-children.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ROOT = "AB_human_male_C"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-ab-children.json")
res = {"ok": False, "children": []}
try:
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    flt = unreal.ARFilter(class_names=["AnimBlueprint"], recursive_classes=True) if hasattr(unreal.ARFilter, "class_names") else None
    assets = reg.get_assets(flt) if flt else reg.get_assets_by_class("AnimBlueprint")
    parents = {}
    for a in assets:
        pkg = str(a.package_name)
        tag = ""
        for t in ("ParentClass", "NativeParentClass"):
            try:
                v = a.get_tag_value(t)
                if v and t == "ParentClass":
                    tag = str(v)
            except Exception:
                pass
        parents[pkg] = tag
    res["anim_blueprints"] = len(parents)

    def reaches(pkg, depth=0):
        tag = parents.get(pkg, "")
        if ROOT in tag:
            return True
        if depth > 8 or not tag:
            return False
        # the parent tag is a class path «…/Game/X/Y.Y_C'» — walk to that package
        p = tag.split("'")[1] if "'" in tag else tag
        p = p.split(".")[0]
        return p in parents and reaches(p, depth + 1)

    for pkg, tag in sorted(parents.items()):
        if pkg.endswith("/AB_human_male"):
            continue
        if reaches(pkg):
            res["children"].append({"package": pkg, "parent": tag})
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
