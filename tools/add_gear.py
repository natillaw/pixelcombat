"""Anade a data/items.json y data/recipes.json el equipo nuevo (variedad de drops y de crafteo) y las
tablas de botin propias de los bandidos (data/enemies/bandits.json: loot.items = [{id, chance}]).
Solo se usan piezas LPC corrientes; las vistosas se reservan para pisos altos."""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf8") as f:
        return json.load(f)


def save(rel, data):
    with open(os.path.join(ROOT, rel), "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")


def look(slot, piece, variants):
    return {"slot": slot, "piece": piece, "variants": variants}


NEW_ITEMS = [
    # Armas (las fabrica el artesano y/o las sueltan los bandidos)
    {"id": "militia_mace", "name": "Maza de milicia", "slot": "weapon", "classes": ["warrior"],
     "stats": {"weapon_min": 3.5, "weapon_max": 5.5, "strength": 2.5}, "value": 22, "look": look("main_hand", "weapon_mace", ["default"])},
    {"id": "hunter_crossbow", "name": "Ballesta de cazador", "slot": "weapon", "classes": ["archer"],
     "stats": {"weapon_min": 3, "weapon_max": 4.5, "agility": 2.5}, "value": 22, "look": look("main_hand", "weapon_crossbow", ["default"])},
    {"id": "apprentice_wand", "name": "Varita de aprendiz", "slot": "weapon", "classes": ["mage"],
     "stats": {"weapon_min": 2, "weapon_max": 3.5, "intellect": 3}, "value": 22, "look": look("main_hand", "weapon_wand", ["default"])},
    # Ropa del Cuervo (solo por botin)
    {"id": "crow_bandana", "name": "Pañuelo del Cuervo", "slot": "head", "stats": {"armor": 3, "agility": 1, "stamina": 1}, "value": 14,
     "look": look("head", "bandana", ["maroon"])},
    {"id": "crow_hood", "name": "Capucha del Cuervo", "slot": "head", "stats": {"armor": 2, "intellect": 1, "agility": 1}, "value": 14,
     "look": look("head", "hood", ["maroon"])},
    {"id": "crow_vest", "name": "Jubón del Cuervo", "slot": "chest", "stats": {"armor": 6, "strength": 1.5, "stamina": 1.5}, "value": 18,
     "look": look("chest", "shirt_sleeveless", ["charcoal"])},
    {"id": "crow_breeches", "name": "Calzas del Cuervo", "slot": "legs", "stats": {"armor": 4, "agility": 1.5, "stamina": 1}, "value": 14,
     "look": look("legs", "pants", ["charcoal"])},
    {"id": "crow_boots", "name": "Botas del Cuervo", "slot": "feet", "stats": {"armor": 3, "agility": 1.5, "stamina": 1}, "value": 14,
     "look": look("feet", "boots_basic", ["black"])},
    {"id": "crow_signet", "name": "Sello del Cuervo", "slot": "ring", "stats": {"crit_chance": 0.015, "attack_power_bonus": 2}, "value": 20},
    # Ropa y armas de oficio (se fabrican)
    {"id": "plain_tunic", "name": "Tunica sencilla", "slot": "chest", "stats": {"armor": 5, "stamina": 2, "strength": 1}, "value": 14,
     "look": look("chest", "shirt_longsleeve", ["tan", "navy"])},
    {"id": "traveler_breeches", "name": "Calzas de viajero", "slot": "legs", "stats": {"armor": 5, "stamina": 1.5, "agility": 1}, "value": 12,
     "look": look("legs", "pants", ["brown", "charcoal"])},
    # Unicos de los jefes (rompen la monotonia sin subir el techo de balance: mismos stats base que un item normal x rareza)
    {"id": "deserter_medal", "name": "Medalla del Desertor", "slot": "ring", "stats": {"armor": 3, "stamina": 2, "attack_power_bonus": 2}, "value": 70},
    {"id": "deserter_coat", "name": "Capote del Desertor", "slot": "chest", "stats": {"armor": 9, "stamina": 2.5, "strength": 1.5, "agility": 1}, "value": 70,
     "look": look("chest", "shirt_longsleeve", ["navy", "tan"])},
    {"id": "bone_dagger", "name": "Daga de hueso", "slot": "weapon", "classes": ["rogue"],
     "stats": {"weapon_min": 2.5, "weapon_max": 4.2, "agility": 2.5}, "value": 20, "look": look("main_hand", "weapon_dagger", ["default"])},
    {"id": "rask_cleaver", "name": "Tajador de Rask", "slot": "weapon", "classes": ["warrior"],
     "stats": {"weapon_min": 4.5, "weapon_max": 6.5, "strength": 3}, "value": 60, "look": look("main_hand", "weapon_mace", ["default"])},
    {"id": "veyra_wand", "name": "Varita de Veyra", "slot": "weapon", "classes": ["mage"],
     "stats": {"weapon_min": 3, "weapon_max": 4.5, "intellect": 4}, "value": 60, "look": look("main_hand", "weapon_wand", ["default"])},
    {"id": "blackhand_signet", "name": "Sello de Mano Negra", "slot": "ring",
     "stats": {"crit_chance": 0.02, "attack_power_bonus": 3, "spell_power_bonus": 3}, "value": 80},
    # Equipo de materiales de animales (seda, quitina, esencia, cuero): cada material tiene su uso
    {"id": "silk_hood", "name": "Capucha de seda", "slot": "head", "stats": {"armor": 2.5, "intellect": 2, "stamina": 0.5}, "value": 16,
     "look": look("head", "hood", ["forest", "brown"])},
    {"id": "silk_robe", "name": "Tunica de seda", "slot": "chest", "stats": {"armor": 5, "intellect": 3, "stamina": 1}, "value": 20,
     "look": look("chest", "shirt_longsleeve", ["navy", "tan"])},
    {"id": "chitin_vest", "name": "Peto de quitina", "slot": "chest", "stats": {"armor": 10, "stamina": 2.5}, "value": 20,
     "look": look("chest", "shirt_sleeveless", ["charcoal"])},
    {"id": "chitin_greaves", "name": "Grebas de quitina", "slot": "legs", "stats": {"armor": 7, "stamina": 1.5}, "value": 16,
     "look": look("legs", "pants", ["charcoal", "brown"])},
    {"id": "slime_boots", "name": "Botas de limo", "slot": "feet", "stats": {"armor": 2, "agility": 2, "stamina": 1}, "value": 14,
     "look": look("feet", "boots_basic", ["leather", "black"])},
    {"id": "wisp_ring", "name": "Anillo de fuego fatuo", "slot": "ring", "stats": {"spell_power_bonus": 4, "intellect": 1}, "value": 18},
]

