# kit-krinik-click-events.py — KUMM bug 85: KrinikConanUI's clicks and Esc become blueprint events that run on the GAME thread, so the mod needs no UE4SS key
# bind (a RegisterKeyBind callback runs Lua on UE4SS's event-loop thread while the mod's game-thread Lua runs — one lua_State, no lock; two crashes, bug 85).
# Recon of the game's own path (bug 85, 2026-11-18 19:3x): an FLX button (WBP_ButtonBase) reports a click only through its multicast SignalClicked (one parameter,
# the button) — vanilla popups bind it in their blueprint, and their cancel button's KeyShortcutName «Escape» closes them; UserWidget mouse events reach a blueprint
# only through an override (the attribute wheel's way, kit-attribute-paging-wheel.py). What this script makes (each part idempotent, said so when skipped):
#   1. W_KrinikClickWrap — a plain UserWidget (Overlay root) our Lua puts AROUND a runtime-made widget: the preview of a left press calls
#      KrinikPreview and returns Unhandled. (A W_KrinikButton — a child of WBP_ButtonBase with SignalClicked → KrinikClicked — was built 2026-11-18 and
#      dropped: a Lua-made FLX button stays dead to a press, bug 85 judge D2, the run of 20:22.)
#   2. W_KrinikClickCatcher — a transparent canvas whose OnMouseButtonDown calls KrinikMouseDown and returns Handled (the click outside the mods list).
#   3. W_KrinikModSettings — OnPreviewMouseButtonDown: a left press calls KrinikMouseDown; OnPreviewKeyDown: Esc calls KrinikEsc; both return
#      Unhandled (the routing by hover and the close stay in Lua).
#   4. W_MainMenu_MainMenu, W_IngameMenu — Construct binds Btn_KrinikFeedback.OnClicked to KrinikFeedbackClicked.
#   5. Local/CookInfo.ini (and the copy in the pack's kit/) — the two new assets listed.
# Order: AFTER kit-conanui-edit.py and kit-krinik-modsettings.py (they make the trees this graph reaches by name); run it TWICE before a build (the GUID trap of
# new widgets — KrinikConanUI.md «Kit Python traps»). Any failed node, link or compile stops the run BEFORE the save of that asset.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-krinik-click-events.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

PKG = "/Game/Mods/KrinikConanUI"                    # → kit UE4/Content/Mods/KrinikConanUI/Local/
WRAP = "W_KrinikClickWrap"
CATCH = "W_KrinikClickCatcher"
WIN = "W_KrinikModSettings"
MENUS = (("/Game/UI/Widgets/MainMenu/W_MainMenu_MainMenu", "W_MainMenu_MainMenu"), ("/Game/UI/HUD/W_IngameMenu", "W_IngameMenu"))
FEEDBACK = "Btn_KrinikFeedback"
EV_PREVIEW, EV_DOWN, EV_ESC, EV_FEEDBACK = "KrinikPreview", "KrinikMouseDown", "KrinikEsc", "KrinikFeedbackClicked"
HERE = os.path.dirname(os.path.abspath(__file__))
COOK = os.path.join("F:" + os.sep, "CEUE5Devkit", "UE4", "Content", "Mods", "KrinikConanUI", "Local", "CookInfo.ini")
COOK_COPY = os.path.normpath(os.path.join(HERE, "..", "..", "_unpacked", "KrinikConanUI", "kit", "CookInfo.ini"))
COOK_LINES = ["FilesToCook=Mods/KrinikConanUI/Local/%s.uasset" % n for n in (WRAP, CATCH)]
COOK_DROP = ["FilesToCook=Mods/KrinikConanUI/Local/W_KrinikButton.uasset"]   # 2026-11-18 20:3x: the dead-click design left
REPORT = os.path.join(HERE, "kit-krinik-click-events.json")
lib = unreal.BlueprintEditorLibrary
ged = unreal.BlueprintGraphEditor
pins = unreal.BlueprintGraphPinLibrary
tools = unreal.AssetToolsHelpers.get_asset_tools()
res = {"ok": False, "steps": [], "links": [], "parts": {}}


