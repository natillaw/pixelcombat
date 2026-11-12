## Ultimate del Warrior (Fase 1.4): carga por golpes, coste de carga, salto con
## telegraph, zona central y que la esquiva no la cancele.
##
##   godot --headless --path . --script tests/test_ultimate.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_ultimate (War God's Descent) ==")
	_test_charge_from_a_hit()
	_test_charge_cap_per_swing()
	_test_ultimate_does_not_charge_itself()
	_test_denied_without_charge()
	_test_cast_spends_all_charge()
	_test_ready_signal_once()
	_test_leap_and_telegraph_point()
	_test_leap_respects_bounds()
	_test_center_zone_bonus()
	_test_dodge_cannot_cancel()
	_test_reset_and_snapshot()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_charge_from_a_hit() -> void:
	var world := _make_world([Vector2(50, 0)])
	_check(is_zero_approx(world.player.ultimate_charge), "the ultimate bar starts empty")
	_step(world, 1, _input({"m1": true}))
	_step(world, 40, _input({"m1": false}))
	var gain := float(WarriorKit.M1["ult_gain"])
	_check(is_equal_approx(world.player.ultimate_charge, gain), "one M1 hit gives its ult_gain (%.1f)" % world.player.ultimate_charge)


func _test_charge_cap_per_swing() -> void:
	# Cleaving Strike: 4 por golpe, tope 12 por lanzamiento. Cinco enemigos en el cono.
	var world := _make_world([Vector2(50, 0), Vector2(55, 25), Vector2(55, -25), Vector2(45, 40), Vector2(45, -40)])
	world.player.resource.current_amount = 40.0
	_step(world, 1, _input({"s1": true}))
	_step(world, 60, _input({}))
	var cap := float(WarriorKit.SKILL_BOOK[0]["cost"])
	_check(cap > 0.0, "sanity: the kit entry exists")
	var data := SkillCatalog.skill(&"cleaving_strike")
	_check(is_equal_approx(world.player.ultimate_charge, float(data["ult_cap"])), "a swing stops charging at ult_cap (%.1f)" % world.player.ultimate_charge)


func _test_ultimate_does_not_charge_itself() -> void:
	var world := _make_world([Vector2(150, 0)])
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_step(world, 90, _input({}))
	_check(is_zero_approx(world.player.ultimate_charge), "casting the ultimate does not refill the bar")


func _test_denied_without_charge() -> void:
	var world := _make_world([])
	var denied: Array = []
	world.player.skill_denied.connect(func(slot: String, reason: String) -> void: denied.append([slot, reason]))
	world.player.ultimate_charge = 60.0
	_step(world, 1, _input({"ultimate": true}))
	_check(world.player.state == PlayerSim.AttackState.IDLE, "no cast below 100 charge")
	_check(denied.size() == 1 and denied[0][0] == "ULTIMATE" and denied[0][1] == "charge", "the denial reports the missing charge")
	_check(is_equal_approx(world.player.ultimate_charge, 60.0), "a denied ultimate keeps its charge")


func _test_cast_spends_all_charge() -> void:
	var world := _make_world([])
	var changes: Array = []
	world.player.ultimate_changed.connect(func(current: float, _maximum: float) -> void: changes.append(current))
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_check(world.player.state == PlayerSim.AttackState.WINDUP, "a full bar starts the ultimate")
	_check(is_zero_approx(world.player.ultimate_charge), "the cast spends the whole bar up front")
	_check(not changes.is_empty() and is_zero_approx(float(changes[changes.size() - 1])), "ultimate_changed reports the empty bar")
	_check(is_zero_approx(world.player.attack_cooldown_left("ULTIMATE")), "the ultimate has no cooldown besides the bar")


