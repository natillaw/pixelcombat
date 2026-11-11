## Debug overlay (solo debug, no es UI final). F3 lo muestra/oculta.
##
## Es presentación pura: lee el estado del TickManager en _process y nunca lo
## modifica. El autoload se busca por ruta para que la escena también se pueda
## instanciar en tests headless sin depender de la resolución de nombres global.
class_name DebugOverlay
extends CanvasLayer

const TOGGLE_ACTION: StringName = &"toggle_debug_overlay"

@onready var _label: Label = $Label

var _tick_manager: Node = null

## Ticks contados en la ventana de medición actual (para ticks/s reales).
var _window_start_tick: int = 0
var _window_start_usec: int = 0
var _measured_tps: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tick_manager = get_node_or_null("/root/TickManager")
	if _tick_manager != null:
		_window_start_tick = _tick_manager.current_tick
	_window_start_usec = Time.get_ticks_usec()


func _input(event: InputEvent) -> void:
	if not InputMap.has_action(TOGGLE_ACTION):
		return
	if event.is_action_pressed(TOGGLE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	_update_measured_tps()
	if not visible:
		return

	var net_status := "Offline"
	var net_manager := get_node_or_null("/root/NetworkManager")
	if net_manager != null:
		if net_manager.is_server():
			net_status = "Server (Host)"
		elif net_manager.is_client():
			net_status = "Client (ID: %d)" % net_manager.get_local_id()

	if _tick_manager == null:
		_tick_manager = get_node_or_null("/root/TickManager")
	if _tick_manager == null:
		_label.text = "tick: 0\nTickManager: not found\nFPS: %d\nnet: %s" % [Engine.get_frames_per_second(), net_status]
		return

	_label.text = "tick: %d\ntick delta: %.4f s (%d Hz)\nticks/s: %.1f\nFPS: %d\npaused: %s\nnet: %s" % [
		_tick_manager.current_tick,
		_tick_manager.get_tick_delta(),
		_tick_manager.get_tick_rate(),
		_measured_tps,
		Engine.get_frames_per_second(),
		"yes" if _tick_manager.is_paused() else "no",
		net_status
	]


func _update_measured_tps() -> void:
	var elapsed_usec: int = Time.get_ticks_usec() - _window_start_usec
	if elapsed_usec < 1_000_000:
		return
	if _tick_manager != null:
		var ticks: int = _tick_manager.current_tick - _window_start_tick
		_measured_tps = float(ticks) * 1_000_000.0 / float(elapsed_usec)
		_window_start_tick = _tick_manager.current_tick
	_window_start_usec = Time.get_ticks_usec()
