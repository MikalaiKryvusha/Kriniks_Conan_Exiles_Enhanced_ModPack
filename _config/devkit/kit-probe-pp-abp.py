# kit-probe-pp-abp.py — KUMM plan 52 step 1 (read-only, nothing saved): (1) the rotation / translation mode and space of the vanilla AB_human_male ModifyBone nodes on
# b_spine_3, b_neck_1, b_head (our post-process blueprint must counter the full bend in the SAME space); (2) the hero skeleton asset; (3) the AnimGraph node names the kit's
# graph editor offers for a NEW anim blueprint (create_node_from_name takes them) — from a transient blueprint that is never saved.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-probe-pp-abp.json next to this file. [NOT-TESTED]
import json
import os
import traceback
import warnings

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
TMP_DIR, TMP_NAME = "/Game/Mods/KrinikConanArchery/Tmp", "ABP_KrinikProbe"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-pp-abp.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
FIELDS = ("bone_to_modify", "rotation_mode", "rotation_space", "translation_mode", "translation_space", "scale_mode", "scale_space")
res = {"ok": False, "nodes": [], "steps": []}


def field(inner, k):
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            return str(inner.get_editor_property(k))[:120]
    except Exception as e:
        return "ERR %s" % str(e)[:80]


try:
    bp = unreal.load_asset(ASSET)
    try:
        res["skeleton"] = bp.get_editor_property("target_skeleton").get_path_name()
    except Exception as e:
        res["skeleton"] = "ERR %s" % e
    for n in ged.get_graph_editor_by_name(bp, "AnimGraph").list_all_nodes():
        if n.get_class().get_name() != "AnimGraphNode_ModifyBone":
            continue
        t = str(lib.get_node_title(n)).replace("\n", " ")
        if not any(b in t for b in ("b_spine_3", "b_neck_1", "b_head")):
            continue
        try:
            inner = n.get_editor_property("node")
            res["nodes"].append({"title": t, **{k: field(inner, k) for k in FIELDS}})
        except Exception as e:
            res["nodes"].append({"title": t, "error": str(e)})
    # a transient anim blueprint of the hero skeleton, never saved — its AnimGraph's action menu
    skel = bp.get_editor_property("target_skeleton")
    fac = unreal.AnimBlueprintFactory()
    fac.set_editor_property("target_skeleton", skel)
    fac.set_editor_property("parent_class", unreal.AnimInstance)
    abp = unreal.AssetToolsHelpers.get_asset_tools().create_asset(TMP_NAME, TMP_DIR, unreal.AnimBlueprint, fac)
    res["steps"].append("transient ABP: %s" % (abp.get_path_name() if abp else None))
    graphs = [str(g) for g in lib.list_graph_names(abp)] if abp else []
    res["tmp_graphs"] = graphs
    ag = ged.get_graph_editor_by_name(abp, "AnimGraph")
    avail = [str(a) for a in ag.list_available_nodes([])]
    res["available_count"] = len(avail)
    keys = ("Bone", "Pose", "Space", "Blend", "Layered", "Cached", "Look", "Aim")
    res["available_anim"] = [a for a in avail if any(k in a for k in keys)][:200]
    # the whole catalog to a text file: the names are localized (Russian editor), grep it for the anim nodes (run 1, 15:37: the key filter caught struct breaks only)
    with open(os.path.join(os.path.dirname(REPORT), "kit-probe-pp-abp-catalog.txt"), "w", encoding="utf-8") as f:
        f.write(chr(10).join(avail))
    res["existing_tmp_nodes"] = [str(lib.get_node_title(n)).replace("\n", " ") + " · " + n.get_class().get_name() for n in ag.list_all_nodes()]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
