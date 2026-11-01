# Восемь АЛГОРИТМОВ построения поверхности каймы — сырой грубый варварский металл. Слова владельца 2026-10-31 18:41–18:42: «ты в вариантах металла играл
# только с цветом, а я просил АЛГОРИТМ построения текстуры» · «цвет 1» · «меня интересует посмотреть на разные алгоритмы построения грубой текстуры
# сыыыыыыыыыырого грубого варварского металла».
# Цвет у всех один — медь-золото (металл 1 make_frame.py); форма кромок и углов у всех одна (тот же SEED геометрии). Меняется только то, КАК
# строится поверхность:
#   1 царапины и каверны — шум и штрихи по плоскому профилю (без освещения), как было;
#   2 металл логотипа — куски настоящей поверхности букв Conan Exiles (высокие частоты, без контуров букв), сшитые вдоль полосы;
#   3 рельеф со светом — карта высот из многослойного шума, нормали, свет сверху слева, блик;
#   4 кованые грани — ячейки Вороного, каждая — плоская грань своего наклона (след молота);
#   5 литьё с порами — песчаная шероховатость литья и поры-раковины;
#   6 напильник — продольные полосы опиловки и косая двойная насечка;
#   7 коррозия — металл съеден до дыр от краёв, у ям — вздутые валики;
#   8 рубка зубилом — косые срубы поперёк полосы, у каждого ската свой наклон.
# 3–8 освещаются одной моделью: высота = фаска плиты + рельеф алгоритма → нормали → рассеянный свет + блик.
# Пишет algos/frame_h_N.webp (3840×24) и algos/frame_v_N.webp (24×2160) с прозрачностью и лист algos/lines.webp — восемь полос одна под другой.
# Запуск: python -X utf8 frame_algos.py [номера через запятую]
# [NOT-TESTED]
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'algos')
TMAX, T_MEAN, T_SWING = 24, 19, 4
EDGE = 1.0                     # сколы и сбитые углы: 1 при кайме 6 px; frame_play.py уменьшает для тонкой
LONG_H, LONG_V = 3840, 2160
SS = 3
SEED_SHAPE, SEED_SURF = 31, 77
FLAT = [("#2a1606", 0), ("#8a4f1c", .08), ("#ffd98e", .17), ("#e3a552", .3), ("#d39443", .55), ("#b97a34", .78), ("#7a4516", .9), ("#2a1606", 1)]
ALBEDO = np.array([214., 152., 74.])          # медь-золото металла 1 — без фаски, её даёт свет
LIGHT = np.array([-.45, -.55, .70]); LIGHT /= np.linalg.norm(LIGHT)
NAMES = {1: 'царапины и каверны', 2: 'металл логотипа Conan', 3: 'рельеф со светом', 4: 'кованые грани',
         5: 'литьё с порами', 6: 'напильник', 7: 'коррозия до дыр', 8: 'рубка зубилом'}

def hex2rgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)

