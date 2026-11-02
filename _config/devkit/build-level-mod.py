"""build-level-mod.py — наш мод уровней для Conan Exiles Enhanced 2.1.x (форк MrSerji's Level 1000).

Зачем (13.09.2026, слово владельца): «давай попробует взять кривую опыта с 0,5» · «10000 уровней
сделаем» · «на каждом уровне даётся одно очко аттрибута свободное, без исключений» · очки знаний —
«не больше 50 за уровень», вариант «B» · «собрать такой мод распаковкой мода на 1000 и обратной
упаковкой» · «делай, но это будет наш мод - форк».

Почему не кит: кит 5.8.2 — для патча 2.2.0, он пишет пакеты UE5 1018, а игра 2.1.x грузит 1017
(KUMM EXPERIENCE EXP-0109, researches/conan-devkit/web-recon.md §3).

Как (каждый шаг проверен 13.09 на эталоне — круг разборка→сборка таблиц MrS дал байт-в-байт тот же
контейнер, заголовки и данные):
 1. архив MrS из библиотеки → внешний пак → платформенные файлы (repak);
 2. контейнер MrS → обычные ассеты (retoc to-legacy). retoc разрешает ссылки на пакеты игры ТОЛЬКО если
    их контейнеры лежат в той же папке и не вложенно, поэтому строится папка-представление из ЖЁСТКИХ
    ссылок на контейнеры игры ВНЕ папки игры (ссылка-каталог не годится: retoc не заходит вглубь, а
    рекурсивное удаление по ней дошло бы до игры). Без этого ссылка на STR_* пишется /Engine/UnknownPackage;
 3. три таблицы → JSON (UAssetGUI) → строки из генераторов, пакет переезжает на ВАНИЛЬНЫЙ путь
    /Game/Systems/Progression/ (заменяет родную таблицу целиком, блюпринт-контроллер не нужен:
    retoc ломает импорты блюпринта MrS, таблиц — нет) → обратно в ассеты;
 4. ассеты → контейнер Zen UE5_6 на каждую платформу (retoc to-zen);
 5. платформенный пак (AssetRegistry.bin, без него загрузчик отказывает) и внешняя обёртка V11 с
    manifest.json (MD5) и modinfo.json (repak);
 6. проверка: готовый мод разбирается заново, числа строк и значения сверяются с генераторами.

  python build-level-mod.py --name Level10000 --work <скретчпад> --out <папка результата>

Пишет только в --work, --out и папку-представление (жёсткие ссылки). Папка игры — только чтение.
"""
# [TESTED: 2026-09-13 · ОФЛАЙН, 14 с: три таблицы по 10 000 строк, значения = генераторы, данные в
#  контейнере = записанным UAssetGUI, блок импорта Zen-заголовка = у таблицы MrS (контроль: сборка без
#  разрешения ссылок даёт «не равно» — проверка краснеет); круг без правок на таблицах MrS — байт в байт.
#  В ИГРЕ 13.09 20:49: загрузчик мод принял («schema check: no issues»), таблица на ванильном пути
#  подменила родную — и игра УПАЛА на «Bad name index 1016/1007» (словарь имён, EXP-0110). Исправлено,
#  проверка словаря краснеет на упавшей сборке; повторный запуск — см. KUMM ideas/04]
import argparse
import copy
import csv
import hashlib
import importlib.util
import json
import os
import shutil
import struct
import subprocess
import sys
import zipfile

