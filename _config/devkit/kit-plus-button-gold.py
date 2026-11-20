# kit-plus-button-gold.py — the attribute row's «+» (`LevelAttributeButton` of W_Attribute) in Conan's own gold (KUMM plan 49, the owner's G1:
# `[OWNER]` 2026-11-10 13:41 «05 золото конана» · «и наши кнопочки влево вправо к нему приведи» — verbatim in plan 49).
# The game draws the «+» with its OLIVE texture darkened by a GREY tint (normal T_Attributes_perk_button_default × 0.495, hovered / pressed
# T_Attributes_perk_button_hover × 0.724 / 0.384 — kit-probe-plus-button.json); a higher grey tint turns the olive into a cold cream (the owner's 13:18
# «неужели ты не видишь, как ты не соблюдаешь цветовую схему???»). So each state gets a WARM per-channel tint that brings the rim, measured on a 4K frame at
# the game's 0.495 as sRGB (139, 142, 127), onto a colour of the game's own interactive-gold ladder (Funcom's FS_ scrollbar thumb, KUMM
# researches/conan-ui-color-scheme/): normal #E9C27A, hovered #ECD97C, pressed #5E4A1F. tint_c = 0.495 × lin(target_c) / lin(rim_c) — the formula of
# _config/mockups/plus_brightness_mockup.py (G1 = (1.56, 0.99, 0.46), G2 = (1.61, 1.27, 0.47)).
# **Since 2026-11-14 00:5x the normal and hovered gains live IN OUR TEXTURES, drawn at tint 1.0:** on screen a brush tint is CLAMPED at 1.0 per channel (live:
# R 1.5623 and 1.0 gave the same pixels, 0.3 changed them), so a tint above 1 over the game's olive texture could never reach #E9C27A.
# `_config/branding/make_plus_gold.py` bakes the same gains into T_KrinikPlusGold / T_KrinikPlusGoldHover (imported by import-logo-texture.py into
# /Game/Mods/KrinikConanUI, cooked by CookInfo); pressed keeps the game's hover texture with its tint (every channel < 1 — no clamp).
# Our page arrows already wear the same gold (make-page-arrows.py → import-logo-texture.py). LevelCorruptionButton (the purple «+») is left as it is.
#   UnrealEditor-Cmd.exe F:\CEUE5Devkit\UE4\ConanSandbox.uproject -run=PythonScript -Script=<this file> -EnablePlugins=PythonScriptPlugin -ModDevKit -NullRHI
# Idempotent (sets values). Writes kit-plus-button-gold.json next to this file; saves W_Attribute only when the blueprint compiles.
# [TESTED: 2026-11-14 · cases K5, K6 in the 3.1.0 game: rim (206, 175, 107) vs the owner's mockup 05 (209, 178, 118); hover (229, 206, 104) · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
import json
import os
import traceback

import unreal

WIDGET = "/Game/UI/Inventory/Attributes/W_Attribute"
TREE = WIDGET + ".W_Attribute:WidgetTree"
BUTTON = "LevelAttributeButton"
GAME_TINT = 0.495                       # the game's normal-state grey tint (linear), at which the rim was measured
RIM_SRGB = (139, 142, 127)              # the «+» rim on a 4K frame at GAME_TINT (plan 49, 2026-11-10 13:18)
TARGETS = {"normal": (0xE9, 0xC2, 0x7A),    # G1 — the owner's pick
           "hovered": (0xEC, 0xD9, 0x7C),   # G2 — the game's lighter gold, the same pair our arrows wear
           "pressed": (0x5E, 0x4A, 0x1F)}   # [AI] the game's dark old gold of a dragged thumb (plan 49: «pressed darker (#5E4A1F role)»)
OURS = {"normal": "/Game/Mods/KrinikConanUI/T_KrinikPlusGold",           # states drawn by our baked texture at tint 1.0
        "hovered": "/Game/Mods/KrinikConanUI/T_KrinikPlusGoldHover"}
GAME_HOVER_TEX = "/Game/UI/Textures/GUIs/Inventory/T_Attributes_perk_button_hover"   # pressed: the game's own texture, set explicitly (judge 2026-11-14 round 2, Q3)
MOD = "KrinikConanUI"
KIT_MODS = r"F:\CEUE5Devkit\UE4\Content\Mods"   # the kit saves an edited game asset into the ACTIVE mod's override (judge round 2, D1)
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "kit-plus-button-gold.json")


def to_lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def warm_tint(target):
    return tuple(round(GAME_TINT * to_lin(t) / to_lin(r), 4) for t, r in zip(target, RIM_SRGB))


res = {"ok": False, "gains": {k: warm_tint(v) for k, v in TARGETS.items()}}   # normal / hovered gains are baked into OURS; the brush tint there is 1.0
try:
    # the WHOLE switch, not a substring of a log path or a script path (judge round 4, 2); without mod mode the save would hit the kit's vanilla asset (round 3, 1)
    if "-moddevkit" not in [tok.strip('"').lower() for tok in unreal.SystemLibrary.get_command_line().split()]:
        raise RuntimeError("run with -ModDevKit: the edit must be saved into the active mod's override, not the kit's own W_Attribute")
    active = sorted(m for m in os.listdir(KIT_MODS) if os.path.exists(os.path.join(KIT_MODS, m, "active.txt")))
    if active != [MOD]:
        raise RuntimeError("the active kit mod must be %s alone (active.txt), found %s — the edit would land in another mod's override" % (MOD, active))
    bp = unreal.load_asset(WIDGET)
    b = unreal.find_object(None, TREE + "." + BUTTON)
    if not b:
        raise RuntimeError(BUTTON + " not found in " + TREE)
    st = b.get_editor_property("widget_style")
    res["before"] = {}
    for field, (r, g, bl) in res["gains"].items():
        br = st.get_editor_property(field)
        res["before"][field] = str(br.get_editor_property("tint_color").get_editor_property("specified_color"))
        if field in OURS:                       # the gain is in the texture; a tint above 1 would be clamped on screen anyway
            tex = unreal.load_asset(OURS[field])
            if tex is None:
                raise RuntimeError(OURS[field] + " not found — import it first (import-logo-texture.py KIT_TGA_DIR)")
            br.set_editor_property("resource_object", tex)
            r = g = bl = 1.0
        else:
            br.set_editor_property("resource_object", unreal.load_asset(GAME_HOVER_TEX))
        br.set_editor_property("tint_color", unreal.SlateColor(unreal.LinearColor(r, g, bl, 1.0)))
        st.set_editor_property(field, br)       # the brush is a struct copy — written back into the style, the style into the button
    b.set_editor_property("widget_style", st)
    st2 = b.get_editor_property("widget_style")
    res["after"] = {f: str(st2.get_editor_property(f).get_editor_property("tint_color").get_editor_property("specified_color")) for f in TARGETS}
    res["textures"] = {f: st2.get_editor_property(f).get_editor_property("resource_object").get_path_name() for f in TARGETS}
    compiled = unreal.BlueprintEditorLibrary.compile_blueprint(bp)
    res["compiled"] = compiled
    if not compiled:
        raise RuntimeError("the blueprint does not compile — NOT saved")
    res["saved"] = unreal.EditorAssetLibrary.save_loaded_asset(bp, False)
    res["ok"] = bool(res["saved"])
except Exception:
    res["error"] = traceback.format_exc()
with open(REPORT, "w", encoding="utf-8") as f:
    json.dump(res, f, ensure_ascii=False, indent=1)
