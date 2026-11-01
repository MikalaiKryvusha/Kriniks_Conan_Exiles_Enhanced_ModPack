"""
Сборка документов поставки одной командой: ридми (путеводитель 3.0.1) → PDF и лаунчер → exe.
Слово владельца 2026-10-31 15:39: «скрипты сделать, или один, который Ридпи собирает и рендерит в пдф, и собирает лаунчер exe» ·
«иногда буду пересобирать я сам скриптом» — поэтому вход ещё и двойным щелчком: «Собрать ридми и лаунчер.cmd» в корне сборки.

Шаги:
  1. author_links.txt → ссылки автора (разбор один — author_links.py; кривая строка останавливает сборку с номером строки).
  2. docs/guide/guide-3.0.1.html: раздел между метками AUTHOR_LINKS:BEGIN/END пересобирается из ссылок (остальной текст не трогается).
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
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from author_links import SEPARATOR, LinksError, parse  # noqa: E402

PACK = Path(__file__).resolve().parents[2]
LINKS_FILE = PACK / "author_links.txt"
MANIFEST = PACK / "modpack.json"
GUIDE_HTML = PACK / "docs" / "guide" / "guide-3.0.1.html"
LAUNCHER_DIR = PACK / "_config" / "launcher"
LAUNCHER_SRC = LAUNCHER_DIR / "KrinikConanLauncher.cs"
BUILD_INFO = LAUNCHER_DIR / "BuildInfo.g.cs"
LAUNCHER_EXE = LAUNCHER_DIR / "bin" / "KrinikConanLauncher.exe"
LAUNCHER_RES_DIR = LAUNCHER_DIR / "res"
LAUNCHER_RES = ("wallpaper.jpg", "logo-game.png", "logo-pack.png", "frame_h.png", "frame_v.png",
                "oswald_600.ttf", "oswald_500.ttf", "oswald_400.ttf", "inter_400.ttf")
# Иконка exe — вариант 1 буквы K (владелец 2026-10-31 20:43: «иконки поставляем обе, первая по дефолту»); делает _config/branding/icon/make_icons.py.
LAUNCHER_ICON = PACK / "_config" / "branding" / "icon" / "krinik_build_icon_1.ico"

BEGIN = "<!-- AUTHOR_LINKS:BEGIN"
END = "<!-- AUTHOR_LINKS:END -->"
CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
]
VSWHERE = Path(r"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe")
FRAMEWORK_DIR = Path(r"C:\Windows\Microsoft.NET\Framework64\v4.0.30319")
CHROME_TIMEOUT_S = 120
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
    if not pdf.exists() or pdf.stat().st_mtime <= before or pdf.stat().st_size == 0:
        fail(f"Chrome не напечатал {pdf}")
    print(f"PDF: {pdf.relative_to(PACK)} ({pdf.stat().st_size // 1024} КБ)")


def cs(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_build_info(links, version, uninstall_cmd):
    # Лаунчер пишет короткий текст ссылки (author_links.txt: "Длинный"|"Короткий"[…](…)), ридми — длинный.
    rows = ",\n".join(f"        new Link({cs(l['short'])}, {cs(l['label'])}, {cs(l['url'])})" for l in links)
    BUILD_INFO.write_text(
        "// СГЕНЕРИРОВАНО _config/release/build-docs.py из author_links.txt и modpack.json — руками не править.\n"
        "static class BuildInfo\n{\n"
        f"    public const string PackVersion = {cs(version)};\n"
        f"    public const string UninstallCmd = {cs(uninstall_cmd)};\n"
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


def build_launcher(links, version, uninstall_cmd):
    write_build_info(links, version, uninstall_cmd)
    LAUNCHER_EXE.parent.mkdir(parents=True, exist_ok=True)
    refs = [f"-r:{FRAMEWORK_DIR / d}" for d in ("System.dll", "System.Drawing.dll", "System.Windows.Forms.dll")]
    # Картинки окна (res/, их делает _config/launcher/make-res.py) встраиваются в exe: игроку — один файл, рядом ничего не теряется.
    # Имя ресурса — «res.<файл>», так их и ищет лаунчер.
    missing = [n for n in LAUNCHER_RES if not (LAUNCHER_RES_DIR / n).exists()]
    if missing:
        fail(f"нет картинок лаунчера {missing} в {LAUNCHER_RES_DIR} — запустите _config/launcher/make-res.py")
    res = [f"-resource:{LAUNCHER_RES_DIR / n},res.{n}" for n in LAUNCHER_RES]
    if not LAUNCHER_ICON.exists():
        fail(f"нет иконки {LAUNCHER_ICON} — запустите _config/branding/icon/make_icons.py")
    r = subprocess.run([str(find_csc()), "-nologo", "-target:winexe", "-langversion:latest", "-optimize+", "-utf8output",
                        f"-out:{LAUNCHER_EXE}", f"-win32icon:{LAUNCHER_ICON}", *refs, *res, str(LAUNCHER_SRC), str(BUILD_INFO)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=CSC_TIMEOUT_S)
    if r.returncode != 0:
        fail("компилятор C#:\n" + r.stdout + r.stderr)
    print(f"лаунчер: {LAUNCHER_EXE.relative_to(PACK)} ({LAUNCHER_EXE.stat().st_size // 1024} КБ), версия сборки {version}")


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
    if "--no-pdf" not in args:
        print_pdf(PACK / manifest["guide"])
    if "--no-launcher" not in args:
        # Имя деинсталлятора — то же, что раскатка кладёт в корень игры (manifest.uninstall.cmd, KUMM bugs/72).
        build_launcher(links, manifest["packVersion"], manifest["uninstall"]["cmd"])
    print("Готово.")


if __name__ == "__main__":
    main()
