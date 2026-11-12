## Captura visual de pisos generados: vista general (todo el mapa) y vista cercana en la
## entrada. No es una suite de pass/fail. Necesita un renderer real (no --headless):
##
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_floors.tscn
##
## FLOORS=1,5,10 elige los pisos (por defecto una muestra de varios tiers y estilos).
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
	await _wait(0.5)
	var session: GameSession = _main.get("session")
	var world: CombatWorld = _main.get("world")
	var arena: Arena = _main.get("arena")
	var floors := [1, 2, 5, 10, 11, 21, 31]
	var wanted := OS.get_environment("FLOORS")
	if not wanted.is_empty():
		floors = []
		for part: String in wanted.split(","):
			floors.append(int(part))
	for floor_number: int in floors:
		for n: int in range(1, floor_number):
			session.tower.complete(n)
		world.player.set_level(10)
		session.go_to_floor(floor_number)
		await _wait(0.6)
		await _shot("floor_%03d_spawn" % floor_number)
		var size := session.layout.size
		var view := get_viewport().get_visible_rect().size
		var zoom := minf(view.x / size.x, view.y / size.y)
		arena.camera.limit_left = -100000
		arena.camera.limit_top = -100000
		arena.camera.limit_right = 100000
		arena.camera.limit_bottom = 100000
		arena.camera.zoom = Vector2.ONE * zoom
		arena.set_process(false)
		arena.camera.position_smoothing_enabled = false
		arena.camera.global_position = size * 0.5
		await _wait(0.5)
		await _shot("floor_%03d_overview_%s" % [floor_number, session.layout.style])
		arena.camera.zoom = Vector2.ONE
		arena.set_process(true)
		arena.camera.position_smoothing_enabled = true
		arena.camera.limit_left = 0
		arena.camera.limit_top = 0
		arena.camera.limit_right = int(size.x)
		arena.camera.limit_bottom = int(size.y)
	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	print("shot ", shot_name, " err=", image.save_png(path))
