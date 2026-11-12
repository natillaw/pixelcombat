## Profundidad de combate: estados nuevos (sangrado, silencio, escudo, empuje), refuerzos de
## aliados, zonas persistentes de jefe y coordinacion de campamentos.
##
##   godot --headless --path . --script tests/test_combat_depth.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_combat_depth (estados, zonas y grupos) ==")
	_test_statuses()
	_test_enemy_buff()
	_test_zones()
	_test_group_coordination()
	_test_wandering_elite()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _world(level: int = 6) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 1400, 900))
	world.player.set_level(level)
	world.player.resource.current_amount = 100.0
	return world


func _idle(world: CombatWorld, ticks: int, actions: Dictionary = {}) -> void:
	for i: int in range(ticks):
		var message: InputMessage = InputMessageScript.new()
		message.tick = 0
		message.peer_id = 1
		message.move_dir = Vector2.ZERO
		message.aim_dir = Vector2.RIGHT
		message.actions = actions.duplicate()
		world.submit_input(message)
		world.step(DT)


func _test_statuses() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	var health := player.health
	player.apply_status("bleed", 3.0, 6.0)
	_idle(world, 90)
	_check(player.health < health - 3.0, "el sangrado quita vida con el tiempo (%.1f)" % (health - player.health))
	# Silencio: no hay skills, pero si basicos.
	var silent := _world()
	silent.player.apply_status("silence", 2.0)
	_idle(silent, 2, {"s1": true})
	_check(silent.player.state == PlayerSim.AttackState.IDLE, "el silencio impide usar skills (S1)")
	_idle(silent, 2, {"m1": true})
	_check(silent.player.state != PlayerSim.AttackState.IDLE, "pero no los basicos")
	_idle(silent, 200)
	_check(not silent.player.statuses.has("silence"), "el silencio acaba")
	# Escudo: absorbe antes que la vida.
	var shield_world := _world()
	var shielded: PlayerSim = shield_world.player
	shielded.apply_status("shield", 5.0, 50.0)
	var before := shielded.health
	shielded.take_damage(20.0, Vector2(100, 0), false)
	_check(is_equal_approx(shielded.health, before) and shielded.statuses.has("shield"), "el escudo absorbe un golpe pequeno")
	shielded.take_damage(400.0, Vector2(100, 0), false)
	_check(shielded.health < before and not shielded.statuses.has("shield"), "y se rompe: el sobrante pega a la vida")
	# Empuje del jugador y del enemigo.
	var push_world := _world()
	var start := push_world.player.position
	push_world.player.apply_status("knockback", 0.2, 100.0, start + Vector2(-50, 0))
	_check(push_world.player.position.x > start.x + 90.0, "el empuje aleja al jugador del origen (%.0f)" % (push_world.player.position.x - start.x))
	var slime := push_world.add_enemy(&"slime", start + Vector2(200, 0))
	var slime_start := slime.position
	slime.apply_status("knockback", 0.2, 80.0, start)
	_check(slime.position.x > slime_start.x + 70.0, "y a un enemigo")
	var rask := push_world.add_enemy(&"bandit_rask", start + Vector2(400, 0))
	_check(not rask.alive == false and rask.statuses.apply("knockback", 0.2, 80.0), "los jefes aceptan estados de empuje")


func _test_enemy_buff() -> void:
	var world := _world()
	var shieldman := world.add_enemy(&"bandit_shieldman", world.player.position + Vector2(150, 0))
	var mate := world.add_enemy(&"bandit_thug", world.player.position + Vector2(200, 0))
	shieldman.state = EnemySim.State.CHASE
	var cast := false
	for i: int in range(600):
		_idle(world, 1)
		if shieldman.statuses.has("shield"):
			cast = true
			break
		if not shieldman.alive:
			break
	_check(cast, "el escudero levanta un escudo")
	_check(mate.statuses.has("shield"), "y protege a los aliados cercanos")


