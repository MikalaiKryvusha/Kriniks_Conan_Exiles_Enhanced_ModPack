# kit-probe-carousel.py — what the hub carousel does on a tab switch (KUMM bug 64 items 15/17: the owner 2026-11-06 21:00 «Страницы должны
# переключаться четко и мгновенно» · «эффект темной волны … нахуй не нужен»). Только читает. Пишет kit-probe-carousel.json:
#   - дерево W_Carousel (имя, класс, родитель), его анимации (имя, длина, дорожки, ключи) и картинка Background;
#   - свойства умолчаний класса W_Carousel_C (что отдаёт get_editor_property);
#   - строки DT_UIModuleTable для девяти вкладок хаба и анимации каждого окна вкладки (появление / исчезновение страниц);
#   - кто ссылается на материал M_UI_BlossomTransitionBackground.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<этот файл> -EnablePlugins=PythonScriptPlugin -ModDevKit
# [TESTED: 2026-11-06 · первый прогон 21:0x прочитал дерево, длину анимации 0.5 с и умолчания; дорожки — второй прогон]
import json
import os
import re
import traceback

import unreal

WIDGET = "/Game/UI/HUD/Carousel/W_Carousel"
SUSPECT = "/Game/UI/Materials/General/M_UI_BlossomTransitionBackground"
TABS = ["CharacterInventory", "FeatWindow", "Attributes", "CharacterStatsWindow", "ExilesJourney", "Guild", "Followers", "FullscreenMap", "Stores"]
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-carousel.json")
GAME_PATH = re.compile(r"(/Game/[A-Za-z0-9_/]+)[.][A-Za-z0-9_]+")


def dump_props(obj):
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
        out[n] = str(v)[:300]
    return out


def anim_info(anim):
    d = {"name": anim.get_name()}
    try:
        d["start"] = anim.get_start_time()
        d["end"] = anim.get_end_time()
    except Exception as e:
        d["time_error"] = str(e)
    tracks = []
    try:
        # UE5 Python: the movie scene is not a property (first run 2026-11-06 21:0x); the sequence extension library walks it.
        for b in unreal.MovieSceneSequenceExtensions.get_bindings(anim):
            for t in b.get_tracks():
                tr = {"binding": str(b.get_display_name()), "track": t.get_class().get_name()}
                try:
                    tr["property"] = str(t.get_property_path())
                except Exception:
                    pass
                secs = []
                for sec in t.get_sections():
                    sd = {}
                    try:
                        chans = []
                        for ch in sec.get_all_channels():
                            keys = ch.get_keys()
                            chans.append({"name": str(ch.get_name()),
                                          "keys": [(k.get_time().frame_number.value, str(k.get_value())[:60]) for k in keys][:8]})
                        sd["channels"] = chans
                    except Exception as e:
                        sd["channels_error"] = str(e)[:200]
                    secs.append(sd)
                tr["sections"] = secs
                tracks.append(tr)
        try:
            d["tick_resolution"] = str(unreal.MovieSceneSequenceExtensions.get_tick_resolution(anim))
        except Exception:
            pass
    except Exception as e:
        d["tracks_error"] = str(e)
    d["tracks"] = tracks
    return d


def widget_anims(path):
    """All WidgetAnimations of the widget blueprint at <path> (loaded first); the _INST copies of the generated class are skipped."""
    try:
        unreal.load_asset(path)
    except Exception as e:
        return [{"error": str(e)[:200]}]
    return [anim_info(a) for a in unreal.ObjectIterator(unreal.WidgetAnimation)
            if a.get_path_name().startswith(path + ".") and "_INST" not in a.get_name()]


res = {"ok": False}
try:
    bp = unreal.load_asset(WIDGET)
    res["loaded"] = bp.get_path_name()
    prefix = "%s.W_Carousel:WidgetTree." % WIDGET
    res["widgets"] = []
    for w in unreal.ObjectIterator(unreal.Widget):
        if not w.get_path_name().startswith(prefix):
            continue
        par = w.get_parent()
        res["widgets"].append({"name": w.get_name(), "class": w.get_class().get_name(), "parent": par.get_name() if par else ""})
    res["animations"] = widget_anims(WIDGET)
    gen = unreal.load_object(None, WIDGET + ".W_Carousel_C")
    if gen:
        res["cdo"] = dump_props(unreal.get_default_object(gen))
    bg = unreal.load_object(None, prefix + "Background")
    if bg:
        res["background"] = {"brush": str(bg.get_editor_property("brush"))[:600], "render_opacity": bg.get_editor_property("render_opacity"),
                             "visibility": str(bg.get_editor_property("visibility")), "color": str(bg.get_editor_property("color_and_opacity"))}
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    opts = unreal.AssetRegistryDependencyOptions(True, True, True, True, True)
    res["suspect_referencers"] = [str(p) for p in reg.get_referencers(SUSPECT, opts) or []]
    dt = unreal.load_asset("/Game/UI/Data/DataTables/DT_UIModuleTable")
    csv = unreal.DataTableFunctionLibrary.export_data_table_to_csv_string(dt) if dt else ""
    lines = csv.splitlines()
    res["module_header"] = lines[0][:800] if lines else ""
    res["modules"] = {}
    for ln in lines[1:]:
        key = ln.split(",", 1)[0].strip('"')
        if key in TABS:
            entry = {"row": ln[:1200], "anims": {}}
            for m in GAME_PATH.findall(ln):
                if m.startswith("/Game/UI") and m not in entry["anims"]:
                    entry["anims"][m] = widget_anims(m)
            res["modules"][key] = entry
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
