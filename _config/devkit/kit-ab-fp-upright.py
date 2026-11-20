# kit-ab-fp-upright.py — KUMM bug 95, option B (the owner's pick 2026-11-13 13:20, verbatim in bugs/95): in first person, while the bow is held and NOT drawn,
# the upper body stays upright and only the view pitches — looking down shows the chest, the arms and the bow as the third person shows them.
#
# The cause (kit probe kit-probe-ab-fp-look.py, run 2 2026-11-13 14:17, kit-probe-ab-fp-look.json): AB_human_male's AnimGraph keeps two first-person poses —
#   FirstPersonPoseNotPassive: b_spine_3 rotated by AdjustForLookingUpAndDownFirstPersonAgressive (the FULL view pitch) + the combat arm shifts;
#   FirstPersonPosePassive:    b_spine_3 and b_neck_1 rotated by …Passive (15 % of the pitch) + HeadFOVAdjustments on b_head;
# and a «Blend Poses by bool» chooses them by isPassive (True → Passive, blend 0.1 s). A held bow is a combat stance (isPassive false) → the full bend → the bow
# ≈ 75° under the frame's centre at every pitch (bug 95 forensics).
#
# The edit, native, in the game's own terms:
#   1. a member bool KrinikFirstPersonUpright;
#   2. AnimGraph: the selector's bActiveValue reads KrinikFirstPersonUpright instead of isPassive (a plain member read — thread-safe, the fast path);
#   3. EventGraph, at the head of Event Blueprint Update Animation (the game thread):
#        Branch(isThirdPerson OR isNPC) — True: on to the game's own chain untouched; False:
#        Set KrinikFirstPersonUpright = isPassive OR (GetWeaponArcheType(GetWeaponItemPrimary(CombatBP)) == 3 AND NOT isAttacking) → the game's chain.
#      3 = WeaponArcheTypes::TwoHanded_Ranged — the game's own bow test (BaseBPCombat::EvaluateMovement_RangeCombat = IsAttacking AND GetWeaponItemActive()->
#      GetWeaponArcheType() == 3, bytecode 2026-11-13); a bow draw IS an attack, so «drawn» keeps the full bend and the aim follows the view as in vanilla.
#      The branch keeps the cost off every NPC and every third-person hero: one property read and a branch; the calls run for the first-person player only.
#      Bare hands: GetWeaponItemPrimary gives None, the call on it is skipped silently in the shipping game (ConanSandbox.log: 0 «Accessed None»), isPassive true.
# Why not pin logic on the AnimGraph (run 1–2, 14:31 / 14:35): the blueprint updates on worker threads (use_multi_threaded_animation_update True) and the game's
# two calls are not thread-safe — the compile fails with no node mark; the same rewiring with thread-safe math only compiles (control run 3, 14:39).
# Why the enum goes through Conv_ByteToInt (run 4 and its bisection v1 · v2 · v3 · v3a · v3b, 14:44–15:03 — KRINIK_AB_VARIANT below): GetWeaponArcheType's enum wired
# straight into EqualEqual_ByteByte links «True» from Python and fails the compile silently; the call alone (v3a) and the integer path (v3b) compile.
#
# Run in the kit's mod mode with KrinikConanArchery ACTIVE (active.txt in its folder) — the edited vanilla asset is saved into
# Mods/KrinikConanArchery/Content/Master_AnimBP/AB_human_male.uasset; its FilesToCook line is added to that mod's Local/CookInfo.ini by this script:
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Idempotent: a second run finds the selector already reading KrinikFirstPersonUpright and stops without saving. A failed link, an impure node where a pure
# one is needed, a compile worse than vanilla or new compiler marks stop the run BEFORE the save. Writes kit-ab-fp-upright.json next to this file.
# On a game patch (3.1.0+): re-run on the NEW kit — the override is a whole copy of the hero's anim blueprint and must be re-made from the new vanilla asset.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSET = "/Game/Master_AnimBP/AB_human_male"
ANIM_GRAPH, EVENT_GRAPH = "AnimGraph", "EventGraph"
VAR = "KrinikFirstPersonUpright"
MOD = "KrinikConanArchery"
COOK_LINE = "FilesToCook=Mods/%s/Content/Master_AnimBP/AB_human_male.uasset" % MOD
COOK_INI = r"F:\CEUE5Devkit\UE4\Content\Mods\%s\Local\CookInfo.ini" % MOD
FN_PRIMARY = "/Script/ConanSandbox.AnimInstanceHumanMalePlayer:GetWeaponItemPrimary"
FN_ARCHE = "/Script/ConanSandbox.GameItem:GetWeaponArcheType"
FN_TO_INT = "/Script/Engine.KismetMathLibrary:Conv_ByteToInt"
FN_EQ_INT = "/Script/Engine.KismetMathLibrary:EqualEqual_IntInt"
FN_NOT = "/Script/Engine.KismetMathLibrary:Not_PreBool"
FN_AND = "/Script/Engine.KismetMathLibrary:BooleanAND"
FN_OR = "/Script/Engine.KismetMathLibrary:BooleanOR"
ARCHE_RANGED = "3"            # WeaponArcheTypes::TwoHanded_Ranged, the constant of EvaluateMovement_RangeCombat
UPDATE_EVENT_PIN = "DeltaTimeX"   # the output pin only Event Blueprint Update Animation has — finds the event without its localized title
EXEC_PINS = ("execute", "then")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-ab-fp-upright.json")
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
    return list(pins.list_connected_pins(p))


