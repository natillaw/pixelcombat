## Captura del libro de skills (Tab). Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_book.tscn
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
	await get_tree().create_timer(0.5).timeout
	var world: CombatWorld = main.get("world")
	world.player.safe_zone = true
	world.player.switch_class("mage")
	world.player.set_level(8)
	world.player.learn_skill(&"fireball")
	await get_tree().create_timer(0.3).timeout
	var panel: LoadoutPanel = main.get("loadout_panel")
	panel._toggle()
	await get_tree().create_timer(1.2).timeout
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/book_open.png")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)
