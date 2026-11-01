#!/usr/bin/env python3
"""
Измеряет ДРОЖЬ камеры по серии кадров, а не на глаз.

[NOT-TESTED]

ЗАЧЕМ. Владелец: "камера дёргается". Глазами это спор без разрешения: у него
дёргается, у меня "вроде нет". Кадры спорить не умеют. Прибор считает, насколько
соседние кадры отличаются друг от друга: неподвижная сцена с неподвижным героем
даёт околонулевой ряд, дрожащая камера - пилу с всплесками.

КАК ЧИТАТЬ ЧИСЛА. Метрика - средняя абсолютная разница яркости на пиксель
(0..255). Порядки, снятые на этой сборке:
  * < 0.5   - кадры практически совпадают, камера стоит;
  * 1..3    - слабое шевеление (вода, трава, облака) - это ФОН сцены;
  * > 5     - камера действительно ездит.
Поэтому всегда снимай ФОНОВУЮ серию без вмешательства: без неё любое число
бессмысленно, потому что в Конане само по себе шевелится море и листва.

ОБЛАСТЬ. По умолчанию центральный прямоугольник - там герой, и туда не лезут
ни миникарта, ни панель квеста, ни часы, которые меняются сами и портят замер.

Запуск:
    python _config/frame-diff.py <папка с кадрами>
    python _config/frame-diff.py <папка> --full        по всему кадру
    python _config/frame-diff.py <папка> --csv out.csv
"""
import argparse
import os
import sys

from PIL import Image, ImageChops, ImageStat


def load_gray(path, box):
    img = Image.open(path).convert("L")
    if box:
        img = img.crop(box)
    return img


def centre_box(size, frac=0.5):
    w, h = size
    bw, bh = int(w * frac), int(h * frac)
    x = (w - bw) // 2
    y = (h - bh) // 2
    return (x, y, x + bw, y + bh)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--full", action="store_true", help="по всему кадру, без обрезки")
    ap.add_argument("--frac", type=float, default=0.5, help="доля кадра по центру")
    ap.add_argument("--csv", default=None)
    args = ap.parse_args()

    files = sorted(
        os.path.join(args.folder, f)
        for f in os.listdir(args.folder)
        if f.lower().endswith(".png")
    )
    if len(files) < 2:
        print("нужно хотя бы два кадра, найдено:", len(files))
        return 1

    first = Image.open(files[0])
    box = None if args.full else centre_box(first.size, args.frac)
    first.close()

    prev = load_gray(files[0], box)
    values = []
    for path in files[1:]:
        cur = load_gray(path, box)
        diff = ImageChops.difference(prev, cur)
        values.append(ImageStat.Stat(diff).mean[0])
        prev = cur

    n = len(values)
    avg = sum(values) / n
    mx = max(values)
    mn = min(values)
    over = sum(1 for v in values if v > 5.0)

    area = "весь кадр" if args.full else "центр %d%%" % int(args.frac * 100)
    print("кадров: %d   область: %s" % (len(files), area))
    print("разница соседних кадров: средняя %.2f   мин %.2f   макс %.2f" % (avg, mn, mx))
    print("кадров с разницей > 5 (камера ехала): %d из %d" % (over, n))
    print()
    print("ряд по кадрам:")
    for i, v in enumerate(values):
        bar = "#" * min(int(v * 4), 60)
        print("  %03d->%03d  %6.2f  %s" % (i, i + 1, v, bar))

    if args.csv:
        with open(args.csv, "w", encoding="utf-8", newline="\n") as f:
            f.write("pair,diff\n")
            for i, v in enumerate(values):
                f.write("%d,%.4f\n" % (i, v))
        print()
        print("csv:", args.csv)
    return 0


if __name__ == "__main__":
    sys.exit(main())
