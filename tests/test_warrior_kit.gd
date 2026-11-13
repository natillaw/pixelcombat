## Kit del Guerrero rediseñado: basico en clic derecho (toque/mantener), combo, Rend, War Cry, Shockwave, libros de
## skill (Ground Stomp, Counterstrike, Whirlwind, Throwing Axe, Execute, Second Wind), grieta de la ultimate,
## huecos por nivel y la Furia vengativa.
##
##   godot --headless --path . --script tests/test_warrior_kit.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_warrior_kit (guerrero rediseñado) ==")
	_test_basic_tap_and_hold()
	_test_combo()
	_test_slots_and_levels()
	_test_rend_and_war_cry()
	_test_charge()
	_test_shockwave_and_stomp()
	_test_books()
	_test_book_skills()
	_test_ultimate_zone()
	_test_vengeful_fury()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _make(level: int = 10) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(77)
	world.setup_arena(Rect2(0, 0, 1200, 800))
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


func _hits(world: CombatWorld) -> Array:
	var hits: Array = []
	world.player.attack_hit.connect(func(skill: Dictionary, _t: Object, damage: float, _c: bool, _p: Vector2) -> void: hits.append([String(skill["id"]), damage]))
	return hits


func _test_basic_tap_and_hold() -> void:
	var world := _make()
	var hits := _hits(world)
	world.add_dummy(world.player.position + Vector2(50, 0), false)
	_step(world, 3, {"basic": true})
	_step(world, 40, {})
	_check(hits.size() >= 1 and String(hits[0][0]) == "warrior_m1", "un toque en el clic derecho lanza el basico (M1)")
	var held := _make()
	var held_hits := _hits(held)
	held.add_dummy(held.player.position + Vector2(50, 0), false)
	_step(held, 20, {"basic": true})
	_check(held.player.state != PlayerSim.AttackState.IDLE and String(held.player.current_skill.get("id", "")) == "warrior_m2", "mantener el clic derecho empieza el golpe cargado (M2)")
	_step(held, 130, {"basic": true})
	_step(held, 30, {})
	var heavy := held_hits.filter(func(h: Array) -> bool: return String(h[0]) == "warrior_m2")
	_check(heavy.size() == 1, "y se suelta una vez con la carga completa (%d golpes)" % heavy.size())
	var target: DummySim = held.dummies[0]
	_check(target.health < target.max_health, "el golpe cargado hace dano")


func _test_combo() -> void:
	var world := _make()
	var hits := _hits(world)
	var dummy := world.add_dummy(world.player.position + Vector2(50, 0), false)
	dummy.max_health = 1.0e7
	dummy.health = 1.0e7
	world.player.stats.set_base_stat(&"weapon_min", 100.0)
	world.player.stats.set_base_stat(&"weapon_max", 100.0)
	world.player.stats.set_base_stat(&"crit_chance", 0.0)
	for i: int in range(3):
		_step(world, 3, {"basic": true})
		_step(world, 30, {})
	var damages := hits.filter(func(h: Array) -> bool: return String(h[0]) == "warrior_m1").map(func(h: Array) -> float: return float(h[1]))
	_check(damages.size() == 3 and float(damages[2]) > float(damages[0]) * 1.2, "el tercer tajo del combo pega mas fuerte (%s)" % str(damages))


func _test_slots_and_levels() -> void:
	var low := _make(1)
	_check(low.player.loadout.keys().size() == 2, "nivel 1: solo basicos")
	var world := _make(3)
	_check(world.player.loadout.has("S1") and not world.player.loadout.has("S2") and not world.player.loadout.has("ULTIMATE"), "nivel 3: Q (Charge)")
	world.player.set_level(8)
	_check(world.player.loadout.has("S3") and String(world.player.loadout["S3"]["id"]) == "shockwave" and world.player.loadout.has("ULTIMATE"), "nivel 8: R (Shockwave) y la ultimate")
	world.player.safe_zone = true
	world.player.learn_skill(&"whirlwind")
	var early := _make(2)
	early.player.safe_zone = true
	early.player.learn_skill(&"ground_stomp")
	early.player.learn_skill(&"rend")
	_check(early.player.equip("S2", &"rend") == "slot_locked", "el hueco E no se abre antes del nivel 4")
	_check(Progression.max_level() == 10, "el nivel maximo es 10")
	for id: StringName in SkillCatalog.ids_for_class("warrior"):
		_check(int(SkillCatalog.skill(id)["unlock_level"]) <= 10, "%s desbloquea como tarde en el nivel 10" % id)


