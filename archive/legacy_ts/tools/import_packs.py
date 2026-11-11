"""Overhaul LPC phase 6: copies the used PNGs of the new packs (assets/nuevos assets/, git- and
Godot-ignored) into assets/pixel/packs/<short>/ and registers each pack in assets/ASSET_REGISTRY.json.

    python tools/import_packs.py

Only PNGs, never previews, coupons or pack covers (1840x2445). Licences: CraftPix freebies point to
https://craftpix.net/file-licenses/ (commercial use yes, redistributing the pack no); Willibab icons
are free for commercial use (author page); the three files with no licence are used with the owner's
permission (2026-10-31) and flagged "review before release". Duplicates "* (1).zip" are skipped.
"""
import glob, io, json, os, re, struct, zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, 'assets', 'nuevos assets')
OUT = os.path.join(REPO, 'assets', 'pixel', 'packs')
CRAFTPIX = 'CraftPix Freebie License (https://craftpix.net/file-licenses/): commercial use yes, no redistribution of the pack'
UNKNOWN = 'Unknown licence, use authorised by the owner on 2026-10-31 (exception to D-024) - REVIEW BEFORE RELEASE'
# short name -> (zip name pattern, use)
PACKS = {
    'trees': ('free-top-down-trees-pixel-art', 'forest trees'), 'trees2': ('free-tree-pixel-art-asset-pack', 'forest trees'),
    'bushes': ('free-top-down-bushes', 'forest bushes'), 'forest_objects': ('free-forest-objects-top-down', 'forest props'),
    'rocks': ('free-rocks-pixel-art-asset-pack', 'rocks'), 'rocks2': ('free-rocks-and-stones', 'rocks'), 'rocky': ('free-rocky-area-objects', 'rocks'),
    'paths': ('free-path-and-road-top-down', 'roads'), 'bridges': ('free-bridges-top-down', 'bridges'), 'plants': ('free-pixel-art-plants-for-farm', 'plants'),
    'village_buildings': ('free-fantasy-medieval-village-buildings', 'town'), 'village_tiles': ('free-village-pixel-tileset-for-top-down-defense', 'town'),
    'guild_hall': ('free-top-down-pixel-art-guild-hall', 'town'), 'home': ('main-characters-home', 'town'), 'glassblower': ('free-glassblowers-workshop', 'town'), 'chapel': ('free-chapel-pixel-art', 'town'),
    'dungeon': ('free-2d-top-down-pixel-dungeon', 'dungeon'), 'dungeon_objects': ('free-pixel-art-dungeon-objects', 'dungeon'), 'dungeon_props': ('free-pixel-dungeon-props', 'dungeon'),
    'cave': ('free-top-down-pixel-art-cave-objects', 'cave'), 'crystals': ('top-down-crystals', 'cave'), 'ruins': ('free-top-down-ruins', 'ruins'), 'temple': ('free-ruined-temple', 'ruins'),
    'undead_tiles': ('free-undead-tileset', 'undead'), 'cursed_land': ('free-cursed-land', 'undead'), 'seabed': ('free-top-down-seabed-objects', 'water'),
    'slimes': ('free-slime-mobs', 'creatures'), 'plant_mobs': ('free-predator-plant-mobs', 'creatures'), 'hunt_animals': ('free-top-down-hunt-animals', 'creatures'), 'farm_animals': ('free-top-down-animals-farm', 'creatures'),
    'icons_loot': ('free-rpg-loot-icons', 'item icons'), 'icons_loot40': ('free-40-loot-icons', 'item icons'), 'icons_goblin': ('free-goblin-loot-icons', 'item icons'), 'icons_undead': ('free-undead-loot', 'item icons'),
    'icons_weapons': ('32x32-pixel-art-weapons', 'item icons'), 'icons_bows': ('free-bow-and-crossbow', 'item icons'), 'icons_clothing': ('free-clothing-32x32', 'item icons'),
    'icons_shield_amulet': ('free-shield-and-amulet', 'item icons'), 'icons_belt': ('free-belt-rpg', 'item icons'), 'icons_minerals': ('free-minerals-pixel-art-icons', 'item icons'),
    'icons_mine': ('free-pixel-art-icons-for-mine-location', 'item icons'), 'icons_paint': ('free-paint-pixel-art-icon-pack', 'item icons'),
    'skills_swordsman': ('free-swordsman-skills', 'skill icons'), 'skills_paladin': ('free-paladin-pixel-art-skill', 'skill icons'),
    'ui_icons': ('free-basic-pixel-art-fantasy-icons-16x16', 'UI icons'), 'ui_basic': ('free-basic-pixel-art-ui-for-rpg', 'UI (D-075)'),
    'bg_summer': ('free-summer-pixel-art-backgrounds', 'backgrounds'), 'bg_sky': ('free-sky-with-clouds', 'backgrounds'), 'bg_ocean': ('ocean-and-clouds', 'backgrounds'),
    'bg_nature': ('free-nature-backgrounds', 'backgrounds'), 'bg_battlegrounds': ('free-pixel-art-fantasy-2d-battlegrounds', 'menu backgrounds (side view)'),
    'magic_book': ('free-animated-magic-book', 'effects'), 'halloween': ('free-halloween-icons', 'event catalogue (unused)'),
    'rpg_icons': ('RPG Icons', 'item icons'),
}
SINGLE = {  # loose files in the folder
    'willibab': (['CHESTS.png', 'HELMS.png', 'SHIELDS.png'], 'Willibab armor icons: free for commercial use (author page)', 'item icons'),
    'pixel_weapons': (['32x32_PixelWeapons_Free.png'], UNKNOWN, 'item icons'),
}
SKIP = re.compile(r'(preview|coupon|__macosx|example|promo|license|readme)', re.I)