def node_of(p):
    return pins.get_owning_node(p)


def pname(p):
    return str(pins.get_pin_name(p))


def pin_names(n, direction):
    return [pname(p) for p in lib.list_all_pins(n, direction)]


def pure_call(ed, path):
    # the ':' form is the one the kit takes (EXP-0501); a node with exec pins is refused — every call here feeds a value
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
    # nodes the compiler marked (error_msg) in every graph; the Python compile result is one bool and an anim blueprint's errors reach no LogBlueprint line
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


VARIANT = os.environ.get("KRINIK_AB_VARIANT", "")   # bisection of run 4 (14:44, compile False, no marks): v1 · v2 · v3 — never saved


def vanilla_calls(bp):
    # how the game's own graph calls the two functions: the node's class, its pins and what feeds each input (self especially)
    out = []
    for g in lib.list_graph_names(bp):
        try:
            for n in ged.get_graph_editor_by_name(bp, str(g)).list_all_nodes():
                t = title(n)
                if "GetWeaponItemPrimary" in t or "GetWeaponArcheType" in t or "Get Weapon Item Primary" in t:
                    out.append({"graph": str(g), "node": t, "class": cls(n),
                                "inputs": {pname(p): [title(node_of(q)) + "." + pname(q) for q in linked(p)] for p in lib.list_all_pins(n, IN)}})
        except Exception:
            pass
    return out


