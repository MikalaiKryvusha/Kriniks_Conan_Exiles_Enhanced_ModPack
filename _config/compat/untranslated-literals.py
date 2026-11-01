# -*- coding: utf-8 -*-
"""untranslated-literals.py — английские фразы в файлах модов, которых нет среди FText (а значит, `.locres` их не переведёт).

Зачем (2026-10-26, KUMM bugs/64, п. 7): подсказки школ магии Era of Trials («Entropic magic is dark, deceitful, and unfair.», «You have {0}
Entropic Amp…») — строки-литералы в байткоде виджета `EoT_W_CharInfoMagicDisplay`, а не FText; опись `all-mods-ftext.csv` их не видит, и
владелец нашёл их глазом за пять минут. Это класс бага 28 Сварога: «строки кода вне всех словарей». Скан закрывает класс сразу по всем модам.

Как: в каждом распакованном .uexp — ASCII- и UTF-16-строки, похожие на фразу для игрока (≥ 3 слов, есть пробелы, нет путей и
служебных имён) → вычитаются исходные строки FText из `all-mods-ftext.csv` → остаток по модам и ассетам.

    python -I -X utf8 untranslated-literals.py <папка распаковки модов> [all-mods-ftext.csv] > literals.tsv
Строка вывода: мод · ассет · фраза. В stderr — счёт по модам.
[NOT-TESTED]
"""
import collections, csv, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASCII_RX = re.compile(rb"[\x20-\x7e]{12,}")
UTF16_RX = re.compile(rb"(?:[\x20-\x7e]\x00){12,}")
WORD_RX = re.compile(r"[A-Za-z]{2,}")


def phrase_like(s):
    s = s.strip()
    if len(s) < 12 or " " not in s:
        return False
    if re.search(r"[/\\]|::|\.uasset|\.uexp|_C\b|^\w+_\w+$|Default__|WidgetTree|K2Node|ExecuteUbergraph", s):
        return False
    if len(WORD_RX.findall(s)) < 3:
        return False
    letters = sum(c.isalpha() for c in s)
    return letters >= 0.6 * len(s.replace(" ", ""))


UI_ASSET_RX = re.compile(r"^(W_|WBP_|UI_)|_UI_|_W_|Widget|Tooltip|Menu|HUD|Panel", re.I)
SHORT_RX = re.compile(r"^[A-Za-z][A-Za-z'&+\-]*(?:[ .:·!?/][A-Za-z'&+\-·:!?.]*)*[.:!?]?$")


def short_label(s):
    """Короткая подпись интерфейса: «FISHING», «Apply», «Show coordinates» — то, что длинный фильтр пропускал
    (владелец 2026-10-26: «FISHING · ADMIN» не переведено). Отсев служебных имён: CamelCase внутри слова, подчёркивания, цифры."""
    s = s.strip()
    if len(s) < 3 or len(s) > 60 or "_" in s or any(c.isdigit() for c in s):
        return False
    if not SHORT_RX.match(s):
        return False
    words = re.findall(r"[A-Za-z]+", s)
    if not words or max(len(w) for w in words) < 3:
        return False
    for w in words:
        if re.search(r"[a-z][A-Z]", w):        # ButtonStyle, WidgetTree — имена движка
            return False
    return True


def main():
    root = sys.argv[1]
    csv_path = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "localization", "all-mods-ftext.csv")
    known = set()
    with open(csv_path, encoding="utf-8", newline="") as f:
        for row in csv.reader(f):
            if len(row) >= 4:
                known.add(row[3].strip())
    # \n внутри FText и перевод строки в файле режут фразу на куски: кусок известной строки — не находка
    blob_known = "\x00".join(k.replace("\\n", "\n") for k in known)
    per_mod = collections.Counter()
    out = set()
    for mod in sorted(os.listdir(root)):
        mdir = os.path.join(root, mod)
        if not os.path.isdir(mdir):
            continue
        for dp, _, fn in os.walk(mdir):
            for name in fn:
                if not name.endswith(".uexp"):
                    continue
                blob = open(os.path.join(dp, name), "rb").read()
                ui = bool(UI_ASSET_RX.search(name))
                lo = 3 if ui else 12                      # в файлах интерфейса — и короткие подписи
                found = [m.group().decode("ascii") for m in re.finditer(rb"[\x20-\x7e]{%d,}" % lo, blob)]
                found += [m.group().decode("utf-16-le") for m in re.finditer(rb"(?:[\x20-\x7e]\x00){%d,}" % lo, blob)]
                for s in found:
                    s = s.strip()
                    ok = phrase_like(s) or (ui and short_label(s))
                    if ok and s not in known and s not in blob_known:
                        key = (mod, name[:-5], s)
                        if key not in out:
                            out.add(key)
                            per_mod[mod] += 1
    for mod, asset, s in sorted(out):
        print("%s\t%s\t%s" % (mod, asset, s))
    for mod, n in per_mod.most_common():
        print("%5d  %s" % (n, mod), file=sys.stderr)
    print("всего: %d фраз вне FText в %d модах" % (len(out), len(per_mod)), file=sys.stderr)


if __name__ == "__main__":
    main()
