# kit-probe-bow-montage.py — разведка в ките (только чтение): дорожки и уведомления монтажа натяжки лука, функции AnimationLibrary для правки
# уведомлений (KUMM план 36 п. 34: продлить уведомление обзора `BP_FieldOfViewChangeForDuration` до конца монтажа). Отчёт —
# kit-probe-bow-montage.json рядом со скриптом. Запуск — как import-charge-sound.py (UnrealEditor-Cmd -run=PythonScript). [NOT-TESTED]
import json
import os
import traceback

import unreal

MONTAGE = "/Game/Characters/humans/animations/combat/2h_bow/AM_combat_2h_bow_combo_heavy_c0"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-bow-montage.json")
res = {"ok": False}
try:
    lib = unreal.AnimationLibrary
    res["lib_funcs"] = sorted(n for n in dir(lib) if "notify" in n.lower())
    m = unreal.load_asset(MONTAGE)
    res["asset"] = str(m)
    res["length"] = m.get_editor_property("sequence_length") if hasattr(m, "get_editor_property") else None
    res["tracks"] = [str(t) for t in lib.get_animation_notify_track_names(m)]
    evs = []
    for ev in lib.get_animation_notify_events(m):
        item = {}
        for f in ("notify_name", "trigger_time_offset", "notify_state_class", "notify", "duration", "track_index"):
            try:
                v = ev.get_editor_property(f)
                item[f] = str(v)
            except Exception as e:
                item[f] = "n/a: " + type(e).__name__
        try:
            item["time"] = ev.get_time()
        except Exception:
            pass
        evs.append(item)
    res["events"] = evs
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
