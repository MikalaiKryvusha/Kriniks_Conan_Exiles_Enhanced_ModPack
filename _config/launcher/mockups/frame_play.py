# Игра с двумя алгоритмами, которые владелец отобрал из восьми (frame_algos.py): 2 — металл логотипа Conan и 1 — царапины и каверны. Слово владельца
# 2026-10-31 18:47: «2 хорош, и твой 1. Давай с ними побалуемся, и попрробуем тоньше варианты».
# Ось вариантов: алгоритм (1, 2, их смесь, мелкий рисунок логотипа) × толщина каймы (5, 4, 3 логических пикселя). Держится: цвет 1, способ строить края.
# Пишет play/frame_h_N.webp, play/frame_v_N.webp и лист play/lines.webp (полосы одна под другой, в одном увеличении — толщины сравнимы).
# Запуск: python -X utf8 frame_play.py
# [NOT-TESTED]
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import frame_algos as fa

OUT = os.path.join(fa.HERE, 'play')

def mix(h, w, u, alpha, rng):
    # Смесь: поверхность логотипа со светом, поверх — штрихи алгоритма 1 (царапины, зарубки, каверны) вполовину густоты.
    rgb, a = fa.surf_logo(h, w, u, alpha, rng)
    return fa.strokes(rgb, a, rng, h, w, amount=.55), a

def logo_fine(h, w, u, alpha, rng):
    # Металл логотипа мельче: кусок логотипа вдвое больше по стороне, на полосе он сжимается — царапины тоньше и чаще.
    old = fa.LOGO_P; fa.LOGO_P = 64
    try: return fa.surf_logo(h, w, u, alpha, rng)
    finally: fa.LOGO_P = old

# номер: (подпись, поверхность, толщина каймы в логических пикселях)
VARIANTS = {
    1: ('1 царапины и каверны · 4 px', fa.surf_scratches, 4),
    2: ('1 царапины и каверны · 3 px', fa.surf_scratches, 3),
    3: ('2 металл логотипа · 4 px', fa.surf_logo, 4),
    4: ('2 металл логотипа · 3 px', fa.surf_logo, 3),
    5: ('смесь 2 + 1 · 5 px', mix, 5),
    6: ('смесь 2 + 1 · 4 px', mix, 4),
    7: ('смесь 2 + 1 · 3 px', mix, 3),
    8: ('2 металл логотипа мельче · 4 px', logo_fine, 4),
}

def set_thickness(px):
    # Толщина в пикселях картинки при масштабе 4; средняя и разброс ширины — в той же пропорции, что у каймы 6 px (19 и 4 из 24).
    fa.TMAX = px * 4; fa.T_MEAN = px * 4 * 19 / 24; fa.T_SWING = px * 4 * 4 / 24; fa.EDGE = px / 6

def strip(length, fn, which):
    w = length * fa.SS
    h, u, alpha = fa.geometry(w, np.random.default_rng(fa.SEED_SHAPE + which))
    rgb, a = fn(h, w, u, alpha, np.random.default_rng(fa.SEED_SURF + which))
    im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    return im.resize((length, fa.TMAX), Image.LANCZOS)

def main():
    os.makedirs(OUT, exist_ok=True)
    for n, (label, fn, px) in VARIANTS.items():
        set_thickness(px)
        hz = strip(fa.LONG_H, fn, 0)
        vt = strip(fa.LONG_V, fn, 1).rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT)
        hz.save(os.path.join(OUT, f'frame_h_{n}.webp'), 'WEBP', quality=90)
        vt.save(os.path.join(OUT, f'frame_v_{n}.webp'), 'WEBP', quality=90)
        print(n, label, hz.size, vt.size)
    # Лист: каждая полоса в одном увеличении (×3) — тонкая выглядит тонкой.
    W, ZOOM, LABEL_H, GAP = 3840, 3, 70, 46
    font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 46)
    strips = [Image.open(os.path.join(OUT, f'frame_h_{n}.webp')).convert('RGBA') for n in VARIANTS]
    sheet = Image.new('RGBA', (W, GAP + sum(LABEL_H + s.height * ZOOM + GAP for s in strips)), (22, 18, 14, 255))
    d = ImageDraw.Draw(sheet); y = GAP
    for n, s in zip(VARIANTS, strips):
        d.text((40, y), f'{n}   {VARIANTS[n][0]}', fill='#ffd27e', font=font); y += LABEL_H
        sheet.alpha_composite(s.crop((0, 0, W // ZOOM, s.height)).resize((W, s.height * ZOOM), Image.LANCZOS), (0, y)); y += s.height * ZOOM + GAP
    sheet.convert('RGB').save(os.path.join(OUT, 'lines.webp'), 'WEBP', quality=92)
    print('lines', sheet.size)

main()
