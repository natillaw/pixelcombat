## Special del Warrior, Iron Counter (Fase 1.6): postura que bloquea el primer
## golpe frontal y devuelve un contraataque.
##
##   godot --headless --path . --script tests/test_special.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_special (Iron Counter) ==")
	_test_cast_cost_and_cooldown()
	_test_denied_without_rage()
	_test_stance_opens_after_windup()
	_test_blocks_frontal_hit()
	_test_counter_damage_and_recovery()
	_test_only_blocks_once()
	_test_does_not_block_from_behind_or_dots()
	_test_whiff_has_full_recovery()
	_test_dodge_cancels_stance()
	_test_blocks_a_real_enemy_attack()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_cast_cost_and_cooldown() -> void:
	var world := _make_world([])
	world.warrior.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_check(world.warrior.state == WarriorSim.AttackState.WINDUP, "Q starts the Special")
	_check(is_equal_approx(world.warrior.rage(), 100.0 - float(WarriorKit.SPECIAL["cost"])), "the Special spends its Rage")
	var cooldown: float = world.warrior.attack_cooldown_left("SPECIAL")
	_check(cooldown > 11.0 and cooldown <= float(WarriorKit.SPECIAL["cooldown"]), "the Special goes on cooldown (%.1f s)" % cooldown)


func _test_denied_without_rage() -> void:
	var world := _make_world([])
	var denied: Array = []
	world.warrior.skill_denied.connect(func(slot: String, reason: String) -> void: denied.append([slot, reason]))
	world.warrior.resource.current_amount = 10.0
	_step(world, 1, _input({"special": true}))
	_check(world.warrior.state == WarriorSim.AttackState.IDLE, "no Special without 30 Rage")
	_check(denied.size() == 1 and denied[0][0] == "SPECIAL" and denied[0][1] == "resource", "the denial says Rage is missing")


func _test_stance_opens_after_windup() -> void:
	var world := _make_world([])
	world.warrior.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_check(not world.warrior.stance_active(), "the stance is not open during the windup")
	_step(world, _ticks(float(WarriorKit.SPECIAL["windup"])) + 1, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.ACTIVE and world.warrior.stance_active(), "the stance opens when the windup ends")


func _test_blocks_frontal_hit() -> void:
	var world := _make_world([])
	_open_stance(world)
	var blocked: Array = []
	world.warrior.attack_blocked.connect(func(source: Vector2) -> void: blocked.append(source))
	var health_before: float = world.warrior.health
	var source: Vector2 = world.warrior.position + Vector2(50, 0)
	var dealt: float = world.warrior.take_damage(40.0, source, false)
	_check(is_zero_approx(dealt) and is_equal_approx(world.warrior.health, health_before), "a frontal hit during the stance deals no damage")
	_check(blocked.size() == 1 and blocked[0] == source, "attack_blocked reports the source")
	_check(not world.warrior.vengeful_active, "a blocked hit does not trigger Vengeful Fury")


