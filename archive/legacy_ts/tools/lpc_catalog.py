"""Overhaul LPC phase 5: the wardrobe catalog (every LPC piece, for items) and sample sheets.

    python tools/lpc_catalog.py [path/to/_vendor/lpc]

Writes assets/pixel/lpc/wardrobe_catalog.json (visual_id, slot, lpc_item, variants, material, weight,
body_types, races, anims, z, license, authors, tags) and docs/reports/overhaul/vestuario/<slot>.png
(south-facing idle frame of each piece in its base colours, adult male body, max 60 per sheet) and
docs/reports/overhaul/razas.png. Only pieces whose licences pass the D-G filter are listed.
"""
import json, os, sys, glob, re
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(REPO), '_vendor', 'lpc')
OK = ('CC0', 'CC-BY', 'OGA-BY', 'CC-BY-SA')
SLOT_RULES = [
    (r'^weapons/shields', 'off_hand'), (r'^weapons/', 'main_hand'), (r'^tools/', 'main_hand'),
    (r'^headwear/neck', 'neck'), (r'^headwear/', 'head'),
    (r'^torso/cape', 'back'), (r'^torso/backpack', 'back'), (r'^torso/waist', 'belt'), (r'^torso/', 'chest'),
    (r'^arms/shoulders', 'shoulders'), (r'^arms/', 'hands'),
    (r'^legs/', 'legs'), (r'^feet/', 'feet'),
]
MATERIALS = [('plate', 'plate'), ('legion', 'plate'), ('armour_plate', 'plate'), ('chain', 'chain'), ('mail', 'chain'),
             ('leather', 'leather'), ('hide', 'leather'), ('fur', 'leather'), ('robe', 'cloth'), ('cloth', 'cloth'),
             ('shirt', 'cloth'), ('dress', 'cloth'), ('pants', 'cloth'), ('hood', 'cloth'), ('bandana', 'cloth'),
             ('cape', 'cloth'), ('helmet', 'plate'), ('greaves', 'plate'), ('bracers', 'leather'), ('gloves', 'leather'),
             ('boots', 'leather'), ('shoes', 'leather')]
WEIGHT = {'plate': 'heavy', 'chain': 'medium', 'leather': 'light', 'cloth': 'light'}


def slot_of(rel):
    for pat, s in SLOT_RULES:
        if re.search(pat, rel):
            return s
    return ''


def material_of(rel, name):
    key = (rel + ' ' + name).lower()
    for tok, m in MATERIALS:
        if tok in key:
            return m
    return 'other' if slot_of(rel) in ('main_hand', 'off_hand') else 'unknown'


def main():
    pieces = []
    for f in sorted(glob.glob(os.path.join(LPC, 'sheet_definitions', '**', '*.json'), recursive=True)):
        rel = os.path.relpath(f, os.path.join(LPC, 'sheet_definitions')).replace(os.sep, '/')
        if os.path.basename(f).startswith('meta'):
            continue
        slot = slot_of(rel)
        if not slot:
            continue
        d = json.load(open(f, encoding='utf-8'))
        lics = sorted(set(l for c in d.get('credits', []) for l in c.get('licenses', [])))
        if not any(l.upper().startswith(o) for l in lics for o in OK):
            continue
        l1 = d.get('layer_1', {})
        bodies = [b for b in ('male', 'female', 'muscular') if l1.get(b)]
        if not bodies:
            continue
        rec = d.get('recolors')
        variants = d.get('variants') or (rec if isinstance(rec, list) else [])
        material = material_of(rel, d.get('name', ''))
        vid = re.sub(r'[^a-z0-9]+', '_', rel[:-5].lower()).strip('_')
        pieces.append({'visual_id': vid, 'slot': slot, 'lpc_item': rel, 'name': d.get('name', ''), 'variants': variants,
                       'recolor': rec if isinstance(rec, dict) else None, 'material': material,
                       'weight': WEIGHT.get(material, 'none'), 'body_types': bodies, 'races': ['human', 'elf'],
                       'anims': d.get('animations', []), 'z': l1.get('zPos', 0), 'license': lics,
                       'authors': sorted(set(a for c in d.get('credits', []) for a in c.get('authors', []))),
                       'tags': [t for t in re.split(r'[/_]', rel[:-5]) if len(t) > 2], 'layer_path': l1.get('male') or l1.get(bodies[0])})
    out = os.path.join(REPO, 'assets', 'pixel', 'lpc', 'wardrobe_catalog.json')
    json.dump({'_doc': 'tools/lpc_catalog.py; LPC commit in docs/specs/LPC_FORMAT.md', 'pieces': pieces}, open(out, 'w', encoding='utf-8'), indent=1)
    # sample sheets per slot
    body = Image.open(os.path.join(LPC, 'spritesheets', 'body', 'bodies', 'male', 'idle.png')).convert('RGBA').crop((0, 128, 64, 192))
    head = Image.open(os.path.join(LPC, 'spritesheets', 'head', 'heads', 'human', 'male', 'idle.png')).convert('RGBA').crop((0, 128, 64, 192))
    os.makedirs(os.path.join(REPO, 'docs', 'reports', 'overhaul', 'vestuario'), exist_ok=True)
    by_slot = {}
    for p in pieces:
        by_slot.setdefault(p['slot'], []).append(p)
    counts = {}
    for slot, ps in by_slot.items():
        frames = []
        for p in ps:
            path = p['layer_path']
            cand = [os.path.join(LPC, 'spritesheets', path, 'idle.png'), os.path.join(LPC, 'spritesheets', path, 'walk.png')]
            for v in p['variants'][:1]:
                cand += [os.path.join(LPC, 'spritesheets', path, 'idle', v + '.png'), os.path.join(LPC, 'spritesheets', path, 'walk', v + '.png')]
            src = next((c for c in cand if os.path.exists(c)), None)
            if not src:
                continue
            im = Image.open(src).convert('RGBA')
            if im.height < 192:
                continue
            fr = Image.new('RGBA', (64, 64), (84, 115, 76, 255))
            fr.alpha_composite(body)
            fr.alpha_composite(head)
            fr.alpha_composite(im.crop((0, 128, 64, 192)))
            frames.append(fr)
        counts[slot] = (len(ps), len(frames))
        frames = frames[:60]
        if not frames:
            continue
        cols = 10
        sheet = Image.new('RGBA', (64 * cols, 64 * ((len(frames) + cols - 1) // cols)), (60, 80, 55, 255))
        for i, fr in enumerate(frames):
            sheet.paste(fr, ((i % cols) * 64, (i // cols) * 64))
        sheet.save(os.path.join(REPO, 'docs', 'reports', 'overhaul', 'vestuario', slot + '.png'))
    print('RESULT pieces %d; per slot (catalogued, sampled): %s' % (len(pieces), counts))


if __name__ == '__main__':
    main()
