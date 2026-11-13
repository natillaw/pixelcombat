## Estados alterados (stun, slow, veneno): StatusSet, catalogo, efectos en el
## jugador y en los enemigos, skills que los aplican y ataques enemigos que los
## ponen al jugador.
##
##   godot --headless --path . --script tests/test_status.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_status (estados alterados) ==")
	_test_catalog()
	_test_status_set_rules()
	_test_poison_ticks()
	_test_player_stun()
	_test_player_slow_and_poison()
	_test_stun_immunity_window()
	_test_enemy_stun_interrupts_attacks()
	_test_enemy_slow_poison_and_resist()
	_test_skills_apply_statuses()
	_test_poison_kill_gives_xp()
	_test_enemy_attacks_apply_statuses()
	_test_evaded_or_blocked_hits_apply_nothing()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Datos y reglas ---------------------------------------------------------------


func _test_catalog() -> void:
	for error: String in StatusCatalog.errors():
		print("   error de carga: %s" % error)
	_check(StatusCatalog.errors().is_empty() and StatusCatalog.all_ids() == ["stun", "slow", "poison", "bleed", "silence", "shield", "knockback", "fed", "might", "haste", "warcry", "pull", "stealth", "vanish", "concealed", "backstab", "disarm", "stagger", "burn", "surge", "manashield"], "data/statuses.json carga con los veintiun estados")
	_check(StatusCatalog.validate_on_hit([{"id": "stun", "duration": 0.5}]).is_empty(), "un stun solo necesita duracion")
	_check(not StatusCatalog.validate_on_hit([{"id": "slow", "duration": 2.0}]).is_empty(), "un slow sin strength se rechaza")
	_check(not StatusCatalog.validate_on_hit([{"id": "poison", "duration": 2.0}]).is_empty(), "un veneno sin strength se rechaza")
	_check(not StatusCatalog.validate_on_hit([{"id": "miedo", "duration": 2.0}]).is_empty(), "un estado desconocido se rechaza")
	_check(not StatusCatalog.validate_on_hit([{"id": "stun", "duration": 0.0}]).is_empty(), "una duracion 0 se rechaza")
	_check(not StatusCatalog.validate_on_hit([]).is_empty(), "una lista vacia se rechaza")
	var bad_skill := SkillCatalog.skill(&"crushing_blow")
	bad_skill["on_hit"] = [{"id": "slow", "duration": 1.0}]
	_check(not SkillCatalog.validate(bad_skill).is_empty(), "el catalogo de skills valida on_hit")
	var bad_enemy := EnemyCatalog.enemy(&"slime")
	bad_enemy["attacks"][0]["on_hit"] = [{"id": "nope", "duration": 1.0}]
	_check(not EnemyCatalog.validate(bad_enemy).is_empty(), "el catalogo de enemigos valida on_hit")
	var bad_resist := EnemyCatalog.enemy(&"slime")
	bad_resist["resist"] = {"stun": 2.0}
	_check(not EnemyCatalog.validate(bad_resist).is_empty(), "una resistencia fuera de 0..1 se rechaza")


