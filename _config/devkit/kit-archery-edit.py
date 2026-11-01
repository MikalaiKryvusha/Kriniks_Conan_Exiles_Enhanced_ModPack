# kit-archery-edit.py — правка в ките для мода KrinikConanArchery (китовая половина; до 2026-10-28 — отдельный мод KrinikBowFixes) (KUMM план 36 п. 34 и 39b). Запуск в режиме модов кита
# (`-ModDevKit`, активный мод KrinikConanArchery по active.txt): изменённый родной ассет кит сам сохраняет в Mods/KrinikConanArchery/Content/…,
# новый — в Mods/KrinikConanArchery/Local/….
#  1. WAV полного заряда → звук /Game/Mods/KrinikConanArchery/S_ChargeFull.
#  2. Монтаж натяжки AM_combat_2h_bow_combo_heavy_c0: уведомление обзора BP_FieldOfViewChangeForDuration — от 0 до КОНЦА монтажа (родное —
#     6,08 с, кончалось через 0,24 с после начала выстрела, отсюда «камера отъезжает при выстреле»). Любой конец раньше конца монтажа роняет
#     зум при зажатой ПКМ: после выстрела монтаж доигрывает сам, кнопка его не прерывает (кейс N1 2026-10-28, конец 6,346 → отъезд 107° на
#     ≈450 мс). Выход из прицела по отпусканию ПКМ после выстрела — в KrinikConanArchery (родной FieldOfViewChange(0.1, 0)). EaseIn 1,5 / EaseOut 0,1.
#  3. Там же — звук S_ChargeFull в начале петли удержания `sl` (полный заряд, тот же отрезок, где горит золотой блеск).
# Отчёт kit-bowfixes-edit.json рядом. Слова владельца: «если ПКС зажата, то нужно оставаться в прицеле после выстрела» · «звук натяжения не
# сделан». [NOT-TESTED]
import json
import os
import traceback

import unreal

MONTAGE = "/Game/Characters/humans/animations/combat/2h_bow/AM_combat_2h_bow_combo_heavy_c0"
FOV_CLASS = "/Game/Systems/Combat/BP_FieldOfViewChangeForDuration.BP_FieldOfViewChangeForDuration_C"
# Звук — свой синтез 2026-10-28 (`_config/sound-synth.py fastsoft`, №2): высокий тонкий «дзинь» кончика стрелы 3,2 кГц, звон 0,12 с, атака 8 мс,
# мягкая вершина 30 мс, долгий отзвук зала RT60 1,2 с, верхи −3 дБ; громкость — как у варианта 9 «мягкий отзвук, как в зале». Путь выбора владельцем:
# «С можно брать» (запись koiroylers) → «грязный колокольчик, может можно свой синтезировать?» → … → «2 атака 8 мс, вершина мягкая (30 мс)»
SRC_WAV = r"D:\work\ai_sandbox\ConanExiles\_config\sounds\charge_full.wav"
SOUND_DIR, SOUND_NAME = "/Game/Mods/KrinikConanArchery", "S_ChargeFull"
HOLD_LOOP_START = 1.8333334   # участок `sl` (петля удержания) по выгрузке монтажа 3.0.1
# Звук — за 20 мс ДО петли удержания, в конце участка натяжки `pc`, который играет один раз: внутри петли (было +0,02) звук повторялся каждые
# ≈4 с удержания (запись звука 2026-10-28, кейс M4) — `[OWNER]` «повторять звук полного натяжения каждые 4 секунды не нужно» · 2026-10-28
SOUND_AT = HOLD_LOOP_START - 0.02
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-archery-edit.json")

res = {"ok": False, "steps": []}
try:
    lib = unreal.AnimationLibrary
    # 1. звук
    task = unreal.AssetImportTask()
    for k, v in (("filename", SRC_WAV), ("destination_path", SOUND_DIR), ("destination_name", SOUND_NAME), ("automated", True),
                 ("replace_existing", True), ("save", True)):
        task.set_editor_property(k, v)
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    wave = unreal.load_asset(SOUND_DIR + "/" + SOUND_NAME)
    res["steps"].append("sound: " + str(wave))
    # 2. уведомление обзора до конца монтажа
    m = unreal.load_asset(MONTAGE)
    length = m.get_editor_property("sequence_length")
    fov_track = None
    for t in lib.get_animation_notify_track_names(m):
        names = [str(e.get_editor_property("notify_name")) for e in lib.get_animation_notify_events_for_track(m, t)]
        if "BP_FieldOfViewChangeForDuration" in names:
            fov_track = t
    res["fov_track"] = str(fov_track)
    lib.remove_animation_notify_events_by_name(m, "BP_FieldOfViewChangeForDuration")
    fov_cls = unreal.load_class(None, FOV_CLASS)
    inst = lib.add_animation_notify_state_event(m, fov_track, 0.0, length, fov_cls)
    inst.set_editor_property("EaseIn", 1.5)
    inst.set_editor_property("EaseOut", 0.1)
    res["steps"].append("fov notify 0..%.3f on track %s: %s" % (length, fov_track, str(inst)))
    # 3. звук полного заряда — своей дорожкой
    track = "KrinikChargeSound"
    if not lib.is_valid_anim_notify_track_name(m, track):
        lib.add_animation_notify_track(m, track, unreal.LinearColor(1.0, 0.8, 0.2, 1.0))
    lib.remove_animation_notify_events_by_track(m, track)   # повторный запуск не кладёт второй звук поверх первого
    snd = lib.add_animation_notify_event(m, track, SOUND_AT, unreal.AnimNotify_PlaySound)
    snd.set_editor_property("sound", wave)
    # Немое: монтаж общий с NPC, и «дзинь» звучал и у врагов (`[OWNER]` «Можно врагам не дзинкать, а только для героя игрока?» · 2026-10-28).
    # Уведомление держит звук загруженным вместе с монтажом, а играет его KrinikConanArchery только герою игрока (без LoadAsset — баг 05).
    snd.set_editor_property("volume_multiplier", 0.0)
    res["steps"].append("sound notify at %.3f: %s" % (SOUND_AT, str(snd)))
    res["saved_montage"] = unreal.EditorAssetLibrary.save_loaded_asset(m, False)
    res["saved_sound"] = unreal.EditorAssetLibrary.save_loaded_asset(wave, False)
    res["events_after"] = ["%s @%.3f dur %.3f" % (str(e.get_editor_property("notify_name")), lib.get_anim_notify_event_trigger_time(e),
                                                  lib.get_anim_notify_event_duration(e)) for e in lib.get_animation_notify_events(m)]
    res["ok"] = True
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
