## PlaytestLog: no escribe si esta desactivado, registra entradas/completados/muertes con tiempos y se corta.
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	var path := "user://test_playtest_log.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var log := PlaytestLog.new()
	log.path = path
	log.record("enter", 1, 1)
	_check(log.events.is_empty() and not FileAccess.file_exists(path), "desactivado no registra ni escribe")
	log.enabled = true
	log.record("enter", 3, 2)
	log.record("complete", 3, 3, {"xp": 120})
	log.record("death", 4, 3)
	_check(log.events.size() == 3, "registra tres eventos")
	_check(float((log.events[1] as Dictionary)["seconds_in_floor"]) >= 0.0 and int((log.events[1] as Dictionary)["xp"]) == 120, "el completado lleva segundos y XP")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Array and (parsed as Array).size() == 3 and String(((parsed as Array)[2] as Dictionary)["kind"]) == "death", "el archivo JSON contiene los eventos")
	for i: int in range(PlaytestLog.MAX_EVENTS + 20):
		log.record("enter", 1, 1)
	_check(log.events.size() == PlaytestLog.MAX_EVENTS, "el registro se corta en %d eventos" % PlaytestLog.MAX_EVENTS)
	var session := GameSession.new(CombatWorld.new(3), "")
	_check(not session.playtest_log.enabled, "sin guardado real el registro de la sesion esta desactivado")
	DirAccess.remove_absolute(path)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)
