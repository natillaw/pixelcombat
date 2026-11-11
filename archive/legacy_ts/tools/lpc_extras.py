"""D-082b: adds two pieces to the imported LPC set without re-running the whole importer.

    python tools/lpc_extras.py [path/to/_vendor/lpc]

- shield_round: the LPC "Round Shield" (brown = wooden), for the warriors' starter shield.
- weapon_dagger_offhand: the imported LPC dagger mirrored (left/right rows swapped and flipped, up/down
  flipped), so a rogue shows a second dagger in the other hand. LPC has no off-hand dagger of its own.
Updates assets/pixel/lpc/lpc_index.json and appends the shield's credits to assets/pixel/lpc/CREDITS.csv
(the mirrored dagger keeps the dagger's credits). Licences: OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0.
"""
import csv
import json
import os
import sys

from PIL import Image, ImageOps

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(REPO), '_vendor', 'lpc')
OUT = os.path.join(REPO, 'assets', 'pixel', 'lpc')
FRAME = 64
BODIES = ['male', 'female']


def mirror_sheet(img):
    """Rows are up, left, down, right (or one row): swap left/right and flip every row."""
    rows = img.height // FRAME
    out = Image.new('RGBA', img.size)
    for r in range(rows):
        src = r
        if rows >= 4 and r in (1, 3):
            src = 4 - r                      # left <-> right
        row = img.crop((0, src * FRAME, img.width, (src + 1) * FRAME))
        # flip each frame in place (not the whole strip, so the frame order stays)
        flipped = Image.new('RGBA', row.size)
        for c in range(row.width // FRAME):
            fr = row.crop((c * FRAME, 0, (c + 1) * FRAME, FRAME))
            flipped.paste(ImageOps.mirror(fr), (c * FRAME, 0))
        out.paste(flipped, (0, r * FRAME))
    return out


def main():
    index_path = os.path.join(OUT, 'lpc_index.json')
    index = json.load(open(index_path, encoding='utf-8'))
    anims = index['anims']
    # 1. round shield (brown)
    defn = json.load(open(os.path.join(LPC, 'sheet_definitions', 'weapons', 'shields', 'shield_round.json'), encoding='utf-8'))
    layer = defn['layer_1']
    files = {}
    for body in BODIES:
        for anim in anims:
            src = os.path.join(LPC, 'spritesheets', layer[body], anim, 'brown.png')
            if not os.path.exists(src):
                continue
            rel = 'shield_round/layer_1/%s/%s.png' % (body, anim)
            os.makedirs(os.path.dirname(os.path.join(OUT, rel)), exist_ok=True)
            Image.open(src).convert('RGBA').save(os.path.join(OUT, rel))
            files.setdefault(body, {}).setdefault('default', {})[anim] = rel
    index['pieces']['shield_round'] = {'name': 'Round Shield (wood)', 'licenses': sorted(set(l for c in defn['credits'] for l in c['licenses'])),
                                       'authors': sorted(set(a for c in defn['credits'] for a in c['authors'])),
                                       'layers': [{'z': int(layer.get('zPos', 110)), 'files': files}]}
    # 2. off-hand dagger: mirror of the imported dagger
    dag = index['pieces']['weapon_dagger']
    layers = []
    for lay in dag['layers']:
        nf = {}
        for body, variants in lay['files'].items():
            for var, by_anim in variants.items():
                for anim, rel in by_anim.items():
                    img = Image.open(os.path.join(OUT, rel)).convert('RGBA')
                    nrel = rel.replace('weapon_dagger/', 'weapon_dagger_offhand/', 1)
                    os.makedirs(os.path.dirname(os.path.join(OUT, nrel)), exist_ok=True)
                    mirror_sheet(img).save(os.path.join(OUT, nrel))
                    nf.setdefault(body, {}).setdefault(var, {})[anim] = nrel
        layers.append({'z': lay['z'], 'files': nf})
    index['pieces']['weapon_dagger_offhand'] = {'name': 'Dagger (off hand, mirrored)', 'licenses': dag['licenses'], 'authors': dag['authors'], 'layers': layers}
    json.dump(index, open(index_path, 'w', encoding='utf-8'), indent=1)
    # credits for the shield
    # the generator's CREDITS.csv has no row for it: the sheet definition's own credits are written
    cpath = os.path.join(OUT, 'CREDITS.csv')
    have = {r['filename'] for r in csv.DictReader(open(cpath, encoding='utf-8'))}
    with open(cpath, 'a', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        for c in defn['credits']:
            key = c['file'] + '/brown.png'
            if key not in have:
                w.writerow([key, c.get('notes', ''), ','.join(c['authors']), ','.join(c['licenses']), ','.join(c['urls'])])
    print('RESULT shield_round %d bodies, weapon_dagger_offhand %d layers' % (len(files), len(layers)))


if __name__ == '__main__':
    main()