func _test_zones() -> void:
	var world := _world()
	var rask := world.add_enemy(&"bandit_rask", world.player.position + Vector2(60, 0))
	rask.state = EnemySim.State.CHASE
	world.player.apply_status("shield", 30.0, 400.0)
	var seen := false
	for i: int in range(900):
		_idle(world, 1)
		if not world.zones.is_empty():
			seen = true
			break
	# Forzamos el ataque si el azar no lo eligio: la zona nace del dato del ataque.
	if not seen:
		for attack: Dictionary in rask.data["attacks"]:
			if String(attack["id"]) == "ground_pound":
				rask.current_attack = attack
				rask.attack_direction = Vector2.LEFT
				rask._spawn_zone()
		seen = not world.zones.is_empty()
	_check(seen, "el jefe deja una zona en el suelo")
	var zone: GroundZone = world.zones[0]
	var player: PlayerSim = world.player
	player.statuses.clear()
	player.position = zone.position
	player.health = player.max_health
	var before := player.health
	for i: int in range(120):
		_idle(world, 1)
	_check(player.health < before, "la zona danya a quien se queda dentro (%.1f)" % (before - player.health))
	var far := _world()
	var far_zone := GroundZone.new({"radius": 50, "duration": 3.0, "tick": 0.5, "damage_mult": 1.0}, far.player.position + Vector2(400, 0), 20.0)
	far.spawn_zone(far_zone)
	var far_before := far.player.health
	_idle(far, 120)
	_check(far.player.health == far_before, "y no a quien esta fuera")
	_idle(far, 200)
	_check(far.zones.is_empty(), "las zonas acaban solas")


func _test_group_coordination() -> void:
	# Alerta: golpear a uno despierta a todo el campamento cercano.
	var world := _world()
	var members: Array = []
	for i: int in range(4):
		var enemy := world.add_enemy(&"bandit_swordsman", world.player.position + Vector2(900.0, 200.0 + 40.0 * i))
		enemy.group = "camp_test"
		members.append(enemy)
	(members[0] as EnemySim).take_damage(1.0)
	var awake := 0
	for enemy: EnemySim in members:
		if enemy.state != EnemySim.State.IDLE:
			awake += 1
	_check(awake == 4, "golpear a uno despierta a todo su campamento (%d de 4)" % awake)
	# Turnos: nunca mas de MAX_MELEE_ATTACKERS cuerpo a cuerpo a la vez.
	var duel := _world()
	duel.player.apply_status("shield", 60.0, 400.0)
	var pack: Array = []
	for i: int in range(5):
		var enemy := duel.add_enemy(&"bandit_thug", duel.player.position + Vector2(70.0 + 6.0 * i, -40.0 + 20.0 * i))
		enemy.group = "camp_duel"
		enemy.state = EnemySim.State.CHASE
		pack.append(enemy)
	var peak := 0
	for i: int in range(900):
		_idle(duel, 1)
		var busy := 0
		for enemy: EnemySim in pack:
			if enemy.alive and (enemy.state == EnemySim.State.TELEGRAPH or enemy.state == EnemySim.State.ACTIVE):
				busy += 1
		peak = maxi(peak, busy)
	_check(peak <= EnemySim.MAX_MELEE_ATTACKERS and peak >= 1, "los cuerpo a cuerpo de un campamento atacan por turnos (pico %d)" % peak)


func _test_wandering_elite() -> void:
	var with_elite := 0
	var floors_seen := {}
	for world_seed: int in range(1, 41):
		var floor_number := TowerCatalog.elite_floor(world_seed)
		if floor_number > 0:
			with_elite += 1
			floors_seen[floor_number] = true
	_check(with_elite > 8 and with_elite < 32, "el elite errante toca en parte de las partidas (%d de 40)" % with_elite)
	var in_range := true
	for floor_number: int in floors_seen:
		in_range = in_range and floor_number >= 5 and floor_number <= 10
	_check(in_range and floors_seen.size() >= 4, "y en cualquier piso del 5 al 10 (%s)" % str(floors_seen.keys()))
	var state := TowerState.new()
	var found_seed := 0
	for world_seed: int in range(1, 100):
		if TowerCatalog.elite_floor(world_seed) > 0:
			found_seed = world_seed
			break
	state.world_seed = found_seed
	var target := state.elite_floor()
	var layout := TowerGenerator.generate(target, found_seed, 1, [], true)
	var count := 0
	for spec: Dictionary in layout.enemies:
		if String(spec["id"]) == "bandit_deserter":
			count += 1
			_check(not bool(spec["required"]), "el elite es opcional (no cuenta para completar el piso)")
	_check(count == 1, "el piso %d trae un unico elite" % target)
	var plain := TowerGenerator.generate(target, found_seed, 1, [], false)
	var none := true
	for spec: Dictionary in plain.enemies:
		none = none and String(spec["id"]) != "bandit_deserter"
	_check(none, "sin la marca no aparece")
	state.elite_defeated = true
	var restored := TowerState.from_dict(state.to_dict())
	_check(restored.elite_defeated and restored.elite_floor() == 0, "derrotado no vuelve y se guarda")
	# El elite suelta sus items propios y es un mini-jefe.
	var deserter := EnemyCatalog.enemy(&"bandit_deserter")
	_check(bool(deserter["boss"]) and bool(deserter["elite_boss"]) and (deserter["loot"]["items"] as Array).size() >= 3, "el Desertor es un mini-jefe con botin propio")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
