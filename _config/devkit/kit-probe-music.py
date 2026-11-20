# kit-probe-music.py — how the game plays its music, read from the Dev Kit (read-only): the native classes whose names carry Music / SoundStage,
# their Python-visible members (BlueprintCallable functions and properties), the UFunctions of those classes found by reflection, and WHO REFERENCES the
# music tables and cues (asset-registry referencers) — the blueprint that drives combat music, death music, the Purge. KUMM plan 46 phase 1
# (KrinikConanMusic: `[OWNER]` 2026-11-06 17:25 «да, я хотел бы мод музыки»). Writes kit-probe-music.json next to this file.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# [TESTED: 2026-11-06 · ran in the Dev Kit 14.45 UTC, kit-probe-music.json read: 15 UFunctions, referencers of 10 assets (BP_AC_AudioController owns CombatMusicTable)]
import json
import os
import traceback

import unreal

REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-probe-music.json")
WORDS = ("music", "soundstage")
REFERENCED = [
    "/Game/Sound/Tables/CombatMusicTable",
    "/Game/Sound/Tables/SoundStageAudioTable",
    "/Game/Systems/Audio/BP_SoundStage",
    "/Game/Sound/Music/Music_death_Cue",
    "/Game/Sound/Music/The_Purge/music_Purge_loop_Cue",
    "/Game/Sound/Music/Remaster/Night_Time",
    "/Game/Sound/Music/Music_Startup",
    "/Game/Sound/Mixes_Classes/Music",
    "/Game/Sound/Mixes_Classes/MusicCombat",
    "/Game/Sound/Mixes_Classes/Music_MuteMusic_BG_and_Combat",
]

res = {"ok": False, "classes": {}, "functions": [], "referencers": {}, "errors": []}
try:
    # 1. Python-exposed classes by name.
    for name in dir(unreal):
        low = name.lower()
        if not any(w in low for w in WORDS):
            continue
        cls = getattr(unreal, name, None)
        try:
            members = sorted(n for n in dir(cls) if not n.startswith("_") and n not in dir(unreal.Object))
        except Exception as e:
            members = ["ERR %s" % e]
        res["classes"][name] = members[:200]

    # 2. Every UFunction whose owner or own name carries the words (reflection, not only BlueprintCallable).
    try:
        for fn in unreal.ObjectIterator(unreal.Function):
            path = fn.get_path_name()
            low = path.lower()
            if any(w in low for w in WORDS) and ("/script/" in low):
                res["functions"].append(path)
        res["functions"].sort()
    except Exception as e:
        res["errors"].append("functions: %s" % e)

    # 3. Who references the music assets.
    reg = unreal.AssetRegistryHelpers.get_asset_registry()
    for pkg in REFERENCED:
        try:
            opts = unreal.AssetRegistryDependencyOptions(include_soft_package_references=True, include_hard_package_references=True,
                                                         include_searchable_names=False, include_soft_management_references=False,
                                                         include_hard_management_references=False)
            refs = reg.get_referencers(pkg, opts) or []
            res["referencers"][pkg] = sorted(str(r) for r in refs)
        except Exception as e:
            res["referencers"][pkg] = ["ERR %s" % e]
    res["ok"] = True
except Exception:
    res["errors"].append(traceback.format_exc())

with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
unreal.log("kit-probe-music: wrote %s" % REPORT)
