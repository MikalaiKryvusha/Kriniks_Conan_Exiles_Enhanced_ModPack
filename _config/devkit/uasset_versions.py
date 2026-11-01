"""Distribution of (UE4, UE5, licensee) versions over uncooked .uasset files of a tree.
[TESTED: 2026-09-13 · 3 282 файла кита: движковые ассеты UE5 1003…1018 лиц. 0, ассеты игры в ките
 UE5 1018 лиц. 5 — ступени версий монотонны и правдоподобны; тег пакета отсекает не-пакеты]

FPackageFileSummary head: Tag i32 (0x9E2A83C1), LegacyFileVersion i32 (<0); if != -4: LegacyUE3 i32;
FileVersionUE4 i32; if LegacyFileVersion <= -8: FileVersionUE5 i32; FileVersionLicenseeUE i32.
Usage: python uasset_versions.py <dir> [<dir> ...]
"""
import collections
import os
import struct
import sys

TAG = 0x9E2A83C1
MAX_FILES = 40000


def head(path):
    with open(path, "rb") as f:
        b = f.read(32)
    if len(b) < 24:
        return None
    tag, legacy = struct.unpack_from("<Ii", b, 0)
    if tag != TAG or legacy >= 0:
        return None
    o = 8
    if legacy != -4:
        o += 4
    ue4, = struct.unpack_from("<i", b, o); o += 4
    ue5 = 0
    if legacy <= -8:
        ue5, = struct.unpack_from("<i", b, o); o += 4
    lic, = struct.unpack_from("<i", b, o)
    return (ue4, ue5, lic)


def main():
    seen = collections.Counter()
    newest = {}
    n = 0
    for root in sys.argv[1:]:
        for dp, _, fs in os.walk(root):
            for fn in fs:
                if not fn.endswith((".uasset", ".umap")):
                    continue
                p = os.path.join(dp, fn)
                v = head(p)
                n += 1
                if v:
                    seen[v] += 1
                    newest.setdefault(v, p)
                if n >= MAX_FILES:
                    break
            if n >= MAX_FILES:
                break
    print(f"files scanned: {n}")
    for v, c in sorted(seen.items()):
        print(f"UE4 {v[0]} · UE5 {v[1]} · licensee {v[2]} — {c} files, e.g. {newest[v]}")


if __name__ == "__main__":
    main()
