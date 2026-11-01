# -*- coding: utf-8 -*-
"""rebuild-krinik-paks.py — пересобрать правленые паки чужих модов (KRINIK MODIFIED) по их рецептам и доказать, что внутри ничего не потерялось.

Зачем (2026-10-30, KUMM план 36 п. 14а): наш retoc писал контейнер IoStore без сжатия — правленые паки распухали вдвое-втрое (IMM_WAR 359 → 735 МБ,
Enhanced Armory and Arsenal 131 → 362), а тома архива сборки ≤ 700 МБ (план 35, Г10). Сжатие Oodle добавлено в `_tools/src/retoc` (pack-raw / to-zen
сжимают по умолчанию); паки надо пересобрать. Пересобирать руками по прозе манифеста опасно: строка рецепта, забытая в прозе, молча снимет правку.

Рецепт — машинное поле `krinikBuild` у мода в modpack.json: `{"args": [<Мод>, <Ассет>, <таблица>, <таблица2>, <Ассет2>, …], "env": {…}}` —
аргументы `patch-mod-asset.py build` без <work>. Страж: каждый кусок нового контейнера байт в байт равен куску пака, который стоит в библиотеке
сейчас (меняться может только сжатие), прочие файлы обёртки (кроме .utoc / .ucas / manifest.json) — тоже. Не сошлось — пак не ставится.

    python -I -X utf8 rebuild-krinik-paks.py                 # все, от меньшего к большему: собрать и сверить, ничего не ставя
    python -I -X utf8 rebuild-krinik-paks.py --install       # то же и поставить сошедшиеся в библиотеку и в игру
    python -I -X utf8 rebuild-krinik-paks.py --only Simple_Minimap [--install]
    … --keep                                                  # не убирать черновик сошедшихся (по умолчанию убирается поимённо)
Код 0 — все сошлись; 1 — хоть один не сошёлся или не собрался. Пишет только в черновик (WORK) и, с --install, в библиотеку и папку модов игры.
Черновик сошедшегося мода убирается сразу после сверки (и установки); не сошедшийся остаётся для разбора.
[NOT-TESTED]
"""
import filecmp
import importlib.util
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.dirname(os.path.dirname(HERE))
_spec = importlib.util.spec_from_file_location("pma", os.path.join(HERE, "patch-mod-asset.py"))
pma = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pma)

LIBRARY = r"D:\Games\Conan Exiles Mods\mods"
GAME_MODS = os.path.join(pma.GAME_DIR, r"ConanSandbox\Mods")
WORK = os.environ.get("REBUILD_WORK", r"D:\Temp\kumm-rebuild-krinik")


def unpack_outer(pak, out):
    """Внешний пак → НОВАЯ папка (рекурсивное удаление запрещено правилом дома — каждая сверка пишет в свою); возвращает папку с
    <Мод>-Windows.utoc и сырые куски контейнера."""
    n = 1
    while os.path.exists(f"{out}-{n}"):
        n += 1
    out = f"{out}-{n}"
    pma.run([pma.REPAK, "unpack", "-q", "-s", pma.OUTER_MOUNT, "-o", out, pak])
    files = out if any(f.endswith("-Windows.utoc") for f in os.listdir(out)) else os.path.join(out, "ConanSandbox", "Mods")
    utoc = [f for f in os.listdir(files) if f.endswith("-Windows.utoc")]
    if len(utoc) != 1:
        raise SystemExit(f"{pak}: контейнеров {len(utoc)}, ждали 1")
    raw = os.path.join(out, "_raw")
    pma.run([pma.RETOC, "unpack-raw", os.path.join(files, utoc[0]), raw])
    return files, raw


def same_inside(old_pak, new_pak, work):
    """Куски контейнера и прочие файлы обёртки равны байт в байт. Возвращает (ok, текст)."""
    of, oraw = unpack_outer(old_pak, os.path.join(work, "cmp-old"))
    nf, nraw = unpack_outer(new_pak, os.path.join(work, "cmp-new"))
    oc, nc = sorted(os.listdir(os.path.join(oraw, "chunks"))), sorted(os.listdir(os.path.join(nraw, "chunks")))
    if oc != nc:
        return False, f"наборы кусков разные: {len(oc)} против {len(nc)}"
    diff = [c for c in oc if not filecmp.cmp(os.path.join(oraw, "chunks", c), os.path.join(nraw, "chunks", c), shallow=False)]
    if diff:
        return False, f"куски разошлись: {len(diff)} из {len(oc)} (первый {diff[0]})"
    # Заголовок контейнера (кусок типа 06) игра читает при монтировании как есть, несжатым: сжатый заголовок — «Failed to mount IoStore container …
    # Failed reading 1104 bytes» (Player Ignores Follower Collision, 2026-10-30 00:47; сверка кусков этого не видела — retoc читает и сжатый).
    hdr = [c for c in nc if c.endswith("06")]
    ucas = [f for f in os.listdir(nf) if f.endswith("-Windows.ucas")]   # бывают и серверные -LinuxServer / -WindowsServer (PIFC)
    if len(hdr) != 1 or len(ucas) != 1:
        return False, f"заголовков {len(hdr)}, .ucas {len(ucas)} — ждали по одному"
    if open(os.path.join(nraw, "chunks", hdr[0]), "rb").read() not in open(os.path.join(nf, ucas[0]), "rb").read():
        return False, "заголовок контейнера в .ucas сжат — игра его не смонтирует"
    skip = {"manifest.json"}
    of_ = sorted(f for f in os.listdir(of) if not f.endswith((".utoc", ".ucas")) and f not in skip)
    nf_ = sorted(f for f in os.listdir(nf) if not f.endswith((".utoc", ".ucas")) and f not in skip)
    if of_ != nf_:
        return False, f"файлы обёртки разные: {of_} против {nf_}"
    bad = [f for f in of_ if os.path.isfile(os.path.join(of, f)) and not filecmp.cmp(os.path.join(of, f), os.path.join(nf, f), shallow=False)]
    if bad:
        return False, f"файлы обёртки разошлись: {bad}"
    return True, f"кусков {len(oc)} — байт в байт, файлов обёртки {len(of_)} — равны"


