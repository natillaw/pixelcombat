## Prediction — Lógica de predicción del lado del cliente (ISSUE P0.4).
class_name ClientPrediction
extends RefCounted

var pending_inputs: Array = []
var predicted_position: Vector2 = Vector2.ZERO
var speed: float = 200.0


func record_input(input_msg: Object, delta: float) -> void:
	pending_inputs.append(input_msg)
	# Aplicar movimiento predicho inmediatamente
	predicted_position += input_msg.move_dir.normalized() * speed * delta


func get_predicted_position() -> Vector2:
	return predicted_position
