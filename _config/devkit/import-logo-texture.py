# import-logo-texture.py — our logo «KRINIK MOD PACK» as a UI texture of the kit mod KrinikConanUI (KUMM plan 36 W26: the build's logo in the
# game menus — `[OWNER]` «нужно в главном меню наш логотип поставить» · «в меню по ESC наше лого будет слева от оригинального, в главном меню -
# справа» · 2026-10-30 22:39–22:40). Source: the TGA in env KIT_LOGO_TGA (made from _config/branding/krinik-modpack-logo.webp: trimmed to its
# alpha box, 1024 wide). UI settings: UserInterface2D compression, the UI texture group, no mips, never streamed.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit
# Writes import-logo-texture.json next to this file.
# [TESTED: 2026-10-30 · imported, cooked, seen in both menus · KUMM testcases/reports/2026-10-30_conan-menu-logos.md]
import json
import os
import traceback

import unreal

SRC = os.environ.get("KIT_LOGO_TGA", "")
DEST_DIR = os.environ.get("KIT_TEX_DIR", "/Game/Mods/KrinikConanUI")   # /Game/UI/Textures/Logos — the game's own logo, overridden (W26, 2026-10-31)
DEST_NAME = os.environ.get("KIT_TEX_NAME", "T_KrinikModpackLogo")   # also the «Оставить отзыв» textures (plan 36 W37, 2026-10-31)
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "import-logo-texture.json")
res = {"ok": False}
try:
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", SRC)
    task.set_editor_property("destination_path", DEST_DIR)
    task.set_editor_property("destination_name", DEST_NAME)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", True)
    task.set_editor_property("save", False)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    res["imported"] = [str(p) for p in task.get_editor_property("imported_object_paths")]
    tex = unreal.load_asset(DEST_DIR + "/" + DEST_NAME)
    tex.set_editor_property("compression_settings", unreal.TextureCompressionSettings.TC_EDITOR_ICON)
    tex.set_editor_property("lod_group", unreal.TextureGroup.TEXTUREGROUP_UI)
    tex.set_editor_property("mip_gen_settings", unreal.TextureMipGenSettings.TMGS_NO_MIPMAPS)
    tex.set_editor_property("never_stream", True)
    res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(tex, False)
    res["asset"] = tex.get_path_name()
    # /Game/Mods/<active mod>/ lands in UE4/Content/Mods/<mod>/Local/ (run 2026-10-30 22:57) → CookInfo «Mods/KrinikConanUI/Local/T_KrinikModpackLogo.uasset»
    res["size"] = [tex.blueprint_get_size_x(), tex.blueprint_get_size_y()]
    res["ok"] = bool(res["saved"])
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
