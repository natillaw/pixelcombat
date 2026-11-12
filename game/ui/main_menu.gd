## MainMenu — menu principal: Continuar, personajes (ranuras de guardado), ajustes y salir.
##
## Es presentacion pura: emite `slot_chosen(index, fresh)` y la sesion carga la partida.
## Pausa la simulacion mientras esta abierto.
class_name MainMenu
extends Control

signal slot_chosen(index: int, fresh: bool)
signal quit_requested

var settings: SettingsPanel
var _screen: String = "main"
var _was_paused: bool = false
var _confirm_delete: int = 0
var _body: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	settings = SettingsPanel.new()
	settings.closed.connect(_rebuild)
	add_child(settings)


func open() -> void:
	SaveGame.migrate_legacy()
	_screen = "main"
	_confirm_delete = 0
	if not visible:
		_was_paused = TickManager.is_paused()
	visible = true
	TickManager.set_paused(true)
	_rebuild()


## Cierra el menu y devuelve el juego al estado de pausa que tenia.
func close() -> void:
	visible = false
	TickManager.set_paused(_was_paused)


func _rebuild() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	move_child(_body, 0)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.02, 0.035, 1.0)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(backdrop)
	var tower := CharacterCreator.TowerArt.new()
	tower.progress = 0.6
	tower.position = Vector2(0, 0)
	tower.size = Vector2(640, 360)
	tower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(tower)
	MenuKit.label(_body, "PIXELCOMBAT", Rect2(0, 36, 640, 30), 32, MenuKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	MenuKit.label(_body, "La Torre de las Cien Puertas", Rect2(0, 72, 640, 14), 12, MenuKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	if _screen == "slots":
		_build_slots()
	else:
		_build_main()


func _build_main() -> void:
	var latest := SaveGame.latest_slot()
	var x := 250.0
	var continue_button := MenuKit.button(_body, "Continuar", Rect2(x, 130, 140, 24), func() -> void: _choose(latest, false), 10)
	continue_button.disabled = latest == 0
	if latest > 0:
		var info := SaveGame.summary(SaveGame.slot_path(latest))
		MenuKit.label(_body, "%s - %s nivel %d" % [info["name"], String(info["class_id"]).capitalize(), info["level"]], Rect2(x - 40.0, 156, 220, 10), 8, MenuKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	MenuKit.button(_body, "Personajes", Rect2(x, 176, 140, 24), func() -> void: _screen = "slots"; _rebuild(), 10)
	MenuKit.button(_body, "Ajustes", Rect2(x, 206, 140, 24), func() -> void: settings.open(), 10)
	MenuKit.button(_body, "Salir", Rect2(x, 236, 140, 24), func() -> void: quit_requested.emit(), 10)
	move_child(settings, get_child_count() - 1)


func _build_slots() -> void:
	MenuKit.label(_body, "Elige una ranura: vacia = personaje nuevo", Rect2(0, 100, 640, 12), 8, MenuKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	for index: int in range(1, SaveGame.SLOT_COUNT + 1):
		var x := 20.0 + float(index - 1) * 204.0
		var card := Rect2(x, 122, 196, 150)
		MenuKit.panel(_body, card, "RANURA %d" % index)
		var info := SaveGame.summary(SaveGame.slot_path(index))
		if bool(info.get("exists", false)) and bool(info.get("created", false)):
			MenuKit.label(_body, String(info["name"]), Rect2(x + 8, 146, 180, 14), 12, MenuKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			MenuKit.label(_body, "%s - nivel %d" % [String(info["class_id"]).capitalize(), info["level"]], Rect2(x + 8, 166, 180, 12), 8, MenuKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			MenuKit.label(_body, "Torre: piso %d" % info["floor"], Rect2(x + 8, 180, 180, 12), 8, MenuKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			MenuKit.button(_body, "Jugar", Rect2(x + 28, 206, 140, 20), func() -> void: _choose(index, false))
			var armed := _confirm_delete == index
			MenuKit.button(_body, "Seguro? Borrar" if armed else "Borrar", Rect2(x + 28, 232, 140, 18), func() -> void: _delete(index))
		else:
			MenuKit.label(_body, "Vacia", Rect2(x + 8, 160, 180, 14), 12, MenuKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
			MenuKit.button(_body, "Nuevo personaje", Rect2(x + 28, 206, 140, 20), func() -> void: _choose(index, true))
	MenuKit.button(_body, "Volver", Rect2(250, 292, 140, 22), func() -> void: _screen = "main"; _rebuild())


func _delete(index: int) -> void:
	if _confirm_delete != index:
		_confirm_delete = index
	else:
		SaveGame.delete(SaveGame.slot_path(index))
		_confirm_delete = 0
	_rebuild()


func _choose(index: int, fresh: bool) -> void:
	if index <= 0:
		return
	slot_chosen.emit(index, fresh)
