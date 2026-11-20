"""
Проверка русских строк сборки на тире вместо глагола (HOUSE_RULES KUMM, правило 33; методичка ядра KUMM/krinik-stylometry/russian_norms/RUSSIAN_RULES.md §11).
Владелец 2026-11-18 00:44 увидел в лаунчере «Игра не найдена: сборку — в папку игры» и велел убрать такие тексты везде
(дословно — KUMM PROJECT_HISTORY, запись 2026-11-18 00:44).

Запуск из корня пака: python -I -X utf8 _config/release/dash_lint.py [--only <подстрока пути>] [--list-files]
Код 0 — тире нет; 1 — найдены строки, каждая с файлом и номером строки; 2 — источник не прочитан.

Что читается. Только то, что видит игрок: строковые литералы C# лаунчера, Lua модов Krinik, PowerShell и cmd установщика,
деинсталлятора и отчёта; русская колонка наших переводов в _config/localization; текст руководства и README сборки.
Комментарии кода не читаются: их видит только агент.

Что считается тире: «—», «–» или дефис с пробелом с обеих сторон внутри строки с кириллицей. Диапазон чисел без пробелов
(«1–5») — не тире. Законное тире (прямая речь) записывается в _config/release/dash_lint_allow.txt: строка целиком, затем
табуляция и причина. Без записи строка считается находкой.
[NOT-TESTED]
"""
import html
import re
import sys
from pathlib import Path

PACK = Path(__file__).resolve().parents[2]
KUMM = PACK.parent / "KUMM"
ALLOW_FILE = Path(__file__).with_name("dash_lint_allow.txt")

CYR = re.compile(r"[А-Яа-яЁё]")
# Тире: длинное, короткое или дефис, отделённые пробелами. Неразрывный пробел тоже пробел.
DASH = re.compile(r"[  ][—–-][  ]")


def sources():
    """Файлы со строками для игрока: (путь, разборщик)."""
    out = []
    for p in sorted((PACK / "_config/launcher").glob("*.cs")):
        if p.name != "BuildInfo.g.cs":
            out.append((p, "cs"))
    for d in ("_config/player-report", "_config/uninstall"):
        for p in sorted((PACK / d).glob("*")):
            if p.suffix.lower() in (".ps1", ".cmd", ".txt"):
                out.append((p, "txt" if p.suffix.lower() == ".txt" else "script"))
    # KrinikConanHarness — инструменты агента, в архив игрока не идут (modpack.json "export": false).
    for p in sorted((PACK / "_unpacked").glob("Krinik*/**/*.lua")):
        if "KrinikConanHarness" not in p.parts:
            out.append((p, "lua"))
    # Описания наших модов (README.md в папке мода) едут в архив игрока вместе с модом.
    for p in sorted((PACK / "_unpacked").glob("Krinik*/README.md")):
        out.append((p, "md"))
    # Рабочий список перевода (dm-fish-worklist.tsv) хранит английский оригинал и подсказки, в игру идёт только перевод.
    # Файлы locres-fixes-*.tsv записывают уже внесённые правки Game.locres («было» и «стало»); их источник проверяется здесь же,
    # в таблицах перевода.
    for p in sorted((PACK / "_config/localization").glob("*.tsv")):
        if "worklist" not in p.name and not p.name.startswith("locres-fixes-"):
            out.append((p, "tsv"))
    # Строки ассетов модов KRINIK MODIFIED (папка asset-strings): их вписывает в ассеты patch-mod-asset, игрок видит их в окнах модов
    # (судья 2026-11-18 01:40, находка D1: стеклянный глоб без подпапки их не видел).
    for p in sorted((PACK / "_config/localization/asset-strings").glob("*.tsv")):
        out.append((p, "tsv"))
    # Таблицы перевода текста модов, которые входят в Game.locres (KrinikRU) и в живые виджеты через UE4SS (HosavRU): значения
    # Lua-строк в длинных скобках (находка D2).
    for name in ("KrinikRU", "HosavRU"):
        p = PACK / "_config/localization/kit-saved-loc" / name / "ru_table.lua"
        if p.exists():
            out.append((p, "luatable"))
    # Номер версии мода печатает установщик игрока (Deploy-ModPack.ps1, строка «<мод> <версия> (N файлов)»; находка D3).
    out.append((PACK / "modpack.json", "manifest"))
    # Списки изменений паков Krinik: поле «Список изменений» в списке модов самой игры (KUMM HOUSE_RULES 40, 2026-11-20).
    notes = PACK / "_config/release/krinik_change_notes.json"
    if notes.exists():
        out.append((notes, "notes"))
    # Руководство, которое печатает build-docs.py: guide-<версия игры>.html; старый guide.html (2.2.3) не печатается.
    for p in sorted((PACK / "docs/guide").glob("guide-*.html")):
        out.append((p, "html"))
    out.append((PACK / "_config/public_release/README.template.md", "md"))
    if (KUMM / "Deploy-ModPack.ps1").exists():
        out.append((KUMM / "Deploy-ModPack.ps1", "script"))
    return out


