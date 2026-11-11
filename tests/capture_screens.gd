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

	OS.set_environment("PIXELCOMBAT_NO_SAVE", "1")
	_main = MainScene.instantiate()
	add_child(_main)
	_main.get("session").go_to_training()

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
		# Nivel 10: todas las skills desbloqueadas, panel de loadout y Special.
		world.player.set_level(10)
		world.player.resource.current_amount = 80.0
		await _wait(1.2)  # el loadout solo se abre en reposo: deja acabar el ataque anterior
		await _shot("04a_level10_hud", 0.1)
		_toggle_loadout()
		await _shot("04a2_loadout_panel", 0.3)
		_toggle_loadout()
		await _wait(0.2)
		Input.action_press("special")
		await _shot("04a3_iron_counter_stance", 0.30)
		Input.action_release("special")
		await _wait(1.6)

		# Ultimate: carga llena, telegraph durante el salto y golpe al caer.
		world.player.ultimate_charge = WarriorKit.ULTIMATE_CHARGE_MAX
		await _wait(1.0)  # deja acabar el M2 anterior (el buffer es de 0,25 s)
		_aim_up()
		Input.action_press("ultimate")
		await _shot("04b_ultimate_telegraph", 0.35)
		Input.action_release("ultimate")
		await _shot("04c_ultimate_impact", 0.45)
		await _wait(0.9)

		# Enemigos: el telegraph de cada tipo (cono, linea, circulo, cono pesado).
		await _enemy_telegraph(world, 0, 0, "04d_enemy_slime_cone")
		await _enemy_telegraph(world, 1, 0, "04e_enemy_bat_line")
		await _enemy_telegraph(world, 2, 0, "04f_enemy_spider_circle")
		await _enemy_telegraph(world, 3, 0, "04g_enemy_beetle_cone")
		world.player.health = world.player.max_health
		world.player.reset(world.bounds.get_center())
		for enemy: EnemySim in world.enemies:
			enemy.revive()
		await _wait(0.5)
		world.player.take_damage(25.0, Vector2.ZERO, false)
		_aim_up()
		Input.action_press("attack_m2")
		await _shot("05_vengeful_fury", 0.10)
		Input.action_release("attack_m2")
		world.player.take_damage(99999.0, Vector2.ZERO, false)
		await _shot("06_death", 0.45)

	print("CAPTURE DONE -> ", _dir)
	get_tree().quit(0)


## Coloca al Warrior junto al enemigo `index`, fuerza el ataque `attack_index` y
## hace la captura a mitad del aviso (el relleno del telegraph a medias).
func _enemy_telegraph(world: CombatWorld, index: int, attack_index: int, shot_name: String) -> void:
	var enemy: EnemySim = world.enemies[index]
	var attack: Dictionary = enemy.data["attacks"][attack_index]
	var distance := float(attack["trigger_range"]) * 0.6 + 10.0
	world.player.reset(enemy.position + Vector2(-distance, -10.0))
	world.player.health = world.player.max_health
	enemy.facing = (world.player.position - enemy.position).normalized()
	enemy.state = EnemySim.State.CHASE
	enemy._start_telegraph(attack)
	await _shot(shot_name, float(attack["windup"]) * 0.6)
	await _wait(float(attack["windup"]) + 0.3)


## Abre o cierra el panel de loadout como si se pulsara Tab.
func _toggle_loadout() -> void:
	var press := InputEventAction.new()
	press.action = "toggle_loadout"
	press.pressed = true
	Input.parse_input_event(press)


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
