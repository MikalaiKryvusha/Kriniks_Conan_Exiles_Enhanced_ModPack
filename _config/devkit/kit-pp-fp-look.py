# kit-pp-fp-look.py — KUMM plan 52 step 2: a NEW post-process anim blueprint /Game/Mods/KrinikConanArchery/ABP_KrinikFirstPersonLook (parent AnimInstance, the hero
# skeleton). It runs after the game's anim on the hero's mesh ONLY (KrinikConanArchery's Lua sets it by SetOverridePostProcessAnimBP) — no vanilla asset is touched
# (the AB_human_male override broke its child anim blueprints, EXP-0511).
#   AnimGraph: Input Pose → Local→Component → b_spine_3 rotation ADDITIVE / COMPONENT  Roll = Pitch × SpineUndo   (undoes the combat pose's full bend: vanilla adds
#              Roll = −Pitch in the same space — kit-probe-pp-abp.json)
#            → b_neck_1 rotation ADDITIVE / COMPONENT  Roll = −min(Pitch, 0) × NeckShare   (the neck bends forward looking down — the industry's spine → neck → head)
#            → b_head translation ADDITIVE / BONE  (EyeX, EyeY, EyeZ)   (the camera point from the head's pivot toward the eyes; the camera rides b_headcam, a child)
#            → Component→Local → Output; every node's Alpha = Alpha.
#   EventGraph (Blueprint Update Animation): PitchNow = NormalizeAxis(main anim instance's Pitch); Alpha = FInterpTo(Alpha, Active ? 1 : 0, dt, BlendSpeed).
#   Active is written by KrinikConanArchery's Lua on events (first person · the bow in hand · no draw) — the anim does not poll the game's flags it cannot read
#   (isAttacking / isThirdPerson have no getter outside the game's blueprint; Pitch has — the catalog, 2026-11-13).
# Tunables live on the instance (the remote sets them): SpineUndo, NeckShare, EyeX/EyeY/EyeZ, BlendSpeed; their defaults are written into the class defaults.
# KRINIK_PP_SAVE=1 saves; without it the run builds, compiles and reports the pins — nothing saved. Writes kit-pp-fp-look.json. Mod mode, KrinikConanArchery active:
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

DIR, NAME = "/Game/Mods/KrinikConanArchery", "ABP_KrinikFirstPersonLook"
HERO_ABP = "/Game/Master_AnimBP/AB_human_male"
COOK_LINE = "FilesToCook=Mods/KrinikConanArchery/Local/%s.uasset" % NAME
COOK_INI = r"F:\CEUE5Devkit\UE4\Content\Mods\KrinikConanArchery\Local\CookInfo.ini"
SAVE = os.environ.get("KRINIK_PP_SAVE", "") == "1"
DEFAULTS = {"SpineUndo": 0.85, "NeckShare": 0.5, "EyeX": 0.0, "EyeY": 0.0, "EyeZ": 0.0, "BlendSpeed": 8.0}
N_INPUT = "Анимация|Графыпривязаннойанимации|Входнаяпоза"
N_L2C = "Анимация|Преобразованиепространств|Отлокальногообъектаккомпоненту"
N_C2L = "Анимация|Преобразованиепространств|Откомпонентаклокальномуобъекту"
N_MODIFY = "Animation|SkeletalControls|Преобразовать(изменить)кость"
N_MAIN = "Анимация|GetMainAnimInstance"
N_CAST = "Утилиты|Casting|CastToAnimInstanceHumanMale"
N_PITCH = "Класс|AnimInstanceHumanMale|ПолучитьPitch"
KML = "/Script/Engine.KismetMathLibrary:"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-pp-fp-look.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
IN, OUT = unreal.EdGraphPinDirection.EGPD_INPUT, unreal.EdGraphPinDirection.EGPD_OUTPUT
steps, ok = [], []


def say(s):
    steps.append(s)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def pnames(n):
    return {"in": [str(pins.get_pin_name(p)) for p in lib.list_all_pins(n, IN)], "out": [str(pins.get_pin_name(p)) for p in lib.list_all_pins(n, OUT)]}


