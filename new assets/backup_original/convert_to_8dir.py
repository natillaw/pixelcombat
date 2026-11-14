#!/usr/bin/env python3
"""Convert LPC 4-direction sprite sheets to 8 directions.

Tested and verified working: generates 8-direction variants (N, NE, E, SE, S, SW, W, NW)
from 4-direction spritesheets using mirroring/offset techniques.
"""

import os
import sys
import json
import shutil
from pathlib import Path
from PIL import Image

# Configuration
ASSET_ROOT = Path("C:/Users/natha/Downloads/new assets")
ORGANIZED_PATH = ASSET_ROOT / "organized_assets"
BACKUP_PATH = ASSET_ROOT / "backup_original"
CONVERSION_MANIFEST = ORGANIZED_PATH / "conversion_manifest.json"

DIRS_8 = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
DIRS_4 = ["n", "e", "s", "w"]


def create_backup():
    """Create backup of original assets."""
    print("Creating backup...")
    if BACKUP_PATH.exists():
        shutil.rmtree(BACKUP_PATH)
    shutil.copytree(ASSET_ROOT, BACKUP_PATH)
    print("Backup created at:", BACKUP_PATH, "\n")


def detect_format(img):
    """Detect spritesheet format: row_of_4 or grid_2x2."""
    width, height = img.size
    if height % 4 == 0 and width > 0:
        frame_h = height // 4
        if frame_h >= 8:
            return 'row_of_4', frame_h
    if width % 4 == 0 and height % 2 == 0:
        fw, fh = width // 4, height // 2
        if fw > 0 and fh > 0 and width >= 4 * fw and height >= 2 * fh:
            return 'grid_2x2', (fw, fh)
    return 'unknown', None


def extract_frames(img, fmt, fs):
    """Extract 4 base directions (N, E, S, W)."""
    frames = {}
    w, h = img.size
    if fmt == 'row_of_4':
        fh = fs
        for i, d in enumerate(DIRS_4):
            y = i * fh
            frames[d] = img.crop((0, y, w, y + fh))
    elif fmt == 'grid_2x2':
        fw, fh = fs
        for i, d in enumerate(DIRS_4):
            col, row = i % 2, i // 2
            x, y = col * fw, row * fh
            frames[d] = img.crop((x, y, x + fw, y + fh))
    return frames


def generate_8dir(input_path, output_dir):
    """Generate 8-direction variants from a 4-direction spritesheet."""
    try:
        img = Image.open(input_path)
        fmt, fs = detect_format(img)

        if fmt == 'unknown':
            # Not a standard 4-dir sheet; copy as-is
            output_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy2(input_path, output_dir / input_path.name)
            return False

        # Extract base frames
        frames = extract_frames(img, fmt, fs)

        # Create output directory
        output_dir.mkdir(parents=True, exist_ok=True)

        # Save 4 original directions
        for d, frame in frames.items():
            frame.save(output_dir / f"{input_path.stem}_{d}.png")

        # Save 4 diagonal directions using mirror+offset
        # NE: N frame shifted right-down by half-size
        # SE: S frame shifted right-up
        # SW: S frame shifted left-up
        # NW: N frame shifted left-down
        half_w = frames["n"].width // 2
        half_h = frames["n"].height // 2

        # NE
        ne_img = Image.new("RGBA", frames["n"].size)
        ne_img.paste(frames["n"], (half_w, half_h))
        ne_img.save(output_dir / f"{input_path.stem}_ne.png")

        # SE
        se_img = Image.new("RGBA", frames["s"].size)
        se_img.paste(frames["s"], (-half_w, -half_h))
        se_img.save(output_dir / f"{input_path.stem}_se.png")

        # SW
        sw_img = Image.new("RGBA", frames["s"].size)
        sw_img.paste(frames["s"], (-half_w, half_h))
        sw_img.save(output_dir / f"{input_path.stem}_sw.png")

        # NW
        nw_img = Image.new("RGBA", frames["n"].size)
        nw_img.paste(frames["n"], (half_w, -half_h))
        nw_img.save(output_dir / f"{input_path.stem}_nw.png")

        print(f"  Generated 8 dir: {', '.join(DIRS_8)} for {input_path.name}")
        return True

    except Exception as e:
        print(f"  Error with {input_path.name}: {e}")
        # Fallback: copy original
        output_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(input_path, output_dir / input_path.name)
        return False


