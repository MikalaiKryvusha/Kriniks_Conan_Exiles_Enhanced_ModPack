"""
Resources of KrinikConanLauncher, built once and checked in (build-docs.py embeds res/* into the exe with csc -resource:,
the launcher reads them with GetManifestResourceStream):
  res/wallpaper.jpg  — the CLEAN pack wallpaper, without the baked logos: the original from _extras/Wallpapers-source
                       (make-wallpapers.py puts the logos onto these originals). The owner 2026-10-31 17:42: «в лаунчере на фоне
                       наш волпейпер» · 17:51 «В ЛАУНЧЕРЕ чистый волпейпер!» · «БЕЗ ЗАПЕЧЁННЫХ ЛОГОТИПОВ! ЛОГОТИПЫ САМИ СТАВИМ!».
  res/logo-game.png  — the Conan Exiles Enhanced logo (_config/branding/conan-exiles-enhanced-logo-3x.webp), alpha kept.
  res/logo-pack.png  — the Krinik Mod Pack logo (_config/branding/krinik-modpack-logo.webp), alpha kept.
  res/frame_h.png,   — the APPROVED frame (the owner 2026-10-31 18:53 «7. утвержденооооооо»): play variant 7 of mockups/frame_play.py,
  res/frame_v.png      the mix «logo metal + scratches and caverns», 3 logical px; top strip 3840×12 and left strip 12×2160 with alpha
                       (ragged edges, chipped corners). The window draws the bottom and right strips from these, turned 180° and darker.
  res/oswald_600.ttf, res/oswald_500.ttf, res/oswald_400.ttf, res/inter_400.ttf — the fonts of mockup 11 (title, game name, «для»;
                       path line and links). Players have neither Oswald nor Inter, so the exe carries them: static instances of the
                       variable fonts in mockups/fonts (GDI+ cannot pick a weight of a variable font), cut to Latin + Cyrillic, each
                       under its own family name so the launcher can tell them apart. Both fonts are SIL OFL 1.1 (Google Fonts).
Sizes: the 4K original for the background, logos LOGO_H tall and the 4K frame strips — the window at 300 % on a 4K TV only scales
them DOWN (HOUSE_RULES rule 17.3). .NET Framework does not read WebP, hence JPG/PNG. The source folders are read only.
New names follow HOUSE_RULES rule 18 (underscores); logo-*.png keep their old names because mockups.html reads them.
Run: python _config/launcher/make-res.py
[TESTED: 2026-10-31 · run: res/ listed, unchanged wallpaper and logos byte-identical, font families read back by GDI+ PrivateFontCollection]
"""
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from PIL import Image

HERE = Path(__file__).resolve().parent
BRANDING = HERE.parent / "branding"
MOCKUPS = HERE / "mockups"
WALLPAPER = Path("D:/Games/Conan Exiles Mods/mods/_extras/Wallpapers-source/Krinik_Conan_Exiles_3.0.1_Wallpaper_4K_3840x2160.png")
LOGOS = {"logo-game.png": BRANDING / "conan-exiles-enhanced-logo-3x.webp", "logo-pack.png": BRANDING / "krinik-modpack-logo.webp"}
FRAME_VARIANT = 7  # approved 18:53
FRAMES = {"frame_h.png": MOCKUPS / "play" / f"frame_h_{FRAME_VARIANT}.webp", "frame_v.png": MOCKUPS / "play" / f"frame_v_{FRAME_VARIANT}.webp"}
# file: (variable source, axis position, family name the launcher looks for) — weights as in mockup 11 CSS
FONTS = {
    "oswald_600.ttf": ("Oswald[wght].ttf", {"wght": 600}, "Krinik Oswald SemiBold"),   # h1: font 600 25px Oswald
    "oswald_500.ttf": ("Oswald[wght].ttf", {"wght": 500}, "Krinik Oswald Medium"),     # h2: font-weight 500, 17px
    "oswald_400.ttf": ("Oswald[wght].ttf", {"wght": 400}, "Krinik Oswald"),            # «для»: 400 8px
    "inter_400.ttf": ("Inter[opsz,wght].ttf", {"opsz": 14, "wght": 400}, "Krinik Inter"),  # path 12px, links 13px: opsz clamps to 14
}
# Latin, Latin-1, Cyrillic, general punctuation (« » — … №): every letter the launcher can show, nothing more.
UNICODES = [*range(0x20, 0x7F), *range(0xA0, 0x100), *range(0x400, 0x460), *range(0x2010, 0x2028), 0x2116, 0x20AC]
OUT = HERE / "res"
QUALITY = 90
LOGO_H = 480  # px: the launcher draws a logo up to ~130 logical px tall, 390 px at 300 % — the source stays larger


def static_font(src, axes, family, out):
    font = instancer.instantiateVariableFont(TTFont(src), axes)
    opts = subset.Options()
    opts.name_IDs = ["*"]
    opts.layout_features = ["*"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=UNICODES)
    sub.subset(font)
    # One family per weight, style Regular: GDI+ keys a private font by family + style, two «Oswald Regular» would collide.
    # The STAT table of the instance still says «Weight: Medium», and GDI+ appends that to the family name — it goes, with its names.
    if "STAT" in font:
        del font["STAT"]
    name = font["name"]
    for rec in list(name.names):
        if rec.nameID in (16, 17, 21, 22, 25) or rec.nameID >= 256:
            name.removeNames(nameID=rec.nameID)
    ps = family.replace(" ", "")
    for nid, value in ((1, family), (2, "Regular"), (3, ps + "-Regular"), (4, family), (6, ps + "-Regular")):
        name.setName(value, nid, 3, 1, 0x409)
        name.setName(value, nid, 1, 0, 0)
    font["OS/2"].fsSelection = (font["OS/2"].fsSelection & ~0b1100001) | 0b1000000  # REGULAR, not bold, not italic
    font["head"].macStyle = 0
    # Weight class 400 too: with 600 GDI+ names the family «Krinik Oswald SemiBold SemiBold» and the launcher misses it.
    # The weight lives in the outlines of the instance, the class number only labels it.
    font["OS/2"].usWeightClass = 400
    font.save(out)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(WALLPAPER) as im:
        im.convert("RGB").save(OUT / "wallpaper.jpg", "JPEG", quality=QUALITY, optimize=True)
    for name, src in LOGOS.items():
        with Image.open(src) as im:
            im = im.convert("RGBA")
            im = im.crop(im.getchannel("A").getbbox())  # no empty margins: the window places the logo by its visible edge
            if im.height > LOGO_H:
                im = im.resize((round(im.width * LOGO_H / im.height), LOGO_H), Image.LANCZOS)
            im.save(OUT / name, "PNG", optimize=True)
    for name, src in FRAMES.items():
        with Image.open(src) as im:
            im.convert("RGBA").save(OUT / name, "PNG", optimize=True)  # alpha kept: the chipped edges are transparency
    for name, (src, axes, family) in FONTS.items():
        static_font(MOCKUPS / "fonts" / src, axes, family, OUT / name)
    for f in sorted(OUT.iterdir()):
        if f.suffix == ".ttf":
            print(f"{f.name}: {TTFont(f)['name'].getDebugName(1)}, {f.stat().st_size // 1024} KB")
            continue
        with Image.open(f) as im:
            print(f"{f.name}: {im.size} {im.mode}, {f.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
