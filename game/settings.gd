## Settings — ajustes del jugador: volumen (general, efectos y musica), pantalla completa, teclas y accesibilidad.
##
## Se guardan en user://settings.json (PIXELCOMBAT_SETTINGS_PATH lo cambia, p. ej. en tests) y se
## aplican al arrancar (el autoload InputSetup llama a `load_and_apply`). Las teclas se reasignan
## sobre el InputMap, asi que el resto del juego sigue usando las acciones de siempre.
class_name Settings
extends RefCounted

const DEFAULT_PATH := "user://settings.json"
const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

## Acciones que se pueden reasignar, con su nombre en pantalla.
const REMAPPABLE := [
	["move_up", "Mover arriba"], ["move_down", "Mover abajo"], ["move_left", "Mover izquierda"], ["move_right", "Mover derecha"],
	["attack_m1", "Interactuar (clic)"], ["attack_m2", "Ataque basico (clic)"], ["dodge", "Defensa / movilidad"],
	["skill_1", "Skill 1"], ["skill_2", "Skill 2"], ["skill_3", "Skill 3"], ["special", "Special"], ["ultimate", "Ultimate"],
	["quick_health", "Objeto 1 (pocion)"], ["quick_resource", "Objeto 2 (elixir)"], ["interact", "Interactuar (tecla)"], ["toggle_inventory", "Inventario"], ["toggle_character", "Personaje"], ["toggle_loadout", "Libro de skills"],
]

static var master: float = 0.8
static var sfx: float = 1.0
static var fullscreen: bool = false
## Musica (bus aparte, ver MusicDirector).
static var music: float = 0.7
## Accesibilidad / comodidad (solo presentacion; no cambian ningun resultado de la simulacion).
## Intensidad de la sacudida de camara (0 = sin sacudida).
static var shake: float = 1.0
## Golpe de zoom de la camara al pegar, recibir golpes o morir.
static var zoom_punch: bool = true
## Pausa de impacto (hit-stop) al pegar y recibir golpes.
static var hit_stop: bool = true
## Camara lenta al morir (jugador y jefes).
static var slow_motion: bool = true
## Destellos de pantalla: borde rojo al recibir dano y al tener poca vida.
static var damage_flash: bool = true
## Solo pruebas: milisegundos de retraso del input para sentir el juego con latencia (0 = ninguno).
static var sim_latency_ms: int = 0
## accion -> {"type": "key"|"mouse", "code": int}; solo las que difieren de las de fabrica.
static var bindings: Dictionary = {}
static var _defaults: Dictionary = {}


static func path() -> String:
	var custom := OS.get_environment("PIXELCOMBAT_SETTINGS_PATH")
	return custom if not custom.is_empty() else DEFAULT_PATH


static func load_and_apply() -> void:
	_remember_defaults()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path())) if FileAccess.file_exists(path()) else null
	if parsed is Dictionary:
		master = clampf(float((parsed as Dictionary).get("master", master)), 0.0, 1.0)
		sfx = clampf(float((parsed as Dictionary).get("sfx", sfx)), 0.0, 1.0)
		fullscreen = bool((parsed as Dictionary).get("fullscreen", false))
		music = clampf(float((parsed as Dictionary).get("music", music)), 0.0, 1.0)
		shake = clampf(float((parsed as Dictionary).get("shake", shake)), 0.0, 1.0)
		zoom_punch = bool((parsed as Dictionary).get("zoom_punch", zoom_punch))
		hit_stop = bool((parsed as Dictionary).get("hit_stop", hit_stop))
		slow_motion = bool((parsed as Dictionary).get("slow_motion", slow_motion))
		damage_flash = bool((parsed as Dictionary).get("damage_flash", damage_flash))
		sim_latency_ms = clampi(int((parsed as Dictionary).get("sim_latency_ms", sim_latency_ms)), 0, 400)
		bindings = {}
		var saved: Dictionary = (parsed as Dictionary).get("bindings", {})
		for action: String in saved:
			var entry: Variant = saved[action]
			if InputMap.has_action(action) and entry is Dictionary and ((entry as Dictionary).get("type") == "key" or (entry as Dictionary).get("type") == "mouse"):
				bindings[action] = {"type": String(entry["type"]), "code": int(entry["code"])}
	apply()


