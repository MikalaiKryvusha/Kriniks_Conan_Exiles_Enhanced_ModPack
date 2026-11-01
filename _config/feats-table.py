"""feats-table.py — очки знаний за уровень (DT_FeatsPerLevel) по формуле, выведенной из родной таблицы.

Зачем (13.09.2026, слово владельца): «из ванильных цифр выведи формулу, и по этой формуле для наших
10000 уровней посчитай». Родная таблица — 60 строк, прочитана китом без окна
(KUMM researches/conan-devkit/DT_FeatsPerLevel.csv).

Родная формула: очки(L) = (L // 5 + 1) · (3, если L кратно 10, иначе 1); на 1-м уровне 0 — с него
начинают, повышения не было. То есть норма растёт на 1 каждые пять уровней, каждый десятый уровень даёт
тройную. Сумма по ней к 1 000-му уровню — 121 099, ровно столько обещает мод MrSerji's Level 1000 в своём
описании: автор считал так же.

Потолок нормы — 16 (слово владельца 13.09 ~20:50: «давай всё же не больше 50 за уровень давать. Какую-то
смесь сделаем ванили, но без взрывной прогрессии» → из вариантов A «рост до 50 и ровно» и B «ванильный
ритм навсегда» выбрал «B»). Норма растёт как в игре до 16 (к 75-му уровню) и дальше стоит; каждый десятый
уровень остаётся тройным — 48. Первые 60 уровней совпадают с родной таблицей.

  python feats-table.py --levels 10000                 ключевые уровни и сумма
  python feats-table.py --levels 10000 --csv out.csv   CSV для кита (Name,FeatPoints)
  python feats-table.py --selftest                     формула против родной таблицы и контроль
"""
# [TESTED: 2026-09-13 · --selftest: 60 из 60 строк родной таблицы совпали; контроль без утроения
#  расходится в 6 строках (проверка умеет краснеть); сумма без потолка к 1000-му = 121 099 = число из
#  modinfo MrS; с потолком 16 максимум за уровень 48, контроль без потолка даёт 6 003 — краснеет]
import argparse
import csv
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
VANILLA_CSV = os.path.normpath(os.path.join(
    HERE, "..", "..", "KUMM", "researches", "conan-devkit", "DT_FeatsPerLevel.csv"))
STEP_LEVELS = 5          # норма растёт на 1 каждые пять уровней
BONUS_EVERY = 10         # каждый десятый уровень — тройная норма
BONUS_FACTOR = 3
BASE_CAP = 16            # потолок нормы — выбор владельца «B» 13.09; десятый уровень 16 · 3 = 48
MAX_PER_LEVEL = 50       # слово владельца: «не больше 50 за уровень»
MRS_TOTAL_AT_1000 = 121_099  # из описания мода MrSerji's Level 1000 (modinfo.json)
KEY_LEVELS = [1, 2, 10, 60, 100, 500, 1_000, 2_000, 5_000, 9_999, 10_000]


def feats_at(level: int, bonus: bool = True, cap: int | None = BASE_CAP) -> int:
    if level <= 1:
        return 0
    base = level // STEP_LEVELS + 1
    if cap is not None:
        base = min(base, cap)
    return base * BONUS_FACTOR if bonus and level % BONUS_EVERY == 0 else base


def fmt(n: int) -> str:
    return f"{n:,}".replace(",", " ")


def selftest() -> int:
    vanilla = [int(r["FeatPoints"]) for r in csv.DictReader(open(VANILLA_CSV, encoding="utf-8"))]
    match = sum(1 for L, v in enumerate(vanilla, 1) if feats_at(L) == v)
    control = sum(1 for L, v in enumerate(vanilla, 1) if feats_at(L, bonus=False) != v)
    mrs = sum(feats_at(L, cap=None) for L in range(1, 1_001))
    top = max(feats_at(L) for L in range(1, 10_001))
    top_uncapped = max(feats_at(L, cap=None) for L in range(1, 10_001))
    checks = [
        (f"формула = родная таблица: {match} из {len(vanilla)}", match == len(vanilla) == 60),
        (f"контроль без утроения краснеет: расхождений {control}", control > 0),
        (f"родная формула без потолка к 1000-му = {fmt(mrs)} (MrS обещает {fmt(MRS_TOTAL_AT_1000)})",
         mrs == MRS_TOTAL_AT_1000),
        (f"максимум за уровень до 10 000-го: {top} ≤ {MAX_PER_LEVEL}", top <= MAX_PER_LEVEL),
        (f"контроль без потолка краснеет: максимум {fmt(top_uncapped)}", top_uncapped > MAX_PER_LEVEL),
    ]
    for name, ok in checks:
        print(f"selftest: {name} — {ok}")
    return 0 if all(ok for _, ok in checks) else 1


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", type=int, default=10_000)
    ap.add_argument("--csv")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    total = 0
    running = {}
    for L in range(1, a.levels + 1):
        total += feats_at(L)
        running[L] = total
    for L in KEY_LEVELS:
        if L <= a.levels:
            print(f"уровень {fmt(L):>6}: за уровень {fmt(feats_at(L)):>6} · накоплено {fmt(running[L])}")
    print(f"всего к {fmt(a.levels)}-му уровню: {fmt(total)}")
    if a.csv:
        with open(a.csv, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["Name", "FeatPoints"])
            w.writerows((L, feats_at(L)) for L in range(1, a.levels + 1))
        print(f"CSV: {a.csv} ({fmt(a.levels)} строк)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
