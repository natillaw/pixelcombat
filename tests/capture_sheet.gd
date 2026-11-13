## Captura visual de la ficha con mochila (no es suite). Necesita renderer real.
extends Node

const MainScene := preload("res://game/main.tscn")


func _ready() -> void:
	var dir := OS.get_environment("CAPTURE_DIR")
	if dir.is_empty():
		dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	var main := MainScene.instantiate()
	add_child(main)
	main.get("session").go_to_training()
	await get_tree().create_timer(1.0).timeout
	var world: CombatWorld = main.get("world")
	var rng := RandomNumberGenerator.new()
	for i: int in range(14):
		world.player.add_item(ItemGen.roll_item(rng, 1, "", "", world.player.class_id))
	world.player.add_item({"id": "leather_pants", "rarity": "rare", "tier": 1, "stats": ItemCatalog.item("leather_pants")["stats"]})
	var sheet: CharacterSheet = main.get("character_sheet")
	sheet._toggle()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("sheet.png"))
	world.player.equip_from_bag(world.player.bag.size() - 1)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join("sheet2.png"))
	get_tree().quit()
