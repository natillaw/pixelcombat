"""Overhaul LPC phase 2: reproducible importer from the LPC generator repo into assets/pixel/lpc/.

    python tools/import_lpc.py [path/to/_vendor/lpc]     (default: ../_vendor/lpc next to the repo)

Reads tools/lpc_manifest.json. For every piece and every adult body in the manifest it copies only the
animations the game uses, recoloured with the LPC palettes (palette_definitions/*: the base variant's
colours are swapped for the target variant's, +-1 per channel like the generator), or the named variant
for weapon-style pieces (<layer>/<anim>/<variant>.png). Oversized custom animations (slash_128...) are
not imported yet. Writes assets/pixel/lpc/lpc_index.json (piece -> layers -> files) and
assets/pixel/lpc/CREDITS.csv (only the files used). Licence filter: CC0 / CC-BY / OGA-BY / CC-BY-SA
(dual with GPL is fine; GPL-only is skipped).
"""
import csv, json, os, sys
import numpy as np
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LPC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(REPO), '_vendor', 'lpc')
OUT = os.path.join(REPO, 'assets', 'pixel', 'lpc')
OK = ('CC0', 'CC-BY', 'OGA-BY', 'CC-BY-SA')


def palette(material):
    folder = os.path.join(LPC, 'palette_definitions', material)
    meta = json.load(open(os.path.join(folder, 'meta_%s.json' % material), encoding='utf-8'))
    pal = json.load(open(os.path.join(folder, '%s_ulpc.json' % material), encoding='utf-8'))
    return pal, meta['base']


def hex_rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def recolor(arr, src, dst):
    out = arr.copy()
    rgb = arr[..., :3].astype(np.int16)
    for s, d in zip(src, dst):
        m = np.all(np.abs(rgb - np.array(hex_rgb(s), dtype=np.int16)) <= 1, axis=-1) & (arr[..., 3] > 0)
        out[m, :3] = hex_rgb(d)
    return out


def licence_ok(defn):
    lics = [l for c in defn.get('credits', []) for l in c.get('licenses', [])]
    return any(l.upper().startswith(o) for l in lics for o in OK), sorted(set(lics))


def main():
    man = json.load(open(os.path.join(REPO, 'tools', 'lpc_manifest.json'), encoding='utf-8'))
    index = {'_source': 'LPC generator commit in docs/specs/LPC_FORMAT.md', 'anims': man['anims'], 'pieces': {}}
    credits_rows = {}
    all_credits = {r['filename']: r for r in csv.DictReader(open(os.path.join(LPC, 'CREDITS.csv'), encoding='utf-8'))}
    warnings = []
    written = 0
    for pid, spec in man['pieces'].items():
        defn = json.load(open(os.path.join(LPC, 'sheet_definitions', spec['def']), encoding='utf-8'))
        ok, lics = licence_ok(defn)
        if not ok:
            warnings.append('%s: licence %s not allowed, skipped' % (pid, lics))
            continue
        colors = spec.get('colors')
        colors = man[colors] if isinstance(colors, str) else colors
        colors2 = spec.get('colors2', [None])
        colors2 = man[colors2] if isinstance(colors2, str) else colors2
        pal = palette(spec['palette']) if 'palette' in spec else None
        pal2 = palette(spec['palette2']) if 'palette2' in spec else None
        entry = {'name': defn.get('name', pid), 'licenses': lics, 'authors': sorted(set(a for c in defn.get('credits', []) for a in c.get('authors', []))), 'layers': []}
        for lk in sorted(k for k in defn if k.startswith('layer_')):
            layer = defn[lk]
            if layer.get('custom_animation'):
                continue                               # oversized frames: later phase
            files = {}
            for body in man['bodies']:
                rel = layer.get(body)
                if not rel:
                    warnings.append('%s %s: no %s sheet' % (pid, lk, body))
                    continue
                for anim in man['anims']:
                    if 'variant' in spec or 'variants' in defn and not pal:
                        variant = spec.get('variant') or (defn.get('variants') or [''])[0]
                        src = os.path.join(LPC, 'spritesheets', rel, anim, variant + '.png')
                        if not os.path.exists(src):
                            continue
                        dst_rel = '%s/%s/%s/%s.png' % (pid, lk, body, anim)
                        os.makedirs(os.path.dirname(os.path.join(OUT, dst_rel)), exist_ok=True)
                        Image.open(src).convert('RGBA').save(os.path.join(OUT, dst_rel))
                        files.setdefault(body, {}).setdefault('default', {})[anim] = dst_rel
                        credits_rows[os.path.relpath(src, os.path.join(LPC, 'spritesheets')).replace(os.sep, '/')] = rel
                        written += 1
                        continue
                    src = os.path.join(LPC, 'spritesheets', rel, anim + '.png')
                    if not os.path.exists(src):
                        continue
                    base = np.array(Image.open(src).convert('RGBA'))
                    credits_rows[rel + anim + '.png'] = rel
                    for c1 in colors:
                        for c2 in colors2:
                            arr = base
                            if pal:
                                arr = recolor(arr, pal[0][spec.get('base', pal[1])], pal[0][c1])
                            if pal2 and c2:
                                arr = recolor(arr, pal2[0][spec.get('base2', pal2[1])], pal2[0][c2])
                            var = c1 + ('_' + c2 if c2 else '')
                            dst_rel = '%s/%s/%s/%s/%s.png' % (pid, lk, body, var, anim)
                            os.makedirs(os.path.dirname(os.path.join(OUT, dst_rel)), exist_ok=True)
                            Image.fromarray(arr).save(os.path.join(OUT, dst_rel), optimize=True)
                            files.setdefault(body, {}).setdefault(var, {})[anim] = dst_rel
                            written += 1
            missing = [a for a in man['anims'] if not any(a in v for b in files.values() for v in b.values())]
            if missing:
                warnings.append('%s %s: no %s (falls back in LpcComposer)' % (pid, lk, ','.join(missing)))
            entry['layers'].append({'z': int(layer.get('zPos', 0)), 'files': files})
        index['pieces'][pid] = entry
    os.makedirs(OUT, exist_ok=True)
    json.dump(index, open(os.path.join(OUT, 'lpc_index.json'), 'w', encoding='utf-8'), indent=1)
    with open(os.path.join(OUT, 'CREDITS.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(['filename', 'notes', 'authors', 'licenses', 'urls'])
        seen = set()
        for src, rel in sorted(credits_rows.items()):
            for key in (src, rel.rstrip('/')):
                r = all_credits.get(key)
                if r and key not in seen:
                    seen.add(key)
                    w.writerow([r['filename'], r['notes'], r['authors'], r['licenses'], r['urls']])
    open(os.path.join(OUT, 'import_warnings.txt'), 'w', encoding='utf-8').write('\n'.join(warnings) + '\n')
    print('RESULT pieces %d, files %d, warnings %d' % (len(index['pieces']), written, len(warnings)))


if __name__ == '__main__':
    main()
