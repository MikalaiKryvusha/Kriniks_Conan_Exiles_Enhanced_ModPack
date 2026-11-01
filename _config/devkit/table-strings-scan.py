# -*- coding: utf-8 -*-
"""table-strings-scan.py — английские фразы в рядах таблиц (DataTable и прочих ассетов с «DT» в имени) ВСЕХ модов сборки.

Зачем (2026-10-27, KUMM план 36 п. 14 = bugs/64 п. 20 «двойники»): строки `StrProperty` в рядах таблиц `.locres` не видит — игрок
видит английский там, где FText уже переведён. Шаг 1 плана — опись: какие моды, какие таблицы, сколько фраз. Перевод — следующим шагом,
правкой ассета (KRINIK MODIFIED, `patch-mod-asset.py build`).

    retoc-5.8 to-legacy --version UE5_7 --no-shaders --filter DT <_paksview-3.0.1> <выгрузка>      # раз, в черновик
    python -I -X utf8 table-strings-scan.py <выгрузка> <опись.tsv>

Фраза = латиница, не меньше двух слов, без кириллицы, не путь и не имя ассета. Печатает сводку по модам; в описи — мод, ассет, вид
свойства, путь ряда, текст. Читает только выгрузку в черновике.
[NOT-TESTED]
"""
import os
import re
import subprocess
import sys

UAJ = r"D:\work\ai_sandbox\_tools\src\uaj\bin\Release\net8.0\uaj.exe"
ENGINE = "VER_UE5_8"
WORDS = re.compile(r"[A-Za-z][A-Za-z']+")
CYRILLIC = re.compile(r"[\u0400-\u04FF]")
NOT_TEXT = re.compile(r"^(/Game/|/Script/|[A-Za-z0-9_]+\.[A-Za-z0-9_]+$)")
# Вид свойства: `Text:Base` — FText с ключом, его переводит .locres (не наш класс); `Str` и `Text:None` (неизменяемый текст без ключа)
# .locres не видит — их и ищем. Первый прогон 2026-10-27: 27 274 `Text:Base` из 29 970 — шум без этого отбора.
KINDS = {"Str", "Text:None"}
# Служебные поля, которых игрок не видит: `AutoDescription` — выражение тегов добычи «ALL( Item.Healing, Loot.T2 )» (≈ 400 рядов NPC);
# `DevComment` — заметка разработчика в ряду (теги построек Шемитов, 32 ряда, 2026-10-27).
SKIP_PATH = re.compile(r"/(AutoDescription|DevComment)$")


def is_phrase(s):
    return not CYRILLIC.search(s) and not NOT_TEXT.search(s) and len(WORDS.findall(s)) >= 2 and " " in s.strip()


def main(root, out):
    rows, per_mod = [], {}
    for dirpath, _, files in os.walk(root):
        rel = dirpath.replace("\\", "/")
        if "/Content/Mods/" not in rel + "/":
            continue
        mod = rel.split("/Content/Mods/", 1)[1].split("/")[0] if "/Content/Mods/" in rel else "?"
        for fn in files:
            if not fn.endswith(".uasset"):
                continue
            r = subprocess.run([UAJ, "strings", os.path.join(dirpath, fn), ENGINE], capture_output=True)
            text = r.stdout.decode("utf-8", "replace")
            for line in text.splitlines():
                parts = line.split("\t", 3)
                if len(parts) == 4 and parts[1] in KINDS and not SKIP_PATH.search(parts[2]) and is_phrase(parts[3]):
                    rows.append((mod, fn[:-7], parts[1], parts[2], parts[3]))
                    per_mod[mod] = per_mod.get(mod, 0) + 1
    rows.sort()
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("mod\tasset\tkind\tpath\ttext\n")
        for r in rows:
            f.write("\t".join(r) + "\n")
    for mod, n in sorted(per_mod.items(), key=lambda x: -x[1]):
        print(f"{n:5d}  {mod}")
    print(f"всего фраз: {len(rows)}, модов: {len(per_mod)}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
