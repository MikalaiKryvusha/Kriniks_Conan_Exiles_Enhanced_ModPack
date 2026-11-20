# make_icons.py — the build's two icons (KUMM idea 22): the letter K in the metal of the Conan Exiles C, as Windows .ico files.
# The owner's word 2026-10-31 19:58 «иконка сборки - такая же, как буква К, как у конана С»; 20:43 «иконки поставляем обе, первая по дефолту» —
# variant 1 (upright K) goes on the launcher exe (build-docs.py → csc -win32icon), both .ico files ship in the archive (manifest extras).
# The pictures are ChatGPT's redraws of the game's own icon (prompts ask_variant_*.txt); their tiles have square corners, the game's icon has rounded
# transparent ones — the corners are cut by the ORIGINAL's alpha, scaled to each size (one shape for both icons).
#   python -I -X utf8 _config/branding/make_icons.py      (from the pack root; reads and writes art/icons — the pictures moved there 2026-11-18,
#   interview #040 Q2 A: one art folder at the pack root; the scripts stay in _config)
# [TESTED: 2026-10-31 · both .ico read back with sizes 16/32/48/64/256; the launcher exe built with -win32icon shows icon 1 with rounded corners when
#  extracted by PrivateExtractIcons (256 and 48)]
import sys
from pathlib import Path

from PIL import Image

ICONS = Path(__file__).resolve().parent.parent.parent / "art" / "icons"
SIZES = [256, 64, 48, 32, 16]          # Explorer, the taskbar at 300 %, the classic list sizes
ORIGINAL = ICONS / "conan_original_256.webp"


def icon(src: Path, out: Path) -> None:
    alpha = Image.open(ORIGINAL).convert("RGBA").getchannel("A")
    pic = Image.open(src).convert("RGBA").resize((256, 256), Image.LANCZOS)
    pic.putalpha(alpha)
    pic.save(out, format="ICO", sizes=[(s, s) for s in SIZES])
    back = Image.open(out)
    print(f"{out.name}: {sorted(back.info.get('sizes', []))} · {out.stat().st_size // 1024} KB")


def main() -> int:
    for n in (1, 2):
        icon(ICONS / f"k_variant_{n}.webp", ICONS / f"krinik_build_icon_{n}.ico")
    return 0


if __name__ == "__main__":
    sys.exit(main())
