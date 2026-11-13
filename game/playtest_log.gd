## PlaytestLog — registro local de la partida para el playtest humano (docs/NOTAS_PLAYTEST.md).
##
## Guarda en `user://playtest_log.json` una lista de eventos {kind, floor, level, t, ...}:
## entrada a un piso, piso completado (con los segundos que tardo) y muertes (con la causa).
## Solo escribe la sesion con guardado real (no en tests ni capturas) y se corta a 400 eventos.
## No toca la simulacion: es presentacion pura.
class_name PlaytestLog
extends RefCounted

const PATH := "user://playtest_log.json"
const MAX_EVENTS := 400

var enabled: bool = false
var path: String = PATH
var events: Array = []
var _entered_at: float = 0.0


func record(kind: String, floor_number: int, level: int, extra: Dictionary = {}) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = {"kind": kind, "floor": floor_number, "level": level, "t": snappedf(now, 0.1)}
	if kind == "enter":
		_entered_at = now
	elif kind == "complete" or kind == "death":
		entry["seconds_in_floor"] = snappedf(now - _entered_at, 0.1)
	entry.merge(extra, true)
	events.append(entry)
	while events.size() > MAX_EVENTS:
		events.pop_front()
	_flush()


func _flush() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(events, "\t"))
	file.close()
