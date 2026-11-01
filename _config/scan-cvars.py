#!/usr/bin/env python3
"""
Полный список консольных переменных, зарегистрированных в билде Conan Exiles (UE5).

[TESTED: 2026-09-08 · прогон на ConanSandbox-Win64-Shipping.exe (192 МБ) и
Dreamworld.dll. Два контроля, оба сошлись: ПОЛОЖИТЕЛЬНЫЙ - dw.EnableAILODSystem
попал в cvars-registered.txt; ОТРИЦАТЕЛЬНЫЙ - Icons.AddCircle из него ВЫБЫЛ и
лёг в cvars-rejected.txt с причиной. Проверка умеет краснеть: без второго
контроля отбраковка была бы недоказуемой.
ЧЕГО ПРОВЕРКА НЕ ПОКРЫВАЕТ: что каждое оставшееся имя ДЕЙСТВИТЕЛЬНО
зарегистрировано в консоли. Это доказывается только живой игрой
(DumpConsoleCommands либо чтение значения консолью) - до тех пор список
означает "имя есть в бинарнике", а не "cvar существует".]

ЧЕМ ЭТОТ СКАНЕР ОТЛИЧАЕТСЯ ОТ ПАЛВОРЛДОВСКОГО. В паке Palworld
(_config/scan-cvars-full.py) список префиксов ЗАШИТ РУКАМИ: r|s|p|au|pal|Lumen|...
Это работало там, потому что префикс собственных cvar-ов игры (pal.*) был уже
известен - и стоил половины дня, когда его в списке ещё НЕ было (EXP-0016:
"неполный инструмент опаснее отсутствующего: отсутствие видно, неполноту - нет").

У Конана собственное пространство имён НЕИЗВЕСТНО. Кандидатов видно из билда
несколько - funcom.*, flx.* (плагины FLX/*), dw.* (Dreamworld.dll), conan.*, ce.* -
и угадывать их значит повторить ту же ошибку. Поэтому здесь регулярка НЕ знает
префиксов вовсе: она ловит ЛЮБОЙ идентификатор формы <слово>.<слово>[.<слово>...],
а дальше отсекает известный мусор (расширения файлов, домены, версии) и печатает
статистику по префиксам. Пространство имён игры находится ГЛАЗАМИ в этой
статистике, а не догадкой до запуска.

Запуск:
    python _config/scan-cvars.py [путь-к-exe-или-dll] ...

Без аргументов сканирует exe игры и Dreamworld.dll (собственный модуль Funcom)
из первой включённой цели targets.json. Пишет три файла РЯДОМ С СОБОЙ, в UTF-8:
    cvars-registered.txt  - имена ВЕРОЯТНЫХ cvar-ов, по одному в строке
    cvars-rejected.txt    - отбракованные имена с причиной отбраковки
    cvars-prefixes.txt    - статистика по префиксам, самые частые сверху
Файлы пишет САМ, а не через перенаправление: PowerShell 5.1 пишет редирект в
ANSI (кодовая страница 1251), и кириллица в шапке погибла бы до записи.

ПОЧЕМУ ЕСТЬ ОТБРАКОВКА И ПОЧЕМУ ОНА НЕ УДАЛЯЕТ, А ОТКЛАДЫВАЕТ. Форма
<слово>.<слово> в exe принадлежит не только cvar-ам. Первый прогон 08.09.2026 дал
12222 имени, и среди частых префиксов оказались ЦЕЛЫЕ СЕМЬИ, к консоли отношения
не имеющие: exiles.* и google.* - определения protobuf-сервисов PlayFab; Icons.* -
имена иконок Slate; Actor.*, SceneComponent.* - имена функций Blueprint из
рефлексии; Gamecode.* - gameplay-теги; d.* - поля сертификатов ASN.1.
Отбракованное пишется в отдельный файл С ПРИЧИНОЙ, а не выбрасывается: список
зарегистрированных имён - это ИНСТРУМЕНТ ПРОВЕРКИ, и он врёт в обе стороны.
Лишнее имя стоит дня работы не по адресу; выброшенное молча - того же дня, но
без следа, куда смотреть. Семью, попавшую в отбраковку ошибочно, видно в
cvars-rejected.txt за секунду.
"""
import json
import re
import sys
from pathlib import Path

PACK = Path(__file__).resolve().parent.parent
OUT_NAMES = Path(__file__).resolve().parent / "cvars-registered.txt"
OUT_REJECT = Path(__file__).resolve().parent / "cvars-rejected.txt"
OUT_PREFIX = Path(__file__).resolve().parent / "cvars-prefixes.txt"

# Что сканируем по умолчанию: сам движок и собственный модуль Funcom.
DEFAULT_RELS = [
    "ConanSandbox/Binaries/Win64/ConanSandbox-Win64-Shipping.exe",
    "ConanSandbox/Binaries/Win64/Dreamworld.dll",
]

# Имя cvar-а БЕЗ знания префикса: слово, точка, дальше буквы/цифры/точки/подчёркивания.
# Нижняя граница длины хвоста отсекает мусор вроде "a.b"; верхняя - склейки строк.
NAME = re.compile(r"\b([A-Za-z][A-Za-z0-9_]{0,23}\.[A-Za-z0-9_][A-Za-z0-9_.]{1,71})\b")

# Мусор, который имеет ту же форму, что и cvar. Отсекается по ПОСЛЕДНЕМУ сегменту:
# так уходят и "Engine.ini", и "libxess_dx11.dll", и "foo.bar.baz.pdb".
JUNK_TAIL = {
    "dll", "exe", "ini", "txt", "pdb", "log", "json", "xml", "cfg", "csv", "bin",
    "pak", "ucas", "utoc", "sig", "uasset", "umap", "uexp", "ubulk", "upipelinecache",
    "png", "jpg", "jpeg", "bmp", "tga", "dds", "wav", "mp3", "ogg", "bnk", "bk2",
    "h", "cpp", "inl", "usf", "ush", "hlsl", "py", "lua", "js", "css", "html",
    "com", "net", "org", "io", "ru", "gg", "tv", "co", "uk", "de", "info",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
}