func _test_status_set_rules() -> void:
	var set := StatusSet.new()
	_check(not set.apply("miedo", 1.0) and not set.apply("stun", 0.0), "estado desconocido o duracion 0: no se aplica")
	_check(set.apply("slow", 2.0, 0.4) and set.has("slow") and is_equal_approx(set.strength("slow"), 0.4), "se aplica un slow")
	_check(is_equal_approx(set.speed_mult(), 0.6), "slow 0,4 deja el 60 % de velocidad")
	set.apply("slow", 1.0, 0.2)
	_check(is_equal_approx(set.remaining("slow"), 2.0) and is_equal_approx(set.strength("slow"), 0.4), "reaplicar no se acumula: conserva lo mayor")
	set.apply("slow", 9.0, 0.95)
	_check(is_equal_approx(set.remaining("slow"), 4.0) and is_equal_approx(set.strength("slow"), 0.6), "los topes del catalogo limitan duracion (4 s) y fuerza (0,6)")
	var expired: Array = []
	set.expired.connect(func(id: String) -> void: expired.append(id))
	set.step(4.1)
	_check(not set.has("slow") and expired == ["slow"] and is_equal_approx(set.speed_mult(), 1.0), "expira y emite expired")

	set.apply("stun", 5.0)
	_check(is_equal_approx(set.remaining("stun"), 2.0), "un stun se limita a 2 s")
	_check(set.is_stunned() and is_zero_approx(set.speed_mult()), "aturdido: velocidad 0")
	set.step(2.1)
	_check(not set.is_stunned() and set.is_immune("stun"), "al acabar el stun hay inmunidad")
	_check(not set.apply("stun", 1.0), "y no se puede encadenar otro stun")
	set.step(2.6)
	_check(set.apply("stun", 1.0), "pasada la inmunidad vuelve a poder aplicarse")

	var boss := StatusSet.new()
	boss.resist = {"stun": 1.0, "slow": 0.5}
	_check(not boss.apply("stun", 1.0) and boss.is_immune("stun"), "resistencia 1 = inmune")
	boss.apply("slow", 2.0, 0.4)
	_check(is_equal_approx(boss.remaining("slow"), 1.0), "resistencia 0,5 = duracion a la mitad")
	boss.clear()
	_check(boss.active_ids().is_empty(), "clear() quita todo")


func _test_poison_ticks() -> void:
	var set := StatusSet.new()
	set.apply("poison", 3.0, 6.0)
	var total := 0.0
	var ticks := 0
	for i: int in range(240):
		var dot := set.step(DT)
		if dot > 0.0:
			total += dot
			ticks += 1
	_check(ticks == 6 and absf(total - 18.0) < 0.5, "6 dano/s durante 3 s = 18 en 6 golpes de 0,5 s (%d golpes, %.1f)" % [ticks, total])
	_check(not set.has("poison"), "el veneno acaba")


# --- Jugador ------------------------------------------------------------------------


func _test_player_stun() -> void:
	var world := _world()
	var player: PlayerSim = world.player
	player.set_level(10)
	LegacyKit.apply(player)
	player.resource.current_amount = 100.0
	_step(world, 1, _input({"m2": true}))
	_check(player.state != PlayerSim.AttackState.IDLE, "(preparacion) el jugador esta atacando")
	var applied: Array = []
	player.status_applied.connect(func(id: String) -> void: applied.append(id))
	_check(player.apply_status("stun", 1.0), "el jugador acepta un stun")
	_check(applied == ["stun"], "y emite status_applied")
	_check(player.state == PlayerSim.AttackState.IDLE, "el stun cancela el ataque")
	_step(world, 1, _input({"m1": true, "s1": true, "dodge": true}))
	_check(player.state == PlayerSim.AttackState.IDLE and not player.dodging, "aturdido no ataca ni esquiva")
	var before := player.position
	_step(world, 20, _input({}, Vector2.RIGHT))
	_check(player.position.distance_to(before) < 1.0, "ni se mueve")
	_step(world, 60, _input({}))
	_check(not player.statuses.is_stunned(), "el stun acaba")
	_step(world, 1, _input({"m1": true}))
	_step(world, 1, _input({"m1": true}))
	_check(player.state != PlayerSim.AttackState.IDLE, "y vuelve a poder atacar")

	var world2 := _world()
	world2.player.safe_zone = true
	world2.player.switch_class("rogue")
	world2.player.safe_zone = false
	world2.player.set_level(2)
	_step(world2, 1, _input({}, Vector2.RIGHT))
	_step(world2, 1, _input({"dodge": true}, Vector2.RIGHT))
	_check(world2.player.dodging, "(preparacion) esquivando")
	world2.player.apply_status("stun", 0.5)
	_check(not world2.player.dodging, "un stun corta la esquiva")