def strip_comment(line, marks):
    """Отрезает комментарий, если его знак стоит вне кавычек."""
    q = None
    i = 0
    while i < len(line):
        c = line[i]
        if q:
            if c == "\\" and q != "'":
                i += 2
                continue
            if c == q:
                q = None
        elif c in "\"'":
            q = c
        else:
            for m in marks:
                if line.startswith(m, i):
                    return line[:i]
        i += 1
    return line


STR_DQ = re.compile(r'"((?:[^"\\]|\\.)*)"')
STR_SQ = re.compile(r"'((?:[^'\\]|\\.)*)'")


def strings_of(line, kind):
    if kind == "cs":
        code = strip_comment(line, ("//",))
        return STR_DQ.findall(code)
    if kind == "lua":
        if line.lstrip().startswith("--"):
            return []
        code = strip_comment(line, ("--",))
        return STR_DQ.findall(code) + STR_SQ.findall(code)
    if kind == "script":
        s = line.lstrip()
        if s.startswith("#") or s.lower().startswith("rem ") or s.startswith("::"):
            return []
        code = strip_comment(line, (" #",))
        found = STR_DQ.findall(code) + STR_SQ.findall(code)
        # echo в cmd без кавычек: весь хвост строки — текст игроку
        m = re.match(r"\s*@?echo\s+(.*)", line, re.I)
        if m and not found:
            found = [m.group(1)]
        return found
    if kind == "tsv":
        # Строка с «#» в начале — заметка агента о таблице (источник, слово владельца), в игру не идёт.
        if line.startswith("#"):
            return []
        cols = line.rstrip("\n").split("\t")
        return [c for c in cols[1:] if CYR.search(c)] if len(cols) > 1 else []
    if kind in ("md", "txt"):
        return [line]
    return [line]


# Вызовы журнала: строки внутри них читает только агент (UE4SS.log, журнал лаунчера), игрок их не видит.
LOG_CALLS = {"cs": ("Log", "LogLine"), "lua": ("log", "say", "print", "note", "error", "dbg", "counted")}


