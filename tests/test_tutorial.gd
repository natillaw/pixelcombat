## Pistas del tutorial: datos validos, una sola vez y teclas rellenadas.
##
##   godot --headless --path . --script tests/test_tutorial.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_tutorial ==")
	_check(TutorialHints.tips().size() >= 4, "hay pistas")
	_check(TutorialHints.validate().is_empty(), "el archivo de datos es valido: %s" % str(TutorialHints.validate()))
	var tip := TutorialHints.next_tip("city", {})
	_check(not tip.is_empty() and String(tip["id"]) == "move", "la ciudad propone la pista de movimiento")
	var flags: Dictionary = {TutorialHints.flag_for(tip): true}
	_check(TutorialHints.next_tip("city", flags).is_empty(), "una pista vista no se repite")
	_check(TutorialHints.next_tip("no_existe", {}).is_empty(), "disparador sin pistas")
	var text := TutorialHints.render("Pulsa {a} y {b}.", func(action: String) -> String: return action.to_upper())
	_check(text == "Pulsa A y B.", "las teclas se rellenan: %s" % text)
	for entry: Variant in TutorialHints.tips():
		var rendered := TutorialHints.render(String((entry as Dictionary)["text"]), func(action: String) -> String: return Settings.short_label(action))
		_check(not rendered.contains("{"), "%s: todas las acciones existen" % String((entry as Dictionary)["id"]))
	for trigger: String in TutorialHints.TRIGGERS:
		_check(not TutorialHints.next_tip(trigger, {}).is_empty(), "el disparador '%s' tiene pista" % trigger)
	var food_tip := TutorialHints.render(String(TutorialHints.next_tip("low_health", {})["text"]), func(action: String) -> String: return Settings.short_label(action))
	_check(food_tip.contains(Settings.short_label("quick_food")) and food_tip.contains(Settings.short_label("quick_health")), "la pista de poca vida nombra las teclas de comida y pocion")
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
