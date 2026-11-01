# -*- coding: utf-8 -*-
"""patch-mod-asset.py — нативная правка ОДНОГО ассета чужого мода прямо в его контейнере: остальные куски контейнера байт в байт прежние.

Зачем (2026-10-26, KUMM bugs/64 п. 7, 13, 17, 18; правило HOUSE_RULES §1 «интерфейс чужих модов чинится нативно»): надписи панели Exiles
Fishing («DIFFICULTY», «Apply to server»), подсказки школ магии Era of Trials — строки в данных виджета, `.locres` их не видит. Владелец:
«правим чужие моды напрямую, для оптимизации и скорости» · «луа хуки ... тормозят - как мерцающие переводы». Lua-подмена текста в игре
отвергнута; правка ассета — ноль процессора и нет кадра с английским.

Почему один ассет, а не весь мод: опыт 13.09 (build-level-mod.py) — круг retoc to-legacy → to-zen даёт таблицы байт в байт, а блюпринт-
контроллер — нет. Поэтому мод не пересобирается: в его контейнере подменяется ровно один кусок (unpack-raw → замена → pack-raw).

    python -I -X utf8 patch-mod-asset.py extract   <Мод> <Ассет> <work>      # ассет → legacy + JSON (UAssetGUI)
    python -I -X utf8 patch-mod-asset.py roundtrip <Мод> <Ассет> <work>      # КОНТРОЛЬ: круг без правок даёт тот же кусок?
    python -I -X utf8 patch-mod-asset.py build <Мод> <Ассет> <work> <map.tsv> [<map2.tsv> <Ассет2> …]   # строки → новый <work>/out/<Мод>.pak
<Мод> — имя контейнера в Saved/ExtractedMods без «-Windows» (JaarFishing); <Ассет> — имя файла без расширения (W_EFT_Panel).
Строки меняет uaj (UAssetAPI без JSON: круг JSON ломается на PropertyFlags > Int64; байткод — как есть, SkipParsingBytecode;
контроль «загрузить-записать без правок» дал .uasset и .uexp байт в байт, 2026-10-26).
Пишет только в <work> и в папку-представление VIEW (жёсткие ссылки на контейнеры игры). Папка игры — только чтение.
Ряды таблицы данных (2026-10-29, Ragnar's New Factions — ряды на несуществующие таблицы спавна):
    delrow:<Ряд>                          убрать ряд таблицы целиком
    fname:<Ряд>/<Свойство>\t<было>\t<стало>   имя (NameProperty) в ряду; «было» — страж: не совпало — остановка
    bool:<Функция>@<n>\t<было>\t<стало>       n-й логический токен функции (True|False), порядок — как у kismet-trace.py
    enum:<Ряд>/<Свойство>\t<было>\t<стало>    значение перечисления (EnumProperty или ByteProperty с именем), «Тип::Значение»
                                          (2026-10-29, окна модов в хабе: Category Popup → Modal, FullscreenGUIAction Close → None — KUMM план 36)
Эти строки правятся через JSON UAssetGUI, а кусок собирает retoc to-zen (у таблиц круг to-legacy → to-zen — байт в байт; склейка
не годится: новое имя в таблице имён не попадёт в исходный zen-заголовок). Оба отрезка проверяются на каждой сборке.
PATCH_VIEW=<папка> — своё представление вместо VIEW: прибор не ставит в него жёстких ссылок на игру, а кладёт только global.utoc/.ucas
игры (копией) и контейнер мода из оригинала. Хватает ассетам, которые ссылаются лишь на скрипты движка (таблица данных); иначе сборка
остановится на неразрешённой ссылке.
[NOT-TESTED]
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
from game_target import GAME_DIR, sandbox  # noqa: E402

TOOLS = r"D:\work\ai_sandbox\_tools"
# retoc 0.1.5 + правка тикета trumank/retoc#72 (UE 5.8: ShaderMapHashes по 8 байт) — собран 2026-10-26 из 885a8da; 0.1.5 не читает заголовки контейнеров 3.0.1.
# С 2026-10-30 — сборка локального коммита 8e2eedf: pack-raw и to-zen сжимают блоки Oodle (без сжатия правленые паки были в 2–3 раза больше оригиналов,
# KUMM план 36 п. 14а); прежний exe — retoc-2026-10-26-nocompress.exe рядом
RETOC = os.path.join(TOOLS, "retoc-5.8", "retoc.exe")
UASSETGUI = os.path.join(TOOLS, "UAssetGUI", "UAssetGUI.exe")
RETOC_ENGINE = "UE5_7"          # retoc знает версии до 5.7; формат 5.8 тот же (проверено 2026-10-02, build-level-mod.py)
# Наш UAssetGUI знает VER_UE5_8 и читает пакет с FileVersionUE5 = 1018 как есть; подмена 1018→1017 из сентябрьского опыта (build-level-mod.py)
# с ассетом новой сборки retoc (формат обычного ассета −9) ломала чтение — JSON не писался (2026-10-26 10:25).
UASSET_ENGINE = "VER_UE5_8"
UAJ = os.path.join(TOOLS, "src", "uaj", "bin", "Release", "net8.0", "uaj.exe")   # исходник — _tools/src/uaj/Program.cs
REPAK = os.path.join(TOOLS, "repak", "repak.exe")
OUTER_MOUNT = "../../../ConanSandbox/Mods/"
PAK_VERSION = "V11"                                # игра читает паки не новее V11 (EXP-0089)
ORIGINALS = r"D:\Games\Conan Exiles Mods\_patch-originals"   # исходные паки модов, которые мы правим (KRINIK MODIFIED)
GAME_PAKS = os.path.join(GAME_DIR, r"ConanSandbox\Content\Paks")
EXTRACTED = sandbox("Saved", "ExtractedMods")
VIEW = r"D:\work\ai_sandbox\_paksview-3.0.1"   # жёсткие ссылки на контейнеры игры (тот же том D:), вне папки игры

_spec = importlib.util.spec_from_file_location("blm", os.path.join(HERE, "build-level-mod.py"))


def run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(f"код {r.returncode}: {' '.join(args)}\n{r.stdout[-2000:]}\n{r.stderr[-2000:]}")
    return r.stdout


def ensure_view(mod):
    own = os.environ.get("PATCH_VIEW")
    if own:
        # Своё представление (2026-10-29): правка RNF шла под запретом писать вне черновика и репозитория сборки — общий VIEW и
        # жёсткие ссылки на игру недоступны. Таблице данных хватает global (скриптовые объекты) и контейнера самого мода.
        view = os.path.abspath(own)
        assert not view.lower().startswith(os.path.abspath(GAME_DIR).lower()), "представление внутри игры"
        os.makedirs(view, exist_ok=True)
        for ext in (".utoc", ".ucas"):
            if not os.path.exists(os.path.join(view, "global" + ext)):
                shutil.copyfile(os.path.join(GAME_PAKS, "global" + ext), os.path.join(view, "global" + ext))
        if not os.path.exists(os.path.join(view, f"{mod}-Windows.utoc")):
            files = unpack_original(mod, view + "-outer-" + mod)   # рядом, не внутри: retoc читает всю папку представления
            for ext in (".utoc", ".ucas"):
                shutil.copyfile(os.path.join(files, f"{mod}-Windows{ext}"), os.path.join(view, f"{mod}-Windows{ext}"))
        return view
    view = os.path.abspath(VIEW)
    assert not view.lower().startswith(os.path.abspath(GAME_DIR).lower()), "папка-представление внутри игры"
    os.makedirs(view, exist_ok=True)
    for fn in os.listdir(GAME_PAKS):
        if fn.endswith((".utoc", ".ucas")) and not os.path.exists(os.path.join(view, fn)):
            os.link(os.path.join(GAME_PAKS, fn), os.path.join(view, fn))
    # Контейнеры ВСЕХ модов: виджет ссылается на чужие пакеты (общие каркасы ModsShared), без них retoc пишет /Engine/UnknownPackage
    # и при записи обратно ссылка теряется (2026-10-26: W_EFT_Panel — 4 UnknownExport, когда в представлении был только сам мод).
    for fn in os.listdir(EXTRACTED):
        if fn.endswith((".utoc", ".ucas")):
            src, dst = os.path.join(EXTRACTED, fn), os.path.join(view, fn)
            # не та же жёсткая ссылка — устарела: игра перезаписала контейнер мода (пересборка KrinikBowFixes 28.10 дала .utoc того же размера,
            # 788 байт, сверка по размеру его пропустила, и retoc падал на заголовке «failed to fill whole buffer» по всему представлению)
            if os.path.exists(dst) and not os.path.samefile(src, dst):
                os.remove(dst)
            if not os.path.exists(dst):
                os.link(src, dst)
    return view


def unpack_original(mod, outer):
    """Внешний пак оригинала мода → <outer>; возвращает папку с его контейнерами (<Мод>-Windows.utoc …)."""
    # Источник — ОРИГИНАЛ мода, а не раскатанный: после первой правки в ExtractedMods лежит уже наш контейнер, и вторая сборка не нашла
    # английских строк («НЕ НАЙДЕНО», 2026-10-26 10:42). Оригиналы — ORIGINALS/<Мод>.pak (обновился мод — положить туда новый и пересобрать).
    orig = os.path.join(ORIGINALS, f"{mod}.pak")
    if not os.path.exists(orig):
        raise SystemExit(f"нет оригинала {orig}: скопируй туда исходный пак мода (из библиотеки), потом собирай")
    run([REPAK, "unpack", "-q", "-s", OUTER_MOUNT, "-o", outer, orig])
    return outer if os.path.exists(os.path.join(outer, f"{mod}-Windows.utoc")) else os.path.join(outer, "ConanSandbox", "Mods")


def set_ue5_version(path, frm, to):
    blm = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(blm)
    blm.set_ue5_version(path, frm, to)


def find(root, name, ext):
    # Ближайший к корню из одноимённых: у Hosav рядом с W_SmoothHP лежит авторская копия SUPERUI_Backup_ForFuckups/W_SmoothHP
    # (2026-10-26), и первый попавшийся os.walk мог отдать копию вместо ассета, который игра показывает.
    hits = [os.path.join(dp, name + ext) for dp, _, fs in os.walk(root) if name + ext in fs]
    return min(hits, key=lambda p: (p.count(os.sep), p)) if hits else None


def extract(mod, asset, work):
    view = ensure_view(mod)
    legacy = os.path.join(work, "legacy")
    run([RETOC, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", asset, view, legacy])
    ua = find(legacy, asset, ".uasset")
    if not ua:
        raise SystemExit(f"retoc не выдал {asset}.uasset")
    jp = os.path.join(work, asset + ".json")
    run([UASSETGUI, "tojson", ua, jp, UASSET_ENGINE])
    if not os.path.exists(jp):
        raise SystemExit("UAssetGUI не записал JSON (код 0 без сообщения — так он отказывает)")
    doc = json.load(open(jp, encoding="utf-8"))
    unknown = "/Engine/UnknownPackage" in json.dumps(doc.get("Imports", []))
    print(f"legacy: {ua}\njson: {jp}\nэкспортов {len(doc.get('Exports', []))}, импортов {len(doc.get('Imports', []))}, "
          f"неразрешённых ссылок: {'ЕСТЬ' if unknown else 'нет'}")
    return ua, jp


def chunks_of(raw_dir, asset):
    """Куски ассета в выгрузке unpack-raw: manifest.json сопоставляет номер куска с путём файла."""
    man = json.load(open(os.path.join(raw_dir, "manifest.json"), encoding="utf-8"))
    return {cid: os.path.join(raw_dir, "chunks", cid) for cid, path in man["chunk_paths"].items()
            if os.path.splitext(os.path.basename(path))[0] == asset}


def zen_chunks(legacy_dir, asset, out_dir):
    mini = os.path.join(out_dir, f"{asset}.utoc")
    os.makedirs(out_dir, exist_ok=True)
    run([RETOC, "to-zen", "--version", RETOC_ENGINE, "--filter", asset, legacy_dir, mini])
    raw = os.path.join(out_dir, "raw")
    run([RETOC, "unpack-raw", mini, raw])
    return chunks_of(raw, asset)


def roundtrip(mod, asset, work):
    """Контроль без правок, по двум отрезкам: (а) retoc: legacy → zen = кусок мода? (б) UAssetGUI: JSON → ассет = тот же legacy?"""
    ua, jp = extract(mod, asset, work)
    raw_old = os.path.join(work, "raw-old")
    run([RETOC, "unpack-raw", os.path.join(ensure_view(mod), f"{mod}-Windows.utoc"), raw_old])
    old = chunks_of(raw_old, asset)
    a = zen_chunks(os.path.join(work, "legacy"), asset, os.path.join(work, "zen-a"))
    for cid, p in a.items():
        same = cid in old and open(p, "rb").read() == open(old[cid], "rb").read()
        print(f"(а) retoc legacy→zen, кусок {cid}: {os.path.getsize(p)} против {os.path.getsize(old[cid]) if cid in old else '—'} — "
              f"{'БАЙТ В БАЙТ' if same else 'расходится'}")
    back = os.path.join(work, "back", os.path.relpath(ua, os.path.join(work, "legacy")))
    os.makedirs(os.path.dirname(back), exist_ok=True)
    run([UASSETGUI, "fromjson", jp, back])
    for ext in (".uasset", ".uexp"):
        same = open(ua[:-7] + ext, "rb").read() == open(back[:-7] + ext, "rb").read()
        print(f"(б) UAssetGUI JSON→ассет {ext}: {'БАЙТ В БАЙТ' if same else 'расходится'}")


def uaj_exports(path):
    rows = []
    for line in run([UAJ, "exports", path, UASSET_ENGINE]).splitlines():
        off, size, _kind, _name = line.split("\t", 3)
        rows.append((int(off), int(size)))
    return rows


def uaj_exports_full(path):
    rows = []
    for line in run([UAJ, "exports", path, UASSET_ENGINE]).splitlines():
        off, size, kind, name = line.split("\t", 3)
        rows.append((int(off), int(size), kind, name.strip()))
    return rows


def patch_literals(patched_ua, lits):
    """Строки прямо в байткоде (`lit:` в таблице): kismet.py удлиняет литерал и сдвигает адреса переходов функции (KUMM bugs/64 п. 7,
    `[OWNER]` «Свой пересчёт байткода» · 2026-10-26). Пишет новый .uexp рядом с пропатченным ассетом, возвращает новые (смещение, размер)."""
    sys.path.insert(0, HERE)
    import kismet
    path = patched_ua[:-7] + ".uexp"
    blob = open(path, "rb").read()
    new, rows, report = kismet.patch_uexp(blob, uaj_exports_full(patched_ua), lits)
    used = {en for _, _, en, _ in report}
    for _, _, en, ru in report:
        print(f"   байткод: {en!r} → {ru!r}")
    missing = [en for en in lits if en not in used]
    if missing:
        raise SystemExit(f"литералы не найдены в байткоде: {missing} — сборка остановлена")
    open(path, "wb").write(new)
    return rows


def patch_doubles(patched_ua, dbls, rows=None):
    """Числа прямо в байткоде (`dbl:<функция>\t<старое>\t<новое>` и `flt:…` в таблице): EX_DoubleConst (8 байт) и EX_FloatConst (4 байта)
    правятся на месте — адреса и размеры функций не меняются. Меняются ВСЕ вхождения старого числа в функции; ни одного — остановка.
    Зачем: место миникарты Simple Minimap считает `LoadSettings` от половины её размера (`× 0.5`), и строку координат срезает край экрана
    (KUMM bugs/64 п. 19); кнопка Hosav опрашивает хаб `Delay 3.0` по кругу (п. 16) — опрос глушится, видимость ставит событие.
    dbls = [(функция, старое, новое, 'd'|'f')]; rows — новые места функций после `lit:` (иначе берутся из заголовка ассета).
    Оплачено 2026-10-29: после `lit:` функции за удлинённым литералом сдвинулись, а заголовок .uasset хранит старые смещения — `flt:TryLocal`
    у JaarFishing «не найдено», хотя число там есть (граф событий стоит раньше литералов и нашёлся)."""
    import struct
    sys.path.insert(0, HERE)
    import kismet
    path = patched_ua[:-7] + ".uexp"
    blob = bytearray(open(path, "rb").read())
    if rows is None:
        rows = uaj_exports_full(patched_ua)
    for fn, old, new, kind_ in dbls:
        # `flt:<функция>@<n>` — только n-е вхождение числа (по порядку в байткоде, с 1). Оплачено 2026-10-29: у Era of Trials три `Delay 0.1`
        # в одной функции (вкладка «Снаряжение», окно характеристик, карусель) — глушить надо одно, а без номера правка берёт все.
        fn, _, nth = fn.partition("@")
        nth = int(nth) if nth else 0
        hit = seen = 0
        for off, size, kind, name in rows:
            if name != fn or kind != "RawExport":
                continue
            for hdr, mem, disk, w in kismet.find_scripts(bytes(blob), off, off + size):
                places = {"d": w.dbls, "f": w.flts, "i": w.ints}[kind_]
                # `int:` (2026-10-30): EX_IntConst, 4 байта — делитель «k» Hosav (план 36 W5c)
                want = {"d": old, "f": struct.unpack("<f", struct.pack("<f", old))[0], "i": int(old)}[kind_]
                for pos, val in places:
                    # float32 хранит 3.0 точно, но 0.66 — нет: сравнение по тому же округлению, что и в файле
                    if val == want:
                        seen += 1
                        if nth and seen != nth:
                            continue
                        struct.pack_into({"d": "<d", "f": "<f", "i": "<i"}[kind_], blob, hdr + 8 + pos,
                                         int(new) if kind_ == "i" else new)
                        hit += 1
        if not hit:
            raise SystemExit(f"число {old} не найдено в байткоде {fn} — сборка остановлена")
        print(f"   байткод: {fn} {old} → {new} ({hit} мест{f', вхождение {nth} из {seen}' if nth else ''})")
    open(path, "wb").write(bytes(blob))


def patch_bools(patched_ua, bools, rows=None):
    """Логический токен в байткоде (`bool:<функция>@<n>\t<было>\t<стало>`, было/стало — True|False): n-й по порядку EX_True/EX_False функции
    (с 1, порядок — как у kismet-trace.py) меняется на месте, один байт; не совпало «было» — остановка. Зачем (2026-10-29, KUMM план 36):
    кнопка «Настройки интерфейса» Hosav зовёт ActivateModule('CharacterInventory', False) перед своим окном — закрывает хаб; True
    повторно активирует уже открытый хаб (проверено пультом: хаб и кнопки на месте), и окно Hosav ложится поверх."""
    sys.path.insert(0, HERE)
    import kismet
    path = patched_ua[:-7] + ".uexp"
    blob = bytearray(open(path, "rb").read())
    if rows is None:
        rows = uaj_exports_full(patched_ua)
    for fn, old, new in bools:
        fn, _, nth = fn.partition("@")
        nth = int(nth)
        hit = None
        for off, size, kind, name in rows:
            if name != fn or kind != "RawExport":
                continue
            for hdr, mem, disk, w in kismet.find_scripts(bytes(blob), off, off + size):
                if len(w.bools) >= nth:
                    hit = (hdr + 8 + w.bools[nth - 1][0], w.bools[nth - 1][1])
        if hit is None:
            raise SystemExit(f"логического токена №{nth} в {fn} нет — сборка остановлена")
        if hit[1] != old:
            raise SystemExit(f"{fn}@{nth}: ждали {old}, в байткоде {hit[1]} — сборка остановлена")
        blob[hit[0]] = 0x27 if new else 0x28
        print(f"   байткод: {fn} логический №{nth} {old} → {new}")
    open(path, "wb").write(bytes(blob))


def patch_raw_floats(patched_ua, rawfs):
    """Умолчания, которых нет в выгрузке свойств (`rawf:<старое>\t<новое>` в таблице): число float32 меняется на месте во всём `.uexp`, но только
    если старое встречается в файле РОВНО один раз — иначе остановка (не угадывать, которое из двух). Зачем: умолчания пользовательской
    структуры `NightTerrorsAdminSettings` (шанс засады 80.0, часы 21.0 / 5.0, исчезновение 300.0) лежат в её сырых байтах (KUMM план 35 Г9)."""
    import struct
    path = patched_ua[:-7] + ".uexp"
    blob = bytearray(open(path, "rb").read())
    for old, new in rawfs:
        pat = struct.pack("<f", old)
        n = blob.count(pat)
        if n != 1:
            raise SystemExit(f"float {old} встречается в .uexp {n} раз (нужно ровно 1) — сборка остановлена")
        i = blob.find(pat)
        struct.pack_into("<f", blob, i, new)
        print(f"   сырое число @{i}: {old} → {new}")
    open(path, "wb").write(bytes(blob))


def patch_rows(patched_ua, delrows, fnames, aw):
    """Ряды таблицы данных (`delrow:<Ряд>`, `fname:<Ряд>/<Свойство>\t<было>\t<стало>`) — через JSON UAssetGUI: у uaj нет удаления рядов
    и записи имён, а JSON таблицы, в отличие от чертежа, ходит по кругу без потерь. Зачем: Ragnar's New Factions называет в
    RNF_Shared_WeightedSpawns таблицы спавна, которых в паке нет (плавильщики Wadai, алхимик пиктов, опечатка с пробелом) —
    игра пишет «SpawnNPC - could not find SpawnTable» и оставляет место пустым (KUMM план 36 п. 2, 2026-10-29).
    Страж перед правкой: JSON без правок, записанный тем же json.dump, обязан дать тот же .uexp байт в байт."""
    def dump_and_write(doc, name):
        jp = os.path.join(aw, name + ".json")
        json.dump(doc, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
        out = os.path.join(aw, name, os.path.basename(patched_ua))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        run([UASSETGUI, "fromjson", jp, out])
        if not os.path.exists(out[:-7] + ".uexp"):
            raise SystemExit("UAssetGUI не записал ассет из JSON (код 0 без сообщения — так он отказывает)")
        return out

    def table_of(doc):
        tables = [e for e in doc["Exports"] if e.get("Table") is not None]
        if len(tables) != 1:
            raise SystemExit(f"таблиц данных в ассете {len(tables)}, ждали 1")
        return tables[0]["Table"]["Data"]

    def one_row(data, row):
        hits = [r for r in data if r.get("Name") == row]
        if len(hits) != 1:
            raise SystemExit(f"ряд {row!r}: найдено {len(hits)}, ждали 1 — сборка остановлена")
        return hits[0]

    jp = os.path.join(aw, "rows-src.json")
    run([UASSETGUI, "tojson", patched_ua, jp, UASSET_ENGINE])
    doc = json.load(open(jp, encoding="utf-8"))
    if "/Engine/UnknownPackage" in json.dumps(doc.get("Imports", [])):
        raise SystemExit("в импортах /Engine/UnknownPackage — представлению не хватает контейнеров, круг JSON потеряет ссылку")
    ctrl = dump_and_write(doc, "rows-control")
    if open(ctrl[:-7] + ".uexp", "rb").read() != open(patched_ua[:-7] + ".uexp", "rb").read():
        raise SystemExit("круг JSON без правок дал другой .uexp — сборка остановлена")
    data = table_of(doc)
    for row in delrows:
        data.remove(one_row(data, row))
        print(f"   ряд убран: {row}")
    for row, prop, old, new in fnames:
        props = [p for p in one_row(data, row)["Value"] if p.get("Name") == prop and name_field(p)]
        if len(props) != 1 or props[0].get(name_field(props[0])) != old:
            raise SystemExit(f"ряд {row}, {prop}: ждали имя {old!r}, в таблице {[p.get(name_field(p)) for p in props]} — сборка остановлена")
        props[0][name_field(props[0])] = new
        if new not in doc["NameMap"]:
            # Имени нет в таблице имён — без него UAssetAPI не запишет FName. Ставится НЕ в конец, а перед именами одного заголовка:
            # retoc to-zen берёт в zen-таблицу имён только первые NamesReferencedFromExportDataCount (у RNF 1280 из 1289); имя в конце
            # пропало из куска, и ряд после выгрузки показал номер «1289» вместо имени (2026-10-29, первая сборка).
            at = doc["NamesReferencedFromExportDataCount"]
            doc["NameMap"].insert(at, new)
            doc["NamesReferencedFromExportDataCount"] = at + 1
        print(f"   ряд {row}: {prop} {old!r} → {new!r}")
    out = dump_and_write(doc, "rows-new")
    for ext in (".uasset", ".uexp"):
        shutil.copyfile(out[:-7] + ext, patched_ua[:-7] + ext)
    chk = os.path.join(aw, "rows-check.json")
    run([UASSETGUI, "tojson", patched_ua, chk, UASSET_ENGINE])
    check_rows(chk, delrows, fnames, len(data), "после записи")
    return len(data)


def name_field(p):
    """Поле JSON UAssetGUI, где у свойства лежит имя: NameProperty и EnumProperty — `Value`, ByteProperty-перечисление — `EnumValue`
    (FullscreenGUIAction в UIModuleTableRow — байтовое перечисление, Category — EnumProperty; 2026-10-29). Не имя — None."""
    t = p.get("$type", "")
    if "NamePropertyData" in t or "EnumPropertyData" in t:
        return "Value"
    if "BytePropertyData" in t and p.get("ByteType") == "FName":
        return "EnumValue"
    return None


def check_rows(jp, delrows, fnames, count, when):
    """Ряды таблицы в выгрузке JSON: убранных нет, имена — новые, число рядов — ожидаемое."""
    tables = [e for e in json.load(open(jp, encoding="utf-8"))["Exports"] if e.get("Table") is not None]
    data = tables[0]["Table"]["Data"]
    names = [r.get("Name") for r in data]
    gone = [r for r in delrows if r in names]
    if gone or len(names) != count:
        raise SystemExit(f"{when}: рядов {len(names)} (ждали {count}), не убраны {gone}")
    for row, prop, old, new in fnames:
        v = [p.get(name_field(p)) for r in data if r.get("Name") == row for p in r["Value"] if p.get("Name") == prop]
        if v != [new]:
            raise SystemExit(f"{when}: ряд {row}, {prop} = {v}, ждали {new!r}")
    print(f"   {when}: рядов {count}, убранных нет, имена на месте")


def splice_chunk(zen, orig_ua, patched_ua, new_rows=None):
    """Новый zen-кусок БЕЗ retoc to-zen: исходный заголовок + пропатченный .uexp, в таблице экспортов — новые смещения и размеры.
    Зачем: retoc to-zen ломает классы блюпринтов 5.8 даже без правок (W_EFT_AdminButton → «Bad export index», игра падает; EXP-0338).
    Опора (проверено 2026-10-26 на W_EFT_AdminButton): данные zen-куска после header_size == .uexp обычного ассета байт в байт, смещения
    экспортов в zen-таблице — от начала этих данных, таблица по смещению [32] до [36], запись 72 байта (u64 смещение, u64 размер, …)."""
    import struct
    hs = struct.unpack_from("<I", zen, 4)[0]
    em_off, eb_off = struct.unpack_from("<ii", zen, 32)
    n = (eb_off - em_off) // 72
    orig_uexp = open(orig_ua[:-7] + ".uexp", "rb").read()
    if zen[hs:] != orig_uexp:
        raise SystemExit("данные zen-куска ≠ .uexp обычного ассета — склейка невозможна, нужен другой путь")
    zen_rows = [struct.unpack_from("<QQ", zen, em_off + 72 * i) for i in range(n)]
    orig_rows = uaj_exports(orig_ua)
    if [s for _, s in orig_rows] != [s for _, s in zen_rows] or [o for o, _ in orig_rows] != [o for o, _ in zen_rows]:
        raise SystemExit("порядок или размеры экспортов zen ≠ обычного ассета — склейка небезопасна")
    if new_rows is None:
        new_rows = uaj_exports(patched_ua)
    if len(new_rows) != n:
        raise SystemExit("число экспортов изменилось")
    head = bytearray(zen[:hs])
    for i, (off, size) in enumerate(new_rows):
        struct.pack_into("<QQ", head, em_off + 72 * i, off, size)
    return bytes(head) + open(patched_ua[:-7] + ".uexp", "rb").read()


def md5(path):
    import hashlib
    h = hashlib.md5()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def build(mod, pairs, work):
    """pairs = [(ассет, таблица замен), …]. Каждый ассет: legacy → uaj setstr → to-zen → его кусок; куски подменяются в контейнере
    мода (остальные — байт в байт); внешний пак собирается заново с новыми MD5 в manifest.json."""
    files = unpack_original(mod, os.path.join(work, "outer"))
    view = ensure_view(mod)
    for ext in (".utoc", ".ucas"):                  # в представлении — контейнер оригинала, не раскатанный
        dst = os.path.join(view, f"{mod}-Windows{ext}")
        if os.path.exists(dst):
            os.remove(dst)
        shutil.copyfile(os.path.join(files, f"{mod}-Windows{ext}"), dst)
    # PATCH_VIEW_EXCLUDE=<Мод>[,<Мод>] — убрать из представления контейнеры этих модов. Оплачено 2026-10-29: Accessory System (ModsShared) лежит
    # и в Enhanced Armory and Arsenal, и в Highmane's Arsenal, версии разные; to-legacy по общему представлению взял копию Highmane's, склейка с
    # куском EAA не сошлась, а правка Highmane's в игре не подействовала — грузится копия EAA (замер рождения кнопки «Аксессуары»).
    exclude = [m for m in os.environ.get("PATCH_VIEW_EXCLUDE", "").split(",") if m]
    if exclude:
        vx = os.path.join(work, "view")
        os.makedirs(vx, exist_ok=True)
        for fn in os.listdir(view):
            if any(fn.startswith(m + "-") for m in exclude):
                continue
            if not os.path.exists(os.path.join(vx, fn)):
                os.link(os.path.join(view, fn), os.path.join(vx, fn))
        print(f"   представление без {', '.join(exclude)}: {vx}")
        view = vx
    raw = os.path.join(work, "raw-mod")
    run([RETOC, "unpack-raw", os.path.join(view, f"{mod}-Windows.utoc"), raw])
    mod_chunks = json.load(open(os.path.join(raw, "manifest.json"), encoding="utf-8"))["chunk_paths"]
    for asset, tsv in pairs:
        aw = os.path.join(work, asset)
        legacy = os.path.join(aw, "legacy")
        run([RETOC, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", asset, view, legacy])
        ua = find(legacy, asset, ".uasset")
        patched = os.path.join(aw, "patched", os.path.relpath(ua, legacy))
        os.makedirs(os.path.dirname(patched), exist_ok=True)
        # Страж: запись без правок обязана совпасть с исходником байт в байт, иначе писатель портит что-то кроме строк
        # (2026-10-26: ClassExport в UAssetAPI 1.1.0 — игра падала; лечение — RawExport для StructExport в uaj).
        # Сверяется то, что уходит в игру: .uexp и таблица экспортов (смещения, размеры). Заголовок .uasset в игру не попадает — склейка
        # берёт исходный zen-заголовок; UAssetAPI пишет его иначе (SaveUISettings_UIH Hosav: +16 байт при равном .uexp, 2026-10-26).
        ctrl = os.path.join(aw, "control.uasset")
        run([UAJ, "copy", ua, ctrl, UASSET_ENGINE])
        if open(ua[:-7] + ".uexp", "rb").read() != open(ctrl[:-7] + ".uexp", "rb").read():
            raise SystemExit(f"{asset}: контроль записи без правок НЕ совпал (.uexp) — сборка остановлена")
        if uaj_exports(ua) != uaj_exports(ctrl):
            raise SystemExit(f"{asset}: контроль записи без правок — таблица экспортов разошлась — сборка остановлена")
        # Строки `lit:` — байткод (kismet.py), остальное — свойства (uaj setstr)
        lits, plain, dbls, rawfs, delrows, fnames, bools = {}, [], [], [], [], [], []
        for line in open(tsv, encoding="utf-8").read().splitlines():
            if line.startswith("bool:") and line.count("\t") == 2:
                fn, old, new = line[5:].split("\t")
                if {old, new} != {"True", "False"}:
                    raise SystemExit(f"строка bool: ждёт True/False, дано {old!r} → {new!r}")
                bools.append((fn, old == "True", new == "True"))
            elif line.startswith("delrow:"):
                delrows.append(line[7:].strip())
            elif line.startswith(("fname:", "enum:")) and line.count("\t") == 2:
                where, old, new = line.split(":", 1)[1].split("\t")
                row, _, prop = where.rpartition("/")
                fnames.append((row, prop, old, new))
            elif line.startswith("rawf:") and line.count("\t") == 1:
                old, new = line[5:].split("\t")
                rawfs.append((float(old), float(new)))
            elif line[:4] in ("dbl:", "flt:", "int:") and line.count("\t") == 2:
                fn, old, new = line[4:].split("\t")
                dbls.append((fn, float(old), float(new), line[0]))
            elif line.startswith("lit:") and "\t" in line:
                en, ru = line[4:].split("\t", 1)
                # Русское в кавычках — ради пробела в конце: редактор и инструменты записи срезают его у конца строки, и число
                # прилипало к слову («Мастерство рыбака:60», сборка 2026-10-26 13:1x)
                if len(ru) >= 2 and ru[0] == '"' and ru[-1] == '"':
                    ru = ru[1:-1]
                lits[en.replace("\\n", "\n")] = ru.replace("\\n", "\n")
            else:
                plain.append(line)
        plain_tsv = os.path.join(aw, "plain.tsv")
        open(plain_tsv, "w", encoding="utf-8").write("\n".join(plain) + "\n")
        uaj_out = run([UAJ, "setstr", ua, patched, UASSET_ENGINE, plain_tsv]).strip()
        print(asset + ": " + uaj_out.replace("\n", "\n   "))
        # Отказ uaj по строке таблицы — остановка сборки, а не пак без этой строки: 2026-10-30 отказ «имени WrapTextAt нет в таблице имён»
        # печатался, а сборка шла дальше и выдавала пак, где правки нет (KUMM EXP-0377). Молчаливая частичная правка хуже остановки.
        if "REFUSED" in uaj_out:
            raise SystemExit(f"{asset}: uaj отказал по строке таблицы — сборка остановлена")
        lit_full = patch_literals(patched, lits) if lits else None
        lit_rows = [(o, s) for o, s, _, _ in lit_full] if lit_full else None
        if dbls:
            patch_doubles(patched, dbls, lit_full)   # после литералов: правка на месте по их новым местам; смещения lit_rows остаются верными
        if rawfs:
            patch_raw_floats(patched, rawfs)  # тоже на месте, размер не меняется
        if bools:
            patch_bools(patched, bools, lit_full)   # один байт на месте; места функций — после литералов, как у чисел
        # Кусок пакета: склейка исходного заголовка с пропатченным .uexp (retoc to-zen ломает блюпринты 5.8 — EXP-0338)
        # Кусок — тот, чей путь совпадает с путём правленого ассета (одноимённая копия в подпапке мода — другой кусок)
        rel = os.path.relpath(ua, legacy).replace(os.sep, "/")
        mine = {cid: p for cid, p in mod_chunks.items() if p.replace("\\", "/").endswith("/" + rel)}
        if len(mine) != 1:
            raise SystemExit(f"{asset}: кусков пакета в контейнере мода {len(mine)}, ждали 1")
        cid = next(iter(mine))
        cpath = os.path.join(raw, "chunks", cid)
        if delrows or fnames:
            # Ряды таблицы: кусок собирает retoc to-zen. Страж — тот же to-zen по НЕправленому ассету обязан дать кусок мода байт в байт.
            if lits or dbls or rawfs or bools:
                raise SystemExit(f"{asset}: ряды таблицы и правки байткода в одном ассете — не поддержано")
            count = patch_rows(patched, delrows, fnames, aw)
            base = zen_chunks(legacy, asset, os.path.join(aw, "zen-control"))
            if set(base) != {cid} or open(base[cid], "rb").read() != open(cpath, "rb").read():
                raise SystemExit(f"{asset}: retoc to-zen без правок не повторил кусок мода — сборка остановлена")
            print(f"   страж to-zen: кусок без правок — байт в байт")
            zdir = os.path.join(aw, "zen-new")
            new = zen_chunks(os.path.join(aw, "patched"), asset, zdir)
            if set(new) != {cid}:
                raise SystemExit(f"{asset}: to-zen дал куски {sorted(new)}, ждали {cid}")
            # Проверка самого куска: обратно в legacy (мини-контейнер + global из представления) и те же сверки рядов
            back = os.path.join(aw, "zen-check")
            os.makedirs(back, exist_ok=True)
            for src in (os.path.join(zdir, f"{asset}.utoc"), os.path.join(zdir, f"{asset}.ucas"),
                        os.path.join(view, "global.utoc"), os.path.join(view, "global.ucas")):
                shutil.copyfile(src, os.path.join(back, os.path.basename(src)))
            run([RETOC, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", asset, back, os.path.join(back, "legacy")])
            bj = os.path.join(aw, "zen-check.json")
            run([UASSETGUI, "tojson", find(os.path.join(back, "legacy"), asset, ".uasset"), bj, UASSET_ENGINE])
            check_rows(bj, delrows, fnames, count, "кусок zen")
            new_chunk = open(new[cid], "rb").read()
        else:
            new_chunk = splice_chunk(open(cpath, "rb").read(), ua, patched, lit_rows)
        open(cpath, "wb").write(new_chunk)
        print(f"   кусок {cid} {'собран to-zen' if delrows or fnames else 'склеен'} ({len(new_chunk)} байт)")
    # Контейнер мода с подменёнными кусками
    for ext in (".utoc", ".ucas"):
        os.remove(os.path.join(files, f"{mod}-Windows{ext}"))
    run([RETOC, "pack-raw", raw, os.path.join(files, f"{mod}-Windows.utoc")])
    stub = os.path.join(files, f"{mod}-Windows.pak")       # платформенный пак мода (AssetRegistry и т. п.) — прежний
    assert os.path.exists(stub), "платформенный пак мода пропал"
    # Манифест 3.0 хранит ДВА набора: MD5 (верхний уровень) и XXH128 (раздел «<xxh128>»). Загрузчик сверяет распакованные файлы по
    # XXH128: с одним пересчитанным MD5 игра писала «skip extracting … already exists with correct hash» и оставляла старый контейнер
    # (2026-10-26 10:38). Значение — xxh128().hexdigest() (сверено на modinfo.json: 2cafc502… = манифест).
    import site
    sys.path.append(site.getusersitepackages())    # python -I не видит пользовательские пакеты; xxhash стоит там
    import xxhash
    man_p = os.path.join(files, "manifest.json")
    man = json.load(open(man_p, encoding="utf-8-sig"))
    for fn in list(man):
        if os.path.exists(os.path.join(files, fn)):
            man[fn] = md5(os.path.join(files, fn))
    for fn in list(man.get("<xxh128>", {})):
        p = os.path.join(files, fn)
        if os.path.exists(p):
            h = xxhash.xxh128()
            with open(p, "rb") as f:
                for b in iter(lambda: f.read(1 << 20), b""):
                    h.update(b)
            man["<xxh128>"][fn] = h.hexdigest()
    json.dump(man, open(man_p, "w", encoding="utf-8"), indent=2)
    out = os.path.join(work, "out")
    os.makedirs(out, exist_ok=True)
    final = os.path.join(out, f"{mod}.pak")
    if os.path.exists(final):
        os.remove(final)
    run([REPAK, "pack", "-q", "--version", PAK_VERSION, "--mount-point", OUTER_MOUNT, files, final])
    print(f"готово: {final} ({os.path.getsize(final)} байт); manifest.json пересчитан для {len(man)} файлов")


def main():
    cmd, mod, asset, work = sys.argv[1:5]
    os.makedirs(work, exist_ok=True)
    if cmd == "build":
        rest = sys.argv[5:]
        pairs = [(asset, rest[0])] + [(rest[i + 1], rest[i]) for i in range(1, len(rest) - 1, 2)]
        build(mod, pairs, work)
        return
    {"extract": extract, "roundtrip": roundtrip}[cmd](mod, asset, work)


if __name__ == "__main__":
    main()
