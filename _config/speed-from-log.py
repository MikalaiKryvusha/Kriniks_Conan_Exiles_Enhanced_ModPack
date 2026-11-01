"""speed-from-log.py — скорость героя из серии «ЗАМЕР» зонда ConanAttributeProbe.

Зачем (13.09.2026, идея 03 в KUMM): зонд по Alt+Numpad + пишет в UE4SS.log сорок
точек — место, |скорость|, MaxWalkSpeed, прыжок, выносливость. Считать бег глазами по
сорока строкам — ошибка на каждой; скрипт делает это одинаково каждый раз.

Δt берётся из МЕТОК ВРЕМЕНИ журнала, а не из шага 200 мс: ExecuteWithDelay плюс
ExecuteInGameThread дают плавающую задержку, и скорость «шаг / 0.2 с» врала бы.

Итог — две независимые оценки бега, и расхождение между ними само по себе улика:
  1) медиана |v| компонента движения на точках, где герой бежит;
  2) путь по координатам / время между первой и последней бегущей точкой.

  python speed-from-log.py                 последняя серия
  python speed-from-log.py --series -2     предпоследняя
  python speed-from-log.py --log <путь>    другой журнал
"""
# [TESTED: 2026-09-13 · искусственный журнал 400 ед/с → обе оценки 400, журнал без
#  серии → выход 1; живые серии → 450/442, 729/695 против |v|. Первая живая серия
#  нашла дефект склейки кувырка с бегом (364 вместо 450) — исправлено отрезками]
import argparse
import math
import re
import statistics
import sys
from datetime import datetime

import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
DEFAULT_LOG = sandbox('Binaries', 'Win64', 'ue4ss', 'UE4SS.log')
# Порог «бежит»: стоящий герой даёт |v| = 0, кувырок ~900, бег ~300+.
MOVING_MIN_SPEED = 50.0

STAMP = re.compile(r"^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+)\]")
START = re.compile(r"\[ConanAttributeProbe\] ЗАМЕР начат")
SAMPLE = re.compile(
    r"\[ConanAttributeProbe\] ЗАМЕР (\d+) место=\(([-\d.]+), ([-\d.]+), ([-\d.]+)\) "
    r"\|v\|=([-\d.]+) MaxWalkSpeed=(\S+) JumpZ=(\S+) выносл=(\S+) RunSpeed=(\S+)"
)


def parse_time(s: str) -> datetime:
    # В журнале семь знаков дробной части, strptime понимает не больше шести.
    head, frac = s.split(".")
    return datetime.strptime(f"{head}.{frac[:6]}", "%Y-%m-%d %H:%M:%S.%f")


def read_series(path: str) -> list[list[dict]]:
    series: list[list[dict]] = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            if START.search(line):
                series.append([])
                continue
            m = SAMPLE.search(line)
            t = STAMP.match(line)
            if not (m and t):
                continue
            if not series:
                series.append([])
            series[-1].append({
                "t": parse_time(t.group(1)),
                "n": int(m.group(1)),
                "x": float(m.group(2)), "y": float(m.group(3)), "z": float(m.group(4)),
                "v": float(m.group(5)),
                "mws": m.group(6), "jz": m.group(7), "st": m.group(8), "run": m.group(9),
            })
    return series


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", default=DEFAULT_LOG)
    ap.add_argument("--series", type=int, default=-1)
    a = ap.parse_args()

    all_series = read_series(a.log)
    if not all_series:
        print("серий ЗАМЕР в журнале нет")
        return 1
    s = all_series[a.series]
    print(f"серий в журнале: {len(all_series)}; беру {a.series}, точек {len(s)}")
    if len(s) < 2:
        print("мало точек")
        return 1

    t0 = s[0]["t"]
    print(f"{'n':>3} {'t,с':>6} {'шаг':>6} {'шаг/с':>7} {'|v|':>5} {'MaxWalk':>8} {'JumpZ':>5} {'выносл':>8} {'Run':>5}")
    prev = None
    for p in s:
        t = (p["t"] - t0).total_seconds()
        if prev:
            d = math.hypot(p["x"] - prev["x"], p["y"] - prev["y"])
            dt = (p["t"] - prev["t"]).total_seconds()
            step, rate = f"{d:.0f}", (f"{d / dt:.0f}" if dt > 0 else "—")
        else:
            step, rate = "", ""
        print(f"{p['n']:>3} {t:6.2f} {step:>6} {rate:>7} {p['v']:5.0f} {p['mws']:>8} {p['jz']:>5} {p['st']:>8} {p['run']:>5}")
        prev = p

    # Бег — это самый длинный НЕПРЕРЫВНЫЙ отрезок точек с |v| >= порога. Первый живой
    # замер 13.09 10:07 показал зачем: кувырок от Alt даёт свой короткий отрезок в
    # начале серии, и «все движущиеся точки подряд» склеили кувырок, паузу и бег
    # в одну оценку 364 при настоящих 450.
    segments, cur = [], []
    for p in s:
        if p["v"] >= MOVING_MIN_SPEED:
            cur.append(p)
        elif cur:
            segments.append(cur)
            cur = []
    if cur:
        segments.append(cur)
    moving = max(segments, key=len) if segments else []
    if len(moving) < 3:
        print(f"непрерывного бега (|v| >= {MOVING_MIN_SPEED:.0f}) меньше трёх точек — бега не было")
        return 1
    print(f"отрезков движения: {len(segments)} (длины {[len(g) for g in segments]}); беру самый длинный")
    # Первая и последняя точки отрезка — разгон и торможение; их не мерим.
    core = moving[1:-1] if len(moving) >= 4 else moving
    path = sum(math.hypot(b["x"] - a_["x"], b["y"] - a_["y"]) for a_, b in zip(core, core[1:]))
    span = (core[-1]["t"] - core[0]["t"]).total_seconds()
    print()
    print(f"бегущих точек: {len(moving)}; медиана |v| = {statistics.median(p['v'] for p in moving):.0f}")
    if span > 0:
        print(f"по координатам: {path:.0f} ед. за {span:.2f} с = {path / span:.0f} ед/с")
    print(f"MaxWalkSpeed в серии: {sorted({p['mws'] for p in s})}; JumpZ: {sorted({p['jz'] for p in s})}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
