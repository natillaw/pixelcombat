## Captura visual de las clases (no es una suite de pass/fail).
##
## Por cada clase: aspecto, un basico en vuelo, una skill y la zona marcada de la
## Ultimate. Necesita un renderer real (no --headless):
##
##   CAPTURE_DIR=$PWD/screenshots godot --path . res://tests/capture_classes.tscn
extends Node

const MainScene := preload("res://game/main.tscn")

var _dir: String = ""
var _main: Node2D = null


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)
	_main = MainScene.instantiate()
	add_child(_main)
	await _wait(1.0)

	var world: CombatWorld = _main.get("world")
	for class_id: String in ["rogue", "mage", "archer"]:
		await _capture_class(world, class_id)

	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _capture_class(world: CombatWorld, class_id: String) -> void:
	world.player.reset(world.bounds.get_center())
	world.player.switch_class("warrior")
	world.player.switch_class(class_id)
	world.player.set_level(8)
	world.player.resource.current_amount = 100.0
	world.player.ultimate_charge = 100.0
	_aim_up()
	await _wait(0.6)
	await _shot("%s_1_idle" % class_id)

	Input.action_press("attack_m1")
	await _shot("%s_2_basic" % class_id, 0.22)
	Input.action_release("attack_m1")
	await _wait(1.0)

	Input.action_press("skill_1")
	await _shot("%s_3_skill" % class_id, 0.30)
	Input.action_release("skill_1")
	await _wait(1.4)

	Input.action_press("ultimate")
	await _shot("%s_4_ultimate" % class_id, 0.45)
	Input.action_release("ultimate")
	await _wait(2.4)


func _aim_up() -> void:
	var window := get_viewport().get_window()
	if window != null:
		window.warp_mouse(Vector2(640, 120))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String, wait: float = 0.0) -> void:
	if wait > 0.0:
		await _wait(wait)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := _dir.path_join(shot_name + ".png")
	print("shot ", shot_name, " err=", image.save_png(path))
