## Menus y ajustes: ranuras de guardado (varios personajes), menu principal, pausa y reasignacion de teclas.
##
##   godot --headless --path . res://tests/test_menus.tscn
extends Node

const DIR := "user://test_menus"

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_menus (ranuras, menu, pausa y teclas) ==")
	DirAccess.make_dir_recursive_absolute(DIR)
	OS.set_environment("PIXELCOMBAT_SLOT_DIR", DIR)
	OS.set_environment("PIXELCOMBAT_SETTINGS_PATH", DIR + "/settings.json")
	for index: int in range(1, SaveGame.SLOT_COUNT + 1):
		SaveGame.delete(SaveGame.slot_path(index))
	_test_slots()
	_test_settings()
	await _test_menu_screens()
	for index: int in range(1, SaveGame.SLOT_COUNT + 1):
		SaveGame.delete(SaveGame.slot_path(index))
	SaveGame.delete(Settings.path())
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _test_slots() -> void:
	_check(SaveGame.latest_slot() == 0 and not bool(SaveGame.summary(SaveGame.slot_path(1)).get("exists", true)), "sin guardados no hay ranuras ni 'continuar'")
	var world := CombatWorld.new(3)
	var session := GameSession.new(world, "")
	session.load_slot(SaveGame.slot_path(1), true)
	_check(session.needs_character(), "una ranura nueva pide crear personaje")
	session.create_character("Ayla", "mage", {"body": "female"})
	world.player.grant_xp(200)
	session.autosave()
	var other := CombatWorld.new(3)
	var second := GameSession.new(other, "")
	second.load_slot(SaveGame.slot_path(2), true)
	second.create_character("Borin", "warrior", {})
	second.autosave()
	var one := SaveGame.summary(SaveGame.slot_path(1))
	var two := SaveGame.summary(SaveGame.slot_path(2))
	_check(String(one["name"]) == "Ayla" and String(one["class_id"]) == "mage" and int(one["level"]) >= 2, "la ranura 1 guarda a Ayla (mago)")
	_check(String(two["name"]) == "Borin" and String(two["class_id"]) == "warrior" and int(two["level"]) == 1, "la ranura 2 guarda a otro personaje distinto")
	_check(SaveGame.latest_slot() in [1, 2], "'continuar' elige una ranura con personaje")
	var reload := CombatWorld.new(3)
	var again := GameSession.new(reload, "")
	again.load_slot(SaveGame.slot_path(1), false)
	_check(reload.player.character_name == "Ayla" and reload.player.class_id == "mage" and not again.needs_character(), "cargar una ranura restaura su personaje")
	again.load_slot(SaveGame.slot_path(2), false)
	_check(reload.player.character_name == "Borin" and reload.player.class_id == "warrior", "y cambiar de ranura cambia de personaje")
	again.load_slot(SaveGame.slot_path(2), true)
	_check(again.needs_character() and not bool(SaveGame.summary(SaveGame.slot_path(2)).get("created", true)), "'nuevo' sobre una ranura borra al personaje anterior")


func _test_settings() -> void:
	Settings.load_and_apply()
	var before := Settings.key_label("dodge")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_V
	event.pressed = true
	_check(Settings.rebind("dodge", event) and InputMap.action_get_events("dodge").size() == 1, "se reasigna la movilidad a V")
	_check(Settings.key_label("dodge") != before, "y la etiqueta cambia (%s -> %s)" % [before, Settings.key_label("dodge")])
	var swap := InputEventKey.new()
	swap.physical_keycode = KEY_V
	swap.pressed = true
	var old_special := Settings.key_label("special")
	Settings.rebind("special", swap)
	_check(Settings.key_label("special") == "V" and Settings.key_label("dodge") == old_special, "si otra accion ya usaba esa tecla, las dos se intercambian")
	var move := InputEventMouseMotion.new()
	_check(not Settings.rebind("special", move), "un movimiento de raton no es una tecla valida")
	Settings.set_master(0.3)
	Settings.set_sfx(0.5)
	Settings.save()
	Settings.master = 1.0
	Settings.bindings = {}
	Settings.load_and_apply()
	_check(is_equal_approx(Settings.master, 0.3) and is_equal_approx(Settings.sfx, 0.5) and Settings.bindings.has("dodge"), "los ajustes se guardan y se cargan")
	_check(AudioServer.get_bus_index(Settings.SFX_BUS) != -1, "existe el bus de efectos")
	Settings.reset_bindings()
	_check(Settings.key_label("dodge") == before and Settings.key_label("special") == old_special, "restablecer devuelve las teclas de fabrica")
	Settings.set_master(0.8)
	Settings.set_sfx(1.0)


func _test_menu_screens() -> void:
	var menu := MainMenu.new()
	add_child(menu)
	var chosen: Array = []
	menu.slot_chosen.connect(func(index: int, fresh: bool) -> void: chosen.append([index, fresh]))
	menu.open()
	await get_tree().process_frame
	_check(menu.visible and TickManager.is_paused(), "el menu principal se abre y pausa el juego")
	menu._screen = "slots"
	menu._rebuild()
	await get_tree().process_frame
	_check(menu.find_children("*", "Button", true, false).size() >= 4, "la pantalla de personajes tiene botones")
	menu._choose(3, true)
	_check(chosen == [[3, true]], "elegir una ranura emite slot_chosen")
	menu.close()
	_check(not menu.visible and not TickManager.is_paused(), "cerrar el menu devuelve el juego")
	var pause := PauseMenu.new()
	add_child(pause)
	pause.open()
	await get_tree().process_frame
	_check(pause.visible and TickManager.is_paused(), "la pausa detiene la simulacion")
	pause.settings.open()
	await get_tree().process_frame
	_check(pause.settings.visible and pause.settings.find_children("*", "Button", true, false).size() >= Settings.REMAPPABLE.size(), "los ajustes listan todas las teclas reasignables")
	pause.settings._close()
	pause.close()
	_check(not pause.visible and not TickManager.is_paused(), "continuar reanuda")
	menu.queue_free()
	pause.queue_free()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