res = {"ok": False}
try:
    bp = unreal.load_asset(ASSET)
    try:
        res["parent_class"] = str(bp.get_editor_property("parent_class").get_name())
    except Exception as e:
        res["parent_class"] = "ERR %s" % e
    res["vanilla_calls"] = vanilla_calls(bp)[:10]
    res["compile_vanilla"] = lib.compile_blueprint(bp)
    res["marks_vanilla"] = compiler_marks(bp)[:40]
    say("vanilla compile: %s, marked nodes %d" % (res["compile_vanilla"], len(res["marks_vanilla"])))
    # --- AnimGraph: the first-person selector (pose 0 from «…FirstPersonPosePassive», pose 1 from «…NotPassive») ---
    ag = ged.get_graph_editor_by_name(bp, ANIM_GRAPH)
    sels = [n for n in ag.list_all_nodes() if cls(n) == "AnimGraphNode_BlendListByBool"
            and any("FirstPersonPosePassive" in title(node_of(q)) for q in linked(lib.find_input_pin(n, "BlendPose_0")))
            and any("FirstPersonPoseNotPassive" in title(node_of(q)) for q in linked(lib.find_input_pin(n, "BlendPose_1")))]
    if len(sels) != 1:
        raise RuntimeError("expected ONE first-person selector, found %d — NOT saved" % len(sels))
    sel = sels[0]
    target = lib.find_input_pin(sel, "bActiveValue")
    src = linked(target)
    src_desc = [title(node_of(q)) + "." + pname(q) for q in src]
    say("selector bActiveValue fed by %s" % src_desc)
    if len(src) == 1 and pname(src[0]) == VAR:
        res["already"] = src_desc
        raise RuntimeError("already edited (the selector reads %s) — nothing done, NOT saved" % VAR)
    if len(src) != 1 or cls(node_of(src[0])) != "K2Node_VariableGet" or pname(src[0]) != "isPassive":
        raise RuntimeError("the selector is not fed by «Get isPassive» alone (the asset changed?) — NOT saved")
    # --- the member ---
    if VAR not in [str(v) for v in lib.list_member_variable_names(bp)]:
        say("add member %s: %s" % (VAR, lib.add_member_variable(bp, VAR, lib.get_basic_type_by_name("bool"))))
    ok = []
    g_sel = ag.add_get_member_variable_node(VAR)
    pins.break_single_pin_link(src[0], target)
    link(ok, lib.find_output_pin(g_sel, VAR), target, "%s -> selector.bActiveValue" % VAR)
    p = lib.get_node_pos(sel)
    lib.set_node_pos(g_sel, unreal.IntPoint(p.x - 300, p.y + 200))
    # --- EventGraph: the head of Event Blueprint Update Animation ---
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
    game_chain = nexts[0]   # the exec input of the game's first node — both ends of our branch return there
    g_tp = eg.add_get_member_variable_node("isThirdPerson")
    g_npc = eg.add_get_member_variable_node("isNPC")
    or_skip = pure_call(eg, FN_OR)
    br = eg.add_branch_node()
    say("branch pins in %s out %s" % (pin_names(br, IN), pin_names(br, OUT)))
    st = eg.add_set_member_variable_node(VAR)
    say("set pins in %s out %s" % (pin_names(st, IN), pin_names(st, OUT)))
    g_pass = eg.add_get_member_variable_node("isPassive")
    g_att = eg.add_get_member_variable_node("isAttacking")
    g_cbp = eg.add_get_member_variable_node("CombatBP")
    nb = pure_call(eg, FN_NOT)
    and_ = pure_call(eg, FN_AND)
    or_ = pure_call(eg, FN_OR)
    link(ok, lib.find_output_pin(g_att, "isAttacking"), lib.find_input_pin(nb, "A"), "isAttacking -> NOT")
    link(ok, lib.find_output_pin(nb, "ReturnValue"), lib.find_input_pin(and_, "B"), "not attacking -> AND.B")
    prim = arche = eq = None
    if VARIANT == "v1":
        say("variant v1: AND.A left at its default (true) — no game functions")
    else:
        prim = pure_call(eg, FN_PRIMARY)
        prim_in = [q for q in lib.list_all_pins(prim, IN) if pname(q) != "self"]
        if len(prim_in) != 1:
            raise RuntimeError("GetWeaponItemPrimary inputs %s — expected one — NOT saved" % [pname(q) for q in prim_in])
        link(ok, lib.find_output_pin(g_cbp, "CombatBP"), prim_in[0], "CombatBP -> GetWeaponItemPrimary." + pname(prim_in[0]))
        if VARIANT in ("v3a", "v3b"):
            # v3 (the full edit) fails, v2 (the item alone) compiles — split the rest: v3a the archetype call with its output unused, v3b its enum
            # through Conv_ByteToInt into an integer comparison
            isv = pure_call(eg, "/Script/Engine.KismetSystemLibrary:IsValid")
            link(ok, lib.find_output_pin(prim, "ReturnValue"), lib.find_input_pin(isv, "Object"), "item -> IsValid")
            arche = pure_call(eg, FN_ARCHE)
            link(ok, lib.find_output_pin(prim, "ReturnValue"), lib.find_input_pin(arche, "self"), "item -> GetWeaponArcheType.self")
            if VARIANT == "v3a":
                link(ok, lib.find_output_pin(isv, "ReturnValue"), lib.find_input_pin(and_, "A"), "IsValid -> AND.A")
            else:
                conv = pure_call(eg, "/Script/Engine.KismetMathLibrary:Conv_ByteToInt")
                eqi = pure_call(eg, "/Script/Engine.KismetMathLibrary:EqualEqual_IntInt")
                link(ok, lib.find_output_pin(arche, "ReturnValue"), lib.find_input_pin(conv, "InByte"), "archetype -> ToInt")
                link(ok, lib.find_output_pin(conv, "ReturnValue"), lib.find_input_pin(eqi, "A"), "int -> ==.A")
                ok.append(pins.set_pin_value(lib.find_input_pin(eqi, "B"), ARCHE_RANGED))
                link(ok, lib.find_output_pin(eqi, "ReturnValue"), lib.find_input_pin(and_, "A"), "bow -> AND.A")
        elif VARIANT == "v2":
            # the item alone into AND.A through IsValid — the second game function left out
            isv = pure_call(eg, "/Script/Engine.KismetSystemLibrary:IsValid")
            link(ok, lib.find_output_pin(prim, "ReturnValue"), lib.find_input_pin(isv, "Object"), "item -> IsValid")
            link(ok, lib.find_output_pin(isv, "ReturnValue"), lib.find_input_pin(and_, "A"), "IsValid -> AND.A")
        else:
            # the enum goes through Conv_ByteToInt into an integer comparison: wired straight into EqualEqual_ByteByte the Python link says True and
            # the compile fails silently (bisection 2026-11-13 15:0x: v3 False, v3a — the call alone — True, v3b — this path — True)
            arche = pure_call(eg, FN_ARCHE)
            conv = pure_call(eg, FN_TO_INT)
            eq = pure_call(eg, FN_EQ_INT)
            link(ok, lib.find_output_pin(prim, "ReturnValue"), lib.find_input_pin(arche, "self"), "item -> GetWeaponArcheType.self")
            link(ok, lib.find_output_pin(arche, "ReturnValue"), lib.find_input_pin(conv, "InByte"), "archetype -> ToInt")
            link(ok, lib.find_output_pin(conv, "ReturnValue"), lib.find_input_pin(eq, "A"), "int -> ==.A")
            ok.append(pins.set_pin_value(lib.find_input_pin(eq, "B"), ARCHE_RANGED))
            say("==.B = %s: %s" % (ARCHE_RANGED, ok[-1]))
            link(ok, lib.find_output_pin(eq, "ReturnValue"), lib.find_input_pin(and_, "A"), "bow -> AND.A")
    link(ok, lib.find_output_pin(g_pass, "isPassive"), lib.find_input_pin(or_, "A"), "isPassive -> OR.A")
    link(ok, lib.find_output_pin(and_, "ReturnValue"), lib.find_input_pin(or_, "B"), "bow held, not drawn -> OR.B")
    link(ok, lib.find_output_pin(or_, "ReturnValue"), lib.find_input_pin(st, VAR), "value -> Set " + VAR)
    # the skip condition and the exec
    link(ok, lib.find_output_pin(g_tp, "isThirdPerson"), lib.find_input_pin(or_skip, "A"), "isThirdPerson -> skip.A")
    link(ok, lib.find_output_pin(g_npc, "isNPC"), lib.find_input_pin(or_skip, "B"), "isNPC -> skip.B")
    link(ok, lib.find_output_pin(or_skip, "ReturnValue"), lib.find_input_pin(br, "Condition"), "skip -> Branch.Condition")
    pins.break_single_pin_link(ev_then, game_chain)
    link(ok, ev_then, lib.find_input_pin(br, "execute"), "update event -> Branch")
    link(ok, lib.find_output_pin(br, "then"), game_chain, "Branch.True -> the game's chain")
    link(ok, lib.find_output_pin(br, "else"), lib.find_input_pin(st, "execute"), "Branch.False -> Set")
    link(ok, lib.find_output_pin(st, "then"), game_chain, "Set -> the game's chain")
    # a half-wired graph is never saved: a cut update event stops the whole hero animation update
    if not all(ok):
        raise RuntimeError("a link failed %s — the asset is NOT saved" % ok)
    e = lib.get_node_pos(ev)
    for i, n in enumerate([x for x in (g_tp, g_npc, or_skip, br, st, g_pass, g_att, g_cbp, prim, arche, eq, nb, and_, or_) if x is not None]):
        lib.set_node_pos(n, unreal.IntPoint(e.x + 260 * (i % 7), e.y - 900 + 180 * (i // 7)))
    compiled = lib.compile_blueprint(bp)
    res["marks_edited"] = compiler_marks(bp)[:40]
    res["variant"], res["compile_edited"] = VARIANT or "full", compiled
    say("compile: %s, marked nodes %d" % (compiled, len(res["marks_edited"])))
    if VARIANT:
        raise RuntimeError("bisection variant %s: compile %s — by design NOT saved" % (VARIANT, compiled))
    if not compiled or res["marks_edited"] != res["marks_vanilla"]:
        raise RuntimeError("the edited blueprint compiles worse than vanilla (compile %s, marks %d vs %d) — NOT saved"
                           % (compiled, len(res["marks_edited"]), len(res["marks_vanilla"])))
    say("save: %s" % unreal.EditorAssetLibrary.save_loaded_asset(bp, False))
    # the cook list: a newly overridden vanilla asset needs its FilesToCook line, or the pak silently lacks it (EXP-0501)
    lines = open(COOK_INI, encoding="utf-8").read().splitlines()
    if COOK_LINE not in [l.strip() for l in lines]:
        with open(COOK_INI, "a", encoding="utf-8") as f:
            f.write(COOK_LINE + "\n")
        say("cook list: added %s" % COOK_LINE)
    else:
        say("cook list: already has the line")
    # read back from a fresh graph editor
    eg2 = ged.get_graph_editor_by_name(bp, EVENT_GRAPH)
    ev2 = [n for n in eg2.list_all_nodes() if cls(n) == "K2Node_Event" and UPDATE_EVENT_PIN in pin_names(n, OUT)][0]
    res["readback_event_then"] = [title(node_of(q)) + "." + pname(q) for q in linked(lib.find_output_pin(ev2, "then"))]
    ag2 = ged.get_graph_editor_by_name(bp, ANIM_GRAPH)
    res["readback_selector"] = [[title(node_of(q)) + "." + pname(q) for q in linked(lib.find_input_pin(n, "bActiveValue"))]
                                for n in ag2.list_all_nodes() if n.get_path_name() == sel.get_path_name()]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
