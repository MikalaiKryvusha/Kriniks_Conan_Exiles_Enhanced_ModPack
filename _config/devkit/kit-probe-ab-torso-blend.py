# kit-probe-ab-torso-blend.py — KUMM bug 104 / interview #038, step 2 of the recon. READ-ONLY. AB_human_male's AnimGraph: every LayeredBoneBlend fed by the
# cached pose TorsoAttackPose (the bow draw's torso slot) — its layer setup in full (each branch filter: bone, blend depth; the blend weights; mesh-space
# flags) — and the Blend Poses by bool it feeds: what drives its bool, its blend times, and what sits on its other pose. Nothing is saved.
# Writes kit-probe-ab-torso-blend.json next to this file. Run like kit-probe-ab-fp-look.py. [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-ab-torso-blend.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
res = {"ok": False, "blends": []}


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def feeders(n):
    rows = []
    for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_INPUT):
        src = [title(pins.get_owning_node(q)) + " · " + str(pins.get_pin_name(q)) for q in pins.list_connected_pins(p)]
        try:
            dv = str(pins.get_default_value(p)) if hasattr(pins, "get_default_value") else ""
        except Exception:
            dv = ""
        rows.append({"pin": str(pins.get_pin_name(p)), "from": src, "default": dv})
    return rows


def consumers(n):
    out = []
    for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_OUTPUT):
        for q in pins.list_connected_pins(p):
            out.append((pins.get_owning_node(q), str(pins.get_pin_name(q))))
    return out


def safe(obj, name):
    try:
        return obj.get_editor_property(name)
    except Exception as e:
        return "<" + str(e)[:80] + ">"


def layer_setup(inner):
    rows = []
    for i, lay in enumerate(safe(inner, "layer_setup") or []):
        filters = []
        for f in (safe(lay, "branch_filters") or []):
            filters.append({"bone": str(safe(f, "bone_name")), "depth": safe(f, "blend_depth")})
        rows.append({"layer": i, "filters": filters})
    return rows


try:
    bp = unreal.load_asset(ASSET)
    ed = ged.get_graph_editor_by_name(bp, "AnimGraph")
    for n in ed.list_all_nodes():
        if "LayeredBoneBlend" not in cls(n):
            continue
        fed = feeders(n)
        if not any("TorsoAttackPose" in s for r in fed for s in r["from"]):
            continue
        inner = n.get_editor_property("node")
        row = {"node": title(n), "inputs": fed, "layers": layer_setup(inner),
               "mesh_rot": str(safe(inner, "mesh_space_rotation_blend")), "mesh_scale": str(safe(inner, "mesh_space_scale_blend")),
               "weights": str(safe(inner, "blend_weights")), "lod": str(safe(inner, "lod_threshold")), "consumers": []}
        for m, pin in consumers(n):
            c = {"node": title(m), "class": cls(m), "pin": pin, "inputs": feeders(m)}
            if "BlendListBy" in cls(m):
                mi = m.get_editor_property("node")
                c["blend_time"] = str(safe(mi, "blend_time"))
            row["consumers"].append(c)
        res["blends"].append(row)
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