def smooth1d(n, step, rng):
    pts = rng.random(n // step + 3)
    x = np.arange(n) / step; i = x.astype(int); t = (1 - np.cos((x - i) * math.pi)) / 2
    return pts[i] * (1 - t) + pts[i + 1] * t

def fnoise(h, w, sy, sx, rng):
    # Плавный шум с ячейкой около sy×sx пикселей (float, бикубически).
    small = rng.random((max(2, h // sy + 2), max(2, w // sx + 2))).astype(np.float32)
    return np.asarray(Image.fromarray(small, 'F').resize((w, h), Image.BICUBIC), float)

def fbm(h, w, scales, rng):
    out = sum(fnoise(h, w, s, s, rng) * (s ** .7) for s in scales)
    return (out - out.min()) / (np.ptp(out) + 1e-9)

def geometry(w, rng):
    # Форма полосы — та же, что в make_frame.py: ширина гуляет, внутренняя кромка рваная, внешняя в сколах, концы скруглены и сбиты.
    h = TMAX * SS
    t = (T_MEAN + T_SWING * ((smooth1d(w, 200 * SS, rng) - .5) * 1.2 + (smooth1d(w, 30 * SS, rng) - .5) * 1.0
                             + (smooth1d(w, 5 * SS, rng) - .5) * .9 + (rng.random(w) - .5) * .35)) * SS
    t = np.clip(t, (T_MEAN - T_SWING - 2) * SS, h - 1)
    chip = np.clip((smooth1d(w, 6 * SS, rng) - .35) * 2.2 * SS * EDGE, 0, None)   # EDGE — масштаб сколов и углов под толщину каймы
    for _ in range(int(w / (28 * SS))):
        c = rng.uniform(0, w); r = rng.uniform(3, 18) * SS; dep = rng.uniform(1, 4.5) * SS * EDGE
        xs = np.arange(max(0, int(c - r)), min(w, int(c + r)))
        chip[xs] = np.maximum(chip[xs], dep * np.sqrt(np.clip(1 - ((xs - c) / r) ** 2, 0, 1)))
    for end in (0, 1):
        R = rng.uniform(9, 20) * SS * max(EDGE, .5)
        xs = np.arange(int(R)) if end == 0 else np.arange(w - int(R), w)
        d = (xs if end == 0 else (w - 1 - xs)).astype(float)
        cut = R - np.sqrt(np.clip(R ** 2 - (R - d) ** 2, 0, None))
        chip[xs] = np.maximum(chip[xs], cut + smooth1d(len(xs) + 8, 2 * SS, rng)[:len(xs)] * 4 * SS)
    y = np.arange(h)[:, None].astype(float)
    u = np.clip((y - chip[None, :]) / (t[None, :] - chip[None, :]), 0, 1)
    alpha = ((y >= chip[None, :]) & (y <= t[None, :])).astype(float)
    return h, u, alpha

def gblur(a, sigma):
    # Гауссово размытие float-массива (Pillow не размывает режим 'F'): свёртка по строкам и столбцам.
    r = int(sigma * 3) + 1; x = np.arange(-r, r + 1); k = np.exp(-x * x / (2 * sigma * sigma)); k /= k.sum()
    p = np.pad(a, r, mode='reflect')
    p = np.apply_along_axis(lambda v: np.convolve(v, k, 'valid'), 1, p)
    return np.apply_along_axis(lambda v: np.convolve(v, k, 'valid'), 0, p)

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def bevel(u):
    # Плита с фасками у обеих кромок: высота 0 у края, 1 на плоскости.
    return smoothstep(0, .22, u) * (1 - smoothstep(.8, 1, u))

def lit(H, albedo, k=1.0, spec_k=.55):
    gy, gx = np.gradient(H)
    n = np.stack([-gx * k, -gy * k, np.ones_like(H)], axis=2); n /= np.linalg.norm(n, axis=2, keepdims=True)
    diff = np.clip(n @ LIGHT, 0, 1)
    half = LIGHT + np.array([0, 0, 1.]); half /= np.linalg.norm(half)
    spec = np.clip(n @ half, 0, 1) ** 28
    return albedo * (.28 + .95 * diff)[:, :, None] + np.array([255, 238, 196.]) * (spec * spec_k)[:, :, None]

def albedo_map(h, w, rng, var=.12):
    return ALBEDO[None, None, :] * (1 + (fnoise(h, w, 4, 4, rng) - .5) * var * 2)[:, :, None]

def grain(h, w, rng, amp):
    return gblur(rng.normal(0, 1, (h, w)), .8) * amp

# ——— 1. Царапины и каверны: плоский профиль, зерно, рябь, штрихи (без освещения) ———
def surf_scratches(h, w, u, alpha, rng):
    stops_p = np.array([p for _, p in FLAT]); stops_c = np.array([hex2rgb(c) for c, _ in FLAT])
    rgb = np.stack([np.interp(u, stops_p, stops_c[:, k]) for k in range(3)], axis=2)
    g = np.asarray(Image.fromarray(((rng.normal(0, 1, (h, w)) * 40) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(.9)), float) / 255 - .5
    pit = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6)), float) / 255
    pit = np.clip((.47 - pit) * 14, 0, 1)
    rgb = (rgb * (1 + g * 1.25)[:, :, None] * (1 - pit * .75)[:, :, None]).clip(0, 255)
    return strokes(rgb, alpha, rng, h, w), alpha

def strokes(rgb, alpha, rng, h, w, amount=1.0):
    # Штрихи алгоритма 1 поверх любой поверхности: светлые и тёмные царапины, зарубки поперёк, каверны. Размеры следов — от толщины полосы
    # (k = 1 при кайме 6 px), иначе на тонкой кайме каверны шире самой полосы. amount — доля густоты.
    k = h / 72
    im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), alpha * 255]).astype(np.uint8), 'RGBA')
    over = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(over, 'RGBA'); f = T_MEAN / 80 * amount
    for _ in range(int(w * .9 * f)):
        x, yy = rng.uniform(0, w), rng.uniform(h * .1, h * .8); L = rng.uniform(18, 200); a = math.radians(rng.normal(0, 22))
        col = (255, 244, 210, int(rng.uniform(80, 190))) if rng.random() < .65 else (30, 12, 3, int(rng.uniform(90, 170)))
        d.line([(x, yy), (x + L * math.cos(a), yy + L * math.sin(a))], fill=col, width=max(1, round(2 * k)))
    for _ in range(int(w * .009 * amount)):
        x = rng.uniform(0, w); a = math.radians(rng.normal(90, 25)); L = rng.uniform(h * .3, h * .7); yy = rng.uniform(0, h * .5)
        d.line([(x, yy), (x + L * math.cos(a), yy + L * math.sin(a))], fill=(18, 8, 2, 170), width=max(1, round(3 * k)))
    for _ in range(int(w * .6 * f)):
        x, yy = rng.uniform(0, w), rng.uniform(h * .05, h * .9); r = (rng.uniform(2, 9) if rng.random() < .25 else rng.uniform(1.2, 4)) * k
        d.ellipse([x - r, yy - r, x + r, yy + r], fill=(12, 5, 1, int(rng.uniform(70, 160))))
    over.putalpha(Image.fromarray((np.asarray(over.getchannel('A'), float) * alpha).astype(np.uint8)))
    im.alpha_composite(over)
    return np.asarray(im.convert('RGB'), float)

