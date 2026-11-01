# tooltip-bbox.py — прямоугольник подсказки на каждом кадре серии hover-watch.ps1: что появилось относительно первого кадра.
# Зачем (2026-10-29, KUMM баг 64 п. 17, класс A): владелец видит, как подсказка предмета открывается в одну строку, затем
# становится в две. Ширина и высота подсказки по кадрам — это число, которое прыжок либо показывает, либо нет; глаз на 200 кадрах
# ошибается, сравнение двух чисел — нет.
# Первый кадр серии снят в момент движения курсора — подсказки на нём ещё нет. Квадрат вокруг курсора (подсветка ячейки) не в счёт.
#   /c/Python314/python.exe -X utf8 tooltip-bbox.py <папка кадров> [--cursor 150,120] [--ignore 110] [--thr 48]
# Печатает строку на каждое ИЗМЕНЕНИЕ прямоугольника: «<мс>  x y w h», в конце — первый и устоявшийся размер.
# [NOT-TESTED]
import argparse
import glob
import os

import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('dir')
ap.add_argument('--cursor', default='150,120', help='курсор в координатах кадра (смещение -Box с обратным знаком)')
ap.add_argument('--ignore', type=int, default=110, help='полуразмер квадрата вокруг курсора, который не считается')
ap.add_argument('--thr', type=int, default=48, help='порог разницы канала, 0..255 (JPEG шумит на ~10–20)')
ap.add_argument('--min-px', type=int, default=400, help='меньше стольких изменённых пикселей — подсказки нет')
ap.add_argument('--roi', default='', help='x0,y0,x1,y1 — считать только здесь (фон за хабом живой: мир идёт, герой дышит)')
a = ap.parse_args()

files = sorted(glob.glob(os.path.join(a.dir, 'f_*.jpg')), key=lambda p: int(os.path.basename(p)[2:7]))
if not files:
    raise SystemExit('нет кадров f_*.jpg в ' + a.dir)
cx, cy = (int(v) for v in a.cursor.split(','))
base = np.asarray(Image.open(files[0]).convert('RGB'), dtype=np.int16)
h, w, _ = base.shape
mask = np.ones((h, w), bool)
mask[max(0, cy - a.ignore):cy + a.ignore, max(0, cx - a.ignore):cx + a.ignore] = False
if a.roi:
    rx0, ry0, rx1, ry1 = (int(v) for v in a.roi.split(','))
    roi = np.zeros((h, w), bool)
    roi[ry0:ry1, rx0:rx1] = True
    mask &= roi

last = None
seen = []
for f in files:
    ms = int(os.path.basename(f)[2:7])
    img = np.asarray(Image.open(f).convert('RGB'), dtype=np.int16)
    diff = (np.abs(img - base).max(axis=2) > a.thr) & mask
    if diff.sum() < a.min_px:
        box = None
    else:
        ys, xs = np.nonzero(diff)
        # края по 1-му и 99-му перцентилю: одиночные шумные пиксели не раздувают рамку
        x0, x1 = np.percentile(xs, [0.5, 99.5]).astype(int)
        y0, y1 = np.percentile(ys, [0.5, 99.5]).astype(int)
        box = (int(x0), int(y0), int(x1 - x0), int(y1 - y0))
    if box != last:
        print(f'{ms:6d}  ' + ('нет подсказки' if box is None else '%d %d %d %d' % box))
        last = box
    if box is not None:
        seen.append((ms, box))
if seen:
    print(f'первый: {seen[0][0]} мс {seen[0][1][2]}x{seen[0][1][3]} · последний: {seen[-1][0]} мс {seen[-1][1][2]}x{seen[-1][1][3]} · кадров с подсказкой {len(seen)} из {len(files)}')
else:
    print(f'подсказки нет ни на одном из {len(files)} кадров')
