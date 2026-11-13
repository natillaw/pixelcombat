"""Reescribe el kit del Guerrero (data/skills/warrior.json y data/classes/warrior.json) segun el diseno aprobado:
basico M2 (toque = combo de 3 tajos, mantener = golpe cargado), Bloqueo/parry en Espacio, Q Rend (nv 2), E War Cry
(nv 4), R Shockwave (nv 8), ultimate en F (nv 6), skills de mundo (Ground Stomp, Whirlwind, Contragolpe) y pasiva
Furia vengativa en nv 8. Cleaving Strike, Piercing Thrust y Crushing Blow quedan retiradas (retired) y solo las usan
los tests de mecanicas (tests/legacy_kit.gd). Se puede volver a ejecutar sin perder nada.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf8") as f:
        return json.load(f)


def save(rel, data):
    with open(os.path.join(ROOT, rel), "w", encoding="utf8") as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")


skills_doc = load("data/skills/warrior.json")
by_id = {s["id"]: s for s in skills_doc["skills"]}


def skill(id, name, slot, kind, role, desc, label, shape, unlock, **kw):
    base = {"id": id, "name": name, "slot": slot, "kind": kind, "role": role, "description": desc, "hud_label": label,
            "shape": shape, "windup": 0.2, "active": 0.12, "recovery": 0.3, "cooldown": 6, "cost": 20, "damage_mult": 1.0,
            "resource_gain": 4, "resource_cap": 16, "max_targets": 0, "move": {"windup": 0.3, "active": 0.1, "recovery": 0.35},
            "anim": "slash", "implemented": True, "ult_gain": 4, "ult_cap": 12, "unlock_level": unlock, "class": "warrior",
            "damage_type": "physical"}
    base.update(kw)
    return base


# --- Basicos: M2 en el mando (toque = M1 en la simulacion, mantener = M2) ---
m1 = by_id["warrior_m1"]
m1["name"] = "Sword Combo"
m1["description"] = "Basico (clic derecho). Combo de 3 tajos: cada golpe da Rage y el tercero es mas ancho y empuja un poco. Se pueden encadenar sin esperar, a cambio de una carga."
m1["combo"] = {"steps": 3, "reset": 0.9, "mults": [1.0, 1.0, 1.35], "arc_bonus": [0, 0, 40], "last_on_hit": [{"id": "knockback", "duration": 0.2, "strength": 40}]}
m2 = by_id["warrior_m2"]
m2["name"] = "Heavy Strike"
m2["description"] = "Basico cargado (mantener clic derecho): hasta 1,2 s cargando. Mas dano y alcance cuanto mas cargues; con la carga completa aturde 0,4 s. Cuesta 15 de Rage."
m2["cost"] = 15
m2["hold"] = {"max": 1.2, "damage_bonus": 0.9, "range_bonus": 0.3, "full_on_hit": [{"id": "stun", "duration": 0.4}]}

# --- Skills base: Q, E, R ---
rend = skill("rend", "Rend", "S", "skill", "Dano / sangrado", "Tajo corto que hace sangrar al enemigo 4 s.", "REND", "cone", 2, range=74, arc=80,
             damage_mult=1.2, cooldown=5, cost=20, windup=0.22, on_hit=[{"id": "bleed", "duration": 4, "strength": 5}])
war_cry = skill("war_cry", "War Cry", "S", "skill", "Mejora / ofensiva", "Grito de guerra: +20 % de dano y +armadura durante 6 s y 30 de Rage al instante.", "CRY", "self", 4,
                cooldown=14, cost=0, windup=0.3, active=0.3, recovery=0.2, damage_mult=0.1, resource_gain=0, resource_cap=0, ult_gain=0, ult_cap=0,
                self_status={"id": "warcry", "duration": 6.0, "strength": 0.2}, resource_burst=30, anim="spellcast",
                move={"windup": 0.6, "active": 0.6, "recovery": 0.8})
shockwave = skill("shockwave", "Shockwave", "S", "skill", "Control / empuje", "Onda en linea que empuja a los enemigos y aturde 0,4 s.", "WAVE", "line", 8, range=240, width=54,
                  damage_mult=1.4, cooldown=10, cost=25, windup=0.3, max_targets=3, anim="thrust",
                  on_hit=[{"id": "knockback", "duration": 0.2, "strength": 110}, {"id": "stun", "duration": 0.4}])

# --- Skills de mundo ---
stomp = by_id["ground_stomp"]
stomp.update({"unlock_level": 3, "world": True, "description": "Golpea el suelo: ralentiza a los enemigos cercanos y los atrae hacia ti.",
              "on_hit": [{"id": "slow", "duration": 2.0, "strength": 0.45}, {"id": "pull", "duration": 0.2, "strength": 70}]})
whirl = skill("whirlwind", "Whirlwind", "S", "skill", "Dano / area", "Giro de 1,5 s que golpea 5 veces a todos los que te rodean.", "WHIRL", "circle", 9, range=92,
              damage_mult=0.8, cooldown=9, cost=30, windup=0.2, active=1.5, recovery=0.35, world=True,
              strikes={"count": 5, "interval": 0.3, "final_mult": 1.4}, move={"windup": 0.4, "active": 0.55, "recovery": 0.6})
counter = by_id["iron_counter"]
counter.update({"name": "Counterstrike", "slot": "S", "unlock_level": 6, "world": True, "legacy_special": True,
                "description": "Postura de 1 s: si te golpean de frente, anulas el golpe y respondes con un corte que hace sangrar.",
                "on_hit": [{"id": "bleed", "duration": 3, "strength": 5}]})
descent = by_id["war_gods_descent"]
descent["zone"] = {"radius": 90, "duration": 4.0, "tick": 0.6, "damage_mult": 0.35, "visual": "fire", "status": [{"id": "slow", "duration": 1.0, "strength": 0.3}]}
descent["description"] = "Salto a una zona marcada con un golpe devastador (mas dano en el centro) que deja una grieta de fuego unos segundos."

# --- Retiradas (solo tests de mecanicas) ---
for retired_id in ["cleaving_strike", "piercing_thrust", "crushing_blow"]:
    by_id[retired_id]["retired"] = True
    by_id[retired_id]["world"] = True

ids = [s["id"] for s in skills_doc["skills"]]
for new in [rend, war_cry, shockwave, whirl]:
    if new["id"] in by_id:
        by_id[new["id"]].update(new)
    else:
        skills_doc["skills"].append(new)
save("data/skills/warrior.json", skills_doc)

cls = load("data/classes/warrior.json")
cls["default_loadout"] = {"M1": "warrior_m1", "M2": "warrior_m2", "S1": "rend", "S2": "war_cry", "S3": "shockwave", "ULTIMATE": "war_gods_descent"}
cls["passive_level"] = 8
cls["mobility"] = {"name": "Bloqueo", "kind": "block", "description": "Mantener Espacio: escudo al frente (-70 % de dano, gasta Rage). Si empieza justo antes del golpe (0,12 s) es parry perfecto: sin dano, aturde al atacante y carga la ultimate.",
                   "cooldown": 0.6, "parry_window": 0.12, "block_reduction": 0.7, "block_cost": 0.5, "block_arc": 150, "icon": "iron_counter"}
cls["ult_charge"]["on_parry"] = 14.0
save("data/classes/warrior.json", cls)
print("guerrero ok:", len(skills_doc["skills"]), "skills")