def say(s):
    res["steps"].append(s)
    # into the editor log at once too: the report is written only at the end, and an editor crash (AddCallFunctionNode, 2026-11-18 21:13) left no trace of
    # the step it died on
    unreal.log_warning("[kit-click] " + s)


def title(n):
    return str(lib.get_node_title(n)).replace("\n", " / ")


def cls(n):
    return n.get_class().get_name()


def linked(p):
    return list(pins.list_connected_pins(p))


def out(n, name):
    p = lib.find_output_pin(n, name)
    if not p:
        raise RuntimeError("no output pin %s on %s: %s" % (name, title(n), [str(pins.get_pin_name(q)) for q in lib.list_all_pins(n)]))
    return p


def inp(n, name):
    p = lib.find_input_pin(n, name)
    if not p:
        raise RuntimeError("no input pin %s on %s: %s" % (name, title(n), [str(pins.get_pin_name(q)) for q in lib.list_all_pins(n)]))
    return p


def link(a, b, what):
    ok = pins.try_create_connection(a, b)
    res["links"].append((what, ok))
    if not ok:
        raise RuntimeError("link failed: %s — NOT saved" % what)


def literal(p, v):
    if not pins.set_pin_value(p, v):
        raise RuntimeError("literal %r refused by %s" % (v, pins.get_pin_name(p)))


def pos(n, x, y):
    lib.set_node_pos(n, unreal.IntPoint(x, y))


def call(ed, path):
    for p in (path, path.replace(":", ".")):
        try:
            n = ed.add_call_function_node(p)
            if n:
                return n
        except Exception as e:
            say("call node %s ERR %s" % (p, str(e)[:160]))
    raise RuntimeError("cannot create a call of " + path)


CATALOG = {}


def norm(t):
    return t.replace(" ", "").replace("_", "").lower()   # the catalog shows a class name as its display name («WBP Button Base»)


def action(ed, key, words, exact, category=None):
    # a node by its catalog name (the kit's palette is localized — matched by the Latin parts); `exact` = the last «|» segment; `category` = the first
    # segment when the same node stands in two categories (run 1: «Кнопка|Событие|…» and «Ввод|Вводспомощьюмыши|…» for OnClicked; «Menu|Event|…» and
    # «События|…» for SignalClicked); exactly one or the run stops
    if key not in CATALOG:
        CATALOG[key] = [str(n) for n in ed.list_available_nodes([])]
    found = sorted(set(n for n in CATALOG[key] if all(norm(w) in norm(n) for w in words)))
    hits = [h for h in found if norm(h.split("|")[-1]) == norm(exact)]
    if category and len(hits) > 1:
        hits = [h for h in hits if norm(h.split("|")[0]) == norm(category)]
    if len(hits) != 1:
        raise RuntimeError("catalog %s %s -> %d exact of %d: %s" % (key, words, len(hits), len(found), found[:30]))
    return hits[0]


def custom_event(ed, name, x, y):
    # one custom event per name: reused when the graph already has it (idempotent runs)
    for n in ed.list_all_nodes():
        if cls(n) == "K2Node_CustomEvent" and norm(title(n).split(" / ")[0]) == norm(name):   # the title is «<name> / <localized «custom event»>»
            return n, False
    ev = ed.add_custom_event_node(name)
    if not ev:
        raise RuntimeError("custom event %s not created" % name)
    pos(ev, x, y)
    return ev, True


def construct_chain(bp, ed):
    # (exec output to continue from, the node it led to or None): Construct of this blueprint, made when absent
    ev = None
    try:
        ev = ed.find_event_node("Construct")
    except Exception as e:
        say("find_event_node(Construct): %s" % str(e)[:120])
    if not ev:
        for p in (unreal.IntPoint(0, 0), unreal.Vector2D(0.0, 0.0)):
            try:
                ev = lib.add_event_override(bp, "Construct", p)
                if ev:
                    break
            except Exception as e:
                say("add_event_override(Construct, %s): %s" % (type(p).__name__, str(e)[:120]))
    if not ev:
        raise RuntimeError("no Construct event in %s" % bp.get_name())
    then = out(ev, "then")
    nxt = linked(then)
    if len(nxt) > 1:
        raise RuntimeError("Construct of %s: %d links from then" % (bp.get_name(), len(nxt)))
    target = nxt[0] if nxt else None
    if target:
        pins.break_single_pin_link(then, target)
    return then, target


