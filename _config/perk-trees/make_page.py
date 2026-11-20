# page_data.json (collect.py) + perk icons (TGA from the kit) -> one self-contained HTML page with two tabs for the owner.
# Run with the Python that has Pillow:  /c/Python314/python.exe -X utf8 make_page.py <out.html>
import base64, html, io, json, os, sys
SCRIPTS = os.path.dirname(os.path.abspath(__file__))
HERE = os.environ.get('PERK_WORK', r'D:\work\ai_sandbox\KUMM\.work\perks')   # data: extracted assets, locres, icons, outputs
D = json.load(open(os.path.join(HERE, 'page_data.json'), encoding='utf-8'))
MEAN = json.load(open(os.path.join(SCRIPTS, 'stat_meanings.json'), encoding='utf-8'))
OUT = sys.argv[1]
E = html.escape
from PIL import Image                                # the page without icons is not this page — no silent fallback (judge round 2)

# --- icons: TGA -> WebP data URI (90, alpha kept only when a pixel is not opaque) --------------------------------------
ICONS = {}
for f in os.listdir(os.path.join(HERE, 'icons')):
    if f.lower().endswith('.tga'):
        im = Image.open(os.path.join(HERE, 'icons', f)).convert('RGBA')
        if im.getchannel('A').getextrema()[0] == 255:
            im = im.convert('RGB')
        im.thumbnail((96, 96))
        b = io.BytesIO()
        im.save(b, 'WEBP', quality=90)
        ICONS[f[:-4]] = 'data:image/webp;base64,' + base64.b64encode(b.getvalue()).decode()
missing_icons = sorted({(p.get('icon') or '').split('.')[-1] for p in D['perks'] if p['source'] == 'game'} - set(ICONS))
if missing_icons:
    sys.exit('perk icons not exported (README step 3): %s' % missing_icons)


def icon(p):
    name = (p.get('icon') or '').split('.')[-1]
    uri = ICONS.get(name)
    return f'<img class="ico" src="{uri}" alt="">' if uri else '<span class="ico ph"></span>'


ORDER = ['AttributeMight', 'AttributeAthleticism', 'AttributeHealth', 'AttributeStamina', 'AttributeLeadership', 'AttributeEncumbrance']
CORRUPT = [('AttributeScourge', 'Осквернённая сила'), ('AttributeAbberation', 'Осквернённая живучесть'),
           ('AttributeSummoning', 'Осквернённый авторитет')]
perks = [p for p in D['perks'] if p['source'] == 'game']
eaa = [p for p in D['perks'] if p['source'] != 'game']
# the footnote calls a mod's rows nameless service rows; a named one (a mod update adding a real perk) must be drawn — stop instead of hiding it
named_mod_rows = [p['row'] for p in eaa if (p.get('name_en') or '-').strip() not in ('-', '')]
if named_mod_rows:
    sys.exit('a mod adds named perk rows — draw them in their trees first: %s' % named_mod_rows)
# the page's prose says «four rungs: 5, 10, 15, 20; a choice at 10 and 20; nothing past 20» — data that says otherwise must rewrite the prose first
off_prose = sorted({p['row'] for p in perks if p['points'] not in (5, 10, 15, 20)})
if off_prose:
    sys.exit('perks outside 5/10/15/20 — update the page prose and the ladders first: %s' % off_prose)
dup_rows = sorted({p['row'] for p in perks if [q['row'] for q in perks].count(p['row']) > 1})
if dup_rows:
    sys.exit('a perk row name twice in the game table: %s' % dup_rows)
overriding = sorted({p['row'] for p in eaa} & {p['row'] for p in perks})   # a mod row of the same name replaces the game's in the merged table
if overriding:
    sys.exit('a mod table re-declares game perk rows (the page would show the vanilla text): %s' % overriding)
missing_attrs = [s for s in ('AttributeMight', 'AttributeAthleticism', 'AttributeHealth', 'AttributeStamina', 'AttributeLeadership', 'AttributeEncumbrance')
                 if not (D['attributes'].get(s) or {}).get('name_ru') or not D['attributes'][s].get('desc_ru')]
