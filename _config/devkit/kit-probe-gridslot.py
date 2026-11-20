# kit-probe-gridslot.py — the selection rim of an inventory cell (KUMM, the owner 2026-11-07 10:57: «в окне квиклута … рамка выбора … плавные анимации
# появления, исчезания, переката … убираем анимации, делаем её переключения с предмета на предмет мгновенными»). Read only. Writes kit-probe-gridslot.json:
# every WidgetAnimation of /Game/UI/Framework/InventoryGridSlotView — name, start / end, its bindings (widget names), tracks, channels and keys (time in
# ticks of the 60000/s resolution, value).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Framework/InventoryGridSlotView"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-gridslot.json")
res = {"widget": WIDGET, "anims": []}
try:
    bp = unreal.load_asset(WIDGET)
    res["loaded"] = bp.get_path_name() if bp else None
    for a in unreal.ObjectIterator(unreal.WidgetAnimation):
        p = a.get_path_name()
        if not p.startswith(WIDGET + ".InventoryGridSlotView:"):
            continue
        item = {"path": p, "start": a.get_start_time(), "end": a.get_end_time(), "bindings": []}
        for b in unreal.MovieSceneSequenceExtensions.get_bindings(a):
            bi = {"name": str(b.get_display_name()), "tracks": []}
            for t in b.get_tracks():
                ti = {"track": t.get_class().get_name(), "name": str(t.get_display_name()), "sections": []}
                for sec in t.get_sections():
                    si = {"channels": []}
                    try:
                        si["range"] = [sec.get_start_frame_seconds(), sec.get_end_frame_seconds()]
                    except Exception:
                        pass
                    for ch in sec.get_all_channels():
                        keys = []
                        for k in ch.get_keys():
                            try:
                                fr = k.get_time(unreal.MovieSceneTimeUnit.TICK_RESOLUTION)
                                keys.append([fr.frame_number.value, float(k.get_value()) if not isinstance(k.get_value(), bool) else k.get_value()])
                            except Exception as e:
                                keys.append(str(e))
                        si["channels"].append({"name": ch.get_name(), "keys": keys})
                    ti["sections"].append(si)
                bi["tracks"].append(ti)
            item["bindings"].append(bi)
        res["anims"].append(item)
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