def cast_to(ed, key, klass, obj_pin, x, y):
    n = ed.create_node_from_name(action(ed, key, ["Castto" + klass], "Castto" + klass), unreal.Vector2D(x, y), [])
    if not n:
        raise RuntimeError("no Cast To %s node" % klass)
    obj = [p for p in lib.list_all_pins(n) if str(pins.get_pin_name(p)) == "Object"]
    typed = [p for p in lib.list_all_pins(n, unreal.EdGraphPinDirection.EGPD_OUTPUT) if str(pins.get_pin_name(p)).startswith("As")]
    if not obj or not typed:
        raise RuntimeError("Cast To %s pins: %s" % (klass, [str(pins.get_pin_name(p)) for p in lib.list_all_pins(n)]))
    link(obj_pin, obj[0], "-> Cast To %s" % klass)
    return n, typed[0]


def widget_by_name(ed, name, x, y):
    # self.GetWidgetFromName(Conv_StringToName("<name>")) — an FName pin takes no literal in this kit (attribute step 2, run 3); a String pin does
    conv = call(ed, "/Script/Engine.KismetStringLibrary:Conv_StringToName")
    literal(inp(conv, "InString"), name)
    get = call(ed, "/Script/UMG.UserWidget:GetWidgetFromName")
    name_pin = [p for p in lib.list_all_pins(get) if str(pins.get_pin_name(p)) not in ("self", "ReturnValue", "execute", "then")]
    if len(name_pin) != 1:
        raise RuntimeError("GetWidgetFromName pins: %s" % [str(pins.get_pin_name(p)) for p in lib.list_all_pins(get)])
    link(out(conv, "ReturnValue"), name_pin[0], "%s name -> GetWidgetFromName" % name)
    pos(conv, x - 300, y)
    pos(get, x - 120, y)
    return out(get, "ReturnValue")


def bind(ed, key, words, exact, declaring, target_pin, ev, x, y, what, category=None):
    # «Bind Event to <delegate>» on target_pin (None = self) with OUR custom event; the event takes the delegate's signature from the link
    name = action(ed, key, words, exact, category)
    say("bind %s: catalog node %s" % (what, name))
    node = None
    for extra in (((declaring,) if declaring else ()), ()):
        try:
            node = ed.create_node_from_name(name, unreal.Vector2D(x, y), [target_pin] if target_pin else [], *extra)
        except Exception as e:
            say("bind %s %s: %s" % (what, extra, str(e)[:160]))
        if node:
            break
    if not node:
        raise RuntimeError("no bind node for %s" % what)
    say("bind %s pins: %s" % (what, [str(pins.get_pin_name(p)) for p in lib.list_all_pins(node)]))
    if target_pin and not linked(inp(node, "self")):
        link(target_pin, inp(node, "self"), "%s -> bind.self" % what)
    link(out(ev, "OutputDelegate"), inp(node, "Delegate"), "%s event -> bind" % what)
    return node


def save(bp, part):
    ok = lib.compile_blueprint(bp)
    say("%s: compile %s" % (part, ok))
    if not ok:
        raise RuntimeError("%s does not compile — NOT saved (LogBlueprint: Error in the editor log)" % part)
    s = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    say("%s: saved %s" % (part, s))
    return s