TOOLS = r"D:\work\ai_sandbox\_tools"
RETOC = os.path.join(TOOLS, "retoc", "retoc.exe")
UASSETGUI = os.path.join(TOOLS, "UAssetGUI", "UAssetGUI.exe")
REPAK = os.path.join(TOOLS, "repak", "repak.exe")
KIT_UNREALPAK = r"F:\CEUE5Devkit\Engine\Binaries\Win64\UnrealPak.exe"   # только чтение контейнеров; кит 3.0.1 (старого F:\CEDevKit больше нет — 2026-10-30)
# 2026-10-02, переезд на 2.2.3 (UE 5.8). Игра, представление и донор — новые; для 2.1.x взять эти пять
# строк из git (коммит до переезда): там игра D:\Games\Conan Exiles, донор 1.0.4, retoc UE5_6.
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))))
from game_target import GAME_DIR, sandbox   # путь игры — из targets.json (2026-10-25: 2.2.3 удалена)
GAME_PAKS = os.path.join(GAME_DIR, r"ConanSandbox\Content\Paks")
VIEW = r"D:\work\ai_sandbox\_paksview-2.2.3"    # жёсткие ссылки на контейнеры игры, вне папки игры
VIEW_301 = r"D:\work\ai_sandbox\_paksview-3.0.1"                                   # все контейнеры 3.0.1 (игра + моды), KUMM STATUS «work trees kept»
RETOC_58 = os.path.join(TOOLS, "retoc-5.8", "retoc-2026-10-26-nocompress.exe")    # retoc с UE 5.8: разрешает ссылки 3.0.1
CAV_OBJECT_VERSION = "OS_SUB_OBJECT_SHADOW_SERIALIZATION"   # ObjectVersionUE5 таблиц, прочитанных путём uasset_json (VER_UE5_6)
MRS_ZIP = r"D:\Games\Conan Exiles Mods\mods\MrSerji's Level 1000 15 1.0.5 2026-09-17T08-48Z iP5rAx98z.zip"
MRS = "MrS_Level1000"
# retoc 0.1.5 знает версии только до UE5_7, а игра 2.2.x — UE 5.8. Проверено 2026-10-02 кругом без правок
# на доноре 1.0.5 (сварен под 5.8): to-legacy UE5_7 → to-zen UE5_7, распаковка UnrealPak кита — у всех трёх
# таблиц .uexp и .uheader байт в байт как у MrS. Не сходится только его блюпринт-контроллер (он нам не нужен).
RETOC_ENGINE = "UE5_7"
UASSET_ENGINE = "VER_UE5_6"
# UAssetGUI (UAssetAPI) ассет с FileVersionUE5 = 1018 НЕ ЧИТАЕТ: молча выходит с кодом 0 и не пишет JSON.
# Сверка 2026-10-02 одной и той же таблицы MrS под 5.6 и 5.8: заголовок пакета различается ОДНИМ полем —
# FileVersionUE5 1017 → 1018 (смещение 16), данные .uexp у двух таблиц из трёх совпали байт в байт. Поэтому
# на входе UAssetGUI версия подменяется на 1017, на выходе возвращается 1018 — см. uasset_json / uasset_write.
UE5_VERSION_OFFSET = 16
UE5_VERSION_GAME = 1018      # пакеты 2.2.x
UE5_VERSION_TOOL = 1017      # что читает UAssetGUI
PLATFORMS = ["Windows", "WindowsServer", "LinuxServer"]   # порядок как в manifest.json у MrS
PAK_VERSION = "V11"                                        # игра читает паки не новее V11 (EXP-0089)
OUTER_MOUNT = "../../../ConanSandbox/Mods/"                # как у внешней обёртки MrS
PLATFORM_MOUNT = "../../../ConanSandbox/Content/"          # как у платформенного пака MrS

LEVELS = 10_000
XP_P = 0.5
XP_ANCHOR = 500      # 16.09.2026, слово владельца: «кривую опыта нужно поднимать - на множителе 1,
                     # я прокачал более 30 уровней за час игры... Нужно замедлять в раза 2» →
                     # затем прямо: «давай базу 500 опыта сделаем». Было 175 (родная цена 1-го
                     # уровня); промежуточный 350 был раскатан в 21:30 и через минуту заменён
                     # этим по слову владельца — в игре на нём не играли. Поднят ЯКОРЬ, а
                     # не наклон: форма закона и «без потолка» сохраняются, каждый уровень дороже
                     # ровно в 500/175 = 2,857 раза.
ATTR_COST = 1        # у MrS CostPerPoint = 1 во всех 1000 строках; держим так же
ATTR_REWARD = 1      # «на каждом уровне даётся одно очко аттрибута свободное, без исключений»

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.dirname(HERE)


