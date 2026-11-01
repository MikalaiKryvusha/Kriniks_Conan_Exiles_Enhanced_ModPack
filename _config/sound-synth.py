# Синтез чистого «дзинь» кончика стрелы с мягким отзвуком зала — страница вариантов для выбора на слух.
# Слово владельца 2026-10-28: «мягкий отзвук как в зале, но какой-то там "грязный" колокольчик, может можно свой синтезировать? Это классический
# дзинь кончика стрелы». Звон — сумма негармоничных обертонов тонкого металлического стержня (свободный брусок: 1 · 2,756 · 5,404 · 8,933), каждый со
# своим затуханием (верхние гаснут быстрее), атака 2 мс; отзвук — тот же aecho, что у понравившегося варианта 9 sound-variants.py; громкость —
# по максимуму мгновенной громкости того варианта (образец — третий аргумент).
# Запуск: python -I -X utf8 sound-synth.py <папка вывода> <образец громкости.wav>   [NOT-TESTED]
import html, importlib.util, pathlib, subprocess, sys
import numpy as np

spec = importlib.util.spec_from_file_location('prep', pathlib.Path(__file__).with_name('sound-prep.py'))
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)
OUT, REF = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
prep.OUT = OUT
SR = prep.SR
BAR = [(1.0, 1.0), (2.756, 0.45), (5.404, 0.22), (8.933, 0.10)]   # доля частоты, доля громкости
HALL = 'apad=pad_dur=1.2,aecho=0.8:0.6:40|90|150:0.30|0.20|0.12'

VARIANTS = [   # подпись, основной тон Гц, затухание основного с, сколько обертонов, отзвук, яркость (верхи дБ)
    ('высокий тонкий дзинь, короткий', 3200, 0.35, 4, True, 0),
    ('высокий тонкий дзинь, звенит подольше', 3200, 0.8, 4, True, -3),
    ('средний, чистый, звенит подольше', 2400, 0.8, 3, True, -3),
    ('средний, мягкий, почти без верхов', 2400, 0.6, 2, True, -6),
    ('ниже, «стальной», коротко', 1700, 0.45, 4, True, -3),
    ('ниже, «стальной», долгий', 1700, 1.1, 3, True, -4),
    ('совсем чистый тон, как стекло', 2800, 0.7, 1, True, 0),
    ('высокий тонкий дзинь без отзвука — для сравнения', 3200, 0.35, 4, False, 0),
]
# Набор «short» — после выбора владельца 2026-10-28: «высокий тонкий дзинь, короткий» · «но нужно ещё короче». Отзвук: True — зал, 'short' — короче
SHORT = [
    ('как было (№1) — для сравнения', 3200, 0.35, 4, True, 0),
    ('звон 0,25 с', 3200, 0.25, 4, True, 0),
    ('звон 0,18 с', 3200, 0.18, 4, True, 0),
    ('звон 0,12 с', 3200, 0.12, 4, True, 0),
    ('звон 0,18 с, отзвук короче', 3200, 0.18, 4, 'short', 0),
    ('звон 0,12 с, отзвук короче', 3200, 0.12, 4, 'short', 0),
]
HALL_SHORT = 'apad=pad_dur=0.6,aecho=0.8:0.5:30|60:0.25|0.12'
# Набор «soft» — выбор владельца 2026-10-28: вариант 6 набора short, «но пик дзыня нужно мягче, изящнее» (набрано в английской раскладке:
# «6? yj gbr lpsyz ye;yj vzprt? bpzott»). Седьмое поле — нарастание удара, мс (было 2); шестое — верхи, дБ; четвёртое — сколько обертонов.
SOFT = [
    ('как было (№6) — для сравнения', 3200, 0.12, 4, 'short', 0, 2),
    ('удар мягче — нарастание 8 мс', 3200, 0.12, 4, 'short', 0, 8),
    ('удар ещё мягче — 15 мс', 3200, 0.12, 4, 'short', 0, 15),
    ('удар совсем мягкий — 25 мс', 3200, 0.12, 4, 'short', 0, 25),
    ('15 мс и тише верхние обертоны — тоньше', 3200, 0.12, 4, 'short', -5, 15),
    ('15 мс, только два обертона — чище всего', 3200, 0.12, 2, 'short', 0, 15),
]
# Набор «tender» — владелец 2026-10-28: «ЕЩЕ нежнее удар, а отзвук дольше». 'long' — зал с поздними долгими отражениями
HALL_LONG = 'apad=pad_dur=2.2,aecho=0.8:0.7:50|120|220|350:0.35|0.25|0.18|0.10'
# Число в поле отзвука — настоящий зал: свёртка с синтезированным откликом, время затухания RT60 в секундах. aecho без обратной связи даёт лишь
# несколько отражений — «длинный» вариант на aecho глохнул к ≈0,9 с, как и обычный (лист волн 2026-10-28)
TENDER = [
    ('как было (25 мс, короткий отзвук) — для сравнения', 3200, 0.12, 4, 'short', 0, 25),
    ('удар 40 мс, отзвук зала', 3200, 0.12, 4, True, -3, 40),
    ('удар 60 мс, отзвук зала', 3200, 0.12, 4, True, -3, 60),
    ('удар 40 мс, долгий отзвук зала (1,2 с)', 3200, 0.12, 4, 1.2, -3, 40),
    ('удар 60 мс, долгий отзвук зала (1,8 с)', 3200, 0.12, 4, 1.8, -3, 60),
    ('удар 80 мс, долгий отзвук (1,8 с), верхи тише', 3200, 0.12, 4, 1.8, -6, 80),
]
REVERB_MIX = 0.35    # доля «мокрого» сигнала зала