# ---------------------------------------------------------------- shared: a new widget blueprint with a root, and «a key → our event» overrides
def new_widget(name, root_cls, root_vis):
    # a UserWidget blueprint with the given root panel (the UMG editor settings' default root widget, this session only — kit-krinik-modsettings.py run 3)
    path = "%s/%s" % (PKG, name)
    bp = unreal.load_asset(path) if unreal.EditorAssetLibrary.does_asset_exist(path) else None
    if bp is None:
        ues = unreal.get_default_object(unreal.load_class(None, "/Script/UMGEditor.UMGEditorProjectSettings"))
        prop = None
        for p in ("default_root_widget", "DefaultRootWidget"):   # the two spellings kit-krinik-modsettings.py tries (run 1 here: the first refused)
            try:
                ues.set_editor_property(p, root_cls)
                prop = p
                break
            except Exception as e:
                say("UMGEditorProjectSettings.%s not set: %s" % (p, str(e)[:120]))
        if prop is None:
            raise RuntimeError("no default root widget setting — %s would have no root" % name)
        f = unreal.WidgetBlueprintFactory()
        f.set_editor_property("parent_class", unreal.UserWidget)
        bp = tools.create_asset(name, PKG, unreal.WidgetBlueprint, f)
        try:
            ues.set_editor_property(prop, None)                                 # back to no root for any later asset of this session
        except Exception as e:
            say("%s not reset: %s" % (prop, str(e)[:120]))
        if bp is None:
            raise RuntimeError("%s not created" % name)
        say("%s created (root %s)" % (name, root_cls.__name__))
    t = unreal.find_object(None, "%s.%s:WidgetTree" % (path, name))
    root = None
    for n in ("CanvasPanel_0", "Overlay_0", "CanvasPanel", "Overlay"):
        w = unreal.find_object(None, "%s.%s:WidgetTree.%s" % (path, name, n))
        if w is not None and w.get_parent() is None:
            root = w
    if root is None:
        raise RuntimeError("%s has no root panel" % name)
    root.set_editor_property("visibility", root_vis)
    return bp, path


def key_override(bp, gen, fn_name, entry_pin, getter, key, event, on_hit, part):
    # fn_name(…): when getter(entry_pin) == key → call our custom event, return on_hit (Handled / Unhandled); any other key → Unhandled.
    # Idempotent: a graph that already calls the event is left alone; a graph with nodes of someone else's is never touched.
    g = lib.add_function_override(bp, fn_name)
    if not g:
        raise RuntimeError("%s override refused" % fn_name)
    fed = ged.get_graph_editor_by_name(bp, g.get_name())
    nodes = list(fed.list_all_nodes())
    if any(norm(event) in norm(title(n)) for n in nodes):
        say("%s: %s already calls %s — skipped" % (part, fn_name, event))
        return
    if len(nodes) > 2:
        raise RuntimeError("%s has %d foreign nodes — NOT touched" % (fn_name, len(nodes)))
    entry = [n for n in nodes if cls(n) == "K2Node_FunctionEntry"][0]
    ret = [n for n in nodes if cls(n) == "K2Node_FunctionResult"][0]
    then = out(entry, "then")
    for p in linked(then):
        pins.break_single_pin_link(then, p)
    say("%s: %s — graph %s, %d nodes, adding the key getter" % (part, fn_name, g.get_name(), len(nodes)))
    k = call(fed, getter)
    # OnMouseButtonDoubleClick names its event InMouseEvent (UserWidget.h), the press overrides MouseEvent: the first pin that exists is taken.
    names = entry_pin if isinstance(entry_pin, tuple) else (entry_pin,)
    found = next((n for n in names if lib.find_output_pin(entry, n)), names[0])
    link(out(entry, found), inp(k, "Input"), "%s -> key" % found)
    eq = call(fed, "/Script/Engine.KismetInputLibrary:EqualEqual_KeyKey")
    link(out(k, "ReturnValue"), inp(eq, "A"), "key -> ==")
    literal(inp(eq, "B"), key)
    br = fed.add_branch_node()
    link(then, inp(br, "execute"), "entry -> branch")
    link(out(eq, "ReturnValue"), inp(br, "Condition"), "== %s -> branch" % key)
    c = call(fed, "%s:%s" % (gen, event))
    link(out(br, "then"), inp(c, "execute"), "%s -> %s" % (key, event))
    # ONE return node: both branches return on_hit. The kit's graph API makes no second result node, so a «Handled» here would apply to every key —
    # only the catcher (a press on it is always ours) asks for Handled; key and preview overrides return Unhandled.
    link(out(c, "then"), inp(ret, "execute"), "%s -> return" % event)
    link(out(br, "else"), inp(ret, "execute"), "other key -> return")
    res_node = call(fed, "/Script/UMG.WidgetBlueprintLibrary:" + ("Handled" if on_hit == "Handled" else "Unhandled"))
    link(out(res_node, "ReturnValue"), inp(ret, "ReturnValue"), "%s -> return value" % on_hit)
    for i, n in enumerate((k, eq, br, c, res_node)):
        pos(n, 200 + 220 * i, 0)
    pos(ret, 1500, 0)
    say("%s: %s built (%s → %s, returns %s)" % (part, fn_name, key, event, on_hit))