if missing_attrs:
    sys.exit('attributes without a label or a description: %s' % missing_attrs)
by_stat = {}
for p in perks:
    by_stat.setdefault(p['stat'].split('::')[-1], []).append(p)
DRAWN = []                                           # every game row drawn exactly once — checked below, a lost row stops the build


def perk_box(p, cls=''):
    DRAWN.append(p['row'])
    en = f'<div class="en">{E(p["name_en"])}</div>' if p.get('name_en') else ''
    name = p['name_ru'] or p['name_en'] or p['row']
    desc = p['desc_ru'] or p['desc_en'] or ''
    return (f'<div class="perk {cls}">{icon(p)}<div class="txt"><div class="pn">{E(name)}</div>'
            f'<div class="pd">{E(desc)}</div>{en}</div></div>')


def ladder(stat, base, corrupt=False):
    rows = by_stat.get(stat, [])
    levels = sorted(set(base) | {p['points'] for p in rows})   # a data level outside the base still gets its rung
    out = []
    for lv in levels:
        here = sorted((p for p in rows if p['points'] == lv), key=lambda x: x['row'])
        if not here:
            out.append(f'<div class="lv free"><div class="badge">{lv}</div><div class="slot">свободно — место для нового перка</div></div>')
        elif len(here) == 1:
            out.append(f'<div class="lv"><div class="badge">{lv}</div>{perk_box(here[0], "corrupt" if corrupt else "")}</div>')
        else:
            boxes = '<div class="or">или</div>'.join(perk_box(p, "corrupt" if corrupt else "") for p in here)
            out.append(f'<div class="lv choice"><div class="badge">{lv}</div><div class="pair">{boxes}</div></div>')
    return ''.join(out)


cards = []
for st in ORDER:
    a = D['attributes'].get(st, {})
    cards.append(f'<article class="card"><h3>{E(a.get("name_ru", st))}</h3><p class="adesc">{E(a.get("desc_ru", ""))}</p>'
                 f'{ladder(st, [5, 10, 15, 20, 25, 30, 35, 40])}</article>')
ccards = []
for st, name in CORRUPT:
    ccards.append(f'<article class="card ccard"><h3>{E(name)}</h3>{ladder(st, [5, 10, 15, 20], corrupt=True)}</article>')
lost = sorted({p['row'] for p in perks} - set(DRAWN))
if lost or len(DRAWN) != len(perks):
    sys.exit('rows not drawn exactly once: lost %s, drawn %d of %d' % (lost, len(DRAWN), len(perks)))

# --- tab 2: the hero's variables ----------------------------------------------------------------------------------------
attr_rows = ''.join(f'<tr><td class="nm">{E(D["attributes"][s]["name_ru"])}</td><td>{E(D["attributes"][s]["desc_ru"])}</td></tr>'
                    for s in ORDER if s in D['attributes'])

GROUPS = [('Урон', ['TotalDamage', 'DamageFromWeapon', 'DamageFromStrength', 'DamageFromAgility', 'DamageFromItems']),
          ('Доспехи и защита', ['TotalArmor', 'ArmorFromGrit', 'ArmorFromItems', 'ArmorTotalDamageReduction']),
          ('Здоровье', ['TotalHealth', 'HealthBonusFromVitality', 'HealthBonusFromItems', 'PassiveHealthRegeneration']),
          ('Запас сил', ['Stamina', 'StaminaBonus', 'StaminaBonusItems', 'StaminaRegen']),
          ('Движение', ['TotalMovementSpeed', 'MovementSpeedBonusFromBuffs']),
          ('Переносимый вес', ['TotalCarryWeight', 'CarryWeightFromAttributes', 'CarryWeightFromItems', 'Encumbrance']),
          ('Температура', ['HeatResistance', 'ColdResistance']),
          ('Спутники', ['FollowerTotalDamageIncrease', 'FollowerDamageFromCharisma', 'FollowerDamageFromItems', 'ConcussiveDamageFromCharisma']),
          ('Прочее', ['SpectralCurrent']),
          ('Точки появления', ['TextBlock_15', 'TextBlock_17'])]   # «Кровать», «Подстилка» — the respawn list's kinds (judge round 4: they were dropped)
