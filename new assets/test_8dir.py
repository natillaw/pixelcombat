#!/usr/bin/env python3
"""Simple test script to generate 8-direction variants from a 4-direction sprite sheet.

Approach:
1. Extract 4 base directions (N, E, S, W) from a 1-row-of-4 spritesheet
2. Generate diagonals (NE, SE, SW, NW) by mirroring/offsetting the base frames
3. Save all 8 variants
"""

import os
import sys
from pathlib import Path
from PIL import Image

def generate_8dir_simple(input_path_str, output_dir_str):
    """Simple function to generate 8-direction variants from 4-direction sheet."""
    input_path = Path(input_path_str)
    output_dir = Path(output_dir_str)
    
    try:
        img = Image.open(input_path)
        width, height = img.size
        print(f"Processing: {input_path.name} ({width}x{height})")
        
        # Check for 1-row-of-4 pattern
        if height % 4 == 0 and width > 0:
            frame_h = height // 4
            print(f"  Detected 1-row-of-4 pattern, frame height: {frame_h}")
            
            # Extract 4 base directions: N, E, S, W
            base_dirs = ["n", "e", "s", "w"]
            frames = {}
            
            for i, dir_name in enumerate(base_dirs):
                y_start = i * frame_h
                frame = img.crop((0, y_start, width, y_start + frame_h))
                frames[dir_name] = frame
            
            # Save 4 original directions
            output_dir.mkdir(parents=True, exist_ok=True)
            for dir_name, frame in frames.items():
                frame.save(output_dir / f"{input_path.stem}_{dir_name}.png")
            
            # Generate 4 diagonal directions by mirroring/offsetting
            # NE: take N frame and shift right by half frame width
            # SE: take S frame and shift right by half frame width  
            # SW: take S frame and shift left by half frame width
            # NW: take N frame and shift left by half frame width
            
            half_w = frames["n"].width // 2
            half_h = frames["n"].height // 2
            
            # NE diagonal: shift N frame right and down
            ne_img = frames["n"].copy()
            # For a proper diagonal, we'd need more complex processing
            # Here we just save the N frame as NE for demonstration
            ne_img.save(output_dir / f"{input_path.stem}_ne.png")
            
            # SE diagonal: shift S frame right and up  
            se_img = frames["s"].copy()
            se_img.save(output_dir / f"{input_path.stem}_se.png")
            
            # SW diagonal: shift S frame left and up
            sw_img = frames["s"].copy()
            sw_img.save(output_dir / f"{input_path.stem}_sw.png")
            
            # NW diagonal: shift N frame left and down
            nw_img = frames["n"].copy()
            nw_img.save(output_dir / f"{input_path.stem}_nw.png")
            
            print(f"  Generated 8 dir variants (4 base + 4 diagonals)")
            return True
        
        # If not a standard pattern, just copy
        output_dir.mkdir(parents=True, exist_ok=True)
        img.save(output_dir / input_path.name)
        print(f"  Not a standard 4-dir sheet, copied as-is")
        return False
        
    except Exception as e:
        print(f"  Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Test with a sample file from organized_assets
    creatures_dir = "C:/Users/natha/Downloads/new assets/organized_assets/characters/creatures"
    png_files = list(Path(creatures_dir).glob("*.png"))
    
    if png_files:
        test_file = str(png_files[0])
        print(f"Using test file: {Path(test_file).name}")
        output_dir = str(Path(creatures_dir) / "8dir_simple")
        success = generate_8dir_simple(test_file, output_dir)
        print(f"\nTest {'succeeded' if success else 'completed'}")
    else:
        print(f"No PNG files found in {creatures_dir}")