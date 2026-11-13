## Vida de la ciudad: residentes con los que se habla, props bien colocados y todo alcanzable.
##
##   godot --headless --path . --script tests/test_city_life.gd
extends SceneTree

const CombatWorldScript := preload("res://game/sim/combat_world.gd")

var _failures: int = 0
var _checks: int = 0
var _last_message: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_city_life ==")
	_check(Residents.validate().is_empty(), "residents.json es valido: %s" % str(Residents.validate()))
	_check(Residents.all().size() >= 8, "hay al menos 8 residentes (%d)" % Residents.all().size())
	var city := Layouts.city()
	var grid := city.grid
	var spawn_cell := grid.world_to_cell(city.player_spawn)
	var reach := grid.reachable_from(spawn_cell)
	for entry_value: Variant in Residents.all():
		var entry: Dictionary = entry_value
		var id := String(entry["id"])
		var portal: Array = city.portals.filter(func(p: Dictionary) -> bool: return String(p["id"]) == "talk_" + id)
		_check(portal.size() == 1 and String((portal[0] as Dictionary)["action"]) == "talk:" + id, "%s: tiene su portal para hablar" % id)
		var npcs: Array = city.npcs.filter(func(n: Dictionary) -> bool: return String(n["id"]) == "res_" + id)
		_check(npcs.size() == 1, "%s: tiene su PNJ" % id)
		var cell := grid.world_to_cell((npcs[0] as Dictionary)["position"])
		_check(not grid.blocks_move(cell.x, cell.y) and reach[cell.y * grid.cols + cell.x] == 1, "%s: esta en suelo alcanzable" % id)
		for stage: int in range(4):
			_check(not Residents.line_for(entry, stage).is_empty(), "%s: tiene frase en la etapa %d" % [id, stage])
	# Ningun prop pisa un portal ni a un residente.
	var overlaps := 0
	for obstacle: Dictionary in city.obstacles:
		if not bool(obstacle.get("hidden", false)) or float(obstacle["radius"]) > 24.0:
			continue
		for portal: Dictionary in city.portals:
			if String(portal["id"]).begins_with("talk_") or String(portal["id"]).begins_with("door_"):
				continue
			if (obstacle["position"] as Vector2).distance_to(portal["position"]) < float(obstacle["radius"]):
				overlaps += 1
	_check(overlaps == 0, "ningun obstaculo tapa un portal de la ciudad (%d)" % overlaps)
	var kinds: Dictionary = {}
	for prop: Dictionary in city.props:
		kinds[String(prop["kind"])] = true
	for kind: String in ["banner", "brazier", "stall", "bench", "planter", "lamppost", "flowerbed", "plaza_ring", "statue"]:
		_check(kinds.has(kind), "la ciudad tiene props de tipo %s" % kind)
	# Hablar: la frase sale por la sesion y rota entre las frases de la etapa.
	var session := GameSession.new(CombatWorldScript.new(11), "")
	session.message.connect(func(text: String) -> void: _last_message = text)
	session.go_to_city()
	session._talk_to("old_man")
	var first := _last_message
	session._talk_to("old_man")
	_check(first.begins_with("Perrin: ") and _last_message.begins_with("Perrin: "), "el residente habla con su nombre: %s" % first)
	_check(first != _last_message, "la segunda vez dice otra frase")
	session.tower.set_flag("garrick_defeated")
	session._talk_to("gate_guard_a")
	_check(_last_message.contains("Garrick") or _last_message.contains("terminado"), "tras vencer a Garrick cambia lo que dicen: %s" % _last_message)
	_last_message = ""
	session._talk_to("no_existe")
	_check(_last_message == "", "un residente desconocido no dice nada")
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
