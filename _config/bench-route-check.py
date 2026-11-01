# bench-route-check.py <routes.lua> <маршрут> — расчёт маршрута облёта ДО игры: по каждому участку горизонталь, перепад, уклон,
# скорость, вертикальная скорость и секунды; в конце — длительность облёта (без зависания на старте).
# Зачем (KUMM EXP-0332, пункты 6–7): владелец 2026-10-25 вечером — «некрасивые резкие у тебя над рекой взлёты вверх и опыскания
# ввниз» · «нужно плавнее и дольше вверху лететь»: уклоны 24–50° третьей редакции видны в расчёте за секунду, а в игре — за прогон.
# Время участка считается как в моде (main.lua, build): max(горизонталь, |перепад|) / средняя скорость концов. Сплайн не учтён —
# это оценка по прямым между точками. Участок круче MAX_SLOPE помечается «!».
# [NOT-TESTED]
import math, re, sys

MAX_SLOPE = 15.0   # град; круче — «резкий взлёт» по слову владельца
src = open(sys.argv[1], encoding="utf-8").read()
name = sys.argv[2]
blk = src.split('["%s"]' % name, 1)[1]
blk = blk.split("points", 1)[1].split("},\n    },", 1)[0]
num = r"\s*(-?\d+)"
pts = []
for m in re.finditer(r"\{" + r",".join([num] * 3) + r"(?:," + num + r")?(?:," + num + r")?\s*\}", blk):
    pts.append(tuple(int(v) if v is not None else None for v in m.groups()))
speed = int(re.search(r"speed\s*=\s*(\d+)", src.split('["%s"]' % name, 1)[1]).group(1))
T, steep = 0.0, 0
for a, b in zip(pts, pts[1:]):
    h = math.hypot(b[0] - a[0], b[1] - a[1]); dz = b[2] - a[2]
    v = ((a[4] or speed) + (b[4] or speed)) / 2
    t = max(h, abs(dz)) / v; T += t
    slope = math.degrees(math.atan2(dz, h))
    flag = "!" if abs(slope) > MAX_SLOPE else " "
    steep += flag == "!"
    print("%s %8d,%7d -> %8d,%7d  гориз %4.0f м  перепад %+4.0f м  уклон %+5.1f°  %4.1f м/с  верт %+5.1f м/с  %4.1f с  (с начала %5.1f)"
          % (flag, a[0], a[1], b[0], b[1], h / 100, dz / 100, slope, v / 100, dz / 100 / t, t, T))
print("точек %d · облёт %.1f с · круче %.0f°: %d участков" % (len(pts), T, MAX_SLOPE, steep))
