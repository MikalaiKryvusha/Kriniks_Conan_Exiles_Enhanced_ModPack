"""Read the versioning block of a Zen (IoStore) package header (.uheader).
[TESTED: 2026-09-13 · MrS_Level1000: таблица и контроллер дали одинаковые Zen 3 / UE4 524 / UE5 1017 /
 лиц. 5, у контроллера 9 пользовательских версий, у таблицы 0 — раскладка сходится на двух разных ассетах]

FZenPackageSummary (UE 5.3+): bHasVersioningInfo u32, HeaderSize u32, Name (u32,u32), PackageFlags u32,
CookedHeaderSize u32, then 7 int32 offsets -> 52 bytes. If bHasVersioningInfo: ZenVersion u32,
PackageVersion (UE4 i32, UE5 i32), LicenseeVersion i32, CustomVersions (count i32; guid 16 + i32 each).
Usage: python zen_versions.py <a.uheader> [<b.uheader>]  -> prints both and the differences.
"""
import struct
import sys


def read(path):
    b = open(path, "rb").read()
    has, header_size = struct.unpack_from("<II", b, 0)
    out = {"file": path, "bytes": len(b), "has_versioning": has, "header_size": header_size}
    if not has:
        return out
    o = 52
    zen, ue4, ue5, lic, n = struct.unpack_from("<Iiiii", b, o)
    o += 20
    if not (0 <= n < 1000):
        out["error"] = f"implausible custom version count {n} — layout differs"
        return out
    customs = {}
    for _ in range(n):
        g = b[o:o + 16]
        v, = struct.unpack_from("<i", b, o + 16)
        a, b2, c, d = struct.unpack_from("<IIII", g)
        customs[f"{a:08X}-{b2:08X}-{c:08X}-{d:08X}"] = v
        o += 20
    out.update(zen_version=zen, ue4=ue4, ue5=ue5, licensee=lic, customs=customs)
    return out


def main():
    rs = [read(p) for p in sys.argv[1:]]
    for r in rs:
        print({k: v for k, v in r.items() if k != "customs"}, "customs:", len(r.get("customs", {})))
    if len(rs) == 2 and "customs" in rs[0] and "customs" in rs[1]:
        a, b = rs
        for k in ("zen_version", "ue4", "ue5", "licensee"):
            if a[k] != b[k]:
                print(f"DIFF {k}: {a[k]} -> {b[k]}")
        for g in sorted(set(a["customs"]) | set(b["customs"])):
            va, vb = a["customs"].get(g), b["customs"].get(g)
            if va != vb:
                print(f"DIFF custom {g}: {va} -> {vb}")


if __name__ == "__main__":
    main()