def code_strings(text, kind):
    """Строковые литералы файла C# или Lua: (номер строки, текст, внутри вызова журнала?). Комментарии пропускаются."""
    out, i, line, n = [], 0, 1, len(text)
    line_cmt = "//" if kind == "cs" else "--"
    stack = []  # на каждую открытую скобку: True, если это вызов журнала
    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            i += 1
            continue
        if text.startswith(line_cmt, i):
            # Длинный комментарий Lua: --[[ … ]] и с уровнем --[==[ … ]==].
            lb = re.match(r"\[(=*)\[", text[i + 2:i + 12]) if kind == "lua" else None
            if lb:
                close = "]" + lb.group(1) + "]"
                j = text.find(close, i)
                j = n if j < 0 else j + len(close)
            else:
                j = text.find("\n", i)
                j = n if j < 0 else j
            line += text.count("\n", i, j)
            i = j
            continue
        if kind == "cs" and text.startswith("/*", i):
            j = text.find("*/", i)
            j = n if j < 0 else j + 2
            line += text.count("\n", i, j)
            i = j
            continue
        # Символьный литерал C# ('"', '\\', '\'', ' ') пропускается целиком: кавычка внутри '"' открывала «строку», и разбор до следующей
        # кавычки забирал код и русские комментарии (KrinikConanGames.cs:248 Trim('"') — выпуск RC1 2026-11-20 15:09 встал на 7 ложных строках). [NOT-TESTED]
        if kind == "cs" and c == "'":
            m = re.match(r"'(?:\\u[0-9A-Fa-f]{4}|\\.|[^'\\\n])'", text[i:i + 8])
            if m:
                i += len(m.group(0))
                continue
        if c in "\"'" and (kind == "lua" or c == '"'):
            verbatim = kind == "cs" and i > 0 and text[i - 1] == "@"
            j, buf, start = i + 1, [], line
            while j < n and text[j] != c:
                if text[j] == "\\" and not verbatim:
                    buf.append(text[j:j + 2])
                    j += 2
                    continue
                if text[j] == "\n":
                    line += 1
                buf.append(text[j])
                j += 1
            out.append((start, "".join(buf), any(stack)))
            i = j + 1
            continue
        if kind == "lua" and text.startswith("[[", i):
            j = text.find("]]", i)
            j = n if j < 0 else j
            out.append((line, text[i + 2:j], any(stack)))
            line += text.count("\n", i, j)
            i = j + 2
            continue
        if c == "(":
            k = i - 1
            while k >= 0 and text[k] in " \t":
                k -= 1
            m = re.search(r"[A-Za-z_][A-Za-z_0-9]*$", text[max(0, k - 40):k + 1])
            stack.append(bool(m and m.group(0) in LOG_CALLS[kind]))
        elif c == ")" and stack:
            stack.pop()
        i += 1
    return out


LUA_VALUE = re.compile(r"\]\s*=\s*\[(=*)\[(.*?)\]\1\]", re.S)


def luatable_strings(text):
    """Значения таблицы перевода `[ [=[английский]=] ] = [=[русский]=]`: (номер строки, русский текст). Ключ (английский) не читается."""
    for m in LUA_VALUE.finditer(text):
        yield text.count("\n", 0, m.start(2)) + 1, m.group(2)


def manifest_strings(text):
    """Поле version каждого мода манифеста: (номер строки, значение)."""
    import json
    for mod in json.loads(text).get("mods", []):
        v = mod.get("version")
        if isinstance(v, str) and CYR.search(v):
            at = text.find('"version": ' + json.dumps(v, ensure_ascii=False))
            yield (text.count("\n", 0, at) + 1 if at >= 0 else 0), v


def change_note_strings(text):
    """Каждая строка каждого списка изменений krinik_change_notes.json: (номер строки файла с этим модом, текст строки). [NOT-TESTED]"""
    import json
    for rel, mods in json.loads(text).items():
        block = text.find(json.dumps(rel) + ":")      # the mod's line inside ITS release block (a later release repeats the mod names)
        for mod, note in mods.items():
            at = text.find(json.dumps(mod) + ":", max(block, 0))
            n = text.count("\n", 0, at) + 1 if at >= 0 else 0
            for line in note.split("\n"):
                yield n, line


def html_lines(path):
    raw = path.read_text(encoding="utf-8")
    raw = re.sub(r"<style.*?</style>", lambda m: "\n" * m.group(0).count("\n"), raw, flags=re.S)
    raw = re.sub(r"<script.*?</script>", lambda m: "\n" * m.group(0).count("\n"), raw, flags=re.S)
    raw = re.sub(r"<!--.*?-->", lambda m: "\n" * m.group(0).count("\n"), raw, flags=re.S)
    for n, line in enumerate(raw.split("\n"), 1):
        yield n, html.unescape(re.sub(r"<[^>]+>", " ", line))


