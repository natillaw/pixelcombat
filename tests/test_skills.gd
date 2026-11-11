## Skills S1-S5 en la simulacion (Fase 1.3): coste, cooldown, formas, limite de
## objetivos, loadout y movimiento por fase.
##
##   godot --headless --path . --script tests/test_skills.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_skills (skills por datos en la sim) ==")
	_test_default_loadout()
	_test_cost_and_cooldown()
	_test_denied_without_rage()
	_test_cone_hits_everyone()
	_test_line_shape_and_target_limit()
	_test_cone_misses_behind()
	_test_set_loadout()
	_test_movement_comes_from_data()
	_test_press_not_hold()
	_test_snapshot()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_default_loadout() -> void:
	var world := _make_world([])
	var loadout: Dictionary = world.player.loadout
	_check(loadout.has("M1") and loadout.has("M2") and loadout.has("S1") and loadout.has("S2"), "default loadout has M1, M2, S1 and S2")
	_check(not loadout.has("S3"), "empty slots stay empty")
	_check(loadout["S1"]["id"] == &"cleaving_strike", "S1 is Cleaving Strike")
	_check(loadout["S2"]["slot"] == "S2", "the loadout stores the slot it was equipped in")


func _test_cost_and_cooldown() -> void:
	var world := _make_world([Vector2(60, 0)])
	world.player.resource.current_amount = 50.0
	_step(world, 1, _input("s1"))
	_check(world.player.state == PlayerSim.AttackState.WINDUP, "S1 starts a cast")
	var cost := float(WarriorKit.SKILL_BOOK[0]["cost"])
	_check(is_equal_approx(world.player.resource_amount(), 50.0 - cost), "S1 spends its Rage cost up front (%.1f)" % world.player.resource_amount())
	var cd := world.player.attack_cooldown_left("S1")
	_check(cd > 5.0 and cd <= float(WarriorKit.SKILL_BOOK[0]["cooldown"]), "S1 cooldown counts from the cast (%.2f s)" % cd)
	_check(is_equal_approx(world.player.attack_cooldown_total("S1"), float(WarriorKit.SKILL_BOOK[0]["cooldown"])), "cooldown_total for a skill is its data cooldown")
	# Con el cooldown activo y Rage de sobra, pulsar de nuevo no la relanza.
	_step(world, 60, _input(""))
	world.player.resource.current_amount = 80.0
	var before: float = world.player.resource_amount()
	_step(world, 1, _input("s1"))
	_check(is_equal_approx(world.player.resource_amount(), before), "no recast while the cooldown runs")


func _test_denied_without_rage() -> void:
	var world := _make_world([Vector2(60, 0)])
	var denied: Array = []
	world.player.skill_denied.connect(func(slot: String, reason: String) -> void: denied.append([slot, reason]))
	world.player.resource.current_amount = 5.0
	_step(world, 1, _input("s1"))
	_check(world.player.state == PlayerSim.AttackState.IDLE, "S1 does not start without Rage")
	_check(denied.size() == 1 and denied[0][0] == "S1" and denied[0][1] == "resource", "a denied cast emits skill_denied")
	_check(is_equal_approx(world.player.resource_amount(), 5.0), "a denied cast spends nothing")
	_check(is_zero_approx(world.player.attack_cooldown_left("S1")), "a denied cast does not trigger the cooldown")