NEW_RECIPES = [
    {"id": "sew_silk_hood", "station": "tailor", "item": "silk_hood", "cost": {"silk": 3, "herb": 1}, "gold": 12, "quality_bonus": 1.0},
    {"id": "sew_silk_robe", "station": "tailor", "item": "silk_robe", "cost": {"silk": 5, "hide": 1}, "gold": 16, "quality_bonus": 1.0},
    {"id": "sew_chitin_vest", "station": "tailor", "item": "chitin_vest", "cost": {"chitin": 5, "hide": 2}, "gold": 16, "quality_bonus": 1.0},
    {"id": "forge_chitin_greaves", "station": "blacksmith", "item": "chitin_greaves", "cost": {"chitin": 4, "ore": 1}, "gold": 14, "quality_bonus": 1.0},
    {"id": "sew_slime_boots", "station": "tailor", "item": "slime_boots", "cost": {"essence": 3, "hide": 2}, "gold": 12, "quality_bonus": 1.0},
    {"id": "brew_wisp_ring", "station": "alchemist", "item": "wisp_ring", "cost": {"essence": 4, "herb": 1}, "gold": 16, "quality_bonus": 1.0},
    {"id": "forge_bone_dagger", "station": "blacksmith", "item": "bone_dagger", "cost": {"chitin": 3, "ore": 2}, "gold": 18, "quality_bonus": 1.0},
    {"id": "forge_militia_mace", "station": "blacksmith", "item": "militia_mace", "cost": {"ore": 6, "wood": 2}, "gold": 20, "quality_bonus": 1.0},
    {"id": "carve_hunter_crossbow", "station": "carpenter", "item": "hunter_crossbow", "cost": {"wood": 6, "ore": 2}, "gold": 22, "quality_bonus": 1.0},
    {"id": "carve_apprentice_wand", "station": "carpenter", "item": "apprentice_wand", "cost": {"wood": 3, "essence": 3}, "gold": 22, "quality_bonus": 1.0},
    {"id": "sew_plain_tunic", "station": "tailor", "item": "plain_tunic", "cost": {"hide": 4, "herb": 1}, "gold": 12, "quality_bonus": 1.0},
    {"id": "sew_traveler_breeches", "station": "tailor", "item": "traveler_breeches", "cost": {"hide": 3, "herb": 1}, "gold": 10, "quality_bonus": 1.0},
]