def make(ed, name, x, y):
    n = ed.create_node_from_name(name, unreal.Vector2D(x, y), [])
    if not n:
        raise RuntimeError("cannot create node " + name)
    say("node %s · %s · pins %s" % (title(n), n.get_class().get_name(), pnames(n)))
    return n


def call(ed, fn):
    n = ed.add_call_function_node(KML + fn)
    if not n:
        raise RuntimeError("cannot create " + fn)
    return n


def pin(n, name, direction):
    p = lib.find_input_pin(n, name) if direction == IN else lib.find_output_pin(n, name)
    if p is None:
        raise RuntimeError("no pin %s on %s (pins %s)" % (name, title(n), pnames(n)))
    return p


def link(a, b, what):
    r = pins.try_create_connection(a, b)
    say("link %s: %s" % (what, r))
    ok.append(r)


def setv(p, v, what):
    r = pins.set_pin_value(p, str(v))
    say("value %s = %s: %s" % (what, v, r))
    ok.append(r)


def modify(ed, bone, x, rot_mode, rot_space, tr_mode, tr_space):
    n = make(ed, N_MODIFY, x, 0)
    inner = n.get_editor_property("node")
    ref = inner.get_editor_property("bone_to_modify")
    ref.set_editor_property("bone_name", bone)
    inner.set_editor_property("bone_to_modify", ref)
    inner.set_editor_property("rotation_mode", rot_mode)
    inner.set_editor_property("rotation_space", rot_space)
    inner.set_editor_property("translation_mode", tr_mode)
    inner.set_editor_property("translation_space", tr_space)
    n.set_editor_property("node", inner)
    try:
        n.reconstruct_node()
    except Exception as e:
        say("reconstruct %s: %s" % (bone, e))
    say("modify %s · pins %s" % (bone, pnames(n)))
    return n


