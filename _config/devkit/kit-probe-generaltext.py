# kit-probe-generaltext.py — every readable editor property of W_ActionTutorial.PreText (class GeneralText) and of our T_PromptLine1
# (KUMM plan 36 W6 centred: our TextBlock copy of the font rendered in another face — GeneralText styles itself). Read-only.
# [NOT-TESTED]
import json
import os
import traceback

import unreal

AT = "/Game/UI/HUD/Notifications/W_ActionTutorial"
CI = "/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-generaltext.json")
res = {"ok": False}
try:
    unreal.load_asset(AT)
    unreal.load_asset(CI)
    for key, path in (("pre", "%s.W_ActionTutorial:WidgetTree.PreText" % AT), ("line1", "%s.WBP_ContainerInfo:WidgetTree.T_PromptLine1" % CI)):
        o = unreal.find_object(None, path)
        if o is None:
            res[key] = None
            continue
        props = {"__class__": o.get_class().get_path_name(), "__pyclass__": type(o).__name__}
        for n in dir(o):
            if n.startswith("_"):
                continue
            try:
                v = o.get_editor_property(n)
                props[n] = str(v)[:300]
            except Exception:
                pass
        res[key] = props
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
