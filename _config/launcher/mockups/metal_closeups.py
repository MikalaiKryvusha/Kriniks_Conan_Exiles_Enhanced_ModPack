# Лист металлов каймы: только сами полосы, восемь горизонтальных, одна под другой, с номером и названием (18:40 «только линии металла открой
# на листе, 8 горизонтальных»). Полоса — начало metals/frame_h_N.webp (с углом), увеличенное в ZOOM раз, на тёмном фоне.
# Запуск: python -X utf8 metal_closeups.py <папка вывода>   → <папка>/metals_lines.webp (3840 в ширину)
# [NOT-TESTED]
import os, sys
from PIL import Image, ImageDraw, ImageFont

here = os.path.dirname(os.path.abspath(__file__))
folder = sys.argv[1]
NAMES = {1: 'медь-золото', 2: 'тёмная бронза с патиной', 3: 'чёрное железо', 4: 'ржавое железо',
         5: 'старое золото', 6: 'красная медь', 7: 'кованая сталь', 8: 'закопчённая латунь, светлые края'}
W, ZOOM = 3840, 3              # ширина листа; полоса — первые W/ZOOM пикселей, увеличенные в ZOOM раз
LABEL_H, GAP = 70, 50
font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 46)
strips = [Image.open(os.path.join(here, 'metals', f'frame_h_{n}.webp')).convert('RGBA') for n in NAMES]
sh = strips[0].height * ZOOM
sheet = Image.new('RGBA', (W, GAP + len(strips) * (LABEL_H + sh + GAP)), (22, 18, 14, 255))
d = ImageDraw.Draw(sheet)
y = GAP
for n, s in zip(NAMES, strips):
    d.text((40, y), f'{n}   {NAMES[n]}', fill='#ffd27e', font=font)
    y += LABEL_H
    part = s.crop((0, 0, W // ZOOM, s.height)).resize((W, sh), Image.LANCZOS)
    sheet.alpha_composite(part, (0, y))
    y += sh + GAP
out = os.path.join(folder, 'metals_lines.webp')
sheet.convert('RGB').save(out, 'WEBP', quality=92)
print(out, sheet.size)
