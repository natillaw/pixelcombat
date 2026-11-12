## Captura del creador de personaje (necesita renderer real):
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_creator.tscn
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await get_tree().create_timer(0.6).timeout
	var creator: CharacterCreator = main.get("creator")
	await _shot(dir, "creator_1_lore")
	for i: int in range(Lore.intro_pages().size()):
		creator._next_page()
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "creator_2_create")
	creator._select_class("mage")
	creator._cycle("body", 1)
	creator._cycle("hair", 2)
	creator._cycle("hair_color", 5)
	creator._cycle("skin", 3)
	await get_tree().create_timer(0.4).timeout
	await _shot(dir, "creator_3_mage")
	print("CAPTURE DONE")
	get_tree().quit(0)


func _shot(dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(shot_name + ".png"))
