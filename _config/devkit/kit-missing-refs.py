# kit-missing-refs.py — the class check of KUMM bug 71: which /Game packages a VANILLA asset references that the mod kit does not have.
# A kit save of a vanilla widget writes every such hard reference as None — the main menu lost its six backdrop movies that way and
# drew a white screen («все белое», the owner 2026-10-31 00:10). Run it on every vanilla asset our kit pak overrides, before the build:
#   1. retoc-5.8 to-legacy --version UE5_7 --no-shaders --filter <AssetName> "<game>/ConanSandbox/Content/Paks" <scratch>
#   2. uaj tojson <scratch>/…/<AssetName>.uasset <scratch>/<AssetName>.json VER_UE5_8
#   3. python -I kit-missing-refs.py <scratch>/<AssetName>.json …
# Exit 0 — nothing missing; 1 — a reference the kit lacks (each printed): give it a placeholder of the same class at the same path,
# outside CookInfo (kit-conanui-edit.py → MENU_MOVIES), or the override loses it.
# [TESTED: 2026-10-31 · seven vanilla widgets of KrinikConanUI: 12 missing in W_MainMenu_MainMenu, 0 in the six others — testcases/reports/2026-10-31_conan-main-menu-white-bg.md]
import json
import os
import sys

KIT_CONTENT = "F:/CEUE5Devkit/UE4/Content"
# a placeholder the active mod holds counts as present: the kit saves `/Game/<path>` of a mod into Mods/<Mod>/Content/<path>
ROOTS = [KIT_CONTENT] + [os.path.join(KIT_CONTENT, "Mods", m, "Content") for m in os.listdir(os.path.join(KIT_CONTENT, "Mods"))
                         if os.path.exists(os.path.join(KIT_CONTENT, "Mods", m, "active.txt"))]


def missing(json_path):
    d = json.load(open(json_path, encoding="utf-8"))
    pk = sorted({str(im["ObjectName"]) for im in d["Imports"]
                 if str(im["ClassName"]) == "Package" and str(im["ObjectName"]).startswith("/Game/")})
    return pk, [p for p in pk if not any(os.path.exists(os.path.join(r, p[len("/Game/"):] + ".uasset")) for r in ROOTS)]


bad = 0
for path in sys.argv[1:]:
    pk, miss = missing(path)
    print("%s: %d /Game packages, missing in the kit %d" % (os.path.basename(path), len(pk), len(miss)))
    for m in miss:
        print("   ", m)
    bad += len(miss)
sys.exit(1 if bad else 0)
