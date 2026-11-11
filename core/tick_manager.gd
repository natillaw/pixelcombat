## TickManager — reloj de simulación a tick fijo (autoload "TickManager").
##
## SEPARACIÓN SIMULACIÓN / PRESENTACIÓN
## ------------------------------------
## - SIMULACIÓN: posición, stats, cooldowns, estado, todo lo que afecta al
##   resultado del juego. Vive en objetos [Tickable] y SOLO cambia dentro de
##   [method Tickable._on_tick]. Nunca en _process(delta).
## - PRESENTACIÓN: animaciones, VFX, cámara, UI. Puede usar _process y leer el
##   estado de la simulación, pero nunca escribirlo.
##
## FUNCIONAMIENTO
## --------------
## - Avanza un tick por cada frame de física (_physics_process), a
##   Engine.physics_ticks_per_second (60 Hz en project.godot).
## - [member current_tick] empieza en 0 y vale el número del último tick
##   ejecutado. El primer tick es el 1.
## - El delta que reciben los Tickables es fijo (1.0 / tick_rate), no el delta
##   del motor, para que la simulación sea determinista.
## - Orden determinista: los Tickables se ejecutan en orden de registro.
## - Registrar durante un tick: empieza a recibir ticks en el siguiente.
## - Desregistrar durante un tick: se marca como "pending_removal", termina el
##   tick actual (si aún no lo había recibido, lo recibe) y se retira al final.
## - [method set_paused] detiene la simulación sin pausar la presentación.
##   Este nodo usa PROCESS_MODE_ALWAYS: la pausa del árbol de escena no le
##   afecta; la única fuente de verdad es set_paused().
##
## Este script no tiene class_name para no chocar con el nombre del autoload.
extends Node

const Tickable = preload("res://core/tickable.gd")

## Emitida una vez por tick, después de ejecutar todos los Tickables.
signal tick(tick_number: int, delta: float)
## Emitida al cambiar el estado de pausa.
signal paused_changed(paused: bool)

## Número del último tick ejecutado (0 = ninguno todavía).
var current_tick: int = 0
## true si la simulación está avanzando.
var is_running: bool:
	get:
		return not _paused

var _paused: bool = false
var _in_tick: bool = false
var _tickables: Array[Tickable] = []
var _pending_add: Array[Tickable] = []
var _pending_removal: Array[Tickable] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Corre antes que cualquier otro _physics_process.
	process_physics_priority = -1000


func _physics_process(_engine_delta: float) -> void:
	if _paused:
		return
	step()


## Ticks por segundo de la simulación.
func get_tick_rate() -> int:
	return Engine.physics_ticks_per_second


## Duración fija de un tick en segundos.
func get_tick_delta() -> float:
	return 1.0 / float(get_tick_rate())


## Avanza exactamente un tick. Lo llama _physics_process; es público para
## tests y para re-simulación (reconciliación en P0.4).
func step() -> void:
	current_tick += 1
	var delta: float = get_tick_delta()
	_in_tick = true
	for tickable: Tickable in _tickables:
		tickable._on_tick(current_tick, delta)
	_in_tick = false
	_flush_pending()
	tick.emit(current_tick, delta)


## Registra un Tickable. Devuelve false si ya estaba registrado.
func register(tickable: Tickable) -> bool:
	if tickable == null or is_registered(tickable):
		return false
	if _in_tick:
		_pending_add.append(tickable)
	else:
		_tickables.append(tickable)
	tickable._on_register()
	return true


## Desregistra un Tickable. Devuelve false si no estaba registrado.
func unregister(tickable: Tickable) -> bool:
	if tickable == null:
		return false
	var queued: int = _pending_add.find(tickable)
	if queued != -1:
		_pending_add.remove_at(queued)
		tickable._on_unregister()
		return true
	if not _tickables.has(tickable) or _pending_removal.has(tickable):
		return false
	if _in_tick:
		_pending_removal.append(tickable)
	else:
		_tickables.erase(tickable)
		tickable._on_unregister()
	return true


func is_registered(tickable: Tickable) -> bool:
	return (_tickables.has(tickable) and not _pending_removal.has(tickable)) \
		or _pending_add.has(tickable)


func get_tickable_count() -> int:
	return _tickables.size() - _pending_removal.size() + _pending_add.size()


## Pausa o reanuda la simulación. Al reanudar, el siguiente tick es
## current_tick + 1 (el contador no se reinicia).
func set_paused(paused: bool) -> void:
	if paused == _paused:
		return
	_paused = paused
	paused_changed.emit(_paused)


func is_paused() -> bool:
	return _paused


func _flush_pending() -> void:
	for tickable: Tickable in _pending_removal:
		_tickables.erase(tickable)
		tickable._on_unregister()
	_pending_removal.clear()
	_tickables.append_array(_pending_add)
	_pending_add.clear()