func _test_player_slow_and_poison() -> void:
	var world := _world()
	_step(world, 30, _input({}, Vector2.RIGHT))
	var free_speed: float = world.player.velocity.length()
	world.player.apply_status("slow", 3.0, 0.5)
	_step(world, 30, _input({}, Vector2.RIGHT))
	_check(absf(world.player.velocity.length() - free_speed * 0.5) < 2.0, "un slow del 50 %% reduce la velocidad a la mitad (%.0f -> %.0f)" % [free_speed, world.player.velocity.length()])

	var world2 := _world()
	var health: float = world2.player.health
	world2.player.apply_status("poison", 4.0, 5.0)
	_step(world2, 90, _input({}))
	_check(world2.player.health < health - 3.0, "el veneno quita vida con el tiempo (%.1f)" % (health - world2.player.health))
	_check(is_zero_approx(world2.player.resource_amount()), "y no regala Rage al Warrior")
	# El veneno ignora los i-frames de la esquiva.
	var world3 := _world()
	world3.player.safe_zone = true
	world3.player.switch_class("rogue")
	world3.player.safe_zone = false
	world3.player.apply_status("poison", 4.0, 5.0)
	_step(world3, 1, _input({"dodge": true}, Vector2.RIGHT))
	_check(world3.player.is_invulnerable(), "(preparacion) hay i-frames")
	var health3: float = world3.player.health
	world3.player.statuses._active["poison"]["tick_left"] = 0.001  # el siguiente tick cae dentro de los i-frames
	_step(world3, 2, _input({}, Vector2.RIGHT))
	_check(world3.player.is_invulnerable() and world3.player.health < health3, "el veneno atraviesa los i-frames")
	world3.player.reset(world3.bounds.get_center())
	_check(world3.player.statuses.active_ids().is_empty(), "reset() limpia los estados")


func _test_stun_immunity_window() -> void:
	var world := _world()
	_check(world.player.apply_status("stun", 0.4), "primer stun")
	_step(world, 40, _input({}))
	_check(not world.player.apply_status("stun", 0.4), "inmune justo despues: no se encadena")
	_step(world, 200, _input({}))
	_check(world.player.apply_status("stun", 0.4), "pasada la inmunidad, otra vez")


# --- Enemigos -----------------------------------------------------------------------


func _test_enemy_stun_interrupts_attacks() -> void:
	var world := _world()
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(34, 0))
	var landed: Array = []
	slime.attack_landed.connect(func(damage: float) -> void: landed.append(damage))
	var guard := 0
	while not slime.is_telegraphing() and guard < 200:
		_step(world, 1, _input({}))
		guard += 1
	_check(slime.is_telegraphing(), "(preparacion) el slime avisa su golpe")
	_check(slime.apply_status("stun", 1.0), "el slime acepta un stun")
	_check(slime.state == EnemySim.State.STUN and slime.current_attack.is_empty(), "el stun interrumpe el ataque en curso")
	_step(world, 50, _input({}))
	_check(landed.is_empty(), "y el golpe que avisaba nunca cae")
	var spot := slime.position
	_step(world, 20, _input({}))
	_check(slime.position == spot, "aturdido no se mueve")
	_step(world, 100, _input({}))
	_check(slime.state != EnemySim.State.STUN, "al acabar vuelve a luchar")