def load_module(name, filename):
    spec = importlib.util.spec_from_file_location(name, os.path.join(CONFIG, filename))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


xpt = load_module("xpt", "xp-table.py")
fts = load_module("fts", "feats-table.py")
cav = load_module("cav", "caverns_loot.py")   # таблица сундуков Caverns of Set (шаг 3б; владелец 2026-11-01 08:58 «делаем сейчас 2»)


def say(msg):
    print(msg, flush=True)


def run(args, **kw):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace", **kw)
    if r.returncode != 0:
        raise SystemExit(f"ОШИБКА {os.path.basename(args[0])} ({r.returncode}):\n{r.stdout[-2000:]}\n{r.stderr[-2000:]}")
    return r.stdout + r.stderr


def md5(path):
    h = hashlib.md5()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def pack_version_fields():
    """versionMajor/Minor/Build из packVersion манифеста сборки («1.0.0») — версия модов Krinik = версия сборки."""
    manifest = json.load(open(os.path.join(os.path.dirname(CONFIG), "modpack.json"), encoding="utf-8"))
    major, minor, build = (int(x) for x in manifest["packVersion"].split("."))
    return {"versionMajor": major, "versionMinor": minor, "versionBuild": build}


# --- расписание строк: одно место, откуда берутся все числа мода ---------------------------------
def table_rows():
    xp = xpt.build(LEVELS, XP_P, XP_ANCHOR)
    assert xp["fits"] and len(xp["rows"]) == LEVELS
    return {
        # имя таблицы: (первое имя строки, [значения колонок по префиксу имени колонки])
        "ExperienceSystemLevel": [(str(L), {"LevelStart": s, "LevelEnd": e}) for L, s, e in xp["rows"]],
        "AttributeSystem": [(str(i), {"CostPerPoint": ATTR_COST, "RewardPerLevel": ATTR_REWARD}) for i in range(LEVELS)],
        "FeatsPerLevel": [(str(L), {"FeatPoints": fts.feats_at(L)}) for L in range(1, LEVELS + 1)],
    }


def replace_strings(node, mapping):
    if isinstance(node, dict):
        return {k: replace_strings(v, mapping) for k, v in node.items()}
    if isinstance(node, list):
        return [replace_strings(v, mapping) for v in node]
    if isinstance(node, str) and node in mapping:
        return mapping[node]
    return node


def transform_table(doc, table, rows):
    old_obj, new_obj = f"DT_MrS_{table}", f"DT_{table}"
    old_pkg, new_pkg = f"/Game/Mods/{MRS}/DataTable/{old_obj}", f"/Game/Systems/Progression/{new_obj}"
    doc = replace_strings(doc, {old_obj: new_obj, old_pkg: new_pkg})
    data = doc["Exports"][0]["Table"]["Data"]
    template = data[0]
    new_data = []
    for name, values in rows:
        row = copy.deepcopy(template)
        row["Name"] = name
        for col in row["Value"]:
            col["Value"] = values[col["Name"].split("_")[0]]
        new_data.append(row)
    doc["Exports"][0]["Table"]["Data"] = new_data
    # Оплачено падением игры 13.09 20:49 («DT_FeatsPerLevel: Bad name index 1016/1007»). retoc to-zen кладёт
    # в словарь пакета только ПЕРВЫЕ NamesReferencedFromExportDataCount имён (дальше — служебные имена
    # импортов, их Zen хранит хешами). retoc to-legacy записал туда 1007/1008, UAssetAPI переносит поле из
    # JSON без пересчёта — и 9 000 новых имён строк молча выпали. Поэтому: новые имена вставляются В ЭТОТ
    # блок (сразу за числовыми именами), а счётчик растёт на число вставленных.
    names = doc["NameMap"]
    have = set(names)
    lead = 0
    while lead < len(names) and names[lead].isdigit():
        lead += 1
    added = [n for n, _ in rows if n not in have]
    referenced = doc["NamesReferencedFromExportDataCount"]
    assert lead <= referenced <= len(names), (lead, referenced, len(names))
    names[lead:lead] = added
    doc["NamesReferencedFromExportDataCount"] = referenced + len(added)
    return doc


