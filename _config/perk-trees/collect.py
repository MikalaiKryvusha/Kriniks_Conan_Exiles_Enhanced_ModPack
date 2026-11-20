# Collects everything the owner's page shows into page_data.json:
#   attributes (label, description), perks (perks.json), the «Параметры» window labels, the stat enums of the kit probe (its ok flag checked).
# Our placeholder perks (KrinikConanUI DT_KrinikPerks) are NOT shown: switched off 2026-11-10 by the owner's word (krinik_mod_settings PLACEHOLDER_PERKS false);
# a page must show what the game has, and the judge of 2026-11-14 caught the first draft claiming them.
import json, os, sys
SCRIPTS = os.path.dirname(os.path.abspath(__file__))
HERE = os.environ.get('PERK_WORK', r'D:\work\ai_sandbox\KUMM\.work\perks')   # data: extracted assets, locres, icons, outputs
sys.path.insert(0, SCRIPTS)
from panel_texts import texts

PROBE = os.path.join(os.path.dirname(SCRIPTS), 'devkit', 'kit-probe-hero-stats.json')
WANT_ENUMS = ('ECharIntStatID', 'ECharFloatStatID')

OUT = os.path.join(HERE, 'page_data.json')
if os.path.exists(OUT):
    os.remove(OUT)                                   # a failed run must not leave the previous data for make_page.py (judge round 4)
# our placeholder perks are not drawn because they are OFF in the game — if they are switched back on, the page would hide them
SETTINGS_LUA = os.path.join(os.path.dirname(os.path.dirname(SCRIPTS)), '_unpacked', 'KrinikConanUI', 'ue4ss', 'Scripts', 'krinik_mod_settings.lua')
if 'local PLACEHOLDER_PERKS = false' not in open(SETTINGS_LUA, encoding='utf-8').read():
    sys.exit('KrinikConanUI placeholder perks are not off any more (%s) — draw them on the page first' % SETTINGS_LUA)
# a mod's copy of the attribute table that re-declares a game row would win in the game; the page reads the game's table only
EOT = os.path.join(HERE, 'eot_add.json')
if os.path.exists(EOT):
    game_rows = {r['owner'] for r in texts(os.path.join(HERE, 'add.json'))}
    clash = sorted(game_rows & {r['owner'] for r in texts(EOT)})
    if clash:
        sys.exit('Era of Trials re-declares attribute rows %s — read its texts first' % clash)
attrs = {}
for r in texts(os.path.join(HERE, 'add.json')):
    a = attrs.setdefault(r['owner'], {'stat': r['owner']})
    if r['field'].startswith('Label'):
        a['name_ru'], a['name_en'] = r['ru'] or r['en'], r['en']
    elif r['field'].startswith('Description'):
        a['desc_ru'], a['desc_en'] = r['ru'] or r['en'], r['en']

panel = [r for r in texts(os.path.join(HERE, 'sp.json')) if r['field'] == 'Text']
perks = json.load(open(os.path.join(HERE, 'perks.json'), encoding='utf-8'))
probe = json.load(open(PROBE, encoding='utf-8'))
enums = probe.get('enums', {})
bad = [n for n in WANT_ENUMS if not isinstance(enums.get(n), dict) or not enums[n].get('members')
       or n not in (probe.get('requested') or {}).get('enums', [])]   # a report of an older probe version (no `requested`) is refused too
if not probe.get('ok') or bad:
    sys.exit('kit probe unusable: ok=%s error=%s enums missing/empty=%s' % (probe.get('ok'), (probe.get('error') or '')[:300], bad))
json.dump({'attributes': attrs, 'perks': perks, 'panel': panel, 'enums': {n: enums[n] for n in WANT_ENUMS}},
          open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('attributes', len(attrs), 'perks', len(perks), 'panel labels', len(panel), 'labels in English', sum(1 for r in panel if r['ru'] is None),
      'enums', {n: len(enums[n]['members']) for n in WANT_ENUMS}, '; kit probe of', probe.get('at'), '(re-run it after a game or kit update — README step 3)')
