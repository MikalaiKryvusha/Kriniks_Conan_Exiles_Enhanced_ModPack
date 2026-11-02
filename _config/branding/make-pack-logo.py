# make-pack-logo.py — the «KRINIK MOD PACK» logo TONED to the game's «Conan Exiles Enhanced» logo, for the menu texture T_KrinikModpackLogo.
#
# WHY (2026-11-01 20:46, `[OWNER]` «в главном меню тон логотипок Conan Exiles Enhanced и KRINIK MOD PACK отличаются» · «лого KRINIK MOD PACK белесое какое-то,
# светлее» · «Можно тонокорекцией KRINIK MOD PACK привести его к лого Conan Exiles Enhanced?» · «словно слово KRINIK не такое как CONAN»): the two logos stand
# side by side in the main menu; ours read paler and greyer (frame 20:48: darkest 5 % at 12 against the game's 4). The widgets are equal (tint 1, opacity 1)
# and both textures go through one import (`devkit/import-logo-texture.py`), so the tone lives in the picture itself.
# HOW: histogram matching per RGB channel — the opaque pixels (alpha > 200) of our logo get the value distribution of the opaque pixels of the game's logo
# master (the standard «match colour» of image editors). Alpha stays the owner's. The owner's original `krinik-modpack-logo.webp` is not touched.
#   /c/Python314/python.exe -X utf8 make-pack-logo.py <out_dir> [strength 0..1, default 1]
#     → <out_dir>/krinik-modpack-logo-toned.webp   full size, for the eye
#     → <out_dir>/T_KrinikModpackLogo.tga           the kit texture: trimmed to the alpha box, 1024 wide (as the 2026-10-30 import)
# [TESTED: 2026-11-01 21:02 · in game KRINIK dark fill 6/12/19/30 vs CONAN 5/11/19/31 · KUMM testcases/reports/2026-11-01_conan-logo-tone-minimap.md]
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OURS = os.path.join(HERE, "krinik-modpack-logo.webp")
GAME = os.path.join(HERE, "conan-exiles-enhanced-logo-3x.webp")
OPAQUE = 200          # a pixel counts as the letters' body above this alpha (the soft shadow stays out of the statistics)
TEX_WIDTH = 1024      # the kit texture width of 2026-10-30 (1024×388)
DARK_L = 70           # luminance under which a pixel is the letters' dark fill (≈ 76 % of the body in both logos, measured 2026-11-01)
KEEP_L = 110          # luminance from which the owner's colour is kept whole (gold rims, highlights)


def match_channel(src, ref):
    # The CDF of src mapped onto the quantiles of ref — every value of src gets the ref value of the same rank.
    s_vals, s_idx, s_cnt = np.unique(src, return_inverse=True, return_counts=True)
    r_vals, r_cnt = np.unique(ref, return_counts=True)
    s_q = np.cumsum(s_cnt) / src.size
    r_q = np.cumsum(r_cnt) / ref.size
    return np.interp(s_q, r_q, r_vals)[s_idx]


def main():
    out = sys.argv[1]
    k = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0
    os.makedirs(out, exist_ok=True)
    ours = np.asarray(Image.open(OURS).convert("RGBA")).astype(np.float64)
    game = np.asarray(Image.open(GAME).convert("RGBA")).astype(np.float64)
    # Only the DARK FILL is matched (`[OWNER]` 20:51 «темное внутри CONAN и внутри KRINIK различается»): the letters' body below DARK_L in both logos; the
    # gold rims and highlights keep the owner's colour — the weight falls from 1 at DARK_L to 0 at KEEP_L (a smooth step, no seam in the gradient).
    lum = lambda a: 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
    l_o, l_g = lum(ours), lum(game)
    m_o = (ours[..., 3] > OPAQUE) & (l_o < DARK_L)
    m_g = (game[..., 3] > OPAQUE) & (l_g < DARK_L)
    t = np.clip((l_o - DARK_L) / (KEEP_L - DARK_L), 0, 1)
    w = (1 - t * t * (3 - 2 * t)) * k
    res = ours.copy()
    for c in range(3):
        src = ours[..., c][m_o]
        matched = match_channel(src, game[..., c][m_g])
        # One lookup table per channel, built from the dark body; values above the dark range map to themselves.
        xs = np.concatenate([np.sort(src), [src.max() + 1, 255]])
        ys = np.concatenate([np.sort(matched), [src.max() + 1, 255]])
        lut = np.interp(np.arange(256), xs, ys)
        ch = lut[ours[..., c].astype(np.uint8)]
        res[..., c] = ours[..., c] * (1 - w) + ch * w
    img = Image.fromarray(np.clip(res, 0, 255).round().astype(np.uint8), "RGBA")
    img.save(os.path.join(out, "krinik-modpack-logo-toned.webp"), quality=90)
    box = img.split()[3].getbbox()
    tex = img.crop(box)
    tex = tex.resize((TEX_WIDTH, round(tex.height * TEX_WIDTH / tex.width)), Image.LANCZOS)
    tex.save(os.path.join(out, "T_KrinikModpackLogo.tga"))
    print("toned", OURS, "→", out, "strength", k, "tex", tex.size)


main()