def walk_strings(node, mapping):
    """Заменить в поддереве JSON строки-значения по словарю (имена меток в запросе RequiredTags); вернуть, что заменено."""
    hit = set()
    def go(n):
        if isinstance(n, dict):
            for k, v in n.items():
                if isinstance(v, str) and v in mapping:
                    n[k] = mapping[v]
                    hit.add(v)
                else:
                    go(v)
        elif isinstance(n, list):
            for i, v in enumerate(n):
                if isinstance(v, str) and v in mapping:
                    n[i] = mapping[v]
                    hit.add(v)
                else:
                    go(v)
    go(node)
    return hit


def caverns_table(doc):
    """Ванильная DT_LC_RelicHunter → таблица сундуков Caverns of Set по пути, который ждёт сундук мода: другой пакет и имя,
    строки — копии строк-образцов с полями и метками из _config/caverns_loot.py.
    [TESTED: 2026-11-01 · step 6 green; in game the chests read the table and fill · KUMM testcases/reports/2026-11-01_conan-caverns-chest-loot.md]"""
    doc = replace_strings(doc, {cav.SOURCE_TABLE: cav.TABLE, cav.SOURCE_PACKAGE: cav.PACKAGE})
    data = doc["Exports"][0]["Table"]["Data"]
    by_name = {r["Name"]: r for r in data}
    new_data, new_names = [], []
    for name, src, fields, tags in cav.ROWS:
        row = copy.deepcopy(by_name[src])
        row["Name"] = name
        new_names.append(name)
        for col in row["Value"]:
            if col["Name"] in fields:
                col["Value"] = fields[col["Name"]]
        if tags:
            req = next(c for c in row["Value"] if c["Name"] == "RequiredTags")
            done = walk_strings(req, tags)
            assert done == set(tags), f"строка {name}: в запросе меток образца {src} нет {set(tags) - done}"
            new_names += list(tags.values())
        new_data.append(row)
    doc["Exports"][0]["Table"]["Data"] = new_data
    # новые имена (строки, метки) — в блок имён, на которые ссылаются данные экспорта (урок «Bad name index», transform_table)
    names = doc["NameMap"]
    have = set(names)
    lead = 0
    while lead < len(names) and names[lead].isdigit():
        lead += 1
    added = list(dict.fromkeys(n for n in new_names if n not in have))
    referenced = doc["NamesReferencedFromExportDataCount"]
    names[lead:lead] = added
    doc["NamesReferencedFromExportDataCount"] = referenced + len(added)
    assert cav.SOURCE_TABLE not in json.dumps(doc), "имя ванильной таблицы осталось в ассете"
    return doc


def caverns_rows(doc):
    """Строки записанной таблицы — для сверки на шаге 6: (имя, ItemID, Min, Max, шанс, броски, метки запроса)."""
    out = []
    for r in doc["Exports"][0]["Table"]["Data"]:
        v = {c["Name"]: c for c in r["Value"]}
        tags = sorted(set(x for x in json.dumps(v["RequiredTags"]).split('"') if x.count(".") and x[0].isupper() and " " not in x))
        out.append((r["Name"], v["ItemID"]["Value"], v["Min"]["Value"], v["Max"]["Value"], v["PercentChance"]["Value"],
                    v["NumRolls"]["Value"], tags))
    return out


def ensure_view(mrs_platform_dir):
    view = os.path.abspath(VIEW)
    assert not view.lower().startswith(os.path.abspath(GAME_DIR).lower()), "папка-представление внутри игры"
    os.makedirs(view, exist_ok=True)
    for fn in os.listdir(GAME_PAKS):
        if fn.endswith((".utoc", ".ucas")) and not os.path.exists(os.path.join(view, fn)):
            os.link(os.path.join(GAME_PAKS, fn), os.path.join(view, fn))
    for ext in (".utoc", ".ucas"):
        shutil.copyfile(os.path.join(mrs_platform_dir, f"{MRS}-Windows{ext}"), os.path.join(view, f"{MRS}-Windows{ext}"))
    return view


