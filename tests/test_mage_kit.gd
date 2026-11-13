## Kit del Mago rediseñado: basico con coste y chispazo, Arcane Surge, Mana Shield, Ice Lance vs ralentizados, quemadura.
##
##   godot --headless --path . --script tests/test_mage_kit.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_mage_kit (mago rediseñado) ==")
	_test_basic_costs_mana()
	_test_spark_without_mana()
	_test_surge()
	_test_mana_shield()
	_test_ice_lance_bonus()
	_test_burn()
	_test_blink_cost()
	_test_slots()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _make(level: int = 10) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(77)
	world.setup_arena(Rect2(0, 0, 1200, 800))
	world.player.switch_class("mage")
	world.player.set_level(level)
	world.player.resource.current_amount = 100.0
	world.player.aim_dir = Vector2.RIGHT
	return world


func _step(world: CombatWorld, ticks: int, actions: Dictionary = {}) -> void:
	for i: int in range(ticks):
		var message: InputMessage = InputMessageScript.new()
		message.tick = 0
		message.peer_id = 1
		message.aim_dir = Vector2.RIGHT
		message.actions = actions.duplicate()
		world.submit_input(message)
		world.step(DT)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if ok:
		print("   ok   %s" % label)
	else:
		_failures += 1
		print("   FAIL %s" % label)


func _damages(world: CombatWorld) -> Array:
	var out: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: out.append(damage))
	return out


func _fix(world: CombatWorld) -> void:
	world.player.stats.set_base_stat(&"crit_chance", 0.0)
	world.player.stats.set_base_stat(&"weapon_min", 10.0)
	world.player.stats.set_base_stat(&"weapon_max", 10.0)


func _test_basic_costs_mana() -> void:
	var world := _make(1)
	world.add_enemy(&"slime", world.player.position + Vector2(100, 0))
	var before: float = world.player.resource.get_current()
	_step(world, 3, {"basic": true})
	_step(world, 3, {})
	_check(world.player.resource.get_current() < before, "Arcane Bolt cuesta mana")


func _test_spark_without_mana() -> void:
	var full := _make(1)
	var dry := _make(1)
	for world: CombatWorld in [full, dry]:
		_fix(world)
		var enemy := world.add_enemy(&"slime", world.player.position + Vector2(80, 0))
		enemy.max_health = 1.0e6
		enemy.health = 1.0e6
	dry.player.resource.current_amount = 0.0
	var a := _damages(full)
	var b := _damages(dry)
	_step(full, 3, {"basic": true})
	_step(full, 60, {})
	_step(dry, 3, {"basic": true})
	_step(dry, 60, {})
	_check(not a.is_empty() and not b.is_empty() and float(b[0]) < float(a[0]) * 0.5, "sin mana sale un chispazo mucho mas debil")


func _test_surge() -> void:
	var world := _make(10)
	_step(world, 1, {"s1": true})
	_step(world, 70, {})
	_check(world.player.statuses.has("surge"), "usar una skill da Arcane Surge")
	var mana: float = world.player.resource.get_current()
	_step(world, 3, {"basic": true})
	_step(world, 3, {})
	_check(not world.player.statuses.has("surge") and world.player.resource.get_current() >= mana, "el siguiente basico lo consume y sale gratis")


func _test_mana_shield() -> void:
	var world := _make(10)
	world.player.statuses.apply("manashield", 6.0, 0.6)
	var mana: float = world.player.resource.get_current()
	world.player.take_damage(20.0)
	_check(world.player.resource.get_current() < mana, "Mana Shield paga parte del dano con mana")


func _test_ice_lance_bonus() -> void:
	var results: Array = []
	for slowed: bool in [false, true]:
		var world := _make(10)
		_fix(world)
		world.player.learn_skill(&"ice_lance")
		world.player.equip("S1", &"ice_lance")
		var enemy := world.add_enemy(&"slime", world.player.position + Vector2(100, 0))
		enemy.max_health = 1.0e6
		enemy.health = 1.0e6
		if slowed:
			enemy.statuses.apply("slow", 5.0, 0.3)
		var damages := _damages(world)
		_step(world, 1, {"s1": true})
		_step(world, 60, {})
		results.append(float(damages[0]) if not damages.is_empty() else -1.0)
	_check(float(results[0]) > 0.0 and float(results[1]) > float(results[0]) * 1.8, "Ice Lance hace el doble contra un ralentizado")


func _test_burn() -> void:
	var world := _make(10)
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(100, 0))
	slime.max_health = 1.0e6
	slime.health = 1.0e6
	_step(world, 1, {"s1": true})
	_step(world, 90, {})
	_check(slime.health < slime.max_health and slime.statuses.has("burn"), "Fireball deja al enemigo ardiendo")


func _test_blink_cost() -> void:
	var world := _make(10)
	var mana: float = world.player.resource.get_current()
	_step(world, 1, {"dodge": true})
	_check(world.player.resource.get_current() < mana, "Blink cuesta mana")


func _test_slots() -> void:
	var low := _make(3)
	_check(low.player.loadout.has("S1") and not low.player.loadout.has("S2"), "nivel 3: solo la Q (Fireball)")
	var high := _make(10)
	_check(high.player.loadout.has("S3") and String(high.player.loadout["S3"]["id"]) == "arcane_orb" and high.player.loadout.has("ULTIMATE"), "nivel 10: R (Arcane Orb) y la ultimate")
