# kit-ab-bow-draw-upper.py — KUMM bug 104 / interview #038 (`[OWNER]` 2026-11-17 09:18, answer A «Как стоя»: walking in the bow draw keeps the standing draw — the
# right hand at the chin, the string fully drawn).
#
# The cause (kit probes kit-probe-ab-torso-slot.py / kit-probe-ab-torso-blend.py, 2026-11-17 10:48 / 10:53): AB_human_male's AnimGraph has a «Blend Poses by bool»
# driven by isCrouching — True: ONE LayeredBoneBlend (base PostEquipPose, layer TorsoAttackPose — the attack slot AttackMontageTorso3rd —, filter b_spine_1 depth 3,
# weight 1.0, mesh-space rotation): the whole upper body from the draw; False: the standing / walking chain of hand-tuned partial blends (0.7 / 0.33 / 0.44) that
# then takes b_R_clavicle / b_L_clavicle BACK from PostEquipPose — the locomotion's shoulders: walking moves the right arm off the chin.
#
# The edit, in the game's own terms (the pattern of kit-ab-fp-upright.py in the same KrinikConanArchery override):
#   1. a member bool KrinikBowDrawUpper;
#   2. AnimGraph: that selector's bActiveValue reads KrinikBowDrawUpper instead of isCrouching (a plain member read — thread-safe, the fast path);
#   3. EventGraph, at the head of Event Blueprint Update Animation (the game thread): Branch(isNPC OR NOT isAttacking) —
#        True:  Set KrinikBowDrawUpper = isCrouching (the game's own choice, no game call — every NPC and every hero not attacking);
#        False: Set KrinikBowDrawUpper = isCrouching OR (GetWeaponArcheType(GetWeaponItemPrimary(CombatBP)) → Conv_ByteToInt == 3) — the bow draw takes the
#               crouch branch's whole upper body while standing and walking; melee keeps the game's chain;
#      both → the game's chain (the update event's former first node — fp-upright's Branch when that edit is in).
#      3 = WeaponArcheTypes::TwoHanded_Ranged (the game's own bow test, EvaluateMovement_RangeCombat); the enum goes through Conv_ByteToInt (fp-upright v3b).
# Run in the kit's mod mode with KrinikConanArchery ACTIVE — the override AB_human_male.uasset of that mod is edited (its cook line is in Local/CookInfo.ini since
# bug 95; checked again here):
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Idempotent: a second run finds the selector already reading KrinikBowDrawUpper and stops without saving. A failed link, an impure node, a compile worse than
# before the edit or new compiler marks stop the run BEFORE the save. Writes kit-ab-bow-draw-upper.json next to this file. [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
ANIM_GRAPH, EVENT_GRAPH = "AnimGraph", "EventGraph"
VAR = "KrinikBowDrawUpper"
MOD = "KrinikConanArchery"
COOK_LINE = "FilesToCook=Mods/%s/Content/Master_AnimBP/AB_human_male.uasset" % MOD
COOK_INI = r"F:\CEUE5Devkit\UE4\Content\Mods\%s\Local\CookInfo.ini" % MOD
FN_PRIMARY = "/Script/ConanSandbox.AnimInstanceHumanMalePlayer:GetWeaponItemPrimary"
FN_ARCHE = "/Script/ConanSandbox.GameItem:GetWeaponArcheType"
FN_TO_INT = "/Script/Engine.KismetMathLibrary:Conv_ByteToInt"
FN_EQ_INT = "/Script/Engine.KismetMathLibrary:EqualEqual_IntInt"
FN_NOT = "/Script/Engine.KismetMathLibrary:Not_PreBool"
FN_OR = "/Script/Engine.KismetMathLibrary:BooleanOR"
ARCHE_RANGED = "3"
UPDATE_EVENT_PIN = "DeltaTimeX"
EXEC_PINS = ("execute", "then")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-ab-bow-draw-upper.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
IN, OUT = unreal.EdGraphPinDirection.EGPD_INPUT, unreal.EdGraphPinDirection.EGPD_OUTPUT
steps = []


