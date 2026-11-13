"""Reescribe el kit del Mago segun el diseno aprobado: basico M2 con coste de mana y chispazo sin mana, Blink con coste,
Q Fireball (nv 2), E Frost Nova (nv 4), R Arcane Orb (nv 8), F Cataclysm (nv 6), pasiva Arcane Surge (nv 8) y libros:
Ice Lance, Arcane Explosion, Meteor y Mana Shield. Arcane Overload queda retirada. Se puede volver a ejecutar."""
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


doc = load("data/skills/mage.json")
by_id = {s["id"]: s for s in doc["skills"]}


def skill(id, name, role, desc, label, shape, unlock, book=False, **kw):
    base = {"id": id, "name": name, "slot": "S", "kind": "skill", "role": role, "description": desc, "hud_label": label,
            "shape": shape, "windup": 0.25, "active": 0.05, "recovery": 0.3, "cooldown": 8, "cost": 25, "damage_mult": 1.0,
            "resource_gain": 0, "resource_cap": 0, "max_targets": 0, "move": {"windup": 0.4, "active": 0.2, "recovery": 0.5},
            "anim": "spellcast", "implemented": True, "ult_gain": 4, "ult_cap": 12, "unlock_level": unlock, "class": "mage",
            "damage_type": "magic"}
    if book:
        base["world"] = True
        base["source"] = "book"
    base.update(kw)
    return base


# --- Basicos ---
bolt = by_id["arcane_bolt"]
bolt["description"] = "Basico (clic derecho). Proyectil debil: cuesta 3 de mana y tiene una pausa corta entre disparos. Sin mana sale un chispazo al 25 %."
bolt["cost"] = 3
bolt["cooldown"] = 0.3
bolt["damage_mult"] = 1.0
bolt["spark_mult"] = 0.25
bolt.pop("charges", None)
blast = by_id["charged_arcane_blast"]
blast["description"] = "Basico cargado (mantener clic derecho): hasta 1,2 s cargando; mucho dano y, con la carga completa, ralentiza. Cuesta 12 de mana."
blast["cost"] = 12
blast["cooldown"] = 2.5
blast["spark_mult"] = 0.25
blast["hold"] = {"max": 1.2, "damage_bonus": 1.0, "range_bonus": 0.3, "full_on_hit": [{"id": "slow", "duration": 2.0, "strength": 0.4}]}

# --- Q, E, R ---
fb = by_id["fireball"]
fb.update({"unlock_level": 2, "description": "Bola de fuego con explosion pequena; deja al enemigo ardiendo 3 s.", "cooldown": 6,
           "on_hit": [{"id": "burn", "duration": 3.0, "strength": 5.0}]})
fb.pop("world", None)
nova = by_id["frost_nova"]
nova.update({"unlock_level": 4, "description": "Explosion helada a tu alrededor: casi inmoviliza 1,5 s y ralentiza despues. Los jefes solo se ralentizan a medias.",
             "on_hit": [{"id": "slow", "duration": 3.5, "strength": 0.9}]})
orb = skill("arcane_orb", "Arcane Orb", "Dano / zona", "Orbe lento que atraviesa a los enemigos y los ralentiza.", "ORB", "projectile", 8,
            cost=30, cooldown=10, windup=0.3, damage_mult=1.4,
            projectile={"speed": 150, "range": 300, "radius": 14, "count": 1, "spread": 0, "pierce": 6, "visual": "orb"},
            on_hit=[{"id": "slow", "duration": 2.0, "strength": 0.3}])

# --- Libros ---
lance = by_id["ice_lance"]
lance.update({"unlock_level": 3, "world": True, "source": "book", "bonus_vs": {"status": "slow", "mult": 2.0},
              "description": "Lanza de hielo que atraviesa: hace el doble de dano contra enemigos ralentizados."})
expl = by_id["arcane_explosion"]
expl.update({"unlock_level": 5, "world": True, "source": "book", "description": "Explosion arcana a tu alrededor, de coste alto."})
meteor = skill("meteor", "Meteor", "Dano / area", "Marca una zona y, tras 1 s, cae un meteoro que quema.", "METEOR", "circle", 7, book=True,
               cost=40, cooldown=16, windup=1.0, range=70, damage_mult=3.0, anchor="aim_point", point_distance=190, telegraph=True,
               on_hit=[{"id": "burn", "duration": 3.0, "strength": 6.0}])
mshield = skill("mana_shield", "Mana Shield", "Defensa", "6 s: el 60 % del dano que recibes se paga con mana.", "SHIELD", "self", 9, book=True,
                cost=20, cooldown=20, windup=0.2, damage_mult=0.1, ult_gain=0, ult_cap=0,
                self_status={"id": "manashield", "duration": 6.0, "strength": 0.6})

