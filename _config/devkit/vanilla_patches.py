# -*- coding: utf-8 -*-
"""vanilla_patches.py — правки ВАНИЛЬНЫХ блюпринтов игры, которые везёт наш KrinikConanGameplay (шаг 4б build-level-mod.py).

Зачем (KUMM 2026-11-08, слово владельца):
  • предел атрибутов 20 снимается правкой пака скриптом — `[OWNER]` 23:05 «(А) — правку пака скриптом» (KUMM plans/49: предел — одно
    число `BP_ProgressionSystem.MaxAttributePointsSpent` = 20 в объекте класса по умолчанию; его читает и «+» окна, и сервер);
  • черта «Верная рука» (`Agility_10b`, Dead Shot) ускоряет стрелу не вдвое, а на 20 % — `[OWNER]` 23:05 «это имбаланс» · «я бы перк
    изменил, чтобы он процентов 20% прибавлял к скорости» (байткод `BP_BaseProjectile`: при `ApplyPerkProjectileSpeed` начальная скорость
    × литерал 2.0 — единственный литерал 2.0 в его графе событий).
Как: кусок пакета берётся из контейнера ИГРЫ (`retoc get`), ассет — `to-legacy`; правка на месте (`uaj setstr prop:` — число объекта по
умолчанию; `patch_doubles` из patch-mod-asset.py — литерал в байткоде), размер .uexp не меняется; новый кусок = исходный zen-заголовок +
правленый .uexp (`splice_chunk` — retoc to-zen ломает блюпринты 5.8, KUMM EXP-0338). Стражи: запись без правок = исходнику байт в байт;
правка меняет ровно столько байт, сколько весит число (4 для int, 8 для double); данные куска игры = .uexp ассета.
Ни один мод сборки эти два пути не везёт (`mod-overrides.py`, 2026-11-08 23:2x) — копия в нашем паке ничью правку не затирает.
Пишет только в <work>. Папка игры и представление — только чтение.
[TESTED: 2026-11-08 · build step 4b + step 6 (2 из 2 на трёх платформах), страж числа краснеет на 3.0; в игре — предел 10000, Проворство 25 → 26,
 «+» на кадре 4K; «Верная рука» 5999 → 3000 см/с против 4979 → 2490 без черты · KUMM testcases/reports/2026-11-08_conan-attributes-uncapped-dead-shot.md]
"""
import importlib.util
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from game_target import PAKS_VIEW  # noqa: E402

TOOLS = r"D:\work\ai_sandbox\_tools"
RETOC_58 = os.path.join(TOOLS, "retoc-5.8", "retoc.exe")
# the current target's view (game_target.py, 2026-11-13): the hard-coded 3.0.1 view would patch vanilla blueprints of the old game inside a 3.1.0 build
# (judge D, B5). The name stays for its callers.
VIEW_301 = PAKS_VIEW
RETOC_ENGINE = "UE5_7"
HERE = os.path.dirname(os.path.abspath(__file__))

# путь пакета под /Game (без расширения) · id куска в контейнере игры (retoc list, 2026-11-08) · правки
PATCHES = [
    {
        "path": "Systems/Progression/BP_ProgressionSystem",
        "chunk": "b1bc00efb4fd1ab800000001",
        # предел очков в одном атрибуте: 20 → 10 000 (= числу уровней сборки; очко даётся каждый уровень, упереться нельзя)
        "props": [("Default__BP_ProgressionSystem_C/MaxAttributePointsSpent", "20", "10000")],
        "dbls": [],
        "bytes_changed": 4,
    },
    {
        "path": "Items/Weapons/BP_BaseProjectile",
        "chunk": "3dedc65ed608a18d00000001",
        "props": [],
        # «Верная рука»: стрела и метательное оружие × 2.0 → × 1.2 к начальной скорости
        "dbls": [("ExecuteUbergraph_BP_BaseProjectile", 2.0, 1.2, "d")],
        "bytes_changed": None,   # double 2.0 → 1.2: число изменённых байт внутри 8 — проверяется «не больше 8 и только в одном окне»
    },
]


