"""Reescribe el kit del Picaro (data/skills/rogue.json, data/classes/rogue.json) segun el diseno aprobado:
basico M2 (toque = combo de 4 golpes, mantener = Cross Cut cargado), Roll en Espacio (cuesta 15 Energy), Q Fan of Knives
(nv 2), E Shadow Step (nv 4), R Stealth (nv 8), ultimate en F (nv 6), pasiva Filo envenenado (nv 8) y skills de mundo en
libros: Smoke Bomb, Caltrops, Poisoned Blades, Blade Flurry, Vanish y Disarm. Ambush, Crippling Strike y Perfect Evasion
quedan retiradas (solo las usan los tests de mecanicas). Se puede volver a ejecutar sin perder nada.
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


doc = load("data/skills/rogue.json")
by_id = {s["id"]: s for s in doc["skills"]}


def skill(id, name, role, desc, label, shape, unlock, book=False, **kw):
    base = {"id": id, "name": name, "slot": "S", "kind": "skill", "role": role, "description": desc, "hud_label": label,
            "shape": shape, "windup": 0.15, "active": 0.1, "recovery": 0.3, "cooldown": 8, "cost": 20, "damage_mult": 1.0,
            "resource_gain": 0, "resource_cap": 0, "max_targets": 0, "move": {"windup": 0.5, "active": 0.3, "recovery": 0.6},
            "anim": "slash", "implemented": True, "ult_gain": 2, "ult_cap": 8, "unlock_level": unlock, "class": "rogue",
            "damage_type": "physical"}
    if book:
        base["world"] = True
        base["source"] = "book"
    base.update(kw)
    return base


# --- Basicos ---
fang = by_id["twin_fang"]
fang["description"] = "Basico (clic derecho). Combo de 4 golpes rapidos: cada uno da 6 de Energy y el cuarto es un doble tajo (+40 %). Por la espalda del enemigo hace +25 %."
fang["combo"] = {"steps": 4, "reset": 0.8, "mults": [1.0, 1.0, 1.0, 1.4], "arc_bonus": [0, 0, 0, 20]}
fang["resource_gain"] = 6
fang["resource_cap"] = 12
cross = by_id["cross_cut"]
cross["description"] = "Basico cargado (mantener clic derecho): hasta 0,9 s cargando. Embestida corta con dos cortes cruzados: mas dano y alcance cuanto mas cargues; con la carga completa hace sangrar 3 s. Cuesta 15 de Energy."
cross["cost"] = 15
cross["hold"] = {"max": 0.9, "damage_bonus": 0.6, "range_bonus": 0.4, "full_on_hit": [{"id": "bleed", "duration": 3, "strength": 4}]}

# --- Q, E, R ---
fan = by_id["fan_of_knives"]
fan["description"] = "Abanico de 5 dagas con veneno de 3 s: la herramienta a distancia del Picaro."
fan["on_hit"] = [{"id": "poison", "duration": 3, "strength": 4}]
fan["projectile"]["range"] = 200
step = skill("shadow_step", "Shadow Step", "Movilidad / ofensiva", "Te teletransportas detras del enemigo mas cercano hacia donde apuntas (hasta 220 px): tu siguiente golpe en 3 s hace +50 %.", "STEP", "self", 4,
             cost=20, cooldown=9, windup=0.1, active=0.1, recovery=0.15, damage_mult=0.1, ult_gain=0, ult_cap=0,
             teleport_behind={"range": 220, "backstab": {"id": "backstab", "duration": 3.0, "strength": 0.5}}, anim="thrust",
             move={"windup": 0.6, "active": 0.6, "recovery": 0.8})
stealth = skill("stealth", "Stealth", "Sigilo / emboscada", "Te vuelves invisible hasta 20 s: los enemigos normales te pierden. Se rompe al atacar, usar otra skill, recibir dano o volver a usarla; el primer golpe hace +25 %. Los jefes siempre te ven.", "STEALTH", "self", 8,
                cost=20, cooldown=25, windup=0.6, active=0.1, recovery=0.2, damage_mult=0.1, ult_gain=0, ult_cap=0,
                self_status={"id": "stealth", "duration": 20.0, "strength": 0.25}, stealth_toggle=True, anim="spellcast",
                move={"windup": 0.5, "active": 0.5, "recovery": 0.8})
sentence = by_id["death_sentence"]
sentence["description"] = "Salta sobre el objetivo y encadena cortes; los golpes matan al instante a quien tenga menos del 30 % de vida (menos a los jefes)."
sentence["execute"] = {"below": 0.3, "mult": 1.0, "kill": True}
sentence["damage_mult"] = 1.9
sentence["strikes"]["final_mult"] = 4.5
sentence["strikes"]["count"] = 5
sentence["strikes"]["interval"] = 0.12
sentence["active"] = 0.6
by_id["twin_fang"]["combo"]["mults"] = [1.15, 1.15, 1.15, 1.6]

# --- Libros de skill (skills de mundo) ---
smoke = skill("smoke_bomb", "Smoke Bomb", "Control / sigilo", "Una nube de humo ralentiza a los enemigos y te oculta de ellos 3 s.", "SMOKE", "self", 3, book=True,
              cost=20, cooldown=14, windup=0.2, damage_mult=0.1, ult_gain=0, ult_cap=0, anim="spellcast",
              self_status={"id": "concealed", "duration": 3.0, "strength": 0.0},
              zone={"radius": 80, "duration": 4.0, "tick": 0.5, "damage_mult": 0.0, "visual": "dark", "status": [{"id": "slow", "duration": 1.0, "strength": 0.4}]})
caltrops = skill("caltrops", "Caltrops", "Control / trampa", "Siembra abrojos delante de ti: los enemigos que los pisen sangran y se ralentizan.", "CALTROP", "self", 5, book=True,
                 cost=20, cooldown=12, windup=0.2, damage_mult=0.1, ult_gain=0, ult_cap=0, anim="thrust",
                 zone={"radius": 70, "duration": 6.0, "tick": 0.6, "damage_mult": 0.3, "offset": 90, "visual": "blood",
                       "status": [{"id": "bleed", "duration": 2.0, "strength": 3}, {"id": "slow", "duration": 1.0, "strength": 0.35}]})
venom = by_id["poisoned_blades"]
venom.update({"description": "Tus 4 siguientes golpes aplican un veneno fuerte (5 s).", "shape": "self", "world": True, "source": "book", "unlock_level": 6,
              "grant_venom_hits": 4, "cost": 20, "cooldown": 14, "windup": 0.2, "active": 0.1, "recovery": 0.2, "damage_mult": 0.1, "ult_gain": 0, "ult_cap": 0,
              "anim": "spellcast"})
venom.pop("on_hit", None)
venom.pop("range", None)
venom.pop("arc", None)
flurry = by_id["blade_flurry"]
flurry.update({"unlock_level": 7, "world": True, "source": "book", "range": 58, "strikes": {"count": 5, "interval": 0.08, "final_mult": 1.2},
               "active": 0.45, "description": "Rafaga de 5 cortes en circulo, de alcance corto."})
vanish = skill("vanish", "Vanish", "Sigilo / escape", "Desapareces al instante 5 s: +30 % de velocidad, sueltas a quien te persigue, reinicias el combo y tu primer golpe es critico. Sobrevive al primer golpe que recibas; los jefes te siguen viendo.", "VANISH", "self", 9, book=True,
              cost=25, cooldown=30, windup=0.05, active=0.05, recovery=0.1, damage_mult=0.1, ult_gain=0, ult_cap=0, anim="spellcast",
              self_status={"id": "vanish", "duration": 5.0, "strength": 0.3}, stealth_toggle=True, vanish=True,
              move={"windup": 1.0, "active": 1.0, "recovery": 1.0})
disarm = skill("disarm", "Disarm", "Control", "Un golpe que desarma al objetivo 2,5 s: no puede atacar. Los jefes son inmunes.", "DISARM", "cone", 10, book=True,
               range=58, arc=70, cost=25, cooldown=15, damage_mult=1.1, windup=0.2, on_hit=[{"id": "disarm", "duration": 2.5}])

# --- Retiradas ---
for retired in ["ambush", "crippling_strike"]:
    by_id[retired]["retired"] = True
    by_id[retired]["world"] = True
by_id["perfect_evasion"].update({"retired": True, "world": True, "legacy_special": True, "unlock_level": 4})

for new in [step, stealth, smoke, caltrops, vanish, disarm]:
    if new["id"] in by_id:
        by_id[new["id"]].update(new)
    else:
        doc["skills"].append(new)
save("data/skills/rogue.json", doc)

cls = load("data/classes/rogue.json")
cls["default_loadout"] = {"M1": "twin_fang", "M2": "cross_cut", "S1": "fan_of_knives", "S2": "shadow_step", "S3": "stealth", "ULTIMATE": "death_sentence"}
cls["passive"] = "shadow_venom"
cls["passive_level"] = 8
cls["slot_gates"] = True
cls["backstab_bonus"] = 0.25
cls["mobility"] = {"name": "Roll", "kind": "roll", "description": "Rodar con invulnerabilidad al inicio (cuesta 5 de Energy). Una esquiva perfecta carga la ultimate.",
                   "dir": "move", "duration": 0.25, "distance": 104, "iframe_start": 0.0, "iframe_end": 0.2, "cooldown": 3.5, "cost": 5, "icon": "dodge"}
save("data/classes/rogue.json", cls)

# --- libros como consumibles ---
consumables = load("data/consumables.json")
have = {c["id"] for c in consumables["consumables"]}
books = [("poisoned_blades", "Hojas envenenadas", "Poisoned Blades"), ("blade_flurry", "Rafaga de cuchillas", "Blade Flurry"),
         ("smoke_bomb", "Bomba de humo", "Smoke Bomb"), ("caltrops", "Abrojos", "Caltrops"), ("vanish", "Desvanecerse", "Vanish"), ("disarm", "Desarmar", "Disarm")]
for skill_id, spanish, english in books:
    book_id = "book_" + skill_id
    if book_id not in have:
        consumables["consumables"].append({
            "id": book_id, "name": "Libro: %s" % spanish, "kind": "book",
            "description": "Ensena la habilidad %s del Picaro. Al leerlo la aprendes y puedes cambiarla por una de tus skills Q, E o R en el libro de skills (Tab)." % english,
            "effect": {"learn": skill_id}, "price": 0, "value": 60, "icon": "skill_tome"})
save("data/consumables.json", consumables)

# --- iconos (pack 496 RPG icons) ---
picks = {"shadow_step": "S_Buff04", "stealth": "S_Buff05", "vanish": "S_Buff07", "smoke_bomb": "S_Poison09", "caltrops": "S_Earth04", "disarm": "S_Sword02"}
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

# --- estados ---
st = load("data/statuses.json")
have = {s["id"] for s in st["statuses"]}
new_status = [
    {"id": "stealth", "name": "Stealth", "kind": "buff", "description": "Invisible para los enemigos normales (strength = bonus del primer golpe).", "max_duration": 20.0, "max_strength": 1.0, "immune_after": 0.0, "color": [0.6, 0.6, 0.75, 1.0]},
    {"id": "vanish", "name": "Vanish", "kind": "buff", "description": "Invisible, mas rapido y sobrevives al primer golpe (strength = bonus de velocidad).", "max_duration": 6.0, "max_strength": 0.6, "immune_after": 0.0, "color": [0.7, 0.5, 0.9, 1.0]},
    {"id": "concealed", "name": "Concealed", "kind": "buff", "description": "Oculto por el humo unos segundos.", "max_duration": 5.0, "immune_after": 0.0, "color": [0.5, 0.5, 0.55, 1.0]},
    {"id": "backstab", "name": "Backstab", "kind": "buff", "description": "El siguiente golpe hace dano extra (strength = fraccion).", "max_duration": 4.0, "max_strength": 1.0, "immune_after": 0.0, "color": [0.9, 0.4, 0.4, 1.0]},
    {"id": "disarm", "name": "Disarm", "kind": "control", "description": "No puede atacar (los jefes son inmunes).", "max_duration": 3.0, "immune_after": 0.0, "color": [0.9, 0.75, 0.4, 1.0]},
    {"id": "stagger", "name": "Stagger", "kind": "control", "description": "Tambaleo corto (el parry a un jefe): pausa breve, no es un stun.", "max_duration": 0.6, "immune_after": 3.0, "color": [1.0, 0.85, 0.5, 1.0]},
]
for entry in new_status:
    if entry["id"] not in have:
        st["statuses"].append(entry)
save("data/statuses.json", st)

fx = load("data/fx.json")
fx["events"]["shadow_step_out"] = [{"id": "arcane/blink-out", "scale": 0.9, "up": 0}]
fx["events"]["shadow_step_in"] = [{"id": "arcane/teleport-in", "scale": 0.9, "up": 0}]
fx["events"]["stealth_break"] = [{"id": "smoke/smoke-bomb", "scale": 0.7, "up": 0}]
for sid in ["stealth", "vanish", "concealed", "backstab", "disarm", "stagger"]:
    fx["events"]["status_" + sid] = [{"id": "smoke/dust-puff", "scale": 0.8, "up": 8}]
fx["events"]["status_disarm"] = [{"id": "impacts/parry", "scale": 0.7, "up": 12}]
fx["events"]["status_stagger"] = [{"id": "impacts/hit-spark", "scale": 0.9, "up": 12}]
fx["skills"]["shadow_step"] = {"cast": [{"id": "smoke/dash-dust", "scale": 1.0, "at": "self"}]}
fx["skills"]["stealth"] = {"cast": [{"id": "smoke/smoke-bomb", "scale": 0.9, "at": "self"}]}
fx["skills"]["vanish"] = {"cast": [{"id": "smoke/smoke-bomb", "scale": 1.2, "at": "self"}]}
fx["skills"]["smoke_bomb"] = {"cast": [{"id": "smoke/smoke-bomb", "scale": 1.6, "at": "self"}]}
fx["skills"]["caltrops"] = {"cast": [{"id": "arcane/rune-trap", "scale": 1.0, "ahead": 0.9}]}
fx["skills"]["disarm"] = {"cast": [{"id": "melee/shadow-claw", "scale": 1.0, "ahead": 0.5}], "hit": "impacts/parry"}
fx["skills"]["fan_of_knives"]["cast"] = [{"id": "smoke/dash-dust", "scale": 0.8, "at": "self"}]
save("data/fx.json", fx)
print("picaro ok:", len(doc["skills"]), "skills")