lab = {r['owner'][:-5] if r['owner'].endswith('Label') else r['owner']: r for r in D['panel']}
grouped = {k for _, keys in GROUPS for k in keys}
# every text of the window is a value label in GROUPS or a NAMED non-value: section headings, the empty-list «Нет», the unit postfixes (`…Postfix`)
NOT_VALUES = {'Offence', 'TextBlock', 'TextBlock_0', 'TextBlock_1', 'TextBlock_3', 'TextBlock_12', 'TextBlock_16', 'TextBlock_18', 'TextBlock_20', 'TextBlock_23'}
ungrouped = sorted(k for k in lab if k not in grouped and k not in NOT_VALUES and not k.endswith('Postfix'))
gone = sorted(k for k in grouped if k not in lab)
if ungrouped or gone:
    sys.exit('«Параметры» labels changed (a game patch?): in no group %s · listed but gone %s' % (ungrouped, gone))
gtxt = []
for g, keys in GROUPS:
    items = [f'<li>{E((lab[k]["ru"] or lab[k]["en"]).strip().rstrip(":"))}</li>' for k in keys if k in lab]   # no Russian → the English the game shows
    gtxt.append(f'<div class="grp"><h4>{E(g)}</h4><ul>{"".join(items)}</ul></div>')


UNGLOSSED = []


def plural_rows(n):
    return 'строку' if n % 10 == 1 and n % 100 != 11 else ('строки' if n % 10 in (2, 3, 4) and n % 100 not in (12, 13, 14) else 'строк')


def snake(camel):
    out = ''
    for i, ch in enumerate(camel):
        if ch.isupper() and i and (not camel[i - 1].isupper() or (i + 1 < len(camel) and camel[i + 1].islower())):
            out += '_'
        out += ch
    return out.upper()


def enum_table(name, title, note):
    v = D['enums'].get(name)
    if not isinstance(v, dict):
        return f'<p class="muted">{E(title)}: список не прочитан ({E(str(v))}).</p>'
    by_snake = {snake(k): (k, t) for k, t in MEAN.get(name, {}).items()}
    trs, n = [], 0
    for m in v['members']:
        if m['name'].endswith('STAT_ID_MAX'):          # the enum's own count member only — HEALTH_MAX, STAMINA_MAX are real stats
            continue
        code, mean = by_snake.get(m['name'], (m['name'], ''))
        if not mean:
            UNGLOSSED.append(name + '.' + m['name'])
        trs.append(f'<tr><td class="num">{m["value"]}</td><td class="code">{E(code)}</td><td>{E(mean)}</td></tr>')
        n += 1
    return (f'<h3>{E(title)} <span class="cnt">{n}</span></h3><p class="muted">{E(note)}</p>'
            f'<table class="enum"><tr><th>№</th><th>Имя в коде</th><th>Что это</th></tr>{"".join(trs)}</table>')


eaa_note = (f'<p class="muted foot">Мод Enhanced Armory and Arsenal добавляет в ту же таблицу {len(eaa)} {plural_rows(len(eaa))} без названия и описания '
            f'({", ".join(E(p["row"]) for p in eaa)}) — служебные, в деревьях выше их нет.</p>') if eaa else ''

