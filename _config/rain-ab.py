#!/usr/bin/env python3
"""
Ждёт дождя и снимает ПАРЫ кадров «мод включён / мод выключен» под разными углами.

[NOT-TESTED]

ЗАЧЕМ. Заказ владельца 09.09.2026: «дождаться дождя, снять скриншоты под разными
углами парами с вкл и выкл мода». Без пары под ОДНИМ дождём любой кадр ничего не
доказывает: дожди разные, время суток разное, мокрость успевает накопиться.

КАК ЛОВИТСЯ ДОЖДЬ — спрашиваем саму игру, а не гадаем по картинке.
Съёмка Weather_SceneCapture2d_Rain существует ТОГДА И ТОЛЬКО ТОГДА, когда идёт
дождь: создаётся с ним и уничтожается с ним. Прибор жмёт зонд (Numpad 1) и
читает в журнале строку «класс SceneCaptureComponent2D: всего N».

Две отвергнутые версии, чтобы их не изобретали заново:
  * ПО ЯРКОСТИ — путает ночь: ночное небо дало 9 единиц против 100 дневного.
  * ПО ДВИЖЕНИЮ между двумя кадрами — дало ложную тревогу в 21:09 на сухой
    сцене и сняло восемь бесполезных кадров. Пиксели шевелятся от чего угодно:
    анимации героя, облаков, облёта камеры в простое.
Движение всё ещё считается, но только для отчёта, решения оно не принимает.

ЧТО ПЕРЕКЛЮЧАЕТ МОД. Numpad . (0x6E) в моде камеры меняет OrthoWidth съёмки
дождя между ванильными 4096 (41 м) и нашими 12288 (123 м). Прибор ПРОВЕРЯЕТ по
журналу, какое значение встало, и подписывает кадр им — а не тем, что собирался
поставить.

Запуск:
    python _config/rain-ab.py --out <папка> --minutes 40
"""
import argparse
import os
import re
import subprocess
import sys
import time

from PIL import Image, ImageChops, ImageStat

HERE = os.path.dirname(os.path.abspath(__file__))
CAPTURE = os.path.join(HERE, "capture.ps1")
INPUT = os.path.join(HERE, "input.ps1")
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
ULOG = sandbox('Binaries', 'Win64', 'ue4ss', 'UE4SS.log')
TOGGLE_KEY = "0x6E"

# Углы: сдвиг мыши от текущего положения и обратно. Пары снимаются на каждом.
ANGLES = [
    ("gorizont", (0, 0)),
    ("naklon45", (0, 180)),
    ("sverhu", (0, 200)),
    ("vbok", (500, -250)),
]


def ps(script, *args):
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script]
    cmd.extend(args)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                       errors="replace")
    return (r.stdout or "") + (r.stderr or "")


def shot(path, width=960):
    ps(CAPTURE, "-Out", path, "-Width", str(width))
    return path


def look(dx, dy):
    if dx or dy:
        ps(INPUT, "-Look", "%d,%d" % (dx, dy))


def game_alive():
    r = subprocess.run(["powershell", "-NoProfile", "-Command",
                        "if (Get-Process -Name 'ConanSandbox-Win64-Shipping' "
                        "-ErrorAction SilentlyContinue) {'yes'} else {'no'}"],
                       capture_output=True, text=True)
    return "yes" in (r.stdout or "")


def raining():
    """ОПРЕДЕЛЁННЫЙ признак дождя, а не эвристика.

    Съёмка Weather_SceneCapture2d_Rain существует ТОГДА И ТОЛЬКО ТОГДА, когда
    идёт дождь: она создаётся вместе с ним и уничтожается вместе с ним
    (проверено 09.09.2026: под дождём ровно одна, в сухую ночь ноль).

    Первая редакция ловила дождь по ДВИЖЕНИЮ между двумя кадрами - и в 21:09
    дала ложную тревогу на сухой сцене, сняв восемь бесполезных кадров. Пиксели
    шевелятся от чего угодно: анимации героя, облаков, облёта камеры. Здесь
    спрашиваем саму игру.
    """
    before = os.path.getsize(ULOG) if os.path.exists(ULOG) else 0
    ps(INPUT, "-Key", "0x61")          # зонд дождя
    time.sleep(2.5)
    try:
        with open(ULOG, encoding="utf-8", errors="replace") as f:
            f.seek(before)
            tail = f.read()
    except OSError:
        return False
    m = re.findall(r"класс SceneCaptureComponent2D: всего (\d+)", tail)
    return bool(m) and int(m[-1]) > 0


