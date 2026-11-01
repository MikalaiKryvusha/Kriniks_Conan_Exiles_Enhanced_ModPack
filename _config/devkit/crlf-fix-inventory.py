# Возвращает в описи all-mods-ftext.csv настоящий перевод строки \r\n тем исходникам, у которых в ассете \r\n, а в описи \n\n
# (сканер байткода превращал CRLF в два LF; хэш исходника в .locres не совпадал, игра выбрасывала перевод — KUMM bugs/64 п. 7b).
# Таблицу перевода НЕ трогает: сшивщик hosav-ru-entries.py находит такой исходник по варианту «\r\n → \n\n» и ставит \r\n
# в русскую строку (2026-10-26: правка одной описи без сшивщика потеряла 27 переводов).
# Выбор строк — тот же, что у crlf-scan.py (все одноимённые файлы, UTF-8 и UTF-16LE). Копия описи — рядом, .bak-crlf.
import csv, os, shutil, importlib.util
spec = importlib.util.spec_from_file_location("crlf_scan", os.path.join(os.path.dirname(os.path.abspath(__file__)), "crlf-scan.py"))
cs = importlib.util.module_from_spec(spec); spec.loader.exec_module(cs)

raw = open(cs.CSV, "rb").read()
term = "\r\n" if raw.split(b"\n", 1)[0].endswith(b"\r") else "\n"   # концы строк файла сохраняются как были
shutil.copy2(cs.CSV, cs.CSV + ".bak-crlf")
rows = list(csv.reader(open(cs.CSV, encoding="utf-8", newline="")))
idx = cs.index_files()
fixed = []
for r in rows[1:]:
    if len(r) > 3 and "\n\n" in r[3]:
        paths = idx.get(os.path.basename(r[0]))
        if paths and cs.classify_any(r[3], paths) == "crlf":
            r[3] = r[3].replace("\n\n", "\r\n")
            fixed.append(r[2])
with open(cs.CSV, "w", encoding="utf-8", newline="") as f:
    csv.writer(f, lineterminator=term).writerows(rows)
print("fixed", len(fixed), "Entropic C0CC26C9 among them:", "C0CC26C940083BD9FF366FB7B179339B" in fixed)
