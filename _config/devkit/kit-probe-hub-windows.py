# kit-probe-hub-windows.py — the nine hub tab windows: their native parent classes and every class-default property (KUMM bug 64 items 15/17:
# two pages drawn over each other for 30–130 ms on a tab switch, clips of review folder 69). Only reads. Writes kit-probe-hub-windows.json.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WINDOWS = {
    "CharacterInventory": "/Game/UI/Inventory/CraftingGUI.CraftingGUI_C",
    "FeatWindow": "/Game/UI/Inventory/W_FeatWindow.W_FeatWindow_C",
    "Attributes": "/Game/UI/Inventory/Attributes/W_Attributes.W_Attributes_C",
    "CharacterStatsWindow": "/Game/UI/Widgets/CharacterStats/W_CharacterStatsWindow.W_CharacterStatsWindow_C",
    "ExilesJourney": "/Game/UI/Widgets/Journey/W_NewJourneyWindow.W_NewJourneyWindow_C",
    "Guild": "/Game/UI/Widgets/Guild/W_GuildView.W_GuildView_C",
    "Followers": "/Game/UI/Widgets/Guild/Followers/W_FollowersView.W_FollowersView_C",
    "FullscreenMap": "/Game/UI/Widgets/Map/W_FullscreenMap.W_FullscreenMap_C",
    "Stores": "/Game/DLC/Special/Store/UI/Windows/W_StoreWindow.W_StoreWindow_C",
}
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-hub-windows.json")


def chain(cls):
    out = []
    c = cls
    while c is not None and len(out) < 12:
        out.append(c.get_path_name())
        try:
            c = c.get_super_class()
        except Exception:
            break
    return out


def props(obj):
    out = {}
    for n in dir(obj):
        if n.startswith("_"):
            continue
        try:
            v = obj.get_editor_property(n)
        except Exception:
            continue
        if callable(v):
            continue
        out[n] = str(v)[:200]
    return out


res = {"ok": False, "windows": {}}
try:
    for key, path in WINDOWS.items():
        d = {}
        try:
            unreal.load_asset(path.split(".")[0])
            cls = unreal.load_object(None, path)
            d["chain"] = chain(cls)
            d["cdo"] = props(unreal.get_default_object(cls))
            bp_path = path.split(".")[0]
            d["anims"] = [a.get_name() for a in unreal.ObjectIterator(unreal.WidgetAnimation) if a.get_path_name().startswith(bp_path + ".")]
        except Exception:
            d["error"] = traceback.format_exc()[-600:]
        res["windows"][key] = d
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
