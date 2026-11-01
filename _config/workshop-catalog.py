# -*- coding: utf-8 -*-
"""workshop-catalog.py -- описания и комментарии ВСЕХ модов Мастерской для Conan Exiles Enhanced, локально.

ЗАЧЕМ. Слово владельца 2026-10-25: «всех страниц нужно выкачать описания и комментарии» · «локально» ·
«и по ним будем анализировать - подходит под интересы николая, или нет». Каталог 09.09 (docs/08) снял
только 120 карточек из 1150 и ни одной страницы мода целиком; здесь -- всё, на диск, для разбора.

ОТКУДА.
  * Список id -- _catalog/ids/*.txt: страницы обзора Мастерской, снятые залогиненным Chrome
    (node <KUMM>/kumm.mjs eval ...): гостю обзор отдаёт ноль карточек (docs/08, ловушка 1).
  * Описание, подписчики, избранное, даты, метки, автор -- публичный метод Steam
    ISteamRemoteStorage/GetPublishedFileDetails пачками по 100. Проверено 2026-10-25 на трёх модах:
    отдаёт НАСТОЯЩЕЕ описание (4916 знаков у Exiles Fishing), а не гостевую заглушку страницы (ловушка 7).
  * Комментарии -- тот же адрес, которым страница мода подгружает обсуждение сама:
    /comment/PublishedFile_Public/render/<автор>/<id>/?start=&count= (JSON, без входа; проверено).

ВЕЖЛИВОСТЬ К STEAM. Один запрос за раз, пауза PAUSE_S между запросами, на 429 -- ожидание BACKOFF_S и
повтор. Комментарии -- не больше MAX_COMMENTS самых свежих на мод: для решения «подходит или нет» важны
свежие (совместимость с 3.0, баги), а у популярных модов их тысячи.

ЧЕСТНОСТЬ. У каждого мода три исхода: прочитан / нет комментариев / НЕ ПРОЧЁЛ (сеть, ошибка). Третий
пишется в _catalog/failed.txt и НЕ выдаётся за «комментариев нет» (KUMM EXP-0116). Повторный запуск
дочитывает только недостающее.

    python -I _config/workshop-catalog.py details      # описания всех id -> _catalog/details.json
    python -I _config/workshop-catalog.py comments     # комментарии -> _catalog/comments/<id>.json
    python -I _config/workshop-catalog.py export       # плоский текст для чтения -> _catalog/mods/<id>.txt
[NOT-TESTED]
"""

import glob
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
CAT = os.path.join(os.path.dirname(HERE), "_catalog")
DETAILS = os.path.join(CAT, "details.json")
COMMENTS_DIR = os.path.join(CAT, "comments")
MODS_DIR = os.path.join(CAT, "mods")
FAILED = os.path.join(CAT, "failed.txt")

API = "https://api.steampowered.com/ISteamRemoteStorage/GetPublishedFileDetails/v1/"
COMMENTS = "https://steamcommunity.com/comment/PublishedFile_Public/render/%s/%s/?start=%d&count=%d"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0 Safari/537.36"

BATCH = 100          # id на один запрос описаний
PAGE = 50            # комментариев на один запрос
MAX_COMMENTS = 300   # самых свежих комментариев на мод
PAUSE_S = 1.2        # между запросами к Steam
BACKOFF_S = 60       # после ответа 429
TRIES = 4


