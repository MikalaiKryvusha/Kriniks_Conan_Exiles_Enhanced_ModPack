"""build-archive.py -- собрать архив мода ровно в том виде, в каком его качают.

ЧТО ВНУТРИ И ПОЧЕМУ ИМЕННО ЭТО. Инструкция на странице говорит: положите папку
ConanCameraControl в ue4ss\\Mods\\. Значит в архиве ОДНА папка с этим именем, и
в ней только то, что нужно игре, плюс README. Мастерская - страница, логотипы,
кадры, схемы, отладочный канал agent-cmd.txt и резервные копии конфига - в
архив не идёт: каждый лишний файл там это вопрос от скачавшего.

ДВА ЗНАЧЕНИЯ КОНФИГА МЕНЯЮТСЯ ПРИ СБОРКЕ, и оба названы вслух:

  camera_pitch   -> 0.0    В рабочем конфиге стоит 4.0, и это СЛЕД от нажатия,
                           а не выбор. Ноль - та посадка (подъём 65, дистанция
                           190, наклон 0), которую владелец принял словами
                           "с камерой всё супппер"; её же держит preset_pitch.
  logging_enabled -> false  Для нас журнал инструмент, для скачавшего - строка
                           в UE4SS.log каждую секунду.

ПРОВЕРКА ВХОДИТ В СБОРКУ. Архив распаковывается во временную папку, набор
файлов сверяется со списком, а содержимое - с источником побайтно. Архив,
который никто не раскрыл, - это надежда, а не поставка.

    python build-archive.py [--version 1.0.0]
"""

import filecmp
import hashlib
import io
import os
import shutil
import sys
import tempfile
import zipfile

PACK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..",
                                    "_unpacked", "ConanCameraControl"))
OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..",
                                       "_unpacked"))
MOD = "ConanCameraControl"

PAYLOAD = ["Scripts/main.lua", "config.lua", "enabled.txt"]

README = """Camera Behind - Third Person Camera Control
ConanCameraControl, a Lua mod for UE4SS

WHAT IT DOES
  Puts the third-person camera directly behind your character instead of over
  the shoulder, and gives you full control of the zoom range. Character,
  camera and crosshair line up, so you see what you aim at. Everything is
  tuned live on the numpad and saved automatically.

REQUIREMENTS
  Conan Exiles Enhanced (UE 5.6). Not for the legacy UE4 version.
  UE4SS - tested on 3.0.1 build 1127: https://github.com/UE4SS-RE/RE-UE4SS
  Singleplayer. Not tested on servers.

INSTALLATION
  1. Install UE4SS into ConanSandbox\\Binaries\\Win64.
  2. Drop this ConanCameraControl folder into
     ConanSandbox\\Binaries\\Win64\\ue4ss\\Mods\\
  3. Add "ConanCameraControl : 1" to ue4ss\\Mods\\mods.txt, or just keep the
     enabled.txt that ships in this folder.
  4. Start the game.

  DO NOT USE UE4SS HOT RELOAD (Ctrl+R) ON THIS MOD. It stacks the mod's timer
  loop instead of replacing it, and the game will come down after a while.
  Restart the game instead.

CONTROLS - NUMPAD (NumLock on)
  8 / 2          camera back / forward
  4 / 6          camera left / right
  9 / 3          camera up / down
  7 / 1          pivot up / down
  5              centre it - zero the sideways offset
  + / -          distance
  /              save the current setup
  0              restore the saved setup
  Ctrl + 8/2, 4/6, 9/3   move the PIVOT instead of the camera
  Ctrl + 5       reset the pivot
  Ctrl + 0       re-acquire the camera component (emergency)

  The * key is left free on purpose - the game uses it for chat.

CAMERA OFFSET VS PIVOT
  SocketOffset moves THE CAMERA and rides along when you turn, so the
  character keeps its place on screen. TargetOffset moves THE ORBIT CENTRE in
  world space, so the character sits lower in frame - which is how the classic
  TES IV: Oblivion framing is built. Neither turns the camera: aim always
  follows the mouse.

COMPATIBILITY NOTE - ENHANCED ARMORY AND ARSENAL
  EAA ships its own "Extended Camera Zoom" and takes the spring arm over,
  which breaks the zoom limit. This mod detects it and stops just its camera
  component; the rest of EAA keeps working. Set mute_foreign_camera = false in
  config.lua if you prefer EAA's zoom.

CONFIG
  config.lua holds every value and is rewritten by the mod itself whenever you
  tune something on the numpad. Comments you add there will not survive.

CREDITS
  Built by Krinik with Claude (Anthropic). Free to use and to learn from.
"""