func _test_counter_damage_and_recovery() -> void:
	# Mismo dano de arma y sin criticos: el contraataque pega special.damage_mult
	# veces lo que pega M1 (cociente de multiplicadores).
	var world := _make_world([Vector2(44, 0)])
	_fix_damage(world)
	var enemy: DummySim = world.dummies[0]
	var damages: Array = []
	world.warrior.attack_hit.connect(func(skill: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: damages.append([skill["id"], damage]))
	_step(world, 1, _input({"m1": true}))
	_step(world, 60, _input({}))
	var m1_damage := float(damages[0][1]) if not damages.is_empty() else 0.0
	damages.clear()
	enemy.health = enemy.max_health
	world.warrior.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_step(world, _ticks(float(WarriorKit.SPECIAL["windup"])) + 1, _input({}))
	var rage_before: float = world.warrior.rage()
	world.warrior.take_damage(30.0, enemy.position, false)
	_check(damages.size() == 1 and damages[0][0] == &"iron_counter", "the block triggers the counter-strike")
	if damages.size() == 1:
		var expected := float(WarriorKit.SPECIAL["damage_mult"]) / float(WarriorKit.M1["damage_mult"])
		_check(absf(float(damages[0][1]) / m1_damage - expected) < 0.01, "the counter hits x%.1f harder than M1" % expected)
	_check(world.warrior.rage() > rage_before, "the counter-strike generates Rage")
	_check(world.warrior.state == WarriorSim.AttackState.RECOVERY, "after the counter it recovers")
	var counter_recovery := float(WarriorKit.SPECIAL["stance"]["counter_recovery"])
	_step(world, _ticks(counter_recovery) - 3, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.RECOVERY, "the counter recovery is still running just before it ends")
	_step(world, 6, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.IDLE, "and it is over after counter_recovery (%.2f s), faster than a whiff" % counter_recovery)


func _test_only_blocks_once() -> void:
	var world := _make_world([])
	_open_stance(world)
	var source: Vector2 = world.warrior.position + Vector2(50, 0)
	world.warrior.take_damage(40.0, source, false)
	var second: float = world.warrior.take_damage(40.0, source, false)
	_check(second > 0.0, "the stance only blocks one hit; the next one lands")


func _test_does_not_block_from_behind_or_dots() -> void:
	var world := _make_world([])
	_open_stance(world)
	var behind: Vector2 = world.warrior.position + Vector2(-50, 0)
	var health_before: float = world.warrior.health
	var dealt_behind: float = world.warrior.take_damage(20.0, behind, false)
	_check(dealt_behind > 0.0 and world.warrior.health < health_before, "a hit from behind is not blocked")
	_check(world.warrior.stance_active(), "and it does not spend the stance")
	var dealt_dot: float = world.warrior.take_damage(10.0, world.warrior.position + Vector2(50, 0), true)
	_check(dealt_dot > 0.0, "damage over time is not blocked")
	var dealt_unknown: float = world.warrior.take_damage(10.0, Vector2.ZERO, false)
	_check(dealt_unknown > 0.0, "a hit with no source position cannot be blocked")


func _test_whiff_has_full_recovery() -> void:
	var world := _make_world([])
	world.warrior.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	var windup_ticks := _ticks(float(WarriorKit.SPECIAL["windup"]))
	var active_ticks := _ticks(float(WarriorKit.SPECIAL["active"]))
	_step(world, windup_ticks + active_ticks + 3, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.RECOVERY and not world.warrior.stance_active(), "an unused stance expires into recovery")
	var recovery_ticks := _ticks(float(WarriorKit.SPECIAL["recovery"]))
	_step(world, recovery_ticks - 8, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.RECOVERY, "a whiff pays the full recovery")
	_step(world, 14, _input({}))
	_check(world.warrior.state == WarriorSim.AttackState.IDLE, "and then ends")


func _test_dodge_cancels_stance() -> void:
	var world := _make_world([])
	_open_stance(world)
	_step(world, 1, _input({"dodge": true}))
	_check(world.warrior.dodging, "the dodge can cancel the open stance")
	_check(not world.warrior.stance_active(), "and the stance is gone")


func _test_blocks_a_real_enemy_attack() -> void:
	var world := _make_world([])
	var slime := world.add_enemy(&"slime", world.warrior.position + Vector2(34, 0))
	var landed: Array = []
	var blocked: Array = []
	slime.attack_landed.connect(func(damage: float) -> void: landed.append(damage))
	world.warrior.attack_blocked.connect(func(_source: Vector2) -> void: blocked.append(true))
	var guard := 0
	while not (slime.is_telegraphing() and slime.telegraph_progress() > 0.5) and guard < 300:
		_step(world, 1, _input({}))
		guard += 1
	_check(slime.is_telegraphing(), "(preparacion) the slime is winding up")
	world.warrior.resource.current_amount = 100.0
	var health_before: float = world.warrior.health
	var slime_health_before := slime.health
	_step(world, 1, _input({"special": true}))
	_step(world, 90, _input({}))
	_check(blocked.size() == 1, "the stance blocks the slime's smash")
	_check(is_equal_approx(world.warrior.health, health_before), "the Warrior takes no damage from it (%.1f)" % (health_before - world.warrior.health))
	_check(slime.health < slime_health_before, "and the counter-strike hurts the slime")
	_check(landed.size() == 1 and is_zero_approx(float(landed[0])), "the slime's attack reports 0 damage dealt")


# --- Helpers ----------------------------------------------------------------


func _open_stance(world: CombatWorld) -> void:
	world.warrior.resource.current_amount = 100.0
	_step(world, 1, _input({"special": true}))
	_step(world, _ticks(float(WarriorKit.SPECIAL["windup"])) + 1, _input({}))


func _ticks(seconds: float) -> int:
	return int(ceil(seconds / DT))


func _make_world(offsets: Array) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(2)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.warrior.set_level(10)
	var origin: Vector2 = world.warrior.position
	for offset: Vector2 in offsets:
		world.add_dummy(origin + offset, false)
	return world


func _fix_damage(world: CombatWorld) -> void:
	world.warrior.stats.set_base_stat(&"weapon_min", 10.0)
	world.warrior.stats.set_base_stat(&"weapon_max", 10.0)
	world.warrior.stats.set_base_stat(&"crit_chance", 0.0)


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
