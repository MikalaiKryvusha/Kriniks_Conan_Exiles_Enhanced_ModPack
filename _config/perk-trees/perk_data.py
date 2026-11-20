# Perk rows of the game's PerksTable and EAA's table -> perks.json; texts in Russian as the player sees them (panel_texts.ru: key + source hash).
import json, os, sys
SCRIPTS = os.path.dirname(os.path.abspath(__file__))
HERE = os.environ.get('PERK_WORK', r'D:\work\ai_sandbox\KUMM\.work\perks')   # data: extracted assets, locres, icons, outputs
sys.path.insert(0, SCRIPTS)
from panel_texts import ru


def imp_path(j, idx):
    if not isinstance(idx, int) or idx >= 0:
        return None
    im = j['Imports'][-idx - 1]
    outer = im.get('OuterIndex')
    pkg = j['Imports'][-outer - 1]['ObjectName'] if isinstance(outer, int) and outer < 0 else ''
    return pkg + '.' + im['ObjectName']


def rows(path, source):
    j = json.load(open(path, encoding='utf-8'))
    out = []
    for e in j['Exports']:
        if 'DataTable' not in e.get('$type', ''):
            continue
        for r in e['Table']['Data']:
            f = {p['Name']: p for p in r['Value']}
            name, desc = f.get('PerkName'), f.get('PerkDescription')
            out.append({
                'row': r['Name'], 'source': source,
                'name_en': name.get('CultureInvariantString') if name else None, 'name_ru': ru(name),
                'desc_en': desc.get('CultureInvariantString') if desc else None, 'desc_ru': ru(desc),
                'stat': (f.get('TargetIntStat') or {}).get('Value'), 'points': (f.get('AttributePointsRequired') or {}).get('Value'),
                'icon': imp_path(j, (f.get('Icon') or {}).get('Value')),
            })
    return out


data = rows(os.path.join(HERE, 'vanilla.json'), 'game') + rows(os.path.join(HERE, 'eaa.json'), 'EnhancedArmoryAndArsenal')
json.dump(data, open(os.path.join(HERE, 'perks.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
game = [d for d in data if d['source'] == 'game']
miss = [d['row'] for d in game if not d['name_ru'] or not d['desc_ru']]
print('rows', len(data), '(game %d)' % len(game), '; game rows the player sees in English:', len(miss), miss)
