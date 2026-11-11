"""Overhaul LPC phase 5: one sample of every non-human LPC race head (adult) on the male body.
    python tools/lpc_races_sheet.py [path/to/_vendor/lpc]  -> docs/reports/overhaul/razas.png"""
import json, os, sys, glob
from PIL import Image
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(REPO), '_vendor', 'lpc')
body = Image.open(os.path.join(LPC, 'spritesheets/body/bodies/male/idle.png')).convert('RGBA').crop((0, 128, 64, 192))
frames, names = [], []
for f in sorted(glob.glob(os.path.join(LPC, 'sheet_definitions/head/heads/*/*.json'))):
    if 'child' in f or 'human' in f or os.path.basename(f).startswith('meta'):
        continue
    d = json.load(open(f, encoding='utf-8'))
    p = d.get('layer_1', {}).get('male')
    src = os.path.join(LPC, 'spritesheets', p or '', 'idle.png')
    if not p or not os.path.exists(src):
        continue
    fr = Image.new('RGBA', (64, 64), (84, 115, 76, 255))
    fr.alpha_composite(body)
    fr.alpha_composite(Image.open(src).convert('RGBA').crop((0, 128, 64, 192)))
    frames.append(fr)
    names.append(d.get('name'))
sheet = Image.new('RGBA', (64 * 10, 64 * ((len(frames) + 9) // 10)), (60, 80, 55, 255))
for i, fr in enumerate(frames):
    sheet.paste(fr, ((i % 10) * 64, (i // 10) * 64))
sheet.save(os.path.join(REPO, 'docs/reports/overhaul/razas.png'))
print('RESULT razas %d: %s' % (len(names), ', '.join(names)))
