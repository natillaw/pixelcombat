import os
import glob
import zipfile

def unpack_all():
    dest_base = os.path.join("assets", "packs")
    os.makedirs(dest_base, exist_ok=True)
    
    zip_files = sorted(glob.glob(os.path.join("assets", "*.zip")))
    print(f"Found {len(zip_files)} zip archives to unpack into {dest_base}")
    
    for zpath in zip_files:
        name = os.path.splitext(os.path.basename(zpath))[0]
        out_dir = os.path.join(dest_base, name)
        if os.path.exists(out_dir):
            print(f"Skipping {name}, already unpacked at {out_dir}")
            continue
        print(f"Extracting {name}...")
        os.makedirs(out_dir, exist_ok=True)
        try:
            with zipfile.ZipFile(zpath, 'r') as zf:
                zf.extractall(out_dir)
            print(f"  Successfully extracted {name} ({len(os.listdir(out_dir))} items)")
        except Exception as e:
            print(f"  Error extracting {name}: {e}")

if __name__ == "__main__":
    unpack_all()
