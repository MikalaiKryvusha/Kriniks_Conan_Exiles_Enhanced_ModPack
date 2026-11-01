# Текстура каймы лаунчера — плоская кованая полоса грубого металла, как края букв логотипа Conan Exiles. Слова владельца 2026-10-31:
# 18:26 «не из гладкого металла, а из грубого, как в логотипе конана» · «тоньще койма»; 18:30 «контур тоньшн и плоский кованный метал, а не круглый»;
# 18:31 «некрасивая кайма» · «тени на койме были» (пятна света и тени — нет); 18:32, 18:34 «метал грубее» · «без идельных углов».
# Поэтому: поперёк полосы — плоскость (узкая фаска у края, широкая ровная медь-золото), ширина полосы гуляет вдоль края, внутренняя кромка
# неровная, по внешней — сколы, концы полосы скруглены и сбиты (углы рамы не под линейку, полосы заходят друг на друга); грубость — мелкими
# следами: зерно, светлые царапины, зарубки, раковины. Тёмных пятен нет.
# Пишет две полосы под 4K при масштабе 4 (кайма около 5 логических пикселей, до 6 — по самым широким местам):
#   frame_h.webp — 3840×24, верх окна (низ — она же, перевёрнутая);  frame_v.webp — 24×2160, левый край (правый — перевёрнутая).
# Прозрачность — там, где полоса уже своей наибольшей ширины и в сколах (WebP с альфа-каналом).
# Запуск: python -X utf8 make_frame.py [папка]   (по умолчанию — рядом со скриптом)
# [NOT-TESTED]
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TMAX = 24                      # наибольшая ширина полосы в пикселях картинки (6 логических × 4)
T_MEAN, T_SWING = 19, 4        # средняя ширина и её разброс вдоль края
LONG_H, LONG_V = 3840, 2160    # длина полос: ширина и высота окна 960×540 × 4
SEED = 31
SS = 3                         # рисуем крупнее и уменьшаем: штрихи и кромки без сглаживания иначе ступенчатые

# Восемь металлов (18:36 «дай варианты металла, 8 штук»). Форма у всех одна — тот же SEED; меняется только металл:
#   flat — профиль поперёк полосы от внешнего края к внутреннему; pit — во что уходят каверны и рябь (тёмное, патина, ржа);
#   lite / dark — цвет светлых и тёмных царапин; grain — сила зерна.
PRESETS = {
    1: dict(name='медь-золото', grain=1.25, pit='#140902', lite=(255, 244, 210), dark=(30, 12, 3),
            flat=[("#2a1606", 0), ("#8a4f1c", .08), ("#ffd98e", .17), ("#e3a552", .3), ("#d39443", .55), ("#b97a34", .78), ("#7a4516", .9), ("#2a1606", 1)]),
    2: dict(name='тёмная бронза с патиной', grain=1.1, pit='#2f6b5a', lite=(236, 206, 150), dark=(20, 14, 6),
            flat=[("#1a1206", 0), ("#5e4318", .08), ("#c9a05a", .17), ("#8f6a30", .3), ("#7d5c28", .55), ("#6b4d20", .78), ("#4a3414", .9), ("#160f05", 1)]),
    3: dict(name='чёрное железо', grain=1.3, pit='#5a2a10', lite=(220, 222, 226), dark=(6, 6, 8),
            flat=[("#0c0c0e", 0), ("#3a3a40", .08), ("#9a9ca4", .17), ("#55565c", .3), ("#47484e", .55), ("#3a3b40", .78), ("#26272b", .9), ("#0a0a0c", 1)]),
    4: dict(name='ржавое железо', grain=1.5, pit='#3a1404', lite=(240, 190, 140), dark=(30, 10, 2),
            flat=[("#1c0b03", 0), ("#6b2e0e", .08), ("#d4864a", .17), ("#a24f1e", .3), ("#8e4318", .55), ("#7a3a16", .78), ("#4f240c", .9), ("#180902", 1)]),
    5: dict(name='старое золото', grain=1.0, pit='#3a2a08', lite=(255, 250, 220), dark=(50, 34, 6),
            flat=[("#2a1e06", 0), ("#8a6a1c", .08), ("#fff0a8", .17), ("#e8c35a", .3), ("#d9b04a", .55), ("#c49a38", .78), ("#7a5e18", .9), ("#241a05", 1)]),
    6: dict(name='красная медь', grain=1.2, pit='#2a0c04', lite=(255, 214, 190), dark=(36, 10, 4),
            flat=[("#240c04", 0), ("#7a2e12", .08), ("#f4a07a", .17), ("#c86a40", .3), ("#b45a32", .55), ("#9a4828", .78), ("#5e2a14", .9), ("#1e0a03", 1)]),
    7: dict(name='кованая сталь', grain=1.2, pit='#1a1c20', lite=(255, 255, 255), dark=(20, 22, 26),
            flat=[("#1a1c1f", 0), ("#5c6168", .08), ("#e6e9ee", .17), ("#a9adb4", .3), ("#9a9ea6", .55), ("#868a92", .78), ("#4e5258", .9), ("#16181b", 1)]),
    8: dict(name='закопчённая латунь, светлые края', grain=1.2, pit='#0a0703', lite=(255, 232, 170), dark=(8, 6, 2),
            flat=[("#1a1206", 0), ("#c9a050", .07), ("#ffe6a0", .14), ("#4a3818", .26), ("#2e2210", .5), ("#4a3818", .74), ("#d9ac58", .86), ("#1a1206", 1)]),
}

