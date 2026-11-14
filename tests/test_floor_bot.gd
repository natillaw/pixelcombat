## FloorBot sin conocer el mapa: explora con niebla, solo ve lo que tiene a la vista y camina hasta lo que recoge.
##
##   godot --headless --path . --script tests/test_floor_bot.gd
extends SceneTree

const DT := 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _known_count(bot: FloorBot) -> int:
	var total := 0
	for value: int in bot._known:
		total += value
	return total


func _run() -> void:
	print("== test_floor_bot ==")
	var world := CombatWorld.new(20261110)
	var session := GameSession.new(world, "")
	world.player.safe_zone = false
	world.player.set_level(10)
	session._enter(TowerGenerator.generate(2, 20261110, 1, ["clear"]), false)
	var bot := FloorBot.new()
	_check(not bot.knows_map, "por defecto el bot no conoce el mapa")
	var cells := world.grid.cols * world.grid.rows
	var start := world.player.position
	var enemies_total := world.enemies.size()
	for i: int in range(30):
		world.submit_input(bot.decide(world))
		world.step(DT)
	var known_start := _known_count(bot)
	_check(known_start > 20 and known_start < cells / 10, "al empezar solo conoce lo que ve (%d de %d casillas)" % [known_start, cells])
	_check(bot._seen_enemies.size() < enemies_total / 2, "y ve pocos enemigos (%d de %d)" % [bot._seen_enemies.size(), enemies_total])
	for i: int in range(60 * 90):
		var message := bot.decide(world)
		message.actions["quick_health"] = world.player.health < world.player.max_health * 0.4
		world.submit_input(message)
		world.step(DT)
		if not world.player.alive:
			world.player.reset(world.player.position)
	_check(_known_count(bot) > known_start * 3, "tras 90 s ha descubierto mucho mas mapa (%d casillas)" % _known_count(bot))
	_check(world.player.position.distance_to(start) > 250.0, "se ha alejado del inicio explorando (%d px)" % int(world.player.position.distance_to(start)))
	var alive := world.enemies.filter(func(e: EnemySim) -> bool: return e.alive).size()
	_check(alive < enemies_total, "ha peleado con los enemigos que fue encontrando (%d de %d siguen vivos)" % [alive, enemies_total])
	_check(alive > enemies_total / 2, "pero no conoce el mapa: no ha limpiado el piso en 90 s")
	# Un bot que si conoce el mapa sigue funcionando (modo antiguo para comparar).
	var old_bot := FloorBot.new()
	old_bot.knows_map = true
	var message2 := old_bot.decide(world)
	_check(message2 != null, "el modo antiguo sigue disponible")
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