# ——— 2. Металл логотипа: высокие частоты поверхности букв, куски сшиты вдоль полосы с плавным переходом ———
def logo_detail_patches():
    logo = Image.open(os.path.join(HERE, '..', 'res', 'logo-game.png')).convert('RGBA')
    L = np.asarray(logo.convert('L'), float)
    detail = L - gblur(L, 5)
    inner = np.asarray(logo.getchannel('A').filter(ImageFilter.MinFilter(LOGO_P + 7 | 1)), float) > 250   # центр куска P×P целиком внутри буквы
    ys, xs = np.nonzero(inner)
    return detail, ys, xs

LOGO_P = 34                    # сторона куска логотипа в его пикселях: больше кусок — мельче рисунок на полосе

def surf_logo(h, w, u, alpha, rng):
    detail, ys, xs = logo_detail_patches()
    P, step = LOGO_P, int(h * .7)
    tex = np.zeros((h, w)); wsum = np.zeros((h, w))
    ramp = np.minimum(1, np.minimum(np.arange(h) + 1, h - np.arange(h)) / (h * .2))   # вес куска к краям падает — швы растворяются
    x0 = -h // 3
    while x0 < w:
        i = rng.integers(len(ys)); cy, cx = ys[i], xs[i]
        patch = detail[cy - P // 2: cy + P // 2, cx - P // 2: cx + P // 2]
        patch = np.rot90(patch, rng.integers(4))
        patch = np.asarray(Image.fromarray(patch.astype(np.float32), 'F').resize((h, h), Image.BICUBIC), float)
        a, b = max(0, x0), min(w, x0 + h)
        wgt = ramp[a - x0: b - x0][None, :] * np.ones((h, 1))
        tex[:, a:b] += patch[:, a - x0: b - x0] * wgt; wsum[:, a:b] += wgt
        x0 += step
    tex /= np.maximum(wsum, 1e-6)
    H = bevel(u) * 12 + tex * .16
    alb = albedo_map(h, w, rng) * (1 + np.clip(tex, -60, 60) / 255 * 1.6)[:, :, None]
    return lit(H, alb), alpha

# ——— 3. Рельеф со светом: многослойный шум как карта высот ———
def surf_relief(h, w, u, alpha, rng):
    H = bevel(u) * 12 + fbm(h, w, [3, 7, 16, 40], rng) * 9 + grain(h, w, rng, .25)
    return lit(H, albedo_map(h, w, rng)), alpha

# ——— 4. Кованые грани: ячейки Вороного, в каждой — плоскость своего наклона ———
def surf_facets(h, w, u, alpha, rng):
    n = int(w / (h * .45))
    px, py = rng.uniform(0, w, n), rng.uniform(-h * .2, h * 1.2, n)
    sa, sb = rng.uniform(-.55, .55, n), rng.uniform(-.55, .55, n)
    order = np.argsort(px); px, py, sa, sb = px[order], py[order], sa[order], sb[order]
    H = np.zeros((h, w)); yy = np.arange(h)[:, None].astype(float)
    CH = 256
    for x0 in range(0, w, CH):
        x1 = min(w, x0 + CH); xx = np.arange(x0, x1)[None, :].astype(float)
        lo, hi = np.searchsorted(px, x0 - h * 2), np.searchsorted(px, x1 + h * 2)
        best = np.full((h, x1 - x0), np.inf); val = np.zeros((h, x1 - x0))
        for k in range(lo, hi):
            d = (xx - px[k]) ** 2 + (yy - py[k]) ** 2
            m = d < best; best[m] = d[m]
            val[m] = (sa[k] * (xx - px[k]) + sb[k] * (yy - py[k]))[m]
        H[:, x0:x1] = val
    H = H + bevel(u) * 12 + grain(h, w, rng, .2)
    return lit(H, albedo_map(h, w, rng), k=.9), alpha

# ——— 5. Литьё с порами: песчаная шероховатость и раковины ———
def surf_cast(h, w, u, alpha, rng):
    sand = fbm(h, w, [2, 3, 6], rng)
    pores_n = fnoise(h, w, 4, 4, rng)
    pore = smoothstep(.2, .1, pores_n)
    big = smoothstep(.12, .05, fnoise(h, w, 14, 14, rng))
    H = bevel(u) * 12 + sand * 3 - pore * 5 - big * 8
    alb = albedo_map(h, w, rng) * (1 - (pore * .55 + big * .6))[:, :, None]
    return lit(H, alb), alpha

# ——— 6. Напильник: продольные полосы опиловки и косая двойная насечка ———
def surf_file(h, w, u, alpha, rng):
    streak = np.asarray(Image.fromarray(rng.normal(0, 1, (h, w // 60 + 2)).astype(np.float32), 'F').resize((w, h), Image.BILINEAR), float)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    wob = fnoise(h, w, 20, 20, rng) * 6
    hatch = sum(np.abs(np.sin(((xx * math.cos(a) + yy * math.sin(a)) / 7.0 + wob) * math.pi)) for a in (math.radians(35), math.radians(-35)))
    H = bevel(u) * 12 + streak * 1.4 + hatch * 1.1 + grain(h, w, rng, .2)
    return lit(H, albedo_map(h, w, rng)), alpha

# ——— 7. Коррозия: металл съеден от краёв до дыр, у ям — валики ———
def surf_corrosion(h, w, u, alpha, rng):
    E = fbm(h, w, [3, 8, 20], rng)
    edge = 1 - np.minimum(u, 1 - u) * 2
    thr = .22 + .32 * edge ** 2
    hole = E < thr
    a2 = alpha * (~hole)
    near = np.exp(-((E - thr) / .05) ** 2)
    pit = smoothstep(thr + .12, thr, E)
    H = bevel(u) * 12 + near * 5 - pit * 6 + grain(h, w, rng, .3)
    alb = albedo_map(h, w, rng) * (1 - pit * .5)[:, :, None]
    alb = alb * (1 - pit[:, :, None] * .3) + np.array([110, 52, 20.]) * (pit[:, :, None] * .3)   # в ямах — бурый налёт
    return lit(H, alb), a2

# ——— 8. Рубка зубилом: косые срубы поперёк полосы, у каждого ската свой наклон ———
def surf_chisel(h, w, u, alpha, rng):
    cuts = [0.]
    while cuts[-1] < w + h * 2: cuts.append(cuts[-1] + rng.uniform(.5, 1.6) * h)
    cuts = np.array(cuts) - h
    tilt = np.tan(np.radians(rng.normal(0, 22, len(cuts))))
    slope = rng.choice([-1, 1], len(cuts)) * rng.uniform(.25, .6, len(cuts))
    yslope = rng.uniform(-.25, .25, len(cuts))
    H = np.zeros((h, w)); xx = np.arange(w).astype(float)
    for y in range(h):
        pos = cuts + (y - h / 2) * tilt
        seg = np.clip(np.searchsorted(pos, xx) - 1, 0, len(cuts) - 2)
        mid = (pos[seg] + pos[seg + 1]) / 2
        H[y] = slope[seg] * (xx - mid) + yslope[seg] * (y - h / 2)
    H = H + bevel(u) * 12 + grain(h, w, rng, .25)
    return lit(H, albedo_map(h, w, rng), k=.85), alpha

ALGOS = {1: surf_scratches, 2: surf_logo, 3: surf_relief, 4: surf_facets, 5: surf_cast, 6: surf_file, 7: surf_corrosion, 8: surf_chisel}

def strip(length, n, which):
    w = length * SS
    h, u, alpha = geometry(w, np.random.default_rng(SEED_SHAPE + which))   # форма одна у всех алгоритмов
    rgb, a = ALGOS[n](h, w, u, alpha, np.random.default_rng(SEED_SURF + which))
    im = Image.fromarray(np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8), 'RGBA')
    return im.resize((length, TMAX), Image.LANCZOS)

def lines_sheet(nums):
    W, ZOOM, LABEL_H, GAP = 3840, 3, 70, 50
    font = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 46)
    strips = [Image.open(os.path.join(OUT, f'frame_h_{n}.webp')).convert('RGBA') for n in nums]
    sh = TMAX * ZOOM
    sheet = Image.new('RGBA', (W, GAP + len(nums) * (LABEL_H + sh + GAP)), (22, 18, 14, 255)); d = ImageDraw.Draw(sheet); y = GAP
    for n, s in zip(nums, strips):
        d.text((40, y), f'{n}   {NAMES[n]}', fill='#ffd27e', font=font); y += LABEL_H
        sheet.alpha_composite(s.crop((0, 0, W // ZOOM, TMAX)).resize((W, sh), Image.LANCZOS), (0, y)); y += sh + GAP
    sheet.convert('RGB').save(os.path.join(OUT, 'lines.webp'), 'WEBP', quality=92)

def main():
    os.makedirs(OUT, exist_ok=True)
    nums = [int(x) for x in sys.argv[1].split(',')] if len(sys.argv) > 1 else list(ALGOS)
    for n in nums:
        hz = strip(LONG_H, n, 0)
        vt = strip(LONG_V, n, 1).rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT)
        hz.save(os.path.join(OUT, f'frame_h_{n}.webp'), 'WEBP', quality=90)
        vt.save(os.path.join(OUT, f'frame_v_{n}.webp'), 'WEBP', quality=90)
        print(n, NAMES[n], hz.size, vt.size)
    lines_sheet(sorted(set(nums) | {int(f.split('_')[-1].split('.')[0]) for f in os.listdir(OUT) if f.startswith('frame_h_')}))

if __name__ == "__main__":
    main()