# ---------------------------------------------------------------- 1. W_KrinikClickWrap
def part_wrap():
    # a wrapper our Lua puts AROUND a runtime-made widget (the mods button, its list): the preview of a left press calls KrinikPreview and returns
    # Unhandled — the press goes on to the children. A Lua-made FLX button stays dead to a real click (spike S11, bug 85 judge D2: run 2026-11-18 20:22,
    # 0 presses of a Lua-made W_KrinikButton on Esc, with the GameInstance and with the window as its owner) — the wrap is a plain UserWidget.
    bp, path = new_widget(WRAP, unreal.Overlay, unreal.SlateVisibility.SELF_HIT_TEST_INVISIBLE)
    gen = "%s.%s_C" % (path, WRAP)
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    custom_event(ed, EV_PREVIEW, 0, 300)
    lib.compile_blueprint(bp)
    key_override(bp, gen, "OnPreviewMouseButtonDown", "MouseEvent", "/Script/Engine.KismetInputLibrary:PointerEvent_GetEffectingButton",
                 "LeftMouseButton", EV_PREVIEW, "Unhandled", WRAP)
    double_click(bp, gen, EV_PREVIEW, "Unhandled", WRAP)
    return save(bp, WRAP)


# The second press of a quick pair at one spot comes from Windows as WM_LBUTTONDBLCLK, and Slate routes it ONLY as OnMouseButtonDoubleClick, bubbling,
# with no preview and no OnMouseButtonDown: the press overrides above never see it, and a checkbox clicked twice fast toggled once (judge 2026-11-18,
# round 2, finding 1; the old key bind saw every press). The same event is called from the double-click override; the return is the press override's.
def double_click(bp, gen, event, on_hit, part):
    key_override(bp, gen, "OnMouseButtonDoubleClick", ("InMouseEvent", "MouseEvent"), "/Script/Engine.KismetInputLibrary:PointerEvent_GetEffectingButton",
                 "LeftMouseButton", event, on_hit, part)


# ---------------------------------------------------------------- 2. W_KrinikClickCatcher
def part_catcher():
    # a transparent canvas under the mods list: a left press on it (= outside the list) calls KrinikMouseDown and is Handled
    bp, path = new_widget(CATCH, unreal.CanvasPanel, unreal.SlateVisibility.VISIBLE)   # an empty Visible canvas takes the press over its area
    gen = "%s.%s_C" % (path, CATCH)
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    custom_event(ed, EV_DOWN, 0, 300)
    lib.compile_blueprint(bp)
    key_override(bp, gen, "OnMouseButtonDown", "MouseEvent", "/Script/Engine.KismetInputLibrary:PointerEvent_GetEffectingButton",
                 "LeftMouseButton", EV_DOWN, "Handled", CATCH)
    double_click(bp, gen, EV_DOWN, "Handled", CATCH)
    return save(bp, CATCH)


# ---------------------------------------------------------------- 3. W_KrinikModSettings
def part_window():
    # a left press anywhere in the window → KrinikMouseDown (Unhandled: the routing by hover stays in Lua); Esc → KrinikEsc (Unhandled — the window
    # swallows Esc itself, recon R2 2026-11-18; Lua closes it on the next game-thread pass; until 2026-11-18 a UE4SS key bind did it — bug 85's class)
    path = "%s/%s" % (PKG, WIN)
    bp = unreal.load_asset(path)
    if bp is None:
        raise RuntimeError("W_KrinikModSettings not found — run kit-krinik-modsettings.py first")
    gen = "%s/%s.%s_C" % (PKG, WIN, WIN)
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    custom_event(ed, EV_DOWN, -2000, 5000)
    custom_event(ed, EV_ESC, -2000, 5400)
    lib.compile_blueprint(bp)
    key_override(bp, gen, "OnPreviewMouseButtonDown", "MouseEvent", "/Script/Engine.KismetInputLibrary:PointerEvent_GetEffectingButton",
                 "LeftMouseButton", EV_DOWN, "Unhandled", WIN)
    key_override(bp, gen, "OnPreviewKeyDown", "InKeyEvent", "/Script/Engine.KismetInputLibrary:GetKey", "Escape", EV_ESC, "Unhandled", WIN)
    double_click(bp, gen, EV_DOWN, "Unhandled", WIN)
    return save(bp, WIN)


