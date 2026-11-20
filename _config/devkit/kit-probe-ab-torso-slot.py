# kit-probe-ab-torso-slot.py — KUMM bug 104 / interview #038 (the owner 2026-11-17 09:18: the standing draw kept while walking). READ-ONLY probe of
# AB_human_male's AnimGraph: the nodes whose title names the torso slot (the bow draw montage plays in AttackMontageTorso3rd / 1st) — two hops downstream,
# with the blend nodes' inputs — and EVERY LayeredBoneBlend node with its runtime settings (branch filters, mesh-space blends) and what feeds it.
# Nothing is saved. Writes kit-probe-ab-torso-slot.json next to this file. Built on kit-probe-ab-fp-look.py (its guarded reads).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback
import warnings

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-ab-torso-slot.json")
WATCH = ("AttackMontageTorso", "Torso", "UpperBody")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
res = {"ok": False, "graphs": [], "watched": [], "layered": []}


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def node_props(n):
    # the runtime node of an AnimGraphNode — its readable fields; every read guarded (the kit turns a DeprecationWarning into an exception — fp-look run 1)
    out = {}
    try:
        inner = n.get_editor_property("node")
    except Exception as e:
        return {"no node": str(e)}
    for k in dir(inner):
        if k.startswith("_"):
            continue
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                v = getattr(inner, k)
            if callable(v):
                continue
            out[k] = str(v)[:600]
        except Exception:
            pass
    return out


def inputs(n):
    # one hop UPSTREAM: every input pin, what feeds it or its default value
    rows = []
    for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_INPUT):
        src = [{"from": title(pins.get_owning_node(q)), "class": cls(pins.get_owning_node(q)), "pin": str(pins.get_pin_name(q))}
               for q in pins.list_connected_pins(p)]
        try:
            dv = str(pins.get_default_value(p)) if hasattr(pins, "get_default_value") else ""
        except Exception:
            dv = ""
        rows.append({"pin": str(pins.get_pin_name(p)), "linked": src, "default": dv})
    return rows


BLENDS = ("BlendListBy", "LayeredBoneBlend", "TwoWayBlend", "BlendSpace", "UseCachedPose", "SaveCachedPose", "ModifyBone", "Slot")


def hop(n, depth, seen):
    rows = []
    if depth == 0 or id(n) in seen:
        return rows
    seen.add(id(n))
    for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_OUTPUT):
        for q in pins.list_connected_pins(p):
            m = pins.get_owning_node(q)
            row = {"from_pin": str(pins.get_pin_name(p)), "to": title(m), "class": cls(m), "to_pin": str(pins.get_pin_name(q))}
            if cls(m).startswith("AnimGraphNode_"):
                row["props"] = node_props(m)
            if any(b in cls(m) for b in BLENDS):
                row["inputs"] = inputs(m)
            row["next"] = hop(m, depth - 1, seen)
            rows.append(row)
    return rows


try:
    bp = unreal.load_asset(ASSET)
    res["graphs"] = [str(g) for g in lib.list_graph_names(bp)] if hasattr(lib, "list_graph_names") else []
    ed = ged.get_graph_editor_by_name(bp, "AnimGraph")
    nodes = list(ed.list_all_nodes())
    res["anim_graph_nodes"] = len(nodes)
    for n in nodes:
        t = title(n)
        if any(w in t for w in WATCH):
            res["watched"].append({"node": t, "class": cls(n), "props": node_props(n), "inputs": inputs(n), "down": hop(n, 2, set())})
        if "LayeredBoneBlend" in cls(n):
            res["layered"].append({"node": t, "class": cls(n), "props": node_props(n), "inputs": inputs(n), "down": hop(n, 1, set())})
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
