"""D-127 (pista D): LPC pieces for the new items, added to the imported set without re-running the whole importer.

    python tools/lpc_extras_items.py [path/to/_vendor/lpc]

Same rules as tools/import_lpc.py (adult male/female bodies, the game's animations, licence filter, palette
recolour or a named variant). Pieces:
- weapon_bow_recurve (medium wood), weapon_bow_great (dark wood, the longbow), weapon_crossbow: the bows D-082
  reserved for items.
- shield_kite (gray), shield_spartan (bronze): drop/craft shields next to the round wooden one.
- backpack_satchel (square pack, walnut) and backpack_pack (backpack, leather): the tanner's bags.
- pants_dyed (navy, walnut): cloth trousers (tailor) and leather trousers (tanner).
Updates assets/pixel/lpc/lpc_index.json and appends the pieces' credits to assets/pixel/lpc/CREDITS.csv.
Run it after tools/import_lpc.py and tools/lpc_extras.py (the importer rewrites the index).
"""
import csv
import json
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_lpc as base  # noqa: E402  (recolor, palette, licence_ok)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(REPO), '_vendor', 'lpc')
base.LPC = LPC
OUT = os.path.join(REPO, 'assets', 'pixel', 'lpc')
BODIES = ['male', 'female']

PIECES = {
    'weapon_bow_recurve': {'def': 'weapons/ranged/bow/weapon_ranged_bow_recurve.json', 'variant': 'medium'},
    'weapon_bow_great': {'def': 'weapons/ranged/bow/weapon_ranged_bow_great.json', 'variant': 'dark'},
    'weapon_crossbow': {'def': 'weapons/ranged/weapon_ranged_crossbow.json', 'variant': 'crossbow'},
    'shield_kite': {'def': 'weapons/shields/shield_kite.json', 'variant': 'kite_gray'},
    'shield_spartan': {'def': 'weapons/shields/shield_spartan.json', 'variant': 'spartan'},
    'backpack_satchel': {'def': 'torso/backpack/backpack_squarepack.json', 'variant': 'walnut'},
    'backpack_pack': {'def': 'torso/backpack/backpack.json', 'variant': 'leather'},
    'pants_dyed': {'def': 'legs/pants/legs_pants.json', 'palette': 'cloth', 'colors': ['navy', 'walnut']},
}


def import_piece(pid, spec, anims, credits_rows):
    defn = json.load(open(os.path.join(LPC, 'sheet_definitions', spec['def']), encoding='utf-8'))
    ok, lics = base.licence_ok(defn)
    if not ok:
        print('SKIP %s: licence %s' % (pid, lics))
        return None
    pal = base.palette(spec['palette']) if 'palette' in spec else None
    entry = {'name': defn.get('name', pid), 'licenses': lics,
             'authors': sorted(set(a for c in defn.get('credits', []) for a in c.get('authors', []))), 'layers': []}
    for lk in sorted(k for k in defn if k.startswith('layer_')):
        layer = defn[lk]
        if layer.get('custom_animation'):
            continue
        files = {}
        for body in BODIES:
            rel = layer.get(body)
            if not rel:
                continue
            for anim in anims:
                if 'variant' in spec:
                    src = os.path.join(LPC, 'spritesheets', rel, anim, spec['variant'] + '.png')
                    if not os.path.exists(src):
                        continue
                    dst_rel = '%s/%s/%s/%s.png' % (pid, lk, body, anim)
                    os.makedirs(os.path.dirname(os.path.join(OUT, dst_rel)), exist_ok=True)
                    Image.open(src).convert('RGBA').save(os.path.join(OUT, dst_rel))
                    files.setdefault(body, {}).setdefault('default', {})[anim] = dst_rel
                    credits_rows[os.path.relpath(src, os.path.join(LPC, 'spritesheets')).replace(os.sep, '/')] = rel
                    continue
                src = os.path.join(LPC, 'spritesheets', rel, anim + '.png')
                if not os.path.exists(src):
                    continue
                arr0 = np.array(Image.open(src).convert('RGBA'))
                credits_rows[rel + anim + '.png'] = rel
                for c in spec['colors']:
                    arr = base.recolor(arr0, pal[0][spec.get('base', pal[1])], pal[0][c])
                    dst_rel = '%s/%s/%s/%s/%s.png' % (pid, lk, body, c, anim)
                    os.makedirs(os.path.dirname(os.path.join(OUT, dst_rel)), exist_ok=True)
                    Image.fromarray(arr).save(os.path.join(OUT, dst_rel), optimize=True)
                    files.setdefault(body, {}).setdefault(c, {})[anim] = dst_rel
        if files:
            entry['layers'].append({'z': int(layer.get('zPos', 0)), 'files': files})
    return entry, defn


def main():
    index_path = os.path.join(OUT, 'lpc_index.json')
    index = json.load(open(index_path, encoding='utf-8'))
    all_credits = {r['filename']: r for r in csv.DictReader(open(os.path.join(LPC, 'CREDITS.csv'), encoding='utf-8'))}
    cpath = os.path.join(OUT, 'CREDITS.csv')
    have = {r['filename'] for r in csv.DictReader(open(cpath, encoding='utf-8'))}
    rows = []
    for pid, spec in PIECES.items():
        credits_rows = {}
        got = import_piece(pid, spec, index['anims'], credits_rows)
        if got is None:
            continue
        entry, defn = got
        index['pieces'][pid] = entry
        found = False
        for src, rel in sorted(credits_rows.items()):
            for key in (src, rel.rstrip('/')):
                r = all_credits.get(key)
                if r and key not in have:
                    have.add(key)
                    found = True
                    rows.append([r['filename'], r['notes'], r['authors'], r['licenses'], r['urls']])
        if not found:                            # no generator row: the sheet definition's own credits
            for c in defn.get('credits', []):
                key = c['file'] + ('/' + spec['variant'] + '.png' if 'variant' in spec else '')
                if key not in have:
                    have.add(key)
                    rows.append([key, c.get('notes', ''), ','.join(c['authors']), ','.join(c['licenses']), ','.join(c['urls'])])
        n = sum(len(a) for lay in entry['layers'] for b in lay['files'].values() for a in b.values())
        print('piece %s: %d layers, %d sheets' % (pid, len(entry['layers']), n))
    json.dump(index, open(index_path, 'w', encoding='utf-8'), indent=1)
    with open(cpath, 'a', newline='', encoding='utf-8') as f:
        csv.writer(f).writerows(rows)
    print('RESULT %d pieces, %d credit rows' % (len(PIECES), len(rows)))


if __name__ == '__main__':
    main()
