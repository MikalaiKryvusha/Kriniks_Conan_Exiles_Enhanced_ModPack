# locres.py - reader/writer for Unreal .locres (versions 2-3) plus UE's string hash (FCrc::StrCrc32 over TCHAR).
#
# Зачем: перевод мода кладётся ПОВЕРХ живого .locres игры — файл надо прочитать, дописать записи
# и записать назад в том же формате. Записи несут ДВА хэша: хэш ключа (FTextKey) и хэш исходной
# строки. Хэш исходника — FCrc::StrCrc32 (проверено на файле игры: 15 282 из 15 282 совпали, 12.09);
# хэш ключа считается ДРУГИМ алгоритмом (ни один из 19 кандидатов CRC не сошёлся) — поэтому писатель
# переносит хэши ключей КАК ЕСТЬ из прочитанных файлов и никогда не вычисляет их сам. Новые записи
# берут хэши из .locres, скомпилированного самим движком (GatherText → GenerateTextLocalizationResource).
#
# [TESTED: 2026-09-12 · selftest на ru/Exiles_UI.locres игры — источники по CRC совпали, запись→чтение
#  байт в байт]  (обновлять маркер при изменении формата)
#
# Только чтение файлов игры; запись — в путь, который назвал вызывающий.
import struct, sys, os

MAGIC = bytes([0x0E, 0x14, 0x74, 0x75, 0x67, 0x4A, 0x03, 0xFC, 0x4A, 0x15, 0x90, 0x9D, 0xC3, 0x37, 0x7F, 0x1B])

# standard CRC-32 table (poly 0xEDB88320) = Unreal's CRCTablesSB8[0]
_TABLE = []
for _i in range(256):
    _c = _i
    for _ in range(8):
        _c = (_c >> 1) ^ 0xEDB88320 if _c & 1 else _c >> 1
    _TABLE.append(_c)