func _test_enemy_slow_poison_and_resist() -> void:
	var world := _world()
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(150, 0))
	slime.take_damage(1.0)
	slime.apply_status("slow", 5.0, 0.5)
	var before := slime.position
	_step(world, 30, _input({}))
	var slowed := before.distance_to(slime.position)
	var control_world := _world()
	var control := control_world.add_enemy(&"slime", control_world.player.position + Vector2(150, 0))
	control.take_damage(1.0)
	var control_before := control.position
	_step(control_world, 30, _input({}))
	_check(slowed < control_before.distance_to(control.position) * 0.6, "un slow del 50 %% frena al enemigo (%.1f vs %.1f px)" % [slowed, control_before.distance_to(control.position)])

	var victim := _world().add_enemy(&"slime", Vector2(100, 100))
	var health := victim.health
	victim.apply_status("poison", 4.0, 8.0)
	for i: int in range(150):
		victim.step(i, DT, null)
	_check(victim.health < health - 10.0, "el veneno daña al enemigo con el tiempo (%.1f)" % (health - victim.health))

	var boss_world := _world()
	var boss := boss_world.add_enemy(&"brood_beetle", Vector2(300, 100))
	_check(not boss.apply_status("stun", 1.0) and boss.state != EnemySim.State.STUN, "el jefe es inmune al stun")
	boss.apply_status("slow", 2.0, 0.4)
	_check(is_equal_approx(boss.statuses.remaining("slow"), 1.0), "y el slow le dura la mitad")
	var dummy := _world().add_dummy(Vector2(50, 50), false)
	_check(not dummy.has_method("apply_status"), "(sanidad) los munecos no tienen estados y las skills lo toleran")


# --- Skills y ataques ------------------------------------------------------------------


func _test_skills_apply_statuses() -> void:
	# Crushing Blow: stun al enemigo golpeado.
	var world := _world()
	world.player.set_level(10)
	LegacyKit.apply(world.player)
	world.player.resource.current_amount = 100.0
	var slime := world.add_enemy(&"slime", world.player.position + Vector2(50, 0))
	_step(world, 1, _input({"s3": true}))
	_step(world, 40, _input({}))
	_check(world.player.loadout.has("S3") and world.player.loadout["S3"]["id"] == &"crushing_blow", "(preparacion) Crushing Blow esta en S3 a nivel 10")
	_check(slime.statuses.has("stun") or slime.state == EnemySim.State.STUN, "Crushing Blow aturde al enemigo")

	# Ground Stomp: slow en area.
	var stomp_world := _world()
	stomp_world.player.set_level(24)
	LegacyKit.apply(stomp_world.player)
	stomp_world.player.resource.current_amount = 100.0
	var near := stomp_world.add_enemy(&"slime", stomp_world.player.position + Vector2(60, 0))
	var far := stomp_world.add_enemy(&"slime", stomp_world.player.position + Vector2(300, 0))
	var slot := ""
	for candidate: String in stomp_world.player.loadout:
		if stomp_world.player.loadout[candidate]["id"] == &"ground_stomp":
			slot = candidate
	_check(not slot.is_empty(), "(preparacion) Ground Stomp esta equipada a nivel 24")
	_step(stomp_world, 1, _input({slot.to_lower(): true}))
	_step(stomp_world, 40, _input({}))
	_check(near.statuses.has("slow") and is_equal_approx(near.statuses.strength("slow"), 0.45), "Ground Stomp ralentiza a los cercanos")
	_check(not far.statuses.has("slow"), "y no a los lejanos")

	# Frost Nova (Mage): stun y slow a la vez.
	var nova_world := _world()
	nova_world.player.switch_class("mage")
	nova_world.player.set_level(12)
	LegacyKit.apply(nova_world.player)
	nova_world.player.resource.current_amount = 100.0
	var target := nova_world.add_enemy(&"slime", nova_world.player.position + Vector2(50, 0))
	var nova_slot := ""
	for candidate: String in nova_world.player.loadout:
		if nova_world.player.loadout[candidate]["id"] == &"frost_nova":
			nova_slot = candidate
	_check(not nova_slot.is_empty(), "(preparacion) Frost Nova se desbloquea a nivel 12")
	_step(nova_world, 1, _input({nova_slot.to_lower(): true}))
	_step(nova_world, 40, _input({}))
	_check(target.statuses.has("slow"), "Frost Nova casi inmoviliza (slow)")

	# Crippling Arrow (proyectil) y Poisoned Blades (cuerpo a cuerpo).
	var arrow_world := _world()
	arrow_world.player.switch_class("archer")
	arrow_world.player.set_level(14)
	LegacyKit.apply(arrow_world.player)
	arrow_world.player.resource.current_amount = 100.0
	var arrow_target := arrow_world.add_enemy(&"slime", arrow_world.player.position + Vector2(150, 0))
	arrow_target.take_damage(1.0)
	var arrow_slot := ""
	for candidate: String in arrow_world.player.loadout:
		if arrow_world.player.loadout[candidate]["id"] == &"crippling_arrow":
			arrow_slot = candidate
	_check(not arrow_slot.is_empty(), "(preparacion) Crippling Arrow se desbloquea a nivel 14")
	_step(arrow_world, 1, _input({arrow_slot.to_lower(): true}))
	_step(arrow_world, 80, _input({}))
	_check(arrow_target.statuses.has("slow"), "una flecha que impacta aplica su slow")

	var blade_world := _world()
	blade_world.player.switch_class("rogue")
	blade_world.player.set_level(16)
	LegacyKit.apply(blade_world.player)
	blade_world.player.resource.current_amount = 100.0
	var poisoned := blade_world.add_enemy(&"beetle", blade_world.player.position + Vector2(50, 0))
	var blade_slot := ""
	for candidate: String in blade_world.player.loadout:
		if blade_world.player.loadout[candidate]["id"] == &"poisoned_blades":
			blade_slot = candidate
	_check(not blade_slot.is_empty(), "(preparacion) Poisoned Blades se desbloquea a nivel 16")
	_step(blade_world, 1, _input({blade_slot.to_lower(): true}))
	_step(blade_world, 40, _input({}))
	_check(blade_world.player.venom_hits == 4, "Poisoned Blades prepara 4 golpes envenenados")