def frame_motion(tmp_a, tmp_b):
    """Насколько сцена шевелится между двумя кадрами подряд (только для отчёта)."""
    shot(tmp_a, 640)
    time.sleep(0.4)
    shot(tmp_b, 640)
    a = Image.open(tmp_a).convert("L")
    b = Image.open(tmp_b).convert("L")
    w, h = a.size
    # Нижние две трети: без неба, где облака ползут сами по себе.
    box = (0, h // 3, w, h)
    d = ImageChops.difference(a.crop(box), b.crop(box))
    v = ImageStat.Stat(d).mean[0]
    a.close()
    b.close()
    return v


def ortho_now():
    """Какое значение охвата стоит СЕЙЧАС - по последней строке журнала мода."""
    try:
        with open(ULOG, encoding="utf-8", errors="replace") as f:
            txt = f.read()
    except OSError:
        return None
    hits = re.findall(r"переключатель охвата: [\d.]+ -> ([\d.]+)", txt)
    if hits:
        return float(hits[-1])
    hits = re.findall(r"дождь: охват съёмки [\d.]+ -> ([\d.]+)", txt)
    return float(hits[-1]) if hits else None


def toggle():
    ps(INPUT, "-Key", TOGGLE_KEY)
    time.sleep(1.2)
    return ortho_now()


def do_pairs(out, tag):
    """Пары кадров на каждом угле: как есть -> переключили -> вернули."""
    made = []
    for name, (dx, dy) in ANGLES:
        look(dx, dy)
        time.sleep(1.0)

        v1 = ortho_now()
        p1 = os.path.join(out, "%s_%s_A_%s.png" % (tag, name, int(v1 or 0)))
        shot(p1)

        v2 = toggle()
        p2 = os.path.join(out, "%s_%s_B_%s.png" % (tag, name, int(v2 or 0)))
        shot(p2)

        v3 = toggle()          # вернуть как было
        made.append((name, v1, v2, v3, p1, p2))
        print("  угол %-9s A=%s  B=%s  (вернул %s)" % (name, v1, v2, v3))

        look(-dx, -dy)         # вернуть ракурс
        time.sleep(0.6)
    return made


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--minutes", type=int, default=40)
    ap.add_argument("--every", type=int, default=45, help="секунд между проверками")
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    tmp_a = os.path.join(args.out, "_t1.png")
    tmp_b = os.path.join(args.out, "_t2.png")

    print("базовый уровень движения сцены:")
    base = []
    for _ in range(3):
        base.append(frame_motion(tmp_a, tmp_b))
        time.sleep(1.0)
    baseline = sum(base) / len(base)
    thr = max(baseline * 2.0, baseline + 2.0)
    print("  %s  ->  база %.2f, порог дождя %.2f" %
          (" ".join("%.2f" % v for v in base), baseline, thr))
    print()

    deadline = time.time() + args.minutes * 60
    shots = 0
    while time.time() < deadline:
        if not game_alive():
            print("игра закрыта - останавливаюсь")
            break
        stamp = time.strftime("%H:%M:%S")
        wet = raining()
        m = frame_motion(tmp_a, tmp_b)
        if wet:
            print("[%s] СЪЁМКА ДОЖДЯ ЕСТЬ (движение %.2f) - снимаю пары" % (stamp, m))
            made = do_pairs(args.out, time.strftime("%H%M%S"))
            shots += len(made)
            # Хватит одного полного набора; второй - если дождь ещё идёт позже.
            time.sleep(120)
        else:
            print("[%s] сухо (съёмки дождя нет, движение %.2f)" % (stamp, m))
        time.sleep(args.every)

    for t in (tmp_a, tmp_b):
        if os.path.exists(t):
            os.remove(t)
    print("готово. пар снято: %d" % shots)
    return 0


if __name__ == "__main__":
    sys.exit(main())
