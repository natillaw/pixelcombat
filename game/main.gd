## Main — punto de entrada del primer corte jugable de PixelCombat.
##
## Monta el mundo de simulación, la arena, los actores, el HUD y el overlay de
## debug. Traduce el teclado/ratón a [InputMessage] y lo entrega a
## [CombatWorld] una vez por tick de física.
extends Node2D

const DebugOverlayScene := preload("res://ui/debug_overlay.tscn")

var world: CombatWorld
var session: GameSession
var arena: Arena
var hud: GameHud
var loadout_panel: LoadoutPanel

var _was_dead: bool = false


func _ready() -> void:
	world = CombatWorld.new(1337)
	session = GameSession.new(world, "" if OS.get_environment("PIXELCOMBAT_NO_SAVE") != "" else SaveGame.DEFAULT_PATH)

	arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build(world)
	arena.session = session

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HudLayer"
	hud_layer.layer = 10
	add_child(hud_layer)

	hud = GameHud.new()
	hud.name = "Hud"
	hud_layer.add_child(hud)
	hud.bind(world, session)

	# Panel de loadout (Tab): capa propia por encima del HUD.
	var loadout_layer := CanvasLayer.new()
	loadout_layer.name = "LoadoutLayer"
	loadout_layer.layer = 20
	add_child(loadout_layer)
	loadout_panel = LoadoutPanel.new()
	loadout_panel.name = "LoadoutPanel"
	loadout_layer.add_child(loadout_panel)
	loadout_panel.bind(world)

	var debug_overlay: CanvasLayer = DebugOverlayScene.instantiate()
	debug_overlay.name = "DebugOverlay"
	add_child(debug_overlay)

	TickManager.register(world)
	_was_dead = false


func _exit_tree() -> void:
	if world != null and TickManager.is_registered(world):
		TickManager.unregister(world)


func _physics_process(_delta: float) -> void:
	if world == null:
		return

	if Input.is_action_just_pressed("restart_training"):
		session.restart()
		_was_dead = false
	if Input.is_action_just_pressed("interact"):
		session.try_interact()
	if Input.is_action_just_pressed("floor_prev"):
		session.select_floor(-1)
	if Input.is_action_just_pressed("floor_next"):
		session.select_floor(1)

	if world.player.alive and world.player.health <= 0.0:
		_was_dead = true

	world.submit_input(_read_input())


func _read_input() -> InputMessage:
	var message := InputMessage.new()
	message.tick = TickManager.current_tick + 1
	message.peer_id = 1
	message.move_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var mouse_world := get_global_mouse_position()
	var aim := mouse_world - world.player.position
	if aim.length_squared() > 4.0:
		message.aim_dir = aim.normalized()
	else:
		message.aim_dir = world.player.aim_dir

	message.actions = {
		"m1": Input.is_action_pressed("attack_m1"),
		"m2": Input.is_action_pressed("attack_m2"),
		"dodge": Input.is_action_pressed("dodge"),
		"s1": Input.is_action_pressed("skill_1"),
		"s2": Input.is_action_pressed("skill_2"),
		"s3": Input.is_action_pressed("skill_3"),
		"s4": Input.is_action_pressed("skill_4"),
		"s5": Input.is_action_pressed("skill_5"),
		"ultimate": Input.is_action_pressed("ultimate"),
		"special": Input.is_action_pressed("special"),
		"debug_level_up": Input.is_action_pressed("debug_level_up"),
		"debug_level_reset": Input.is_action_pressed("debug_level_reset"),
		"debug_class_next": Input.is_action_pressed("debug_class_next"),
	}
	return message