def _pm():
    spec = importlib.util.spec_from_file_location("pm", os.path.join(HERE, "patch-mod-asset.py"))
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def _run(args):
    r = subprocess.run(args, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise SystemExit(f"{os.path.basename(args[0])} {args[1]}: код {r.returncode}\n{r.stdout[-800:]}\n{r.stderr[-800:]}")
    return r.stdout


def mount_path(p):
    return f"../../../ConanSandbox/Content/{p['path']}.uasset"


def build_chunks(work, say=print):
    """Правленые куски: {id куска: (путь в контейнере, байты)}."""
    pm = _pm()
    os.makedirs(work, exist_ok=True)
    out = {}
    for p in PATCHES:
        name = os.path.basename(p["path"])
        aw = os.path.join(work, name)
        legacy = os.path.join(aw, "legacy")
        _run([RETOC_58, "to-legacy", "--version", RETOC_ENGINE, "--no-shaders", "--filter", p["path"], VIEW_301, legacy])
        ua = os.path.join(legacy, "ConanSandbox", "Content", *p["path"].split("/")) + ".uasset"
        if not os.path.exists(ua):
            raise SystemExit(f"{name}: to-legacy не дал {ua}")
        ctrl = os.path.join(aw, "control.uasset")
        _run([pm.UAJ, "copy", ua, ctrl, pm.UASSET_ENGINE])
        if open(ua[:-7] + ".uexp", "rb").read() != open(ctrl[:-7] + ".uexp", "rb").read():
            raise SystemExit(f"{name}: запись без правок ≠ исходнику — остановка")
        patched = os.path.join(aw, "patched", name + ".uasset")
        os.makedirs(os.path.dirname(patched), exist_ok=True)
        plain = os.path.join(aw, "plain.tsv")
        open(plain, "w", encoding="utf-8").write("".join(f"prop:{k}\t{new}\n" for k, _old, new in p["props"]))
        if p["props"]:
            js = os.path.join(aw, "orig.json")
            _run([pm.UASSETGUI, "tojson", ua, js, pm.UASSET_ENGINE])
            txt = open(js, encoding="utf-8").read()
            for k, old, _new in p["props"]:
                prop = k.split("/")[-1]
                if f'"Name": "{prop}"' not in txt:
                    raise SystemExit(f"{name}: свойства {prop} нет в ассете — остановка")
        res = _run([pm.UAJ, "setstr", ua, patched, pm.UASSET_ENGINE, plain]).strip()
        if "REFUSED" in res or "НЕ НАЙДЕНО" in res:
            raise SystemExit(f"{name}: uaj отказал: {res}")
        if p["dbls"]:
            pm.patch_doubles(patched, p["dbls"])
        a = open(ua[:-7] + ".uexp", "rb").read()
        b = open(patched[:-7] + ".uexp", "rb").read()
        if len(a) != len(b):
            raise SystemExit(f"{name}: размер .uexp изменился ({len(a)} → {len(b)}) — правка на месте не вышла")
        diff = [i for i in range(len(a)) if a[i] != b[i]]
        if not diff or (diff[-1] - diff[0]) >= 8:
            raise SystemExit(f"{name}: изменено байт {len(diff)} в окне {diff[:1]}…{diff[-1:]} — ждали одно число")
        if p["bytes_changed"] and len(diff) > p["bytes_changed"]:
            raise SystemExit(f"{name}: изменено {len(diff)} байт, ждали ≤ {p['bytes_changed']}")
        zen_p = os.path.join(aw, "orig.zen")
        _run([RETOC_58, "get", VIEW_301, p["chunk"], zen_p])
        new = pm.splice_chunk(open(zen_p, "rb").read(), ua, patched)
        what = ["%s %s → %s" % (k.split("/")[-1], o, n) for k, o, n in p["props"]] + ["%s %s → %s" % (fn, o, n) for fn, o, n, _ in p["dbls"]]
        say(f"   {name}: {', '.join(what)} · изменено байт {len(diff)} @uexp+{diff[0]} · кусок {len(new)} байт")
        out[p["chunk"]] = (mount_path(p), new)
    return out


def inject(utoc, chunks, work):
    """Добавить куски в готовый контейнер: unpack-raw → куски + chunk_paths → pack-raw на место."""
    import json
    raw = os.path.join(work, "raw-" + os.path.basename(utoc)[:-5])
    _run([RETOC_58, "unpack-raw", utoc, raw])
    mp = os.path.join(raw, "manifest.json")
    man = json.load(open(mp, encoding="utf-8"))
    for cid, (path, data) in chunks.items():
        if cid in man["chunk_paths"]:
            raise SystemExit(f"{os.path.basename(utoc)}: кусок {cid} уже есть в контейнере")
        open(os.path.join(raw, "chunks", cid), "wb").write(data)
        man["chunk_paths"][cid] = path
    json.dump(man, open(mp, "w", encoding="utf-8"), indent=2)
    for ext in (".utoc", ".ucas"):
        os.remove(utoc[:-5] + ext)
    _run([RETOC_58, "pack-raw", raw, utoc])


def verify(utoc, chunks, work):
    """Куски в готовом контейнере = собранным байт в байт."""
    bad = []
    for cid, (_path, data) in chunks.items():
        got = os.path.join(work, f"verify-{cid}.bin")
        _run([RETOC_58, "get", utoc, cid, got])
        if open(got, "rb").read() != data:
            bad.append(cid)
    return bad
