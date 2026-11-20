"""
krinik_modinfo.py -- the fields of the game's own mod list for every Krinik mod pak: author, author URL, change note (KUMM HOUSE_RULES rule 40).

ONE source for all of them: the author and the URL below, the change notes in the pack's table _config/release/krinik_change_notes.json
(release X.Y.Z -> one line per Krinik pak mod: what changed in THAT mod in that release). Three callers write them into a pak's modinfo.json:
  kit-buildmod.py     step 4, the wrapper of a kit mod (Archery, Graphics, UI);
  build-level-mod.py  step 5, the modinfo of KrinikConanGameplay;
  set-pak-modinfo.py  the release export, and --check-krinik: the guard of the release and of the working game.
So a rebuild can no longer leave the fields empty (the owner's frame of 2026-11-03: «Автор --», «URL автора --», «Список изменений --»).

A release that has no line for a mod stops the build BEFORE the cook: rule 40.2, «a new release adds its line before the paks are built».
The release is the X.Y.Z of the manifest's packVersion: an RC tail («0.9.1-RC1») is the build's number, the mods keep three numbers (KUMM plans/55).

    import krinik_modinfo
    krinik_modinfo.fill(info, "KrinikConanUI")       # author, authorUrl, changeNote into a modinfo dict
    krinik_modinfo.problems(info, "KrinikConanUI")   # [] when the three fields equal the source
[NOT-TESTED]
"""
import json
import os
import re

PACK = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLE = os.path.join(PACK, "_config", "release", "krinik_change_notes.json")
AUTHOR = "Кот Криник (KOT KRINIK)"
AUTHOR_URL = "https://www.nexusmods.com/conanexilesenhanced/mods/65"
FIELDS = ("author", "authorUrl", "changeNote")


def release(pack=PACK):
    """X.Y.Z of the manifest's packVersion -- the version of the Krinik mods themselves."""
    with open(os.path.join(pack, "modpack.json"), encoding="utf-8") as fh:
        v = json.load(fh)["packVersion"]
    m = re.match(r"(\d+\.\d+\.\d+)", v)
    if not m:
        raise SystemExit("packVersion «%s» не начинается с трёх чисел X.Y.Z" % v)
    return m.group(1)


def pak_mods(pack=PACK):
    """The Krinik mods the manifest ships as paks (kind «pak», export not false) -- the set the guard expects to find."""
    with open(os.path.join(pack, "modpack.json"), encoding="utf-8") as fh:
        mods = json.load(fh)["mods"]
    return sorted(m["name"] for m in mods if m["name"].startswith("Krinik") and m.get("kind") == "pak" and m.get("export", True) is not False)


def change_note(mod, rel=None):
    rel = rel or release()
    with open(TABLE, encoding="utf-8") as fh:
        table = json.load(fh)
    note = ((table.get(rel) or {}).get(mod) or "").strip()
    if not note:
        raise SystemExit("в таблице %s нет строки изменений мода %s для выпуска %s: допишите её до сборки пака (KUMM HOUSE_RULES 40)"
                         % (TABLE, mod, rel))
    return note


def expected(mod, rel=None):
    return {"author": AUTHOR, "authorUrl": AUTHOR_URL, "changeNote": change_note(mod, rel)}


def fill(info, mod, rel=None):
    info.update(expected(mod, rel))
    return info


def problems(info, mod, rel=None):
    """Names of the fields that are empty or differ from the source; [] when the pak carries the source's values."""
    want = expected(mod, rel)
    return [k for k in FIELDS if not (info.get(k) or "").strip() or info.get(k) != want[k]]


def write_json(path, info, like=None):
    """modinfo.json as the kit writes it: tabs, the line ending and the BOM of the file it replaces (like), UTF-8."""
    raw = open(like or path, "rb").read() if os.path.exists(like or path) else b""
    text = json.dumps(info, ensure_ascii=False, indent="\t")
    if b"\r\n" in raw:
        text = text.replace("\n", "\r\n")
    with open(path, "wb") as fh:
        fh.write((b"\xef\xbb\xbf" if raw.startswith(b"\xef\xbb\xbf") else b"") + text.encode("utf-8"))
