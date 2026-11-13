## Ninguna tecla de fabrica sirve a dos acciones (antes R era la skill 3 y ademas reiniciaba el piso).
##
##   godot --headless --path . --script tests/test_input_conflicts.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_input_conflicts ==")
	var owners: Dictionary = {}
	var conflicts: Array[String] = []
	for action: String in InputSetup.ACTIONS:
		for key: int in InputSetup.ACTIONS[action]:
			if owners.has(key):
				conflicts.append("%s y %s comparten %s" % [owners[key], action, OS.get_keycode_string(key)])
			else:
				owners[key] = action
	_check(conflicts.is_empty(), "ninguna tecla de fabrica esta en dos acciones (%s)" % str(conflicts))
	# El reinicio del patio no puede estar en ninguna tecla de skill ni de objeto.
	for action: String in ["skill_1", "skill_2", "skill_3", "special", "ultimate", "dodge", "quick_health", "quick_resource"]:
		for key: int in InputSetup.ACTIONS[action]:
			_check(not (InputSetup.ACTIONS["restart_training"] as Array).has(key), "reiniciar no comparte tecla con %s" % action)
	# Y las acciones remapeables del menu existen todas.
	for pair: Array in Settings.REMAPPABLE:
		_check(InputSetup.ACTIONS.has(String(pair[0])), "la accion remapeable %s existe" % String(pair[0]))
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