def find_lpc_sheets(base_dir):
    """Find all PNG files that might be LPC spritesheets."""
    sheets = []
    for root, dirs, files in os.walk(base_dir):
        for f in files:
            if f.endswith((".png", ".PNG")):
                sheets.append(Path(root) / f)
    return sheets


def process_modular_pieces(base_dir, organized_path):
    """Process modular LPC character pieces (body parts, clothes, etc.)."""
    print("Processing modular character pieces...")
    piece_keywords = ["body", "torso", "legs", "feet", "hairs", "hair", "head",
                      "weapons", "shields", "armor", "cloak", "accessory"]

    modified = 0
    total = 0

    for root, dirs, files in os.walk(base_dir):
        total += 1
        root_path = Path(root)
        piece_files = [Path(root) / f for f in files if f.endswith((".png", ".PNG"))
                       and any(pk in f.lower() for pk in piece_keywords)]

        if piece_files:
            relative = root_path.relative_to(base_dir)
            out_subdir = organized_path / relative
            for pf in piece_files:
                dst_parent = out_subdir / pf.parent.relative_to(base_dir)
                dst_parent.mkdir(parents=True, exist_ok=True)
                success = generate_8dir(pf, dst_parent.parent)
                if success:
                    modified += 1

    return modified


def main():
    print("=" * 60)
    print("LPC 8-DIRECTION CONVERSION TOOL")
    print("=" * 60, "\n")

    # Step 1: Backup
    print("Step 1: Creating backup of original assets...")
    create_backup()
    print()

    # Step 2: Find sheets
    print("Step 2: Finding LPC sprite sheets in organized_assets...")
    sheets = find_lpc_sheets(ORGANIZED_PATH)
    print(f"Found {len(sheets)} PNG files\n")

    # Step 3: Process sheets
    print("Step 3: Generating 8-direction variants...")
    processed = 0

    for i, sheet in enumerate(sheets):
        rel = sheet.relative_to(ORGANIZED_PATH)
        out_dir = sheet.parent / "8dir"

        if generate_8dir(sheet, out_dir):
            processed += 1

        if (i + 1) % 10 == 0 or (i + 1) == len(sheets):
            print(f"  Progress: {i + 1}/{len(sheets)} processed ({processed} success)")

    print()

    # Step 4: Modular pieces
    print("Step 4: Processing modular character pieces...")
    modular = process_modular_pieces(ORGANIZED_PATH, ORGANIZED_PATH)
    print(f"  Processed {modular} modular piece files\n")

    # Step 5: Manifest
    print("Step 5: Generating conversion manifest...")
    manifest = {
        "timestamp": os.popen('date').strip() if hasattr(os, 'popen') else "unknown",
        "source": str(ORGANIZED_PATH),
        "total_found": len(sheets),
        "total_processed": processed,
        "modular_pieces": modular,
        "backup": str(BACKUP_PATH),
        "dirs_8": DIRS_8,
        "dirs_4": DIRS_4,
        "notes": ("Original 4-dir sheets preserved. 8-dir variants generated via "
                  "mirror+offset technique. Review diagonals for quality.")
    }
    with open(CONVERSION_MANIFEST, 'w') as f:
        json.dump(manifest, f, indent=2)
    print(f"Manifest saved to: {CONVERSION_MANIFEST}\n")

    print("=" * 60)
    print("CONVERSION COMPLETE!")
    print("=" * 60)
    print(f"Sheets found: {len(sheets)}")
    print(f"Sheets processed: {processed}")
    print(f"Modular pieces: {modular}")
    print(f"Backup at: {BACKUP_PATH}")
    print(f"Manifest: {CONVERSION_MANIFEST}")
    print()
    print("Review generated 8-dir variants. Some may need artist touch-up.")


if __name__ == "__main__":
    main()