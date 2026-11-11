## Test headless de predicción y reconciliación (ISSUE P0.4).
##
##   godot --headless --path . --script net/tests/test_reconciliation.gd
##
extends SceneTree

const ClientPredictionScript: GDScript = preload("res://net/prediction.gd")
const ServerReconciliationScript: GDScript = preload("res://net/reconciliation.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const SnapshotScript: GDScript = preload("res://net/snapshot.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_reconciliation (P0.4) ==")

	var speed: float = 100.0
	var delta: float = 1.0 / 60.0
	var peer_id: int = 1

	var prediction = ClientPredictionScript.new()
	prediction.speed = speed

	# 1. Simular 5 ticks de input de movimiento hacia la derecha (Vector2.RIGHT)
	for tick: int in range(1, 6):
		var msg = InputMessageScript.new()
		msg.tick = tick
		msg.peer_id = peer_id
		msg.move_dir = Vector2.RIGHT
		prediction.record_input(msg, delta)

	var expected_pos_unreconciled = Vector2.RIGHT * (speed * delta * 5.0)
	_check(prediction.get_predicted_position().is_equal_approx(expected_pos_unreconciled), "client predicts position after 5 ticks")
	_check(prediction.pending_inputs.size() == 5, "5 pending inputs recorded")

	# 2. Recibir snapshot del servidor para el tick 3 con una posición ligeramente divergente
	var snapshot = SnapshotScript.new()
	snapshot.tick = 3
	snapshot.entity_states[peer_id] = {
		"position": [2.0, 0.0]
	}

	var reconciliation = ServerReconciliationScript.new()
	reconciliation.reconcile(prediction, snapshot, peer_id, speed, delta)

	# Inputs con tick <= 3 deben haber sido descartados
	_check(prediction.pending_inputs.size() == 2, "pending inputs filtered to keep only > tick 3 (ticks 4 and 5)")
	_check(prediction.pending_inputs[0].tick == 4, "first remaining input is tick 4")
	_check(prediction.pending_inputs[1].tick == 5, "second remaining input is tick 5")

	# La posición corregida debe ser: posicion_servidor (2.0) + replay de ticks 4 y 5
	var expected_replayed_pos = Vector2(2.0, 0.0) + Vector2.RIGHT * (speed * delta * 2.0)
	_check(prediction.get_predicted_position().is_equal_approx(expected_replayed_pos), "position correctly reconciled and replayed")

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