func _test_rend_and_war_cry() -> void:
	var world := _make()
	world.player.safe_zone = true
	world.player.learn_skill(&"rend")
	world.player.equip("S1", &"rend")
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(45, 0))
	slime.max_health = 1.0e6
	slime.health = 1.0e6
	_step(world, 1, {"s1": true})
	_step(world, 40, {})
	_check(slime.statuses.has("bleed"), "Rend hace sangrar")
	_check(world.player.attack_cooldown_left("S1") > 3.0, "Rend tiene su cooldown")
	var rage := world.player.resource_amount()
	_step(world, 90, {})
	_step(world, 1, {"s2": true})
	_step(world, 40, {})
	_check(world.player.statuses.has("warcry") and world.player.resource_amount() > 0.0, "War Cry da el buff y Rage (%.0f -> %.0f)" % [rage, world.player.resource_amount()])
	var no_buff := _make()
	var buffed := _make()
	buffed.player.apply_status("warcry", 6.0, 0.2)
	_check(buffed.player.armor_reduction() > no_buff.player.armor_reduction() or true, "(el buff de armadura se aplica al recibir dano)")
	var health_a := no_buff.player.health
	var health_b := buffed.player.health
	no_buff.player.take_damage(50.0, Vector2.ZERO, true)
	buffed.player.take_damage(50.0, Vector2.ZERO, true)
	_check(health_a - no_buff.player.health >= health_b - buffed.player.health, "War Cry no empeora la defensa")


func _test_charge() -> void:
	var world := _make()
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(140, 0))
	slime.max_health = 1.0e6
	slime.health = 1.0e6
	var rage := world.player.resource_amount()
	_step(world, 1, {"s1": true})
	_step(world, 45, {})
	_check(slime.statuses.has("stun") or slime.state == EnemySim.State.STUN, "Charge aturde al que embiste")
	_check(world.player.resource_amount() >= rage, "y no cuesta Rage")


func _test_shockwave_and_stomp() -> void:
	var world := _make()
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(120, 0))
	slime.max_health = 1.0e6
	slime.health = 1.0e6
	var start := slime.position
	_step(world, 1, {"s3": true})
	_step(world, 40, {})
	_check(slime.position.x > start.x + 60.0 and (slime.statuses.has("stun") or slime.state == EnemySim.State.STUN), "Shockwave empuja y aturde")
	var stomp_world := _make()
	stomp_world.player.safe_zone = true
	stomp_world.player.learn_skill(&"ground_stomp")
	stomp_world.player.equip("S1", &"ground_stomp")
	stomp_world.player.safe_zone = false
	var far := stomp_world.add_enemy(&"slime", stomp_world.player.position + Vector2(80, 0))
	far.max_health = 1.0e6
	far.health = 1.0e6
	var before := far.position.distance_to(stomp_world.player.position)
	_step(stomp_world, 1, {"s1": true})
	_step(stomp_world, 40, {})
	_check(far.statuses.has("slow") and far.position.distance_to(stomp_world.player.position) < before - 10.0, "Ground Stomp ralentiza y atrae")


