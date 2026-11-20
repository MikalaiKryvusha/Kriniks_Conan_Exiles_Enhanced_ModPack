"""Print the UTF-16 strings around each named cvar in the game exe. Read-only.
Usage: python -I -X utf8 cvar-help.py <ConanSandbox-Win64-Shipping.exe> <cvar> [<cvar>...]
In the 3.0.1 exe a cvar's help string sits BEFORE its name: the text printed after name N is the help of the NEXT cvar (KUMM bug 89, 2026-11-09).
[TESTED: 2026-11-09 · run on the 3.0.1 exe; the help of r.Water.SingleLayer.Reflection.* read and quoted in KUMM bugs/89]"""
import sys

EXE = sys.argv[1]
NAMES = sys.argv[2:]
data = open(EXE, 'rb').read()
NUL2 = bytes(2)
for n in NAMES:
    b = n.encode('utf-16-le')
    hits = []
    start = 0
    while True:
        i = data.find(b + NUL2, start)
        if i < 0:
            break
        hits.append(i)
        start = i + 1
    if not hits:
        print(n, 'NOT FOUND (utf-16)')
        continue
    for i in hits[:2]:
        seg = data[i + len(b) + 2: i + len(b) + 2 + 2400]
        txt = seg.decode('utf-16-le', 'ignore')
        parts = [p for p in txt.split(chr(0)) if len(p) > 12][:2]
        print(n, '@', hex(i), '=>', ' || '.join(parts)[:600])
    print()
