# kit_manifest.py — the hashes of a Conan kit wrapper's manifest.json, in ONE place (KUMM plan 53 step 10, 2026-11-14).
#
# A kit wrapper's manifest.json maps each file to its MD5 and, in the nested block «<xxh128>», to its XXH128 (BuildMod.cs of the kit: «MD5 was the
# original hash format, XXH128 was added as a faster option»). The game's loader decides by these hashes whether an extracted file is current:
# with only the MD5 recomputed it logged «skip extracting … already exists with correct hash» and kept the OLD file (2026-10-26 10:38, patch-mod-asset.py).
# So an edit of any wrapper file updates BOTH entries — set_entry() does it; entry_ok() / data_ok() check both. XXH128 here = xxhash.xxh3_128().hexdigest(),
# proven equal to the kit's System.IO.Hashing.XxHash128 on 10 of 10 files of an official build (Frequent_meteors, 2026-11-14).
# xxhash is imported only when a manifest carries the block (judge 2026-11-14, finding 6: an MD5-only wrapper must not need the module).
# Users: kit-buildmod.py, set-pak-version.py, set-pak-modinfo.py (patch-mod-asset.py keeps its own copy of the same rule).
# [TESTED: 2026-11-14 · kit-buildmod.py builds of three mods (manifests 7/7 by an independent re-hash, mounted in the 3.1.0 game), set-pak-version.py and set-pak-modinfo.py on copies of an <xxh128> pak (10/10; the old script's control: DIFF) · KUMM testcases/reports/2026-11-14_conan-kit-310-our-mods.md]
import hashlib

XXH = "<xxh128>"


def _xxh3_128():
    try:
        import xxhash
    except ImportError:
        import site
        import sys
        sys.path.append(site.getusersitepackages())   # `python -I` does not see the user's packages; xxhash lives there (pip install --user xxhash)
        import xxhash
    return xxhash.xxh3_128()


def _hash(path, h):
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def md5(path):
    return _hash(path, hashlib.md5())


def xxh128(path):
    return _hash(path, _xxh3_128())


def set_entry(man, name, path):
    """The file's MD5 at the top level and, when the manifest carries the «<xxh128>» block, its XXH128 there too."""
    man[name] = md5(path)
    if XXH in man:
        man[XXH][name] = xxh128(path)


def entry_ok(man, name, path):
    """Both hashes of `name` (the XXH128 only when the block exists) match the file at `path`."""
    if man.get(name) != md5(path):
        return False
    return XXH not in man or man[XXH].get(name) == xxh128(path)


def data_ok(man, name, data):
    """The same check for the file's bytes in memory (a wrapper read by `repak get`, not unpacked)."""
    if man.get(name) != hashlib.md5(data).hexdigest():
        return False
    if XXH not in man:
        return True
    h = _xxh3_128()
    h.update(data)
    return man[XXH].get(name) == h.hexdigest()
