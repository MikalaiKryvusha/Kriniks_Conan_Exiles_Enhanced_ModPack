# ru-rows-replace.py <dm-fish-ru.tsv> <replacements.tsv> — заменить русские строки перевода по номеру ряда («N\tрусский»), остальное — байт в байт.
# Зачем (2026-10-26, KUMM bugs/64 п. 21–24): наши переводы длиннее английских и вылезают из кнопок и окон модов (EAA, Simple Minimap);
# правка — короче по смыслу, пачкой, без ручного поиска по файлу на 23 тыс. строк. Печатает «N: было → стало»; номер, которого нет, — остановка.
# [NOT-TESTED]
import sys

path, repl_path = sys.argv[1], sys.argv[2]
repl = {}
for line in open(repl_path, encoding="utf-8").read().splitlines():
    if line.strip():
        n, ru = line.split("\t", 1)
        repl[n] = ru
raw = open(path, "rb").read().decode("utf-8")
nl = "\r\n" if "\r\n" in raw else "\n"
rows = raw.split(nl)
seen = set()
for i, r in enumerate(rows):
    n = r.split("\t", 1)[0]
    if n in repl and "\t" in r:
        old = r.split("\t", 1)[1]
        rows[i] = n + "\t" + repl[n]
        seen.add(n)
        print(f"{n}: {old} → {repl[n]}")
missing = set(repl) - seen
if missing:
    sys.exit(f"нет рядов: {sorted(missing)} — ничего не записано")
open(path, "wb").write(nl.join(rows).encode("utf-8"))
print("заменено", len(seen))
