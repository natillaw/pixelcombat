## Fuzz de la simulacion: inputs aleatorios de las 4 clases contra pisos reales (incluido el del jefe) y se vigilan
## los invariantes: vida y recurso dentro de rango, posiciones finitas y dentro del mapa, sin enemigos ni proyectiles
## fuera de limites, y ningun error de script.
##
##   godot --headless --path . --script tests/test_sim_fuzz.gd
extends SceneTree

const DT := 1.0 / 60.0
const TICKS := 2400

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_sim_fuzz ==")
	for class_id: String in ClassCatalog.all_ids():
		for floor_number: int in [1, 5, 10]:
			_fuzz(class_id, floor_number)
	# Determinismo: el mismo input sobre el mismo piso deja exactamente el mismo estado (base del PvP y de la red).
	for class_id: String in ["warrior", "mage"]:
		var first := _fuzz(class_id, 5)
		var second := _fuzz(class_id, 5)
		_check(first == second, "%s: dos partidas con el mismo input acaban igual (%s)" % [class_id, first])
	# Duelos (PvP): los dos jugadores con input aleatorio, todas las parejas de clases.
	var ids: Array = ClassCatalog.all_ids()
	for a: String in ids:
		for b: String in ids:
			_fuzz_duel(a, b)
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _fuzz(class_id: String, floor_number: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s%d" % [class_id, floor_number])
	var world := CombatWorld.new(rng.seed)
	var session := GameSession.new(world, "")
	world.player.safe_zone = true
	world.player.switch_class(class_id)
	world.player.set_level(clampi(floor_number, 1, 10))
	world.player.safe_zone = false
	for n: int in range(1, floor_number):
		session.tower.complete(n)
	session._enter(TowerGenerator.generate(floor_number, 20261110, 1), false)
	var problems: Array[String] = []
	var bounds: Rect2 = world.bounds.grow(8.0)
	var moves := [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	var move := Vector2.ZERO
	var aim := Vector2.RIGHT
	var held: Dictionary = {}
	for tick: int in range(TICKS):
		if tick % 500 == 0:
			# Se coloca al jugador junto a un enemigo para que el fuzz pelee de verdad (si no, solo pasea).
			var candidates: Array = world.enemies.filter(func(e: EnemySim) -> bool: return e.alive and not e.invulnerable)
			if not candidates.is_empty():
				var target: EnemySim = candidates[rng.randi() % candidates.size()]
				world.player.position = world.resolve_position(target.position + Vector2(150.0, 0.0), PlayerSim.RADIUS)
		if tick % 20 == 0:
			move = moves[rng.randi() % moves.size()]
			aim = Vector2.from_angle(rng.randf() * TAU)
		var message := InputMessage.new()
		message.tick = tick
		message.peer_id = 1
		message.move_dir = move
		message.aim_dir = aim
		message.target_pos = world.player.position + aim * 120.0
		message.actions = {}
		for action: String in ["m1", "m2", "s1", "s2", "s3", "special", "ultimate", "dodge", "quick_health", "quick_resource", "basic"]:
			if rng.randf() < 0.06:
				held[action] = not bool(held.get(action, false))
			message.actions[action] = bool(held.get(action, false))
		world.submit_input(message)
		world.step(DT)
		if not world.player.alive:
			world.player.reset(world.player.position)
		if tick % 30 == 0:
			var player := world.player
			if not (is_finite(player.position.x) and is_finite(player.position.y)):
				problems.append("tick %d: posicion no finita" % tick)
			elif not bounds.has_point(player.position):
				problems.append("tick %d: jugador fuera del mapa %s" % [tick, str(player.position)])
			if player.health < 0.0 or player.health > player.max_health + 0.01 or is_nan(player.health):
				problems.append("tick %d: vida fuera de rango %.1f/%.1f" % [tick, player.health, player.max_health])
			var resource := player.resource.get_current()
			if resource < -0.01 or resource > player.resource.max_amount + 0.01 or is_nan(resource):
				problems.append("tick %d: recurso fuera de rango %.1f" % [tick, resource])
			if player.ultimate_charge < -0.01 or player.ultimate_charge > WarriorKit.ULTIMATE_CHARGE_MAX + 0.01:
				problems.append("tick %d: carga de ultimate fuera de rango %.1f" % [tick, player.ultimate_charge])
			for enemy: EnemySim in world.enemies:
				if enemy.alive and (not is_finite(enemy.position.x) or not is_finite(enemy.position.y) or not bounds.has_point(enemy.position)):
					problems.append("tick %d: enemigo %s fuera del mapa %s" % [tick, str(enemy.def_id), str(enemy.position)])
					break
				if enemy.alive and (enemy.health < 0.0 or enemy.health > enemy.max_health + 0.01):
					problems.append("tick %d: vida del enemigo %s fuera de rango" % [tick, str(enemy.def_id)])
					break
			for projectile: ProjectileSim in world.projectiles:
				if not is_finite(projectile.position.x) or not is_finite(projectile.position.y):
					problems.append("tick %d: proyectil no finito" % tick)
					break
		if problems.size() >= 3:
			break
	_check(problems.is_empty(), "%s en el piso %d: %d ticks de input aleatorio sin romper invariantes %s" % [class_id, floor_number, TICKS, str(problems.slice(0, 2))])
	var alive := 0
	for enemy: EnemySim in world.enemies:
		alive += 1 if enemy.alive else 0
	return "%.3f,%.3f,%.2f,%.2f,%d,%d" % [world.player.position.x, world.player.position.y, world.player.health, world.player.resource.get_current(), alive, world.tick]


func _random_message(rng: RandomNumberGenerator, held: Dictionary, tick: int, from: Vector2, toward: Vector2) -> InputMessage:
	var message := InputMessage.new()
	message.tick = tick
	message.peer_id = 1
	var to_target := (toward - from)
	var aim := to_target.normalized() if to_target.length() > 1.0 else Vector2.RIGHT
	if rng.randf() < 0.2:
		aim = aim.rotated(rng.randf_range(-1.0, 1.0))
	message.aim_dir = aim
	message.move_dir = aim if rng.randf() < 0.5 else Vector2.from_angle(rng.randf() * TAU) * float(rng.randi() % 2)
	message.target_pos = from + aim * 100.0
	message.actions = {}
	for action: String in ["m1", "m2", "s1", "s2", "s3", "special", "ultimate", "dodge", "basic"]:
		if rng.randf() < 0.08:
			held[action] = not bool(held.get(action, false))
		message.actions[action] = bool(held.get(action, false))
	return message


func _fuzz_duel(class_a: String, class_b: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("duel%s%s" % [class_a, class_b])
	var world := CombatWorld.new(rng.seed)
	world.player.safe_zone = true
	world.player.switch_class(class_a)
	world.player.enter_rules("pvp")
	world.player.safe_zone = false
	var rival := world.add_opponent(class_b, Vector2(560, 320))
	world.player.reset(Vector2(360, 320))
	var held_a: Dictionary = {}
	var held_b: Dictionary = {}
	var problems: Array[String] = []
	for tick: int in range(1500):
		world.submit_input(_random_message(rng, held_a, tick, world.player.position, rival.position))
		world.submit_opponent_input(rival, _random_message(rng, held_b, tick, rival.position, world.player.position))
		world.step(DT)
		if tick % 30 == 0:
			for who: PlayerSim in [world.player, rival]:
				if not is_finite(who.position.x) or not is_finite(who.position.y) or not world.bounds.grow(8.0).has_point(who.position):
					problems.append("tick %d: posicion fuera de rango" % tick)
				if who.health < 0.0 or who.health > who.max_health + 0.01 or is_nan(who.health):
					problems.append("tick %d: vida fuera de rango" % tick)
		if not world.player.alive:
			world.player.reset(Vector2(360, 320))
		if not rival.alive:
			rival.reset(Vector2(560, 320))
		if problems.size() >= 3:
			break
	_check(problems.is_empty(), "duelo %s contra %s con input aleatorio sin romper invariantes %s" % [class_a, class_b, str(problems.slice(0, 2))])


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
