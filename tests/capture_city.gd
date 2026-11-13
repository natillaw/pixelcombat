## Captura visual de la ciudad: plaza, puerta de la Torre, mercado y calle sur. No es pass/fail.
## Necesita renderer real:  CAPTURE_DIR=$PWD/shots godot --path . res://tests/capture_city.tscn
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
	var main := MainScene.instantiate()
	add_child(main)
	await _wait(0.5)
	var session: GameSession = main.get("session")
	var world: CombatWorld = main.get("world")
	world.player.set_level(10)
	session.go_to_city()
	await _wait(0.6)
	var spots := {
		"plaza": Vector2(42.5, 34.5), "gate": Vector2(42.5, 19.0), "market": Vector2(42.5, 30.8),
		"west": Vector2(26.0, 31.5), "south": Vector2(42.5, 44.0),
	}
	for key: String in spots:
		world.player.position = (spots[key] as Vector2) * 32.0
		await _wait(1.2)
		await _shot("city_" + key)
	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	print("shot ", shot_name, " err=", image.save_png(_dir.path_join(shot_name + ".png")))
