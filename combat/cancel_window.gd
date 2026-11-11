## CancelWindow — Ventana de cancelación de acciones (ISSUE P1.4).
class_name CancelWindow
extends RefCounted

var start_time: float = 0.0
var end_time: float = 0.0


func _init(p_start: float = 0.0, p_end: float = 0.0) -> void:
	start_time = p_start
	end_time = p_end


func is_in_window(elapsed_time: float) -> bool:
	return elapsed_time >= start_time and elapsed_time <= end_time