# Подпись к таблице и рисунку по ГОСТ 7.32 пишется через тире: «Таблица 1 — Моды сборки». Это норма оформления, глагол там не пропущен.
GOST_CAPTION = re.compile(r"^\s*(Таблица|Рисунок)\s+[0-9А-Я.]+\s+[—–-]\s")


def mod_names():
    """Имена модов из манифеста: тире внутри имени («MSCasaDesFlores — Weapons & Armors») принадлежит автору мода."""
    try:
        import json
        m = json.loads((PACK / "modpack.json").read_text(encoding="utf-8"))
        return sorted({x["name"] for x in m.get("mods", []) if DASH.search(x.get("name", ""))}, key=len, reverse=True)
    except (OSError, ValueError, KeyError):
        return []


MOD_NAMES = mod_names()


def has_dash(s):
    """Тире внутри фразы. Дефис в начале строки (после отступа или после «\\n» внутри строки) — знак пункта списка, не тире."""
    if GOST_CAPTION.match(s):
        s = GOST_CAPTION.sub("", s, count=1)
    for name in MOD_NAMES:
        s = s.replace(name, "МОД")
    for m in DASH.finditer(s):
        head = re.split(r"\n|\\n", s[:m.start() + 1])[-1]
        if head.strip():
            return True
    return False


def load_allow():
    allow = set()
    if ALLOW_FILE.exists():
        for line in ALLOW_FILE.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                allow.add(line.split("\t")[0].strip())
    return allow


def main(argv):
    only = argv[argv.index("--only") + 1] if "--only" in argv else None
    allow = load_allow()
    hits, files_read = [], 0
    for path, kind in sources():
        if only and only not in str(path).replace("\\", "/"):
            continue
        # --skip-mod-tables: без таблиц перевода чужих модов (ru_table.lua KrinikRU / HosavRU и asset-strings) — их вычитка в следующей версии по слову
        # владельца 2026-11-20 09:47; все наши строки (лаунчер, Lua-моды Krinik, скрипты, README, списки изменений, руководство) проверяются (судья
        # 2026-11-20, круг 7, находка 3: ворота PDF с --only guide теряли их). [NOT-TESTED]
        if "--skip-mod-tables" in argv and (kind == "luatable" or "asset-strings" in str(path).replace("\\", "/")):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="strict")
            if kind == "html":
                lines = list(html_lines(path))
        except (OSError, UnicodeDecodeError) as e:
            print(f"не прочитан {path}: {e}", file=sys.stderr)
            return 2
        files_read += 1
        if "--list-files" in argv:
            print(path)
        if kind in ("cs", "lua"):
            for n, s, in_log in code_strings(text, kind):
                if in_log and "--with-logs" not in argv:
                    continue
                if CYR.search(s) and has_dash(s) and s.strip() not in allow:
                    hits.append((path, n, s.strip()))
            continue
        if kind in ("luatable", "manifest", "notes"):
            gen = {"luatable": luatable_strings, "manifest": manifest_strings, "notes": change_note_strings}[kind]
            for n, s in gen(text):
                if CYR.search(s) and has_dash(s) and s.strip() not in allow:
                    hits.append((path, n, s.strip()))
            continue
        if kind != "html":
            lines = list(enumerate(text.split("\n"), 1))
        for n, line in lines:
            for s in strings_of(line, "md" if kind == "html" else kind):
                if CYR.search(s) and has_dash(s) and s.strip() not in allow:
                    hits.append((path, n, s.strip()))
    by_file = {}
    for path, n, s in hits:
        by_file.setdefault(path, []).append((n, s))
    for path, rows in by_file.items():
        rel = path.relative_to(PACK) if PACK in path.parents else path
        print(f"\n{rel} — {len(rows)}")
        for n, s in rows:
            # Строка печатается целиком, с переводами строк как «\n» (находка D5). Скопировать такую строку в список разрешённых пока нельзя:
            # load_allow не превращает «\n» обратно в перевод строки (судья 2026-11-18, находка 8; KUMM plans/58).
            print(f"  {n}: {s.replace(chr(10), chr(92) + 'n')}")
    print(f"\nфайлов прочитано {files_read}, строк с тире {len(hits)}")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