# Домены и пути целиком - у них узнаваемое начало.
JUNK_HEAD = {"www", "http", "https", "ftp", "mailto", "api", "cdn", "steamcommunity"}

# Семьи, к консоли отношения НЕ имеющие. Ключ - префикс, значение - причина:
# причина едет в cvars-rejected.txt, чтобы ошибочную отбраковку было видно глазом.
# Каждая семья попала сюда ПО НАБЛЮДЕНИЮ в первом прогоне, а не по догадке.
DENY_FAMILIES = {
    "exiles": "protobuf-сервисы PlayFab (exiles.auth.v1.*), не консоль",
    "google": "protobuf runtime, не консоль",
    "grpc": "protobuf runtime, не консоль",
    "Icons": "имена иконок Slate (Icons.AddCircle), не консоль",
    "Colors": "имена цветов темы Slate, не консоль",
    "Brushes": "имена кистей темы Slate, не консоль",
    "Actor": "имена функций Blueprint из рефлексии UObject",
    "SceneComponent": "имена функций Blueprint из рефлексии UObject",
    "Pawn": "имена функций Blueprint из рефлексии UObject",
    "Character": "имена функций Blueprint из рефлексии UObject",
    "PrimitiveComponent": "имена функций Blueprint из рефлексии UObject",
    "Gamecode": "gameplay-теги игры (Gamecode.AI.Brain), не cvar-ы",
    "d": "поля сертификатов ASN.1 и мусор коротких строк",
    "UE": "имена аудиопараметров и форматов, не консоль",
}


def targets_exes():
    tj = PACK / "targets.json"
    if not tj.exists():
        raise SystemExit("targets.json не найден - укажи путь к exe аргументом")
    data = json.loads(tj.read_text(encoding="utf-8"))
    for t in data.get("targets", []):
        if t.get("enabled", True):
            root = Path(t["path"])
            return [root / rel for rel in DEFAULT_RELS]
    raise SystemExit("В targets.json нет включённых целей")


def harvest(path):
    """Все имена cvar-подобной формы из одного файла: ASCII + UTF-16LE с обоими сдвигами."""
    raw = path.read_bytes()
    names = set()
    # Узкие строки.
    names |= set(NAME.findall(raw.decode("latin-1", "ignore")))
    # Широкие строки: именно в них у Palworld жили ВСЕ собственные cvar-ы игры.
    names |= set(NAME.findall(raw.decode("utf-16-le", "ignore")))
    # Смещение на байт: широкая строка может начинаться с нечётного адреса.
    names |= set(NAME.findall(raw[1:].decode("utf-16-le", "ignore")))
    return names


def reject_reason(name):
    """Причина отбраковки, либо None если имя похоже на cvar."""
    parts = name.split(".")
    if parts[0].lower() in JUNK_HEAD:
        return "домен или схема URL"
    if parts[-1].lower() in JUNK_TAIL:
        return f"хвост '.{parts[-1]}' - расширение файла, домен или число"
    # Версии вида 2.10.3 - все сегменты числовые.
    if all(p.isdigit() for p in parts[1:]):
        return "номер версии, а не имя"
    if parts[0] in DENY_FAMILIES:
        return DENY_FAMILIES[parts[0]]
    return None


def main():
    args = [Path(a) for a in sys.argv[1:]]
    files = args if args else targets_exes()

    names = set()
    scanned = []
    for f in files:
        if not f.exists():
            print(f"# пропущен (нет файла): {f}", file=sys.stderr)
            continue
        got = harvest(f)
        names |= got
        scanned.append((f, len(got)))

    if not scanned:
        raise SystemExit("Нечего сканировать: ни один файл не найден")

    clean, rejected = [], []
    for n in sorted({x.rstrip(".") for x in names}, key=str.lower):
        why = reject_reason(n)
        if why:
            rejected.append((n, why))
        else:
            clean.append(n)

    OUT_NAMES.write_text("\n".join(clean) + "\n", encoding="utf-8")
    OUT_REJECT.write_text(
        "# Отбраковано сканером. Причина в правой колонке. Семья здесь по ошибке?\n"
        "# Убери её из DENY_FAMILIES в scan-cvars.py и перезапусти - файл пересоберётся.\n"
        + "\n".join(f"{n}\t{why}" for n, why in rejected) + "\n",
        encoding="utf-8")

    by_prefix = {}
    for n in clean:
        head = n.split(".")[0]
        by_prefix[head] = by_prefix.get(head, 0) + 1
    ranked = sorted(by_prefix.items(), key=lambda kv: (-kv[1], kv[0].lower()))

    lines = [f"{cnt}\t{pref}" for pref, cnt in ranked]
    OUT_PREFIX.write_text("\n".join(lines) + "\n", encoding="utf-8")

    for f, cnt in scanned:
        print(f"# {f.name}: {cnt} сырых совпадений", file=sys.stderr)
    print(f"# вероятных cvar-ов: {len(clean)}; отбраковано: {len(rejected)}; "
          f"префиксов: {len(ranked)}", file=sys.stderr)
    print(f"# записано: {OUT_NAMES.name}, {OUT_REJECT.name}, {OUT_PREFIX.name}",
          file=sys.stderr)
    print("# топ-30 префиксов:", file=sys.stderr)
    for pref, cnt in ranked[:30]:
        print(f"#   {cnt:6d}  {pref}", file=sys.stderr)


if __name__ == "__main__":
    main()
