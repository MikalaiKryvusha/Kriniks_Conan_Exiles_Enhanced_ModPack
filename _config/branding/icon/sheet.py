# Icon comparison sheet: the Conan C and our K variants at the sizes Windows shows an icon (256, 64, 32), on a dark and a light desktop.
import sys
from PIL import Image, ImageDraw, ImageFont

d = sys.argv[1]
items = [("Conan Exiles (original)", "conan_icon_256.webp"), ("K, variant 1", "k_gpt_1.webp"), ("K, variant 2", "k_gpt_2.webp")]
sizes = [256, 64, 32]
cell_w, pad = 300, 30
H = 2 * (256 + 64 + 32 + 4 * pad) + 60
W = cell_w * len(items) + pad
sheet = Image.new("RGB", (W, H), (30, 30, 30))
dr = ImageDraw.Draw(sheet)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 20)
for col, (label, f) in enumerate(items):
    src = Image.open(f"{d}/{f}").convert("RGBA")
    x = pad + col * cell_w
    dr.text((x, 10), label, fill=(230, 230, 230), font=font)
    for half, bg in enumerate([(30, 30, 30), (225, 225, 225)]):
        y = 50 + half * (H - 50) // 2
        dr.rectangle([x - 10, y - 5, x + cell_w - 30, y + (H - 50) // 2 - 15], fill=bg)
        for s in sizes:
            im = src.resize((s, s), Image.LANCZOS)
            sheet.paste(im, (x, y), im)
            y += s + pad
sheet.save(sys.argv[2], "WEBP", quality=92)
print(sheet.size)
