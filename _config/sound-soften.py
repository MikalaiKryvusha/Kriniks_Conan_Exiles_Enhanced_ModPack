# Варианты одного звука с мягким ударом и плавным растворением в тишину — для выбора на слух.
# Слово владельца 2026-10-28: «звук 15 нравиться, давай с ним поработаем. Удар сделать не таким резким. Может нормировать кромкость, и фейд
# в конце более плавный, чтобы незаметно звок растрорялся в тишину» (№15 — koiroylers-cheerful-ping-356011).
# Удар смягчают три ручки: нарастание громкости в начале (мс), сжатие пика (дБ, компрессор с быстрой атакой) и приглушение верхов (дБ на
# 5 кГц — щелчок удара живёт в верхах). Хвост гаснет ровно по децибелам до −60 дБ: на слух так звук растворяется, а не обрывается.
# Запуск: python -I -X utf8 sound-soften.py <исходник> <папка вывода>   [NOT-TESTED]
import html, importlib.util, json, pathlib, sys
import numpy as np

spec = importlib.util.spec_from_file_location('prep', pathlib.Path(__file__).with_name('sound-prep.py'))
prep = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prep)   # функции sound-prep: декодирование, огибающая, замер громкости, запись WAV
SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
prep.OUT = OUT
SR = prep.SR

TAIL_FLOOR_DB = -60.0
VARIANTS = [   # имя, нарастание мс, сжатие пика дБ, верхи дБ, затухание с какой доли звука
    ('A — как было, только хвост плавнее', 3, 0, 0, 0.35),
    ('B — удар чуть мягче', 15, 3, -2, 0.30),
    ('C — удар мягче', 30, 5, -4, 0.25),
    ('D — удар заметно мягче', 50, 7, -6, 0.20),
    ('E — совсем мягко, почти без удара', 80, 9, -8, 0.15),
]


def ff(x, af):
    import subprocess
    pcm = x.astype('<f4').tobytes()
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', '-af', af, '-f', 'f32le', '-'],
                         input=pcm, capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


x = prep.decode(SRC)
env = prep.envelope(x)
peak = float(env.max())
lead = peak * 10 ** (prep.LEAD_DB / 20)
tail = peak * 10 ** (prep.SILENCE_DB / 20)
start = max(0, int(np.nonzero(env > lead)[0][0]) - int(prep.PRE_ROLL_S * SR))
end = int(np.nonzero(env > tail)[0][-1]) + 1
base = x[start:end]
rows = []
for i, (name, rise_ms, squash_db, high_db, fade_from) in enumerate(VARIANTS):
    y = base.copy()
    filters = []
    if high_db:
        filters.append(f'highshelf=f=5000:g={high_db}')
    if squash_db:
        # порог — на squash_db ниже пика, сжатие 8:1: срезается почти весь выступ удара, тело звука не тронуто
        thr = peak * 10 ** (-squash_db / 20)
        filters.append(f'acompressor=threshold={thr:.5f}:ratio=8:attack=0.5:release=80:knee=4:makeup=1')
    if filters:
        y = ff(y, ','.join(filters))
    n = len(y)
    rise = int(rise_ms / 1000 * SR)
    y[:rise] *= (0.5 * (1 - np.cos(np.linspace(0, np.pi, rise))))[:, None].astype(np.float32)
    f0 = int(n * fade_from)
    # хвост: от f0 до конца громкость падает ровно по дБ до −60 — растворение без ступеньки
    db = np.linspace(0, TAIL_FLOOR_DB, n - f0)
    y[f0:] *= (10 ** (db / 20))[:, None].astype(np.float32)
    tmp = OUT / '_measure.wav'
    prep.write_wav(y, tmp)
    gain = prep.TARGET_MOMENTARY - prep.momentary_max(tmp)
    tmp.unlink()
    y *= 10 ** (gain / 20)
    out = OUT / f'15{chr(ord("a") + i)}.wav'
    prep.write_wav(y, out, limit=True)
    rows.append(dict(title=name, out=out.name, out_s=n / SR, m_out=prep.momentary_max(out)))
    print(json.dumps(rows[-1], ensure_ascii=False))

items = '\n'.join(f'<li><button data-src="{html.escape(r["out"])}">▶</button><span class="n">{chr(65 + i)}</span>'
                  f'<span class="t">{html.escape(r["title"][4:])}</span><span class="d">{r["out_s"]:.1f} с</span></li>' for i, r in enumerate(rows))
page = (pathlib.Path(__file__).with_name('sound-prep.html').read_text(encoding='utf-8')
        .replace('{{ITEMS}}', items).replace('{{COUNT}}', str(len(rows)))
        .replace('<h1>Звук полного натяжения лука</h1>', '<h1>Звук 15 — мягкость удара</h1>')
        .replace('{{COUNT}} звуков. Громкость выровнена, тишина спереди срезана, после удара — не дольше 4 с, в конце затухание. Назовите номер, '
                 'который ставить в игру.',
                 f'{len(rows)} вариантов одного звука. От A к E удар всё мягче; у всех хвост растворяется в тишину, громкость выровнена. '
                 'Назовите букву.'))
(OUT / 'index.html').write_text(page, encoding='utf-8')
print('OK', len(rows), '->', OUT)
