# make-weight-icon.py <vanilla T_BuffIconEncumberance_T1.tga> <out.tga> [<preview.webp>] — the HUD weight icon in the style of Hosav's food and water icons.
# KUMM, the owner's word 2026-11-03 20:14: «под иконкой перегруза тень слишком сильная, не такая, как под жаждой и голодом - там или легче или нет» ·
# «Сделать однотипно легко всем иконкам худа». Hosav draws food and water with his own 128 px textures (a flat light body, a thin dark outline); the
# weight is the GAME's buff icon, 64 px, a white body with a soft black shadow ≈ 14 px wide (alpha up to 145 at the body edge), and Hosav stacks it twice
# (`Image_Weight` + `Image_Weight_Blinking`), so the shadow doubles while the weight blinks.
# Steps: the body = the white pixels (luminance > 128) weighted by alpha → upscaled ×4 (bicubic) → the edge sharpened by a smoothstep → a thin dark
# outline (a dilation of OUTLINE_PX) under it → 256 × 256 RGBA, white body (the HUD tints it), no shadow.
# Run without -I: Pillow lives in the user site-packages. [NOT-TESTED]
import sys
from PIL import Image, ImageFilter, ImageChops

SCALE = 4                 # 64 → 256: crisp at 4K (HOUSE_RULES rule 17.3)
OUTLINE_PX = 5            # at 256: ≈ 1 screen px at 4K, like the stomach's outline (7 filled the ring's hole, preview 22:2x)
OUTLINE_RGB = (38, 28, 24)
OUTLINE_ALPHA = 235

src = Image.open(sys.argv[1]).convert('RGBA')
w, h = src.size
body = Image.new('L', (w, h), 0)
sp, bp = src.load(), body.load()
for y in range(h):
    for x in range(w):
        r, g, b, a = sp[x, y]
        lum = (r + g + b) / 3
        bp[x, y] = int(a * min(1.0, max(0.0, (lum - 40) / 180)))   # white body only; the black shadow (lum 0) drops out
big = body.resize((w * SCALE, h * SCALE), Image.BICUBIC)
# sharpen the upscaled edge: smoothstep over 35…220
big = big.point(lambda v: 0 if v < 35 else 255 if v > 220 else int(255 * ((v - 35) / 185) ** 2 * (3 - 2 * ((v - 35) / 185))))
ring = big.filter(ImageFilter.MaxFilter(OUTLINE_PX * 2 + 1)).filter(ImageFilter.GaussianBlur(1.0))
out = Image.new('RGBA', big.size, OUTLINE_RGB + (0,))
out.putalpha(ring.point(lambda v: v * OUTLINE_ALPHA // 255))
white = Image.new('RGBA', big.size, (255, 255, 255, 0))
white.putalpha(big)
out.alpha_composite(white)
out.save(sys.argv[2])
if len(sys.argv) > 3:
    bg = Image.new('RGBA', (big.size[0] * 2 + 40, big.size[1] + 20), (196, 150, 98, 255))
    van = src.resize(big.size, Image.BICUBIC)
    bg.alpha_composite(van, (10, 10))
    bg.alpha_composite(out, (big.size[0] + 30, 10))
    bg.convert('RGB').save(sys.argv[3], quality=90)
print('written', sys.argv[2], out.size)