def hall_reverb(y, rt60):
    # отклик зала: шум с плавным подъёмом 15 мс и затуханием −60 дБ за rt60, верхи отклика глушатся одним полюсом (зал «тёплый»)
    rng = np.random.default_rng(11)
    n = int(SR * rt60 * 1.1)
    t = np.arange(n) / SR
    ir = rng.standard_normal((n, 2)) * np.exp(-6.91 * t / rt60)[:, None]
    a = 0.6
    for i in range(1, n):
        ir[i] = a * ir[i - 1] + (1 - a) * ir[i]
    ir[:int(0.015 * SR)] *= np.linspace(0, 1, int(0.015 * SR))[:, None]
    ir /= np.sqrt((ir ** 2).sum(axis=0))
    m = len(y) + n - 1
    size = 1 << (m - 1).bit_length()
    wet = np.stack([np.fft.irfft(np.fft.rfft(y[:, c], size) * np.fft.rfft(ir[:, c], size), size)[:m] for c in range(2)], axis=1)
    dry = np.pad(y, ((0, n - 1), (0, 0)))
    return (dry + REVERB_MIX * wet).astype(np.float32)
# Набор «round» — владелец 2026-10-28: «4 нравится, но ты размазываешь передний фронт аттаки, но пик все равно острый». Поля 8–9: ширина
# сглаживания вершины, мс · верхние обертоны вступают позже
ROUND = [
    ('как было (№4) — для сравнения', 3200, 0.12, 4, 1.2, -3, 40),
    ('скруглённая вершина, 60 мс', 3200, 0.12, 4, 1.2, -3, 0, 60, False),
    ('скруглённая вершина, мягче — 90 мс', 3200, 0.12, 4, 1.2, -3, 0, 90, False),
    ('скруглённая 60 мс, верхние обертоны вступают позже', 3200, 0.12, 4, 1.2, -3, 0, 60, True),
    ('скруглённая 90 мс, верхние позже — самый мягкий', 3200, 0.12, 4, 1.2, -3, 0, 90, True),
    ('скруглённая 60 мс, верхи тише на 6 дБ', 3200, 0.12, 4, 1.2, -6, 0, 60, False),
]
if len(sys.argv) > 3 and sys.argv[3] == 'tender':
    VARIANTS = TENDER
# Набор «fastsoft»: поля 7 — атака мс, 10 — скругление вершины мс (поле 8 «сглаживание окном» не используется, None)
FASTSOFT = [
    ('как было (№4) — для сравнения', 3200, 0.12, 4, 1.2, -3, 40),
    ('атака 8 мс, вершина мягкая (30 мс)', 3200, 0.12, 4, 1.2, -3, 8, None, False, 30),
    ('атака 8 мс, вершина мягче (60 мс)', 3200, 0.12, 4, 1.2, -3, 8, None, False, 60),
    ('атака 12 мс, вершина мягче (60 мс)', 3200, 0.12, 4, 1.2, -3, 12, None, False, 60),
    ('атака 8 мс, вершина 60 мс, верхние обертоны мягче', 3200, 0.12, 4, 1.2, -3, 8, None, True, 60),
    ('атака 12 мс, вершина 90 мс, верхние мягче — самый округлый', 3200, 0.12, 4, 1.2, -3, 12, None, True, 90),
]
if len(sys.argv) > 3 and sys.argv[3] == 'round':
    VARIANTS = ROUND
if len(sys.argv) > 3 and sys.argv[3] == 'fastsoft':
    VARIANTS = FASTSOFT
if len(sys.argv) > 3 and sys.argv[3] == 'short':
    VARIANTS = SHORT
if len(sys.argv) > 3 and sys.argv[3] == 'soft':
    VARIANTS = SOFT