def hex2rgb(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)
P = None; STOP_POS = STOP_RGB = PIT = None

def use(preset):
    # Делает рецепт текущим для draw_strip.
    global P, STOP_POS, STOP_RGB, PIT
    P = PRESETS[preset]
    STOP_POS = np.array([p for _, p in P['flat']]); STOP_RGB = np.array([hex2rgb(c) for c, _ in P['flat']]); PIT = hex2rgb(P['pit'])

def smooth1d(n, step, rng):
    # Плавная случайная кривая длины n: точки через step, между ними — косинусная интерполяция.
    pts = rng.random(n // step + 3)
    x = np.arange(n) / step; i = x.astype(int); t = (1 - np.cos((x - i) * math.pi)) / 2
    return pts[i] * (1 - t) + pts[i + 1] * t

def draw_strip(w, rng):
    h = TMAX * SS
    # Ширина полосы вдоль края: гуляет крупно, средне и мелко — внутренняя кромка рваная, а не линейка (18:35 «без идеальных ровных краев»).
    t = (T_MEAN + T_SWING * ((smooth1d(w, 200 * SS, rng) - .5) * 1.2 + (smooth1d(w, 30 * SS, rng) - .5) * 1.0
                             + (smooth1d(w, 5 * SS, rng) - .5) * .9 + (rng.random(w) - .5) * .35)) * SS
    t = np.clip(t, (T_MEAN - T_SWING - 2) * SS, h - 1)
    # Внешняя кромка: мелкая рябь по всей длине и частые сколы разной глубины.
    chip = np.clip((smooth1d(w, 6 * SS, rng) - .35) * 2.2 * SS, 0, None)
    for _ in range(int(w / (28 * SS))):
        c = rng.uniform(0, w); r = rng.uniform(3, 18) * SS; dep = rng.uniform(1, 4.5) * SS
        xs = np.arange(max(0, int(c - r)), min(w, int(c + r)))
        chip[xs] = np.maximum(chip[xs], dep * np.sqrt(np.clip(1 - ((xs - c) / r) ** 2, 0, 1)))
    # Концы полосы — углы рамы: скруглены неровно, радиус и сбитость у каждого конца свои.
    for end in (0, 1):
        R = rng.uniform(9, 20) * SS
        xs = np.arange(int(R)) if end == 0 else np.arange(w - int(R), w)
        d = (xs if end == 0 else (w - 1 - xs)).astype(float)
        cut = R - np.sqrt(np.clip(R ** 2 - (R - d) ** 2, 0, None))
        chip[xs] = np.maximum(chip[xs], cut + smooth1d(len(xs) + 8, 2 * SS, rng)[:len(xs)] * 4 * SS)
    y = np.arange(h)[:, None].astype(float)
    u = np.clip((y - chip[None, :]) / (t[None, :] - chip[None, :]), 0, 1)
    rgb = np.stack([np.interp(u, STOP_POS, STOP_RGB[:, k]) for k in range(3)], axis=2)
    alpha = ((y >= chip[None, :]) & (y <= t[None, :])).astype(float)
    # Зерно — грубое и контрастное, плюс коррозийная рябь (мелкие тёмные крупинки порогом по шуму); крупных пятен света и тени нет.
    grain = rng.normal(0, 1, (h, w))
    grain = np.asarray(Image.fromarray(((grain * 40) + 128).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9)), float) / 255 - .5
    pit = np.asarray(Image.fromarray((rng.random((h, w)) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.6)), float) / 255
    pit = np.clip((.47 - pit) * 14, 0, 1)
    rgb = rgb * (1 + grain * P['grain'])[:, :, None]
    rgb = (rgb * (1 - pit * .75)[:, :, None] + PIT[None, None, :] * (pit * .75)[:, :, None]).clip(0, 255)
    im = Image.fromarray(np.dstack([rgb, alpha * 255]).astype(np.uint8), 'RGBA')
    over = Image.new('RGBA', im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(over, 'RGBA')
    f = T_MEAN / 80
    # Царапины: светлые (свежий металл), реже тёмные — в основном вдоль полосы.
    for _ in range(int(w * .9 * f)):
        x, yy = rng.uniform(0, w), rng.uniform(h * .1, h * .8)
        L = rng.uniform(18, 200); a = math.radians(rng.normal(0, 22))
        col = P['lite'] + (int(rng.uniform(80, 190)),) if rng.random() < .65 else P['dark'] + (int(rng.uniform(90, 170)),)
        d.line([(x, yy), (x + L * math.cos(a), yy + L * math.sin(a))], fill=col, width=2)
    # Зарубки поперёк — как на буквах логотипа.
    for _ in range(int(w * .009)):
        x = rng.uniform(0, w); a = math.radians(rng.normal(90, 25)); L = rng.uniform(h * .3, h * .7); yy = rng.uniform(0, h * .5)
        d.line([(x, yy), (x + L * math.cos(a), yy + L * math.sin(a))], fill=P['dark'] + (170,), width=3)
        d.line([(x + 3, yy), (x + 3 + L * math.cos(a), yy + L * math.sin(a))], fill=P['lite'] + (80,), width=2)
    # Раковины: тёмные точки разного размера.
    for _ in range(int(w * .6 * f)):
        x, yy = rng.uniform(0, w), rng.uniform(h * .05, h * .9); r = rng.uniform(2, 9) if rng.random() < .25 else rng.uniform(1.2, 4)   # каверны — крупные и мелкие
        d.ellipse([x - r, yy - r, x + r, yy + r], fill=tuple(int(c * .6) for c in PIT) + (int(rng.uniform(70, 160)),))
    # Следы рисуются только по металлу: прозрачные места полосы остаются прозрачными.
    over.putalpha(Image.fromarray((np.asarray(over.getchannel('A'), float) * alpha).astype(np.uint8)))
    im.alpha_composite(over)
    return im

def strip(length, rng):
    return draw_strip(length * SS, rng).resize((length, TMAX), Image.LANCZOS)

def make(preset, out, suffix):
    use(preset)
    rng = np.random.default_rng(SEED)  # один источник случайности на обе полосы — форма одна у всех металлов
    h = strip(LONG_H, rng)
    v = strip(LONG_V, rng).rotate(90, expand=True).transpose(Image.FLIP_LEFT_RIGHT)  # внешний край — слева
    h.save(os.path.join(out, f'frame_h{suffix}.webp'), 'WEBP', quality=90)
    v.save(os.path.join(out, f'frame_v{suffix}.webp'), 'WEBP', quality=90)
    print(preset, P['name'], h.size, h.mode, v.size, v.mode)

def main():
    # frame_h.webp / frame_v.webp — металл макета по умолчанию (1); metals/frame_*_N.webp — все восемь для ?metal=N.
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))
    make(1, out, '')
    os.makedirs(os.path.join(out, 'metals'), exist_ok=True)
    for n in PRESETS: make(n, os.path.join(out, 'metals'), f'_{n}')

main()
