## Esquiva del Warrior (Fase 1.2): desplazamiento, i-frames, cooldown, buffer y
## cancelaciones.
##
##   godot --headless --path . --script tests/test_dodge.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0
## Movilidad de la clase probada (el Rogue rueda: el esquive clasico con invulnerabilidad).
var _mob: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_dodge (esquiva) ==")
	_test_moves_along_input()
	_test_idle_dodges_backward()
	_test_iframes()
	_test_dots_pass_through()
	_test_cooldown_and_hold()
	_test_cancels_windup()
	_test_not_in_active()
	_test_respects_bounds()
	_test_snapshot()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_moves_along_input() -> void:
	var world := _make_world()
	var start: Vector2 = world.player.position
	_step_until_dodge_ends(world, Vector2.RIGHT, Vector2.RIGHT)
	var moved: Vector2 = world.player.position - start
	var distance := float(_mob["distance"])
	_check(absf(moved.x - distance) < 8.0, "dodge covers the configured distance (%.1f vs %.1f)" % [moved.x, distance])
	_check(absf(moved.y) < 0.5, "dodge keeps the input direction")


func _test_idle_dodges_backward() -> void:
	var world := _make_world()
	var start: Vector2 = world.player.position
	# Sin movimiento y apuntando a la derecha: retrocede hacia la izquierda.
	_step_until_dodge_ends(world, Vector2.RIGHT, Vector2.ZERO)
	_check(world.player.position.x < start.x - 90.0, "a stationary dodge goes opposite to the aim")


