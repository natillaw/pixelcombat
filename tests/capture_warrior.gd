## Captura del guerrero rediseñado: HUD (basico, defensa, Q E R, ultimate, barra de objetos) y libro de skills. Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --position 12000,12000 --path . res://tests/capture_warrior.tscn
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
	world.player.safe_zone = true
	world.player.set_level(9)
	for id: String in ["whirlwind", "throwing_axe", "execute", "second_wind", "ground_stomp", "iron_counter"]:
		world.player.learn_skill(StringName(id))
	world.player.add_consumable("health_potion", 3)
	world.player.add_consumable("resource_potion", 2)
	world.player.safe_zone = false
	await get_tree().create_timer(0.4).timeout
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/warrior_hud.png")
	world.player.safe_zone = true
	main.get("loadout_panel")._toggle()
	await get_tree().create_timer(1.3).timeout
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/warrior_book.png")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)
