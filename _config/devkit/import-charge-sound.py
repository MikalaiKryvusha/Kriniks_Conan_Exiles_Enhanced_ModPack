# import-charge-sound.py — импорт WAV полного заряда лука в звуковой ассет кита (KUMM план 36 п. 39b).
#
# Зачем (2026-10-27, `[OWNER]` «звук натяжения не сделан» · «можно в любой удобный тебе формат сконвертить»): Lua UE4SS не играет файл
# с диска, игре нужен SoundWave в паке. Этот скрипт — шаг 1 из трёх: импорт и сохранение ассета в Mods/KrinikConanArchery кита; шаг 2 —
# кук, шаг 3 — контейнер и обёртка мода (как make-loc-mod.py: repak V11).
#
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<этот файл> -EnablePlugins=PythonScriptPlugin
#
# Пишет только в кит (UE4/Content/Mods/KrinikConanArchery) и отчёт import-charge-sound.json рядом со скриптом. [NOT-TESTED]
import json
import os
import traceback

import unreal

SRC = r"D:\work\ai_sandbox\ConanExiles\_unpacked\KrinikConanArchery\sounds\charge_full.wav"
DEST_DIR = "/Game/Mods/KrinikConanArchery"
DEST_NAME = "S_ChargeFull"
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "import-charge-sound.json")

res = {"ok": False}
try:
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", SRC)
    task.set_editor_property("destination_path", DEST_DIR)
    task.set_editor_property("destination_name", DEST_NAME)
    task.set_editor_property("automated", True)
    task.set_editor_property("replace_existing", True)
    task.set_editor_property("save", True)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    res["imported"] = [str(p) for p in task.get_editor_property("imported_object_paths")]
    wave = unreal.load_asset(DEST_DIR + "/" + DEST_NAME)
    res["asset"] = str(wave)
    if wave:
        res["duration"] = wave.get_editor_property("duration")
        res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
