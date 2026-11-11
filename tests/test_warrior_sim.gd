## Test headless de la simulación del Warrior (game/sim).
##
##   godot --headless --path . --script tests/test_warrior_sim.gd
##
## No abre ventana ni escena: crea CombatWorld, le inyecta InputMessage y
## avanza ticks fijos, exactamente como lo hará el servidor autoritativo.
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior_sim (Reflections) ==")

	_test_m1_damage_and_rage()
	_test_m2_is_heavier()
	_test_vengeful_fury()
	_test_vengeful_expiry()
	_test_rage_decay()
	_test_death_and_reset()
	_test_dummy_telegraph_and_respawn()
	_test_determinism()
	_test_snapshot()
	_test_collision()

	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Casos ------------------------------------------------------------------


func _test_m1_damage_and_rage() -> void:
	var world := _make_world(false, 11)
	var dummy: DummySim = world.dummies[0]
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, critical: bool, _pos: Vector2) -> void:
		hits.append({"damage": damage, "critical": critical})
	)

	_step(world, 60, _input(Vector2(0, -1), true, false))

	_check(hits.size() >= 1, "M1 lands at least one hit")
	_check(dummy.health < dummy.max_health, "the dummy loses health")
	_check(world.warrior.rage() > 0.0, "hitting generates Rage")
	_check(world.warrior.rage() <= WarriorKit.MAX_RAGE, "Rage never exceeds its cap")
	if not hits.is_empty():
		_check(float(hits[0]["damage"]) > 0.0, "M1 deals positive damage")


func _test_m2_is_heavier() -> void:
	var light := _first_hit("M1", 77)
	var heavy := _first_hit("M2", 77)

	_check(not light.is_empty() and not heavy.is_empty(), "both basics land a hit")
	if not light.is_empty() and not heavy.is_empty():
		_check(
			float(heavy[0]) > float(light[0]) * 1.5,
			"M2 hits at least 50%% harder than M1 (%.1f vs %.1f)" % [heavy[0], light[0]]
		)


func _test_vengeful_fury() -> void:
	var base := _first_hit("M2", 55)
	var buffed := _first_hit("M2", 55, true)

	_check(base.size() == 1 and buffed.size() == 1, "M2 lands in both runs")
	if base.size() == 1 and buffed.size() == 1:
		_check(
			float(buffed[0]) > float(base[0]) * 1.25,
			"Vengeful Fury buffs M2 by roughly 30%% (%.1f vs %.1f)" % [buffed[0], base[0]]
		)

	var world := _make_world(false, 31)
	world.warrior.take_damage(10.0, Vector2.ZERO, false)
	_check(world.warrior.vengeful_active, "a direct hit activates Vengeful Fury")
	_step(world, 40, _input(Vector2(0, -1), false, true))
	_check(not world.warrior.vengeful_active, "the next Heavy Strike consumes the passive")


func _test_vengeful_expiry() -> void:
	var world := _make_world(false, 5)
	world.warrior.take_damage(10.0, Vector2.ZERO, false)
	_check(world.warrior.vengeful_active, "passive starts active")
	_step(world, 250, null)
	_check(not world.warrior.vengeful_active, "passive expires after its 4 s window")


func _test_rage_decay() -> void:
	var world := _make_world(false, 9)
	# Un solo swing: mantener M1 todo el rato encadenaría golpes y falsearía el pico.
	_step(world, 1, _input(Vector2(0, -1), true, false))
	_step(world, 40, null)
	var peak: float = world.warrior.rage()
	_check(peak > 0.0, "Rage is stored after a hit")

	_step(world, 340, null)
	_check(world.warrior.rage() < peak, "Rage decays after the 5 s grace period")


func _test_death_and_reset() -> void:
	var world := _make_world(false, 3)
	var died: Array = [false]
	world.warrior.died.connect(func() -> void: died[0] = true)

	world.warrior.take_damage(99999.0, Vector2.ZERO, false)
	_check(not world.warrior.alive, "lethal damage kills the Warrior")
	_check(is_zero_approx(world.warrior.health), "health is clamped to zero")
	_check(died[0], "the died signal fires")

	world.reset()
	_check(world.warrior.alive, "reset revives the Warrior")
	_check(is_equal_approx(world.warrior.health, world.warrior.max_health), "reset restores full health")
	_check(is_zero_approx(world.warrior.rage()), "reset clears Rage")
	_check(world.warrior.position.distance_to(world.bounds.get_center()) < 0.01, "reset returns to the arena center")


