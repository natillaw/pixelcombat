## Captura conjunta del tier 1: inventario con iconos propios, mercader, comida activa en el HUD, aviso al
## despertar, estados en enemigos y caida de un bandido. Renderer real, fuera de pantalla:
##   CAPTURE_DIR=$PWD/screenshots godot --position 12000,12000 --path . res://tests/capture_tier1.tscn
extends Node

const MainScene := preload("res://game/main.tscn")
var _dir: String = ""


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "1")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	main.get("session").go_to_training()
	await _wait(0.8)
	var world: CombatWorld = main.get("world")
	var player := world.player
	for enemy: EnemySim in world.enemies.duplicate():
		enemy.take_damage(1.0e9)
	player.safe_zone = true
	player.set_level(8)
	player.add_gold(400)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for id: String in ["iron_sword", "leather_cap", "leather_vest", "militia_mace", "crow_bandana", "crow_hood", "crow_vest", "crow_boots", "copper_ring", "crow_signet", "apprentice_wand", "short_bow", "plain_tunic", "chitin_vest", "worn_boots"]:
		player.add_item(ItemGen.roll_item(rng, 1, ["common", "uncommon", "rare"][rng.randi_range(0, 2)], "", "", id))
	for id: String in ["health_potion", "resource_potion", "hunters_stew", "silk_tea", "herb_bread", "skill_tome"]:
		player.add_consumable(id, 3)
	player.use_consumable("hunters_stew")
	player.use_consumable("silk_tea")
	player.use_consumable("herb_bread")
	player.equip_from_bag(0)
	player.equip_from_bag(0)
	await _wait(0.4)
	main.get("inventory_panel")._toggle() if main.get("inventory_panel").has_method("_toggle") else null
	await _wait(0.4)
	await _shot("t1_inventory")
	main.get("inventory_panel")._toggle()
	await _wait(0.2)
	main.get("session").service_opened.emit("merchant")
	await _wait(0.4)
	await _shot("t1_merchant")
	main.get("service_panel").close()
	await _wait(0.3)
	player.safe_zone = false
	var origin := player.position
	var group: Array = []
	for i: int in range(4):
		var enemy := world.add_enemy(&"bandit_swordsman" if i % 2 == 0 else &"bandit_shieldman", origin + Vector2(160.0 + 40.0 * i, -50.0 + 30.0 * i))
		enemy.group = "camp_capture"
		group.append(enemy)
	(group[0] as EnemySim).take_damage(1.0)
	await _wait(0.35)
	await _shot("t1_alert")
	(group[1] as EnemySim).apply_status("bleed", 4.0, 4.0)
	(group[2] as EnemySim).apply_status("shield", 6.0, 50.0)
	(group[3] as EnemySim).apply_status("stun", 1.5)
	await _wait(0.5)
	await _shot("t1_status")
	(group[0] as EnemySim).take_damage(1.0e9)
	await _wait(0.25)
	await _shot("t1_death_mid")
	await _wait(0.6)
	await _shot("t1_death_end")
	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _shot(name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
