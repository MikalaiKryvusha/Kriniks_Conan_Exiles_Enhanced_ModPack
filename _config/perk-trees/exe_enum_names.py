# Enum entry names as the game's executable stores them for reflection ("ECharIntStatID::AttributeMight"), ASCII and UTF-16, in file order.
import re, sys
data = open(sys.argv[1], 'rb').read()
for enum in sys.argv[2:]:
    pat_a = re.compile(re.escape(enum.encode()) + rb'::[A-Za-z0-9_]+')
    pat_w = re.compile(re.escape(enum.encode('utf-16le')) + rb'(?::\x00:\x00)(?:[A-Za-z0-9_]\x00)+')
    a = [m.group().decode() for m in pat_a.finditer(data)]
    w = [m.group().decode('utf-16le') for m in pat_w.finditer(data)]
    print(enum, 'ascii', len(a), 'utf16', len(w))
    seen, order = set(), []
    for n in a + w:
        if n not in seen:
            seen.add(n)
            order.append(n)
    print('  ' + ' '.join(n.split('::')[1] for n in order))
