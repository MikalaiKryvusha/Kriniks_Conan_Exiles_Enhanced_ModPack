# kit-probe-plus-button.py — READ-ONLY (nothing saved): the look of the attribute row's «+» (`LevelAttributeButton`, W_Attribute) and its neighbours — every brush of
# the button's style (normal / hovered / pressed / disabled: texture, draw-as, tint, image size, margin) and the content image if any. For the owner's word
# 2026-11-10 13:13 «Можно плюсы ярче сделать?» · «но чтобы сохранить стиль конана» (our page arrow is brighter than the game's «+»).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Writes kit-probe-plus-button.json next to this file.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

TREE = "/Game/UI/Inventory/Attributes/W_Attribute.W_Attribute:WidgetTree"
NAMES = ("LevelAttributeButton", "LevelCorruptionButton", "Btn_KrinikPagePrev")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-plus-button.json")


def brush(b):
    d = {}
    for k in ("resource_object", "draw_as", "tint_color", "image_size", "margin"):
        try:
            v = b.get_editor_property(k)
            d[k] = v.get_path_name() if hasattr(v, "get_path_name") else str(v)
        except Exception as e:
            d[k] = "ERR %s" % str(e)[:80]
    return d


res = {"ok": False, "widgets": {}}
try:
    unreal.load_asset("/Game/UI/Inventory/Attributes/W_Attribute")
    for name in NAMES:
        w = unreal.find_object(None, TREE + "." + name)
        if not w:
            res["widgets"][name] = "not found"
            continue
        st = w.get_editor_property("widget_style")
        r = {f: brush(st.get_editor_property(f)) for f in ("normal", "hovered", "pressed", "disabled")}
        try:
            r["color_and_opacity"] = str(w.get_editor_property("color_and_opacity"))
            r["background_color"] = str(w.get_editor_property("background_color"))
        except Exception as e:
            r["colors"] = "ERR %s" % str(e)[:80]
        c = w.get_content()
        r["content"] = c.get_class().get_name() + " " + c.get_name() if c else None
        if c and isinstance(c, unreal.Image):
            r["content_brush"] = brush(c.get_editor_property("brush"))
            r["content_color"] = str(c.get_editor_property("color_and_opacity"))
        res["widgets"][name] = r
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
