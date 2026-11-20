# disasm-rva.py — disassemble the game exe around a hot address from a profile, and list the sample hits per instruction.
#
# Why (KUMM researches/conan-hitch-profiler, 2026-11-09 20:4x): the Shipping exe has no PDB, so a hot spot of a hitch is only an address. Its code
# tells the class of work — a `pause` loop is a spin wait on a lock, a compare-and-advance loop is a search over an array, `rep movs` a copy —
# and the strings it references (RIP-relative LEA into .rdata) often name the subsystem.
#   python -X utf8 disasm-rva.py <exe> <image base hex> <hot address hex> [--before 0x200] [--after 0x200] [--hits <file of «count addr» lines>]
# Reads the PE section table itself (no pefile dependency); capstone does the decoding (`pip install --user capstone`).
# [NOT-TESTED]
import struct
import sys

import capstone


def sections(data):
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    nsec = struct.unpack_from("<H", data, pe + 6)[0]
    opt = struct.unpack_from("<H", data, pe + 20)[0]
    off = pe + 24 + opt
    out = []
    for i in range(nsec):
        name, vsize, va, rsize, raw = struct.unpack_from("<8sIIII", data, off + i * 40)
        out.append((name.rstrip(b"\0").decode(), va, vsize, raw, rsize))
    return out


def rva_to_off(secs, rva):
    for name, va, vsize, raw, rsize in secs:
        if va <= rva < va + max(vsize, rsize):
            return raw + (rva - va), name
    return None, None


def cstring_at(data, secs, rva, limit=120):
    off, name = rva_to_off(secs, rva)
    if off is None or name not in (".rdata", ".data"):
        return None
    s = data[off:off + limit]
    if s[:1].isascii() and len(s) > 2 and s[1:2] == b"\0":       # UTF-16
        try:
            txt = s.decode("utf-16-le").split("\0")[0]
            return txt if len(txt) >= 3 and txt.isprintable() else None
        except UnicodeDecodeError:
            return None
    txt = s.split(b"\0")[0]
    try:
        t = txt.decode("ascii")
        return t if len(t) >= 3 and t.isprintable() else None
    except UnicodeDecodeError:
        return None


def main():
    exe, base, hot = sys.argv[1], int(sys.argv[2], 16), int(sys.argv[3], 16)
    before = int(sys.argv[sys.argv.index("--before") + 1], 16) if "--before" in sys.argv else 0x200
    after = int(sys.argv[sys.argv.index("--after") + 1], 16) if "--after" in sys.argv else 0x200
    hits = {}
    if "--hits" in sys.argv:
        for ln in open(sys.argv[sys.argv.index("--hits") + 1], encoding="utf-8"):
            p = ln.split()
            if len(p) == 2:
                hits[int(p[1], 16)] = int(p[0])
    data = open(exe, "rb").read()
    secs = sections(data)
    rva0 = hot - base - before
    off, sec = rva_to_off(secs, rva0)
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)
    md.detail = False
    print("section %s, RVA 0x%X … 0x%X" % (sec, rva0, rva0 + before + after))
    for ins in md.disasm(data[off:off + before + after], base + rva0):
        mark = ""
        h = sum(c for a, c in hits.items() if ins.address <= a < ins.address + ins.size)
        if h:
            mark = "  <<< %d" % h
        note = ""
        if "rip" in ins.op_str and ins.mnemonic in ("lea", "mov", "cmp"):
            try:
                disp = int(ins.op_str.split("rip")[1].split("]")[0].replace(" ", "").replace("+", ""), 16)
                tgt = ins.address + ins.size + disp - base
                s = cstring_at(data, secs, tgt)
                if s:
                    note = '   ; "%s"' % s
            except ValueError:
                pass
        print("0x%X  %-8s %s%s%s" % (ins.address, ins.mnemonic, ins.op_str, mark, note))


if __name__ == "__main__":
    main()
