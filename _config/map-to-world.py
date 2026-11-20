# map pixel (mapA, 2000x1125 display) -> world; spec «name X Y marchYaw viewYaw» for water-scenes / shore-try.
import math
s, bx, by = 2.660560e-03, 912.3, 53.9
def w(px, py): return ((px - bx) / s, (py - by) / s)
def yaw(a, b): return math.degrees(math.atan2(b[1] - a[1], b[0] - a[0]))
pts = {  # land start, water point to march to, a point across the water to look at
    'delta_north': ((1395, 330), (1450, 352), (1570, 365)),
    'delta_west':  ((1300, 445), (1340, 412), (1460, 360)),
    'bend':        ((1175, 600), (1185, 545), (1300, 470)),
    'desert_river': ((960, 705), (960, 675), (1120, 680)),
    'south_channel': ((1690, 548), (1690, 522), (1560, 515)),
}
for n, (land, water, look) in pts.items():
    L, W, K = w(*land), w(*water), w(*look)
    print('%s %.0f %.0f %.0f %.0f' % (n, L[0], L[1], yaw(L, W), yaw(L, K)))
