# Варианты громкости и тембра одного уже выбранного звука — страница для выбора на слух (рядом sound-prep.html — тот же вид).
# Слово владельца 2026-10-28 18:5x: «и звук натяжения нужно сделать тише, и меньше высоких звенящих - давй варианты отслушать».
# Громкость НЕ выравнивается: «тише» — это и есть вопрос, поэтому каждый вариант — тот же звук минус N дБ после фильтра верхов.
# Запуск: python -I -X utf8 sound-variants.py <исходник.wav> <папка вывода>   [NOT-TESTED]
import html, pathlib, subprocess, sys

SRC, OUT = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
VARIANTS = [   # подпись, фильтр ffmpeg верхов (или ''), насколько тише, дБ
    ('как сейчас — для сравнения', '', 0),
    ('тише на 4 дБ, звон чуть мягче (верхи −4 дБ)', 'highshelf=f=4000:g=-4', 4),
    ('тише на 6 дБ, звон мягче (верхи −8 дБ)', 'highshelf=f=4000:g=-8', 6),
    ('тише на 6 дБ, звон срезан выше 5 кГц', 'lowpass=f=5000:poles=2', 6),
    ('тише на 8 дБ, звон срезан выше 3,5 кГц', 'lowpass=f=3500:poles=2', 8),
    ('тише на 10 дБ, звон срезан выше 3,5 кГц', 'lowpass=f=3500:poles=2', 10),
    # «можешь подаловаться, наложить разрые эффекты» (владелец 18:5x) — эффекты; у эха и отзвука хвост дорастает в добавленной тишине и гаснет
    ('ниже на полтона, звон мягче', 'asetrate=48000*0.944,aresample=48000,highshelf=f=4000:g=-6', 6),
    ('ниже на тон — теплее, глуше', 'asetrate=48000*0.891,aresample=48000,lowpass=f=4500:poles=2', 6),
    ('мягкий отзвук, как в зале', 'lowpass=f=5000:poles=2,apad=pad_dur=1.2,aecho=0.8:0.6:40|90|150:0.30|0.20|0.12,afade=t=out:st=2.0:d=1.1', 7),
    ('эхо пещеры', 'lowpass=f=4500:poles=2,apad=pad_dur=1.5,aecho=0.8:0.7:180|360:0.35|0.18,afade=t=out:st=2.3:d=1.1', 8),
    ('хорус — звон «шире», мерцает', 'highshelf=f=4000:g=-6,chorus=0.6:0.9:50|60:0.4|0.32:0.25|0.4:2|2.3', 7),
    ('фазер — звон «плывёт»', 'highshelf=f=4000:g=-6,aphaser=in_gain=0.6:out_gain=0.8:delay=3:decay=0.5:speed=0.6', 6),
    ('лёгкое вибрато — «живой» колокольчик', 'lowpass=f=5000:poles=2,vibrato=f=5:d=0.15', 6),
    ('далёкий колокол — глухо и с отзвуком', 'asetrate=48000*0.891,aresample=48000,lowpass=f=3000:poles=2,apad=pad_dur=1.2,aecho=0.8:0.5:60|130:0.30|0.15,afade=t=out:st=2.1:d=1.1', 6),
    ('тихий «тинь» — коротко, без хвоста', 'lowpass=f=4500:poles=2,afade=t=out:st=0.25:d=0.5', 6),
]
rows = []
for i, (title, flt, quieter) in enumerate(VARIANTS, 1):
    af = ','.join(x for x in (flt, f'volume={-quieter}dB') if x)
    out = OUT / f'{i:02d}.wav'
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(SRC), '-af', af, '-c:a', 'pcm_s16le', str(out)], check=True)
    rows.append((title, out.name))
    print(i, title, af)
items = '\n'.join(f'<li><button data-src="{html.escape(o)}">▶</button><span class="n">{i}</span><span class="t">{html.escape(t)}</span>'
                  f'<span class="d"></span></li>' for i, (t, o) in enumerate(rows, 1))
page = (pathlib.Path(__file__).with_name('sound-prep.html').read_text(encoding='utf-8')
        .replace('{{ITEMS}}', items).replace('{{COUNT}}', str(len(rows)))
        .replace('<h1>Звук полного натяжения лука</h1>', '<h1>Звук натяжения — тише и мягче</h1>')
        .replace(f'{len(rows)} звуков. Громкость выровнена, тишина спереди срезана, после удара — не дольше 4 с, в конце затухание. '
                 'Назовите номер, который ставить в игру.',
                 'Тот же звук C. Первый — как сейчас в игре, дальше всё тише и всё меньше звона. Назовите номер.'))
(OUT / 'index.html').write_text(page, encoding='utf-8')
print('OK', len(rows), '->', OUT)
