# Кадры макетов JPEG → WebP 90 (исходник удаляется после того, как WebP записан и открыт), плюс лист вариантов sheet.webp:
# две колонки по 960 пикселей с номером варианта — для глаза агента, владельцу идут полные кадры.
# Запуск (его зовёт shoot.mjs): python -X utf8 to_webp_sheet.py <папка> <кадр.jpg>…
# [NOT-TESTED]
import os, sys
from PIL import Image, ImageDraw, ImageFont

out, files = sys.argv[1], sys.argv[2:]
CELL_W, CELL_H, COLS = 960, 540, 2
webps = []
for f in files:
    w = os.path.splitext(f)[0] + '.webp'
    Image.open(f).convert('RGB').save(w, 'WEBP', quality=90)
    Image.open(w).verify()
    os.remove(f)
    webps.append(w)
    print('webp', w, Image.open(w).size)

if webps:
    rows = (len(webps) + COLS - 1) // COLS
    sheet = Image.new('RGB', (CELL_W * COLS, CELL_H * rows), '#111')
    font = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 40)
    for i, w in enumerate(webps):
        im = Image.open(w).convert('RGB').resize((CELL_W, CELL_H), Image.LANCZOS)
        x, y = (i % COLS) * CELL_W, (i // COLS) * CELL_H
        sheet.paste(im, (x, y))
        d = ImageDraw.Draw(sheet)
        label = os.path.basename(w).split('_')[1].split('.')[0].lstrip('0')
        d.rectangle([x, y, x + 70, y + 54], fill='#000')
        d.text((x + 12, y + 4), label, fill='#ff0', font=font)
    sheet.save(os.path.join(out, 'sheet.webp'), 'WEBP', quality=85)
    print('sheet', os.path.join(out, 'sheet.webp'), sheet.size)
