# Fit world (X, Y) -> map pixel (px, py) of the in-game map frame mapA (displayed 2000x1125) from vistas: eye icons vs vista world coordinates.
import itertools
eyes = [(237, 97), (398, 110), (228, 161), (838, 127), (958, 173), (553, 254), (1637, 214), (1590, 281), (1403, 289), (1805, 186), (1684, 530)]
vistas = {'Oasis Overlook': (-253832, 16193), 'Canopy Outlook': (220425, 43688), 'Godsight Spire': (-135060, 74567), 'Skyfall Ridge': (-177478, -141986),
          'Riversend': (-193946, -32220), 'Shattered Springs': (-193314, 21149), 'Eyelet Lake': (-179518, -170940), 'Crowngrove': (-256864, -10091),
          'Nekhet': (-256741, 39991), "Imi's Cradle": (32653, 21022), "Priestking's Retreat": (-28442, 27185), 'Lake view': (-203528, -26068),
          'Spring view': (43844, 101468)}
names = list(vistas)
best = []
axes = [(0, 1, 1, 1), (0, 1, 1, -1), (0, 1, -1, 1), (0, 1, -1, -1), (1, 0, 1, 1), (1, 0, 1, -1), (1, 0, -1, 1), (1, 0, -1, -1)]
for ax in axes:
    ix, iy, sx, sy = ax  # px = sx*s*W[ix] + bx ; py = sy*s*W[iy] + by
    for (n1, n2) in itertools.permutations(names, 2):
        w1, w2 = vistas[n1], vistas[n2]
        for e1, e2 in itertools.permutations(eyes, 2):
            dw = sx * (w2[ix] - w1[ix])
            if dw == 0: continue
            s = (e2[0] - e1[0]) / dw
            if s <= 0: continue
            dwy = sy * (w2[iy] - w1[iy])
            if dwy == 0 or abs((e2[1] - e1[1]) - s * dwy) > 6: continue
            bx = e1[0] - sx * s * w1[ix]
            by = e1[1] - sy * s * w1[iy]
            hits = []
            for n in names:
                w = vistas[n]
                p = (sx * s * w[ix] + bx, sy * s * w[iy] + by)
                d = min(((p[0] - e[0]) ** 2 + (p[1] - e[1]) ** 2) ** 0.5 for e in eyes)
                if d < 12: hits.append(n)
            best.append((len(hits), ax, s, bx, by, hits))
best.sort(key=lambda t: -t[0])
seen = set()
for b in best[:40]:
    key = (b[1], round(b[2] * 1e6), round(b[3]), round(b[4]))
    if key in seen: continue
    seen.add(key)
    print(b[0], b[1], '%.6e' % b[2], round(b[3], 1), round(b[4], 1), b[5])
