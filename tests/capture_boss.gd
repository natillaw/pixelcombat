## Captura visual de los enemigos a distancia y del jefe (no es una suite de
## pass/fail). Necesita un renderer real (no --headless):
##
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_boss.tscn
extends Node

const MainScene := preload("res://game/main.tscn")

var _dir: String = ""
var _main: Node2D = null
var _world: CombatWorld = null


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	_main = MainScene.instantiate()
	add_child(_main)
	_main.get("session").go_to_training()
	await _wait(1.0)
	_world = _main.get("world")
	_world.player.set_level(10)

	await _telegraph(&"wisp", "orb", "boss_1_wisp_lane", Vector2(-170, 0))
	await _telegraph(&"hornet", "sting", "boss_2_hornet_fan", Vector2(-150, 0))
	var boss := _find(&"brood_beetle")
	await _telegraph(&"brood_beetle", "crush", "boss_3_crush", Vector2(-80, 20))
	_hurt_to(boss, 0.60)
	await _wait(0.5)
	await _shot("boss_4_roar_phase2")
	await _wait(1.2)
	await _telegraph(&"brood_beetle", "spit", "boss_5_spit_fan", Vector2(-230, 0))
	await _telegraph(&"brood_beetle", "charge", "boss_6_charge_lane", Vector2(-200, 0))
	_hurt_to(boss, 0.25)
	await _wait(1.5)
	await _telegraph(&"brood_beetle", "quake", "boss_7_quake", Vector2(-110, 10))

	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _find(def_id: StringName) -> EnemySim:
	for enemy: EnemySim in _world.enemies:
		if enemy.def_id == def_id and not enemy.summoned:
			return enemy
	return null


func _hurt_to(enemy: EnemySim, fraction: float) -> void:
	var armor := float(enemy.data["stats"].get("armor", 0.0))
	enemy.take_damage((enemy.health - enemy.max_health * fraction) / (1.0 - armor / (armor + 100.0)) + 0.01)


## Coloca al jugador a `offset` del enemigo, fuerza el ataque y captura a mitad
## del aviso.
func _telegraph(def_id: StringName, attack_id: String, shot_name: String, offset: Vector2) -> void:
	var enemy := _find(def_id)
	_world.player.reset(enemy.position - offset)
	_world.player.health = _world.player.max_health
	var attack: Dictionary = {}
	for candidate: Dictionary in enemy.data["attacks"]:
		if candidate["id"] == attack_id:
			attack = candidate
	enemy.state = EnemySim.State.CHASE
	enemy.facing = (_world.player.position - enemy.position).normalized()
	enemy._start_telegraph(attack)
	await _shot(shot_name, float(attack["windup"]) * 0.65)
	await _wait(float(attack["windup"]) + 0.6)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String, wait: float = 0.0) -> void:
	if wait > 0.0:
		await _wait(wait)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	print("shot ", shot_name, " err=", image.save_png(path))
