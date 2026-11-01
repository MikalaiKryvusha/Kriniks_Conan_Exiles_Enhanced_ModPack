# Подготовка коротких звуков к прослушке и к игре: срез тишины спереди, хвост не длиннее 4 с после удара («дзынь»),
# затухание в конце, выравнивание громкости по LUFS. Страница с кнопками — index.html рядом с готовыми файлами.
# Слово владельца 2026-10-28: «Нужно им всем нормировать громкость, отрезать тишину вначале - в конце отрезать хвосты, чтобы после
# дзынь файл длился 4 секунды максимум с фейтдом вниз громкости».
# Запуск: python -I -X utf8 sound-prep.py <папка с исходниками> <папка вывода>   [NOT-TESTED]
import hashlib, html, json, pathlib, subprocess, sys
import numpy as np

SR = 48000
SILENCE_DB = -50.0      # тише пика на 50 дБ — тишина в хвосте
LEAD_DB = -35.0         # спереди тишиной считается всё тише −35 дБ: шипение фона chime-74910 (−48 дБ) держало 0,4 с перед ударом,
                        # а шорох перед «дзынь» у tunetank (≈ −17 дБ) сохраняется
STRIKE_SHARE = 0.25     # «дзынь» — первое событие не тише −12 дБ от пика: у звонков из нескольких ударов берётся первый
                        # (chime-74910: первый удар 0,4 с на −6 дБ, громкий — на 11,7 с; с порогом 60 % вышло 15,7 с звука)
GAP_S = 0.15            # пауза тишины, после которой звук начинается заново: шорох перед ударом сохраняется, одиночный щелчок
                        # за 1,9 с до удара отрезается (ding-67618)
AFTER_STRIKE_S = 4.0    # слово владельца: после удара не больше 4 с
FADE_CUT_S = 1.5        # затухание, если хвост обрезан по 4 с
FADE_NATURAL_S = 0.4    # затухание на естественном конце (не длиннее 30 % звука)
PRE_ROLL_S = 0.005      # запас перед первым звуком, чтобы не съесть атаку
FADE_IN_S = 0.003       # без щелчка на первом отсчёте
# Громкость коротких звуков ровняется по максимуму мгновенной громкости (окно 400 мс, BS.1770): интегральная у звука в полсекунды
# тонет в затухании, и пинги с острой атакой упирались в пиковый потолок — разброс вышел 7 дБ (первый прогон 2026-10-28)
TARGET_MOMENTARY = -16.0
PEAK_CEIL = 0.891       # −1 дБ — потолок лимитера
EXTS = {'.mp3', '.wav', '.ogg', '.flac', '.m4a'}


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', str(path), '-ac', '2', '-ar', str(SR), '-f', 'f32le', '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def envelope(x, win_s=0.005):
    a = np.abs(x).max(axis=1)
    w = max(1, int(win_s * SR))
    pad = (-len(a)) % w
    blocks = np.pad(a, (0, pad)).reshape(-1, w).max(axis=1)
    return np.repeat(blocks, w)[:len(a)]


def momentary_max(path):
    # Максимум мгновенной громкости (M) по кадрам ebur128; хвост в 400 мс тишины даёт короткому звуку полное окно
    err = subprocess.run(['ffmpeg', '-v', 'info', '-nostats', '-i', str(path), '-af', 'apad=pad_dur=0.4,ebur128=framelog=info',
                          '-f', 'null', '-'], capture_output=True, text=True, encoding='utf-8', errors='replace').stderr
    vals = [float(line.split('M:')[1].split()[0]) for line in err.splitlines() if ' M:' in line and 'TARGET' in line]
    return max(vals)


def write_wav(x, path, limit=False):
    pcm = (np.clip(x, -4, 4)).astype('<f4').tobytes()
    af = ['-af', f'alimiter=limit={PEAK_CEIL}:attack=1:release=60:level=0'] if limit else []
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-', *af, '-c:a', 'pcm_s16le',
                    str(path)], input=pcm, check=True)


def strikes(x):
    # Отдельные удары в одном файле: огибающая (блоки 20 мс) взлетает на 12 дБ за 200 мс, громче −24 дБ от пика, удары не чаще
    # раза в секунду (двойной звонок велосипеда остаётся одним звуком). Слово владельца 2026-10-28: «длинные, в которых несколько
    # дзинь — порежь на отдельные» (chime-74910 и ding-67618 — по три удара)
    w = int(0.02 * SR)
    a = np.abs(x).max(axis=1)
    n = len(a) // w
    e = 20 * np.log10(a[:n * w].reshape(n, w).max(axis=1) + 1e-9)
    e -= e.max()
    hits = []
    for i in range(1, n):
        if e[i] >= -24 and e[i] - e[max(0, i - 10):i].min() >= 12 and (not hits or i - hits[-1] >= 50):
            hits.append(i)
    return [i * w for i in hits]