static func save() -> void:
	var file := FileAccess.open(path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"master": master, "sfx": sfx, "music": music, "fullscreen": fullscreen, "shake": shake, "zoom_punch": zoom_punch, "hit_stop": hit_stop, "slow_motion": slow_motion, "damage_flash": damage_flash, "sim_latency_ms": sim_latency_ms, "bindings": bindings}, "\t"))


static func apply() -> void:
	_ensure_sfx_bus()
	AudioServer.set_bus_volume_db(0, _to_db(master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), _to_db(sfx))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MUSIC_BUS), _to_db(music))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	for action: String in bindings:
		_set_event(action, _event_from(bindings[action]))


static func set_master(value: float) -> void:
	master = clampf(value, 0.0, 1.0)
	apply()


static func set_music(value: float) -> void:
	music = clampf(value, 0.0, 1.0)
	apply()


static func set_sfx(value: float) -> void:
	sfx = clampf(value, 0.0, 1.0)
	apply()


static func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()


## Reasigna `action` a la tecla o boton de `event`. false si el evento no sirve (p. ej. un movimiento de raton).
static func rebind(action: String, event: InputEvent) -> bool:
	var entry := _entry_from(event)
	if entry.is_empty() or not InputMap.has_action(action):
		return false
	# Si otra accion ya usa esa tecla, intercambian (no queda ninguna sin tecla ni duplicada).
	for other: Array in REMAPPABLE:
		var other_id := String(other[0])
		if other_id != action and _entry_matches(other_id, entry):
			var previous := _first_entry(action)
			if previous.is_empty():
				bindings.erase(other_id)
				InputMap.action_erase_events(other_id)
			else:
				bindings[other_id] = previous
				_set_event(other_id, _event_from(previous))
	bindings[action] = entry
	_set_event(action, _event_from(entry))
	save()
	return true


static func reset_bindings() -> void:
	bindings = {}
	for action: String in _defaults:
		InputMap.action_erase_events(action)
		for event: InputEvent in _defaults[action]:
			InputMap.action_add_event(action, event)
	save()


## Texto de la tecla de una accion ("W", "Espacio", "Clic izq.").
static func key_label(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code) if DisplayServer.get_name() != "headless" else code)
		if event is InputEventMouseButton:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					return "Clic izq."
				MOUSE_BUTTON_RIGHT:
					return "Clic der."
				MOUSE_BUTTON_MIDDLE:
					return "Clic central"
				_:
					return "Raton %d" % event.button_index
	return "-"


## Version corta para el HUD ("LMB", "RMB", "SPC", "Q").
static func short_label(action: String) -> String:
	var text := key_label(action)
	match text:
		"Clic izq.":
			return "LMB"
		"Clic der.":
			return "RMB"
		"Clic central":
			return "MMB"
		"Space":
			return "SPC"
	return text.to_upper()


static func _to_db(linear: float) -> float:
	return -80.0 if linear <= 0.001 else linear_to_db(linear)


static func _ensure_sfx_bus() -> void:
	for bus_name: String in [SFX_BUS, MUSIC_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, "Master")


static func _remember_defaults() -> void:
	if not _defaults.is_empty():
		return
	for pair: Array in REMAPPABLE:
		var action := String(pair[0])
		var copy: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			copy.append(event.duplicate())
		_defaults[action] = copy


static func _entry_from(event: InputEvent) -> Dictionary:
	if event is InputEventKey and (event as InputEventKey).pressed:
		var code: int = (event as InputEventKey).physical_keycode if (event as InputEventKey).physical_keycode != 0 else (event as InputEventKey).keycode
		return {"type": "key", "code": code}
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		return {"type": "mouse", "code": (event as InputEventMouseButton).button_index}
	return {}


static func _event_from(entry: Dictionary) -> InputEvent:
	if String(entry["type"]) == "key":
		var key := InputEventKey.new()
		key.physical_keycode = int(entry["code"])
		return key
	var button := InputEventMouseButton.new()
	button.button_index = int(entry["code"])
	return button


static func _first_entry(action: String) -> Dictionary:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return {"type": "key", "code": (event as InputEventKey).physical_keycode}
		if event is InputEventMouseButton:
			return {"type": "mouse", "code": (event as InputEventMouseButton).button_index}
	return {}


static func _entry_matches(action: String, entry: Dictionary) -> bool:
	var probe := _event_from(entry)
	for event: InputEvent in InputMap.action_get_events(action):
		if event.is_match(probe):
			return true
	return false


static func _set_event(action: String, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