def say(s):
    steps.append(s)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def linked(p):
    return list(pins.list_connected_pins(p)) if p else []


def node_of(p):
    return pins.get_owning_node(p)


def pname(p):
    return str(pins.get_pin_name(p))


def pin_names(n, direction):
    return [pname(p) for p in lib.list_all_pins(n, direction)]


def pure_call(ed, path):
    for p in (path, path.replace(":", ".")):
        try:
            n = ed.add_call_function_node(p)
            if n:
                names = pin_names(n, IN) + pin_names(n, OUT)
                say("call node %s via %s, pins %s" % (title(n), p, names))
                if any(e in names for e in EXEC_PINS):
                    raise RuntimeError("%s is impure (exec pins) — NOT saved" % path)
                return n
        except RuntimeError:
            raise
        except Exception as e:
            say("call node %s ERR %s" % (p, e))
    raise RuntimeError("cannot create " + path)


def link(ok, a, b, what):
    r = pins.try_create_connection(a, b)
    say("link %s: %s" % (what, r))
    ok.append(r)


def compiler_marks(bp):
    marks = []
    for g in lib.list_graph_names(bp):
        try:
            for n in ged.get_graph_editor_by_name(bp, str(g)).list_all_nodes():
                try:
                    v = n.get_editor_property("error_msg")
                except Exception:
                    continue
                if v:
                    marks.append({"graph": str(g), "node": title(n), "msg": str(v)[:300]})
        except Exception:
            pass
    return marks


def fed_by_torso_layer(n):
    # a LayeredBoneBlend whose layer is the cached pose TorsoAttackPose
    if cls(n) != "AnimGraphNode_LayeredBoneBlend":
        return False
    return any("TorsoAttackPose" in title(node_of(q)) for q in linked(lib.find_input_pin(n, "BlendPoses_0")))


