## Latencia simulada: el input llega N ticks tarde, en orden y sin perderse.
##
##   godot --headless --path . --script tests/test_input_delay.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _message(tick: int) -> InputMessage:
	var message := InputMessage.new()
	message.tick = tick
	message.move_dir = Vector2.RIGHT
	message.actions = {"basic": true}
	return message


func _run() -> void:
	print("== test_input_delay ==")
	_check(InputDelay.ticks_for(0) == 0 and InputDelay.ticks_for(100) == 6 and InputDelay.ticks_for(300) == 18, "ms -> ticks (100 ms = 6 ticks)")
	var plain := InputDelay.new()
	var direct := _message(5)
	_check(plain.push(direct, 0) == direct, "sin latencia el mensaje pasa tal cual")
	var delayed := InputDelay.new()
	var out_ticks: Array = []
	var neutral_ok := true
	for tick: int in range(1, 11):
		var out := delayed.push(_message(tick), 3)
		out_ticks.append(out.tick)
		if tick <= 3 and (out.move_dir != Vector2.ZERO or not out.actions.is_empty()):
			neutral_ok = false
	_check(neutral_ok, "mientras no ha llegado nada, el jugador no se mueve ni actua")
	_check(out_ticks == [1, 2, 3, 1, 2, 3, 4, 5, 6, 7], "con 3 ticks de retraso la sim recibe el mensaje de hace 3 ticks (%s)" % str(out_ticks))
	# Si baja la latencia, no se acumulan mensajes viejos ni se reordenan.
	var shrink := InputDelay.new()
	for tick: int in range(1, 9):
		shrink.push(_message(tick), 6)
	var after := shrink.push(_message(9), 2)
	_check(after.tick >= 6, "al bajar el retraso salta a mensajes mas recientes (tick %d)" % after.tick)
	var next := shrink.push(_message(10), 2)
	_check(next.tick > after.tick, "y sigue en orden (%d -> %d)" % [after.tick, next.tick])
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
