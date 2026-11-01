"""xp-table.py — таблица опыта Конана (DT_ExperienceSystemLevel) по ОДНОМУ закону от 1-го уровня.

Зачем (13.09.2026, слово владельца): «мод на 10000 уровней» → «нужно посчитать кривую равномерную,
не то, что до 60 одна кривая, а после 60 другая — равномерный закон от уровня 1 до 10000, то есть
почти для бесконечности» → «это аналог моего Level Uncap в Обливион: чтобы играл и не думал о том,
что когда-то будет кап уровня».

Что известно из кита (KUMM researches/conan-devkit, 13.09):
- максимум уровня игра берёт из ЧИСЛА СТРОК таблицы (BP_ProgressionSystem → GetDataTableRowNames);
- в строке два поля, LevelStart и LevelEnd, оба int (int32): весь опыт до последнего уровня
  обязан уместиться в 2 147 483 647. Это предел типа числа — «бесконечная» прокачка упирается
  в него, и задача кривой — отодвинуть этот предел туда, куда игрок не доходит;
- в родной таблице 60 уровней, 1-й уровень стоит 175 опыта, 60-й — 359 500.

Закон: опыт за уровень L = anchor · L^p, один на все уровни.
- anchor — цена 1-го уровня (по умолчанию родные 175: начало игры идёт в родном темпе);
- p — насколько круто дорожают уровни: 0 — все одинаковые, 1 — растут прямо, 2 — как родная кривая;
- --p auto — подобрать p так, чтобы ровно --levels уровней заняли весь предел int32.

  python xp-table.py --reach                              сколько уровней влезает при разных p
  python xp-table.py --levels 10000                       p подбирается под 10 000 уровней
  python xp-table.py --levels 10000 --p 0.5 --csv out.csv  CSV для импорта в кит (Name,LevelStart,LevelEnd)
"""
# [TESTED: 2026-09-13 · --selftest 5 из 5: 10 000 уровней при подобранном p занимают int32 почти
#  впритык, цепочка LevelStart/LevelEnd цела, цена не убывает, p=1 даёт 4953 уровня как формула
#  суммы 175·N(N+1)/2, p=0 даёт int32 // 175. Не проверено: импорт CSV в кит и таблица в игре]
import argparse
import csv
import json
import os
import sys

INT32_MAX = 2_147_483_647
VANILLA_LEVEL1 = 175
REACH_LIMIT = 50_000_000       # защита от бесконечного счёта при p около 0
REACH_PS = [2.0, 1.5, 1.0, 0.75, 0.5, 0.25, 0.1, 0.0]
KEY_LEVELS = [1, 10, 60, 100, 1_000, 10_000, 100_000]
HERE = os.path.dirname(os.path.abspath(__file__))
VANILLA_CSV = os.path.normpath(os.path.join(
    HERE, "..", "..", "KUMM", "researches", "conan-devkit", "DT_ExperienceSystemLevel.csv"))


def xp_at(level: int, p: float, anchor: float) -> int:
    return max(1, int(round(anchor * level ** p)))


def reach(p: float, anchor: float) -> int:
    """Сколько уровней подряд влезает в int32 при этом законе."""
    total, level = 0, 0
    while level < REACH_LIMIT:
        cost = xp_at(level + 1, p, anchor)
        if total + cost > INT32_MAX:
            return level
        total += cost
        level += 1
    return level


def total_for(levels: int, p: float, anchor: float) -> int:
    return sum(xp_at(L, p, anchor) for L in range(1, levels + 1))


def solve_p(levels: int, anchor: float) -> float:
    """Наибольшее p, при котором levels уровней ещё влезают в int32 (бисекция)."""
    lo, hi = 0.0, 3.0
    if total_for(levels, lo, anchor) > INT32_MAX:
        raise SystemExit(f"{levels} уровней не влезают даже при одинаковой цене {anchor} — уменьшите --anchor")
    for _ in range(40):
        mid = (lo + hi) / 2
        if total_for(levels, mid, anchor) <= INT32_MAX:
            lo = mid
        else:
            hi = mid
    return lo


def build(levels: int, p: float, anchor: float) -> dict:
    rows, start = [], 0
    for L in range(1, levels + 1):
        cost = xp_at(L, p, anchor)
        if start + cost > INT32_MAX:
            break
        rows.append((L, start, start + cost))
        start += cost
    return {"p": p, "anchor": anchor, "levels_requested": levels, "rows": rows,
            "fits": len(rows) == levels, "reach": reach(p, anchor)}


