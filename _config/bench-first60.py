# bench-first60.py — рывки (кадры ≥ 50 мс) в первые N секунд облёта по CSV PresentMon, по одной строке на файл.
#
# Зачем (KUMM TC_conan_quickwins_tier_a_2026-11-09, 2026-11-09): строки «шейдеры при загрузке» (niagara.CreateShadersOnLoad,
# r.CreateShadersOnLoad) переносят создание шейдеров с первого показа на загрузку — выигрыш ждём в начале ХОЛОДНОГО облёта, а
# bench-report.py считает рывки за весь облёт. Прибор читает те же CSV и печатает рывки и их сумму в первые N секунд.
#   python -I -X utf8 bench-first60.py <csv>… [--sec 60]
# [TESTED: 2026-11-09 · `--sec 9999` on 2026-11-09_161104_ram-A1.csv = bench-journal (33 hitches · 2109.6 ms · worst 156.8); first 60 s: 15 · 846.1 · 65.2]
import csv
import sys

HITCH_MS = 50.0


def first(path, sec):
    rows = list(csv.DictReader(open(path, encoding="utf-8", errors="replace")))
    col = "MsBetweenPresents" if "MsBetweenPresents" in rows[0] else "FrameTime"
    t = 0.0
    hitches = []
    for r in rows:
        v = r.get(col)
        if v in (None, "", "NA"):
            continue
        ms = float(v)
        if t >= sec * 1000:
            break
        if ms >= HITCH_MS:
            hitches.append(ms)
        t += ms
    return len(hitches), round(sum(hitches), 1), round(max(hitches), 1) if hitches else 0.0


def main():
    args = sys.argv[1:]
    sec = 60.0
    if "--sec" in args:
        i = args.index("--sec")
        sec = float(args[i + 1])
        del args[i:i + 2]
    for p in args:
        n, total, worst = first(p, sec)
        print("%s\tfirst %gs: hitches %d · %s ms · worst %s ms" % (p.replace("\\", "/").split("/")[-1], sec, n, total, worst))


if __name__ == "__main__":
    main()
