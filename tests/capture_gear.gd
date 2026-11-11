## Captura visual del equipo en el sprite (no es una suite de pass/fail).
##
## Muestra a cada clase sin equipo y con un conjunto equipado, y el inventario y el
## taller abiertos. Necesita un renderer real (no --headless):
##
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_gear.tscn
extends Node

const MainScene := preload("res://game/main.tscn")

var _dir: String = ""
var _main: Node2D = null


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	_main = MainScene.instantiate()
	add_child(_main)
	_main.get("session").go_to_training()
	await _wait(1.0)
	var world: CombatWorld = _main.get("world")
	for class_id: String in ["warrior", "rogue", "mage", "archer"]:
		world.player.switch_class(class_id)
		world.player.bag.clear()
		world.player.reset(world.bounds.get_center())
		await _wait(0.5)
		await _shot("gear_%s_1_default" % class_id)
		var weapon_id := String(ItemCatalog.items_for("weapon", class_id)[0]["id"])
		var set_ids := [weapon_id, "leather_cap", "leather_vest", "leather_pants", "worn_boots", "copper_ring"]
		for rarity: String in ["common", "epic"]:
			for id: String in set_ids:
				world.player.bag.erase(null)
				world.player.add_item({"id": id, "rarity": rarity, "tier": 1, "stats": ItemCatalog.item(id)["stats"]})
			for i: int in range(set_ids.size()):
				world.player.equip_from_bag(0)
			world.player.bag.clear()
			await _wait(0.5)
			await _shot("gear_%s_2_%s" % [class_id, rarity])

	var inventory: InventoryPanel = _main.get("inventory_panel")
	world.player.add_material("ore_t1", 7)
	world.player.add_material("herb_t1", 3)
	world.player.add_material("hide_t1", 5)
	for i: int in range(8):
		world.player.add_item(ItemGen.roll_item(RandomNumberGenerator.new(), 1))
	inventory._toggle()
	await _wait(0.4)
	await _shot("gear_inventory")
	inventory._toggle()
	var crafting: CraftingPanel = _main.get("crafting_panel")
	world.player.add_gold(100)
	crafting.open("tailor")
	await _wait(0.4)
	await _shot("gear_crafting")
	crafting.close()

	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	print("shot ", shot_name, " err=", image.save_png(path))
