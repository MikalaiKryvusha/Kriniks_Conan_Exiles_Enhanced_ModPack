# -*- coding: utf-8 -*-
"""package-id.py — идентификатор пакета UE (FPackageId) по пути: CityHash64 (v1.1, как в Core/Hash/CityHash движка) от пути в нижнем
регистре в UTF-16LE; в оглавлении контейнера байты идут в обратном порядке (колонка le=).

Зачем (2026-10-25): старый кит удалён, а retoc 0.1.5 читает паки ИГРЫ 5.8 без путей — у них нет индекса каталогов, видны только
идентификаторы чанков. Зная идентификатор, ванильный ассет достаётся без кита:
    MSYS_NO_PATHCONV=1 python -I -X utf8 package-id.py /Game/Items/ItemStatModificationTable      # -> le=1c1c03902cf25439
    retoc list <pakchunkN-Windows.utoc> | grep <le>00000001 ;  retoc get <utoc> <le>00000001 > out.chunk
(MSYS_NO_PATHCONV=1 — иначе Git Bash превращает /Game/... в путь Windows.)

[TESTED: 2026-10-25 · две пары путь↔идентификатор из оглавления мода Double Storage Space (retoc list --path) совпали:
 DT_MergeControl f5b223fe03a76aae, DT_DoubledStorage 2962ceeb34360d75; по вычисленному id найден и извлечён
 Items/ItemStatModificationTable в pakchunk0 игр 3.0.1 (943 374 байта) и 2.2.3 (929 526) — KUMM plans/33, шаг 28]"""
import struct
import sys

M = 0xFFFFFFFFFFFFFFFF
k0, k1, k2 = 0xc3a5c85c97cb3127, 0xb492b66fbe98f273, 0x9ae16a3b2f90404f


def f64(s, i): return struct.unpack_from('<Q', s, i)[0]
def f32(s, i): return struct.unpack_from('<I', s, i)[0]
def rot(v, s): return v if s == 0 else ((v >> s) | (v << (64 - s))) & M
def smix(v): return v ^ (v >> 47)


def h16(u, v):
    kM = 0x9ddfea08eb382d69
    a = ((u ^ v) * kM) & M; a ^= a >> 47
    b = ((v ^ a) * kM) & M; b ^= b >> 47
    return (b * kM) & M


def h16m(u, v, mul):
    a = ((u ^ v) * mul) & M; a ^= a >> 47
    b = ((v ^ a) * mul) & M; b ^= b >> 47
    return (b * mul) & M


def h0to16(s):
    n = len(s)
    if n >= 8:
        mul = (k2 + n * 2) & M
        a = (f64(s, 0) + k2) & M
        b = f64(s, n - 8)
        c = (rot(b, 37) * mul + a) & M
        d = ((rot(a, 25) + b) * mul) & M
        return h16m(c, d, mul)
    if n >= 4:
        mul = (k2 + n * 2) & M
        a = f32(s, 0)
        return h16m((n + (a << 3)) & M, f32(s, n - 4), mul)
    if n > 0:
        a, b, c = s[0], s[n >> 1], s[n - 1]
        y = a + (b << 8)
        z = n + (c << 2)
        return (smix(((y * k2) ^ (z * k0)) & M) * k2) & M
    return k2


def h17to32(s):
    n = len(s); mul = (k2 + n * 2) & M
    a = (f64(s, 0) * k1) & M; b = f64(s, 8); c = (f64(s, n - 8) * mul) & M; d = (f64(s, n - 16) * k2) & M
    return h16m((rot((a + b) & M, 43) + rot(c, 30) + d) & M, (a + rot((b + k2) & M, 18) + c) & M, mul)


def wh32(w, x, y, z, a, b):
    a = (a + w) & M
    b = rot((b + a + z) & M, 21)
    c = a
    a = (a + x) & M; a = (a + y) & M
    b = (b + rot(a, 44)) & M
    return (a + z) & M, (b + c) & M


def wh32s(s, i, a, b): return wh32(f64(s, i), f64(s, i + 8), f64(s, i + 16), f64(s, i + 24), a, b)


def h33to64(s):
    n = len(s); mul = (k2 + n * 2) & M
    a = (f64(s, 0) * k2) & M; b = f64(s, 8); c = f64(s, n - 24); d = f64(s, n - 32)
    e = (f64(s, 16) * k2) & M; f = (f64(s, 24) * 9) & M; g = f64(s, n - 8); h = (f64(s, n - 16) * mul) & M
    u = (rot((a + g) & M, 43) + (rot(b, 30) + c) * 9) & M
    v = (((a + g) ^ d) + f + 1) & M
    w = (((u + v) * mul) >> 0) & M; w = int.from_bytes(struct.pack('<Q', w)[::-1], 'big')  # bswap
    x = (rot((e + f) & M, 42) + c) & M
    y = int.from_bytes(struct.pack('<Q', ((v + w) * mul) & M)[::-1], 'big') + g & M
    z = (e + f + c) & M
    a = int.from_bytes(struct.pack('<Q', ((x + z) * mul + y) & M)[::-1], 'big') + b & M
    b = (smix((z + a) * mul + d + h & M) * mul) & M
    return (b + x) & M


def city64(s):
    n = len(s)
    if n <= 32:
        return h0to16(s) if n <= 16 else h17to32(s)
    if n <= 64:
        return h33to64(s)
    x = f64(s, n - 40); y = (f64(s, n - 16) + f64(s, n - 56)) & M
    z = h16((f64(s, n - 48) + n) & M, f64(s, n - 24))
    v = wh32s(s, n - 64, n, z); w = wh32s(s, n - 32, (y + k1) & M, x)
    x = (x * k1 + f64(s, 0)) & M
    n2 = (n - 1) & ~63; i = 0
    while True:
        x = (rot((x + y + v[0] + f64(s, i + 8)) & M, 37) * k1) & M
        y = (rot((y + v[1] + f64(s, i + 48)) & M, 42) * k1) & M
        x ^= w[1]
        y = (y + v[0] + f64(s, i + 40)) & M
        z = (rot((z + w[0]) & M, 33) * k1) & M
        v = wh32s(s, i, (v[1] * k1) & M, (x + w[0]) & M)
        w = wh32s(s, i + 32, (z + w[1]) & M, (y + f64(s, i + 16)) & M)
        z, x = x, z
        i += 64; n2 -= 64
        if n2 == 0:
            break
    return h16((h16(v[0], w[0]) + smix(y) * k1 + z) & M, (h16(v[1], w[1]) + x) & M)


def pkgid(name):
    return city64(name.lower().encode('utf-16-le'))


if __name__ == '__main__':
    for nm in sys.argv[1:]:
        v = pkgid(nm)
        print('%s  be=%016x  le=%s' % (nm, v, struct.pack('<Q', v).hex()))
