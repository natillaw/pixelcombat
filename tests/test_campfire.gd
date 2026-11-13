## Hoguera de descanso: una por piso (menos el 1), alcanzable, y cura una vez.
##
##   godot --headless --path . --script tests/test_campfire.gd
extends SceneTree

const CombatWorldScript := preload("res://game/sim/combat_world.gd")
const DT := 1.0 / 60.0
const SEED := 20261110

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _campfires(layout: FloorLayout) -> Array:
	return layout.interactables.filter(func(o: Dictionary) -> bool: return String(o["kind"]) == "campfire")


func _run() -> void:
	print("== test_campfire ==")
	for floor_number: int in range(1, 11):
		var layout := TowerGenerator.generate(floor_number, SEED, 1)
		var fires := _campfires(layout)
		_check(fires.size() == (0 if floor_number == 1 else 1), "piso %d: %d hogueras" % [floor_number, fires.size()])
		var again := _campfires(TowerGenerator.generate(floor_number, SEED, 1))
		_check(again.size() == fires.size() and (fires.is_empty() or fires[0]["position"] == again[0]["position"]), "piso %d: misma semilla, misma hoguera" % floor_number)

	var session := GameSession.new(CombatWorldScript.new(11), "")
	session.tower.complete(1)
	session.world.player.safe_zone = false
	session.world.player.set_level(10)
	session._enter(TowerGenerator.generate(2, SEED, 1), false)
	session.tower.visit(2)
	var world := session.world
	var fire: Interactable = world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "campfire")[0]
	for enemy: EnemySim in world.enemies.duplicate():
		if enemy.alive:
			enemy.take_damage(1.0e9)
	var player := world.player
	player.position = fire.position + Vector2(40, 0)
	world.step(DT)
	player.health = player.max_health * 0.2
	var before := player.health
	world.try_click(fire.position)
	for i: int in range(400):
		world.step(DT)
	_check(fire.done, "tras canalizar, la hoguera queda gastada")
	_check(absf(player.health - minf(player.max_health, before + player.max_health * CombatWorldScript.CAMPFIRE_HEAL)) < player.max_health * 0.05, "cura %d%% de la vida maxima" % int(CombatWorldScript.CAMPFIRE_HEAL * 100.0))
	player.health = player.max_health * 0.2
	world.try_click(fire.position)
	for i: int in range(400):
		world.step(DT)
	_check(player.health < player.max_health * 0.4, "una hoguera gastada no vuelve a curar (queda en %d%%)" % int(player.health / player.max_health * 100.0))
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
