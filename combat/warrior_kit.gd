## WarriorKit — datos canónicos de la clase Warrior (documento de clases v2).
##
## Fuente de verdad de los números provisionales del Warrior. Las skills
## ejecutables (M1, M2, Cleaving Strike, Piercing Thrust) viven en
## data/skills/warrior.json y se cargan con SkillCatalog; aqui quedan la pasiva,
## Special, Ultimate, la esquiva y el Skill Book completo (15 habilidades).
## La simulacion (game/sim/player_sim.gd) lee estos datos; no tiene valores de
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

## Skill Book del Guerrero: las skills de equipo (Q, E, R) y de mundo, mas las retiradas que solo usan los tests de mecanicas. Los datos reales viven en data/skills/warrior.json; aqui se espeja para comprobar que no se desincronizan.
const SKILL_BOOK := [
	{"id": &"cleaving_strike", "unlock_level": 4, "name": "Cleaving Strike", "role": "Daño / AoE", "cost": 20, "cooldown": 6.0, "description": "Corte horizontal amplio que daña a todos los enemigos alcanzados.", "implemented": true},
	{"id": &"crushing_blow", "unlock_level": 10, "name": "Crushing Blow", "role": "Burst / castigo", "cost": 25, "cooldown": 10.0, "description": "Golpe descendente muy pesado; aturde a los enemigos alcanzados.", "implemented": true},
	{"id": &"piercing_thrust", "unlock_level": 2, "name": "Piercing Thrust", "role": "Daño preciso", "cost": 15, "cooldown": 5.0, "description": "Estocada rápida y lineal con más alcance que M1.", "implemented": true},
	{"id": &"rend", "unlock_level": 2, "name": "Rend", "role": "Dano / sangrado", "cost": 20, "cooldown": 5.0, "description": "Tajo corto que hace sangrar al enemigo 4 s.", "implemented": true},
	{"id": &"war_cry", "unlock_level": 4, "name": "War Cry", "role": "Mejora / ofensiva", "cost": 0, "cooldown": 14.0, "description": "Grito de guerra: +20 % de dano y +armadura durante 6 s y 30 de Rage al instante.", "implemented": true},
	{"id": &"shockwave", "unlock_level": 8, "name": "Shockwave", "role": "Control / empuje", "cost": 25, "cooldown": 10.0, "description": "Onda en linea que empuja a los enemigos y aturde 0,4 s.", "implemented": true},
	{"id": &"ground_stomp", "unlock_level": 3, "name": "Ground Stomp", "role": "Control / AoE", "cost": 25, "cooldown": 11.0, "description": "Golpea el suelo: ralentiza a los enemigos cercanos y los atrae hacia ti.", "implemented": true},
	{"id": &"iron_counter", "unlock_level": 6, "name": "Counterstrike", "role": "Contraataque", "cost": 30, "cooldown": 12.0, "description": "Postura de 1 s: si te golpean de frente, anulas el golpe y respondes con un corte que hace sangrar.", "implemented": true},
	{"id": &"whirlwind", "unlock_level": 9, "name": "Whirlwind", "role": "Dano / area", "cost": 30, "cooldown": 9.0, "description": "Giro de 1,5 s que golpea 5 veces a todos los que te rodean.", "implemented": true},
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