def fmt(n: int) -> str:
    return f"{n:,}".replace(",", " ")


def load_vanilla() -> list[int]:
    try:
        return [int(r["XPForThisLevel"]) for r in csv.DictReader(open(VANILLA_CSV, encoding="utf-8"))]
    except OSError:
        return []


def print_build(t: dict, vanilla: list[int]) -> None:
    rows = t["rows"]
    last = rows[-1]
    head = f"закон: опыт за уровень = {t['anchor']:g} · L^{t['p']:.4f}"
    print(head)
    if t["fits"]:
        print(f"  {fmt(t['levels_requested'])} уровней влезают: итог LevelEnd {fmt(last[2])} из {fmt(INT32_MAX)}")
    else:
        print(f"  ⚠️ влезло только {fmt(len(rows))} уровней из {fmt(t['levels_requested'])} — дальше предел int32")
    print(f"  всего при этом законе влезает уровней: {fmt(t['reach'])}")
    parts = []
    for L in KEY_LEVELS:
        if L <= len(rows):
            v = rows[L - 1][2] - rows[L - 1][1]
            ref = f" (в игре {fmt(vanilla[L - 1])})" if vanilla and L <= len(vanilla) else ""
            parts.append(f"{fmt(L)}-й {fmt(v)}{ref}")
    print("  цена уровня: " + " · ".join(parts))


def selftest() -> int:
    ok = True
    t = build(10_000, solve_p(10_000, VANILLA_LEVEL1), VANILLA_LEVEL1)
    r = t["rows"]
    c1 = t["fits"] and r[-1][2] <= INT32_MAX and r[-1][2] > INT32_MAX * 0.999
    c2 = r[0] == (1, 0, VANILLA_LEVEL1) and all(r[i + 1][1] == r[i][2] for i in range(len(r) - 1))
    c3 = all((r[i + 1][2] - r[i + 1][1]) >= (r[i][2] - r[i][1]) for i in range(len(r) - 1))
    # Контроль по формуле: при p = 1 сумма 175·N(N+1)/2 ≤ int32 даёт N = 4953.
    c4 = reach(1.0, VANILLA_LEVEL1) == 4953
    c5 = reach(0.0, VANILLA_LEVEL1) == INT32_MAX // VANILLA_LEVEL1
    for name, c in (("10 000 уровней влезают почти впритык", c1), ("цепочка LevelStart/LevelEnd", c2),
                    ("цена не убывает", c3), ("p=1: 4953 уровня по формуле", c4), ("p=0: int32 // 175", c5)):
        print(f"selftest: {name} — {c}")
        ok = ok and c
    return 0 if ok else 1


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", type=int, default=10_000)
    ap.add_argument("--p", default="auto", help="показатель закона или auto")
    ap.add_argument("--anchor", type=float, default=VANILLA_LEVEL1, help="цена 1-го уровня")
    ap.add_argument("--reach", action="store_true", help="сколько уровней влезает при разных p")
    ap.add_argument("--csv")
    ap.add_argument("--json")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    vanilla = load_vanilla()
    if a.reach:
        print(f"цена 1-го уровня {a.anchor:g}; сколько уровней влезает в int32 ({fmt(INT32_MAX)}):")
        for p in REACH_PS:
            n = reach(p, a.anchor)
            note = "" if n < REACH_LIMIT else " (и больше)"
            print(f"  p = {p:<4g} → {fmt(n)} уровней{note}; последний стоит {fmt(xp_at(max(n, 1), p, a.anchor))}")
        return 0
    p = solve_p(a.levels, a.anchor) if a.p == "auto" else float(a.p)
    t = build(a.levels, p, a.anchor)
    print_build(t, vanilla)
    if a.csv:
        with open(a.csv, "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f)
            w.writerow(["Name", "LevelStart", "LevelEnd"])
            w.writerows(t["rows"])
        print(f"CSV: {a.csv} ({fmt(len(t['rows']))} строк)")
    if a.json:
        json.dump({"p": p, "anchor": a.anchor, "reach": t["reach"],
                   "xp": [r[2] - r[1] for r in t["rows"]], "end": [r[2] for r in t["rows"]]},
                  open(a.json, "w", encoding="utf-8"))
        print(f"JSON: {a.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
