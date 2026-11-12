"""Genera data/enemies/bandits.json (los bandidos del Cuervo, tier 1).
   python tools/gen_bandits.py   (los numeros se ajustan aqui y se vuelve a generar)"""
import json
import os


def look(body="male", skin="light", eyes="brown", hair="hair_plain", hc="black", beard=""):
    return {"body": body, "skin": skin, "eyes": eyes, "head": "head_human_" + body, "hair": hair, "hair_color": hc, "beard": beard}


def atk(id, shape, rng=None, windup=0.7, active=0.1, recovery=0.6, cd=2.0, mult=1.0, trig=None, anim="slash", weight=1, **kw):
    a = {"id": id, "shape": shape, "windup": windup, "active": active, "recovery": recovery, "cooldown": cd,
         "damage_mult": mult, "trigger_range": trig or (rng or 60) - 6, "weight": weight, "anim": anim}
    if shape != "projectile":
        a["range"] = rng
    a.update(kw)
    return a


def proj(speed, rng, radius, count, spread, visual="stinger"):
    return {"speed": speed, "range": rng, "radius": radius, "count": count, "spread": spread, "pierce": 0, "visual": visual}


def en(id, name, role, desc, hp, speed, radius, dmg, armor, xp, aggro, equip, attacks, scale=1.0, keep=None,
       loot=None, mats=None, lk=None, boss=False, phases=None, resist=None, respawn=10, leash=1.6):
    e = {"id": id, "name": name, "tier": 1, "role": role, "description": desc,
         "stats": {"health": hp, "speed": speed, "radius": radius, "damage": dmg, "armor": armor, "xp": xp},
         "ai": {"aggro_range": aggro, "leash": leash}, "respawn_seconds": respawn,
         "sprite": {"lpc": {"look": lk or look(), "equipment": equip}, "scale": scale}, "attacks": attacks}
    if keep:
        e["ai"]["keep_distance"] = keep
    if boss:
        e["boss"] = True
    if phases:
        e["phases"] = phases
    if resist:
        e["resist"] = resist
    if loot:
        e["loot"] = loot
    if mats:
        e["materials"] = mats
    return e


M = "maroon"


def L(piece, variant):
    return [piece, variant]


