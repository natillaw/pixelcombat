## Kit del Picaro rediseñado: Stealth/Vanish, Shadow Step, veneno, ejecucion, Roll con coste, jefes inmunes.
##
##   godot --headless --path . --script tests/test_rogue_kit.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_rogue_kit (picaro rediseñado) ==")
	_test_stealth()
	_test_damage_breaks_stealth()
	_test_vanish_survives_one_hit()
	_test_roll_cost()
	_test_boss_immunity()
	_test_normal_enemies_get_ccs()
	_test_execute()
	_test_venom_hits()
	_test_shadow_step()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _make(level: int = 10) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(77)
	world.setup_arena(Rect2(0, 0, 1200, 800))
	world.player.switch_class("rogue")
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


func _test_stealth() -> void:
	var world := _make()
	_step(world, 1, {"s3": true})
	_step(world, 60, {})
	_check(world.player.is_hidden(), "Stealth oculta al picaro")
	_step(world, 1, {"s3": true})
	_step(world, 60, {})
	_check(not world.player.is_hidden(), "volver a usar Stealth lo rompe")


func _test_damage_breaks_stealth() -> void:
	var world := _make()
	_step(world, 1, {"s3": true})
	_step(world, 60, {})
	world.player.take_damage(5.0)
	_check(not world.player.is_hidden(), "recibir dano rompe Stealth")


func _test_vanish_survives_one_hit() -> void:
	var world := _make()
	world.player.statuses.apply("vanish", 5.0, 0.3)
	world.player.vanish_hits_left = 1
	world.player.take_damage(5.0)
	_check(world.player.is_hidden(), "Vanish aguanta el primer golpe")
	world.player.take_damage(5.0)
	_check(not world.player.is_hidden(), "y se rompe con el segundo")


func _test_roll_cost() -> void:
	var world := _make()
	var before: float = world.player.resource.get_current()
	_step(world, 1, {"dodge": true})
	_check(world.player.resource.get_current() < before, "el Roll cuesta Energy")


func _test_boss_immunity() -> void:
	var world := _make()
	var rask := world.add_enemy(&"bandit_rask", Vector2(400, 400))
	_check(not rask.statuses.apply("stun", 1.0), "un jefe es inmune al aturdimiento")
	_check(not rask.statuses.apply("disarm", 1.0), "y al desarme")


func _test_normal_enemies_get_ccs() -> void:
	var world := _make()
	var beetle := world.add_enemy(&"beetle", Vector2(400, 400))
	_check(beetle.statuses.apply("stun", 1.0), "un enemigo normal si se aturde")
	_check(beetle.statuses.apply("disarm", 1.0), "y se desarma")


func _test_execute() -> void:
	var world := _make()
	var beetle := world.add_enemy(&"beetle", world.player.position + Vector2(190, 0))
	beetle.health = beetle.max_health * 0.2
	world.player.ultimate_charge = 100.0
	_step(world, 1, {"ultimate": true})
	_step(world, 90, {})
	_check(not beetle.alive, "Death Sentence ejecuta a quien tiene poca vida")


func _test_venom_hits() -> void:
	var world := _make()
	world.player.venom_hits = 4
	var beetle := world.add_enemy(&"beetle", world.player.position + Vector2(40, 0))
	_step(world, 1, {"basic": true})
	_step(world, 30, {})
	_check(beetle.statuses.has("poison") and world.player.venom_hits == 3, "un golpe con veneno envenena y gasta una carga")


func _test_shadow_step() -> void:
	var world := _make()
	var beetle := world.add_enemy(&"beetle", world.player.position + Vector2(120, 0))
	_step(world, 1, {"s2": true})
	_step(world, 30, {})
	_check(world.player.position.distance_to(beetle.position) < 60.0, "Shadow Step te lleva junto al enemigo")
