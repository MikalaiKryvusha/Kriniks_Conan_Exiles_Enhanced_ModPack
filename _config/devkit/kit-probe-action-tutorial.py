# kit-probe-action-tutorial.py — разведка строки подсказки действия W_ActionTutorial (KUMM план 36 W6: подсказка над трупом в две строки).
# Только читает, ничего не сохраняет. Пишет kit-probe-action-tutorial.json рядом: дерево виджета, у каждого ребёнка HorizontalBox_0 —
# класс, слот (padding, size, выравнивания), у текстов — justification, шрифт, авто-перенос; у значка — что есть из размеров.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<этот файл> -EnablePlugins=PythonScriptPlugin -ModDevKit
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/HUD/Notifications/W_ActionTutorial"
NAMES = ("HorizontalBox_0", "PreText", "Icon", "PostText")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-action-tutorial.json")


def props(obj, names):
    out = {}
    for n in names:
        try:
            out[n] = str(obj.get_editor_property(n))
        except Exception as e:
            out[n] = "?" + type(e).__name__
    return out


res = {"ok": False, "widgets": {}}
try:
    bp = unreal.load_asset(WIDGET)
    res["loaded"] = bp.get_path_name()
    for name in NAMES:
        w = unreal.find_object(None, "%s.W_ActionTutorial:WidgetTree.%s" % (WIDGET, name))
        if w is None:
            res["widgets"][name] = None
            continue
        d = {"class": w.get_class().get_name()}
        d.update(props(w, ("visibility", "render_transform", "justification", "auto_wrap_text", "wrap_text_at", "font",
                           "min_desired_width", "line_height_percentage")))
        slot = w.get_editor_property("slot")
        if slot is not None:
            d["slot_class"] = slot.get_class().get_name()
            d["slot"] = props(slot, ("padding", "size", "horizontal_alignment", "vertical_alignment"))
        res["widgets"][name] = d
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
