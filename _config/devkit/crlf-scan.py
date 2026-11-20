# Строки описи all-mods-ftext.csv с \n в исходнике: сверка с байтами ассета — как в описи, или в ассете \r\n вместо \n\n.
# Ассет хранит строку в UTF-8 (только ASCII) или в UTF-16LE (есть хоть один не-ASCII символ: ’, —, …) — сверяются обе формы;
# до 2026-10-26 вечера сканер искал только UTF-8, и 550 строк числились «не сверить» (KUMM bugs/64 п. 7b).
# Выход: счётчики по видам; --list печатает ключи вида «crlf» и «none». Код 1 — есть исходники вида «crlf» (опись врёт байтам).
import csv, os, sys, collections
ROOT = r"D:\work\ai_sandbox\ConanExiles\_library\_text-extract-3.0.1"
CSV = r"D:\work\ai_sandbox\ConanExiles\_config\localization\all-mods-ftext.csv"

def forms(s):
    return [s.encode("utf-8"), s.encode("utf-16-le")]

def classify(src, b):
    """as is · crlf (в ассете \r\n вместо \n\n) · none."""
    if any(f in b for f in forms(src)):
        return "as is"
    if "\n\n" in src and any(f in b for f in forms(src.replace("\n\n", "\r\n"))):
        return "crlf"
    return "none"

def index_files():
    """имя файла → ВСЕ пути: у разных модов бывают одноимённые ассеты (dt_Ma_Table.uexp — у двух), и первый попавшийся
    путь давал 15 ложных «не найдено» (2026-10-26)."""
    idx = collections.defaultdict(list)
    for d in os.listdir(ROOT):
        for dp, _, fs in os.walk(os.path.join(ROOT, d, "x")):
            for f in fs:
                idx[f].append(os.path.join(dp, f))
    return idx

def classify_any(src, paths):
    kinds = [classify(src, open(p, "rb").read()) for p in paths]
    return "as is" if "as is" in kinds else "crlf" if "crlf" in kinds else "none"

if __name__ == "__main__":
    rows = list(csv.reader(open(CSV, encoding="utf-8", newline="")))
    multi = [r for r in rows[1:] if len(r) > 3 and "\n" in r[3]]
    print("rows", len(rows) - 1, "multi-line sources", len(multi))
    idx = index_files()
    stat, keys = collections.Counter(), collections.defaultdict(list)
    for r in multi:
        paths = idx.get(os.path.basename(r[0]))
        if not paths:
            stat["no file"] += 1; continue
        k = classify_any(r[3], paths)
        if k == "none" and chr(0) in r[3]:
            k = "binary"   # обрывок двоичных данных, принятый разборщиком за строку, — не текст игрока
        stat[k] += 1; keys[k].append(r[2])
    print(dict(stat))
    if "--list" in sys.argv:
        for k in ("crlf", "none"):
            print(k, len(keys[k]), " ".join(keys[k][:40]))
    sys.exit(1 if stat["crlf"] else 0)
