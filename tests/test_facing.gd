## Orientacion del personaje: camina hacia donde va; el cursor solo manda al atacar.
##
##   godot --headless --path . --script tests/test_facing.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_facing ==")
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
	# Caminar: manda el movimiento, no el cursor (cursor a la izquierda, camina a la derecha).
	_eq(PlayerActor.facing_for_movement(Vector2(120, 0), "left"), "right", "camina a la derecha mirando a la derecha")
	_eq(PlayerActor.facing_for_movement(Vector2(-120, 0), "right"), "left", "camina a la izquierda mirando a la izquierda")
	_eq(PlayerActor.facing_for_movement(Vector2(0, -120), "left"), "up", "camina arriba mirando arriba")
	_eq(PlayerActor.facing_for_movement(Vector2(3, 2), "left"), "left", "quieto conserva la direccion")
	_eq(PlayerActor.facing_for_movement(Vector2.ZERO, "up"), "up", "sin velocidad no cambia")
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
