# kit-probe-tree.py — the widget tree of any widget blueprints found by ASSET NAME (env KIT_WIDGETS="W_MainMenu_MainMenu;W_IngameMenu"), read-only.
# Per widget: name, class, parent, slot (padding, size, alignments, CanvasPanelSlot layout — anchors, offsets, alignment, auto size, z-order), an
# Image's brush as T3D text, a text widget's text. Writes kit-probe-tree.json next to this file. KUMM plan 36 W26 (the build's logo in the main
# menu — right of the game's logo, the Esc menu — left of it; versions under both: `[OWNER]` 2026-10-30 22:39–22:40).
#   set KIT_WIDGETS=…  then  UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

NAMES = [n for n in os.environ.get("KIT_WIDGETS", "").split(";") if n]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-tree.json")
SLOT_PROPS = ("padding", "size", "horizontal_alignment", "vertical_alignment", "layout_data", "auto_size", "z_order")
TEXT_PROPS = ("text",)


def props(obj, names):
    out = {}
    for n in names:
        try:
            out[n] = str(obj.get_editor_property(n))[:300]
        except Exception:
            pass
    return out


res = {"ok": False, "widgets": {}}
try:
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    for name in NAMES:
        found = [a for a in reg.get_assets_by_class(unreal.TopLevelAssetPath("/Script/UMGEditor", "WidgetBlueprint"), True)
                 if str(a.asset_name) == name]
        if not found:
            res["widgets"][name] = "NOT FOUND"
            continue
        path = str(found[0].package_name)
        bp = unreal.load_asset(path)
        prefix = "%s.%s:WidgetTree." % (path, name)
        rows = []
        # WidgetTree.RootWidget is not exposed to Python (2026-10-30 19:1x) — iterate widgets whose path lies in this tree.
        for w in unreal.ObjectIterator(unreal.Widget):
            if not w.get_path_name().startswith(prefix):
                continue
            par = w.get_parent()
            d = {"name": w.get_name(), "class": w.get_class().get_name(), "parent": par.get_name() if par else ""}
            slot = w.get_editor_property("slot")
            if slot is not None:
                d["slot_class"] = slot.get_class().get_name()
                d["slot"] = props(slot, SLOT_PROPS)
            if isinstance(w, unreal.Image):
                try:
                    d["brush"] = w.get_editor_property("brush").export_text()[:500]
                except Exception as e:
                    d["brush"] = "ERR %s" % e
            if isinstance(w, unreal.TextBlock):
                d["text"] = props(w, TEXT_PROPS)
            try:
                d["visibility"] = str(w.get_editor_property("visibility"))
            except Exception:
                pass
            rows.append(d)
        res["widgets"][name] = {"path": path, "tree": rows}
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
