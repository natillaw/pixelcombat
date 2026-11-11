"""Bakes the Tiled maps (.tmx) shipped inside the CraftPix packs into PNG scenes (owner, 2026-10-31:
building interiors you can enter). Reads the zips in assets/nuevos assets/ (never copied raw) and
writes assets/pixel/interiors/<name>.png plus <name>.json (size, tile size).

    python tools/bake_tmx.py

Supports orthogonal maps, embedded or external tilesets (.tsx) with one image, CSV / base64 (+zlib/gzip)
layer data, tile flips, group layers, hidden layers skipped, and tile objects in object layers.
"""
import base64, gzip, io, json, os, re, struct, zipfile, zlib
import xml.etree.ElementTree as ET
from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, 'assets', 'nuevos assets')
OUT = os.path.join(REPO, 'assets', 'pixel', 'interiors')
MAPS = {  # output name -> (zip pattern, tmx path)
    'smithy_interior': ('glassblowers-workshop', 'Tiled_files/Interior.tmx'),
    'smithy_exterior': ('glassblowers-workshop', 'Tiled_files/Exterior.tmx'),
    'chapel_interior': ('free-chapel', 'Tiled_files/Interior.tmx'),
    'chapel_exterior': ('free-chapel', 'Tiled_files/Exterior.tmx'),
    'guild_hall_1f': ('guild-hall', 'Tiled_files/Interior_1st_floor.tmx'),
    'guild_hall_2f': ('guild-hall', 'Tiled_files/Interior_2nd_floor.tmx'),
    'home_interior': ('main-characters-home', 'Tiled_files/Interior1.tmx'),
    'home_exterior': ('main-characters-home', 'Tiled_files/Exterior.tmx'),
    'dungeon1': ('pixel-dungeon-asset-pack', 'Tiled_files/Dungeon1.tmx'),
    'temple_interior': ('ruined-temple', 'Tiled_files/Ruined_temple_interior.tmx'),
    'temple_exterior': ('ruined-temple', 'Tiled_files/Ruined_temple_exterior.tmx'),
}
## Buildings alone (for the town): only the layers whose name matches, ground excluded.
BUILDINGS = {
    'bld_smithy': ('glassblowers-workshop', 'Tiled_files/Exterior.tmx', r'(?i)^(tent_shadow|supplies|tent|sign|walls|windows_top|roof|stovepipe|roof_detail|barrel|cart)$'),
    'bld_chapel': ('free-chapel', 'Tiled_files/Exterior.tmx', r'(?i)^(house)$'),
    'bld_home': ('main-characters-home', 'Tiled_files/Exterior.tmx', r'(?i)^(house_wall|windows1|windows2|house_roof)$'),
    'bld_temple': ('ruined-temple', 'Tiled_files/Ruined_temple_exterior.tmx', r'(?i)^(house_platform|house|bricks|roof|statues|columns)$'),
}
ONLY = None
FLIP_H, FLIP_V, FLIP_D = 0x80000000, 0x40000000, 0x20000000


def zfind(zf, path):
    path = os.path.normpath(path).replace(os.sep, '/')
    names = {n.lower(): n for n in zf.namelist() if not n.startswith('__MACOSX')}
    if path.lower() in names:
        return names[path.lower()]
    base = os.path.basename(path).lower()
    for low, real in names.items():
        if low.endswith('/' + base) or low == base:
            return real
    return None


