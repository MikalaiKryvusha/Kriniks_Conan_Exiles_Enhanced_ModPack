# -*- coding: utf-8 -*-
"""workshop-shortlist.py -- первый отсев каталога Мастерской под «игру мечты» Николая.

ЗАЧЕМ. 1 348 модов Enhanced глазами не перечитать. Код делает механическую часть: по словам в названии и
описании отмечает, какие критерии игры мечты мод может закрывать, и отсекает заведомо мёртвое (не
обновлялся с выхода 2.2.0 -- значит, сварен под 5.6 и 3.0.1 его не примет). Решает НЕ код: он только
поднимает кандидатов наверх, суждение -- чтение описания и комментариев.

Критерии -- Game_Of_Dream/game_of_the_dream_requirements.md (слово владельца):
  world    большой открытый мир (новые земли, подземелья, исследование)
  growth   бесконечная skill-based прокачка (уровни, атрибуты, навыки без потолка)
  life     симуляция мира: NPC живут сами, ходят, торгуют, воюют
  events   случайные события, «всё время что-то новенькое»
  loot     лут со случайными характеристиками (аффиксы, редкость, самоцветы)
Независимость от серверов -- отдельная пометка: «нужен Tot ! Custom / только сервер» = минус.

    python -I _config/workshop-shortlist.py            # -> _catalog/shortlist.tsv
[NOT-TESTED]
"""

import json
import os
import re
import time

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.dirname(HERE)
CAT = os.path.join(PACK, "_catalog")

# Выход патча 2.2.0 (UE 5.8): что не обновлялось с тех пор -- сварено под 5.6, игра 3.0.1 не примет.
ALIVE_SINCE = time.mktime((2026, 9, 15, 0, 0, 0, 0, 0, -1))

CRITERIA = {
    "world": r"\bnew (map|land|region|area|island|biome|dungeon|zone)s?\b|\bexplor\w*|\bdungeon|\bcave|\bruins?\b|\bpoi\b|points? of interest|\bworld map",
    "growth": r"\buncap\w*|\blevel ?cap|\bmax level|\b(1000|500|300|200|10000) levels?|\bprogression|\battribute|\bskill tree|\bperk|\bexperience|\bxp\b|\bmastery|\bleveling|\bprestige|\bparagon",
    "life": r"\bnpc|\bpatrol|\bcaravan|\btraveler|\bmerchant|\btrader|\bsettlement|\bvillage|\btown|\broam|\bwander|\bfaction|\bliving\b|\bsimulat\w*|\bcamp(s)?\b|\bbandits?|\bguards?\b|\bcitizens?|\bdaily routine",
    "events": r"\bevents?\b|\brandom\w*|\binvasion|\bpurge|\braid|\bencounter|\bworld boss|\bbount(y|ies)|\bquests?\b|\bdynamic|\bambush|\bstorm|\bsiege",
    "loot": r"\bloot|\baffix\w*|\brarit(y|ies)|\blegendar\w*|\benchant\w*|\brunes?\b|\bgems?\b|\bsocket|\brandom stats?|\broll(s|ed)? stats|\bunique items?|\bset items?|\bdrops?\b",
}
SERVER_ONLY = r"tot ?! ?custom|dedicated server only|server only|not (work|compatible) (in|with) single ?player|single ?player (is )?not supported"


def in_build():
    data = json.load(open(os.path.join(PACK, "modpack.json"), encoding="utf-8"))
    ids = set()
    for m in data["mods"]:
        if m.get("workshopId"):
            ids.add(str(m["workshopId"]))
    return ids


def main():
    mods = json.load(open(os.path.join(CAT, "details.json"), encoding="utf-8"))
    have = in_build()
    rows = []
    for d in mods:
        if d.get("result") != 1:
            continue
        text = (d.get("title", "") + "\n" + d.get("description", "")).lower()
        hits = [k for k, rx in CRITERIA.items() if re.search(rx, text)]
        rows.append({
            "id": d["publishedfileid"],
            "title": d.get("title", "").replace("\t", " "),
            "subs": int(d.get("subscriptions") or 0),
            "fav": int(d.get("favorited") or 0),
            "updated": d.get("time_updated", 0),
            "alive": d.get("time_updated", 0) >= ALIVE_SINCE,
            "in_build": d["publishedfileid"] in have,
            "server_only": bool(re.search(SERVER_ONLY, text)),
            "hits": hits,
            "tags": ",".join(t["tag"] for t in d.get("tags", [])),
            "desc_len": len(d.get("description", "")),
        })
    rows.sort(key=lambda r: (-len(r["hits"]), -r["subs"]))
    out = os.path.join(CAT, "shortlist.tsv")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("id\ttitle\tsubs\tfav\tupdated\talive\tin_build\tserver_only\tcriteria\ttags\n")
        for r in rows:
            fh.write("%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n" % (
                r["id"], r["title"], r["subs"], r["fav"], time.strftime("%Y-%m-%d", time.localtime(r["updated"])),
                int(r["alive"]), int(r["in_build"]), int(r["server_only"]), ",".join(r["hits"]), r["tags"]))
    alive = [r for r in rows if r["alive"]]
    print("модов %d, живых (обновлены после 2.2.0) %d, в сборке %d, только сервер %d" % (
        len(rows), len(alive), sum(r["in_build"] for r in rows), sum(r["server_only"] for r in rows)))
    for k in CRITERIA:
        print("  %-7s живых с признаком: %d" % (k, sum(1 for r in alive if k in r["hits"])))
    print("->", out)


if __name__ == "__main__":
    main()
