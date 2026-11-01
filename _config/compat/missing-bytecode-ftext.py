# -*- coding: utf-8 -*-
"""missing-bytecode-ftext.py — локализуемые тексты из байткода (EX_TextConst, тип LocalizedText), которых нет в описи all-mods-ftext.csv.

Зачем (2026-10-26, KUMM bugs/64 п. 7): подсказки школ магии Era of Trials («Entropic magic is dark…») — FText С КЛЮЧОМ внутри байткода
функции Get_I_Entropic_1_ToolTipWidget: `29 01 1F <источник>\0 1F <ключ>\0 1F <пространство>\0`. .locres переведёт их по ключу, но опись их
не собрала (многострочные источники), и владелец увидел английский. Скан находит все такие тексты во всех модах — переводить .locres, без
правки ассетов.

    python -I -X utf8 missing-bytecode-ftext.py <папка распаковки модов> [all-mods-ftext.csv] > missing.csv
Вывод — строки в формате описи (file,namespace,key,source) для дописывания в all-mods-ftext.csv; в stderr — счёт по модам.
[NOT-TESTED]
"""
import collections, csv, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
RX = re.compile(rb"\x29\x01\x1f([^\x00]{1,4000})\x00\x1f([0-9A-F]{32})\x00\x1f([^\x00]{0,200})\x00")
# UTF-16 источник: EX_UnicodeStringConst (0x34) вместо 0x1F
RXU = re.compile(rb"\x29\x01\x34((?:[^\x00].|.[^\x00]){1,4000}?)\x00\x00\x1f([0-9A-F]{32})\x00\x1f([^\x00]{0,200})\x00", re.S)
TAIL = re.compile(rb"\x1f([0-9A-F]{32})\x00\x1f([^\x00]{0,200})\x00")


def utf16_hits(blob):
    """EX_TextConst с UTF-16 источником (EX_UnicodeStringConst 0x34) — тот же текст, что RXU, но разбором от каждого маркера, без регулярки
    по всему файлу. Зачем (2026-10-30, KUMM план 36 W18): RXU с ленивым повтором не уложился в 15 мин на 12 ГБ и был выключен 26.10 — все тексты
    модов с не-ASCII знаком (•, «», —) выпали из описи, и владелец увидел английскую подсказку рыбалки «Profile slot: … A dot (•) marks …».
    [NOT-TESTED]"""
    out = []
    i = blob.find(b"\x29\x01\x34")
    while i >= 0:
        j = i + 3
        end = -1
        while j + 1 < len(blob) and j - i < 8003:          # источник до 4000 знаков
            if blob[j] == 0 and blob[j + 1] == 0:
                end = j
                break
            j += 2
        if end > i + 3:
            m = TAIL.match(blob, end + 2)
            if m:
                out.append((blob[i + 3:end].decode("utf-16-le", "replace"), m.group(1).decode(), m.group(2).decode("latin1")))
        i = blob.find(b"\x29\x01\x34", i + 3)
    return out


def main():
    root = sys.argv[1]
    csv_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "localization", "all-mods-ftext.csv")
    known = set()
    with open(csv_path, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            if len(row) >= 3:
                known.add(row[2])
    out = csv.writer(sys.stdout, lineterminator="\n")
    per_mod = collections.Counter()
    seen = set()
    for mod in sorted(os.listdir(root)):
        mdir = os.path.join(root, mod)
        if not os.path.isdir(mdir):
            continue
        for dp, _, fn in os.walk(mdir):
            for name in fn:
                if not name.endswith(".uexp"):
                    continue
                path = os.path.join(dp, name)
                blob = open(path, "rb").read()
                rel = os.path.relpath(path, mdir).replace("\\", "/")
                if b"\x29\x01\x1f" not in blob and b"\x29\x01\x34" not in blob:
                    continue
                # UTF-16 — разбором от маркера (utf16_hits), не регуляркой RXU: та не уложилась в 15 мин на 12 ГБ (2026-10-26) и была выключена
                hits = [(m.group(1).decode("latin1"), m.group(2).decode(), m.group(3).decode("latin1")) for m in RX.finditer(blob)]
                hits += utf16_hits(blob)
                for src, key, ns in hits:
                    if key in known or key in seen or not re.search("[A-Za-z]{2}", src):
                        continue
                    seen.add(key)
                    per_mod[mod] += 1
                    out.writerow([rel, ns, key, src])
    for mod, n in per_mod.most_common():
        print("%5d  %s" % (n, mod), file=sys.stderr)
    print("всего ключей вне описи: %d" % len(seen), file=sys.stderr)


if __name__ == "__main__":
    main()
