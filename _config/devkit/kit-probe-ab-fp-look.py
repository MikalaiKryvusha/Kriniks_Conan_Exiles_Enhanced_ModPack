# kit-probe-ab-fp-look.py — KUMM bug 95 (option B, the owner's pick 2026-11-13 13:20: the upper body stays upright in first person while the bow is held and not
# drawn). READ-ONLY probe of the hero's anim blueprint AB_human_male: where the first-person look variables AdjustForLookingUpAndDownFirstPersonAgressive /
# …Passive (and ShouldUseFullAimOffset, FirstPersonPelvisHeight) feed in the AnimGraph — the nodes their pins link to (two hops downstream), the bone-modify
# nodes' own settings, and the nodes that consume the cached poses FirstPersonPosePassive / FirstPersonPoseNotPassive (what chooses between them, and by what).
# Nothing is saved. Writes kit-probe-ab-fp-look.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback
import warnings

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-ab-fp-look.json")
WATCH = ("AdjustForLookingUpAndDown", "ShouldUseFullAimOffset", "FirstPersonPelvisHeight", "FirstPersonPose", "ShouldUseAimOffset", "ArmAimOffset")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
res = {"ok": False, "graphs": [], "watched": [], "consumers": []}


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def node_props(n):
    # an AnimGraphNode keeps its runtime node in the «node» property; dump its readable fields (bones, spaces, modes, alphas).
    # Run 1 (2026-11-13 13:28) died here: the kit turns a DeprecationWarning into an exception on getattr of a deprecated property
    # (AnimNode_BlendListByBool.reset_child_on_activation) — every read is guarded and warnings are silenced per key.
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
            out[k] = str(v)[:200]
        except Exception:
            pass
    return out


def inputs(n):
    # one hop UPSTREAM: every input pin of n, what feeds it (node title · its pin) or its default value — for a blend node this names
    # what selects between its poses (the bool / enum / alpha source)
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


BLENDS = ("BlendListBy", "LayeredBoneBlend", "TwoWayBlend", "BlendSpace", "UseCachedPose", "SaveCachedPose", "ModifyBone")


def hop(n, depth, seen):
    # the nodes downstream of every output pin of n, depth levels deep
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
            res["watched"].append({"node": t, "class": cls(n), "down": hop(n, 3, set())})
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
