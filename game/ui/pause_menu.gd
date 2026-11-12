## PauseMenu — menu de pausa (Esc): seguir, ajustes, cambiar de personaje y salir.
## Pausa la simulacion mientras esta abierto.
class_name PauseMenu
extends Control

signal main_menu_requested
signal quit_requested

var settings: SettingsPanel
var _was_paused: bool = false
var _body: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	settings = SettingsPanel.new()
	add_child(settings)


func open() -> void:
	if visible:
		return
	_was_paused = TickManager.is_paused()
	TickManager.set_paused(true)
	visible = true
	_build()


func close() -> void:
	if not visible:
		return
	visible = false
	TickManager.set_paused(_was_paused)


func _build() -> void:
	if _body != null:
		_body.queue_free()
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_body)
	move_child(_body, 0)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(shade)
	MenuKit.panel(_body, Rect2(235, 80, 170, 200), "PAUSA")
	MenuKit.button(_body, "Continuar", Rect2(255, 112, 130, 22), close, 10)
	MenuKit.button(_body, "Ajustes", Rect2(255, 142, 130, 22), func() -> void: settings.open(), 10)
	MenuKit.button(_body, "Personajes", Rect2(255, 172, 130, 22), func() -> void: main_menu_requested.emit(), 10)
	MenuKit.button(_body, "Salir del juego", Rect2(255, 202, 130, 22), func() -> void: quit_requested.emit(), 10)
	MenuKit.label(_body, "Esc: volver al juego", Rect2(235, 250, 170, 10), 8, MenuKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and not settings.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