def set_ue5_version(path, frm, to):
    """Переписать FileVersionUE5 в заголовке пакета .uasset; проверяет, что там стояло ожидаемое."""
    with open(path, "r+b") as f:
        f.seek(UE5_VERSION_OFFSET)
        have, = struct.unpack("<i", f.read(4))
        assert have == frm, f"{os.path.basename(path)}: FileVersionUE5 = {have}, ждали {frm}"
        f.seek(UE5_VERSION_OFFSET)
        f.write(struct.pack("<i", to))


def uasset_json(src, dst):
    # Копия рядом с JSON, с версией, которую понимает UAssetGUI; .uexp едет без изменений.
    shim = dst[:-5] + ".tool.uasset"
    shutil.copyfile(src, shim)
    shutil.copyfile(src[:-7] + ".uexp", shim[:-7] + ".uexp")
    set_ue5_version(shim, UE5_VERSION_GAME, UE5_VERSION_TOOL)
    run([UASSETGUI, "tojson", shim, dst, UASSET_ENGINE])
    if not os.path.exists(dst):
        raise SystemExit(f"UAssetGUI не записал {dst} (код 0, без сообщения — так он отказывает)")
    return json.load(open(dst, encoding="utf-8"))


def uasset_write(jp, dst):
    run([UASSETGUI, "fromjson", jp, dst])
    set_ue5_version(dst, UE5_VERSION_TOOL, UE5_VERSION_GAME)


def uasset_json_58(src, dst):
    # Вывод retoc-5.8 UAssetGUI читает напрямую как VER_UE5_8; подмена версии 1018 → 1017 и VER_UE5_6 (uasset_json) он молча отвергает
    # (2026-11-01 09:5x). Запись — fromjson без подмены: заголовок остаётся 1018, как у пакетов игры.
    run([UASSETGUI, "tojson", src, dst, "VER_UE5_8"])
    if not os.path.exists(dst):
        raise SystemExit(f"UAssetGUI не записал {dst} (код 0, без сообщения — так он отказывает)")
    return json.load(open(dst, encoding="utf-8"))