enemies = [
    en("bandit_thug", "Bandit Thug", "Maton de maza",
       "Un bruto del Cuervo con una maza. Golpe alto con aviso largo y, si te alejas, una embestida de hombro corta.",
       150, 72, 13, 16, 10, 34, 210,
       {"chest": L("shirt_sleeveless", "charcoal"), "legs": L("pants", "brown"), "feet": L("boots_basic", "leather"),
        "head": L("bandana", M), "main_hand": L("weapon_mace", "default")},
       [atk("smash", "cone", 54, 0.8, 0.1, 0.7, 1.6, 1.0, anim="slash", arc=110, on_hit=[{"id": "stun", "duration": 0.3}]),
        atk("shoulder", "line", 110, 0.6, 0.25, 0.8, 4.0, 0.9, trig=120, anim="thrust", width=28, dash_distance=100)],
       lk=look(skin="olive", hair="hair_buzzcut", hc="dark_brown", beard="beard_trimmed"),
       loot={"chance": 0.3, "slots": ["weapon", "chest", "head"]}, mats={"hide": 0.2}),
    en("bandit_swordsman", "Bandit Swordsman", "Espadachin",
       "Rapido con la espada: tajo en arco y, desde media distancia, una estocada con salto hacia delante.",
       125, 92, 12, 15, 8, 34, 230,
       {"chest": L("shirt_longsleeve", "tan"), "legs": L("pants", "charcoal"), "feet": L("boots_basic", "black"),
        "head": L("bandana", M), "main_hand": L("weapon_arming", "default")},
       [atk("slash", "cone", 50, 0.55, 0.1, 0.55, 1.3, 1.0, anim="slash", arc=90),
        atk("lunge", "line", 120, 0.65, 0.2, 0.8, 3.5, 1.1, trig=130, anim="thrust", width=22, dash_distance=105)],
       lk=look(skin="light", hair="hair_plain", hc="chestnut"),
       loot={"chance": 0.3, "slots": ["weapon", "chest", "legs"]}, mats={"hide": 0.2}),
    en("bandit_archer", "Bandit Archer", "Arquero a distancia",
       "Mantiene la distancia. Una flecha rapida y, cada pocos segundos, una descarga de tres flechas en abanico.",
       82, 84, 11, 14, 0, 32, 280,
       {"chest": L("shirt_longsleeve", "tan"), "legs": L("pants", "brown"), "feet": L("boots_basic", "leather"),
        "head": L("hood", M), "main_hand": L("weapon_bow", "default")},
       [atk("arrow", "projectile", None, 0.7, 0.1, 0.5, 1.8, 1.0, trig=290, anim="shoot", projectile=proj(310, 330, 5, 1, 0)),
        atk("volley", "projectile", None, 1.0, 0.1, 0.7, 4.5, 0.7, trig=270, anim="shoot", projectile=proj(280, 300, 5, 3, 34),
            on_hit=[{"id": "slow", "duration": 1.0, "strength": 0.2}])],
       keep=170, lk=look(skin="taupe", hair="hair_bob", hc="ginger"),
       loot={"chance": 0.28, "slots": ["weapon", "head", "feet"]}, mats={"hide": 0.2}),
    en("bandit_hexer", "Bandit Hexer", "Hechicero a distancia",
       "Un renegado que estudio las grietas de la Torre. Lanza orbes lentos que frenan y, si te acercas, una onda que aturde.",
       78, 74, 11, 14, 0, 36, 270,
       {"chest": L("shirt_longsleeve", "navy"), "legs": L("pants_dyed", "navy"), "feet": L("shoes_basic", "leather"),
        "head": L("hood", M), "main_hand": L("weapon_staff", "default")},
       [atk("hex_orb", "projectile", None, 0.9, 0.1, 0.6, 2.4, 1.0, trig=270, anim="spellcast",
            projectile=proj(200, 310, 7, 1, 0, "wisp"), on_hit=[{"id": "slow", "duration": 1.6, "strength": 0.3}]),
        atk("nova", "circle", 78, 1.0, 0.12, 0.8, 5.0, 1.2, trig=70, anim="spellcast", on_hit=[{"id": "stun", "duration": 0.3}])],
       keep=150, lk=look(skin="light", hair="hair_bob", hc="gray", eyes="green"),
       loot={"chance": 0.3, "slots": ["weapon", "ring", "head"]}, mats={"herb": 0.3}),
    en("bandit_cutthroat", "Bandit Cutthroat", "Degollador veloz",
       "Veloz y fragil: una embestida en linea con daga envenenada y un doble tajo corto.",
       88, 118, 10, 13, 0, 36, 250,
       {"chest": L("shirt_sleeveless", "charcoal"), "legs": L("pants", "charcoal"), "feet": L("boots_basic", "black"),
        "head": L("hood", M), "main_hand": L("weapon_dagger", "default"), "off_hand": L("weapon_dagger_offhand", "default")},
       [atk("stab", "line", 135, 0.5, 0.22, 0.7, 2.8, 1.0, trig=140, anim="thrust", width=22, dash_distance=125,
            on_hit=[{"id": "poison", "duration": 3, "strength": 3}]),
        atk("flurry", "cone", 44, 0.45, 0.1, 0.5, 1.4, 0.8, anim="slash", arc=110)],
       lk=look(skin="olive", hair="hair_plain", hc="black"),
       loot={"chance": 0.3, "slots": ["weapon", "feet", "ring"]}, mats={"hide": 0.25}),
    en("bandit_shieldman", "Bandit Shieldman", "Escudero resistente",
       "Muy resistente con su escudo: un empujon que aturde y un barrido a su alrededor. Hay que rodearlo.",
       240, 56, 14, 20, 40, 56, 200,
       {"chest": L("shirt_longsleeve", "navy"), "legs": L("pants", "brown"), "feet": L("boots_basic", "leather"),
        "head": L("bandana", M), "main_hand": L("weapon_arming", "default"),
        "off_hand": L("shield_round", "default")},
       [atk("bash", "cone", 52, 1.0, 0.12, 0.9, 2.6, 1.0, anim="thrust", arc=80, on_hit=[{"id": "stun", "duration": 0.5}]),
        atk("sweep", "circle", 70, 1.1, 0.12, 0.9, 4.5, 1.1, trig=64, anim="slash")],
       lk=look(skin="brown", hair="hair_buzzcut", hc="black", beard="beard_trimmed"),
       loot={"chance": 0.35, "slots": ["chest", "head", "weapon", "legs"]}, mats={"hide": 0.2}),
]