func _test_poison_kill_gives_xp() -> void:
	var world := _world()
	var rat := world.add_enemy(&"slime", Vector2(600, 100))
	rat.health = 4.0
	rat.apply_status("poison", 4.0, 12.0)
	var xp: Array = []
	world.player.xp_gained.connect(func(amount: int, _p: Vector2) -> void: xp.append(amount))
	_step(world, 90, _input({}))
	_check(not rat.alive and xp == [int(rat.data["stats"]["xp"])], "matar con veneno da la XP al jugador (%s)" % str(xp))


func _test_enemy_attacks_apply_statuses() -> void:
	for case: Array in [[&"spider", "slow", Vector2(40, 0)], [&"beetle", "stun", Vector2(44, 0)], [&"hornet", "poison", Vector2(120, 0)]]:
		var world := _world()
		var enemy := world.add_enemy(case[0], world.player.position + case[2])
		var guard := 0
		while not world.player.statuses.has(String(case[1])) and guard < 900:
			_step(world, 1, _input({}))
			guard += 1
			world.player.health = world.player.max_health
		_check(world.player.statuses.has(String(case[1])), "%s le pone %s al jugador cuando le alcanza" % [case[0], case[1]])
		_check(enemy != null, "(sanidad)")


func _test_evaded_or_blocked_hits_apply_nothing() -> void:
	var world := _world()
	var beetle := world.add_enemy(&"beetle", world.player.position + Vector2(44, 0))
	world.player.set_level(6)
	world.player.resource.current_amount = 100.0
	var guard := 0
	while not (beetle.is_telegraphing() and beetle.telegraph_progress() > 0.45) and guard < 300:
		_step(world, 1, _input({}))
		guard += 1
	_step(world, 1, _input({"special": true}))
	_step(world, 120, _input({}))
	_check(not world.player.statuses.has("stun"), "un golpe bloqueado por la postura no aturde")


# --- Helpers ----------------------------------------------------------------


func _world() -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(17)
	world.setup_arena(Rect2(0, 0, 900, 600))
	return world


func _input(actions: Dictionary, move: Vector2 = Vector2.ZERO) -> InputMessage:
	var message: InputMessage = InputMessageScript.new()
	message.tick = 0
	message.peer_id = 1
	message.move_dir = move
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