def process(x):
    env = envelope(x)
    peak = float(env.max())
    thr = peak * 10 ** (SILENCE_DB / 20)
    loud = np.nonzero(env > thr)[0]
    natural_end = loud[-1] + 1
    strike = int(np.nonzero(env >= peak * STRIKE_SHARE)[0][0])
    # начало — после последней паузы тишины длиной GAP_S перед ударом
    lead_thr = peak * 10 ** (LEAD_DB / 20)
    quiet = env[:strike] <= lead_thr
    gap, run, first = int(GAP_S * SR), 0, int(np.nonzero(env > lead_thr)[0][0])
    for i in range(strike - 1, -1, -1):
        run = run + 1 if quiet[i] else 0
        if run >= gap:
            first = i + run
            break
    start = max(0, first - int(PRE_ROLL_S * SR))
    cap_end = strike + int(AFTER_STRIKE_S * SR)
    cut = cap_end < natural_end
    end = min(natural_end, cap_end)
    y = x[start:end].copy()
    n = len(y)
    fade = int((FADE_CUT_S if cut else min(FADE_NATURAL_S, 0.3 * n / SR)) * SR)
    if fade > 0:
        # косинусная кривая: громкость уходит плавно, без ступеньки в конце
        y[-fade:] *= (0.5 * (1 + np.cos(np.linspace(0, np.pi, fade))))[:, None].astype(np.float32)
    fi = int(FADE_IN_S * SR)
    y[:fi] *= np.linspace(0, 1, fi, dtype=np.float32)[:, None]
    tmp = OUT / '_measure.wav'
    write_wav(y, tmp)
    m_in = momentary_max(tmp)
    gain_db = TARGET_MOMENTARY - m_in
    y *= 10 ** (gain_db / 20)
    over_db = 20 * np.log10(np.abs(y).max() / PEAK_CEIL)   # сколько дБ атаки срежет лимитер
    tmp.unlink()
    return y, dict(src_s=len(x) / SR, out_s=n / SR, cut_s=start / SR, strike_s=(strike - start) / SR, cut_tail=bool(cut),
                   m_in=m_in, gain_db=float(gain_db), limited_db=float(max(0.0, over_db)))


OUT = None   # папка вывода; её же берёт sound-soften.py, загружая этот файл модулем


def main():
    global OUT
    SRC = pathlib.Path(sys.argv[1])
    OUT = pathlib.Path(sys.argv[2])
    OUT.mkdir(parents=True, exist_ok=True)
    seen, rows = {}, []
    for f in sorted(p for p in SRC.iterdir() if p.suffix.lower() in EXTS):
        digest = hashlib.md5(f.read_bytes()).hexdigest()
        if digest in seen:
            print(f'DUP {f.name} = {seen[digest]}')
            continue
        seen[digest] = f.name
        x = decode(f)
        cuts = strikes(x)
        # кусок удара — за 50 мс до него (у первого — с начала файла) и до того же места перед следующим: атака не срезается
        pre = int(0.05 * SR)
        bounds = [0] + [c - pre for c in cuts[1:]] + [len(x)]
        for k in range(len(bounds) - 1):
            y, info = process(x[bounds[k]:bounds[k + 1]])
            title = f.stem if len(bounds) == 2 else f'{f.stem} — удар {k + 1}'
            out = OUT / f'{len(rows) + 1:02d} {title}.wav'
            write_wav(y, out, limit=True)
            info.update(src=f.name, title=title, at_s=bounds[k] / SR, out=out.name, m_out=momentary_max(out))
            rows.append(info)
            print(json.dumps(info, ensure_ascii=False))

    (OUT / 'report.json').write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding='utf-8')
    items = '\n'.join(
        f'<li><button data-src="{html.escape(r["out"])}">▶</button><span class="n">{i + 1}</span>'
        f'<span class="t">{html.escape(r["title"])}</span><span class="d">{r["out_s"]:.1f} с</span></li>'
        for i, r in enumerate(rows))
    page = (pathlib.Path(__file__).with_name('sound-prep.html').read_text(encoding='utf-8')
            .replace('{{ITEMS}}', items).replace('{{COUNT}}', str(len(rows))))
    (OUT / 'index.html').write_text(page, encoding='utf-8')
    print('OK', len(rows), 'files ->', OUT)


if __name__ == '__main__':
    main()
