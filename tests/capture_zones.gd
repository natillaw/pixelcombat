## Captura de las zonas de suelo de jefe con sprites (fuego, sangre, oscuridad, veneno, hielo). Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --position 12000,12000 --path . res://tests/capture_zones.tscn
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
	await get_tree().create_timer(0.8).timeout
	var world: CombatWorld = main.get("world")
	for enemy: EnemySim in world.enemies.duplicate():
		enemy.take_damage(1.0e9)
	var origin := world.player.position
	var visuals := ["fire", "blood", "dark", "poison", "frost"]
	for i: int in range(visuals.size()):
		var spec := {"radius": 70, "duration": 30.0, "tick": 99.0, "damage_mult": 0.0, "visual": visuals[i]}
		world.spawn_zone(GroundZone.new(spec, origin + Vector2(-240.0 + 120.0 * i, -60.0), 10.0))
	await get_tree().create_timer(1.2).timeout
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/zones.png")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)
