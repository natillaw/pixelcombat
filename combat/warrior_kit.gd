## WarriorKit — datos canónicos de la clase Warrior (documento de clases v2).
##
## Fuente de verdad de los números provisionales del Warrior. Las skills
## ejecutables (M1, M2, Cleaving Strike, Piercing Thrust) viven en
## data/skills/warrior.json y se cargan con SkillCatalog; aqui quedan la pasiva,
## Special, Ultimate, la esquiva y el Skill Book completo (15 habilidades).
## La simulacion (game/sim/warrior_sim.gd) lee estos datos; no tiene valores de
## combate hardcodeados. `implemented` marca lo que ya se puede jugar.
class_name WarriorKit
extends RefCounted

const ClassResourceScript := preload("res://combat/class_resource.gd")

const CLASS_ID := "warrior"
const CLASS_NAME := "Warrior"
const RESOURCE_NAME := "Rage"
const MAX_RAGE := 100.0
const SPECIAL_COST := 30.0
const ULTIMATE_CHARGE_MAX := 100.0

## M1 y M2 viven en data/skills/warrior.json (SkillCatalog). Se exponen aqui para
## que el resto del codigo y los tests sigan leyendolos como WarriorKit.M1/M2.
## M1: rapido, fiable, poca Rage. M2: lento y pesado; castiga compromisos.
static var M1: Dictionary = SkillCatalog.skill(&"warrior_m1")
static var M2: Dictionary = SkillCatalog.skill(&"warrior_m2")

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

## Special (Q): Iron Counter. Los datos viven en data/skills/warrior.json.
static var SPECIAL: Dictionary = SkillCatalog.skill(&"iron_counter")

## Ultimate: barra aparte de Ultimate Charge (0-100), que sube al conectar golpes.
## Los datos viven en data/skills/warrior.json; no tiene cooldown aparte, la
## limita la carga.
static var ULTIMATE: Dictionary = SkillCatalog.skill(&"war_gods_descent")

## Skill Book completo (15 habilidades normales). Costes y cooldowns provisionales.
const SKILL_BOOK := [
	{"id": &"cleaving_strike", "unlock_level": 4, "name": "Cleaving Strike", "role": "Daño / AoE", "cost": 20, "cooldown": 6.0, "description": "Corte horizontal amplio que daña a todos los enemigos alcanzados.", "implemented": true},
	{"id": &"crushing_blow", "unlock_level": 10, "name": "Crushing Blow", "role": "Burst / castigo", "cost": 25, "cooldown": 10.0, "description": "Golpe descendente muy pesado; interrumpe habilidades canalizadas si conecta.", "implemented": false},
	{"id": &"piercing_thrust", "unlock_level": 2, "name": "Piercing Thrust", "role": "Daño preciso", "cost": 15, "cooldown": 5.0, "description": "Estocada rápida y lineal con más alcance que M1.", "implemented": true},
	{"id": &"whirlwind", "unlock_level": 14, "name": "Whirlwind", "role": "Daño / AoE", "cost": 30, "cooldown": 9.0, "description": "Giro con la espada extendida que golpea alrededor, con límite de impactos.", "implemented": false},
	{"id": &"parry", "unlock_level": 12, "name": "Parry", "role": "Defensa", "cost": 20, "cooldown": 10.0, "description": "Desvía un ataque frontal en una ventana breve; si acierta, permite contraatacar.", "implemented": false},
	{"id": &"iron_guard", "unlock_level": 18, "name": "Iron Guard", "role": "Defensa / mitigación", "cost": 15, "cooldown": 8.0, "description": "Postura defensiva temporal que reduce el daño frontal y la velocidad de movimiento.", "implemented": false},
	{"id": &"retaliation", "unlock_level": 28, "name": "Retaliation", "role": "Contraataque", "cost": 20, "cooldown": 8.0, "description": "Prepara una respuesta potente si recibe un ataque durante la ventana.", "implemented": false},
	{"id": &"combat_roll", "unlock_level": 16, "name": "Combat Roll", "role": "Movilidad / evasión", "cost": 10, "cooldown": 6.0, "description": "Rodar en una dirección con una ventana breve de evasión.", "implemented": false},
	{"id": &"heroic_leap", "unlock_level": 20, "name": "Heroic Leap", "role": "Movilidad / iniciación", "cost": 20, "cooldown": 12.0, "description": "Salto a una ubicación seleccionada con golpe al aterrizar; el impacto se muestra antes.", "implemented": false},
	{"id": &"relentless_pursuit", "unlock_level": 32, "name": "Relentless Pursuit", "role": "Movilidad / persecución", "cost": 15, "cooldown": 9.0, "description": "Carga frontal con daño al impactar y ralentización breve.", "implemented": false},
	{"id": &"ground_stomp", "unlock_level": 24, "name": "Ground Stomp", "role": "Control / AoE", "cost": 25, "cooldown": 11.0, "description": "Golpea el suelo y ralentiza brevemente a los enemigos cercanos.", "implemented": false},
	{"id": &"earth_splitter", "unlock_level": 45, "name": "Earth Splitter", "role": "Control de zona", "cost": 30, "cooldown": 12.0, "description": "Fisura frontal que daña y ralentiza a los enemigos alcanzados.", "implemented": false},
	{"id": &"sundering_strike", "unlock_level": 36, "name": "Sundering Strike", "role": "Debilitamiento", "cost": 20, "cooldown": 10.0, "description": "Golpe que reduce temporalmente la armadura del objetivo; no se acumula.", "implemented": false},
	{"id": &"battle_cry", "unlock_level": 40, "name": "Battle Cry", "role": "Mejora / ofensiva", "cost": 25, "cooldown": 15.0, "description": "Aumenta temporalmente el Attack Power propio y de aliados cercanos.", "implemented": false},
	{"id": &"war_banner", "unlock_level": 50, "name": "War Banner", "role": "Apoyo / Control de zona", "cost": 30, "cooldown": 18.0, "description": "Planta un estandarte que reduce el daño recibido por aliados cercanos.", "implemented": false},
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
