# kit-probe-palms.py — how the game's palms are set up for shadows, read from the Dev Kit (read-only). KUMM bug 67 (palm leaf shadows flicker;
# [OWNER] 2026-11-06 19:23 «нужна глубокая разведка кода. устройства игры, устройство UE 5,8»). For every palm FoliageType: the shadow / WPO /
# culling properties; for its mesh: Nanite settings and materials; for every material: parent chain and whether World Position Offset is connected.
# Writes kit-probe-palms.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [NOT-TESTED]
import json
import os
import traceback

import unreal

REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-palms.json")
FT_PROPS = ["mesh", "cast_shadow", "cast_dynamic_shadow", "cast_static_shadow", "cast_contact_shadow", "shadow_cache_invalidation_behavior",
            "world_position_offset_disable_distance", "evaluate_world_position_offset", "cull_distance", "mobility", "use_as_occluder",
            "affect_distance_field_lighting", "lighting_channels", "cast_shadow_as_two_sided", "cast_far_shadow", "visible_in_ray_tracing"]
NANITE_PROPS = ["enabled", "preserve_area", "explicit_tangents", "position_precision", "fallback_target", "keep_percent_triangles",
                "displacement_uv_channel"]


def props(obj, names):
    out = {}
    for n in names:
        try:
            v = obj.get_editor_property(n)
            out[n] = v.get_path_name() if hasattr(v, "get_path_name") else str(v)
        except Exception as e:
            out[n] = "n/a"
    return out


def material_info(mi):
    info = {"path": mi.get_path_name()}
    chain = []
    m = mi
    for _ in range(6):
        try:
            parent = m.get_editor_property("parent")
        except Exception:
            parent = None
        if parent is None:
            break
        chain.append(parent.get_path_name())
        m = parent
    info["parents"] = chain
    base = m
    try:
        node = unreal.MaterialEditingLibrary.get_material_property_input_node(base, unreal.MaterialProperty.MP_WORLD_POSITION_OFFSET)
        info["wpo_connected"] = node is not None
        info["wpo_node"] = node.get_class().get_name() if node else None
    except Exception as e:
        info["wpo_connected"] = "ERR %s" % e
    try:
        info["base_props"] = props(base, ["blend_mode", "two_sided", "shading_model", "always_evaluate_world_position_offset",
                                          "max_world_position_offset_displacement", "dithered_lod_transition"])
    except Exception as e:
        info["base_props"] = "ERR %s" % e
    return info


res = {"ok": False, "foliage_types": {}, "errors": []}
try:
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    assets = reg.get_assets_by_path("/Game/Environment/Foliage/FoliageType", recursive=True)
    for a in assets:
        name = str(a.asset_name)
        if "palm" not in name.lower():
            continue
        ft = a.get_asset()
        entry = {"class": ft.get_class().get_name(), "props": props(ft, FT_PROPS)}
        mesh = None
        try:
            mesh = ft.get_editor_property("mesh")
        except Exception:
            pass
        if mesh:
            m = {"path": mesh.get_path_name()}
            try:
                m["nanite"] = props(mesh.get_editor_property("nanite_settings"), NANITE_PROPS)
            except Exception as e:
                m["nanite"] = "ERR %s" % e
            mats = []
            try:
                for sm in mesh.get_editor_property("static_materials"):
                    mi = sm.get_editor_property("material_interface")
                    if mi:
                        mats.append(material_info(mi))
            except Exception as e:
                mats.append("ERR %s" % e)
            m["materials"] = mats
            entry["mesh"] = m
        res["foliage_types"][name] = entry
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())

with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
unreal.log("kit-probe-palms: wrote %s" % REPORT)