func _test_dummy_telegraph_and_respawn() -> void:
	var world := _make_world(true, 21)
	var dummy: DummySim = world.dummies[0]
	var telegraphs: Array = [0]
	var landings: Array = [0]
	dummy.telegraph_started.connect(func(_dir: Vector2, _radius: float, _arc: float) -> void:
		telegraphs[0] += 1
	)
	dummy.attack_landed.connect(func(_damage: float) -> void:
		landings[0] += 1
	)

	_step(world, 70, null)
	_check(telegraphs[0] >= 1, "the dummy telegraphs its attack")
	_check(landings[0] >= 1, "the dummy lands its attack")
	_check(world.warrior.health < world.warrior.max_health, "the dummy hurts the Warrior")

	dummy.take_damage(99999.0)
	_check(not dummy.alive, "a dummy can be destroyed")
	_step(world, 195, null)
	_check(dummy.alive, "the dummy respawns after 3 s")


func _test_determinism() -> void:
	var first := _run_sequence(42)
	var second := _run_sequence(42)
	_check(JSON.stringify(first) == JSON.stringify(second), "same seed + same inputs = same snapshot")

	var other := _run_sequence(43)
	_check(JSON.stringify(first) != JSON.stringify(other), "a different seed changes the outcome")


func _test_snapshot() -> void:
	var world := _make_world(false, 1)
	var snap: Dictionary = world.snapshot()
	_check(snap.has("tick") and snap.has("warrior") and snap.has("dummies"), "snapshot has the network sections")
	var warrior: Dictionary = snap["warrior"]
	for key: String in ["position", "velocity", "aim", "health", "max_health", "rage", "state", "vengeful", "alive"]:
		_check(warrior.has(key), "warrior snapshot has %s" % key)

	var dummy: Dictionary = snap["dummies"][0]
	for key: String in ["position", "health", "max_health", "alive", "state", "telegraph"]:
		_check(dummy.has(key), "dummy snapshot has %s" % key)


func _test_collision() -> void:
	var world: CombatWorld = CombatWorldScript.new(1)
	world.setup_arena(Rect2(0, 0, 200, 200), [{"position": Vector2(100, 100), "radius": 30}])

	var clamped: Vector2 = world.resolve_position(Vector2(-50, -50), 14.0)
	_check(clamped.x >= 14.0 and clamped.y >= 14.0, "positions are clamped inside the arena")

	var pushed: Vector2 = world.resolve_position(Vector2(105, 100), 14.0)
	_check(pushed.distance_to(Vector2(100, 100)) >= 43.9, "pillars push actors out")

	world.add_dummy(Vector2(60, 60), false)
	var around_dummy: Vector2 = world.resolve_position(Vector2(62, 60), 14.0)
	_check(around_dummy.distance_to(Vector2(60, 60)) >= 29.9, "living dummies block movement")


# --- Helpers ----------------------------------------------------------------


func _make_world(auto_attack: bool, seed_value: int) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(seed_value)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.add_dummy(Vector2(450, 230), auto_attack)
	return world


func _input(aim: Vector2, m1: bool, m2: bool, move: Vector2 = Vector2.ZERO) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = move
	message.aim_dir = aim.normalized()
	message.actions = {"m1": m1, "m2": m2}
	return message


func _step(world: CombatWorld, ticks: int, message: InputMessage) -> void:
	for i: int in range(ticks):
		if message != null:
			world.submit_input(_duplicate_input(message))
		world.step(DT)


func _duplicate_input(message: InputMessage) -> InputMessage:
	var copy: InputMessage = InputMessageScript.new()
	copy.tick = message.tick
	copy.peer_id = message.peer_id
	copy.move_dir = message.move_dir
	copy.aim_dir = message.aim_dir
	copy.actions = message.actions.duplicate()
	return copy


func _first_hit(slot: String, seed_value: int, hurt_first: bool = false) -> Array:
	var world := _make_world(false, seed_value)
	var hits: Array = []
	world.warrior.attack_hit.connect(func(_skill: Dictionary, _target: Object, damage: float, _critical: bool, _pos: Vector2) -> void:
		hits.append(damage)
	)
	if hurt_first:
		world.warrior.take_damage(10.0, Vector2.ZERO, false)
	_step(world, 60, _input(Vector2(0, -1), slot == "M1", slot == "M2"))
	return hits


func _run_sequence(seed_value: int) -> Dictionary:
	var world := _make_world(true, seed_value)
	for i: int in range(120):
		var message := _input(
			Vector2(0, -1),
			i % 7 < 4,
			(i + 3) % 11 == 0,
			Vector2(0.25, 0.0) if i > 40 else Vector2.ZERO
		)
		world.submit_input(message)
		world.step(DT)
	return world.snapshot()


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)
