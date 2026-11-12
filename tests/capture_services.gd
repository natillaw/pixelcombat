## Captura de la ciudad con sus PNJ y de las ventanas de servicio. Renderer real:
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_services.tscn
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
	await _wait(0.6)
	var world: CombatWorld = main.get("world")
	var session: GameSession = main.get("session")
	world.player.add_gold(300)
	world.player.add_consumable("health_potion", 3)
	world.player.add_consumable("resource_potion", 2)
	world.player.add_material("herb_t1", 8)
	for npc: Dictionary in session.layout.npcs:
		if npc.get("station", "") == "tavern":
			world.player.position = (npc["position"] as Vector2) + Vector2(30, 40)
	await _wait(1.0)
	await _shot(dir, "svc_1_city")
	for station: String in ["tavern", "guild", "merchant"]:
		session.service_opened.emit(station)
		await _wait(0.3)
		await _shot(dir, "svc_2_" + station)
		main.get("service_panel").close()
	print("CAPTURE DONE -> ", dir)
	get_tree().quit(0)


func _shot(dir: String, name: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
