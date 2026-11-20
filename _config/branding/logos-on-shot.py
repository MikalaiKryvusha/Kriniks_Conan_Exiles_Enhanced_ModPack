# logos-on-shot.py — the two logos + versions (make-wallpapers.py «top-centre») on a game frame, in the free sky between the HUD and the minimap.
#   python -X utf8 logos-on-shot.py <in.jpg> <out base> <logo_h> <digit_h> <dy share> [dx share]   → <out base>.jpg (q93) and .webp
# The owner's accepted values for a 4K frame (KUMM plan 43, 2026-11-02 19:16–19:20: «в центр поставить два лого» · «там, где небо» · «убрать тени из-под
# текстов версий» · «больше логотипы и ниже» · «нет, назад» · «и чуть-чуть выше» · «кадр принят»): logo_h 0.10, digit_h 0.040, dy 0.163, dx 0, no digit halo.
# [TESTED: 2026-11-02 · the release frame hero_oasis_1_logos, looked at · KUMM testcases/reports/2026-11-02_conan-release-0.9.0.md]
import importlib.util, sys
from PIL import Image
spec = importlib.util.spec_from_file_location("mw", r"D:/work/ai_sandbox/ConanExiles/_config/branding/make-wallpapers.py")
mw = importlib.util.module_from_spec(spec); spec.loader.exec_module(mw)
mw.HALO_ALPHA = 0   # the owner 19:17 «убрать тени из-под текстов версий»
src, out, logo_h, digit_h, dy = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
dx = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0   # share of the width, + right
frame = Image.open(src).convert("RGBA")
layer = Image.new("RGBA", frame.size, (0, 0, 0, 0))
import json  # the versions under the logos — the pack's manifest (KUMM plans/55 R1; were the constants 3.0.1 / 0.9.0)
manifest = json.load(open(r"D:/work/ai_sandbox/ConanExiles/modpack.json", encoding="utf-8"))
mw.compose(layer, "top-centre", manifest["launcher"]["gameVersion"], manifest["packVersion"], logo_h, digit_h)
shifted = Image.new("RGBA", frame.size, (0, 0, 0, 0))
shifted.paste(layer, (int(dx * frame.width), int(dy * frame.height)))
res = Image.alpha_composite(frame, shifted).convert("RGB")
res.save(out + ".jpg", "JPEG", quality=93, subsampling=0)
res.save(out + ".webp", "WEBP", quality=90)
print("bbox of logos", shifted.getbbox(), frame.size)
