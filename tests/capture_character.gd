## Captura de la ficha del personaje (C). Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_character.tscn
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
	world.player.set_level(6)
	for id: String in ["crow_bandana", "crow_vest", "crow_breeches", "militia_mace", "crow_signet", "crow_boots"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		world.player.add_item(ItemGen.roll_item(rng, 1, "rare", "", "", id))
	for index: int in range(world.player.bag.size()):
		world.player.equip_from_bag(0)
	await get_tree().create_timer(0.3).timeout
	var sheet: CharacterSheet = main.get("character_sheet")
	sheet._toggle()
	await get_tree().create_timer(0.3).timeout
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "/character_sheet.png")
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)
