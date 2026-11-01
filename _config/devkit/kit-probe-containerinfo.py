# kit-probe-containerinfo.py — the tree of the corpse strip WBP_ContainerInfo (KUMM plan 36 W6: centre the two-line corpse prompt; the owner 2026-10-30 19:48 «центрируй»). Read-only, the same walk as kit-probe-quickloot.py.
# кнопок меняет набор «Перейти · Q Забрать все» ↔ «F Забрать · Q Забрать все · Esc Отмена»). Только читает. Пишет kit-probe-containerinfo.json:
# каждый виджет дерева — имя, класс, родитель, слот (padding, size, выравнивания), у SizeBox — width/height override и min/max.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<этот файл> -EnablePlugins=PythonScriptPlugin -ModDevKit
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-containerinfo.json")
SLOT_PROPS = ("padding", "size", "horizontal_alignment", "vertical_alignment", "layout_data", "auto_size")
SIZEBOX_PROPS = ("width_override", "height_override", "min_desired_width", "min_desired_height", "max_desired_width", "max_desired_height")


def props(obj, names):
    out = {}
    for n in names:
        try:
            out[n] = str(obj.get_editor_property(n))
        except Exception:
            pass
    return out


res = {"ok": False, "widgets": []}
try:
    bp = unreal.load_asset(WIDGET)
    res["loaded"] = bp.get_path_name()
    prefix = "%s.WBP_ContainerInfo:WidgetTree." % WIDGET
    # WidgetTree.RootWidget is not exposed to Python (first run 2026-10-30 19:1x): iterate every Widget object whose path lies inside this
    # blueprint's WidgetTree, parent by UWidget.GetParent.
    for w in unreal.ObjectIterator(unreal.Widget):
        if not w.get_path_name().startswith(prefix):
            continue
        par = w.get_parent()
        d = {"name": w.get_name(), "class": w.get_class().get_name(), "parent": par.get_name() if par else ""}
        slot = w.get_editor_property("slot")
        if slot is not None:
            d["slot_class"] = slot.get_class().get_name()
            d["slot"] = props(slot, SLOT_PROPS)
        if d["class"] == "SizeBox":
            d["sizebox"] = props(w, SIZEBOX_PROPS)
        res["widgets"].append(d)
    res["ok"] = bool(res["widgets"])
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
