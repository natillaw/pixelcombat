## Captura de los menus (principal, personajes, ajustes y pausa). Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_menu.tscn
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_SLOT_DIR", "user://capture_slots")
	DirAccess.make_dir_recursive_absolute("user://capture_slots")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await _wait(0.5)
	await _shot(dir, "menu_1_main")
	main.main_menu._screen = "slots"
	main.main_menu._rebuild()
	await _wait(0.3)
	await _shot(dir, "menu_2_slots")
	main.main_menu.settings.open()
	await _wait(0.3)
	await _shot(dir, "menu_3_settings")
	main.main_menu.settings._close()
	main.main_menu.close()
	main.pause_menu.open()
	await _wait(0.3)
	await _shot(dir, "menu_4_pause")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