rask = en("bandit_rask", "Rask the Cleaver", "Mini-jefe del tier 1",
          "Teniente del Cuervo. Tajos amplios y una carga; por debajo de la mitad llama a sus matones y golpea el suelo.",
          560, 80, 17, 22, 25, 150, 280,
          {"chest": L("shirt_sleeveless", "charcoal"), "legs": L("pants", "charcoal"), "feet": L("boots_basic", "black"),
           "head": L("bandana", M), "main_hand": L("weapon_mace", "default"),
           "off_hand": L("shield_round", "default")},
          [atk("cleave", "cone", 86, 0.9, 0.12, 0.8, 2.2, 1.2, anim="slash", arc=130, on_hit=[{"id": "stun", "duration": 0.35}]),
           atk("charge", "line", 200, 0.8, 0.3, 0.9, 4.5, 1.2, trig=220, anim="thrust", width=40, dash_distance=200),
           atk("ground_pound", "circle", 100, 1.2, 0.15, 1.0, 6.0, 1.4, trig=90, anim="slash", on_hit=[{"id": "stun", "duration": 0.4}])],
          scale=1.1, boss=True, leash=2, respawn=40, resist={"stun": 0.5},
          lk=look(skin="bronze", hair="hair_buzzcut", hc="black", beard="beard_trimmed"),
          phases=[{"name": "Rask the Cleaver", "hp_below": 1, "speed_mult": 1, "attacks": ["cleave", "charge"]},
                  {"name": "Rask Enraged", "hp_below": 0.5, "speed_mult": 1.25, "attacks": ["cleave", "charge", "ground_pound"],
                   "summons": [{"id": "bandit_thug", "count": 2}]}],
          loot={"slots": ["head", "legs", "weapon", "chest"]}, mats={"hide": 1})

veyra = en("bandit_veyra", "Veyra the Hexer", "Mini-jefe del tier 1",
           "Teniente del Cuervo. Descargas de orbes desde lejos; por debajo de la mitad se rodea de arqueros y suelta una onda.",
           470, 92, 15, 18, 10, 140, 330,
           {"chest": L("shirt_longsleeve", "navy"), "legs": L("pants_dyed", "navy"), "feet": L("shoes_basic", "leather"),
            "head": L("hood", M), "bag": L("cape", "maroon"), "main_hand": L("weapon_staff", "default")},
           [atk("barrage", "projectile", None, 0.9, 0.1, 0.7, 3.0, 0.8, trig=340, anim="spellcast",
                projectile=proj(250, 400, 7, 5, 56, "wisp"), on_hit=[{"id": "slow", "duration": 1.5, "strength": 0.3}]),
            atk("nova", "circle", 110, 1.1, 0.12, 0.9, 5.0, 1.3, trig=100, anim="spellcast", on_hit=[{"id": "stun", "duration": 0.4}]),
            atk("hex_bolt", "projectile", None, 0.7, 0.1, 0.6, 2.2, 1.0, trig=330, anim="spellcast", projectile=proj(280, 380, 8, 1, 0, "wisp"))],
           scale=1.05, keep=230, boss=True, leash=2, respawn=40, resist={"stun": 0.5},
           lk=look(body="female", skin="light", hair="hair_bob", hc="red", eyes="green"),
           phases=[{"name": "Veyra the Hexer", "hp_below": 1, "speed_mult": 1, "attacks": ["barrage", "hex_bolt"]},
                   {"name": "Veyra Unbound", "hp_below": 0.5, "speed_mult": 1.25, "attacks": ["barrage", "hex_bolt", "nova"],
                    "summons": [{"id": "bandit_archer", "count": 2}]}],
           loot={"slots": ["head", "ring", "weapon", "legs"]}, mats={"herb": 1})

