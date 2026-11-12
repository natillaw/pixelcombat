## Kit base de cada clase: 5 skills (M1, M2, S1, Special, Ultimate) distintas entre si, skills de mundo
## que se aprenden, una habilidad de movilidad propia (carga, rodar, blink, salto atras) y una forma
## propia de cargar la ultimate.
##
##   godot --headless --path . --script tests/test_kits.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_kits (kit base, movilidad y ultimates) ==")
	_test_base_kits()
	_test_world_skills()
	_test_mobility()
	_test_ultimate_sources()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _make(class_id: String, level: int = 6) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(31)
	world.setup_arena(Rect2(0, 0, 1200, 800))
	world.player.switch_class(class_id)
	world.player.set_level(level)
	world.player.resource.current_amount = 100.0
	return world


func _test_base_kits() -> void:
	for class_id: String in ClassCatalog.all_ids():
		var world := _make(class_id)
		var slots: Array = world.player.loadout.keys()
		slots.sort()
		_check(slots == ["M1", "M2", "S1", "SPECIAL", "ULTIMATE"], "%s: el kit base son 5 skills (%s)" % [class_id, str(slots)])
		var shapes := {}
		for slot: String in slots:
			var skill: Dictionary = world.player.loadout[slot]
			shapes["%s/%s" % [String(skill["slot"]), String(skill.get("shape", ""))]] = true
		var kinds := {}
		for slot: String in slots:
			kinds[String(world.player.loadout[slot]["kind"])] = true
		_check(kinds.size() >= 3, "%s: el kit mezcla tipos de skill (%s)" % [class_id, str(kinds.keys())])
		var cfg: Dictionary = world.player.class_def["ult_charge"]
		_check(not cfg.is_empty() and world.player.mobility().has("kind"), "%s: tiene movilidad y forma propia de cargar la ultimate" % class_id)
	var kinds_seen := {}
	for class_id: String in ClassCatalog.all_ids():
		kinds_seen[String(_make(class_id).player.mobility()["kind"])] = true
	_check(kinds_seen.has("charge") and kinds_seen.has("roll") and kinds_seen.has("blink") and kinds_seen.has("backstep") and kinds_seen.size() == 4, "cada clase tiene una movilidad distinta")


func _test_world_skills() -> void:
	var world := _make("mage", 12)
	_check(world.player.equip("S2", &"fireball") == "not_learned", "una skill de mundo no se equipa sin aprenderla")
	_check(not world.player.loadout.has("S2"), "ni llega sola por nivel")
	_check(world.player.learn_skill(&"fireball") and not world.player.learn_skill(&"fireball"), "se aprende una vez")
	_check(not world.player.learn_skill(&"frost_nova") and not world.player.learn_skill(&"cleaving_strike"), "no se aprende una skill base ni de otra clase")
	_check(world.player.loadout.has("S2") and world.player.loadout["S2"]["id"] == &"fireball", "al aprenderla se equipa en un hueco libre")
	var exported: Dictionary = world.player.export_state()
	var other := _make("warrior", 1)
	other.player.import_state(exported)
	_check(other.player.learned_skills == ["fireball"], "lo aprendido se guarda y se carga")


func _test_mobility() -> void:
	# Guerrero: la carga aturde 1 s al primer golpe.
	var world := _make("warrior")
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(90, 0))
	_step(world, 1, {"dodge": true}, Vector2.RIGHT, Vector2.RIGHT)
	_step(world, 25, {}, Vector2.RIGHT, Vector2.ZERO)
	_check(slime.statuses.has("stun") or slime.state == EnemySim.State.STUN, "la carga del guerrero aturde al enemigo")
	_check(slime.statuses.strength("stun") >= 0.0 and world.player.dodge_cooldown_total() >= 6.0, "y tiene su cooldown (%.1f s)" % world.player.dodge_cooldown_total())
	# Mago: blink de ~190 px casi instantaneo, sin aturdir.
	var mage := _make("mage")
	var start: Vector2 = mage.player.position
	_step(mage, 1, {"dodge": true}, Vector2.RIGHT, Vector2.RIGHT)
	_step(mage, 12, {}, Vector2.RIGHT, Vector2.ZERO)
	_check(mage.player.position.distance_to(start) > 170.0, "el blink del mago recorre ~190 px (%.0f)" % mage.player.position.distance_to(start))
	# Arquero: salto atras, lejos de donde apunta.
	var archer := _make("archer")
	start = archer.player.position
	_step(archer, 1, {"dodge": true}, Vector2.RIGHT, Vector2.ZERO)
	_step(archer, 20, {}, Vector2.RIGHT, Vector2.ZERO)
	_check(archer.player.position.x < start.x - 120.0, "el salto del arquero va hacia atras (%.0f)" % (archer.player.position.x - start.x))
	# Picaro: rueda con invulnerabilidad.
	var rogue := _make("rogue")
	_step(rogue, 1, {"dodge": true}, Vector2.RIGHT, Vector2.RIGHT)
	_check(rogue.player.dodging and rogue.player.is_invulnerable(), "el picaro rueda y es invulnerable al inicio")


func _test_ultimate_sources() -> void:
	# Guerrero: aguantar golpes carga la ultimate.
	var warrior := _make("warrior")
	warrior.player.ultimate_charge = 0.0
	warrior.player.take_damage(40.0, Vector2(100, 0), false)
	_check(warrior.player.ultimate_charge > 3.0, "el guerrero carga la ultimate al recibir dano (%.1f)" % warrior.player.ultimate_charge)
	# Picaro: esquivar un golpe carga mucho mas que recibirlo.
	var rogue := _make("rogue")
	rogue.player.ultimate_charge = 0.0
	_step(rogue, 1, {"dodge": true}, Vector2.RIGHT, Vector2.RIGHT)
	rogue.player.take_damage(30.0, Vector2(100, 0), false)
	_check(rogue.player.ultimate_charge >= 10.0, "el picaro carga la ultimate esquivando (%.1f)" % rogue.player.ultimate_charge)
	# Mago: lanzar hechizos la carga, aunque no acierten.
	var mage := _make("mage")
	mage.player.ultimate_charge = 0.0
	_step(mage, 1, {"s1": true}, Vector2.RIGHT, Vector2.ZERO)
	_step(mage, 40, {}, Vector2.RIGHT, Vector2.ZERO)
	_check(mage.player.ultimate_charge > 3.0, "el mago carga la ultimate al lanzar skills (%.1f)" % mage.player.ultimate_charge)
	# Arquero: un acierto lejano carga mas que uno cercano.
	var far_gain := _archer_gain(300.0)
	var near_gain := _archer_gain(90.0)
	_check(far_gain > near_gain, "el arquero carga mas con aciertos lejanos (%.1f vs %.1f)" % [far_gain, near_gain])


func _archer_gain(distance: float) -> float:
	var world := _make("archer")
	world.add_dummy(world.player.position + Vector2(distance, 0), false)
	world.player.ultimate_charge = 0.0
	_step(world, 1, {"m1": true}, Vector2.RIGHT, Vector2.ZERO)
	_step(world, 90, {}, Vector2.RIGHT, Vector2.ZERO)
	return world.player.ultimate_charge


func _step(world: CombatWorld, ticks: int, actions: Dictionary, aim: Vector2, move: Vector2) -> void:
	for i: int in range(ticks):
		var message: InputMessage = InputMessageScript.new()
		message.tick = 0
		message.peer_id = 1
		message.move_dir = move
		message.aim_dir = aim.normalized()
		message.actions = actions.duplicate()
		world.submit_input(message)
		world.step(DT)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