res = {"ok": False, "saved": False}
try:
    skel = unreal.load_asset(HERO_ABP).get_editor_property("target_skeleton")
    path = "%s/%s" % (DIR, NAME)
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        say("delete the previous %s: %s" % (path, unreal.EditorAssetLibrary.delete_asset(path)))
    fac = unreal.AnimBlueprintFactory()
    fac.set_editor_property("target_skeleton", skel)
    fac.set_editor_property("parent_class", unreal.AnimInstance)
    abp = unreal.AssetToolsHelpers.get_asset_tools().create_asset(NAME, DIR, unreal.AnimBlueprint, fac)
    say("created %s" % abp.get_path_name())
    for v in ("Active",):
        lib.add_member_variable(abp, v, lib.get_basic_type_by_name("bool"))
    # «float» from get_basic_type_by_name made INTEGER members (run 2, 15:46: SpineUndo 0.85 read back 0, BlendSpeed 8) — UE5's float type is «real»
    # «float» stays INTEGER (runs 2–3: 0.85 reads 0); the pin type's fields are not exposed (run 4); «real» is the UE5 name of the float category — judged by the
    # defaults read back below (0.85 must stay 0.85)
    real = lib.get_basic_type_by_name("real")
    say("float type from «real»: %s" % (real is not None))
    for v in ("Alpha", "PitchNow", *DEFAULTS.keys()):
        lib.add_member_variable(abp, v, real)
    # ---- AnimGraph ----
    ag = ged.get_graph_editor_by_name(abp, "AnimGraph")
    root = [n for n in ag.list_all_nodes() if n.get_class().get_name() == "AnimGraphNode_Root"][0]
    say("root pins %s" % pnames(root))
    inp = make(ag, N_INPUT, -1400, 0)
    l2c = make(ag, N_L2C, -1150, 0)
    MM, SP = unreal.BoneModificationMode, unreal.BoneControlSpace
    spine = modify(ag, "b_spine_3", -900, MM.BMM_ADDITIVE, SP.BCS_COMPONENT_SPACE, MM.BMM_IGNORE, SP.BCS_COMPONENT_SPACE)
    neck = modify(ag, "b_neck_1", -650, MM.BMM_ADDITIVE, SP.BCS_COMPONENT_SPACE, MM.BMM_IGNORE, SP.BCS_COMPONENT_SPACE)
    head = modify(ag, "b_head", -400, MM.BMM_IGNORE, SP.BCS_COMPONENT_SPACE, MM.BMM_ADDITIVE, SP.BCS_BONE_SPACE)
    c2l = make(ag, N_C2L, -150, 0)
    first_out = lambda n: lib.list_all_pins(n, OUT)[0]
    first_in = lambda n: lib.list_all_pins(n, IN)[0]
    link(first_out(inp), first_in(l2c), "input pose -> L2C")
    link(first_out(l2c), pin(spine, "ComponentPose", IN), "L2C -> spine")
    link(pin(spine, "Pose", OUT), pin(neck, "ComponentPose", IN), "spine -> neck")
    link(pin(neck, "Pose", OUT), pin(head, "ComponentPose", IN), "neck -> head")
    link(pin(head, "Pose", OUT), first_in(c2l), "head -> C2L")
    link(first_out(c2l), first_in(root), "C2L -> output")
    # the values on the pins: thread-safe math over members (compiles on an AnimGraph pin — EXP-0510)
    g = lambda name, x, y: (lambda n: (lib.set_node_pos(n, unreal.IntPoint(x, y)), n)[1])(ag.add_get_member_variable_node(name))
    for node in (spine, neck, head):
        link(pin(g("Alpha", -1000, 300), "Alpha", OUT), pin(node, "Alpha", IN), "Alpha -> " + title(node)[:40])
    m1 = call(ag, "Multiply_DoubleDouble")
    link(pin(g("PitchNow", -1300, 400), "PitchNow", OUT), pin(m1, "A", IN), "PitchNow -> ×")
    link(pin(g("SpineUndo", -1300, 450), "SpineUndo", OUT), pin(m1, "B", IN), "SpineUndo -> ×")
    r1 = call(ag, "MakeRotator")
    link(pin(m1, "ReturnValue", OUT), pin(r1, "Roll", IN), "× -> spine Roll")
    link(pin(r1, "ReturnValue", OUT), pin(spine, "Rotation", IN), "rotator -> spine")
    mn = call(ag, "FMin")
    link(pin(g("PitchNow", -1300, 600), "PitchNow", OUT), pin(mn, "A", IN), "PitchNow -> min")
    setv(pin(mn, "B", IN), 0.0, "min.B")
    m2 = call(ag, "Multiply_DoubleDouble")
    link(pin(mn, "ReturnValue", OUT), pin(m2, "A", IN), "min -> ×")
    link(pin(g("NeckShare", -1300, 650), "NeckShare", OUT), pin(m2, "B", IN), "NeckShare -> ×")
    neg = call(ag, "Multiply_DoubleDouble")
    link(pin(m2, "ReturnValue", OUT), pin(neg, "A", IN), "× -> neg")
    setv(pin(neg, "B", IN), -1.0, "neg.B")
    r2 = call(ag, "MakeRotator")
    link(pin(neg, "ReturnValue", OUT), pin(r2, "Roll", IN), "neg -> neck Roll")
    link(pin(r2, "ReturnValue", OUT), pin(neck, "Rotation", IN), "rotator -> neck")
    mv = call(ag, "MakeVector")
    for ax in ("X", "Y", "Z"):
        link(pin(g("Eye" + ax, -1300, 800 + 40 * "XYZ".index(ax)), "Eye" + ax, OUT), pin(mv, ax, IN), "Eye%s -> vector" % ax)
    link(pin(mv, "ReturnValue", OUT), pin(head, "Translation", IN), "vector -> head")
    # ---- EventGraph ----
    eg = ged.get_graph_editor_by_name(abp, "EventGraph")
    evs = [n for n in eg.list_all_nodes() if n.get_class().get_name() == "K2Node_Event"]
    say("event graph events %s" % [title(n) + " " + str(pnames(n)) for n in evs])
    ev = [n for n in evs if "DeltaTimeX" in pnames(n)["out"]]
    if not ev:
        ev = [eg.add_event_override("BlueprintUpdateAnimation")]
        say("event added %s" % pnames(ev[0]))
    ev = ev[0]
    main = make(eg, N_MAIN, 250, 0)
    cast = make(eg, N_CAST, 500, 0)
    gp = make(eg, N_PITCH, 800, 150)
    na = call(eg, "NormalizeAxis")
    st_p = eg.add_set_member_variable_node("PitchNow")
    sel = call(eg, "SelectFloat")
    fi = call(eg, "FInterpTo")
    st_a = eg.add_set_member_variable_node("Alpha")
    link(pin(ev, "then", OUT), pin(cast, "execute", IN), "event -> cast")
    link(lib.list_all_pins(main, OUT)[0], pin(cast, "Object", IN), "main anim -> cast")
    # the cast's typed output is «AsAnim Instance Human Male» (spaces — run 1, 15:44)
    cast_out = [p for p in lib.list_all_pins(cast, OUT) if str(pins.get_pin_name(p)).startswith("As")]
    if not cast_out:
        raise RuntimeError("cast output pin not found %s" % pnames(cast))
    link(cast_out[0], lib.list_all_pins(gp, IN)[0], "cast -> Get Pitch")
    link(lib.list_all_pins(gp, OUT)[0], pin(na, "Angle", IN), "Pitch -> NormalizeAxis")
    link(pin(na, "ReturnValue", OUT), pin(st_p, "PitchNow", IN), "normalized -> Set PitchNow")
    link(pin(cast, "then", OUT), pin(st_p, "execute", IN), "cast ok -> Set PitchNow")
    setv(pin(sel, "A", IN), 1.0, "select.A")
    setv(pin(sel, "B", IN), 0.0, "select.B")
    link(pin(eg.add_get_member_variable_node("Active"), "Active", OUT), pin(sel, "bPickA", IN), "Active -> select")
    link(pin(eg.add_get_member_variable_node("Alpha"), "Alpha", OUT), pin(fi, "Current", IN), "Alpha -> FInterpTo.Current")
    link(pin(sel, "ReturnValue", OUT), pin(fi, "Target", IN), "target -> FInterpTo")
    link(pin(ev, "DeltaTimeX", OUT), pin(fi, "DeltaTime", IN), "dt -> FInterpTo")
    link(pin(eg.add_get_member_variable_node("BlendSpeed"), "BlendSpeed", OUT), pin(fi, "InterpSpeed", IN), "BlendSpeed -> FInterpTo")
    link(pin(fi, "ReturnValue", OUT), pin(st_a, "Alpha", IN), "FInterpTo -> Set Alpha")
    link(pin(st_p, "then", OUT), pin(st_a, "execute", IN), "Set PitchNow -> Set Alpha")
    res["links_failed"] = sum(1 for r in ok if not r)
    if not all(ok):
        raise RuntimeError("%d link(s) failed — NOT saved" % res["links_failed"])
    res["compile"] = lib.compile_blueprint(abp)
    say("compile %s" % res["compile"])
    # read back what the three bone nodes carry after the compile (the modes are set through the node's struct copy — proof they held)
    res["readback"] = []
    for n in ag.list_all_nodes():
        if n.get_class().get_name() == "AnimGraphNode_ModifyBone":
            inner = n.get_editor_property("node")
            res["readback"].append({"title": title(n), **{k: str(inner.get_editor_property(k))[-40:] for k in ("rotation_mode", "rotation_space", "translation_mode", "translation_space")}})
    if not res["compile"]:
        raise RuntimeError("compile False — NOT saved")
    cdo = unreal.get_default_object(abp.generated_class())
    for k, v in DEFAULTS.items():
        cdo.set_editor_property(k, v)
    res["defaults"] = {k: cdo.get_editor_property(k) for k in DEFAULTS}
    if SAVE:
        res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(abp, False)
        lines = open(COOK_INI, encoding="utf-8").read().splitlines()
        if COOK_LINE not in [l.strip() for l in lines]:
            with open(COOK_INI, "a", encoding="utf-8") as f:
                f.write(COOK_LINE + chr(10))
            say("cook list: added")
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
res["steps"] = steps
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
