# bench-fps-map.py <csv PresentMon> <bench.log> <выход без расширения> [номер облёта с конца журнала, 1 — последний] [подпись]
# — карта кадров облёта-бенча: по каждой секунде полёта к/с, худший кадр и рывки ≥ 50 мс из CSV PresentMon и место камеры из строк
# `EV fly=prog t=<с> cam=x,y,z` журнала KrinikConanBench. Пишет <выход>.tsv и <выход>.webp (маршрут сверху, раскрашенный по к/с,
# рывки — крестами; под ним к/с по секундам).
# Зачем: владелец 2026-10-25 — «это эталон, по нему будем бенчить, снимать FPS карту»: где на маршруте игра проседает — место, а не
# только среднее за облёт. Секунда CSV = секунда полёта: bench-flight.sh запускает PresentMon по метке «EV fly=start» (сдвиг < 0,5 с).
# Картинка — WebP (правило проекта: PNG никогда).
# [NOT-TESTED]
import csv, re, sys
from collections import defaultdict

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HITCH_MS = 50.0
csv_path, log_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
nth = int(sys.argv[4]) if len(sys.argv) > 4 else 1
title = sys.argv[5] if len(sys.argv) > 5 else out

# кадры по секундам
rows = list(csv.DictReader(open(csv_path, encoding="utf-8-sig", errors="replace")))
t0 = float(rows[0]["TimeInMs"])
sec = defaultdict(list)
for r in rows:
    try:
        t, ms = float(r["TimeInMs"]), float(r["MsBetweenPresents"])
    except (ValueError, KeyError):
        continue
    sec[int((t - t0) / 1000.0)].append(ms)

# места камеры: облёт № nth с конца журнала (строки между «EV fly=start» и «EV fly=done»)
flights, cur = [], None
for line in open(log_path, encoding="utf-8", errors="replace"):
    if "EV fly=start" in line:
        cur = {}
    elif "EV fly=done" in line and cur is not None:
        flights.append(cur); cur = None
    elif cur is not None:
        m = re.search(r"EV fly=prog t=(\d+) cam=(-?\d+),(-?\d+),(-?\d+)", line)
        if m:
            cur[int(m.group(1))] = tuple(int(v) for v in m.groups()[1:])
pos = flights[-nth]

out_rows = []
for k in sorted(sec):
    if k not in pos:
        continue
    ms = sec[k]
    fps = len(ms) / (sum(ms) / 1000.0)
    out_rows.append((k, *pos[k], fps, max(ms), sum(1 for v in ms if v >= HITCH_MS)))

with open(out + ".tsv", "w", encoding="utf-8") as f:
    f.write("сек\tx\ty\tz\tк/с\tхудший_мс\tрывков\n")
    for r in out_rows:
        f.write("%d\t%d\t%d\t%d\t%.1f\t%.1f\t%d\n" % r)

xs = [r[1] / 100 for r in out_rows]; ys = [r[2] / 100 for r in out_rows]; fps = [r[4] for r in out_rows]
fig, (a1, a2) = plt.subplots(2, 1, figsize=(12, 13), gridspec_kw={"height_ratios": [3, 1]})
sc = a1.scatter(xs, ys, c=fps, cmap="RdYlGn", vmin=20, vmax=90, s=40)
for r in out_rows:
    if r[6]:
        a1.scatter([r[1] / 100], [r[2] / 100], marker="x", c="black", s=60 + 30 * r[6])
for r in out_rows[::10]:
    a1.annotate("%d с" % r[0], (r[1] / 100, r[2] / 100), fontsize=8, xytext=(4, 4), textcoords="offset points")
a1.invert_yaxis()                     # +Y — юг (вода течёт к морю): север — вверх, как на карте игры
a1.set_aspect("equal"); a1.set_xlabel("x, м (запад ← → восток)"); a1.set_ylabel("y, м (север ↑)")
a1.set_title("%s — к/с по секундам облёта; × — рывки ≥ %d мс" % (title, HITCH_MS))
fig.colorbar(sc, ax=a1, label="к/с")
a2.plot([r[0] for r in out_rows], fps, color="#2a6"); a2.set_xlabel("секунда облёта"); a2.set_ylabel("к/с"); a2.grid(alpha=.3)
fig.tight_layout(); fig.savefig(out + ".webp", format="webp", dpi=90)
lows = sorted(out_rows, key=lambda r: r[4])[:5]
print("секунд %d · худшие места: %s" % (len(out_rows), "; ".join("%d с (%d,%d) %.0f к/с" % (r[0], r[1], r[2], r[4]) for r in lows)))
