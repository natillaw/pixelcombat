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
var vignette: Vignette
var creator: CharacterCreator
var loadout_panel: LoadoutPanel
var inventory_panel: InventoryPanel
var crafting_panel: CraftingPanel
var service_panel: ServicePanel
var character_sheet: CharacterSheet
var main_menu: MainMenu
var pause_menu: PauseMenu
## Con menu principal: la partida se elige ahi (sin menu en tests y capturas).
var _use_menu: bool = false

var _was_dead: bool = false
## Hasta soltar el boton, el clic que recogio algo no ataca.
var _click_consumed: bool = false


func _ready() -> void:
	world = CombatWorld.new(1337)
	var save_path := SaveGame.DEFAULT_PATH
	if not OS.get_environment("PIXELCOMBAT_SAVE_PATH").is_empty():
		save_path = OS.get_environment("PIXELCOMBAT_SAVE_PATH")
	if not OS.get_environment("PIXELCOMBAT_NO_SAVE").is_empty():
		save_path = ""
	_use_menu = DisplayServer.get_name() != "headless" and OS.get_environment("PIXELCOMBAT_NO_MENU").is_empty() and OS.get_environment("PIXELCOMBAT_NO_SAVE").is_empty() and OS.get_environment("PIXELCOMBAT_SAVE_PATH").is_empty()
	session = GameSession.new(world, "" if _use_menu else save_path)
	session.use_menus = true

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
	var vignette_layer := CanvasLayer.new()
	vignette_layer.name = "VignetteLayer"
	vignette_layer.layer = 5
	add_child(vignette_layer)
	vignette = Vignette.new()
	vignette.name = "Vignette"
	vignette_layer.add_child(vignette)
	vignette.apply_layout(session.layout)
	session.location_changed.connect(vignette.apply_layout)

	# Panel de loadout (Tab): capa propia por encima del HUD.
	var loadout_layer := CanvasLayer.new()
	loadout_layer.name = "LoadoutLayer"
	loadout_layer.layer = 20
	add_child(loadout_layer)
	loadout_panel = LoadoutPanel.new()
	loadout_panel.name = "LoadoutPanel"
	loadout_layer.add_child(loadout_panel)
	loadout_panel.bind(world)
	inventory_panel = InventoryPanel.new()
	inventory_panel.name = "InventoryPanel"
	loadout_layer.add_child(inventory_panel)
	inventory_panel.bind(world)
	crafting_panel = CraftingPanel.new()
	crafting_panel.name = "CraftingPanel"
	loadout_layer.add_child(crafting_panel)
	crafting_panel.bind(world, session)
	character_sheet = CharacterSheet.new()
	character_sheet.name = "CharacterSheet"
	loadout_layer.add_child(character_sheet)
	character_sheet.bind(world)
	service_panel = ServicePanel.new()
	service_panel.name = "ServicePanel"
	loadout_layer.add_child(service_panel)
	service_panel.bind(world, session)

	var debug_overlay: CanvasLayer = DebugOverlayScene.instantiate()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.visible = false                    # F3 lo muestra; ya no tapa el HUD al abrir el juego
	add_child(debug_overlay)

	var creator_layer := CanvasLayer.new()
	creator_layer.name = "CreatorLayer"
	creator_layer.layer = 40
	add_child(creator_layer)
	creator = CharacterCreator.new()
	creator.name = "CharacterCreator"
	creator_layer.add_child(creator)
	creator.created.connect(_on_character_created)

	var menu_layer := CanvasLayer.new()
	menu_layer.name = "MenuLayer"
	menu_layer.layer = 50
	add_child(menu_layer)
	main_menu = MainMenu.new()
	main_menu.name = "MainMenu"
	menu_layer.add_child(main_menu)
	main_menu.slot_chosen.connect(_on_slot_chosen)
	main_menu.quit_requested.connect(func() -> void: get_tree().quit())
	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	menu_layer.add_child(pause_menu)
	pause_menu.main_menu_requested.connect(_on_main_menu_requested)
	pause_menu.quit_requested.connect(func() -> void:
		session.autosave()
		get_tree().quit())

	TickManager.register(world)
	_was_dead = false
	if _use_menu:
		main_menu.open()
	elif session.needs_character() and OS.get_environment("PIXELCOMBAT_NO_CREATOR").is_empty():
		creator.start()


