"""One-off migration of the UI screens from 1280x720 design pixels to the 640x360 base (D-063).
Halves the numbers of UI-only sizes and positions (custom_minimum_size, control positions/sizes,
container separations and margins) and routes explicit font sizes through UIKit.fpx(). World
coordinates (map, heroes, camera, viewport) are left alone. Idempotent: lines already converted carry
a '# px' marker.  python tools/ui_to_base_pixels.py"""
import re, sys, glob, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = [f for f in glob.glob(os.path.join(ROOT, "scripts", "ui", "*.gd")) if not f.endswith("ui_kit.gd")]
FILES.append(os.path.join(ROOT, "scripts", "sandbox", "sandbox_screen.gd"))
WORLD = ("th.", "map.", "world", "_viewport", "Vector2i", "camera", "hero_screen", "center_of", "relic", "_escort", "_mark")
UI_PATTERNS = ("custom_minimum_size = Vector2(", ".position = Vector2(", ".position += Vector2(", "position += Vector2(",
               ".size = Vector2(", "position = Vector2(")


def halve(m):
    def h(x):
        x = x.strip()
        try:
            v = float(x)
        except ValueError:
            return x
        return str(int(round(v / 2.0)))
    return "Vector2(" + ", ".join(h(p) for p in m.group(1).split(",")) + ")"


def convert(line):
    if "# px" in line:
        return line
    new = line
    new = re.sub(r'add_theme_font_size_override\("font_size", (\d+)\)', r'add_theme_font_size_override("font_size", UIKit.fpx(\1))', new)
    if any(p in new for p in UI_PATTERNS) and not any(w in new for w in WORLD):
        new = re.sub(r'Vector2\(([-\d., ]+)\)', halve, new)
    m = re.search(r'add_theme_constant_override\("(separation|margin_\w+|h_separation|v_separation)", (\d+)\)', new)
    if m:
        new = new.replace(m.group(0), 'add_theme_constant_override("%s", %d)' % (m.group(1), max(1, round(int(m.group(2)) / 2))))
    if new != line:
        new = new.rstrip("\n") + "  # px\n" if not new.rstrip().endswith(")") or "#" not in new else new.rstrip("\n") + "\n"
    return new


changed = 0
for f in FILES:
    lines = open(f, encoding="utf-8", newline="").readlines()
    out = [convert(l) for l in lines]
    changed += sum(1 for a, b in zip(lines, out) if a != b)
    open(f, "w", encoding="utf-8", newline="").writelines(out)
print("lines changed:", changed)
