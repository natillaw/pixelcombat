## Captura visual para CI (no es una suite de pass/fail).
##
## Abre la escena real del juego, mueve al Warrior, lanza M1/M2, fuerza la
## muerte y guarda PNGs. Necesita un renderer real (no --headless):
##
##   CAPTURE_DIR=$PWD/screenshots xvfb-run -a godot --path . \
##     --rendering-driver opengl3 --resolution 1280x720 \
##     res://tests/capture_screens.tscn
extends Node

const MainScene := preload("res://game/main.tscn")
const InputMessageScript := preload("res://net/input_message.gd")

var _dir: String = ""
var _main: Node2D = null


func _ready() -> void:
	_dir = OS.get_environment("CAPTURE_DIR")
	if _dir.is_empty():
		_dir = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(_dir)

	_main = MainScene.instantiate()
	add_child(_main)

	await _wait(1.2)
	await _shot("01_arena")

	# El Warrior spawnea en el centro; el muñeco activo está 124 px arriba.
	Input.action_press("move_up")
	await _wait(0.55)
	Input.action_release("move_up")
	await _wait(0.25)

	_aim_up()
	Input.action_press("attack_m1")
	await _shot("02_sword_slash", 0.16)
	Input.action_release("attack_m1")
	await _wait(0.35)

	Input.action_press("attack_m2")
	await _shot("03_heavy_strike", 0.34)
	Input.action_release("attack_m2")
	await _shot("04_impact", 0.12)

	# Pasiva activa + pantalla de muerte.
	var world: CombatWorld = _main.get("world")
	if world != null:
		# Ultimate: carga llena, telegraph durante el salto y golpe al caer.
		world.warrior.ultimate_charge = WarriorKit.ULTIMATE_CHARGE_MAX
		await _wait(1.0)  # deja acabar el M2 anterior (el buffer es de 0,25 s)
		_aim_up()
		Input.action_press("ultimate")
		await _shot("04b_ultimate_telegraph", 0.35)
		Input.action_release("ultimate")
		await _shot("04c_ultimate_impact", 0.45)
		await _wait(0.9)
		world.warrior.take_damage(25.0, Vector2.ZERO, false)
		_aim_up()
		Input.action_press("attack_m2")
		await _shot("05_vengeful_fury", 0.10)
		Input.action_release("attack_m2")
		world.warrior.take_damage(99999.0, Vector2.ZERO, false)
		await _shot("06_death", 0.45)

	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


func _aim_up() -> void:
	# El viewport lógico es 640x360; apuntar por encima del centro.
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
	var err := image.save_png(path)
	print("shot ", shot_name, " -> ", path, " err=", err)