## Se elige una ranura en el menu: se carga (o se crea) esa partida y, si es nueva, se abre el creador.
func _on_slot_chosen(index: int, fresh: bool) -> void:
	main_menu.close()
	session.load_slot(SaveGame.slot_path(index), fresh)
	_was_dead = false
	if session.needs_character():
		creator.start()


func _on_main_menu_requested() -> void:
	session.autosave()
	pause_menu.close()
	main_menu.open()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game") and world != null and not creator.visible and not main_menu.visible and not pause_menu.visible and not service_panel.is_open and not character_sheet.is_open:
		pause_menu.open()
		get_viewport().set_input_as_handled()


func _on_character_created(character_name: String, class_id: String, appearance: Dictionary) -> void:
	session.create_character(character_name, class_id, appearance)


func _exit_tree() -> void:
	if world != null and TickManager.is_registered(world):
		TickManager.unregister(world)


func _process(_delta: float) -> void:
	if world == null:
		return
	var over_enemy := creator != null and not creator.visible and GameCursor.enemy_under(world, get_global_mouse_position())
	GameCursor.set_mode("attack" if over_enemy else "default")


func _physics_process(_delta: float) -> void:
	if world == null or (creator != null and creator.visible) or (main_menu != null and main_menu.visible) or (pause_menu != null and pause_menu.visible) or (service_panel != null and service_panel.is_open) or (character_sheet != null and character_sheet.is_open):
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

	_update_pickup_hover()
	world.submit_input(_read_input())


## Si el cursor esta sobre algo que se puede coger y el jugador llega, el clic
## izquierdo lo recoge en vez de atacar. La arena resalta lo que hay bajo el cursor.
func _update_pickup_hover() -> void:
	var target := world.target_at(get_global_mouse_position())
	arena.hovered_pickable = target
	hud.pickup_prompt = ""
	if target != null:
		var label := ""
		var verb := "RECOGER"
		if target is LootDrop:
			label = ItemCatalog.display_name((target as LootDrop).item)
		elif target is Interactable:
			label = (target as Interactable).display_name()
			verb = "USAR"
		else:
			label = (target as ResourceNode).display_name()
			verb = "RECOLECTAR"
		hud.pickup_prompt = ("CLIC: %s  %s" % [verb, label]) if world.in_reach(target) else ("%s  (acercate)" % label)
	_click_consumed = _click_consumed and Input.is_action_pressed("attack_m1")
	if target != null and world.in_reach(target) and Input.is_action_just_pressed("attack_m1"):
		_click_consumed = true
	elif target == null and Input.is_action_just_pressed("attack_m1"):
		_click_portal()


## Clic izquierdo sobre una puerta o un PNJ cercano: lo usa (como la tecla de interactuar).
func _click_portal() -> void:
	var portal: Variant = session.nearest_portal()
	if portal == null:
		return
	var reach := float((portal as Dictionary).get("radius", 40.0)) * 1.3
	if get_global_mouse_position().distance_to((portal as Dictionary)["position"]) <= reach:
		session.try_interact()


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

	message.target_pos = mouse_world
	message.actions = {
		"pickup": _click_consumed,
		"basic": Input.is_action_pressed("attack_m2"),
		"dodge": Input.is_action_pressed("dodge"),
		"s1": Input.is_action_pressed("skill_1"),
		"s2": Input.is_action_pressed("skill_2"),
		"s3": Input.is_action_pressed("skill_3"),
		"s4": Input.is_action_pressed("skill_4"),
		"s5": Input.is_action_pressed("skill_5"),
		"ultimate": Input.is_action_pressed("ultimate"),
		"special": Input.is_action_pressed("special"),
		"quick_health": Input.is_action_pressed("quick_health"),
		"quick_resource": Input.is_action_pressed("quick_resource"),
		"debug_level_up": Input.is_action_pressed("debug_level_up"),
		"debug_level_reset": Input.is_action_pressed("debug_level_reset"),
		"debug_class_next": Input.is_action_pressed("debug_class_next"),
	}
	return message