def remove_by_enumeration(top):
    """Рабочая папка сошедшегося мода → убрать поимённо: каждый файл, затем пустые папки снизу вверх (рекурсивное удаление одной
    командой запрещено правилом дома). Зачем (2026-10-30): двенадцать пересборок оставили ≈ 86 ГБ рабочих папок, диск D: дошёл до 33 МБ.
    Ссылку и точку соединения (junction) удаляем как запись, внутрь не заходим: жёсткая ссылка на контейнер игры снимается без вреда
    для файла игры, а пройти по junction значило бы убирать чужую папку. Только внутри WORK — иначе отказ.
    [TESTED: 2026-10-30 · U1–U5 на собранном дереве (жёсткая ссылка, junction, только-чтение, отказ вне WORK) + настоящий прогон SimpleModlist —
    «черновик убран: 66 файлов» · KUMM testcases/reports/2026-10-30_conan-rebuild-cleanup.md]"""
    top = os.path.abspath(top)
    root = os.path.abspath(WORK)
    if os.path.normcase(os.path.commonpath([top, root])) != os.path.normcase(root) or os.path.normcase(top) == os.path.normcase(root):
        raise SystemExit(f"уборка вне черновика отклонена: {top}")
    files = 0
    for e in os.scandir(top):
        junction = getattr(e, "is_junction", lambda: False)()
        if e.is_symlink() or junction:
            (os.rmdir if e.is_dir(follow_symlinks=False) or junction else os.unlink)(e.path)
            files += 1
        elif e.is_dir(follow_symlinks=False):
            files += remove_by_enumeration(e.path)
        else:
            os.chmod(e.path, 0o666)   # retoc и repak иногда оставляют файлы только для чтения
            os.remove(e.path)
            files += 1
    os.rmdir(top)
    return files


def mb(p):
    return os.path.getsize(p) / 1048576


def main():
    install = "--install" in sys.argv
    keep = "--keep" in sys.argv
    only = sys.argv[sys.argv.index("--only") + 1] if "--only" in sys.argv else None
    manifest = json.load(open(os.path.join(PACK, "modpack.json"), encoding="utf-8"))
    jobs = []
    for m in manifest["mods"]:
        rb = m.get("krinikBuild")
        if not rb:
            continue
        mod = rb["args"][0]
        if only and mod != only:
            continue
        lib_dir = os.path.join(LIBRARY, m["source"]["folder"].replace("/", os.sep))
        current = os.path.join(lib_dir, mod + ".pak")
        jobs.append((mb(current), m["name"], mod, rb, lib_dir, current))
    if not jobs:
        raise SystemExit("нет модов с krinikBuild" + (f" по имени {only}" if only else ""))
    failed = 0
    for _, name, mod, rb, lib_dir, current in sorted(jobs):
        # своя новая папка на каждый прогон: retoc unpack-raw не пишет в существующую (прогон 2026-10-30 00:4x — Simple_Minimap после пилота «os error 183»)
        n = 1
        while os.path.exists(os.path.join(WORK, f"{mod}-{n}")):
            n += 1
        work = os.path.join(WORK, f"{mod}-{n}")
        os.makedirs(work)
        args = list(rb["args"])
        cmd = [sys.executable, "-I", "-X", "utf8", os.path.join(HERE, "patch-mod-asset.py"), "build", args[0], args[1], work] + args[2:]
        env = dict(os.environ)
        for k, v in rb.get("env", {}).items():
            env[k] = v.replace("<work>", work)
        print(f"== {name} ({mod}): сборка …", flush=True)
        r = subprocess.run(cmd, cwd=PACK, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace")
        built = os.path.join(work, "out", mod + ".pak")
        if r.returncode != 0 or not os.path.exists(built):
            failed += 1
            print(f"   НЕ СОБРАН (код {r.returncode}):\n{r.stdout[-1500:]}\n{r.stderr[-800:]}")
            continue
        orig = os.path.join(pma.ORIGINALS, mod + ".pak")
        ok, why = same_inside(current, built, work)
        line = f"   оригинал {mb(orig):.1f} МБ · стоит {mb(current):.1f} · новый {mb(built):.1f} — {why}"
        if not ok:
            failed += 1
            print(line + " — НЕ СТАВЛЮ")
            continue
        print(line)
        if install:
            shutil.copyfile(built, current)
            shutil.copyfile(built, os.path.join(GAME_MODS, mod + ".pak"))
            print(f"   поставлен: библиотека и {GAME_MODS}")
        if not keep:
            # сошедшийся мод больше не нужен в черновике; не сошедшийся (выше — continue) остаётся для разбора
            print(f"   черновик убран: {remove_by_enumeration(work)} файлов, {work}")
    print(f"итог: {len(jobs) - failed} из {len(jobs)} сошлись" + (", поставлены" if install else " (без установки)"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