def str_crc32(s: str, base: int = 0) -> int:
    """FCrc::StrCrc32<TCHAR>: every UTF-16 code unit is fed as four bytes (lo, hi, 0, 0).
    This is the SourceStringHash of a locres entry (verified against the game's file)."""
    crc = (~base) & 0xFFFFFFFF
    raw = s.encode('utf-16le')
    units = struct.unpack('<%dH' % (len(raw) // 2), raw)
    for ch in units:
        for _ in range(4):
            crc = (crc >> 8) ^ _TABLE[(crc ^ ch) & 0xFF]
            ch >>= 8
    return (~crc) & 0xFFFFFFFF


def _read_fstring(d, pos):
    n = struct.unpack_from('<i', d, pos)[0]
    pos += 4
    if n == 0:
        return '', pos
    if n > 0:
        return d[pos:pos + n - 1].decode('latin-1'), pos + n
    m = -n * 2
    return d[pos:pos + m - 2].decode('utf-16le'), pos + m


def _write_fstring(s: str) -> bytes:
    if s == '':
        # the engine's locres writer stores the empty namespace as a 1-byte string (just the NUL),
        # not as length 0 - seen in the game's own file (round trip was one byte short otherwise)
        return struct.pack('<i', 1) + b'\x00'
    if all(ord(c) < 0x80 for c in s):
        b = s.encode('ascii') + b'\x00'
        return struct.pack('<i', len(b)) + b
    b = s.encode('utf-16le') + b'\x00\x00'
    return struct.pack('<i', -(len(b) // 2)) + b


class Entry:
    __slots__ = ('ns', 'ns_hash', 'key', 'key_hash', 'src_hash', 'tr')

    def __init__(self, ns, ns_hash, key, key_hash, src_hash, tr):
        self.ns, self.ns_hash, self.key, self.key_hash, self.src_hash, self.tr = ns, ns_hash, key, key_hash, src_hash, tr

    def __repr__(self):
        return 'Entry(%r, %08X, %s, %08X, %08X, %r)' % (self.ns, self.ns_hash, self.key, self.key_hash, self.src_hash, self.tr)

    def tuple(self):
        return (self.ns, self.ns_hash, self.key, self.key_hash, self.src_hash, self.tr)


def read(path):
    """Return (version, entries) in file order; entries are Entry objects carrying both stored hashes."""
    d = open(path, 'rb').read()
    if d[:16] != MAGIC:
        raise ValueError('not a v2+ locres: ' + path)
    version = d[16]
    pos = 17
    str_off = struct.unpack_from('<q', d, pos)[0]
    pos += 8
    if version >= 2:
        pos += 4  # entry count
    ns_count = struct.unpack_from('<i', d, pos)[0]
    pos += 4
    raw = []
    for _ in range(ns_count):
        ns_hash = 0
        if version >= 2:
            ns_hash = struct.unpack_from('<I', d, pos)[0]
            pos += 4
        ns, pos = _read_fstring(d, pos)
        kc = struct.unpack_from('<i', d, pos)[0]
        pos += 4
        for _ in range(kc):
            key_hash = 0
            if version >= 2:
                key_hash = struct.unpack_from('<I', d, pos)[0]
                pos += 4
            key, pos = _read_fstring(d, pos)
            src_hash = struct.unpack_from('<I', d, pos)[0]
            pos += 4
            idx = struct.unpack_from('<i', d, pos)[0]
            pos += 4
            raw.append((ns, ns_hash, key, key_hash, src_hash, idx))
    p = str_off
    cnt = struct.unpack_from('<i', d, p)[0]
    p += 4
    strings = []
    for _ in range(cnt):
        s, p = _read_fstring(d, p)
        if version >= 3:
            p += 4  # ref count
        strings.append(s)
    return version, [Entry(ns, nh, key, kh, sh, strings[idx]) for ns, nh, key, kh, sh, idx in raw]


def write(path, entries, version=3):
    """Write entries (Entry objects) keeping namespace order of first appearance and key order within
    a namespace; identical translations share one string slot in first-appearance order (as the engine does).
    Hashes are written AS CARRIED by the entries - never recomputed here."""
    by_ns = {}
    ns_order = []
    ns_hash = {}
    for e in entries:
        if e.ns not in by_ns:
            by_ns[e.ns] = []
            ns_order.append(e.ns)
            ns_hash[e.ns] = e.ns_hash
        by_ns[e.ns].append(e)
    strings, index, refs = [], {}, []

    def slot(tr):
        if tr not in index:
            index[tr] = len(strings)
            strings.append(tr)
            refs.append(0)
        refs[index[tr]] += 1
        return index[tr]

    body = bytearray()
    total = 0
    body += struct.pack('<i', len(ns_order))
    for ns in ns_order:
        if version >= 2:
            body += struct.pack('<I', ns_hash[ns] & 0xFFFFFFFF)
        body += _write_fstring(ns)
        body += struct.pack('<i', len(by_ns[ns]))
        for e in by_ns[ns]:
            if version >= 2:
                body += struct.pack('<I', e.key_hash & 0xFFFFFFFF)
            body += _write_fstring(e.key)
            body += struct.pack('<I', e.src_hash & 0xFFFFFFFF)
            body += struct.pack('<i', slot(e.tr))
            total += 1
    header_len = 16 + 1 + 8 + (4 if version >= 2 else 0)
    str_off = header_len + len(body)
    out = bytearray(MAGIC)
    out += bytes([version])
    out += struct.pack('<q', str_off)
    if version >= 2:
        out += struct.pack('<I', total)
    out += body
    out += struct.pack('<i', len(strings))
    for i, s in enumerate(strings):
        out += _write_fstring(s)
        if version >= 3:
            out += struct.pack('<i', refs[i])
    with open(path, 'wb') as f:
        f.write(out)
    return total, len(strings)


def selftest(path):
    version, entries = read(path)
    tmp = path + '.roundtrip'
    write(tmp, entries, version)
    same = open(tmp, 'rb').read() == open(path, 'rb').read()
    print('version', version, 'entries', len(entries), 'round-trip byte-identical:', same)
    if not same:
        v2, e2 = read(tmp)
        print('  entries equal after re-read:', [x.tuple() for x in e2] == [x.tuple() for x in entries])
    os.remove(tmp)
    return same


if __name__ == '__main__':
    if len(sys.argv) >= 3 and sys.argv[1] == 'selftest':
        sys.exit(0 if selftest(sys.argv[2]) else 1)
    if len(sys.argv) >= 3 and sys.argv[1] == 'dump':
        v, e = read(sys.argv[2])
        for x in e[:int(sys.argv[3]) if len(sys.argv) > 3 else 20]:
            print(x)
        sys.exit(0)
    print('usage: locres.py selftest <file.locres> | dump <file.locres> [n]')