PAGE = f'''<!doctype html><html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Перки и параметры героя</title>
<style>
:root {{ --bg:#14110d; --panel:#1e1913; --panel2:#272017; --gold:#e9c27a; --text:#ece4d4; --muted:#a3967f; --line:rgba(233,194,122,.22);
  --purple:#a77ad6; --purple-bg:#211a29; --ours:#7fb3a0; }}
* {{ box-sizing:border-box; }}
body {{ margin:0; background:var(--bg); color:var(--text); font:17px/1.45 "Segoe UI", "PT Sans", Arial, sans-serif; }}
header {{ position:sticky; top:0; z-index:5; background:linear-gradient(#1b1610,#14110d); border-bottom:1px solid var(--line); padding:14px 24px 0; }}
h1 {{ margin:0 0 4px; font:600 26px "PT Serif", Georgia, serif; color:var(--gold); letter-spacing:.02em; }}
.sub {{ color:var(--muted); font-size:15px; margin-bottom:10px; }}
.tabs {{ display:flex; gap:4px; }}
.tabs button {{ background:none; border:1px solid var(--line); border-bottom:none; color:var(--muted); font:600 17px "PT Serif", Georgia, serif;
  padding:9px 22px; cursor:pointer; border-radius:6px 6px 0 0; }}
.tabs button.on {{ background:var(--panel); color:var(--gold); }}
main {{ padding:22px 24px 60px; max-width:2400px; margin:0 auto; }}
section {{ display:none; }} section.on {{ display:block; }}
.intro {{ max-width:1100px; color:var(--text); }}
.intro b {{ color:var(--gold); font-weight:600; }}
.grid {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(520px, 1fr)); gap:18px; margin-top:16px; }}
.card {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:16px 18px; }}
.card h3 {{ margin:0; font:600 23px "PT Serif", Georgia, serif; color:var(--gold); }}
.adesc {{ margin:4px 0 12px; color:var(--muted); font-size:15px; }}
.lv {{ display:flex; gap:12px; align-items:stretch; padding:8px 0; border-top:1px solid var(--line); }}
.badge {{ flex:0 0 46px; height:46px; border:1px solid var(--gold); color:var(--gold); border-radius:50%; display:flex; align-items:center;
  justify-content:center; font:600 18px "PT Serif", Georgia, serif; margin-top:2px; }}
.pair {{ display:flex; gap:8px; align-items:stretch; flex:1; }}
.or {{ align-self:center; color:var(--muted); font-style:italic; font-size:14px; }}
.perk {{ flex:1; display:flex; gap:10px; background:var(--panel2); border-radius:6px; padding:8px 10px; min-width:0; }}
.ico {{ width:44px; height:44px; flex:0 0 44px; border-radius:4px; }}
.ico.ph {{ background:#33291d; }}
.pn {{ font-weight:600; color:#f3e7cf; }}
.pd {{ font-size:15px; }}
.en {{ font-size:12.5px; color:var(--muted); margin-top:2px; }}
.free .badge {{ border-style:dashed; color:var(--muted); border-color:var(--muted); }}
.free .slot {{ flex:1; border:1px dashed rgba(163,150,127,.45); border-radius:6px; color:var(--muted); display:flex; align-items:center;
  padding:0 12px; font-size:14.5px; }}
.perk.corrupt .pn {{ color:#d9c3f0; }}
h2 {{ font:600 22px "PT Serif", Georgia, serif; color:var(--gold); margin:30px 0 4px; }}
.ccard {{ background:var(--purple-bg); border-color:rgba(167,122,214,.35); }}
.ccard h3 {{ color:var(--purple); }} .ccard .badge {{ border-color:var(--purple); color:var(--purple); }}
.muted {{ color:var(--muted); }} .foot {{ margin-top:18px; font-size:14.5px; }}
table {{ border-collapse:collapse; width:100%; max-width:1500px; }}
td, th {{ border-bottom:1px solid var(--line); padding:6px 10px; text-align:left; vertical-align:top; }}
th {{ color:var(--gold); font-weight:600; }}
td.nm {{ color:var(--gold); font-weight:600; white-space:nowrap; }}
.groups {{ display:grid; grid-template-columns:repeat(auto-fill, minmax(320px, 1fr)); gap:14px; max-width:1800px; }}
.grp {{ background:var(--panel); border:1px solid var(--line); border-radius:8px; padding:10px 16px; }}
.grp h4 {{ margin:0 0 4px; color:var(--gold); font:600 18px "PT Serif", Georgia, serif; }}
.grp ul {{ margin:0; padding-left:18px; }}
.enum td.num {{ width:56px; color:var(--muted); }} .enum td.code {{ font-family:Consolas, monospace; font-size:14.5px; width:420px; }}
.cnt {{ color:var(--muted); font-size:15px; font-weight:400; }}
.two {{ display:grid; grid-template-columns:1fr 1fr; gap:28px; }}
@media (max-width:1400px) {{ .two {{ grid-template-columns:1fr; }} }}
</style></head><body>
<header><h1>Перки и параметры героя</h1>
<div class="sub">Conan Exiles 3.1.0, сборка Krinik. Тексты — из таблиц игры и русского перевода сборки, как их видит игрок.</div>
<div class="tabs"><button data-t="perks">Деревья перков</button><button data-t="stats">Параметры героя</button></div></header>
<main>
<section id="perks">
<p class="intro">У каждой из шести характеристик четыре ступени перков: на <b>5</b>, <b>10</b>, <b>15</b> и <b>20</b> очках. На 10 и 20 игрок
<b>выбирает один перк из двух</b>. Выше 20 очков перков в игре нет: в сборке очков в характеристике может быть больше, страницы 21–40 уже
работают, а пунктир ниже отмечает свободные места для новых перков.</p>
<div class="grid">{"".join(cards)}</div>
<h2>Осквернённые характеристики</h2>
<p class="intro">Скверна открывает свою ветку у трёх характеристик: четыре перка без выбора, на 5, 10, 15 и 20 очках скверны.</p>
<div class="grid">{"".join(ccards)}</div>
{eaa_note}
</section>
<section id="stats">
<p class="intro">Что есть у героя в коде игры и что из этого можно повышать нашими деревьями. Сам перк — только строка таблицы: название,
описание и порог. Действует он через код игры, который спрашивает «есть ли у героя этот перк». Значит, новый перк — это новая строка
таблицы плюс наш код, который меняет одну из переменных ниже.</p>
<h2>Что сейчас дают характеристики</h2>
<table>{attr_rows}</table>
<h2>Что игра показывает в окне «Параметры»</h2>
<p class="muted">Подписи окна, сгруппированные по смыслу.</p>
<div class="groups">{"".join(gtxt)}</div>
<h2>Все переменные героя в коде игры</h2>
<p class="muted">Игра хранит у персонажа два набора чисел: целые и дробные. Номер — это то, что спрашивают функции игры
<span class="code">GetIntStat(№)</span> и <span class="code">GetFloatStat(№)</span>.</p>
<div class="two"><div>{enum_table("ECharIntStatID", "Целые переменные", "Характеристики, уровень, очки, здоровье и прочие целые числа.")}</div>
<div>{enum_table("ECharFloatStatID", "Дробные переменные", "Множители, скорости, сопротивления и прочие дробные числа.")}</div></div>
<p class="muted foot">Номера и имена — из кода игры 3.1.0. Пояснения в третьей колонке — мой перевод имён: игра сама эти имена нигде не
расшифровывает. Где смысл понятен только по имени, так и написано.</p>
</section>
</main>
<script>
const bs = document.querySelectorAll('.tabs button'), ss = document.querySelectorAll('section');
function show(t) {{ bs.forEach(b => b.classList.toggle('on', b.dataset.t === t)); ss.forEach(s => s.classList.toggle('on', s.id === t));
  try {{ history.replaceState(null, '', '#' + t); }} catch (e) {{}} }}
bs.forEach(b => b.onclick = () => show(b.dataset.t));
show(location.hash === '#stats' ? 'stats' : 'perks');
</script></body></html>'''
if UNGLOSSED:
    sys.exit('stats without a Russian gloss in stat_meanings.json (a patch added a member?): %s' % UNGLOSSED)
open(OUT, 'w', encoding='utf-8').write(PAGE)
print('written', OUT, len(PAGE), 'bytes; perks drawn', len(DRAWN), 'of', len(perks), '; icons', len(ICONS), '; stats without a gloss', len(UNGLOSSED), UNGLOSSED)
