## Captura de los bandidos del tier 1 (formacion y jefe). Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_bandits.tscn
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	main.get("session").go_to_training()
	await _wait(1.0)
	var world: CombatWorld = main.get("world")
	world.player.set_level(10)
	for enemy: EnemySim in world.enemies.duplicate():
		enemy.take_damage(1.0e9)
	var origin := world.player.position
	var ids := ["bandit_thug", "bandit_swordsman", "bandit_archer", "bandit_hexer", "bandit_cutthroat", "bandit_shieldman"]
	for i: int in range(ids.size()):
		var e := world.add_enemy(StringName(ids[i]), origin + Vector2(-150.0 + 60.0 * i, -70.0))
		e.state = EnemySim.State.IDLE
	for i: int in range(3):
		world.add_enemy(StringName(["bandit_rask", "bandit_veyra", "bandit_garrick"][i]), origin + Vector2(-130.0 + 130.0 * i, 70.0))
	world.player.position = origin + Vector2(0, 220)
	await _wait(0.6)
	get_viewport().get_texture().get_image().save_png(dir + "/bandits_lineup.png")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
