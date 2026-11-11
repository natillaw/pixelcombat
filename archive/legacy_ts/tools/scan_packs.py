import os
import glob

def scan_packs():
    packs_dir = os.path.join("assets", "packs")
    if not os.path.exists(packs_dir):
        print("No assets/packs found.")
        return
    for pack in os.listdir(packs_dir):
        p_path = os.path.join(packs_dir, pack)
        if os.path.isdir(p_path):
            print(f"\n=== Pack: {pack} ===")
            files = glob.glob(os.path.join(p_path, "**", "*.png"), recursive=True)
            print(f"  Total PNGs: {len(files)}")
            for f in files[:10]:
                print(f"    - {os.path.relpath(f, p_path)}")
            if len(files) > 10:
                print(f"    ... and {len(files) - 10} more PNGs.")

if __name__ == "__main__":
    scan_packs()