res = {"ok": False}
try:
    # REFUSED until the children step exists (KUMM bugs/95, 2026-11-14 15:27): AB_human_male is the PARENT of AB_human_female (the heroine) and AB_human_werewolf;
    # an override of the parent alone left the children's cooked data stale and put the hero into the T-pose. This edit ships only together with the children
    # re-compiled and saved against the edited parent in the same mod (and their cook lines) — and other mods' children (Immersive Warriors' IMWA_AB_MaleChildDrunk)
    # cannot be re-cooked without their sources: KUMM EXP-0511 «never override a PARENT anim blueprint in a modded build». Kept as the record of the graph edit;
    # the fix goes the post-process route (KUMM bugs/104, plan 52). Never run this file.
    raise RuntimeError("refused: never override the parent anim blueprint in this modded build (KUMM EXP-0511, bug 95 T-pose) — NOT run")
    bp = unreal.load_asset(ASSET)
    res["compile_before"] = lib.compile_blueprint(bp)
    res["marks_before"] = compiler_marks(bp)[:40]
    say("compile before: %s, marked nodes %d" % (res["compile_before"], len(res["marks_before"])))
    ag = ged.get_graph_editor_by_name(bp, ANIM_GRAPH)
    sels = []
    for n in ag.list_all_nodes():
        if cls(n) != "AnimGraphNode_BlendListByBool":
            continue
        p0 = [node_of(q) for q in linked(lib.find_input_pin(n, "BlendPose_0"))]
        if any(fed_by_torso_layer(m) for m in p0):
            src = linked(lib.find_input_pin(n, "bActiveValue"))
            if any(pname(q) in ("isCrouching", VAR) for q in src):
                sels.append(n)
    if len(sels) != 1:
        raise RuntimeError("expected ONE crouch selector over the torso layer, found %d — NOT saved" % len(sels))
    sel = sels[0]
    target = lib.find_input_pin(sel, "bActiveValue")
    src = linked(target)
    src_desc = [title(node_of(q)) + "." + pname(q) for q in src]
    say("selector bActiveValue fed by %s" % src_desc)
    if len(src) == 1 and pname(src[0]) == VAR:
        res["already"] = src_desc
        raise RuntimeError("already edited (the selector reads %s) — nothing done, NOT saved" % VAR)
    if len(src) != 1 or cls(node_of(src[0])) != "K2Node_VariableGet" or pname(src[0]) != "isCrouching":
        raise RuntimeError("the selector is not fed by «Get isCrouching» alone — NOT saved")
    if VAR not in [str(v) for v in lib.list_member_variable_names(bp)]:
        say("add member %s: %s" % (VAR, lib.add_member_variable(bp, VAR, lib.get_basic_type_by_name("bool"))))
    ok = []
    g_sel = ag.add_get_member_variable_node(VAR)
    pins.break_single_pin_link(src[0], target)
    link(ok, lib.find_output_pin(g_sel, VAR), target, "%s -> selector.bActiveValue" % VAR)
    p = lib.get_node_pos(sel)
    lib.set_node_pos(g_sel, unreal.IntPoint(p.x - 300, p.y + 200))
    eg = ged.get_graph_editor_by_name(bp, EVENT_GRAPH)
    evs = [n for n in eg.list_all_nodes() if cls(n) == "K2Node_Event" and UPDATE_EVENT_PIN in pin_names(n, OUT)]
    if len(evs) != 1:
        raise RuntimeError("expected ONE Event Blueprint Update Animation, found %d — NOT saved" % len(evs))
    ev = evs[0]
    ev_then = lib.find_output_pin(ev, "then")
    nexts = linked(ev_then)
    say("update event: %s, then -> %s" % (title(ev), [title(node_of(q)) + "." + pname(q) for q in nexts]))
    if len(nexts) != 1:
        raise RuntimeError("the update event's exec goes to %d nodes, expected 1 — NOT saved" % len(nexts))
    chain = nexts[0]
    g_npc = eg.add_get_member_variable_node("isNPC")
    g_att = eg.add_get_member_variable_node("isAttacking")
    g_cr1 = eg.add_get_member_variable_node("isCrouching")
    g_cr2 = eg.add_get_member_variable_node("isCrouching")
    g_cbp = eg.add_get_member_variable_node("CombatBP")
    nott = pure_call(eg, FN_NOT)
    skip = pure_call(eg, FN_OR)
    br = eg.add_branch_node()
    st_plain = eg.add_set_member_variable_node(VAR)
    st_bow = eg.add_set_member_variable_node(VAR)
    prim = pure_call(eg, FN_PRIMARY)
    prim_in = [q for q in lib.list_all_pins(prim, IN) if pname(q) != "self"]
    if len(prim_in) != 1:
        raise RuntimeError("GetWeaponItemPrimary inputs %s — expected one — NOT saved" % [pname(q) for q in prim_in])
    arche = pure_call(eg, FN_ARCHE)
    conv = pure_call(eg, FN_TO_INT)
    eq = pure_call(eg, FN_EQ_INT)
    orb = pure_call(eg, FN_OR)
    link(ok, lib.find_output_pin(g_att, "isAttacking"), lib.find_input_pin(nott, "A"), "isAttacking -> NOT")
    link(ok, lib.find_output_pin(g_npc, "isNPC"), lib.find_input_pin(skip, "A"), "isNPC -> skip.A")
    link(ok, lib.find_output_pin(nott, "ReturnValue"), lib.find_input_pin(skip, "B"), "not attacking -> skip.B")
    link(ok, lib.find_output_pin(skip, "ReturnValue"), lib.find_input_pin(br, "Condition"), "skip -> Branch.Condition")
    link(ok, lib.find_output_pin(g_cr1, "isCrouching"), lib.find_input_pin(st_plain, VAR), "isCrouching -> Set (plain)")
    link(ok, lib.find_output_pin(g_cbp, "CombatBP"), prim_in[0], "CombatBP -> GetWeaponItemPrimary." + pname(prim_in[0]))
    link(ok, lib.find_output_pin(prim, "ReturnValue"), lib.find_input_pin(arche, "self"), "item -> GetWeaponArcheType.self")
    link(ok, lib.find_output_pin(arche, "ReturnValue"), lib.find_input_pin(conv, "InByte"), "archetype -> ToInt")
    link(ok, lib.find_output_pin(conv, "ReturnValue"), lib.find_input_pin(eq, "A"), "int -> ==.A")
    ok.append(pins.set_pin_value(lib.find_input_pin(eq, "B"), ARCHE_RANGED))
    say("==.B = %s: %s" % (ARCHE_RANGED, ok[-1]))
    link(ok, lib.find_output_pin(g_cr2, "isCrouching"), lib.find_input_pin(orb, "A"), "isCrouching -> OR.A")
    link(ok, lib.find_output_pin(eq, "ReturnValue"), lib.find_input_pin(orb, "B"), "bow -> OR.B")
    link(ok, lib.find_output_pin(orb, "ReturnValue"), lib.find_input_pin(st_bow, VAR), "value -> Set (bow)")
    pins.break_single_pin_link(ev_then, chain)
    link(ok, ev_then, lib.find_input_pin(br, "execute"), "update event -> Branch")
    link(ok, lib.find_output_pin(br, "then"), lib.find_input_pin(st_plain, "execute"), "Branch.True -> Set (plain)")
    link(ok, lib.find_output_pin(br, "else"), lib.find_input_pin(st_bow, "execute"), "Branch.False -> Set (bow)")
    link(ok, lib.find_output_pin(st_plain, "then"), chain, "Set (plain) -> the chain")
    link(ok, lib.find_output_pin(st_bow, "then"), chain, "Set (bow) -> the chain")
    if not all(ok):
        raise RuntimeError("a link failed %s — the asset is NOT saved" % ok)
    e = lib.get_node_pos(ev)
    for i, n in enumerate((g_npc, g_att, nott, skip, br, g_cr1, st_plain, g_cbp, prim, arche, conv, eq, g_cr2, orb, st_bow)):
        lib.set_node_pos(n, unreal.IntPoint(e.x + 260 * (i % 8), e.y - 1500 + 180 * (i // 8)))
    compiled = lib.compile_blueprint(bp)
    res["marks_edited"] = compiler_marks(bp)[:40]
    res["compile_edited"] = compiled
    say("compile: %s, marked nodes %d" % (compiled, len(res["marks_edited"])))
    if not compiled or res["marks_edited"] != res["marks_before"]:
        raise RuntimeError("the edited blueprint compiles worse than before (compile %s, marks %d vs %d) — NOT saved"
                           % (compiled, len(res["marks_edited"]), len(res["marks_before"])))
    say("save: %s" % unreal.EditorAssetLibrary.save_loaded_asset(bp, False))
    lines = open(COOK_INI, encoding="utf-8").read().splitlines()
    say("cook list has the line: %s" % (COOK_LINE in [l.strip() for l in lines]))
    ag2 = ged.get_graph_editor_by_name(bp, ANIM_GRAPH)
    res["readback_selector"] = [[title(node_of(q)) + "." + pname(q) for q in linked(lib.find_input_pin(n, "bActiveValue"))]
                                for n in ag2.list_all_nodes() if n.get_path_name() == sel.get_path_name()]
    eg2 = ged.get_graph_editor_by_name(bp, EVENT_GRAPH)
    ev2 = [n for n in eg2.list_all_nodes() if cls(n) == "K2Node_Event" and UPDATE_EVENT_PIN in pin_names(n, OUT)][0]
    res["readback_event_then"] = [title(node_of(q)) + "." + pname(q) for q in linked(lib.find_output_pin(ev2, "then"))]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
