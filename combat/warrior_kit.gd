## WarriorKit — datos canónicos de la clase Warrior (documento de clases v2).
##
## Esta clase es la única fuente de verdad de los números provisionales del
## Warrior. La simulación (game/sim/warrior_sim.gd) lee estos diccionarios; no
## tiene valores de combate hardcodeados. Los 15 talents del Skill Book están
## definidos como datos, pero solo M1, M2 y la pasiva están implementados en el
## primer corte. `implemented` marca lo que ya se puede jugar.
class_name WarriorKit
extends RefCounted

const ClassResourceScript := preload("res://combat/class_resource.gd")

const CLASS_ID := "warrior"
const CLASS_NAME := "Warrior"
const RESOURCE_NAME := "Rage"
const MAX_RAGE := 100.0
const SPECIAL_COST := 30.0
const ULTIMATE_CHARGE_MAX := 100.0

## M1: rápido, fiable, poca Rage. Sin combo.
const M1 := {
	"id": &"warrior_m1",
	"name": "Sword Slash",
	"slot": "M1",
	"kind": "basic",
	"role": "Daño / presión",
	"description": "Corte horizontal rápido. Genera poca Rage al acertar.",
	"windup": 0.12,
	"active": 0.12,
	"recovery": 0.18,
	"cooldown": 0.05,
	"range": 78.0,
	"arc": 110.0,
	"damage_mult": 1.0,
	"rage_gain": 8.0,
	"rage_cap": 16.0,
	"anim": "slash",
	"implemented": true,
}

## M2: lento y pesado; más daño y más Rage. Castiga compromisos.
const M2 := {
	"id": &"warrior_m2",
	"name": "Heavy Strike",
	"slot": "M2",
	"kind": "basic",
	"role": "Burst / castigo",
	"description": "Golpe vertical lento y potente, con recuperación mayor y más Rage.",
	"windup": 0.30,
	"active": 0.12,
	"recovery": 0.35,
	"cooldown": 0.20,
	"range": 70.0,
	"arc": 80.0,
	"damage_mult": 2.1,
	"rage_gain": 14.0,
	"rage_cap": 20.0,
	"anim": "thrust",
	"implemented": true,
}

## Esquiva (accion comun a todas las clases): desplazamiento corto con ventana de
## invulnerabilidad. No gasta recurso; solo cooldown. Puede cancelar un ataque
## en WINDUP o RECOVERY, nunca en ACTIVE (el golpe ya salio).
## Sin direccion de movimiento, retrocede (opuesto al cursor).
const DODGE := {
	"id": &"dodge",
	"name": "Dodge",
	"slot": "DODGE",
	"kind": "movement",
	"role": "Movilidad / evasion",
	"description": "Desplazamiento corto con invulnerabilidad al inicio. Cancela windup y recovery.",
	"duration": 0.25,
	"distance": 104.0,
	"iframe_start": 0.0,
	"iframe_end": 0.18,
	"cooldown": 1.1,
	"buffer": 0.15,
	"implemented": true,
}

## Pasiva: Vengeful Fury (nueva en la v2). No se acumula; el daño periódico no la activa.
const PASSIVE := {
	"id": &"vengeful_fury",
	"name": "Vengeful Fury",
	"description": "Al recibir un golpe directo, el siguiente Heavy Strike hace +30% de daño durante 4 s.",
	"window": 4.0,
	"bonus": 0.30,
	"implemented": true,
}

## Special: cuesta 30 Rage.
const SPECIAL := {
	"id": &"iron_counter",
	"name": "Iron Counter",
	"slot": "SPECIAL",
	"kind": "special",
	"role": "Contraataque",
	"description": "Postura de contraataque frontal. Desvía un ataque bloqueable y responde con un corte potente.",
	"cost": 30,
	"cooldown": 12.0,
	"implemented": false,
}

## Ultimate: barra aparte de Ultimate Charge (0-100).
const ULTIMATE := {
	"id": &"war_gods_descent",
	"name": "War God's Descent",
	"slot": "ULTIMATE",
	"kind": "ultimate",
	"role": "Daño de área / iniciación",
	"description": "Salto a una zona marcada con un golpe devastador; más daño en el centro y preparación esquivable.",
	"charge": 100,
	"cooldown": 60.0,
	"implemented": false,
}

