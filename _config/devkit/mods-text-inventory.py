# mods-text-inventory.py — опись текстов модов сборки: что у каждого мода надо перевести, что уже переведено, нет ли своего русского.
#
# Зачем (2026-10-25 вечер, слово владельца «переводить моды на русский»): перевод шёл по модам, которые приходили в сборку партиями
# (рыбалка, 13 модов Мастерской, Era of Trials, QoL), а моды выбора 09.09 — Simple Minimap, Proximity Party, EAA, Emberlight и
# остальные — в рабочий список так и не попали: их английский владелец видел в игре (кадр RU1 — подсказка миникарты). Прибор
# проходит ВЕСЬ манифест, а не партию: для каждого включённого пака Мастерской — распаковка (repak → внутренний utoc → китовый
# UnrealPak -Extract без .ubulk), ключи FText (`KUMM/researches/conan-devkit/ftext_extract.py`), и счёт по форме extend-worklist.py:
# сколько строк настоящих, сколько из них уже есть в рабочем списке перевода. Свой русский — по именам ассетов (`_ru`, `/ru/`).
#
#   python -I -X utf8 mods-text-inventory.py <пак> <рабочая папка> <опись.tsv> [id,id,...]
#   В рабочей папке остаются <id>/x (распаковка) и <id>.csv — его и отдают extend-worklist.py: <метка>=<рабочая>/<id>.csv.
#   Повторный прогон берёт готовые <id>.csv (распаковку не повторяет); удалить csv — распаковать заново.
# [NOT-TESTED]
import csv
import importlib.util
import json
import os
import re
import subprocess
import sys

REPAK = r"D:\work\ai_sandbox\_tools\repak\repak.exe"
KIT_UNREALPAK = r"F:\CEUE5Devkit\Engine\Binaries\Win64\UnrealPak.exe"   # новый кит 2026-10-25; только чтение контейнеров
FTEXT = r"D:\work\ai_sandbox\KUMM\researches\conan-devkit\ftext_extract.py"
WORKLIST = os.path.join(os.path.dirname(__file__), "..", "localization", "dm-fish-worklist.tsv")
OWN_RU = re.compile(r'(_ru\b|/ru/|_RU\b|Russian)', re.I)

# Отсев мусора — тот же, что в extend-worklist.py: одна мерка, иначе опись и список разойдутся в счёте.
spec = importlib.util.spec_from_file_location("ew", os.path.join(os.path.dirname(__file__), "extend-worklist.py"))
ew = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ew)


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError("%s → код %d: %s" % (os.path.basename(args[0]), r.returncode, (r.stderr or r.stdout)[-400:]))
    return r.stdout


def extract(pak, work):
    """pak мода → <work>/x с .uasset/.uexp/.uheader; список имён распакованного."""
    outer = os.path.join(work, "outer")
    x = os.path.join(work, "x")
    run([REPAK, "unpack", "-q", "-f", "-s", "../../../ConanSandbox/Mods/", "-o", outer, pak])
    utocs = [f for f in os.listdir(outer) if f.endswith("-Windows.utoc")]
    if not utocs:
        return []
    for u in utocs:
        run([KIT_UNREALPAK, os.path.join(outer, u), "-Extract", x, "-Filter=*.uasset"])
    names = []
    for d, _, fs in os.walk(x):
        names += [os.path.relpath(os.path.join(d, f), x).replace("\\", "/") for f in fs]
    return names


def main():
    pack, workroot, out = sys.argv[1:4]
    only = set(sys.argv[4].split(",")) if len(sys.argv) > 4 else None
    m = json.load(open(os.path.join(pack, "modpack.json"), encoding="utf-8"))
    lib = m["library"]
    known = {l.rstrip("\r\n").split("\t")[3] for l in open(WORKLIST, encoding="utf-8") if l.strip()}
    rows = []
    for mod in m["mods"]:
        if not mod.get("enabled", True) or mod.get("kind") != "pak" or "workshopId" not in mod:
            continue
        wid = str(mod["workshopId"])
        if only and wid not in only:
            continue
        folder = os.path.join(lib, mod["source"]["folder"])
        paks = [f for f in os.listdir(folder) if f.endswith(".pak")]
        work = os.path.join(workroot, wid)
        csv_path = os.path.join(workroot, wid + ".csv")
        own = ""
        try:
            if not os.path.exists(csv_path):
                os.makedirs(work, exist_ok=True)
                names = []
                for p in paks:
                    names += extract(os.path.join(folder, p), work)
                own = ";".join(n for n in names if OWN_RU.search(n))[:200]
                open(os.path.join(work, "own-ru.txt"), "w", encoding="utf-8").write(own)
                run([sys.executable, "-I", "-X", "utf8", FTEXT, os.path.join(work, "x"), csv_path])
            else:
                f = os.path.join(work, "own-ru.txt")
                own = open(f, encoding="utf-8").read() if os.path.exists(f) else "?"
        except Exception as e:   # мод без IoStore или сбой распаковки — строкой описи, а не обрывом прохода по всей сборке
            rows.append((wid, mod["name"], "ОШИБКА", "", "", str(e)[:200]))
            print("ОШИБКА", wid, mod["name"], str(e)[:200])
            continue
        texts = set()
        if os.path.exists(csv_path):
            for r in csv.DictReader(open(csv_path, encoding="utf-8", newline="")):
                s = r["source"].replace("\r\n", "\n")
                if not ew.junk(s):
                    texts.add(s.replace("\n", "\\n"))
        done = len(texts & known)
        rows.append((wid, mod["name"], str(len(texts)), str(done), str(len(texts) - done), own))
        print("%s\t%-34s строк %5d · в списке %5d · новых %5d %s" % (wid, mod["name"], len(texts), done, len(texts) - done,
                                                                    ("· свой RU: " + own[:60]) if own else ""))
    with open(out, "w", encoding="utf-8", newline="") as fh:
        fh.write("id\tмод\tстрок\tв списке\tновых\tсвой русский\n")
        fh.write("".join("\t".join(r) + "\n" for r in rows))


if __name__ == "__main__":
    main()