def ding(f0, decay, partials, attack_ms=2, round_ms=None, late_highs=False, top_ms=None):
    n = int(SR * max(1.6, decay * 4))
    t = np.arange(n) / SR
    y = np.zeros(n)
    rng = np.random.default_rng(7)
    for ratio, amp in BAR[:partials]:
        f = f0 * ratio * (1 + rng.uniform(-0.002, 0.002))     # чуть живой расстройки — без «синтетики»
        if f > SR / 2 * 0.9:
            continue
        tau = decay / ratio ** 0.6
        env = np.exp(-t / tau)
        if top_ms:
            # Быстрая атака и мягкая вершина раздельно (владелец 2026-10-28: «атаку можно быстрее» · «а пик мягце»): спад начинается с нулевого
            # наклона — exp(−(√(t² + c²) − c)/τ), c — ширина скругления вершины (у верхних обертонов шире, если late_highs); атака — ниже, короткая
            c = top_ms / 1000 * (ratio ** 0.5 if late_highs else 1.0)
            env = np.exp(-(np.sqrt(t * t + c * c) - c) / tau)
        if round_ms:
            # Скруглённая вершина: затухание, сглаженное окном Ханна, — подъём сам перетекает в вершину и спад без угла. Владелец 2026-10-28 о
            # варианте с плавным подъёмом: «ты размазываешь передний фронт аттаки, но пик все равно острый» — там подъём упирался в спад углом.
            w = int((round_ms * (ratio ** 0.5 if late_highs else 1.0)) / 1000 * SR)   # верхние обертоны вступают позже и мягче
            h = np.hanning(w)
            env = np.convolve(env, h)[:n] / h.sum()
        y += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * env
    if not round_ms:
        attack = int(attack_ms / 1000 * SR)
        y[:attack] *= (0.5 * (1 - np.cos(np.linspace(0, np.pi, attack))))   # плавное нарастание — мягче пик удара
    return np.stack([y, y], axis=1).astype(np.float32)


target = prep.momentary_max(REF)
rows = []
for i, v in enumerate(VARIANTS, 1):
    title, f0, decay, partials, hall, high_db = v[:6]
    attack_ms = v[6] if len(v) > 6 else 2
    round_ms = v[7] if len(v) > 7 else None
    late_highs = v[8] if len(v) > 8 else False
    top_ms = v[9] if len(v) > 9 else None
    y = ding(f0, decay, partials, attack_ms, round_ms, late_highs, top_ms)
    af = [f'highshelf=f=5000:g={high_db}'] if high_db else []
    rt60 = hall if isinstance(hall, float) else None
    if rt60:
        y = hall_reverb(y, rt60)
    elif hall:
        af.append({'short': HALL_SHORT, 'long': HALL_LONG}.get(hall, HALL))
    tmp = OUT / '_raw.wav'
    prep.write_wav(y * 0.5, tmp)
    out = OUT / f'{i:02d}.wav'
    # после затухания — без пустой тишины; у коротких — короче и сам файл
    # длина файла — по отзвуку: короткий — по звону, зал — 2,2 с (у долгого звона — 2,7), длинный зал — 3,2 с с затуханием 1,2 с
    if rt60:
        end, fade = 0.3 + rt60 * 1.1, 0.5
    elif hall == 'long':
        end, fade = 3.2, 1.2
    elif hall == 'short' or (decay < 0.3 and hall is not True):
        end, fade = min(2.7, 0.9 + decay * 4), 0.8
    else:
        end, fade = (2.2 if decay < 0.3 else 2.7), 0.8
    chain = ','.join(af + [f'afade=t=out:st={end - fade:.2f}:d={fade}', f'atrim=0:{end:.2f}'])
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(tmp), '-af', chain, '-c:a', 'pcm_s16le', str(out)], check=True)
    gain = target - prep.momentary_max(out)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(out), '-af', f'volume={gain:.2f}dB,alimiter=limit=0.891:level=0',
                    '-c:a', 'pcm_s16le', str(tmp)], check=True)
    tmp.replace(out)
    rows.append((title, out.name))
    print(i, title, f0, decay, partials, hall, high_db, 'gain', round(gain, 1))

items = '\n'.join(f'<li><button data-src="{html.escape(o)}">▶</button><span class="n">{i}</span><span class="t">{html.escape(t)}</span>'
                  f'<span class="d"></span></li>' for i, (t, o) in enumerate(rows, 1))
page = (pathlib.Path(__file__).with_name('sound-prep.html').read_text(encoding='utf-8')
        .replace('{{ITEMS}}', items).replace('{{COUNT}}', str(len(rows)))
        .replace('<h1>Звук полного натяжения лука</h1>', '<h1>Дзинь кончика стрелы — синтез</h1>')
        .replace(f'{len(rows)} звуков. Громкость выровнена, тишина спереди срезана, после удара — не дольше 4 с, в конце затухание. '
                 'Назовите номер, который ставить в игру.',
                 'Свой чистый звон, без записи. У всех, кроме последнего, мягкий отзвук зала, как в варианте 9; громкость — как у варианта 9. '
                 'Назовите номер.'))
(OUT / 'index.html').write_text(page, encoding='utf-8')
print('OK', len(rows), '->', OUT)