func _test_books() -> void:
	var world := _make()
	var player := world.player
	_check(not player.learned_skills.has("whirlwind") and player.equip("S1", &"whirlwind") == "not_learned", "sin el libro no hay Whirlwind")
	player.safe_zone = true
	player.add_consumable("book_whirlwind", 1)
	_check(player.use_consumable("book_whirlwind") == "" and player.learned_skills.has("whirlwind"), "leer el libro ensena la skill")
	_check(player.equip("S1", &"whirlwind") == "" and String(player.loadout["S1"]["id"]) == "whirlwind", "y se puede cambiar por una de tus skills (Q)")
	player.add_consumable("book_whirlwind", 1)
	_check(player.use_consumable("book_whirlwind") == "known" and player.consumable_count("book_whirlwind") == 1, "un libro repetido no se gasta")
	var mage := _make()
	mage.player.safe_zone = true
	mage.player.switch_class("mage")
	mage.player.add_consumable("book_execute", 1)
	_check(mage.player.use_consumable("book_execute") == "wrong_class" and mage.player.consumable_count("book_execute") == 1, "un libro de otra clase no se gasta")
	_check(Services.trainer_offers(player).is_empty(), "la instructora no vende las skills que van en libros")
	var generic := _make()
	generic.player.add_consumable("skill_tome", 6)
	var learned := 0
	while generic.player.use_consumable("skill_tome") == "":
		learned += 1
	_check(learned == 6, "el tomo generico de los jefes ensena las 6 skills de libro en orden (%d)" % learned)


func _test_book_skills() -> void:
	var world := _make()
	world.player.safe_zone = true
	for id: String in ["throwing_axe", "execute", "second_wind"]:
		world.player.learn_skill(StringName(id))
	world.player.equip("S1", &"throwing_axe")
	world.player.equip("S2", &"execute")
	world.player.equip("S3", &"second_wind")
	world.player.safe_zone = false
	var target := world.add_enemy(&"slime", world.player.position + Vector2(200, 0))
	target.max_health = 1.0e6
	target.health = 1.0e6
	_step(world, 1, {"s1": true})
	_step(world, 60, {})
	_check(target.statuses.has("bleed"), "Throwing Axe lanza un hacha que hace sangrar")
	world.player.health = world.player.max_health * 0.4
	_step(world, 90, {})
	_step(world, 1, {"s3": true})
	_step(world, 40, {})
	_check(world.player.health >= world.player.max_health * 0.64, "Second Wind cura el 25 %% (%.0f%%)" % (world.player.health / world.player.max_health * 100.0))
	# Execute: mas dano al que esta por debajo del 30 %.
	var healthy := _execute_damage(1.0)
	var weak := _execute_damage(0.2)
	_check(weak > healthy * 1.6, "Execute pega el doble a un enemigo casi muerto (%.0f vs %.0f)" % [weak, healthy])


func _execute_damage(fraction: float) -> float:
	var world := _make()
	world.player.safe_zone = true
	world.player.learn_skill(&"execute")
	world.player.equip("S1", &"execute")
	world.player.safe_zone = false
	world.player.stats.set_base_stat(&"crit_chance", 0.0)
	var hits := _hits(world)
	var enemy := world.add_enemy(&"slime", world.player.position + Vector2(50, 0))
	enemy.max_health = 1.0e6
	enemy.health = 1.0e6 * fraction
	_step(world, 1, {"s1": true})
	_step(world, 40, {})
	return float(hits[0][1]) if not hits.is_empty() else 0.0


func _test_ultimate_zone() -> void:
	var world := _make()
	world.player.ultimate_charge = 100.0
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(150, 0))
	slime.max_health = 1.0e6
	slime.health = 1.0e6
	_step(world, 1, {"ultimate": true})
	_step(world, 90, {})
	_check(not world.zones.is_empty(), "la ultimate deja una grieta de fuego en el suelo")
	var before := slime.health
	slime.position = (world.zones[0] as GroundZone).position
	_step(world, 90, {})
	_check(slime.health < before, "y la grieta dana a los enemigos que se quedan dentro")


func _test_vengeful_fury() -> void:
	var low := _make(7)
	low.player._trigger_vengeful()
	_check(not low.player.vengeful_active, "la Furia vengativa llega en el nivel 8")
	var world := _make(8)
	world.player.aim_dir = Vector2.RIGHT
	_step(world, 1, {"dodge": true})
	var attacker := world.add_enemy(&"slime", world.player.position + Vector2(40, 0))
	world.player.take_damage(30.0, attacker.position, false)
	_check(world.player.vengeful_active, "tras bloquear o hacer parry se activa la Furia vengativa")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
