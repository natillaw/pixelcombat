## Basicos estilo Drakantos (Fase 1.5a): M1 con cargas y M2 que se potencia
## manteniendo el boton.
##
##   godot --headless --path . --script tests/test_basics.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_basics (M1 con cargas, M2 con hold) ==")
	_test_m1_starts_full_and_spends_charges()
	_test_m1_is_throttled_by_charges()
	_test_m1_recharges()
	_test_m2_tap_is_base_damage()
	_test_m2_full_hold_bonus_and_range()
	_test_m2_partial_hold_is_proportional()
	_test_m2_auto_releases_at_max()
	_test_m2_is_press_not_repeat()
	_test_m2_charge_fraction()
	_test_dodge_cancels_charge()
	_test_snapshot()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- M1 ----------------------------------------------------------------------


func _test_m1_starts_full_and_spends_charges() -> void:
	var world := _make_world([])
	var max_charges: float = world.player.charges_max("M1")
	_check(is_equal_approx(max_charges, float(WarriorKit.M1["charges"]["max"])), "M1 declares its charge pool in the data")
	_check(is_equal_approx(world.player.charges_left("M1"), max_charges), "M1 starts with every charge")
	_step(world, 1, _input({"m1": true}))
	_check(is_equal_approx(world.player.charges_left("M1"), max_charges - 1.0), "a swing spends exactly one charge")


func _test_m1_is_throttled_by_charges() -> void:
	var world := _make_world([])
	var swings: Array = []
	world.player.attack_started.connect(func(skill: Dictionary, _dir: Vector2) -> void:
		swings.append(world.player.tick))
	# Mantener M1 8 s: sin cargas cabrian ~17 swings; con 3 cargas y una nueva cada
	# 0,9 s caben ~3 + 8 / 0,9 = 11.
	_step(world, 480, _input({"m1": true}))
	var swing_time := float(WarriorKit.M1["windup"]) + float(WarriorKit.M1["active"]) + float(WarriorKit.M1["recovery"]) + float(WarriorKit.M1["cooldown"])
	var unthrottled := int(8.0 / swing_time) + 1
	_check(swings.size() < int(unthrottled * 0.8), "charges throttle sustained M1 (%d swings vs %d unthrottled)" % [swings.size(), unthrottled])
	_check(swings.size() >= 4, "M1 still bursts through its stored charges (%d)" % swings.size())
	# Con la reserva vacia no hay swing aunque se mantenga el boton ni aviso de denegado.
	var world2 := _make_world([])
	var denied: Array = []
	world2.player.skill_denied.connect(func(slot: String, _reason: String) -> void: denied.append(slot))
	_step(world2, 480, _input({"m1": true}))
	_check(denied.is_empty(), "running out of M1 charges is silent, not a denial")


func _test_m1_recharges() -> void:
	var world := _make_world([])
	_step(world, 60, _input({"m1": true}))
	var low: float = world.player.charges_left("M1")
	_check(low < world.player.charges_max("M1"), "charges were spent")
	_step(world, 600, _input({}))
	_check(is_equal_approx(world.player.charges_left("M1"), world.player.charges_max("M1")), "idle time refills every M1 charge")
	_step(world, 30, _input({"m1": false}))
	_check(world.player.charges_left("M1") <= world.player.charges_max("M1"), "charges never exceed the pool")


# --- M2 ----------------------------------------------------------------------


## Dano del primer golpe de un M2 mantenido `hold_ticks` ticks tras pulsar
## (1 = un toque). Misma semilla y dano fijo, asi los cocientes son exactos.
func _m2_damage(hold_ticks: int) -> float:
	var world := _make_world([Vector2(50, 0)])
	var hits := _watch_hits(world)
	_fix_damage(world, 10.0)
	_step(world, hold_ticks, _input({"m2": true}))
	_step(world, 120, _input({}))
	return float(hits[0]) if hits.size() == 1 else -1.0


func _test_m2_tap_is_base_damage() -> void:
	var tap := _m2_damage(1)
	_check(tap > 0.0, "a tap on M2 lands exactly one hit")
	var expected_ratio := float(WarriorKit.M2["damage_mult"]) / float(WarriorKit.M1["damage_mult"])
	var world := _make_world([Vector2(50, 0)])
	var m1_hits := _watch_hits(world)
	_fix_damage(world, 10.0)
	_step(world, 1, _input({"m1": true}))
	_step(world, 60, _input({}))
	_check(m1_hits.size() >= 1 and absf(tap / float(m1_hits[0]) - expected_ratio) < 0.01, "a tap deals the base M2 multiplier over M1 (x%.2f)" % expected_ratio)


