"""
Сборка документов поставки одной командой: ридми (путеводитель 3.0.1) → PDF и лаунчер → exe.
Слово владельца 2026-10-31 15:39: «скрипты сделать, или один, который Ридпи собирает и рендерит в пдф, и собирает лаунчер exe» ·
«иногда буду пересобирать я сам скриптом» — поэтому вход ещё и двойным щелчком: «Собрать ридми и лаунчер.cmd» в корне сборки.

Шаги:
  1. author_links.txt → ссылки автора (разбор один — author_links.py; кривая строка останавливает сборку с номером строки).
  2. docs/guide/guide-3.1.1.html: раздел между метками AUTHOR_LINKS:BEGIN/END пересобирается из ссылок (остальной текст не трогается).
  3. Chrome без окна печатает PDF по пути "guide" из modpack.json (свой временный профиль — окно владельца не трогается).
  4. _config/launcher/BuildInfo.g.cs (версия сборки packVersion + те же ссылки) и компилятор C# из Visual Studio 2022
     собирает _config/launcher/bin/KrinikLauncher.exe против .NET Framework 4.x, встроенного в Windows.
Запуск: python _config/release/build-docs.py [--no-pdf] [--no-launcher]
[TESTED: 2026-10-31 · --no-pdf run: guide HTML unchanged, launcher built with the frame strips and fonts; the PDF step not run this time]
"""
import html
import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from author_links import SEPARATOR, LinksError, parse  # noqa: E402

PACK = Path(__file__).resolve().parents[2]
LINKS_FILE = PACK / "author_links.txt"
MANIFEST = PACK / "modpack.json"
GUIDE_HTML = PACK / "docs" / "guide" / "guide-3.1.1.html"
LAUNCHER_DIR = PACK / "_config" / "launcher"
LAUNCHER_SRC = LAUNCHER_DIR / "KrinikConanLauncher.cs"
# Лента выпусков, самообновление лаунчера и обновление сборки (KUMM plan 54) — свой файл рядом с окном.
LAUNCHER_UPDATES_SRC = LAUNCHER_DIR / "KrinikConanUpdates.cs"
# Самостоятельный лаунчер (KUMM plans/57): поиск игры, слова окна на двух языках, части окна по макетам KUIPS.
# KrinikConanVersion.cs — номер выпуска с порядком кандидатов RC1 < RC2 < 0.9.1 (KUMM plans/55 phase E; проверка — launcher/test/version_order.cs).
# KrinikConanDelta.cs — обновление по списку файлов выпуска (KUMM plans/57, фаза 6).
LAUNCHER_MORE_SRC = [LAUNCHER_DIR / n for n in ("KrinikConanGames.cs", "KrinikConanText.cs", "KrinikConanWidgets.cs", "KrinikConanVersion.cs", "KrinikConanDelta.cs")]
BUILD_INFO = LAUNCHER_DIR / "BuildInfo.g.cs"
LAUNCHER_EXE = LAUNCHER_DIR / "bin" / "KrinikConanLauncher.exe"
LAUNCHER_RES_DIR = LAUNCHER_DIR / "res"
LAUNCHER_RES = ("wallpaper.jpg", "logo-game.png", "logo-pack.png", "frame_h.png", "frame_v.png",
                "oswald_600.ttf", "oswald_500.ttf", "oswald_400.ttf", "inter_400.ttf")
# Иконка exe — вариант 1 буквы K (владелец 2026-10-31 20:43: «иконки поставляем обе, первая по дефолту»); делает _config/branding/make_icons.py (картинки — в art/icons).
LAUNCHER_ICON = PACK / "art" / "icons" / "krinik_build_icon_1.ico"