# --- Retirada ---
by_id["arcane_overload"].update({"retired": True, "world": True, "legacy_special": True})

for new in [orb, meteor, mshield]:
    if new["id"] in by_id:
        by_id[new["id"]].update(new)
    else:
        doc["skills"].append(new)
save("data/skills/mage.json", doc)

cls = load("data/classes/mage.json")
cls["default_loadout"] = {"M1": "arcane_bolt", "M2": "charged_arcane_blast", "S1": "fireball", "S2": "frost_nova", "S3": "arcane_orb", "ULTIMATE": "cataclysm"}
cls["passive"] = "arcane_surge"
cls["passive_level"] = 8
cls["slot_gates"] = True
cls["resource"]["regen_per_second"] = 7
cls["resource"]["regen_out_of_combat"] = 12
cls["mobility"]["cost"] = 8
cls["mobility"]["description"] = "Teletransporte corto hacia donde te mueves (o al cursor). Cuesta 8 de mana."
cls["planned"] = []
cls["stats"]["armor"] = 40
cls["stats"]["stamina"] = 14
cls["ult_charge"]["_doc"] = "Lanza hechizos (mas cuanto mas mana gastas) y remata; los golpes sueltos no cargan."
save("data/classes/mage.json", cls)

consumables = load("data/consumables.json")
have = {c["id"] for c in consumables["consumables"]}
for skill_id, spanish, english in [("ice_lance", "Lanza de hielo", "Ice Lance"), ("arcane_explosion", "Explosion arcana", "Arcane Explosion"),
                                   ("meteor", "Meteoro", "Meteor"), ("mana_shield", "Escudo de mana", "Mana Shield")]:
    book_id = "book_" + skill_id
    if book_id not in have:
        consumables["consumables"].append({
            "id": book_id, "name": "Libro: %s" % spanish, "kind": "book",
            "description": "Ensena la habilidad %s del Mago. Al leerlo la aprendes y puedes cambiarla por una de tus skills Q, E o R en el libro de skills (Tab)." % english,
            "effect": {"learn": skill_id}, "price": 0, "value": 60, "icon": "skill_tome"})
save("data/consumables.json", consumables)

st = load("data/statuses.json")
have = {s["id"] for s in st["statuses"]}
for entry in [
    {"id": "burn", "name": "Burn", "kind": "damage", "description": "Quema: dano por segundo (strength).", "max_duration": 6.0, "tick": 0.5, "immune_after": 0.0, "color": [1.0, 0.5, 0.15, 1.0]},
    {"id": "surge", "name": "Arcane Surge", "kind": "buff", "description": "El siguiente basico sale gratis y +50 %.", "max_duration": 8.0, "max_strength": 1.0, "immune_after": 0.0, "color": [0.6, 0.5, 1.0, 1.0]},
    {"id": "manashield", "name": "Mana Shield", "kind": "buff", "description": "Parte del dano se paga con mana (strength = fraccion).", "max_duration": 8.0, "max_strength": 1.0, "immune_after": 0.0, "color": [0.4, 0.6, 1.0, 1.0]},
]:
    if entry["id"] not in have:
        st["statuses"].append(entry)
save("data/statuses.json", st)

fx = load("data/fx.json")
fx["events"]["status_burn"] = [{"id": "explosions/fire-nova", "scale": 0.8, "up": 8}]
fx["events"]["status_surge"] = [{"id": "arcane/teleport-in", "scale": 0.6, "up": 8}]
fx["events"]["status_manashield"] = [{"id": "status/power-up-aura", "scale": 0.7, "up": 4}]
fx["skills"]["arcane_orb"] = {"cast": [{"id": "arcane/rune-trap", "scale": 0.7, "at": "self"}], "hit": "impacts/hit-spark"}
fx["skills"]["meteor"] = {"cast": [{"id": "arcane/rune-trap", "scale": 1.0, "at": "self"}], "hit": "impacts/shockwave-ring"}
fx["skills"]["mana_shield"] = {"cast": [{"id": "status/power-up-aura", "scale": 1.0, "at": "self", "seconds": 1.0}]}
save("data/fx.json", fx)

picks = {"arcane_orb": "S_Magic05", "meteor": "S_Fire06", "mana_shield": "S_Magic09", "charge": "S_Sword03"}
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
        img.resize((w * 2, h * 2), Image.NEAREST).save(os.path.join(out_dir, skill_id + ".png"))
print("mago ok:", len(doc["skills"]), "skills")
