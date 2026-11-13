## Accesibilidad: los ajustes de sacudida, zoom, hit-stop y destellos se guardan y se respetan.
##
##   godot --headless --path . --script tests/test_accessibility.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_accessibility ==")
	OS.set_environment("PIXELCOMBAT_SETTINGS_PATH", "user://test_access_settings.json")
	var arena := Arena.new()
	# Por defecto todo esta activado.
	Settings.shake = 1.0
	Settings.zoom_punch = true
	arena.shake(5.0, 0.2)
	arena.punch_zoom(0.05)
	_check(arena._shake_time > 0.0, "con la sacudida activada la camara se sacude")
	_check(arena._punch > 0.0, "con el zoom activado hay golpe de zoom")
	var quiet := Arena.new()
	Settings.shake = 0.0
	Settings.zoom_punch = false
	quiet.shake(5.0, 0.2)
	quiet.punch_zoom(0.05)
	_check(quiet._shake_time == 0.0, "con la sacudida a 0 la camara no se mueve")
	_check(quiet._punch == 0.0, "con el zoom desactivado no hay golpe de zoom")
	var half := Arena.new()
	Settings.shake = 0.5
	half.shake(8.0, 0.2)
	_check(is_equal_approx(half._shake_strength, 4.0), "la intensidad escala con el ajuste (8 -> %.1f)" % half._shake_strength)
	# Guardado y carga.
	Settings.shake = 0.25
	Settings.zoom_punch = false
	Settings.hit_stop = false
	Settings.slow_motion = false
	Settings.damage_flash = false
	Settings.music = 0.3
	Settings.sim_latency_ms = 80
	Settings.fractional_scale = true
	Settings.save()
	Settings.shake = 1.0
	Settings.zoom_punch = true
	Settings.hit_stop = true
	Settings.slow_motion = true
	Settings.damage_flash = true
	Settings.music = 0.7
	Settings.sim_latency_ms = 0
	Settings.load_and_apply()
	_check(is_equal_approx(Settings.shake, 0.25) and not Settings.zoom_punch and not Settings.hit_stop and not Settings.slow_motion and not Settings.damage_flash, "los ajustes de accesibilidad se guardan y se cargan")
	_check(is_equal_approx(Settings.music, 0.3) and Settings.sim_latency_ms == 80, "la musica y la latencia simulada tambien")
	_check(Settings.fractional_scale, "el escalado ajustado se guarda y se carga")
	_check(AudioServer.get_bus_index(Settings.MUSIC_BUS) != -1, "existe el bus de musica")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_access_settings.json"))
	# Restablece para no ensuciar otras suites.
	Settings.shake = 1.0
	Settings.zoom_punch = true
	Settings.hit_stop = true
	Settings.slow_motion = true
	Settings.damage_flash = true
	Settings.music = 0.7
	Settings.sim_latency_ms = 0
	Settings.fractional_scale = false
	Settings.apply()
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
