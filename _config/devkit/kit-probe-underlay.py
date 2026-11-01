# kit-probe-underlay.py — the dark backing of the corpse strip: WBP_ContainerInfo.Border_Underlay (UBorder) — its brush (draw-as, margin, image
# size, tint, texture) and the Border's own properties; exports the brush texture to TGA so its fade profile can be measured (KUMM plan 36 W6:
# `[OWNER]` «темную подложку нужно расширить, чтобы края строк покрывало» · «нужно пересчитать как у подложки размеры задаются от текста» · 2026-10-30 21:4x).
# Read-only on the asset. Writes kit-probe-underlay.json next to this file; the TGA goes to the path in the env var KIT_PROBE_OUT (a scratchpad).
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit
# [NOT-TESTED]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Widgets/HUD/Interact/WBP_ContainerInfo"
BORDER = "%s.WBP_ContainerInfo:WidgetTree.Border_Underlay" % WIDGET
BRUSH_PROPS = ("draw_as", "image_size", "margin", "tiling", "mirroring", "image_type", "tint_color", "resource_object", "resource_name")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-underlay.json")
OUT_DIR = os.environ.get("KIT_PROBE_OUT", "")


def dump(o):
    props = {"__class__": o.get_class().get_path_name()}
    for n in dir(o):
        if n.startswith("_"):
            continue
        try:
            props[n] = str(o.get_editor_property(n))[:400]
        except Exception:
            pass
    return props


res = {"ok": False}
try:
    unreal.load_asset(WIDGET)
    b = unreal.find_object(None, BORDER)
    res["border"] = dump(b)
    brush = b.get_editor_property("background")
    res["brush"] = {}
    for n in BRUSH_PROPS:
        try:
            res["brush"][n] = str(brush.get_editor_property(n))[:400]
        except Exception as e:
            res["brush"][n] = "ERR %s" % e
    isz = brush.get_editor_property("image_size")
    res["brush"]["image_size_xy"] = [getattr(isz, "x", None), getattr(isz, "y", None)]
    # ImageSize is a DeprecateSlateVector2D whose X/Y Python does not show (run 2, 2026-10-30 22:03); the struct's T3D text carries them.
    try:
        res["brush"]["export_text"] = brush.export_text()
    except Exception as e:
        res["brush"]["export_text"] = "ERR %s" % e
    tex = brush.get_editor_property("resource_object")
    # The resource is a material instance (run 1, 2026-10-30 22:01): its parent and parameter values say how the fade is drawn.
    if isinstance(tex, unreal.MaterialInstance):
        mi = {"parent": str(tex.get_editor_property("parent").get_path_name())}
        for kind, names_fn, get_fn in (
                ("scalar", unreal.MaterialEditingLibrary.get_scalar_parameter_names, unreal.MaterialEditingLibrary.get_material_instance_scalar_parameter_value),
                ("vector", unreal.MaterialEditingLibrary.get_vector_parameter_names, unreal.MaterialEditingLibrary.get_material_instance_vector_parameter_value),
                ("texture", unreal.MaterialEditingLibrary.get_texture_parameter_names, unreal.MaterialEditingLibrary.get_material_instance_texture_parameter_value)):
            vals = {}
            try:
                for pn in names_fn(tex):
                    try:
                        v = get_fn(tex, pn)
                        vals[str(pn)] = v.get_path_name() if hasattr(v, "get_path_name") else str(v)
                    except Exception as e:
                        vals[str(pn)] = "ERR %s" % e
            except Exception as e:
                vals["__err__"] = str(e)
            mi[kind] = vals
        res["material"] = mi
        tex = None
        for p in mi.get("texture", {}).values():
            if isinstance(p, str) and p.startswith("/Game/"):
                tex = unreal.load_asset(p.split(".")[0])
                break
    if tex is not None:
        res["texture"] = {"path": tex.get_path_name(), "class": tex.get_class().get_name()}
        for n in ("blueprint_get_size_x", "blueprint_get_size_y"):
            try:
                res["texture"][n] = getattr(tex, n)()
            except Exception:
                pass
        if OUT_DIR and isinstance(tex, unreal.Texture):
            task = unreal.AssetExportTask()
            task.object = tex
            task.filename = os.path.join(OUT_DIR, "underlay.tga")
            task.automated = True
            task.prompt = False
            task.replace_identical = True
            res["texture"]["exported"] = unreal.Exporter.run_asset_export_task(task)
            res["texture"]["export_path"] = task.filename
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
json.dump(res, open(REPORT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
