"""Importa peinados, barbas y cejas del Universal LPC Spritesheet Character Generator a assets/pixel/lpc/ y los anade a
lpc_index.json. Solo piezas con una licencia de solo atribucion (CC0, OGA-BY, CC-BY 3/4). Las hojas del generador vienen
en la paleta base 'orange' y aqui se recolorean a los 9 colores de pelo del juego.

    python tools/import_lpc_hair.py
"""
import glob
import json
import os
import sys

from PIL import Image

SRC = r"C:\Users\natha\Downloads\new assets\extracted_ulpc\Universal-LPC-Spritesheet-Character-Generator-master"
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "pixel", "lpc")
ANIMS = ["idle", "combat_idle", "walk", "run", "slash", "thrust", "shoot", "spellcast", "hurt"]
COLORS = ["black", "dark_brown", "chestnut", "light_brown", "blonde", "ginger", "gray", "white", "red"]
SAFE = ("CC0", "OGA-BY", "CC-BY 3", "CC-BY 4")

# (id de pieza, definicion del generador)
PIECES = [
    ("hair_long_straight", "hair/long/hair_long_straight"), ("hair_long_center_part", "hair/long/hair_long_center_part"),
    ("hair_long_tied", "hair/braids/hair_long_tied"), ("hair_xlong_wavy", "hair/xlong/hair_xlong_wavy"),
    ("hair_bob_side_part", "hair/bob/hair_bob_side_part"), ("hair_lob", "hair/bob/hair_lob"),
    ("hair_high_ponytail", "hair/braids/hair_high_ponytail"), ("hair_half_up", "hair/braids/hair_half_up"),
    ("hair_curly_short", "hair/curly/hair_curly_short"), ("hair_curly_long", "hair/curly/hair_curly_long"),
    ("hair_afro", "hair/afro/hair_afro"), ("hair_cornrows", "hair/afro/hair_cornrows"),
    ("hair_flat_top_fade", "hair/afro/hair_flat_top_fade"), ("hair_dreadlocks_short", "hair/afro/hair_dreadlocks_short"),
    ("hair_parted3", "hair/short/hair_parted3"), ("hair_balding", "hair/bald/hair_balding"),
    ("beard_medium", "hair/beards/beards_medium"), ("beard_winter", "hair/beards/beards_winter"),
    ("beard_handlebar", "hair/mustaches/beards_handlebar"), ("beard_walrus", "hair/mustaches/beards_walrus"),
    ("brows_thick", "head/eyebrows/eyebrows_thick"), ("brows_thin", "head/eyebrows/eyebrows_thin"),
]


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def main():
    palettes = json.load(open(os.path.join(SRC, "palette_definitions", "hair", "hair_ulpc.json"), encoding="utf8"))
    base = [hex_to_rgb(h) for h in palettes["orange"]]
    index_path = os.path.join(ROOT, "lpc_index.json")
    index = json.load(open(index_path, encoding="utf8"))
    added = 0
    for piece_id, rel in PIECES:
        definition_path = os.path.join(SRC, "sheet_definitions", *rel.split("/")) + ".json"
        definition = json.load(open(definition_path, encoding="utf8"))
        licenses, authors = set(), set()
        for credit in definition.get("credits", []):
            licenses |= set(x.strip() for x in credit.get("licenses", []))
            authors |= set(credit.get("authors", []))
        offered = [x for x in sorted(licenses) if x.startswith(SAFE)]
        if not offered:
            print("OMITIDO (licencia)", piece_id, sorted(licenses))
            continue
        layers = []
        for key in sorted(k for k in definition if k.startswith("layer_")):
            layer = definition[key]
            files = {"male": {}, "female": {}}
            for body in ("male", "female"):
                sheet_dir = layer.get(body)
                if not sheet_dir:
                    continue
                for color in COLORS:
                    entry = {}
                    for anim in ANIMS:
                        source = os.path.join(SRC, "spritesheets", *sheet_dir.strip("/").split("/"), anim + ".png")
                        if not os.path.exists(source):
                            continue
                        out_rel = "%s/%s/%s/%s/%s.png" % (piece_id, key, "male", color, anim)
                        out_path = os.path.join(ROOT, *out_rel.split("/"))
                        if not os.path.exists(out_path):
                            os.makedirs(os.path.dirname(out_path), exist_ok=True)
                            recolor(source, base, [hex_to_rgb(h) for h in palettes[color]]).save(out_path)
                        entry[anim] = out_rel
                    if entry:
                        files[body][color] = entry
            if files["male"] or files["female"]:
                layers.append({"z": int(layer.get("zPos", 100)), "files": files})
        if not layers:
            print("SIN HOJAS", piece_id)
            continue
        index["pieces"][piece_id] = {"name": definition.get("name", piece_id), "licenses": offered, "authors": sorted(authors), "layers": layers}
        added += 1
        print("ok", piece_id, offered)
    json.dump(index, open(index_path, "w", encoding="utf8"), ensure_ascii=False, indent=1)
    print("piezas anadidas:", added)


def recolor(path, base, target):
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    cache = {}
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            if key not in cache:
                best = min(range(len(base)), key=lambda i: sum((base[i][c] - key[c]) ** 2 for c in range(3)))
                cache[key] = target[min(best, len(target) - 1)]
            pixels[x, y] = cache[key] + (a,)
    return image


if __name__ == "__main__":
    sys.exit(main())