def normalise_config(text):
    """Два умышленных изменения, всё остальное - как в рабочем конфиге."""
    changes = []
    for key, want in (("camera_pitch", "0.0"), ("logging_enabled", "false")):
        found = False
        lines = []
        for line in text.split("\n"):
            stripped = line.strip()
            if stripped.startswith(key + " ="):
                had = stripped.split("=", 1)[1].strip().rstrip(",")
                lines.append("    %s = %s," % (key, want))
                changes.append("%s: %s -> %s" % (key, had, want))
                found = True
            else:
                lines.append(line)
        if not found:
            raise SystemExit("в конфиге нет ключа %s - сборка остановлена" % key)
        text = "\n".join(lines)
    return text, changes


def main(argv):
    version = argv[argv.index("--version") + 1] if "--version" in argv else "1.0.0"
    zip_path = os.path.join(OUT_DIR, "%s-%s.zip" % (MOD, version))

    for rel in PAYLOAD:
        src = os.path.join(PACK, rel.replace("/", os.sep))
        if not os.path.exists(src):
            raise SystemExit("нет файла полезной нагрузки: %s" % src)

    cfg_src = io.open(os.path.join(PACK, "config.lua"), encoding="utf-8").read()
    cfg_out, changes = normalise_config(cfg_src)
    for c in changes:
        print("конфиг · %s" % c)

    if os.path.exists(zip_path):
        os.remove(zip_path)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(os.path.join(PACK, "Scripts", "main.lua"),
                "%s/Scripts/main.lua" % MOD)
        z.writestr("%s/config.lua" % MOD, cfg_out)
        z.writestr("%s/enabled.txt" % MOD, "")
        z.writestr("%s/README.txt" % MOD, README)

    # --- ПРОВЕРКА: раскрыть и сверить
    expected = {"%s/Scripts/main.lua" % MOD, "%s/config.lua" % MOD,
                "%s/enabled.txt" % MOD, "%s/README.txt" % MOD}
    with zipfile.ZipFile(zip_path) as z:
        names = set(n for n in z.namelist() if not n.endswith("/"))
        if names != expected:
            raise SystemExit("набор файлов не тот:\n  лишнее: %s\n  нет: %s"
                             % (sorted(names - expected), sorted(expected - names)))
        tmp = tempfile.mkdtemp()
        try:
            z.extractall(tmp)
            got = os.path.join(tmp, MOD, "Scripts", "main.lua")
            want = os.path.join(PACK, "Scripts", "main.lua")
            if not filecmp.cmp(got, want, shallow=False):
                raise SystemExit("main.lua в архиве не совпадает с источником")
            cfg = io.open(os.path.join(tmp, MOD, "config.lua"),
                          encoding="utf-8").read()
            for key, want_v in (("camera_pitch", "0.0"),
                                ("logging_enabled", "false")):
                if ("%s = %s," % (key, want_v)) not in cfg:
                    raise SystemExit("в распакованном конфиге нет %s = %s"
                                     % (key, want_v))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    size = os.path.getsize(zip_path)
    sha = hashlib.sha256(io.open(zip_path, "rb").read()).hexdigest()
    print()
    print("архив: %s" % zip_path)
    print("файлов: %d · размер: %.1f КБ" % (len(expected), size / 1024.0))
    print("sha256: %s" % sha)
    print("раскрыт и сверен: набор файлов и main.lua побайтно, конфиг по двум ключам")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