func _test_iframes() -> void:
	var world := _make_world()
	var evaded: Array = []
	world.player.attack_evaded.connect(func(_pos: Vector2) -> void: evaded.append(true))
	_step(world, 1, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	_check(world.player.dodging, "pressing dodge starts a dodge")
	_check(world.player.is_invulnerable(), "the dodge starts invulnerable")
	var health_before: float = world.player.health
	var resource_before: float = world.player.resource_amount()
	var dealt: float = world.player.take_damage(30.0, Vector2.ZERO, false)
	_check(is_zero_approx(dealt) and is_equal_approx(world.player.health, health_before), "damage during i-frames is ignored")
	_check(evaded.size() == 1, "an evaded hit emits attack_evaded")
	_check(is_equal_approx(world.player.resource_amount(), resource_before), "an evaded hit does not change the resource")
	_check(not world.player.vengeful_active, "an evaded hit does not trigger Vengeful Fury")

	# Pasada la ventana de i-frames, todavia esquivando, vuelve a ser vulnerable.
	var window := float(_mob["iframe_end"])
	var ticks := int(ceil(window / DT)) + 1
	_step(world, ticks, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	_check(world.player.dodging and not world.player.is_invulnerable(), "i-frames end before the dodge ends")
	var dealt_after: float = world.player.take_damage(30.0, Vector2.ZERO, false)
	_check(dealt_after > 0.0, "damage after the i-frame window lands")


func _test_dots_pass_through() -> void:
	var world := _make_world()
	_step(world, 1, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	var dealt: float = world.player.take_damage(10.0, Vector2.ZERO, true)
	_check(dealt > 0.0, "damage over time is not blocked by i-frames")


func _test_cooldown_and_hold() -> void:
	var world := _make_world()
	_step_until_dodge_ends(world, Vector2.RIGHT, Vector2.RIGHT)
	_check(world.player.dodge_cooldown_left() > 0.0, "the dodge goes on cooldown")
	# Soltar y volver a pulsar con cooldown activo no esquiva.
	_step(world, 3, _input(Vector2.RIGHT, Vector2.RIGHT, false))
	_step(world, 1, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	_check(not world.player.dodging, "no dodge while on cooldown")
	# Mantener la tecla no encadena esquivas al terminar el cooldown.
	var wait := int(ceil(float(_mob["cooldown"]) / DT)) + 20
	_step(world, wait, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	_check(not world.player.dodging, "holding the key does not retrigger the dodge")
	_step(world, 2, _input(Vector2.RIGHT, Vector2.RIGHT, false))
	_step(world, 1, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	_check(world.player.dodging, "a fresh press after the cooldown dodges again")


func _test_cancels_windup() -> void:
	var world := _make_world()
	var finished: Array = []
	var hits: Array = []
	world.player.attack_finished.connect(func(skill: Dictionary) -> void: finished.append(skill))
	world.player.attack_hit.connect(func(_s: Dictionary, _t: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(true))
	_step(world, 4, _input(Vector2.RIGHT, Vector2.ZERO, false, false, true))
	_check(world.player.state == PlayerSim.AttackState.WINDUP, "M2 is winding up")
	_step(world, 1, _input(Vector2.RIGHT, Vector2.ZERO, true))
	_check(world.player.dodging, "dodge starts during WINDUP")
	_check(world.player.state == PlayerSim.AttackState.IDLE, "the dodge cancels the attack")
	_check(finished.size() == 1, "a cancelled attack emits attack_finished")
	_step(world, 40, _input(Vector2.RIGHT, Vector2.ZERO, false))
	_check(hits.is_empty(), "a cancelled WINDUP never resolves its hit")
	_check(world.player.attack_cooldown_left("M2") > 0.0, "cooldowns spent on a cancelled attack are kept")


func _test_not_in_active() -> void:
	var world := _make_world()
	_step(world, 1, _input(Vector2.RIGHT, Vector2.ZERO, false, false, true))
	var guard := 0
	while world.player.state != PlayerSim.AttackState.ACTIVE and guard < 120:
		_step(world, 1, _input(Vector2.RIGHT, Vector2.ZERO, false))
		guard += 1
	_check(world.player.state == PlayerSim.AttackState.ACTIVE, "reached the ACTIVE frames")
	_step(world, 1, _input(Vector2.RIGHT, Vector2.ZERO, true))
	_check(not world.player.dodging, "dodge cannot cancel the ACTIVE frames")
	var guard2 := 0
	while not world.player.dodging and guard2 < 30:
		_step(world, 1, _input(Vector2.RIGHT, Vector2.ZERO, false))
		guard2 += 1
	_check(world.player.dodging, "the buffered dodge fires right after the ACTIVE frames")


func _test_respects_bounds() -> void:
	var world := _make_world()
	world.player.position = Vector2(world.bounds.end.x - 20.0, world.bounds.get_center().y)
	_step_until_dodge_ends(world, Vector2.RIGHT, Vector2.RIGHT)
	_check(world.player.position.x <= world.bounds.end.x - PlayerSim.RADIUS + 0.01, "a dodge never leaves the arena")


func _test_snapshot() -> void:
	var world := _make_world()
	_step(world, 1, _input(Vector2.RIGHT, Vector2.RIGHT, true))
	var snap: Dictionary = world.player.snapshot()
	_check(bool(snap.get("dodging", false)), "snapshot reports dodging")
	_check(float(snap.get("dodge_cd", 0.0)) > 0.0, "snapshot reports the dodge cooldown")


# --- Helpers ----------------------------------------------------------------


func _make_world() -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(5)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.add_dummy(Vector2(850, 60), false)
	world.player.safe_zone = true
	world.player.switch_class("rogue")
	world.player.safe_zone = false
	_mob = world.player.mobility()
	return world


func _input(aim: Vector2, move: Vector2, dodge: bool, m1: bool = false, m2: bool = false) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = move
	message.aim_dir = aim.normalized()
	message.actions = {"m1": m1, "m2": m2, "dodge": dodge}
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


## Pulsa esquiva un tick y sigue hasta que termina (sin volver a pulsar).
func _step_until_dodge_ends(world: CombatWorld, aim: Vector2, move: Vector2) -> void:
	_step(world, 1, _input(aim, move, true))
	var guard := 0
	while world.player.dodging and guard < 120:
		_step(world, 1, _input(aim, move, false))
		guard += 1


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