## Skill Book completo (15 habilidades normales). Costes y cooldowns provisionales.
const SKILL_BOOK := [
	{"id": &"cleaving_strike", "name": "Cleaving Strike", "role": "Daño / AoE", "cost": 20, "cooldown": 6.0, "description": "Corte horizontal amplio que daña a todos los enemigos alcanzados.", "implemented": false},
	{"id": &"crushing_blow", "name": "Crushing Blow", "role": "Burst / castigo", "cost": 25, "cooldown": 10.0, "description": "Golpe descendente muy pesado; interrumpe habilidades canalizadas si conecta.", "implemented": false},
	{"id": &"piercing_thrust", "name": "Piercing Thrust", "role": "Daño preciso", "cost": 15, "cooldown": 5.0, "description": "Estocada rápida y lineal con más alcance que M1.", "implemented": false},
	{"id": &"whirlwind", "name": "Whirlwind", "role": "Daño / AoE", "cost": 30, "cooldown": 9.0, "description": "Giro con la espada extendida que golpea alrededor, con límite de impactos.", "implemented": false},
	{"id": &"parry", "name": "Parry", "role": "Defensa", "cost": 20, "cooldown": 10.0, "description": "Desvía un ataque frontal en una ventana breve; si acierta, permite contraatacar.", "implemented": false},
	{"id": &"iron_guard", "name": "Iron Guard", "role": "Defensa / mitigación", "cost": 15, "cooldown": 8.0, "description": "Postura defensiva temporal que reduce el daño frontal y la velocidad de movimiento.", "implemented": false},
	{"id": &"retaliation", "name": "Retaliation", "role": "Contraataque", "cost": 20, "cooldown": 8.0, "description": "Prepara una respuesta potente si recibe un ataque durante la ventana.", "implemented": false},
	{"id": &"combat_roll", "name": "Combat Roll", "role": "Movilidad / evasión", "cost": 10, "cooldown": 6.0, "description": "Rodar en una dirección con una ventana breve de evasión.", "implemented": false},
	{"id": &"heroic_leap", "name": "Heroic Leap", "role": "Movilidad / iniciación", "cost": 20, "cooldown": 12.0, "description": "Salto a una ubicación seleccionada con golpe al aterrizar; el impacto se muestra antes.", "implemented": false},
	{"id": &"relentless_pursuit", "name": "Relentless Pursuit", "role": "Movilidad / persecución", "cost": 15, "cooldown": 9.0, "description": "Carga frontal con daño al impactar y ralentización breve.", "implemented": false},
	{"id": &"ground_stomp", "name": "Ground Stomp", "role": "Control / AoE", "cost": 25, "cooldown": 11.0, "description": "Golpea el suelo y ralentiza brevemente a los enemigos cercanos.", "implemented": false},
	{"id": &"earth_splitter", "name": "Earth Splitter", "role": "Control de zona", "cost": 30, "cooldown": 12.0, "description": "Fisura frontal que daña y ralentiza a los enemigos alcanzados.", "implemented": false},
	{"id": &"sundering_strike", "name": "Sundering Strike", "role": "Debilitamiento", "cost": 20, "cooldown": 10.0, "description": "Golpe que reduce temporalmente la armadura del objetivo; no se acumula.", "implemented": false},
	{"id": &"battle_cry", "name": "Battle Cry", "role": "Mejora / ofensiva", "cost": 25, "cooldown": 15.0, "description": "Aumenta temporalmente el Attack Power propio y de aliados cercanos.", "implemented": false},
	{"id": &"war_banner", "name": "War Banner", "role": "Apoyo / Control de zona", "cost": 30, "cooldown": 18.0, "description": "Planta un estandarte que reduce el daño recibido por aliados cercanos.", "implemented": false},
]


static func create_rage_resource() -> ClassResourceScript:
	var resource := ClassResourceScript.new()
	resource.resource_name = RESOURCE_NAME
	resource.current_amount = 0.0
	resource.max_amount = MAX_RAGE
	resource.min_amount = 0.0
	return resource


static func get_basics() -> Dictionary:
	return {"M1": M1.duplicate(true), "M2": M2.duplicate(true)}


static func get_special() -> Dictionary:
	return SPECIAL.duplicate(true)


static func get_ultimate() -> Dictionary:
	return ULTIMATE.duplicate(true)


static func get_skill_book() -> Array:
	return SKILL_BOOK.duplicate(true)


static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for entry: Dictionary in SKILL_BOOK:
		ids.append(entry["id"])
	return ids