def build(name, display, work, out):
    if os.path.exists(work) and os.listdir(work):
        raise SystemExit(f"--work должна быть пустой или новой: {work}")
    os.makedirs(work, exist_ok=True)
    rows = table_rows()

    say("1. архив MrS → платформенные файлы")
    with zipfile.ZipFile(MRS_ZIP) as z:
        z.extract(f"{MRS}.pak", os.path.join(work, "mrs"))
    mrs_files = os.path.join(work, "mrs", "files")
    # repak снимает только "../../../", а у внешней обёртки точка монтирования глубже — снимаем её целиком
    run([REPAK, "unpack", "-q", "-s", OUTER_MOUNT, "-o", mrs_files, os.path.join(work, "mrs", f"{MRS}.pak")])
    plat_pak = os.path.join(work, "mrs", "platpak")
    run([REPAK, "unpack", "-q", "-o", plat_pak, os.path.join(mrs_files, f"{MRS}-Windows.pak")])
    registry = next(os.path.join(dp, f) for dp, _, fs in os.walk(plat_pak) for f in fs if f == "AssetRegistry.bin")

    say("2. контейнер MrS → ассеты (ссылки на пакеты игры разрешаются через представление)")
    view = ensure_view(mrs_files)
    legacy = os.path.join(work, "legacy")
    run([RETOC, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", MRS, view, legacy])
    src_dt = os.path.join(legacy, "ConanSandbox", "Content", "Mods", MRS, "DataTable")

    say("3. таблицы → JSON → 10 000 строк на ванильных путях → ассеты")
    legacy_out = os.path.join(work, "legacy-out")
    dst_dt = os.path.join(legacy_out, "ConanSandbox", "Content", "Systems", "Progression")
    os.makedirs(dst_dt, exist_ok=True)
    shutil.copyfile(os.path.join(legacy, "scriptobjects.bin"), os.path.join(legacy_out, "scriptobjects.bin"))
    for table, trows in rows.items():
        doc = uasset_json(os.path.join(src_dt, f"DT_MrS_{table}.uasset"), os.path.join(work, f"{table}.mrs.json"))
        assert "/Engine/UnknownPackage" not in json.dumps(doc["Imports"]), f"{table}: ссылки не разрешены"
        doc = transform_table(doc, table, trows)
        jp = os.path.join(work, f"{table}.ours.json")
        json.dump(doc, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
        uasset_write(jp, os.path.join(dst_dt, f"DT_{table}.uasset"))
        say(f"   DT_{table}: {len(trows)} строк")

    say("3б. таблица сундуков Caverns of Set ← ванильная DT_LC_RelicHunter (KUMM mods/CavernsOfSet.md)")
    legacy_rh = os.path.join(work, "legacy-relic")
    # Ванильную таблицу — из представления 3.0.1 и retoc-5.8: представление VIEW держит контейнеры 2.2.3 (ensure_view только ДОБАВЛЯЕТ
    # недостающие), и ссылки таблицы на вложенные таблицы игры там не разрешаются (прогон 2026-11-01 09:5x — «/Engine/UnknownPackage»).
    run([RETOC_58, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", cav.SOURCE_TABLE, VIEW_301, legacy_rh])
    src_rh = next(os.path.join(dp, f) for dp, _, fs in os.walk(legacy_rh) for f in fs if f == f"{cav.SOURCE_TABLE}.uasset")
    doc = uasset_json_58(src_rh, os.path.join(work, "caverns.relic.json"))
    assert "/Engine/UnknownPackage" not in json.dumps(doc["Imports"]), "DT_LC_RelicHunter: ссылки не разрешены"
    doc = caverns_table(doc)
    cav_dir = os.path.join(legacy_out, "ConanSandbox", "Content", *cav.PACKAGE.split("/")[2:-1])
    os.makedirs(cav_dir, exist_ok=True)
    jp = os.path.join(work, "caverns.ours.json")
    # В контейнер её кладёт тот же retoc, что и три таблицы прогрессии, — он читает только их сериализацию (версия объектов 5.6 и заголовок
    # 1018 после записи): ассет, записанный как 5.8, он отверг («failed to fill whole buffer», 2026-11-01 09:5x). Поэтому — их путь.
    doc["ObjectVersionUE5"] = CAV_OBJECT_VERSION
    doc["AppendedNullBytes"] = 0
    json.dump(doc, open(jp, "w", encoding="utf-8"), ensure_ascii=False)
    uasset_write(jp, os.path.join(cav_dir, f"{cav.TABLE}.uasset"))
    say(f"   {cav.TABLE}: {len(cav.ROWS)} строк → {cav.PACKAGE}")

    say("4. ассеты → контейнеры Zen")
    stage = os.path.join(work, "outer")
    os.makedirs(stage, exist_ok=True)
    for plat in PLATFORMS:
        run([RETOC, "to-zen", "--version", RETOC_ENGINE, legacy_out, os.path.join(stage, f"{name}-{plat}.utoc")])

    say("5. платформенные паки, manifest.json, modinfo.json, внешняя обёртка")
    content = os.path.join(work, "platpak", "Content")
    reg_dst = os.path.join(content, "Mods", name, "AssetRegistry.bin")
    os.makedirs(os.path.dirname(reg_dst), exist_ok=True)
    shutil.copyfile(registry, reg_dst)
    for plat in PLATFORMS:
        target = os.path.join(stage, f"{name}-{plat}.pak")
        if os.path.exists(target):
            os.remove(target)                      # заглушка, которую пишет retoc, заменяется нашим паком
        run([REPAK, "pack", "-q", "--version", PAK_VERSION, "--mount-point", PLATFORM_MOUNT, content, target])
    info = json.load(open(os.path.join(mrs_files, "modinfo.json"), encoding="utf-8-sig"))
    info.update({
        "name": display, "folderName": name, "author": "", "authorUrl": "",
        "description": (f"{LEVELS} levels. XP per level = {XP_ANCHOR} * level^{XP_P}. "
                        f"One attribute point every level. Feat points: vanilla formula, base capped at "
                        f"{fts.BASE_CAP} (x3 every 10th level). Replaces DT_ExperienceSystemLevel, "
                        f"DT_AttributeSystem, DT_FeatsPerLevel. Fork of MrSerji's Level 1000. "
                        f"Ships the missing loot table of the Caverns of Set chests."),
        # Версия мода = версия сборки packVersion из modpack.json: «в сборке моды Krinik ставим по версии сборки 1.0.0» (владелец 2026-10-31 15:39;
        # отменило «все моды Krinik... получают версию 3.0.1» от 2026-10-28).
        "changeNote": "", **pack_version_fields(),
        "steamPublishedFileId": "", "steamTestLivePublishedFileId": "", "steamWorkshopFileIds": {},
    })
    json.dump(info, open(os.path.join(stage, "modinfo.json"), "w", encoding="utf-8"), ensure_ascii=False, indent="\t")
    manifest = {}
    for plat in PLATFORMS:
        for ext in (".pak", ".utoc", ".ucas"):
            fn = f"{name}-{plat}{ext}"
            manifest[fn] = md5(os.path.join(stage, fn))
    manifest["modinfo.json"] = md5(os.path.join(stage, "modinfo.json"))
    json.dump(manifest, open(os.path.join(stage, "manifest.json"), "w", encoding="utf-8"), indent=2)
    os.makedirs(out, exist_ok=True)
    final = os.path.join(out, f"{name}.pak")
    if os.path.exists(final):
        os.remove(final)
    run([REPAK, "pack", "-q", "--version", PAK_VERSION, "--mount-point", OUTER_MOUNT, stage, final])
    say(f"   {final} ({os.path.getsize(final)} байт)")

    say("6. проверка: готовый мод разбирается заново и сверяется с генераторами")
    check = os.path.join(work, "check")
    os.makedirs(check, exist_ok=True)              # repak не создаёт родителя папки вывода
    run([REPAK, "unpack", "-q", "-s", OUTER_MOUNT, "-o", os.path.join(check, "outer"), final])
    got_manifest = json.load(open(os.path.join(check, "outer", "manifest.json"), encoding="utf-8"))
    for fn, h in got_manifest.items():
        assert md5(os.path.join(check, "outer", fn)) == h, f"MD5 не сходится: {fn}"
    # Обратно через retoc нельзя: наши пакеты носят те же имена, что родные, и при разборе побеждает
    # родная таблица на 60 строк. Поэтому три наблюдения без разрешения ссылок:
    #  (а) данные пакета в контейнере = .uexp, записанный UAssetGUI (байт в байт);
    #  (б) строки и значения записанного ассета = генераторы;
    #  (в) ссылки на классы и структуры игры (хеши публичных экспортов + карта импорта) = у таблицы MrS,
    #      которую игра грузит; имя и словарь имён у нас другие, поэтому сравниваются только эти участки.
    zen_x = os.path.join(check, "zen")
    run([KIT_UNREALPAK, os.path.join(check, "outer", f"{name}-Windows.utoc"), "-Extract", zen_x])
    mrs_x = os.path.join(check, "mrs-zen")
    run([KIT_UNREALPAK, os.path.join(mrs_files, f"{MRS}-Windows.utoc"), "-Extract", mrs_x])
    ok = True
    for table, trows in rows.items():
        zen_dir = os.path.join(zen_x, "ConanSandbox", "Content", "Systems", "Progression")
        same_data = (open(os.path.join(zen_dir, f"DT_{table}.uexp"), "rb").read()
                     == open(os.path.join(dst_dt, f"DT_{table}.uexp"), "rb").read())
        doc = uasset_json(os.path.join(dst_dt, f"DT_{table}.uasset"), os.path.join(check, f"{table}.back.json"))
        data = doc["Exports"][0]["Table"]["Data"]
        got = [(r["Name"], {c["Name"].split("_")[0]: c["Value"] for c in r["Value"]}) for r in data]
        same_rows = got == trows
        ours = open(os.path.join(zen_dir, f"DT_{table}.uheader"), "rb").read()
        theirs = open(os.path.join(mrs_x, "ConanSandbox", "Content", "Mods", MRS, "DataTable",
                                   f"DT_MrS_{table}.uheader"), "rb").read()
        same_imports = import_block(ours) == import_block(theirs)
        zen_names = zen_name_count(ours)
        # имён в словаре пакета не меньше, чем строк: иначе игра падает на «Bad name index» (13.09 20:49)
        names_cover = zen_names >= len(trows)
        good = same_data and same_rows and same_imports and names_cover
        say(f"   {'✅' if good else '❌'} DT_{table}: строк {len(data)} · значения = генератор: {same_rows} · "
            f"данные в контейнере = записанным: {same_data} · ссылки на игру = как у MrS: {same_imports} · "
            f"имён в словаре пакета {zen_names} ≥ строк: {names_cover}")
        ok = ok and good
    # таблица сундуков: данные в контейнере = записанным, строки = рецепт, имён в словаре хватает, путь — тот, что ждёт сундук
    cav_zen = os.path.join(zen_x, "ConanSandbox", "Content", *cav.PACKAGE.split("/")[2:-1])
    have_zen = os.path.exists(os.path.join(cav_zen, f"{cav.TABLE}.uexp"))
    same_data = have_zen and (open(os.path.join(cav_zen, f"{cav.TABLE}.uexp"), "rb").read()
                              == open(os.path.join(cav_dir, f"{cav.TABLE}.uexp"), "rb").read())
    back = uasset_json(os.path.join(cav_dir, f"{cav.TABLE}.uasset"), os.path.join(check, "caverns.back.json"))
    got = caverns_rows(back)
    want_ok = [g[0] for g in got] == [r[0] for r in cav.ROWS]
    for (name, src, fields, tags), g in zip(cav.ROWS, got):
        for k, idx in (("ItemID", 1), ("Min", 2), ("Max", 3), ("PercentChance", 4), ("NumRolls", 5)):
            if k in fields and fields[k] != g[idx]:
                want_ok = False
        if any(t not in g[6] for t in tags.values()):
            want_ok = False
    names_cover = have_zen and zen_name_count(open(os.path.join(cav_zen, f"{cav.TABLE}.uheader"), "rb").read()) >= len(cav.ROWS)
    good = have_zen and same_data and want_ok and names_cover
    say(f"   {'✅' if good else '❌'} {cav.TABLE}: в контейнере по пути сундука: {have_zen} · данные = записанным: {same_data} · "
        f"строки = рецепт: {want_ok} · имён хватает: {names_cover}")
    for g in got:
        say(f"      {g}")
    ok = ok and good
    return 0 if ok else 1


def zen_name_count(uheader):
    """Число имён в словаре Zen-заголовка таблицы. У пакетов без пользовательских версий (все три таблицы)
    счётчик стоит по смещению 80 — снято 13.09 сравнением с MrS: 1007 там же, где UAssetAPI видит 1016 минус
    9 служебных имён импорта."""
    customs, = struct.unpack_from("<i", uheader, 68)
    assert customs == 0, "у таблицы неожиданно есть пользовательские версии — смещение словаря другое"
    return struct.unpack_from("<I", uheader, 80)[0]


def import_block(uheader):
    """Хеши публичных экспортов и карта импорта Zen-заголовка (смещения из FZenPackageSummary)."""
    pub, imp, exp = struct.unpack_from("<iii", uheader, 24)
    return uheader[pub:exp]


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True, help="папка мода и имя пака (слово владельца)")
    ap.add_argument("--display", help="название в списке модов; по умолчанию = --name")
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    return build(a.name, a.display or a.name, a.work, a.out)


if __name__ == "__main__":
    sys.exit(main())
