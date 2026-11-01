#!/usr/bin/env python3
"""
Раскатка конфигов сборки в папку игры.

[TESTED: 2026-09-08 · сухой прогон показал план из 4 файлов, боевой записал все
четыре, каждый сверен по sha256 после записи. Сторож "игра запущена" проверен
МУТАЦИЕЙ: список BLOCKING подменён на заведомо живой процесс (explorer) - скрипт
отказался работать и назвал причину.
GAP: мутация доказала механизм разбора tasklist, но не то, что строка
"ConanSandbox-Win64-Shipping.exe" в нём выглядит именно так. Совпадение имени
проверяется первым же запуском при живой игре.]

ЗАЧЕМ ОТДЕЛЬНЫЙ СКРИПТ, А НЕ COPY-ITEM РУКАМИ. Игра ПЕРЕПИСЫВАЕТ все пять ini
при выходе - наблюдение 08.09.2026: файлы Engine/Game/GameUserSettings/Input/
ServerSettings несут одну метку 0:01:58, момент закрытия сессии 23:56->00:01.
Значит правка на живой игре гарантированно теряется, и копирование обязано
сначала убедиться, что игра закрыта. Ручное копирование этого не проверяет.

Второе: перед каждой раскаткой снимается копия ТОГО, ЧТО СЕЙЧАС В ИГРЕ. Игра
могла сама переписать значения (автодетект качества), и без копии узнать, что
именно она изменила, будет нечем.

Запуск:
    python _config/deploy-config.py            - раскатать
    python _config/deploy-config.py --dry-run  - только показать план
    python _config/deploy-config.py Game.ini GameUserSettings.ini  - только названные файлы
        (2026-10-25, 3.0.1: старый Input.ini с привязками UE 5.6 в игру на UE 5.8 с новой системой
        ввода не везём, а Game.ini и GameUserSettings.ini - везём)
"""
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PACK = Path(__file__).resolve().parent.parent
CFG = PACK / "_config"
BACKUP_ROOT = CFG / "backup"

# Что раскатываем. Порядок значения не имеет, но список закрытый: файл, которого
# здесь нет, в игру не попадёт даже если лежит в _config/.
FILES = ["Engine.ini", "Game.ini", "GameUserSettings.ini", "Input.ini"]
# Engine.ini живёт в моде графики (слово владельца 2026-10-30: «всё по графике Krinik сведём в один мод KrinikConanGraphics»
# · «у нас и Engine.ini поставляется»); остальные файлы — в _config/.
SOURCES = {"Engine.ini": PACK / "_unpacked" / "KrinikConanGraphics" / "Engine.ini"}

# Имена процессов, при которых раскатка запрещена.
BLOCKING = ["ConanSandbox-Win64-Shipping", "ConanSandbox", "FuncomLauncher"]

CONFIG_REL = "ConanSandbox/Saved/Config/Windows"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


def game_config_dir():
    data = json.loads((PACK / "targets.json").read_text(encoding="utf-8"))
    for t in data.get("targets", []):
        if t.get("enabled", True):
            return Path(t["path"]) / CONFIG_REL
    raise SystemExit("В targets.json нет включённых целей")


def running():
    """Живые процессы игры. Пустой список - можно раскатывать."""
    out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"],
                         capture_output=True, text=True, encoding="cp866",
                         errors="ignore").stdout
    alive = []
    for name in BLOCKING:
        if f'"{name}.exe"' in out:
            alive.append(name)
    return alive


def main():
    dry = "--dry-run" in sys.argv
    dst_dir = game_config_dir()
    if not dst_dir.is_dir():
        raise SystemExit(f"Папка конфигов игры не найдена: {dst_dir}")

    alive = running()
    if alive:
        raise SystemExit(
            "ОТКАЗ: игра запущена (" + ", ".join(alive) + "). "
            "Она перепишет конфиги при выходе, и раскатка пропадёт. Закрой игру.")

    stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    backup = BACKUP_ROOT / stamp

    print(f"цель:   {dst_dir}")
    print(f"копия:  {backup}{' (не создаётся: --dry-run)' if dry else ''}\n")
    print(f"{'файл':24} {'в игре':>18} {'станет':>18}   действие")
    print("-" * 78)

    if not dry:
        backup.mkdir(parents=True, exist_ok=True)

    only = [a for a in sys.argv[1:] if a.endswith(".ini")]
    unknown = [a for a in only if a not in FILES]
    if unknown:
        raise SystemExit("Нет в списке раскатки: " + ", ".join(unknown))
    changed = 0
    for name in (only or FILES):
        src = SOURCES.get(name, CFG / name)
        dst = dst_dir / name
        if not src.exists():
            print(f"{name:24} {'-':>18} {'-':>18}   ПРОПУСК: нет файла сборки {src}")
            continue
        old = sha(dst) if dst.exists() else "нет файла"
        new = sha(src)
        if old == new:
            print(f"{name:24} {old:>18} {new:>18}   совпадает")
            continue
        changed += 1
        if dry:
            print(f"{name:24} {old:>18} {new:>18}   БУДЕТ ЗАПИСАН")
            continue
        if dst.exists():
            shutil.copy2(dst, backup / name)
        shutil.copy2(src, dst)
        got = sha(dst)
        ok = "ЗАПИСАН" if got == new else f"ОШИБКА: получилось {got}"
        print(f"{name:24} {old:>18} {new:>18}   {ok}")

    print("-" * 78)
    print(f"изменено файлов: {changed}")
    if not dry and changed:
        print(f"откат: скопировать обратно из {backup}")
    if not dry and not changed:
        shutil.rmtree(backup, ignore_errors=True)


if __name__ == "__main__":
    main()