# id de enemigo -> [(item, probabilidad)] ademas de su botin generico
DROPS = {
    "bandit_thug": [("militia_mace", 0.10), ("crow_bandana", 0.10), ("crow_vest", 0.08), ("crow_boots", 0.06)],
    "bandit_swordsman": [("crow_bandana", 0.10), ("crow_breeches", 0.10), ("crow_boots", 0.08), ("plain_tunic", 0.06)],
    "bandit_archer": [("hunter_crossbow", 0.10), ("crow_hood", 0.10), ("crow_boots", 0.08), ("crow_breeches", 0.06)],
    "bandit_hexer": [("apprentice_wand", 0.10), ("crow_hood", 0.10), ("crow_signet", 0.05), ("plain_tunic", 0.06)],
    "bandit_cutthroat": [("crow_hood", 0.08), ("crow_vest", 0.10), ("crow_signet", 0.06), ("crow_boots", 0.08)],
    "bandit_shieldman": [("militia_mace", 0.08), ("crow_bandana", 0.10), ("crow_vest", 0.10), ("crow_breeches", 0.08)],
    "crow_standard": [("crow_bandana", 0.12), ("crow_vest", 0.08), ("crow_signet", 0.06)],
    "bandit_deserter": [("deserter_medal", 0.6), ("deserter_coat", 0.5), ("crow_signet", 0.3), ("crow_vest", 0.3)],
    "bandit_rask": [("rask_cleaver", 0.45), ("crow_vest", 0.30), ("crow_signet", 0.20)],
    "bandit_veyra": [("veyra_wand", 0.45), ("crow_hood", 0.30), ("crow_signet", 0.20)],
    "bandit_garrick": [("blackhand_signet", 0.55), ("rask_cleaver", 0.15), ("veyra_wand", 0.15), ("crow_signet", 0.30), ("crow_bandana", 0.25)],
}

items = load("data/items.json")
have = {i["id"] for i in items["items"]}
items["items"] += [i for i in NEW_ITEMS if i["id"] not in have]
save("data/items.json", items)

recipes = load("data/recipes.json")
have = {r["id"] for r in recipes["recipes"]}
recipes["recipes"] += [r for r in NEW_RECIPES if r["id"] not in have]
save("data/recipes.json", recipes)

bandits = load("data/enemies/bandits.json")
# Tomos de habilidad: segunda fuente de skills de mundo (la primera es la instructora del Gremio).
TOMES = {"bandit_rask": 0.3, "bandit_veyra": 0.3, "bandit_deserter": 0.6, "bandit_garrick": 1.0}
for e in bandits["enemies"]:
    e.setdefault("loot", {})["items"] = [{"id": i, "chance": c} for i, c in DROPS[e["id"]]]
    if e["id"] in TOMES:
        e["loot"]["consumables"] = [{"id": "skill_tome", "chance": TOMES[e["id"]]}]
save("data/enemies/bandits.json", bandits)
print(len(items["items"]), "items,", len(recipes["recipes"]), "recetas")

# Materiales nuevos (cuero y quitina ya existian)
mats = load("data/materials.json")
have = {k["id"] for k in mats["kinds"]}
NEW_KINDS = [
    {"id": "silk", "name": "Seda", "source": "monster", "names": ["Seda de arana", "Seda reforzada", "Seda de cienaga", "Seda de mina", "Seda espectral", "Seda de escarcha", "Seda abisal", "Seda lunar", "Seda de ceniza", "Seda estelar"]},
    {"id": "essence", "name": "Esencia", "source": "monster", "names": ["Esencia de limo", "Esencia fatua", "Esencia de bruma", "Esencia de cripta", "Esencia espectral", "Esencia carmesi", "Esencia abisal", "Esencia de aurora", "Esencia de ceniza", "Esencia astral"]},
]
mats["kinds"] += [k for k in NEW_KINDS if k["id"] not in have]
save("data/materials.json", mats)

# Las bestias: animales sin lore; cada una suelta sus materiales de animal
BEASTS = {"slime": {"essence": 0.7}, "bat": {"hide": 0.8}, "spider": {"silk": 0.8, "chitin": 0.35},
          "beetle": {"chitin": 1.0, "hide": 0.3}, "wisp": {"essence": 0.9}, "hornet": {"chitin": 0.7, "silk": 0.3}}
t1 = load("data/enemies/tier1.json")
for e in t1["enemies"]:
    if e["id"] in BEASTS:
        e["materials"] = BEASTS[e["id"]]
save("data/enemies/tier1.json", t1)
