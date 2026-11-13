"""Libros de skill del Guerrero: las skills de mundo (Ground Stomp, Counterstrike, Whirlwind y las nuevas Second Wind,
Throwing Axe y Execute) se consiguen en libros que se encuentran en el mundo (jefes, elite y, mas adelante,
misiones secretas y eventos), no con la instructora. Cada libro es un consumible (kind "book", effect.learn =
id de la skill) y al leerlo se aprende la skill y se puede cambiar por una de las tres que llevas (Q, E, R).
Tambien copia los iconos de skill desde el pack 496 RPG icons (fondo blanco -> transparente, x2).
Se puede volver a ejecutar sin perder nada.
"""
import io
import json
import os
import zipfile

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
PACK = r"C:\Users\natha\Downloads\new assets\496_RPG_icons.zip"


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf8") as f:
        return json.load(f)


def save(rel, data):
    with open(os.path.join(ROOT, rel), "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")


skills_doc = load("data/skills/warrior.json")
by_id = {s["id"]: s for s in skills_doc["skills"]}


def skill(id, name, role, desc, label, shape, unlock, **kw):
    base = {"id": id, "name": name, "slot": "S", "kind": "skill", "role": role, "description": desc, "hud_label": label,
            "shape": shape, "windup": 0.22, "active": 0.12, "recovery": 0.3, "cooldown": 8, "cost": 20, "damage_mult": 1.0,
            "resource_gain": 4, "resource_cap": 16, "max_targets": 0, "move": {"windup": 0.3, "active": 0.1, "recovery": 0.35},
            "anim": "slash", "implemented": True, "ult_gain": 4, "ult_cap": 12, "unlock_level": unlock, "class": "warrior",
            "damage_type": "physical", "world": True, "source": "book"}
    base.update(kw)
    return base


new_skills = [
    skill("throwing_axe", "Throwing Axe", "Dano / a distancia", "Lanza un hacha que hace sangrar al impactar: una opcion para quien no puede acercarse.", "AXE", "projectile", 5,
          cooldown=6, cost=15, damage_mult=1.5, windup=0.25, anim="thrust",
          projectile={"speed": 330, "range": 320, "radius": 8, "count": 1, "spread": 0, "pierce": 0, "visual": "knife"},
          on_hit=[{"id": "bleed", "duration": 4, "strength": 5}]),
    skill("execute", "Execute", "Dano / remate", "Golpe brutal que hace el doble de dano a los enemigos con menos del 30 % de vida.", "EXEC", "cone", 7,
          range=72, arc=70, cooldown=8, cost=25, damage_mult=1.6, windup=0.35, execute={"below": 0.3, "mult": 2.0}),
    skill("second_wind", "Second Wind", "Mejora / curacion", "Recupera el 25 % de la vida maxima de golpe (cooldown largo).", "WIND", "self", 4,
          cooldown=30, cost=25, damage_mult=0.1, windup=0.4, active=0.3, recovery=0.3, resource_gain=0, resource_cap=0, ult_gain=0, ult_cap=0,
          self_heal_pct=0.25, anim="spellcast", move={"windup": 0.5, "active": 0.5, "recovery": 0.8}),
]
for new in new_skills:
    if new["id"] in by_id:
        by_id[new["id"]].update(new)
    else:
        skills_doc["skills"].append(new)
# Todas las skills de mundo vigentes se consiguen en libros
for sid in ["ground_stomp", "iron_counter", "whirlwind"]:
    by_id[sid]["source"] = "book"
save("data/skills/warrior.json", skills_doc)

# --- libros como consumibles ---
consumables = load("data/consumables.json")
have = {c["id"] for c in consumables["consumables"]}
books = [("ground_stomp", "Pisoton", "Ground Stomp"), ("iron_counter", "Contragolpe", "Counterstrike"), ("whirlwind", "Torbellino", "Whirlwind"),
         ("throwing_axe", "Hacha arrojadiza", "Throwing Axe"), ("execute", "Remate", "Execute"), ("second_wind", "Segundo aliento", "Second Wind"), ("rend", "Desgarro", "Rend")]
for skill_id, spanish, english in books:
    book_id = "book_" + skill_id
    if book_id in have:
        continue
    consumables["consumables"].append({
        "id": book_id, "name": "Libro: %s" % spanish, "kind": "book",
        "description": "Ensena la habilidad %s del Guerrero. Al leerlo la aprendes y puedes cambiarla por una de tus skills Q, E o R en el libro de skills (Tab)." % english,
        "effect": {"learn": skill_id}, "price": 0, "value": 60, "icon": "skill_tome"})
save("data/consumables.json", consumables)

# --- iconos de skill (pack 496 RPG icons: fondo blanco -> transparente; se amplian x2) ---
picks = {"rend": "S_Sword01", "war_cry": "S_Buff09", "shockwave": "S_Earth06", "whirlwind": "S_Physic01",
         "throwing_axe": "S_Physic02", "execute": "S_Fire05", "second_wind": "S_Holy01"}
out_dir = os.path.join(ROOT, "assets", "pixel", "icons", "skills")
with zipfile.ZipFile(PACK) as zf:
    for skill_id, name in picks.items():
        img = Image.open(io.BytesIO(zf.read(name + ".png"))).convert("RGBA")
        px = img.load()
        w, h = img.size
        stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
        seen = set(stack)
        while stack:
            x, y = stack.pop()
            r, g, b, a = px[x, y]
            if a == 0 or (r > 235 and g > 235 and b > 235):
                px[x, y] = (0, 0, 0, 0)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
        img = img.resize((w * 2, h * 2), Image.NEAREST)
        img.save(os.path.join(out_dir, skill_id + ".png"))
with open(os.path.join(out_dir, "CREDITS.txt"), "a", encoding="utf8") as f:
    f.write("- Iconos de Rend, War Cry, Shockwave, Whirlwind, Throwing Axe, Execute y Second Wind: pack 496 RPG icons (fondo blanco eliminado, x2). REVISAR la licencia antes de publicar el repo.\n")

fx = load("data/fx.json")
fx["skills"]["throwing_axe"] = {"cast": [{"id": "wind/wind-gust", "scale": 0.6, "ahead": 0.3}], "hit": "impacts/blood-splat"}
fx["skills"]["execute"] = {"cast": [{"id": "melee/axe-smear", "scale": 1.4, "ahead": 0.55}], "hit": "impacts/crit-hit", "crit": "impacts/crit-hit"}
fx["skills"]["second_wind"] = {"cast": [{"id": "holy/regen-aura", "scale": 1.0, "at": "self", "seconds": 1.2}]}
save("data/fx.json", fx)
print("libros ok")
