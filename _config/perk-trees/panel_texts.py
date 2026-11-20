# Texts of cooked assets (uaj tojson, UE 5.8) with their Russian as the player sees it in the build.
# A text is localized only when its locres entry carries the hash of the SAME English source (UE shows the source otherwise — a stale translation).
# Order: the build's loose Game.locres (mods' texts and our vanilla overrides) first, then the game's own targets extracted from pakchunk0 (README step 2).
#   python -I -X utf8 panel_texts.py <asset.json>   → TSV for a look; collect.py imports texts() instead.
import json, os, sys
SCRIPTS = os.path.dirname(os.path.abspath(__file__))
HERE = os.environ.get('PERK_WORK', r'D:\work\ai_sandbox\KUMM\.work\perks')   # data: extracted assets, locres, icons, outputs
sys.path.insert(0, os.path.join(os.path.dirname(SCRIPTS), 'devkit'))
sys.path.insert(0, os.path.dirname(SCRIPTS))
import locres
from game_target import sandbox

LOCRES = [sandbox('Content', 'Localization', 'Game', 'ru', 'Game.locres')] + [os.path.join(HERE, 'ru_%s.locres' % t) for t in ('Exiles_UI', 'Exiles_Code', 'Exiles_Items')]
_by_key = None


def _load():
    global _by_key
    if _by_key is None:
        _by_key = {}
        for path in LOCRES:
            for e in locres.read(path)[1]:
                _by_key.setdefault((e.ns, e.key), e)
    return _by_key


def ru(t):
    """Russian of one TextPropertyData as the game shows it; None when the game would show the English source."""
    if t is None:
        return None
    src = t.get('CultureInvariantString')
    e = _load().get((t.get('Namespace') or '', t.get('Value') or ''))
    if e is None or not src or e.src_hash != locres.str_crc32(src):
        return None
    return e.tr


def _walk(v, out, owner):
    if isinstance(v, dict):
        if v.get('$type', '').startswith('UAssetAPI.PropertyTypes.Objects.TextPropertyData') and v.get('CultureInvariantString'):
            out.append({'owner': owner, 'field': v.get('Name'), 'en': v['CultureInvariantString'], 'ru': ru(v)})
        for x in v.values():
            _walk(x, out, owner)
    elif isinstance(v, list):
        for x in v:
            _walk(x, out, owner)


def texts(json_path):
    """Every TextProperty of every export (and of every DataTable row, owner = the row name)."""
    j = json.load(open(json_path, encoding='utf-8'))
    out = []
    for e in j['Exports']:
        _walk(e.get('Data'), out, e.get('ObjectName'))
        if 'DataTable' in e.get('$type', ''):
            for r in e['Table']['Data']:
                _walk(r, out, r['Name'])
    return out


if __name__ == '__main__':
    for r in texts(sys.argv[1]):
        print('%s\t%s\t%s\t%s' % (r['owner'], r['field'], r['en'], r['ru'] if r['ru'] is not None else '<EN>'))
