## Narrativa del tier 1: fichas de los pisos 1-10, dialogos de jefes, PNJ por etapa, banderas del mundo,
## cierre del tier y rumores. Los textos viven en data/lore.json; aqui solo se valida y se comprueba que el
## juego los usa.
##
##   godot --headless --path . --script tests/test_narrative.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_narrative (lore del tier 1) ==")
	_test_data()
	_test_session()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_data() -> void:
	for problem: String in Lore.errors() + Lore.narrative_errors():
		print("   problema: %s" % problem)
	_check(Lore.errors().is_empty(), "lore.json basico completo")
	_check(Lore.narrative_errors().is_empty(), "los pisos 1-10, los jefes, los PNJ y los rumores estan completos y sin promesas de geografia")
	for floor_number: int in range(1, 11):
		var info := Lore.floor_info(floor_number)
		_check(not info.is_empty() and Lore.floor_title(floor_number).begins_with("Piso %d - " % floor_number), "piso %d: %s" % [floor_number, Lore.floor_title(floor_number)])
	_check(Lore.floor_title(11) == "Piso 11" and Lore.floor_info(11).is_empty(), "los pisos 11+ no inventan lore todavia")
	var layout := TowerGenerator.generate(3, 1234)
	_check(layout.title == Lore.floor_title(3), "el piso generado lleva el titulo del lore")
	_check(String(Lore.npc_line("tavern", 0)) != String(Lore.npc_line("tavern", 3)), "los PNJ dicen cosas distintas segun el progreso")
	var late := false
	for i: int in range(20):
		late = late or Lore.rumor(i, ["garrick_defeated"]).contains("relicarios sin abrir")
	var early := false
	for i: int in range(20):
		early = early or Lore.rumor(i, []).contains("relicarios sin abrir")
	_check(late and not early, "tras vencer a Garrick aparecen rumores nuevos")
	var intro_text := ""
	for page: Dictionary in Lore.intro_pages():
		intro_text += String(page["text"]).to_lower()
	_check(intro_text.contains("resurgio") and not intro_text.contains("cayo"), "la Aguja reaparece (canon B): no cae del cielo")


func _test_session() -> void:
	var world: CombatWorld = CombatWorldScript.new(21)
	var session := GameSession.new(world, "")
	var messages: Array = []
	session.message.connect(func(text: String) -> void: messages.append(text))
	_check(session.tower.story_stage() == 0, "se empieza en la etapa 0")
	session.tower.complete(5)
	_check(session.tower.story_stage() == 1, "tras el piso 5, etapa 1")
	for floor_number: int in range(1, 10):
		session.tower.complete(floor_number)
	_check(session.tower.story_stage() == 2, "tras el piso 9, etapa 2")
	session.go_to_floor(3)
	_check(not messages.is_empty() and String(messages[messages.size() - 1]).contains(Lore.floor_title(3)), "entrar a un piso muestra su titulo y su frase")
	# Los jefes hablan y dejan banderas.
	session.go_to_floor(5)
	messages.clear()
	var rask := world.add_enemy(&"bandit_rask", world.player.position + Vector2(200, 0))
	rask.state = EnemySim.State.IDLE
	rask.take_damage(1.0)
	_check(messages.has(Lore.boss_line("bandit_rask", "enter")), "Rask habla al despertar")
	rask.take_damage(1.0e9)
	_check(messages.has(Lore.boss_line("bandit_rask", "death")) and session.tower.has_flag("rask_defeated"), "Rask habla al caer y deja su bandera")
	var garrick := world.add_enemy(&"bandit_garrick", world.player.position + Vector2(300, 0))
	garrick.take_damage(1.0e9)
	_check(session.tower.has_flag("garrick_defeated") and session.tower.story_stage() == 3, "vencer a Garrick cierra la historia del tier 1 (etapa 3)")
	var restored := TowerState.from_dict(session.tower.to_dict())
	_check(restored.has_flag("garrick_defeated") and restored.has_flag("rask_defeated") and restored.story_stage() == 3, "las banderas se guardan y se cargan")
	# Cierre del tier al completar el piso 10 por primera vez.
	var fresh := GameSession.new(CombatWorldScript.new(22), "")
	for floor_number: int in range(1, 10):
		fresh.tower.complete(floor_number)
	var closing: Array = []
	fresh.message.connect(func(text: String) -> void: closing.append(text))
	fresh.go_to_floor(10)
	fresh._complete_floor()
	var found := false
	for text: Variant in closing:
		found = found or String(text).contains(String(Lore.tier_closing(1)["title"]))
	_check(found, "al completar el piso 10 sale el cierre del tier")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
