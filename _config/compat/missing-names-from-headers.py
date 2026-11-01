# -*- coding: utf-8 -*-
"""missing-names-from-headers.py — имена недостающих пакетов по заголовкам самих модов (.uheader хранит имена импортируемых пакетов).

Зачем (2026-10-26): журнал называет недостающий пакет только номером (`dependent package None (D95579806935559B)`), кит 2.2 знает
лишь ванильные имена 2.2 — 43 из 129 номеров остались без имени. Но заголовок zen-пакета мода перечисляет пути всех пакетов, которые он
импортирует; хеш каждого пути (`_config/devkit/package-id.py`) сверяется с номерами журнала — так нашлась таблица
`/Game/ModsShared/SudoExile/TotCustom/Tables/Tot_DT_Hairline_Male`, которой не хватает DeaHair.

    python -I -X utf8 missing-names-from-headers.py <номера.txt> <папка с распакованными .uheader…>  > names-from-headers.tsv

Распаковка заголовков: `UnrealPak <ExtractedMods>/<Мод>-Windows.utoc -Extract <папка в черновике> -Filter=*.uheader` (папку игры только читать).
[NOT-TESTED]
"""
import importlib.util, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("pid", os.path.join(HERE, "..", "devkit", "package-id.py"))
P = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(P)

# Путь пакета в заголовке склеен с соседними именами без разделителя: режем по началу следующего корня.
ROOTS = rb"/(?:Game|Engine|Script|Niagara|Landmass|Paper2D|[A-Z][A-Za-z0-9_]+)/"


def candidates(blob):
    for run in re.findall(rb"[ -~]{6,}", blob):
        for part in re.split(rb"(?=/Game/|/Engine/)", run):
            m = re.match(rb"(/(?:Game|Engine)/[A-Za-z0-9_/\-\.]+)", part)
            if m:
                p = m.group(1).split(b".")[0]
                # хвост может прилипнуть к следующему имени из таблицы имён — пробуем все префиксы по границам сегментов не нужно:
                yield p.decode()


def main():
    ids = {l.strip().upper() for l in open(sys.argv[1]) if l.strip()}
    found = {}
    for root in sys.argv[2:]:
        for dp, _, fn in os.walk(root):
            for f in fn:
                if not f.endswith(".uheader"):
                    continue
                path = os.path.join(dp, f)
                blob = open(path, "rb").read()
                for c in set(candidates(blob)):
                    # имя пакета может склеиться с именем следующего пакета без «/»; проверяем и укороченные варианты
                    segs = c.split("/")
                    for k in range(len(segs), 2, -1):
                        name = "/".join(segs[:k])
                        h = "%016X" % P.pkgid(name)
                        if h in ids:
                            found.setdefault(h, (name, set()))[1].add(os.path.relpath(path, root))
    print("named %d of %d" % (len(found), len(ids)), file=sys.stderr)
    for h in sorted(found):
        name, refs = found[h]
        print("%s\t%s\t%s" % (h, name, ", ".join(sorted(refs))[:300]))


if __name__ == "__main__":
    main()