def load_tileset(zf, ts_el, base_dir):
    first = int(ts_el.get('firstgid'))
    src = ts_el.get('source')
    if src:
        p = zfind(zf, os.path.join(base_dir, src))
        ts_el = ET.fromstring(zf.read(p))
        base_dir = os.path.dirname(p)
    tw, th = int(ts_el.get('tilewidth')), int(ts_el.get('tileheight'))
    cols = int(ts_el.get('columns') or 0)
    img_el = ts_el.find('image')
    tiles = {}
    if img_el is not None:
        p = zfind(zf, os.path.join(base_dir, img_el.get('source')))
        if p is None:
            return tiles                                  # a tileset image the pack does not ship
        sheet = Image.open(io.BytesIO(zf.read(p))).convert('RGBA')
        cols = cols or sheet.width // tw
        count = int(ts_el.get('tilecount') or (sheet.width // tw) * (sheet.height // th))
        margin, spacing = int(ts_el.get('margin') or 0), int(ts_el.get('spacing') or 0)
        for i in range(count):
            x = margin + (i % cols) * (tw + spacing)
            y = margin + (i // cols) * (th + spacing)
            tiles[first + i] = sheet.crop((x, y, x + tw, y + th))
    for t in ts_el.findall('tile'):                     # collection of images
        im = t.find('image')
        if im is not None:
            p = zfind(zf, os.path.join(base_dir, im.get('source')))
            if p:
                tiles[first + int(t.get('id'))] = Image.open(io.BytesIO(zf.read(p))).convert('RGBA')
    return tiles


def decode(data_el, text=None):
    text = data_el.text if text is None else text
    if data_el.get('encoding') == 'csv':
        return [int(v) for v in text.split(',') if v.strip()]
    raw = base64.b64decode(text.strip())
    if data_el.get('compression') == 'zlib':
        raw = zlib.decompress(raw)
    elif data_el.get('compression') == 'gzip':
        raw = gzip.decompress(raw)
    return list(struct.unpack('<%dI' % (len(raw) // 4), raw))


def cells(layer, w):
    """(tile x, tile y, gid) of a layer, for finite maps and infinite (chunked) ones."""
    data = layer.find('data')
    chunks = data.findall('chunk')
    if chunks:
        for ch in chunks:
            cx, cy, cw = int(ch.get('x')), int(ch.get('y')), int(ch.get('width'))
            for i, gid in enumerate(decode(data, ch.text)):
                if gid:
                    yield cx + i % cw, cy + i // cw, gid
    else:
        for i, gid in enumerate(decode(data)):
            if gid:
                yield i % w, i // w, gid


def tile_img(tiles, gid):
    t = tiles.get(gid & ~(FLIP_H | FLIP_V | FLIP_D))
    if t is None:
        return None
    if gid & FLIP_D:
        t = t.transpose(Image.TRANSPOSE)
    if gid & FLIP_H:
        t = t.transpose(Image.FLIP_LEFT_RIGHT)
    if gid & FLIP_V:
        t = t.transpose(Image.FLIP_TOP_BOTTOM)
    return t


def collect(parent, tiles, tw, th, w, draws):
    """Appends (x px, y px, image) in drawing order."""
    for el in parent:
        if el.tag in ('layer', 'objectgroup') and ONLY and not re.search(ONLY, el.get('name') or ''):
            continue
        if el.get('visible') == '0' or re.search(r'(?i)charact|people|npc|citizen|customer', el.get('name') or ''):
            continue                                      # the pack's own characters: our heroes go there
        if el.tag == 'group':
            collect(el, tiles, tw, th, w, draws)
        elif el.tag == 'layer':
            ox, oy = int(float(el.get('offsetx') or 0)), int(float(el.get('offsety') or 0))
            for x, y, gid in cells(el, w):
                t = tile_img(tiles, gid)
                if t is not None:
                    draws.append((x * tw + ox, y * th + oy + th - t.height, t))
        elif el.tag == 'objectgroup':
            for o in sorted(el.findall('object'), key=lambda o: float(o.get('y'))):
                if o.get('gid') and o.get('visible') != '0':
                    t = tile_img(tiles, int(o.get('gid')))
                    if t is None:
                        continue
                    ow, oh = int(float(o.get('width') or t.width)), int(float(o.get('height') or t.height))
                    if (ow, oh) != t.size:
                        t = t.resize((ow, oh), Image.NEAREST)
                    draws.append((int(float(o.get('x'))), int(float(o.get('y'))) - oh, t))


def bake(name, pat, tmx):
    zips = [z for z in os.listdir(SRC) if pat in z and z.endswith('.zip') and ' (1)' not in z]
    zf = zipfile.ZipFile(os.path.join(SRC, zips[0]))
    p = zfind(zf, tmx)
    root = ET.fromstring(zf.read(p))
    w, h = int(root.get('width')), int(root.get('height'))
    tw, th = int(root.get('tilewidth')), int(root.get('tileheight'))
    tiles = {}
    for ts in root.findall('tileset'):
        tiles.update(load_tileset(zf, ts, os.path.dirname(p)))
    draws = []
    collect(root, tiles, tw, th, w, draws)
    x0 = min(d[0] for d in draws)
    y0 = min(d[1] for d in draws)
    x1 = max(d[0] + d[2].width for d in draws)
    y1 = max(d[1] + d[2].height for d in draws)
    out = Image.new('RGBA', (x1 - x0, y1 - y0), (0, 0, 0, 0))
    for x, y, t in draws:
        out.alpha_composite(t, (x - x0, y - y0))
    os.makedirs(OUT, exist_ok=True)
    out.save(os.path.join(OUT, name + '.png'))
    json.dump({'source': zips[0], 'tmx': tmx, 'tile': [tw, th], 'size': list(out.size)}, open(os.path.join(OUT, name + '.json'), 'w'), indent=1)
    return out.size


if __name__ == '__main__':
    for name, (pat, tmx, only) in BUILDINGS.items():
        ONLY = only
        try:
            print('RESULT', name, bake(name, pat, tmx))
        except Exception as e:
            print('FAILED', name, type(e).__name__, str(e)[:120])
    ONLY = None
    for name, (pat, tmx) in MAPS.items():
        try:
            print('RESULT', name, bake(name, pat, tmx))
        except Exception as e:
            print('FAILED', name, type(e).__name__, str(e)[:120])
