## Lore y creador de personaje: el lore esta completo, la partida nueva abre el creador
## (pausado), se recorre la historia, se elige nombre/clase/aspecto (sin ropa), se crea al
## personaje con su aspecto y se guarda.
##
##   godot --headless --path . res://tests/test_creator.tscn
extends Node

const MainScene := preload("res://game/main.tscn")
const SAVE_PATH := "user://test_creator_save.json"

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_creator (lore y creador de personaje) ==")
	_check(Lore.errors().is_empty(), "lore.json completo: %s" % str(Lore.errors()))
	_check(Lore.intro_pages().size() >= 5 and String(Lore.tier_blurb(1)["name"]) == TowerCatalog.tier(1)["name"], "la introduccion tiene paginas y el tier 1 coincide con el nombre del bosque")
	SaveGame.delete(SAVE_PATH)
	OS.set_environment("PIXELCOMBAT_NO_SAVE", "")
	OS.set_environment("PIXELCOMBAT_SAVE_PATH", SAVE_PATH)
	OS.set_environment("PIXELCOMBAT_NO_CREATOR", "")
	var main: Node2D = MainScene.instantiate()
	add_child(main)
	await _frames(4)
	var creator: CharacterCreator = main.get("creator")
	var session: GameSession = main.get("session")
	var world: CombatWorld = main.get("world")
	_check(session.needs_character() and creator.visible and TickManager.is_paused(), "una partida nueva abre el creador y pausa el juego")
	var pages := Lore.intro_pages().size()
	for i: int in range(pages):
		creator._next_page()
		await _frames(1)
	_check(creator._stage == "create", "tras la historia se pasa a la creacion")
	var before_skin := String(creator._look["skin"])
	creator._cycle("skin", 1)
	creator._cycle("hair_color", 2)
	creator._cycle("beard", 1)
	_check(String(creator._look["skin"]) != before_skin and String(creator._look["beard"]) == "beard_trimmed", "se cambian piel, pelo y barba")
	creator._cycle("body", 1)
	_check(String(creator._look["body"]) == "female" and String(creator._look["beard"]) == "" and String(creator._appearance()["head"]) == "head_human_female", "el cuerpo femenino quita la barba y usa su cabeza")
	creator._cycle("beard", 1)
	_check(String(creator._look["beard"]) == "", "una mujer no puede ponerse barba")
	creator._select_class("mage")
	creator._name_edit.text = "  Selene  "
	await _frames(2)
	_check(creator._preview.texture != null, "hay vista previa del personaje")
	# La ropa no se elige: la vista previa usa el atuendo basico de la clase.
	var equipment := ClassLook.equipment("mage")
	_check(not creator.get_children().is_empty() and equipment["chest"][0] == "shirt_longsleeve", "el atuendo es el basico de la clase")
	creator._finish()
	await _frames(3)
	var player := world.player
	_check(player.character_created and player.character_name == "Selene" and player.class_id == "mage", "se crea al personaje con su nombre y clase")
	_check(String(player.appearance["body"]) == "female" and String(player.appearance["hair_color"]) == String(creator._look["hair_color"]), "se guarda su aspecto")
	_check(not creator.visible and not TickManager.is_paused() and not session.needs_character(), "el creador se cierra y el juego sigue")
	var frames := ClassLook.frames("mage", {}, player.appearance)
	_check(frames.has_animation("walk_down") and frames != ClassLook.frames("mage"), "el sprite usa el aspecto elegido")
	var loaded := GameSession.new(CombatWorld.new(1), SAVE_PATH)
	session.save_path = SAVE_PATH
	session.autosave()
	loaded = GameSession.new(CombatWorld.new(1), SAVE_PATH)
	_check(not loaded.needs_character() and loaded.world.player.character_name == "Selene" and String(loaded.world.player.appearance["body"]) == "female" and loaded.world.player.class_id == "mage", "el personaje se guarda y al cargar no vuelve a pedirse")
	SaveGame.delete(SAVE_PATH)
	main.queue_free()
	await _frames(2)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	get_tree().quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