def fetch(url, data=None):
    """Тело ответа или None. 429 -- ждать и повторить; прочие сбои -- повтор с паузой."""
    body = urllib.parse.urlencode(data).encode() if data else None
    for attempt in range(TRIES):
        try:
            req = urllib.request.Request(url, data=body, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            wait = BACKOFF_S if e.code == 429 else 5 * (attempt + 1)
            print("  HTTP %d, жду %d с" % (e.code, wait), file=sys.stderr)
            time.sleep(wait)
        except Exception as e:  # сеть, таймаут
            print("  сбой %s, повтор" % e, file=sys.stderr)
            time.sleep(5 * (attempt + 1))
    return None


def all_ids():
    ids = []
    for path in sorted(glob.glob(os.path.join(CAT, "ids", "*.txt"))):
        for line in open(path, encoding="utf-8", errors="replace"):
            m = re.match(r"^(\d{6,})\t", line)
            if m and m.group(1) not in ids:
                ids.append(m.group(1))
    return ids


def note_failed(what):
    with open(FAILED, "a", encoding="utf-8") as fh:
        fh.write(what + "\n")


def cmd_details():
    ids = all_ids()
    have = {}
    if os.path.exists(DETAILS):
        have = {d["publishedfileid"]: d for d in json.load(open(DETAILS, encoding="utf-8"))}
    todo = [i for i in ids if i not in have]
    print("id всего %d, уже есть %d, читать %d" % (len(ids), len(have), len(todo)))
    for k in range(0, len(todo), BATCH):
        part = todo[k:k + BATCH]
        data = {"itemcount": str(len(part))}
        for n, pid in enumerate(part):
            data["publishedfileids[%d]" % n] = pid
        text = fetch(API, data)
        if text is None:
            for pid in part:
                note_failed("details %s" % pid)
            continue
        for item in json.loads(text)["response"].get("publishedfiledetails", []):
            have[item["publishedfileid"]] = item
        json.dump(list(have.values()), open(DETAILS, "w", encoding="utf-8"), ensure_ascii=False)
        print("  описаний %d / %d" % (len(have), len(ids)))
        time.sleep(PAUSE_S)


def parse_comments(html_text):
    """Текст каждого комментария и ближайшие ПЕРЕД ним метка времени и имя автора.
    Оплачено 2026-10-25: первая версия резала html по '<div class="commentthread_comment ', а у внешнего
    блока атрибуты идут в другом порядке -- разобрано 0 из 263, и файлы писались как «прочитано, пусто».
    Якоря теперь те, что стоят у каждого комментария: commentthread_comment_text, data-timestamp, <bdi>."""
    out = []
    for m in re.finditer(r'<div class="commentthread_comment_text"[^>]*>(.*?)</div>', html_text, re.S):
        head = html_text[:m.start()]
        stamps = re.findall(r'data-timestamp="(\d+)"', head[-3000:])
        authors = re.findall(r"<bdi>(.*?)</bdi>", head[-3000:], re.S)
        text = re.sub(r"<br\s*/?>", "\n", m.group(1))
        text = html.unescape(re.sub(r"<[^>]+>", "", text)).strip()
        out.append({"t": int(stamps[-1]) if stamps else 0,
                    "author": html.unescape(authors[-1]).strip() if authors else "",
                    "text": text})
    return out


def cmd_comments():
    os.makedirs(COMMENTS_DIR, exist_ok=True)
    mods = json.load(open(DETAILS, encoding="utf-8"))
    done = 0
    for item in mods:
        pid = item["publishedfileid"]
        out = os.path.join(COMMENTS_DIR, pid + ".json")
        if os.path.exists(out) or item.get("result") != 1:
            continue
        creator = item.get("creator")
        got, total, ok = [], None, True
        while len(got) < MAX_COMMENTS:
            text = fetch(COMMENTS % (creator, pid, len(got), PAGE))
            time.sleep(PAUSE_S)
            if text is None:
                ok = False
                break
            d = json.loads(text)
            if not d.get("success"):
                ok = False
                break
            total = d.get("total_count", 0)
            page = parse_comments(d.get("comments_html", ""))
            got += page
            if not page or len(got) >= total:
                break
        if not ok or (total and not got):
            # «всего N, разобрано 0» -- сбой разбора, а не тишина: в файл как прочитанное не писать
            note_failed("comments %s (total %s, parsed %d)" % (pid, total, len(got)))
            continue
        json.dump({"id": pid, "total": total, "comments": got}, open(out, "w", encoding="utf-8"),
                  ensure_ascii=False)
        done += 1
        if done % 25 == 0:
            print("  комментарии: модов %d" % done)
    print("комментарии: дочитано модов %d" % done)


def bb_to_text(s):
    s = re.sub(r"\[url=([^\]]+)\](.*?)\[/url\]", r"\2 (\1)", s, flags=re.S)
    s = re.sub(r"\[img\].*?\[/img\]", "", s, flags=re.S)
    s = re.sub(r"\[/?[a-z0-9*]+(?:=[^\]]*)?\]", "", s)
    return s.strip()


def cmd_export():
    os.makedirs(MODS_DIR, exist_ok=True)
    mods = json.load(open(DETAILS, encoding="utf-8"))
    for item in mods:
        if item.get("result") != 1:
            continue
        pid = item["publishedfileid"]
        cpath = os.path.join(COMMENTS_DIR, pid + ".json")
        comments = json.load(open(cpath, encoding="utf-8")) if os.path.exists(cpath) else None
        lines = [
            "# %s" % item.get("title", ""),
            "id %s · подписчиков %s · в избранном %s · обновлён %s · размер %.1f МБ · метки %s" % (
                pid, item.get("subscriptions"), item.get("favorited"),
                time.strftime("%Y-%m-%d", time.localtime(item.get("time_updated", 0))),
                int(item.get("file_size") or 0) / 1e6, ", ".join(t["tag"] for t in item.get("tags", []))),
            "https://steamcommunity.com/sharedfiles/filedetails/?id=%s" % pid,
            "",
            "## Описание",
            bb_to_text(item.get("description", "")),
            "",
        ]
        if comments is None:
            lines.append("## Комментарии: НЕ ПРОЧИТАНЫ")
        else:
            lines.append("## Комментарии: %d из %s (свежие сверху)" % (len(comments["comments"]), comments["total"]))
            for c in comments["comments"]:
                lines.append("- %s · %s" % (time.strftime("%Y-%m-%d", time.localtime(c["t"])), c["text"].replace("\n", " ")))
        open(os.path.join(MODS_DIR, pid + ".txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("выгружено: %d" % len(os.listdir(MODS_DIR)))


if __name__ == "__main__":
    {"details": cmd_details, "comments": cmd_comments, "export": cmd_export}[sys.argv[1]]()
