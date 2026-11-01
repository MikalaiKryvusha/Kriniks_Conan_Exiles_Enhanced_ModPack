# kit-probe-subtitle.py — read-only probe of the game's subtitle widgets W_SubtitleEntryView and W_SubtitleRenderer (KUMM plan 36 W29: enemy
# shouts are subtitles; the line is drawn one frame ≈ 50 px low, then jumps into place; `[OWNER]` «должна сразу на месте появляться,можно с фейдом
# небольшим, типа 200мс, и такой же фейд на скрытие» · «без всяких перемещений по экрану» · 2026-10-31 08:56).
# Per widget: the tree (class, parent, slot fields, visibility, render opacity), the widget animations (name, end time, bindings), the blueprint's
# function graphs and their node titles, the class defaults that look like timings. Writes kit-probe-subtitle.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

ASSETS = ("/Game/UI/HUD/W_SubtitleEntryView", "/Game/UI/HUD/W_SubtitleRenderer")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-subtitle.json")
SLOT_PROPS = ("padding", "size", "horizontal_alignment", "vertical_alignment", "layout_data", "auto_size", "z_order")
WIDGET_PROPS = ("visibility", "render_opacity", "render_transform", "render_transform_pivot")


def props(obj, names):
    out = {}
    for n in names:
        try:
            out[n] = str(obj.get_editor_property(n))[:400]
        except Exception:
            pass
    return out


res = {"ok": False, "widgets": {}}
try:
    for path in ASSETS:
        name = path.rsplit("/", 1)[1]
        bp = unreal.load_asset(path)
        w_res = {"class": bp.get_class().get_name()}
        prefix = "%s.%s:WidgetTree." % (path, name)
        rows = []
        for w in unreal.ObjectIterator(unreal.Widget):
            if not w.get_path_name().startswith(prefix):
                continue
            par = w.get_parent()
            d = {"name": w.get_name(), "class": w.get_class().get_name(), "parent": par.get_name() if par else ""}
            d.update(props(w, WIDGET_PROPS))
            slot = w.get_editor_property("slot")
            if slot is not None:
                d["slot_class"] = slot.get_class().get_name()
                d["slot"] = props(slot, SLOT_PROPS)
            rows.append(d)
        w_res["tree"] = rows
        anims = []
        try:
            for a in bp.get_editor_property("animations"):
                ad = {"name": a.get_name()}
                for n in ("display_label",):
                    try:
                        ad[n] = str(a.get_editor_property(n))
                    except Exception:
                        pass
                try:
                    ad["end_time"] = a.get_end_time()
                except Exception as e:
                    ad["end_time"] = "ERR %s" % e
                try:
                    ad["bindings"] = [str(b.get_editor_property("widget_name")) for b in a.get_editor_property("animation_bindings")]
                except Exception as e:
                    ad["bindings"] = "ERR %s" % e
                try:
                    ms = a.get_movie_scene()
                    ad["tracks"] = []
                    for b in ms.get_bindings():
                        for t in b.get_tracks():
                            secs = []
                            for s in t.get_sections():
                                try:
                                    secs.append([s.get_start_frame(), s.get_end_frame()])
                                except Exception:
                                    pass
                            ad["tracks"].append({"binding": str(b.get_display_name()), "track": t.get_class().get_name(),
                                                 "name": str(t.get_display_name()), "sections": secs})
                    ad["display_rate"] = str(ms.get_display_rate())
                    ad["tick_resolution"] = str(ms.get_tick_resolution())
                except Exception as e:
                    ad["tracks"] = "ERR %s" % e
                anims.append(ad)
        except Exception as e:
            anims = "ERR %s" % e
        w_res["animations"] = anims
        graphs = {}
        try:
            for g in unreal.BlueprintEditorLibrary.get_graphs(bp) if hasattr(unreal, "BlueprintEditorLibrary") and hasattr(unreal.BlueprintEditorLibrary, "get_graphs") else []:
                graphs[g.get_name()] = []
        except Exception as e:
            graphs["ERR"] = str(e)
        w_res["graphs"] = graphs
        cdo = None
        try:
            gen = bp.generated_class()
            cdo = unreal.get_default_object(gen)
        except Exception as e:
            w_res["cdo"] = "ERR %s" % e
        if cdo is not None:
            cd = {}
            for n in dir(cdo):
                if n.startswith("_"):
                    continue
                try:
                    v = cdo.get_editor_property(n)
                except Exception:
                    continue
                s = str(v)
                if len(s) < 200:
                    cd[n] = s
            w_res["cdo"] = cd
        res["widgets"][name] = w_res
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