def png_size(b):
    return struct.unpack('>II', b[16:24]) if b[:8] == b'\x89PNG\r\n\x1a\n' else (0, 0)


def main():
    reg_path = os.path.join(REPO, 'assets', 'ASSET_REGISTRY.json')
    reg = json.load(open(reg_path, encoding='utf-8'))
    entries = reg.setdefault('assets', [])
    report = []
    for short, (pat, use) in PACKS.items():
        zips = [z for z in glob.glob(os.path.join(SRC, '*.zip')) if pat in os.path.basename(z) and ' (1).zip' not in z]
        if not zips:
            report.append('%s: MISSING' % short)
            continue
        zf = zipfile.ZipFile(zips[0])
        n = 0
        for info in zf.infolist():
            name = info.filename
            if not name.lower().endswith('.png') or SKIP.search(name):
                continue
            data = zf.read(name)
            w, h = png_size(data)
            if (w, h) in ((1840, 2445), (0, 0)):
                continue
            dst = os.path.join(OUT, short, re.sub(r'[^A-Za-z0-9_./-]+', '_', name))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            open(dst, 'wb').write(data)
            n += 1
        lic = UNKNOWN if short == 'rpg_icons' else CRAFTPIX
        entries.append({'id': 'pack.' + short, 'source': os.path.basename(zips[0]), 'path': 'assets/pixel/packs/' + short,
                        'license': lic, 'use': use, 'files': n, 'added': '2026-10-31'})
        report.append('%s: %d' % (short, n))
    for short, (files, lic, use) in SINGLE.items():
        n = 0
        for f in files:
            src = os.path.join(SRC, f)
            if os.path.exists(src):
                dst = os.path.join(OUT, short, f)
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                open(dst, 'wb').write(open(src, 'rb').read())
                n += 1
        entries.append({'id': 'pack.' + short, 'source': ', '.join(files), 'path': 'assets/pixel/packs/' + short, 'license': lic, 'use': use, 'files': n, 'added': '2026-10-31'})
        report.append('%s: %d' % (short, n))
    armor16 = os.path.join(SRC, 'Armor[16x16].zip')
    if os.path.exists(armor16):
        zf = zipfile.ZipFile(armor16)
        for info in zf.infolist():
            if info.filename.lower().endswith('.png') and not SKIP.search(info.filename):
                dst = os.path.join(OUT, 'armor16', os.path.basename(info.filename))
                os.makedirs(os.path.dirname(dst), exist_ok=True)
                open(dst, 'wb').write(zf.read(info.filename))
        entries.append({'id': 'pack.armor16', 'source': 'Armor[16x16].zip', 'path': 'assets/pixel/packs/armor16', 'license': UNKNOWN, 'use': 'item icons', 'added': '2026-10-31'})
    seen = {}
    for e in entries:
        seen[e.get('id', id(e))] = e
    reg['assets'] = list(seen.values())
    json.dump(reg, open(reg_path, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
    print('RESULT ' + '; '.join(report))


if __name__ == '__main__':
    main()
