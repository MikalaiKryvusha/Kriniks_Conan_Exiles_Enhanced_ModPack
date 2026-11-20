# make-info-pak.py -- a modinfo-only wrapper pak for a Krinik Lua mod, so the GAME'S OWN mod list shows it (name, description, author, URL, version).
#
#   python -I -X utf8 make-info-pak.py <ModName> <out folder> [--work <dir>]
#
# WHY. The owner 2026-11-03 12:59 (KUMM plan 44 step 4): «а наших модов здесь я всех не нашёл, почему-то, и описаний нет!» — the game lists only paks;
# KrinikConanCamera, KrinikConanGraphics, KrinikConanModPackManager and KrinikConanRussianTranslation are UE4SS Lua mods with no pak. The wrapper holds
# only modinfo.json + manifest.json (the layout of a kit wrapper without the platform paks); the texts come from the README table, as set-pak-modinfo.py.
# Writes <out>/<ModName>.pak; prints its listing. [NOT-TESTED]
import hashlib, importlib.util, json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("spm", os.path.join(HERE, "set-pak-modinfo.py"))
spm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(spm)
VERSION = (0, 9, 0)


def main():
    a = sys.argv[1:]
    work = a[a.index("--work") + 1] if "--work" in a else None
    pos = [x for i, x in enumerate(a) if not x.startswith("--") and (i == 0 or a[i - 1] != "--work")]
    if len(pos) != 2:
        print("usage: make-info-pak.py <ModName> <out folder> [--work <dir>]")
        return 2
    name, out_dir = pos
    row = next((r for r in spm.readme_rows() if r["name"] == name), None)
    if not row:
        print("no README row for", name)
        return 1
    work = os.path.abspath(work or os.path.join(os.environ.get("TEMP", "."), "make-info-pak-" + name))
    shutil.rmtree(work, ignore_errors=True)
    d = os.path.join(work, *spm.INNER.split("/"))
    os.makedirs(d)
    mi = {"name": name, "description": row["desc"], "changeNote": spm.KRINIK_NOTE, "author": spm.KRINIK_AUTHOR, "authorUrl": spm.NEXUS,
          "versionMajor": VERSION[0], "versionMinor": VERSION[1], "versionBuild": VERSION[2], "bRequiresLoadOnStartup": False,
          "steamPublishedFileId": "", "steamTestLivePublishedFileId": "", "steamWorkshopFileIds": {}, "steamVisibility": 0,
          "folderName": name, "devkitRevisionNumber": 1002, "devkitSnapshotId": 0, "minimumVersion": "Enhanced", "requestedHttpOrigins": []}
    mp = os.path.join(d, "modinfo.json")
    open(mp, "wb").write(json.dumps(mi, ensure_ascii=False, indent="\t").replace("\n", "\r\n").encode("utf-8"))
    # The game refuses a wrapper without its platform paks («Incompatible Mods Detected … Missing platform-specific pak», 2026-11-03 13:19): each
    # platform gets a tiny legacy pak with one text file under the mod's own content folder.
    man = {}
    for plat in ("Windows", "WindowsServer"):
        src = os.path.join(work, "inner-" + plat, "ConanSandbox", "Content", "Mods", name)
        os.makedirs(src)
        open(os.path.join(src, "krinik_info.txt"), "w", encoding="utf-8").write(name + " — Krinik Mod Pack: UE4SS Lua mod, this pak only names it in the mod list.\n")
        ip = os.path.join(d, "%s-%s.pak" % (name, plat))
        spm.run([spm.REPAK, "pack", "--version", "V11", "--mount-point", "../../../", os.path.join(work, "inner-" + plat), ip])
        man[os.path.basename(ip)] = spm.md5(ip)
    man["modinfo.json"] = spm.md5(mp)
    json.dump(man, open(os.path.join(d, "manifest.json"), "w", encoding="utf-8"), indent=2)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(os.path.abspath(out_dir), name + ".pak")
    if os.path.exists(out):
        os.remove(out)
    spm.run([spm.REPAK, "pack", "--version", "V11", "--mount-point", spm.MOUNT, d, out])
    print(spm.run([spm.REPAK, "list", out]).strip())
    back = json.loads(spm.run([spm.REPAK, "get", out, spm.INNER + "/modinfo.json"]).lstrip("﻿"))
    print("written:", out, os.path.getsize(out), "· read back:", back["name"], back["author"], "%d.%d.%d" % (back["versionMajor"], back["versionMinor"], back["versionBuild"]))
    shutil.rmtree(work, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