func _test_m2_full_hold_bonus_and_range() -> void:
	var tap := _m2_damage(1)
	var full := _m2_damage(120)
	var bonus := float(WarriorKit.M2["hold"]["damage_bonus"])
	_check(full > 0.0 and tap > 0.0, "tap and full hold both land one hit")
	_check(absf(full / tap - (1.0 + bonus)) < 0.01, "full hold deals +%d%% damage over a tap (x%.2f)" % [int(bonus * 100.0), full / tap])

	# Alcance: un enemigo justo fuera del alcance base solo lo alcanza la carga.
	var base_range := float(WarriorKit.M2["range"])
	var probe := _make_world([Vector2(base_range + 14.0 + 6.0, 0)])
	var radius: float = (probe.dummies[0] as DummySim).radius
	var beyond := base_range + radius + 4.0
	var tap_world := _make_world([Vector2(beyond, 0)])
	var tap_hits := _watch_hits(tap_world)
	_step(tap_world, 1, _input({"m2": true}))
	_step(tap_world, 90, _input({}))
	_check(tap_hits.is_empty(), "a tap does not reach an enemy beyond the base range")
	var hold_world := _make_world([Vector2(beyond, 0)])
	var hold_hits := _watch_hits(hold_world)
	_step(hold_world, 120, _input({"m2": true}))
	_check(hold_hits.size() == 1, "a full hold reaches it (range +%d%%)" % int(float(WarriorKit.M2["hold"]["range_bonus"]) * 100.0))


func _test_m2_partial_hold_is_proportional() -> void:
	var tap := _m2_damage(1)
	var windup := float(WarriorKit.M2["windup"])
	var half_hold := float(WarriorKit.M2["hold"]["max"]) * 0.5
	var press_ticks := int(round((windup + half_hold) / DT))
	var half := _m2_damage(press_ticks)
	var bonus := float(WarriorKit.M2["hold"]["damage_bonus"])
	_check(half > 0.0, "a half hold lands one hit")
	var ratio := half / tap
	_check(ratio > 1.05 and ratio < 1.0 + bonus - 0.05, "a half hold is between tap and full (x%.2f)" % ratio)
	_check(absf(ratio - (1.0 + bonus * 0.5)) < 0.05, "the bonus is proportional to the time held (x%.2f)" % ratio)


func _test_m2_auto_releases_at_max() -> void:
	var world := _make_world([Vector2(50, 0)])
	var hits := _watch_hits(world)
	_step(world, 600, _input({"m2": true}))
	_check(hits.size() == 1, "holding M2 forever fires once at the maximum charge (%d)" % hits.size())


func _test_m2_is_press_not_repeat() -> void:
	var world := _make_world([])
	var casts: Array = []
	world.player.attack_started.connect(func(skill: Dictionary, _dir: Vector2) -> void:
		if skill["slot"] == "M2":
			casts.append(true))
	_step(world, 600, _input({"m2": true}))
	_check(casts.size() == 1, "holding M2 does not chain casts (%d)" % casts.size())


func _test_m2_charge_fraction() -> void:
	var world := _make_world([Vector2(50, 0)])
	_check(is_zero_approx(world.player.charge_fraction()), "no charge before casting")
	var windup_ticks := int(ceil(float(WarriorKit.M2["windup"]) / DT)) + 1
	_step(world, windup_ticks, _input({"m2": true}))
	_step(world, 18, _input({"m2": true}))
	var mid: float = world.player.charge_fraction()
	_check(mid > 0.2 and mid < 0.8, "charge_fraction rises while holding (%.2f)" % mid)
	_step(world, 1, _input({}))
	_step(world, 60, _input({}))
	_check(is_zero_approx(world.player.charge_fraction()), "charge_fraction returns to 0 after release")


func _test_dodge_cancels_charge() -> void:
	var world := _make_world([Vector2(50, 0)])
	var hits := _watch_hits(world)
	var windup_ticks := int(ceil(float(WarriorKit.M2["windup"]) / DT)) + 8
	_step(world, windup_ticks, _input({"m2": true}))
	_check(world.player.charge_fraction() > 0.0, "charging before the dodge")
	_step(world, 1, _input({"m2": true, "dodge": true}))
	_check(world.player.blocking, "the block starts while charging (the Warrior defends with Space)")
	_check(is_zero_approx(world.player.hold_time), "cancelling resets the charge")
	_step(world, 60, _input({}))
	_check(hits.is_empty(), "a cancelled charge never lands")


func _test_snapshot() -> void:
	var world := _make_world([])
	var snap: Dictionary = world.player.snapshot()
	_check(snap.has("charges") and snap["charges"].has("M1"), "snapshot carries the M1 charges")
	_check(snap.has("hold"), "snapshot carries the hold time")


# --- Helpers ----------------------------------------------------------------


func _make_world(offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(4)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.resource.current_amount = 100.0
	var origin: Vector2 = world.player.position
	for offset: Vector2 in offsets:
		world.add_dummy(origin + offset, false)
	return world


func _fix_damage(world: CombatWorld, amount: float) -> void:
	world.player.stats.set_base_stat(&"weapon_min", amount)
	world.player.stats.set_base_stat(&"weapon_max", amount)
	world.player.stats.set_base_stat(&"crit_chance", 0.0)


func _watch_hits(world: CombatWorld) -> Array:
	var hits: Array = []
	world.player.attack_hit.connect(func(s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void:
		if String(s.get("slot", "")) != "MOBILITY":
			hits.append(damage))
	return hits


func _input(actions: Dictionary) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = Vector2.ZERO
	message.aim_dir = Vector2.RIGHT
	message.actions = actions.duplicate()
	return message


func _step(world: CombatWorld, ticks: int, message: InputMessage) -> void:
	for i: int in range(ticks):
		var copy: InputMessage = InputMessageScript.new()
		copy.tick = message.tick
		copy.peer_id = message.peer_id
		copy.move_dir = message.move_dir
		copy.aim_dir = message.aim_dir
		copy.actions = message.actions.duplicate()
		world.submit_input(copy)
		world.step(DT)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