func _test_cone_hits_everyone() -> void:
	# Tres enemigos delante, dentro del cono ancho de Cleaving Strike.
	var world := _make_world([Vector2(60, 0), Vector2(55, 30), Vector2(55, -30)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.resource.current_amount = 40.0
	_step(world, 1, _input("s1"))
	_step(world, 60, _input(""))
	_check(hits.size() == 3, "Cleaving Strike hits all three enemies in its cone (%d)" % hits.size())


func _test_line_shape_and_target_limit() -> void:
	# Piercing Thrust: linea estrecha, maximo 2 objetivos. Tres en fila y uno al lado.
	var world := _make_world([Vector2(50, 0), Vector2(90, 0), Vector2(120, 0), Vector2(50, 60)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.resource.current_amount = 40.0
	_step(world, 1, _input("s2"))
	_step(world, 60, _input(""))
	_check(hits.size() == 2, "Piercing Thrust is capped at max_targets = 2 (%d)" % hits.size())
	var hit_x: Array = hits.map(func(t: Object) -> float: return t.position.x - world.player.position.x)
	hit_x.sort()
	_check(hit_x[0] > 0.0 and hit_x[1] > hit_x[0], "the two nearest enemies in the line are the ones hit")
	var side_hit := false
	for target: Object in hits:
		if absf(target.position.y - world.player.position.y) > 30.0:
			side_hit = true
	_check(not side_hit, "the enemy beside the line is not hit")


func _test_cone_misses_behind() -> void:
	var world := _make_world([Vector2(-60, 0)])
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	world.player.resource.current_amount = 40.0
	_step(world, 1, _input("s1"))
	_step(world, 60, _input(""))
	_check(hits.is_empty(), "an enemy behind the warrior is outside the cone")


func _test_set_loadout() -> void:
	var world := _make_world([])
	world.player.set_loadout({"M1": &"warrior_m1", "S3": &"piercing_thrust", "S9": &"cleaving_strike", "S4": &"no_existe", "S5": &"whirlwind"})
	var loadout: Dictionary = world.player.loadout
	_check(loadout.has("S3") and loadout["S3"]["id"] == &"piercing_thrust", "S3 can hold Piercing Thrust")
	_check(not loadout.has("S9"), "unknown slots are ignored")
	_check(not loadout.has("S4"), "unknown skill ids are ignored")
	_check(not loadout.has("S5"), "skills that are not implemented cannot be equipped")
	_check(not loadout.has("M2"), "slots missing from the new loadout are empty")


func _test_movement_comes_from_data() -> void:
	var world := _make_world([Vector2(300, -200)])
	world.player.resource.current_amount = 40.0
	var move_dir := Vector2.DOWN
	_step(world, 30, _input("", false, move_dir))
	var free_speed: float = world.player.velocity.length()
	_step(world, 1, _input("s1", false, move_dir))
	_step(world, 8, _input("", false, move_dir))
	_check(world.player.state == PlayerSim.AttackState.WINDUP, "S1 is in windup")
	var cast_speed: float = world.player.velocity.length()
	var expected := float(world.player.current_skill["move"]["windup"]) * PlayerSim.MOVE_SPEED
	_check(cast_speed < free_speed * 0.6, "movement slows down while casting (%.0f vs %.0f)" % [cast_speed, free_speed])
	_check(absf(cast_speed - expected) < 2.0, "the slowdown follows move.windup from the data (%.1f vs %.1f)" % [cast_speed, expected])


func _test_press_not_hold() -> void:
	var world := _make_world([Vector2(60, 0)])
	world.player.resource.current_amount = 100.0
	var casts: Array = []
	world.player.attack_started.connect(func(skill: Dictionary, _dir: Vector2) -> void:
		if skill["id"] == &"piercing_thrust":
			casts.append(true))
	# Mantener S2 apretada durante 12 s: solo una vez al pulsar (el cooldown es 5 s).
	_step(world, 720, _input("s2"))
	_check(casts.size() == 1, "holding a skill key casts once, not on every cooldown (%d)" % casts.size())


func _test_snapshot() -> void:
	var world := _make_world([Vector2(60, 0)])
	world.player.resource.current_amount = 50.0
	_step(world, 1, _input("s1"))
	var snap: Dictionary = world.player.snapshot()
	var cooldowns: Dictionary = snap.get("cooldowns", {})
	_check(cooldowns.has("cleaving_strike") and float(cooldowns["cleaving_strike"]) > 0.0, "snapshot carries the per-skill cooldowns")


# --- Helpers ----------------------------------------------------------------


## Mundo 900x600 con el guerrero en el centro mirando a +X; los enemigos se
## colocan con offsets relativos al guerrero y no atacan.
func _make_world(offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(3)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.set_level(10)  # las skills se desbloquean por nivel
	var origin: Vector2 = world.player.position
	for offset: Vector2 in offsets:
		world.add_dummy(origin + offset, false)
	return world


func _input(slot_action: String, m1: bool = false, move: Vector2 = Vector2.ZERO) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = move
	message.aim_dir = Vector2.RIGHT
	message.actions = {"m1": m1, "m2": false, "dodge": false}
	if slot_action != "":
		message.actions[slot_action] = true
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
