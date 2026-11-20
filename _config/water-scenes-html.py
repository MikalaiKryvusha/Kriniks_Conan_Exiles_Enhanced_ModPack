import os, csv, html
D = r"D:\work\ai_sandbox\ConanExiles\_library\НА ОТСМОТР НИКОЛАЕМ\76_voda_5_plyazhey_otrazheniya"
NAMES = {'delta_falls': 'Дельта: скалы с водопадами', 'delta_jungle': 'Дельта в джунглях', 'desert_arch': 'Пустыня: каменная арка',
         'oasis_falls': 'Оазис: водопад и храм', 'river_bend': 'Излучина: красные скалы'}
MODES = [('off', 'Без отражения'), ('6', 'Лучи'), ('sw', 'Программные с дальностью')]
stats = {}
for r in csv.DictReader(open(os.path.join(D, 'fps_table.tsv'), encoding='utf-8'), delimiter='\t'):
    sc = r['scene'].split('_', 1)[1]
    stats[(sc, r['setting'])] = r
rows = []
for sub in sorted(os.listdir(D)):
    p = os.path.join(D, sub)
    if not os.path.isdir(p):
        continue
    n, sc = sub.split('_', 1)
    cells = []
    for m, label in MODES:
        img = f'{sub}/{n}_{sc}_{m}_4k.webp'
        s = stats.get((sc, m))
        num = f"{float(s['avg_fps']):.1f} к/с · медиана {float(s['median_fps']):.1f} · процессор {float(s['cpu_ms']):.1f} мс" if s else '—'
        cells.append(f'<td><a href="{html.escape(img)}" target="_blank"><img src="{html.escape(img)}" loading="lazy"></a><div class="n">{num}</div></td>')
    chart = [f for f in os.listdir(p) if f.endswith('_fps.webp')]
    ch = f'<tr><td colspan="3" class="chart"><img src="{html.escape(sub + "/" + chart[0])}"></td></tr>' if chart else ''
    rows.append(f'<tr><th colspan="3">{n}. {html.escape(NAMES.get(sc, sc))}</th></tr><tr>{"".join(cells)}</tr>{ch}')
table_md = open(os.path.join(D, 'fps_table.md'), encoding='utf-8').read().split('\n\n')[-1].strip().splitlines()
summ = ''.join('<tr>' + ''.join(f'<td>{html.escape(c.strip())}</td>' for c in l.strip('|').split('|')) + '</tr>' for l in table_md if not l.startswith('|---'))
page = f'''<!doctype html><html lang="ru"><head><meta charset="utf-8"><title>Вода: три режима отражений</title>
<style>
body{{background:#15171a;color:#e8e4dc;font:16px/1.4 "Segoe UI",sans-serif;margin:16px}}
h1{{font-weight:500;font-size:24px}} table.g{{width:100%;border-collapse:collapse;table-layout:fixed}}
.g th{{text-align:left;font-weight:500;font-size:19px;padding:22px 4px 8px}} .g td{{padding:4px;vertical-align:top}}
.g img{{width:100%;display:block;border-radius:4px}} .n{{font-size:14px;color:#c9c2b4;padding:4px 2px}}
.head td{{font-size:18px;color:#f0d9a8;padding:6px 4px}} .chart img{{max-width:900px;margin:4px auto}}
table.s{{border-collapse:collapse;margin:8px 0 18px}} .s td{{border:1px solid #3a3d42;padding:6px 10px}} p{{max-width:1100px}}
</style></head><body>
<h1>Вода на пяти пляжах реки: без отражения · лучи · программные отражения с дальностью</h1>
<p>11:00, дождь выключен, мобы заморожены, 30 секунд тишины перед каждым кадром и минутой замера. Клик по кадру — 4K в новой вкладке.
На первом месте лучи и программные дали сотни рывков сразу после включения лучей — его замер стоит переснять.</p>
<table class="s">{summ}</table>
<table class="g"><tr class="head"><td>Без отражения</td><td>Лучи</td><td>Программные с дальностью</td></tr>{"".join(rows)}</table>
</body></html>'''
open(os.path.join(D, 'voda_tri_rezhima.html'), 'w', encoding='utf-8').write(page)
print('ok')
