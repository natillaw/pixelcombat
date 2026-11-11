#!/usr/bin/env python3
"""Contact sheet: stacks every PNG of a folder (recursive) with its name, size and a numbered grid.
Usage: python tools\\contact_sheet.py <folder> <out.png> [--grid 32] [--scale 3] [--width 1500] [--match text] [--max 40]
Needs Pillow (pip install pillow). Lets a person (or an AI) pick tiles/frames from ONE image."""
import argparse, os, sys
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("folder"); ap.add_argument("out")
ap.add_argument("--grid", type=int, default=16, help="cell size in source pixels")
ap.add_argument("--scale", type=int, default=3)
ap.add_argument("--width", type=int, default=1500)
ap.add_argument("--match", default="", help="only files whose path contains this text")
ap.add_argument("--max", type=int, default=60)
a = ap.parse_args()

files = []
for d, _, fs in os.walk(a.folder):
    for f in sorted(fs):
        p = os.path.join(d, f)
        if f.lower().endswith(".png") and a.match.lower() in p.lower():
            files.append(p)
files = sorted(files)[: a.max]
if not files:
    sys.exit("no PNG found")

items = []
for p in files:
    im = Image.open(p).convert("RGBA")
    w, h = im.size
    big = im.resize((w * a.scale, h * a.scale), Image.NEAREST)
    bg = Image.new("RGBA", big.size, (70, 70, 80, 255))      # neutral backdrop so alpha shows
    bg.alpha_composite(big)
    dr = ImageDraw.Draw(bg)
    cs = a.grid * a.scale
    for i, x in enumerate(range(0, big.width, cs)):
        dr.line([(x, 0), (x, big.height)], fill=(255, 255, 0, 110))
        dr.text((x + 2, 1), str(i), fill=(255, 255, 0, 255))
    for j, y in enumerate(range(0, big.height, cs)):
        dr.line([(0, y), (big.width, y)], fill=(0, 255, 255, 110))
        if j:
            dr.text((2, y + 1), "r%d" % j, fill=(0, 255, 255, 255))
    label = "%s  %dx%d" % (os.path.relpath(p, a.folder).replace("\\", "/"), w, h)
    items.append((label, bg))

# shelf layout
pad, y, x, rowh = 8, pad if (pad := 8) else 0, 8, 0
placed = []
for label, im in items:
    if x + im.width + pad > a.width and x > pad:
        x = pad; y += rowh + 20 + pad; rowh = 0
    placed.append((x, y, label, im))
    x += max(im.width, 150) + pad
    rowh = max(rowh, im.height)
H = y + rowh + 28
sheet = Image.new("RGBA", (a.width, H), (30, 30, 36, 255))
dr = ImageDraw.Draw(sheet)
for x, y, label, im in placed:
    dr.text((x, y), label[-70:], fill=(255, 255, 255, 255))
    sheet.alpha_composite(im, (x, y + 14))
sheet.convert("RGB").save(a.out)
print("wrote", a.out, sheet.size, len(items), "images")