garrick = en("bandit_garrick", "Garrick Blackhand", "Jefe del tier 1",
             "El jefe del Cuervo, enorme y con muchos recursos: elige el golpe segun la distancia (salto sobre ti si huyes, cuchillos a media distancia, torbellino y tajos si te pegas) y llama a su banda en cada fase.",
             1900, 64, 24, 32, 35, 400, 340,
             {"chest": L("shirt_longsleeve", "tan"), "legs": L("pants", "charcoal"), "feet": L("boots_basic", "black"),
              "head": L("bandana", M), "bag": L("cape", "maroon"),
              "main_hand": L("weapon_arming", "default"), "off_hand": L("shield_round", "default")},
             [atk("crush", "cone", 104, 0.95, 0.12, 0.7, 2.0, 1.1, trig=100, anim="slash", arc=130, weight=3, on_hit=[{"id": "stun", "duration": 0.35}]),
              atk("backhand", "cone", 80, 0.5, 0.1, 0.5, 1.6, 0.8, trig=76, anim="slash", arc=200, weight=2),
              atk("whirlwind", "circle", 120, 1.0, 0.2, 0.9, 5.5, 1.3, trig=100, anim="slash", weight=2),
              atk("charge", "line", 240, 0.8, 0.35, 1.0, 5.0, 1.2, trig=250, anim="thrust", width=48, dash_distance=240, weight=2),
              atk("leap_slam", "line", 340, 0.9, 0.4, 1.0, 7.0, 1.4, trig=340, anim="thrust", width=60, dash_distance=320, weight=3,
                  on_hit=[{"id": "stun", "duration": 0.4}]),
              atk("throwing_knives", "projectile", None, 0.7, 0.1, 0.6, 3.0, 0.5, trig=300, anim="shoot", weight=3,
                  projectile=proj(300, 330, 6, 3, 30, "stinger"), on_hit=[{"id": "poison", "duration": 3, "strength": 3}]),
              atk("crossbow_volley", "projectile", None, 0.8, 0.1, 0.7, 4.5, 0.5, trig=330, anim="shoot", weight=2,
                  projectile=proj(260, 360, 7, 7, 90, "stinger"), on_hit=[{"id": "slow", "duration": 1.2, "strength": 0.25}]),
              atk("quake", "circle", 150, 1.3, 0.15, 1.0, 6.5, 1.5, trig=125, anim="slash", weight=2, on_hit=[{"id": "stun", "duration": 0.4}])],
             scale=2.3, boss=True, leash=2, respawn=40, resist={"stun": 1, "slow": 0.5},
             lk=look(skin="light", hair="hair_buzzcut", hc="black", beard="beard_trimmed", eyes="gray"),
             phases=[{"name": "Garrick Blackhand", "hp_below": 1, "speed_mult": 1, "attacks": ["crush", "backhand", "leap_slam", "throwing_knives"]},
                     {"name": "The Crows Call", "hp_below": 0.75, "speed_mult": 1.15, "attacks": ["crush", "backhand", "whirlwind", "charge", "leap_slam", "throwing_knives", "crossbow_volley"],
                      "summons": [{"id": "bandit_swordsman", "count": 2}, {"id": "bandit_archer", "count": 1}]},
                     {"name": "Blackhands Wrath", "hp_below": 0.5, "speed_mult": 1.3, "attacks": ["crush", "backhand", "whirlwind", "charge", "leap_slam", "throwing_knives", "crossbow_volley", "quake"],
                      "summons": [{"id": "bandit_cutthroat", "count": 2}, {"id": "bandit_hexer", "count": 1}]},
                     {"name": "Blackhands Last Stand", "hp_below": 0.25, "speed_mult": 1.55, "attacks": ["backhand", "whirlwind", "charge", "leap_slam", "throwing_knives", "crossbow_volley", "quake"],
                      "summons": [{"id": "bandit_shieldman", "count": 1}, {"id": "bandit_thug", "count": 2}]}],
             loot={"slots": ["weapon", "chest", "ring", "head", "legs"]}, mats={"hide": 1})

enemies += [rask, veyra, garrick]
doc = ("Bandidos del Cuervo (pisos 1-10): los enemigos reales del tier 1. Personajes LPC compuestos (sprite.lpc: look + "
       "equipment) con su propio kit de ataques; el atuendo granate es el color de la banda. Generado por "
       "tools/gen_bandits.py. Numeros provisionales.")
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "enemies", "bandits.json")
with open(out, "w", encoding="utf8") as f:
    json.dump({"_doc": doc, "enemies": enemies}, f, ensure_ascii=False, indent=1)
print(len(enemies), "enemigos")

# El botin propio (loot.items) lo anade add_gear.py; se vuelve a aplicar para no perderlo al regenerar.
import subprocess, sys
subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), "add_gear.py")], check=True)
