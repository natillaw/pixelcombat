## Captura: fuente, portales, pose de ciudad, minimapa con niebla, selector de pisos, salida y creador (renderer real).
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
	var session: GameSession = main.get("session")
	var world: CombatWorld = main.get("world")
	session.go_to_city()
	await _wait(0.8)
	world.player.position = Vector2(42.5 * 32.0, 31.5 * 32.0 + 90.0)
	await _wait(0.6)
	await _shot(dir, "fx_1_fountain")
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) == "door_tower":
			world.player.position = (portal["position"] as Vector2) + Vector2(0, 40)
	await _wait(0.6)
	await _shot(dir, "fx_2_tower_door")
	session.tower.complete(1)
	session.tower.complete(2)
	session.service_opened.emit("tower")
	await _wait(0.4)
	await _shot(dir, "fx_3_floor_menu")
	main.get("service_panel").close()
	session.go_to_floor(1)
	await _wait(0.8)
	await _shot(dir, "fx_4_floor1_start")
	for portal: Dictionary in session.layout.portals:
		if String(portal["id"]) == "entrance":
			world.player.position = (portal["position"] as Vector2) + Vector2(0, 60)
	await _wait(1.6)
	await _shot(dir, "fx_5_entrance_portal")
	session.service_opened.emit("leave")
	await _wait(0.4)
	await _shot(dir, "fx_6_leave_menu")
	main.get("service_panel").close()
	# Recorre el piso para ver la niebla del minimapa y el bosque sin huecos negros.
	var size := session.layout.grid.pixel_size()
	world.player.position = Vector2(size.x * 0.5, size.y * 0.5)
	await _wait(0.5)
	await _shot(dir, "fx_7_floor_center")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
