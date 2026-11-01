# bench-report.py — цифры одного облёта KrinikConanBench по CSV PresentMon: к/с, 1 % низких, рывки, худший кадр, видеокарта.
#
# Зачем (2026-10-25, слово владельца «научиться делать бенч - летать камерой по миру, как сделали в Обливионе»): средний FPS
# стоя у Конана упирается в видеокарту (замер 20:32 — 96 %), а то, что игрок чувствует в дороге, — рывки. Мерки — как у
# бенчмарка LTSharpe (KUMM researches/conan-performance-mods-2026-10): рывок — кадр ≥ 50 мс, «1 % низких» — 99-й перцентиль
# времени кадра, худший кадр. Строка JSON дописывается в общий журнал облётов, чтобы «до/после» сравнивались числами.
#
#   python -I -X utf8 bench-report.py <presentmon.csv> <метка> <журнал.jsonl>
# [NOT-TESTED]
import csv
import json
import statistics
import sys

HITCH_MS = 50.0


def main():
    path, label, journal = sys.argv[1:4]
    rows = list(csv.DictReader(open(path, encoding="utf-8", errors="replace")))
    col = "MsBetweenPresents" if "MsBetweenPresents" in rows[0] else "FrameTime"
    ms = [float(r[col]) for r in rows if r.get(col) not in (None, "", "NA")]
    if len(ms) < 30:
        sys.exit("кадров в записи %d — облёт не записан" % len(ms))
    s = sorted(ms)
    p99 = s[int(len(s) * 0.99) - 1]
    hitches = [m for m in ms if m >= HITCH_MS]

    def med(name):
        v = [float(r[name]) for r in rows if r.get(name) not in (None, "", "NA")]
        return round(statistics.median(v), 2) if v else None

    out = {
        "label": label, "frames": len(ms), "seconds": round(sum(ms) / 1000, 1),
        "fps_avg": round(len(ms) / (sum(ms) / 1000), 1), "fps_median": round(1000 / statistics.median(ms), 1),
        "low1_fps": round(1000 / p99, 1), "worst_ms": round(s[-1], 1),
        "hitches": len(hitches), "hitch_ms": round(sum(hitches), 1),
        "gpu_busy_ms": med("MsGPUBusy"), "cpu_busy_ms": med("MsCPUBusy"),
    }
    with open(journal, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(out, ensure_ascii=False) + "\n")
    print(("{label}: {seconds} с, {frames} кадров · к/с {fps_avg} (медиана {fps_median}) · 1 % низких {low1_fps} · "
           "рывков ≥50 мс {hitches} ({hitch_ms} мс) · худший {worst_ms} мс · видеокарта {gpu_busy_ms} мс, процессор {cpu_busy_ms} мс").format(**out))


if __name__ == "__main__":
    main()
