# -*- coding: utf-8 -*-
"""check-mod-updates.py -- готовы ли моды сборки к новой версии игры.

ЗАЧЕМ. После патча игры (2.2.0 от 15.09.2026, UE 5.8.2) паки, сваренные под
прежний движок, игра не принимает: "Mod is too old and needs to be updated for
this game version". Вопрос владельца звучит так: "ждать неделю или ставить уже
сейчас?" -- и отвечается он не чтением форумов, а датой последней публикации
каждого мода сборки. Прибор спрашивает эти даты у Steam и Nexus и печатает,
кто готов, а кто ещё нет.

ОТКУДА ДАТЫ.
  * Мастерская Steam -- публичный анонимный метод ISteamRemoteStorage/
    GetPublishedFileDetails, поле time_updated. Ключ не нужен, все id одним
    запросом. result=9 в ответе значит, что мода в Мастерской БОЛЬШЕ НЕТ
    (удалён или спрятан автором) -- он не обновится никогда.
  * Nexus -- у страницы мода в блоке "File information" лежит
    <time data-date="<unix>"> сразу после заголовка "Last updated". Публичного
    API без ключа нет, поэтому читается страница. Nexus отдаёт 403 без
    User-Agent браузера и придерживает при частых запросах, отсюда UA и
    повторы.
    С 2026-10-02 этого мало: Nexus закрыт Cloudflare для ЛЮБОГО curl (Git и
    System32 -- оба 403, тело -- заставка "Just a moment..."; KUMM bugs/13).
    Прибор честно печатает "НЕ ПРОЧЁЛ" для модов Nexus; даты Nexus берутся
    движком KUMM через живой Chrome: node <KUMM>/kumm.mjs check --root <этот пак>.
    Steam прибор читает по-прежнему.

ПОЧЕМУ NEXUS ЧИТАЕТСЯ ЧЕРЕЗ curl, А STEAM -- ЧЕРЕЗ urllib. Оплачено 18.09.2026:
urllib на страницу Nexus падает с CERTIFICATE_VERIFY_FAILED "certificate has
expired" -- в связке сертификатов Python корень для цепочки Nexus протух. curl
берёт хранилище Windows и ходит нормально. Проверку сертификата НЕ отключать:
дело чинится сменой транспорта, а не снятием защиты.

ЧЕСТНОСТЬ ОТВЕТА. Неудача чтения печатается как "НЕ ПРОЧЁЛ", а не как "ЖДЁМ".
Первая версия прибора валила их в одну кучу и молча записала пять готовых модов
в неготовые -- отчёт, который выглядит как вывод, но им не является.

ВРЕМЯ -- МЕСТНОЕ. Обе службы отдают unix-время, прибор печатает его в часовом
поясе машины. Сравнивая с датами из форумов или из чужого отчёта в UTC, жди
расхождения на сутки у модов, выложенных поздно вечером.

ГРАНИЦА. Прибор отвечает, ПЕРЕВЫЛОЖИЛ ли автор мод после патча. Он НЕ
отвечает, работает ли мод: это проверяется только запуском игры. Свежая дата --
необходимое условие, а не достаточное.

    python check-mod-updates.py                      # порог -- выход 2.2.0
    python check-mod-updates.py --since 2026-09-20   # свой порог
    python check-mod-updates.py --all                # и выключенные тоже
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(os.path.dirname(HERE), "modpack.json")

# Выход патча 2.2.0 -- порог по умолчанию.
DEFAULT_SINCE = "2026-09-15"

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36")

STEAM_API = ("https://api.steampowered.com/ISteamRemoteStorage/"
             "GetPublishedFileDetails/v1/")
NEXUS_GAME = "conanexilesenhanced"

# curl ПО ЯВНОМУ ПУТИ. Оплачено 25.09.2026 (баг 13 KUMM, EXP-0123): на Windows
# CreateProcess ищет голое имя в System32 РАНЬШЕ, чем в PATH, и из Python
# приходил C:\Windows\System32\curl.exe -- ему Nexus отвечает 403. Git curl
# страницу получает. shutil.which тут не помощник: он читает PATH и показывает
# Git curl, а запускается всё равно системный. Взятый путь печатается в шапке,
# чтобы следующая смена транспорта была видна сразу.
CURL_CANDIDATES = (
    r"C:\Program Files\Git\mingw64\bin\curl.exe",
    r"C:\Program Files (x86)\Git\mingw64\bin\curl.exe",
)
CURL = next((p for p in CURL_CANDIDATES if os.path.isfile(p)), "curl")

# Копии авторов, из которых `devkit/patch-mod-asset.py` собирает наши правленые паки.
ORIGINALS = r"D:\work\ai_sandbox\ConanExiles\_library\_patch-originals"


def load_mods(include_disabled):
    with open(MANIFEST, encoding="utf-8") as fh:
        data = json.load(fh)
    out = []
    for mod in data["mods"]:
        if not include_disabled and not mod.get("enabled", True):
            continue
        out.append(mod)
    return out


def workshop_id(mod):
    # Оплачено 2026-11-13 (переезд на 3.1.0): прибор брал id только из папки
    # `_workshop/<id>` и молча пропускал 21 мод Мастерской, который мы правили
    # сами (`_krinik-modified/<id>`), -- именно те, где обновление автора
    # требует переложить нашу правку. Id берётся из поля манифеста `workshopId`,
    # папка -- запасной путь для старых записей без поля.
    if mod.get("workshopId"):
        return str(mod["workshopId"])
    folder = (mod.get("source") or {}).get("folder", "")
    match = re.match(r"_(?:workshop|krinik-modified)/(\d+)$", folder)
    return match.group(1) if match else None


def library_root():
    with open(MANIFEST, encoding="utf-8") as fh:
        lib = json.load(fh).get("library", "")
    return lib if os.path.isabs(lib) else os.path.join(os.path.dirname(MANIFEST), lib)


def copy_stamp(mod):
    """Время самого нового файла нашей копии мода в библиотеке, или None.

    Сравнивается с датой автора: автор выложил ПОЗЖЕ нашей копии -- у нас
    старая версия (для `_krinik-modified` -- поверх неё наша правка, её
    перекладывать на новую). [NOT-TESTED]"""
    # Правленый нами мод (`_krinik-modified`) собран `patch-mod-asset.py build` из
    # копии автора `ORIGINALS/<Контейнер>.pak` (первый аргумент рецепта
    # `krinikBuild`) -- его дата и есть дата нашей копии; дата собранного пака --
    # это дата НАШЕЙ сборки, она позже скачивания и прятала бы обновление автора.
    recipe = (mod.get("krinikBuild") or {}).get("args") or []
    if recipe:
        original = os.path.join(ORIGINALS, recipe[0] + ".pak")
        if os.path.isfile(original):
            return os.path.getmtime(original)
    folder = (mod.get("source") or {}).get("folder", "")
    if not folder:
        return None
    path = os.path.join(library_root(), folder)
    newest = None
    for root, _dirs, files in os.walk(path):
        for name in files:
            stamp = os.path.getmtime(os.path.join(root, name))
            newest = stamp if newest is None or stamp > newest else newest
    return newest


def ask_steam(ids):
    """{id: (unix_time | None, пропал_ли)} одним запросом."""
    if not ids:
        return {}
    body = {"itemcount": str(len(ids))}
    for i, pid in enumerate(ids):
        body["publishedfileids[%d]" % i] = pid
    req = urllib.request.Request(STEAM_API,
                                 data=urllib.parse.urlencode(body).encode())
    with urllib.request.urlopen(req, timeout=60) as resp:
        payload = json.load(resp)["response"]
    result = {}
    for item in payload.get("publishedfiledetails", []):
        pid = item["publishedfileid"]
        gone = item.get("result") == 9
        result[pid] = (item.get("time_updated"), gone)
    return result


def ask_nexus(mod_id, attempts=4):
    """unix-время последнего обновления страницы мода, или None."""
    url = "https://www.nexusmods.com/%s/mods/%d" % (NEXUS_GAME, mod_id)
    for attempt in range(attempts):
        done = subprocess.run([CURL, "-s", "-m", "40", "-A", UA, url],
                              capture_output=True)
        html = done.stdout.decode("utf-8", "replace")
        pos = html.find("Last updated")
        if pos > 0:
            found = re.search(r'data-date="(\d+)"', html[pos:pos + 400])
            if found:
                return int(found.group(1))
        if attempt + 1 < attempts:
            time.sleep(4)
    return None


def fmt(stamp, minutes=False):
    if not stamp:
        return "       ?        " if minutes else "    ?     "
    return datetime.datetime.fromtimestamp(stamp).strftime(
        "%Y-%m-%d %H:%M" if minutes else "%Y-%m-%d")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", default=DEFAULT_SINCE,
                        help="порог в виде ГГГГ-ММ-ДД (по умолчанию %s)"
                             % DEFAULT_SINCE)
    parser.add_argument("--all", action="store_true",
                        help="считать и выключенные моды тоже")
    args = parser.parse_args()

    cut = datetime.datetime.strptime(args.since, "%Y-%m-%d").timestamp()
    mods = load_mods(args.all)

    ws_ids, ws_name, ws_copy = [], {}, {}
    nexus = []
    for mod in mods:
        wid = workshop_id(mod)
        if wid:
            ws_ids.append(wid)
            ws_name[wid] = mod["name"]
            ws_copy[wid] = copy_stamp(mod)
        elif mod.get("nexusId"):
            nexus.append((mod["nexusId"], mod["name"]))

    print("Манифест: %s" % MANIFEST)
    print("Порог готовности: %s (что выложено ПОСЛЕ -- пересобрано под патч)"
          % args.since)
    print("curl для Nexus: %s" % CURL)
    print("Мастерская: %d, Nexus: %d%s\n"
          % (len(ws_ids), len(nexus),
             ", выключенные учтены" if args.all else ""))

    rows = []
    print("Спрашиваю Steam...", file=sys.stderr)
    for pid, (stamp, gone) in ask_steam(ws_ids).items():
        if gone:
            state = "ПРОПАЛ"
        elif stamp is None:
            state = "НЕ ПРОЧЁЛ"
        else:
            state = "OK" if stamp >= cut else "ЖДЁМ"
        rows.append((stamp or 0, "Мастерская", ws_name.get(pid, "?"), state,
                     ws_copy.get(pid)))

    print("Спрашиваю Nexus (по одной странице, это небыстро)...",
          file=sys.stderr)
    for mod_id, name in nexus:
        stamp = ask_nexus(mod_id)
        if stamp is None:
            state = "НЕ ПРОЧЁЛ"
        else:
            state = "OK" if stamp >= cut else "ЖДЁМ"
        # Дату копии Nexus знает имя архива в библиотеке (движок KUMM, `kumm check`);
        # здесь её нет -- столбец пуст, вывод о свежести копии делает `kumm check`.
        rows.append((stamp or 0, "Nexus", name, state, None))

    rows.sort(key=lambda r: (-r[0], r[2]))
    ready = [r for r in rows if r[3] == "OK"]
    stale = [r for r in rows if r[3] in ("ЖДЁМ", "ПРОПАЛ")]
    unread = [r for r in rows if r[3] == "НЕ ПРОЧЁЛ"]
    newer = [r for r in rows if r[0] and r[4] and r[0] > r[4]]

    for stamp, where, name, state, copy in rows:
        mark = "  <- НОВЕЕ НАШЕЙ КОПИИ" if stamp and copy and stamp > copy else ""
        print("%-10s %s  копия %s  %-11s %s%s"
              % (state, fmt(stamp, True), fmt(copy, True), where, name, mark))

    print("\nГотовы: %d из %d. Ждём: %d. Не прочитано: %d. Новее наших копий: %d."
          % (len(ready), len(rows), len(stale), len(unread), len(newer)))
    if newer:
        print("Новее наших копий (скачать заново; у правленных нами -- переложить правку):")
        for stamp, where, name, state, copy in newer:
            print("  * %s (%s, автор %s, наша копия %s)"
                  % (name, where, fmt(stamp, True), fmt(copy, True)))
    if stale:
        print("Не пересобраны:")
        for stamp, where, name, state, _copy in stale:
            note = (" -- УДАЛЁН ИЗ МАСТЕРСКОЙ, не обновится"
                    if state == "ПРОПАЛ" else "")
            print("  * %s (%s, последний раз %s)%s"
                  % (name, where, fmt(stamp).strip(), note))
    if unread:
        print("НЕ ПРОЧИТАНЫ -- это не вывод, а неудача связи, перезапусти:")
        for stamp, where, name, state, _copy in unread:
            print("  * %s (%s)" % (name, where))
    return 0 if not stale and not unread else 1


if __name__ == "__main__":
    sys.exit(main())
