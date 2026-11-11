## Encarar al cursor (Fase 1.1).
##
##   godot --headless --path . --script tests/test_facing.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_facing (encarar al cursor) ==")
	_eq(PlayerActor.facing_for(Vector2.RIGHT, "down"), "right", "cursor a la derecha")
	_eq(PlayerActor.facing_for(Vector2.LEFT, "down"), "left", "cursor a la izquierda")
	_eq(PlayerActor.facing_for(Vector2.UP, "right"), "up", "cursor arriba")
	_eq(PlayerActor.facing_for(Vector2.DOWN, "right"), "down", "cursor abajo")
	# Histeresis: cerca de la diagonal conserva el eje actual.
	var near_diagonal := Vector2(1.0, 1.1).normalized()
	_eq(PlayerActor.facing_for(near_diagonal, "right"), "right", "diagonal ligera mantiene horizontal")
	_eq(PlayerActor.facing_for(near_diagonal, "down"), "down", "diagonal ligera mantiene vertical")
	# Pasado el umbral cambia de eje.
	var past_threshold := Vector2(1.0, 1.4).normalized()
	_eq(PlayerActor.facing_for(past_threshold, "right"), "down", "supera la histeresis y cambia a vertical")
	_eq(PlayerActor.facing_for(Vector2(1.4, 1.0).normalized(), "down"), "right", "supera la histeresis y cambia a horizontal")
	# Estado inicial vacio: usa el eje dominante.
	_eq(PlayerActor.facing_for(Vector2(0.3, -1.0).normalized(), ""), "up", "sin estado previo usa el eje dominante")
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _eq(actual: String, expected: String, label: String) -> void:
	_checks += 1
	if actual == expected:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s (esperado %s, obtenido %s)" % [label, expected, actual])