func _test_ready_signal_once() -> void:
	var world := _make_world([Vector2(50, 0)])
	var ready: Array = []
	world.player.ultimate_ready.connect(func() -> void: ready.append(true))
	world.player.ultimate_charge = 98.0
	_step(world, 1, _input({"m1": true}))
	_step(world, 90, _input({"m1": true}))
	_check(is_equal_approx(world.player.ultimate_charge, 100.0), "the bar never exceeds 100")
	_check(ready.size() == 1, "ultimate_ready fires once when the bar fills (%d)" % ready.size())
	_check(world.player.ultimate_ready_now(), "ultimate_ready_now reports a full bar")


func _test_leap_and_telegraph_point() -> void:
	var world := _make_world([])
	var start: Vector2 = world.player.position
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	var point: Vector2 = world.player.attack_point
	var distance := float(world.player.current_skill["leap_distance"])
	_check(point.is_equal_approx(start + Vector2.RIGHT * distance), "the telegraph point is leap_distance ahead (%s)" % str(point))
	var windup_ticks := int(ceil(float(world.player.current_skill["windup"]) / DT)) + 1
	_step(world, windup_ticks, _input({}))
	_check(world.player.position.distance_to(point) < 1.0, "the warrior lands on the telegraphed point (%s)" % str(world.player.position))
	_check(world.player.state != PlayerSim.AttackState.WINDUP, "the windup is over after landing")


func _test_leap_respects_bounds() -> void:
	var world := _make_world([])
	world.player.position = Vector2(world.bounds.end.x - 40.0, world.bounds.get_center().y)
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_check(world.player.attack_point.x <= world.bounds.end.x - PlayerSim.RADIUS + 0.01, "the landing point stays inside the arena")


func _test_center_zone_bonus() -> void:
	var world := _make_world([Vector2(150, 8), Vector2(150 + 60, 0)])
	world.player.stats.set_base_stat(&"weapon_min", 10.0)
	world.player.stats.set_base_stat(&"weapon_max", 10.0)
	world.player.stats.set_base_stat(&"crit_chance", 0.0)
	var damages: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, damage: float, _c: bool, _p: Vector2) -> void:
		damages.append({"x": target.position.x - world.player.attack_point.x, "damage": damage}))
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_step(world, 90, _input({}))
	_check(damages.size() == 2, "both enemies in the zone are hit (%d)" % damages.size())
	if damages.size() == 2:
		var center: Dictionary = damages[0] if absf(float(damages[0]["x"])) < absf(float(damages[1]["x"])) else damages[1]
		var edge: Dictionary = damages[1] if center == damages[0] else damages[0]
		var ratio := float(center["damage"]) / float(edge["damage"])
		var expected := float(WarriorKit.ULTIMATE["center_mult"])
		_check(absf(ratio - expected) < 0.01, "the center hits %.2fx harder than the edge (%.2f)" % [expected, ratio])


func _test_dodge_cannot_cancel() -> void:
	var world := _make_world([])
	world.player.ultimate_charge = 100.0
	_step(world, 1, _input({"ultimate": true}))
	_step(world, 5, _input({"dodge": true}))
	_check(not world.player.dodging, "the dodge cannot cancel the ultimate windup")
	_check(world.player.state == PlayerSim.AttackState.WINDUP, "the ultimate keeps casting")


func _test_reset_and_snapshot() -> void:
	var world := _make_world([])
	world.player.ultimate_charge = 42.0
	_check(is_equal_approx(float(world.player.snapshot().get("ultimate", -1.0)), 42.0), "snapshot reports the ultimate charge")
	world.player.reset(world.bounds.get_center())
	_check(is_zero_approx(world.player.ultimate_charge), "reset empties the bar")


# --- Helpers ----------------------------------------------------------------


## Mundo 900x600 con el guerrero en el centro mirando a +X; los enemigos se
## colocan con offsets relativos al guerrero y no atacan.
func _make_world(offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(9)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.set_level(10)  # las skills se desbloquean por nivel
	LegacyKit.apply(world.player)
	var origin: Vector2 = world.player.position
	for offset: Vector2 in offsets:
		world.add_dummy(origin + offset, false)
	return world


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
