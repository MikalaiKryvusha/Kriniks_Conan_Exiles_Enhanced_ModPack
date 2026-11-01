# kit-probe-native-class.py — the native (C++) parent chain of widget blueprints and what Python sees on each class: methods, properties, and the
# UFunctions with their flags (BlueprintImplementableEvent / BlueprintNativeEvent / BlueprintCallable). Read-only. KUMM plan 36 W29 (shout subtitles:
# what the game's native SubtitleEntryView / SubtitleRenderer let a blueprint override). Env KIT_ASSETS="/Game/UI/HUD/W_SubtitleEntryView;…".
# Writes kit-probe-native-class.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSETS = [a for a in os.environ.get("KIT_ASSETS", "/Game/UI/HUD/W_SubtitleEntryView;/Game/UI/HUD/W_SubtitleRenderer").split(";") if a]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-native-class.json")
STOP_AT = ("UserWidget", "Widget", "Visual", "Object")

res = {"ok": False, "assets": {}}
try:
    for path in ASSETS:
        bp = unreal.load_asset(path)
        gen = bp.generated_class()
        # A UClass in Python has no get_super_class (2026-10-31 09:08) — the blueprint's own parent_class is the native parent.
        chain = [gen.get_path_name()]
        try:
            chain.append(bp.get_editor_property("parent_class").get_path_name())
        except Exception as e:
            chain.append("ERR %s" % e)
        a_res = {"generated": gen.get_path_name(), "chain": chain}
        # Python classes: unreal.<NativeName> carries methods of the native class; list what is not on UserWidget.
        base = set(dir(unreal.UserWidget))
        natives = {}
        for p in chain:
            short = p.rsplit(".", 1)[-1]
            pyc = getattr(unreal, short, None)
            if pyc is None:
                continue
            natives[short] = sorted(n for n in dir(pyc) if not n.startswith("_") and n not in base)
        a_res["python_members"] = natives
        res["assets"][path] = a_res
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