# ---------------------------------------------------------------- 4. the two menus
def part_menu(wpath, wname):
    bp = unreal.load_asset(wpath)
    if bp is None:
        raise RuntimeError("%s not found" % wpath)
    if unreal.find_object(None, "%s.%s:WidgetTree.%s" % (wpath, wname, FEEDBACK)) is None:
        raise RuntimeError("%s has no %s — run kit-conanui-edit.py first" % (wname, FEEDBACK))
    keep = {}
    if wname == "W_MainMenu_MainMenu":   # bug 71: the backdrop arrays must survive this save as kit-conanui-edit.py left them
        cdo = unreal.get_default_object(bp.generated_class())
        keep = {k: list(cdo.get_editor_property(k)) for k in ("BackgroundMovies", "BackgroundMovieTextures")}
    ed = ged.get_graph_editor_by_name(bp, "EventGraph")
    ev, made = custom_event(ed, EV_FEEDBACK, -3000, 6000)
    if not made:
        say("%s: %s already there — skipped" % (wname, EV_FEEDBACK))
    else:
        then, target = construct_chain(bp, ed)
        cast, as_btn = cast_to(ed, wname, "Button", widget_by_name(ed, FEEDBACK, -2700, 6400), -2500, 6400)
        link(then, inp(cast, "execute"), "Construct -> cast %s" % FEEDBACK)
        b = bind(ed, wname, ["BindEventtoOnClicked"], "BindEventtoOnClicked", unreal.Button, as_btn, ev, -2200, 6400, "%s.OnClicked" % FEEDBACK,
                 "Кнопка")
        link(out(cast, "then"), inp(b, "execute"), "cast -> bind")
        if target:
            link(out(b, "then"), target, "bind -> the old Construct chain")
            link(out(cast, "CastFailed"), target, "cast failed -> the old Construct chain")
    ok = lib.compile_blueprint(bp)
    say("%s: compile %s" % (wname, ok))
    if not ok:
        raise RuntimeError("%s does not compile — NOT saved" % wname)
    if keep:
        cdo = unreal.get_default_object(bp.generated_class())
        for k, v in keep.items():
            now = list(cdo.get_editor_property(k))
            if [o.get_path_name() if o else None for o in now] != [o.get_path_name() if o else None for o in v]:
                cdo.set_editor_property(k, v)
                say("%s: %s restored after the compile" % (wname, k))
        res["menu_backdrop"] = {k: [o.get_path_name() if o else None for o in cdo.get_editor_property(k)] for k in keep}
    s = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    say("%s: saved %s" % (wname, s))
    return s


# ---------------------------------------------------------------- 5. the cook list
def part_cook():
    done = {}
    for f in (COOK, COOK_COPY):
        if not os.path.exists(f):
            done[f] = "missing"
            continue
        with open(f, "r", encoding="utf-8-sig") as h:
            text = h.read()
        lines = text.splitlines()
        lines = [l for l in lines if l not in COOK_DROP]
        add = [l for l in COOK_LINES if l not in lines]
        if add or len(lines) != len(text.splitlines()):   # write only on a change (judge 2026-11-18, round 2, finding 8)
            at = lines.index("[/CookInfo]") + 1 if "[/CookInfo]" in lines else len(lines)
            lines[at:at] = add
            with open(f, "w", encoding="utf-8", newline="\r\n") as h:
                h.write("\n".join(lines) + "\n")
        done[f] = "added %d" % len(add)
    return done


for name, fn in (("wrap", part_wrap), ("catcher", part_catcher), ("window", part_window),
                 ("menu_main", lambda: part_menu(*MENUS[0])), ("menu_ingame", lambda: part_menu(*MENUS[1])), ("cook", part_cook)):
    try:
        res["parts"][name] = fn()
    except Exception:
        res["parts"][name] = "FAILED"
        res.setdefault("errors", {})[name] = traceback.format_exc()
res["ok"] = all(v not in ("FAILED", False, None) for v in res["parts"].values())
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
