# water-scenes-report.py <bench dir> <out dir> [label prefix] — the summary of water-scenes.sh: per scene and setting avg / median FPS, CPU (MsCPUBusy) and GPU
# (MsGPUBusy) ms from the one-minute PresentMon CSVs «*_ws-NN-<scene>-<setting>.csv»; the mean over scenes per setting and its difference from «off»;
# one FPS-per-second chart per scene (a line per setting) and a table (TSV + markdown) — for the owner's review folder.
# Why (KUMM 2026-11-09, `[OWNER]` 00:07 «минуту стой - пиши FPS график» · «Померяем в среднем на статичных сценах в выборке по 5 сценам по минутному бенчу»).
# Run with C:/Python314 (matplotlib there). [NOT-TESTED]
import csv, glob, os, re, statistics, sys
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

bench, out = sys.argv[1], sys.argv[2]
prefix = sys.argv[3] if len(sys.argv) > 3 else 'ws-'
os.makedirs(out, exist_ok=True)
NAMES = {'off': 'без отражения', '6': 'лучи', 'sw': 'программные с дальностью'}
rows, series = [], {}
for f in sorted(glob.glob(os.path.join(bench, '*_' + prefix + '*.csv'))):
    m = re.search(prefix + r'(\d\d)-(.+)-([^-]+)\.csv$', os.path.basename(f))
    if not m:
        continue
    nn, scene, setting = m.groups()
    t, ft, cpu, gpu = [], [], [], []
    with open(f, encoding='utf-8-sig') as fh:
        for r in csv.DictReader(fh):
            try:
                t.append(float(r['TimeInMs']) / 1000.0); ft.append(float(r['MsBetweenPresents']))
                cpu.append(float(r['MsCPUBusy'])); gpu.append(float(r['MsGPUBusy']))
            except (ValueError, KeyError, TypeError):   # a row cut off by a killed PresentMon reads None (2026-11-09 01:0x)
                pass
    if not ft:
        continue
    t0 = t[0]
    per_s = {}
    for ti, fi in zip(t, ft):
        per_s.setdefault(int(ti - t0), []).append(fi)
    fps_s = [(s, len(v) / (sum(v) / 1000.0)) for s, v in sorted(per_s.items()) if sum(v) > 0]
    avg = len(ft) / (sum(ft) / 1000.0)
    med = 1000.0 / statistics.median(ft)
    rows.append((nn, scene, setting, avg, med, statistics.mean(cpu), statistics.mean(gpu)))
    series.setdefault((nn, scene), {})[setting] = fps_s

with open(os.path.join(out, 'fps_table.tsv'), 'w', encoding='utf-8') as fh:
    fh.write('scene\tsetting\tavg_fps\tmedian_fps\tcpu_ms\tgpu_ms\n')
    for nn, sc, st, a, md, c, g in rows:
        fh.write(f'{nn}_{sc}\t{st}\t{a:.1f}\t{md:.1f}\t{c:.2f}\t{g:.2f}\n')
means = {}
for st in ('off', '6', 'sw'):
    v = [r for r in rows if r[2] == st]
    if v:
        means[st] = tuple(statistics.mean(x[i] for x in v) for i in (3, 4, 5, 6)) + (len(v),)
lines = ['| Место | Настройка | Кадров в среднем | Медиана | Процессор, мс | Видеокарта, мс |', '|---|---|---|---|---|---|']
for nn, sc, st, a, md, c, g in rows:
    lines.append(f'| {nn} {sc} | {NAMES.get(st, st)} | {a:.1f} | {md:.1f} | {c:.2f} | {g:.2f} |')
lines += ['', '| Настройка | Мест | Кадров в среднем | Медиана | Процессор, мс | Видеокарта, мс | К «без отражения» |', '|---|---|---|---|---|---|---|']
for st, (a, md, c, g, n) in means.items():
    rel = '' if st == 'off' or 'off' not in means else f'{(a / means["off"][0] - 1) * 100:+.1f} % кадров, {c - means["off"][2]:+.2f} мс процессора'
    lines.append(f'| {NAMES.get(st, st)} | {n} | {a:.1f} | {md:.1f} | {c:.2f} | {g:.2f} | {rel} |')
open(os.path.join(out, 'fps_table.md'), 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('\n'.join(lines))

for (nn, sc), by in sorted(series.items()):
    fig, ax = plt.subplots(figsize=(12, 4.5), dpi=120)
    for st, pts in by.items():
        ax.plot([p[0] for p in pts], [p[1] for p in pts], label=NAMES.get(st, st), linewidth=1.6)
    ax.set_title(f'{nn} {sc}: кадров в секунду, минута стоя'); ax.set_xlabel('секунда'); ax.set_ylabel('кадров/с')
    ax.grid(alpha=0.3); ax.legend()
    fig.tight_layout(); p = os.path.join(out, f'{nn}_{sc}_fps.png'); fig.savefig(p); plt.close(fig)
    from PIL import Image
    Image.open(p).convert('RGB').save(p[:-4] + '.webp', 'WEBP', quality=90); os.remove(p)
print('charts:', len(series))
