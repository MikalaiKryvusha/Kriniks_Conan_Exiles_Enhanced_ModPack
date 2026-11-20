# Engine shader patches for the Conan kit (KUMM bug 67)

The kit compiles material shaders from `F:/CEUE5Devkit/Engine/Shaders/`. The Nanite raster of WPO foliage (palm leaves) is a MATERIAL shader, so a kit
mod that re-saves `M_Foliage` ships it compiled from whatever `Nanite/NaniteRasterizer.ush` the kit holds at cook time
(recon `KUMM/researches/conan-shadow-flicker/2026-11-07_global_shader_rebuild_recon.md`).

| File | What |
|---|---|
| `NaniteRasterizer.ush.orig` | the kit's original (sha256 starts `40b1c41c9f90a58dc0de`, copied 2026-11-07 18:4x) |
| `NaniteRasterizer.ush.conservative` | conservative coverage in the VSM pass only (`#if VIRTUAL_TEXTURE_TARGET`): bbox of every touched pixel + edges pushed out by half a pixel, no top-left rule — the owner's decision 2026-11-07 18:31 |

Apply before the cook, restore right after it (other kit mods must build unpatched):

    cp NaniteRasterizer.ush.conservative "/f/CEUE5Devkit/Engine/Shaders/Private/Nanite/NaniteRasterizer.ush"
    # … cook the mod that re-saves M_Foliage (kit-buildmod.py) …
    cp NaniteRasterizer.ush.orig "/f/CEUE5Devkit/Engine/Shaders/Private/Nanite/NaniteRasterizer.ush"
    sha256sum "/f/CEUE5Devkit/Engine/Shaders/Private/Nanite/NaniteRasterizer.ush"   # must start 40b1c41c9f90a58dc0de

[NOT-TESTED] — not compiled yet. Open: the kit's shader DDC may serve the old compile (clear or bump), the palm MIs may hold their own shader maps.