BEGIN = "<!-- AUTHOR_LINKS:BEGIN"
END = "<!-- AUTHOR_LINKS:END -->"
CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
]
VSWHERE = Path(r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe")
FRAMEWORK_DIR = Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319")
CHROME_TIMEOUT_S = 120
PDF_WAIT_STEPS, PDF_WAIT_STEP_S = 30, 0.5   # up to 15 s for Chrome's child to finish the PDF after the parent returned
CSC_TIMEOUT_S = 120


def fail(msg):
    print("ОШИБКА: " + msg, file=sys.stderr)
    sys.exit(1)


def render_links_html(links):
    rows = [f'    <li>{html.escape(l["text"])}{SEPARATOR}<a href="{html.escape(l["url"], quote=True)}">{html.escape(l["label"])}</a></li>'
            for l in links]
    return "\n".join(rows)


def update_guide(links):
    text = GUIDE_HTML.read_text(encoding="utf-8")
    b, e = text.find(BEGIN), text.find(END)
    if b < 0 or e < b:
        fail(f"в {GUIDE_HTML.name} нет меток {BEGIN} … {END} — некуда класть ссылки")
    head_end = text.index("-->", b) + len("-->")
    new = text[:head_end] + "\n" + render_links_html(links) + "\n    " + text[e:]
    if new != text:
        GUIDE_HTML.write_text(new, encoding="utf-8", newline="\n")
    print(f"ридми: ссылок автора — {len(links)} → {GUIDE_HTML.relative_to(PACK)}")


def print_pdf(pdf):
    chrome = next((c for c in CHROME_CANDIDATES if c.exists()), None)
    if not chrome:
        fail("не найден Chrome — PDF печатать нечем")
    pdf.parent.mkdir(parents=True, exist_ok=True)
    before = pdf.stat().st_mtime if pdf.exists() else 0
    # Свой временный профиль: с общим профилем Chrome отдаёт задание уже открытому окну владельца и выходит без PDF.
    with tempfile.TemporaryDirectory(prefix="krinik-pdf-", ignore_cleanup_errors=True) as profile:
        subprocess.run([str(chrome), "--headless=new", "--disable-gpu", "--no-pdf-header-footer", f"--user-data-dir={profile}",
                        f"--print-to-pdf={pdf}", GUIDE_HTML.as_uri()],
                       check=False, timeout=CHROME_TIMEOUT_S, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Chrome may return before its child finished writing: 2026-11-10 12:44 the check said «не напечатал», and the PDF was there a moment later — wait for it
    for _ in range(PDF_WAIT_STEPS):
        if pdf.exists() and pdf.stat().st_mtime > before and pdf.stat().st_size > 0:
            break
        time.sleep(PDF_WAIT_STEP_S)
    if not pdf.exists() or pdf.stat().st_mtime <= before or pdf.stat().st_size == 0:
        fail(f"Chrome не напечатал {pdf}")
    print(f"PDF: {pdf.relative_to(PACK)} ({pdf.stat().st_size // 1024} КБ)")


def cs(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def launcher_fields(manifest):
    # manifest.launcher (KUMM plan 54): своя версия лаунчера, версия игры и её заметки в Steam, репозиторий ленты выпусков.
    fields = manifest.get("launcher") or {}
    missing = [k for k in ("version", "gameVersion", "gameNotes", "feedRepo") if not fields.get(k)]
    if missing:
        fail("в modpack.json нет launcher." + ", launcher.".join(missing) + " — лаунчеру не из чего взять версии и адреса")
    return fields


def write_build_info(links, version, uninstall_cmd, guide_pdf, launcher):
    # Лаунчер пишет короткий текст ссылки (author_links.txt: "Длинный"|"Короткий"[…](…)), ридми — длинный.
    rows = ",\n".join(f"        new Link({cs(l['short'])}, {cs(l['label'])}, {cs(l['url'])})" for l in links)
    BUILD_INFO.write_text(
        "// СГЕНЕРИРОВАНО _config/release/build-docs.py из author_links.txt и modpack.json — руками не править.\n"
        "static class BuildInfo\n{\n"
        f"    public const string PackVersion = {cs(version)};\n"
        f"    public const string LauncherVersion = {cs(launcher['version'])};\n"
        f"    public const string GameVersion = {cs(launcher['gameVersion'])};\n"
        f"    public const string GameNotes = {cs(launcher['gameNotes'])};\n"
        f"    public const string FeedRepo = {cs(launcher['feedRepo'])};\n"
        f"    public const string UninstallCmd = {cs(uninstall_cmd)};\n"
        # Имя PDF руководства в корне архива — то, под которым его кладёт Deploy-ModPack.ps1 -Export (лист пути manifest.guide).
        f"    public const string GuidePdf = {cs(guide_pdf)};\n"
        f"    public const string Separator = {cs(SEPARATOR)};\n"
        "    public sealed class Link { public readonly string Text, Label, Url;"
        " public Link(string t, string l, string u) { Text = t; Label = l; Url = u; } }\n"
        f"    public static readonly Link[] AuthorLinks =\n    {{\n{rows}\n    }};\n}}\n",
        encoding="utf-8-sig", newline="\r\n")


def find_csc():
    if VSWHERE.exists():
        out = subprocess.run([str(VSWHERE), "-latest", "-products", "*", "-property", "installationPath"],
                             capture_output=True, text=True).stdout.strip()
        for root in out.splitlines():
            csc = Path(root) / "MSBuild" / "Current" / "Bin" / "Roslyn" / "csc.exe"
            if csc.exists():
                return csc
    fail("не найден компилятор C# из Visual Studio (MSBuild\\Current\\Bin\\Roslyn\\csc.exe) — лаунчер собрать нечем")


def build_launcher(links, version, uninstall_cmd, guide_pdf, launcher):
    write_build_info(links, version, uninstall_cmd, guide_pdf, launcher)
    LAUNCHER_EXE.parent.mkdir(parents=True, exist_ok=True)
    # System.Web.Extensions — разбор JSON ленты и pack/modpack.json; System.IO.Compression — распаковка частей сборки; System.Core — для обоих.
    refs = [f"-r:{FRAMEWORK_DIR / d}" for d in ("System.dll", "System.Core.dll", "System.Drawing.dll", "System.Windows.Forms.dll",
                                                  "System.Web.Extensions.dll", "System.IO.Compression.dll")]
    # Картинки окна (res/, их делает _config/launcher/make-res.py) встраиваются в exe: игроку — один файл, рядом ничего не теряется.
    # Имя ресурса — «res.<файл>», так их и ищет лаунчер.
    missing = [n for n in LAUNCHER_RES if not (LAUNCHER_RES_DIR / n).exists()]
    if missing:
        fail(f"нет картинок лаунчера {missing} в {LAUNCHER_RES_DIR} — запустите _config/launcher/make-res.py")
    res = [f"-resource:{LAUNCHER_RES_DIR / n},res.{n}" for n in LAUNCHER_RES]
    if not LAUNCHER_ICON.exists():
        fail(f"нет иконки {LAUNCHER_ICON} — запустите _config/branding/make_icons.py")
    # Та же иконка — ещё и ресурсом exe: окно ставит её себе (Form.Icon), иначе панель задач показывала стандартную иконку WinForms, хотя у exe и ярлыка
    # иконка сборки (владелец 2026-11-17 21:02: «что за ярлык некрасивый у лаунчера на панели задач???»). Все размеры .ico (16–256) — чётко при 300 %.
    res.append(f"-resource:{LAUNCHER_ICON},res.app.ico")
    # -deterministic: одинаковый исходник даёт одинаковый exe байт в байт — проверяющий Nexus сверяет SHA-256 своей сборки с нашей (карантин 0.9.0,
    # тикет 276571: без флага компилятор вшивал в каждую сборку свою метку, и хеш чистой сборки из GitHub не совпадал с выпуском, 2026-11-06).
    # [TESTED: 2026-11-06 · two builds from a fresh public clone, the same SHA-256 d1d43330… · KUMM testcases/reports/2026-11-06_conan-launcher-deterministic-build.md]
    r = subprocess.run([str(find_csc()), "-nologo", "-target:winexe", "-langversion:latest", "-optimize+", "-deterministic", "-utf8output",
                        f"-out:{LAUNCHER_EXE}", f"-win32icon:{LAUNCHER_ICON}", *refs, *res, str(LAUNCHER_SRC), str(LAUNCHER_UPDATES_SRC), *map(str, LAUNCHER_MORE_SRC), str(BUILD_INFO)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=CSC_TIMEOUT_S)
    if r.returncode != 0:
        fail("компилятор C#:\n" + r.stdout + r.stderr)
    # make_variant.py (KUMM plan 54) builds into a folder outside the pack: the path is printed whole then.
    shown = LAUNCHER_EXE.relative_to(PACK) if LAUNCHER_EXE.is_relative_to(PACK) else LAUNCHER_EXE
    print(f"лаунчер: {shown} ({LAUNCHER_EXE.stat().st_size // 1024} КБ), версия сборки {version}, лаунчера {launcher['version']}")


def main():
    # «Собрать ридми и лаунчер.cmd» ставит консоль в UTF-8 (chcp 65001); без этого русские строки выходят кракозябрами.
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    args = set(sys.argv[1:])
    try:
        links = parse(LINKS_FILE)
    except LinksError as e:
        fail(str(e))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    update_guide(links)
    pdf_refused = None
    if "--no-pdf" not in args:
        # Перед печатью — проверки текста: запрещённые классы фраз (guide_lint.py; её заголовок обещал этот вызов с 2026-10-31, а вызова не было —
        # найдено 2026-11-18) и тире вместо глагола во всех русских строках сборки (dash_lint.py, KUMM HOUSE_RULES 33). Красная — PDF не печатается.
        # Красная проверка не даёт печатать PDF, но лаунчер собирается дальше: двойной щелчок владельца по build_docs_and_launcher.cmd не должен
        # терять лаунчер из-за неразобранного перевода модов (судья 2026-11-18, риск 9). В конце сборка выходит с кодом 1 и называет причину.
        # [NOT-TESTED]
        # Тире проверяется во всех строках сборки, кроме таблиц перевода чужих модов (ru_table, asset-strings): их по слову владельца 2026-11-20 09:47
        # (KUMM, хроника 2026-11-20 09:47) вычитывают в следующей версии; с ними PDF 0.9.1 не печатался вовсе (349 строк KrinikRU, выпуск RC1
        # 2026-11-20 15:12), а ворота «только руководство» теряли наши строки (судья 2026-11-20, круг 7, находка 3). Весь список — `python dash_lint.py`. [NOT-TESTED]
        for lint in (["guide_lint.py", str(GUIDE_HTML)], ["dash_lint.py", "--skip-mod-tables"]):
            r = subprocess.run([sys.executable, "-I", "-X", "utf8", str(Path(__file__).with_name(lint[0]))] + lint[1:], cwd=PACK)
            if r.returncode != 0:
                pdf_refused = f"{lint[0]}: текст руководства или строки сборки не прошли проверку, PDF не напечатан"
                print(f"ВНИМАНИЕ: {pdf_refused}")
                break
        else:
            print_pdf(PACK / manifest["guide"])
    if "--no-launcher" not in args:
        # Строки лаунчера проверяются и на пути --no-pdf, которым собирается каждый лаунчер (судья 2026-11-18 01:40, находка D4): тире вместо
        # глагола в окне игрока не уходит в сборку. Проверяются только исходники лаунчера, поэтому неразобранный перевод модов сборку не держит.
        # [NOT-TESTED]
        r = subprocess.run([sys.executable, "-I", "-X", "utf8", str(Path(__file__).with_name("dash_lint.py")), "--only", "_config/launcher"], cwd=PACK)
        if r.returncode != 0:
            fail("dash_lint.py: в строках лаунчера тире вместо глагола — лаунчер не собираю")
        # Имя деинсталлятора — то же, что раскатка кладёт в корень игры (manifest.uninstall.cmd, KUMM bugs/72).
        build_launcher(links, manifest["packVersion"], manifest["uninstall"]["cmd"], Path(manifest["guide"]).name, launcher_fields(manifest))
    if pdf_refused:
        fail(f"{pdf_refused}; лаунчер собран")
    print("Готово.")


if __name__ == "__main__":
    main()
