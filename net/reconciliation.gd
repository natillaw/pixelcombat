## Reconciliation — Lógica de reconciliación del cliente con snapshots del servidor (ISSUE P0.4).
class_name ServerReconciliation
extends RefCounted

const ERROR_THRESHOLD: float = 0.5 ## Umbral de tolerancia de error en unidades


func reconcile(
	prediction: Object,
	server_snapshot: Object,
	local_peer_id: int,
	speed: float,
	delta: float
) -> void:
	if not server_snapshot.entity_states.has(local_peer_id):
		return

	var server_data = server_snapshot.entity_states[local_peer_id]
	var server_pos_arr = server_data.get("position", [0, 0])
	var server_pos = Vector2(server_pos_arr[0], server_pos_arr[1])
	var server_tick = server_snapshot.tick

	# Filtrar inputs ya confirmados por el servidor (tick <= server_tick)
	var remaining_inputs: Array = []
	for input_msg in prediction.pending_inputs:
		if input_msg.tick > server_tick:
			remaining_inputs.append(input_msg)
	
	prediction.pending_inputs = remaining_inputs

	# Empezar desde la posición autoritativa del servidor
	var corrected_pos = server_pos

	# Re-simular todos los inputs pendientes no confirmados (re-play)
	for input_msg in prediction.pending_inputs:
		corrected_pos += input_msg.move_dir.normalized() * speed * delta

	# Comprobar si hay discrepancia significativa
	var error = corrected_pos.distance_to(prediction.predicted_position)
	if error > ERROR_THRESHOLD:
		# Corregir la posición predicha con la reconciliación
		prediction.predicted_position = corrected_pos
