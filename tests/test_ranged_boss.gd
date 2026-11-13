## Enemigos a distancia (Wisp, Hornet) con proyectiles hostiles, y el jefe Brood
## Beetle con fases, rugido invulnerable e invocaciones.
##
##   godot --headless --path . --script tests/test_ranged_boss.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_ranged_boss (a distancia y jefe) ==")
	_test_catalog()
	_test_validator()
	_test_shooter_keeps_its_distance()
	_test_lane_marks_the_shot()
	_test_projectile_hurts_once()
	_test_leaving_the_lane_dodges_it()
	_test_hornet_fan()
	_test_hostile_projectiles_ignore_other_enemies()
	_test_stance_blocks_a_projectile()
	_test_boss_phases_and_roar()
	_test_boss_attacks_per_phase()
	_test_boss_summons_and_cleanup()
	_test_boss_skips_phases_on_big_damage()
	_test_boss_death_and_respawn()
	_test_boss_fight_is_deterministic()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Datos -------------------------------------------------------------------


func _test_catalog() -> void:
	for error: String in EnemyCatalog.errors():
		print("   error de carga: %s" % error)
	_check(EnemyCatalog.errors().is_empty(), "los enemigos (incluidos Wisp, Hornet y el jefe) cargan sin errores")
	for id: StringName in [&"wisp", &"hornet", &"brood_beetle"]:
		_check(EnemyCatalog.has_enemy(id), "%s existe" % id)
	var wisp := EnemyCatalog.enemy(&"wisp")
	_check(wisp["attacks"][0]["shape"] == "projectile" and wisp["ai"].has("keep_distance"), "el Wisp es un tirador que mantiene distancia")
	var boss := EnemyCatalog.enemy(&"brood_beetle")
	_check(bool(boss["boss"]) and boss["phases"].size() == 3, "el Brood Beetle es un jefe de 3 fases")
	_check(is_equal_approx(float(boss["phases"][0]["hp_below"]), 1.0), "la primera fase empieza al 100 %")
	for phase: Dictionary in boss["phases"]:
		for attack_id: String in phase["attacks"]:
			var found := false
			for attack: Dictionary in boss["attacks"]:
				found = found or attack["id"] == attack_id
			_check(found, "la fase %s usa un ataque que existe (%s)" % [phase["name"], attack_id])
	for attack: Dictionary in boss["attacks"]:
		_check(float(attack["windup"]) >= 0.45, "%s: el telegraph del jefe dura al menos 0,45 s" % attack["id"])


func _test_validator() -> void:
	var good := EnemyCatalog.enemy(&"brood_beetle")
	_check(EnemyCatalog.validate(good).is_empty(), "(preparacion) el jefe es valido")
	var bad_first := good.duplicate(true)
	bad_first["phases"][0]["hp_below"] = 0.9
	_check(not EnemyCatalog.validate(bad_first).is_empty(), "la primera fase debe ser 1.0")
	var not_decreasing := good.duplicate(true)
	not_decreasing["phases"][2]["hp_below"] = 0.7
	_check(not EnemyCatalog.validate(not_decreasing).is_empty(), "las fases deben ir bajando de vida")
	var unknown_attack := good.duplicate(true)
	unknown_attack["phases"][1]["attacks"] = ["no_existe"]
	_check(not EnemyCatalog.validate(unknown_attack).is_empty(), "una fase no puede usar un ataque inexistente")
	var bad_summon := good.duplicate(true)
	bad_summon["phases"][1]["summons"] = [{"id": "slime", "count": 0}]
	_check(not EnemyCatalog.validate(bad_summon).is_empty(), "una invocacion necesita count >= 1")
	var bad_projectile := EnemyCatalog.enemy(&"wisp")
	bad_projectile["attacks"][0]["projectile"].erase("speed")
	_check(not EnemyCatalog.validate(bad_projectile).is_empty(), "un ataque de proyectil necesita su bloque completo")
	var bad_tint := good.duplicate(true)
	bad_tint["sprite"]["tint"] = [1.0, 1.0]
	_check(not EnemyCatalog.validate(bad_tint).is_empty(), "el tinte necesita 4 componentes")


# --- Tiradores ---------------------------------------------------------------


func _test_shooter_keeps_its_distance() -> void:
	var setup := _make(&"wisp", Vector2(80, 0))
	var world: CombatWorld = setup["world"]
	var wisp: EnemySim = setup["enemy"]
	var start := wisp.position.distance_to(world.player.position)
	_step(world, 200, _input({}))
	_check(wisp.position.distance_to(world.player.position) > start + 10.0, "el Wisp retrocede si lo alcanzan (%.0f -> %.0f px)" % [start, wisp.position.distance_to(world.player.position)])
	# Un tirador se acerca solo hasta tener al jugador a su alcance de disparo.
	var far := _make(&"hornet", Vector2(230, 0))
	var hornet: EnemySim = far["enemy"]
	var far_world: CombatWorld = far["world"]
	var trigger := float(hornet.data["attacks"][0]["trigger_range"])
	var guard := 0
	while not hornet.is_telegraphing() and guard < 300:
		_step(far_world, 1, _input({}))
		guard += 1
	var distance := hornet.position.distance_to(far_world.player.position)
	_check(hornet.is_telegraphing() and distance <= trigger + 3.0 and distance > 150.0, "empieza a disparar en cuanto lo alcanza (%.0f px, alcance %.0f)" % [distance, trigger])


func _test_lane_marks_the_shot() -> void:
	var setup := _make(&"wisp", Vector2(200, 0))
	var world: CombatWorld = setup["world"]
	var wisp: EnemySim = setup["enemy"]
	var guard := 0
	while not wisp.is_telegraphing() and guard < 200:
		_step(world, 1, _input({}))
		guard += 1
	_check(wisp.is_telegraphing(), "(preparacion) el Wisp apunta")
	_check(wisp.threatens(world.player.position), "el carril marcado cubre al jugador alineado")
	_check(not wisp.threatens(world.player.position + Vector2(0, 90)), "y no a quien esta apartado")
	_check(not wisp.threatens(wisp.position - wisp.attack_direction * 60.0), "ni a lo que queda detras del tirador")
	_check(world.projectiles.is_empty(), "no hay proyectil mientras dura el aviso")


func _test_projectile_hurts_once() -> void:
	var setup := _make(&"wisp", Vector2(200, 0))
	var world: CombatWorld = setup["world"]
	var wisp: EnemySim = setup["enemy"]
	var landed: Array = []
	wisp.attack_landed.connect(func(damage: float) -> void: landed.append(damage))
	var spawned: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: spawned.append(p))
	var health: float = world.player.health
	var guard := 0
	while landed.is_empty() and guard < 400:
		_step(world, 1, _input({}))
		guard += 1
	_check(not spawned.is_empty() and spawned[0].hostile, "el disparo del Wisp es un proyectil hostil")
	var expected := float(wisp.data["stats"]["damage"]) * (1.0 - world.player.armor_reduction())
	_check(landed.size() == 1 and absf(float(landed[0]) - expected) < 0.01, "golpea al jugador con su dano tras la armadura (%.2f)" % expected)
	_check(is_equal_approx(health - world.player.health, float(landed[0])), "y el jugador pierde exactamente eso")
	_check(not spawned[0].alive, "el proyectil muere al impactar")


func _test_leaving_the_lane_dodges_it() -> void:
	var setup := _make(&"wisp", Vector2(200, 0))
	var world: CombatWorld = setup["world"]
	var wisp: EnemySim = setup["enemy"]
	var guard := 0
	while not wisp.is_telegraphing() and guard < 200:
		_step(world, 1, _input({}))
		guard += 1
	var health: float = world.player.health
	world.player.position += Vector2(0, 80)
	_step(world, 240, _input({}))
	_check(is_equal_approx(world.player.health, health), "apartarse del carril esquiva el proyectil")


func _test_hornet_fan() -> void:
	var setup := _make(&"hornet", Vector2(150, 0))
	var world: CombatWorld = setup["world"]
	var directions: Array = []
	world.projectile_spawned.connect(func(p: ProjectileSim) -> void: directions.append(p.direction))
	var guard := 0
	while directions.is_empty() and guard < 300:
		_step(world, 1, _input({}))
		guard += 1
	_step(world, 2, _input({}))
	var spec: Dictionary = EnemyCatalog.enemy(&"hornet")["attacks"][0]["projectile"]
	_check(directions.size() == int(spec["count"]), "el Hornet dispara %d aguijones" % int(spec["count"]))
	if directions.size() == 3:
		var edge := rad_to_deg(directions[0].angle_to(directions[2]))
		_check(absf(absf(edge) - float(spec["spread"])) < 0.5, "abiertos en un abanico de %.0f grados" % float(spec["spread"]))


func _test_hostile_projectiles_ignore_other_enemies() -> void:
	var setup := _make(&"wisp", Vector2(200, 0))
	var world: CombatWorld = setup["world"]
	var dummy := world.add_dummy(world.player.position + Vector2(120, 0), false)
	var enemy_health := dummy.health
	_step(world, 300, _input({}))
	_check(is_equal_approx(dummy.health, enemy_health), "los proyectiles enemigos no dañan a otros blancos")


func _test_stance_blocks_a_projectile() -> void:
	var setup := _make(&"wisp", Vector2(200, 0))
	var world: CombatWorld = setup["world"]
	world.player.set_level(6)
	LegacyKit.apply(world.player)
	world.player.resource.current_amount = 100.0
	var blocked: Array = []
	world.player.attack_blocked.connect(func(_s: Vector2) -> void: blocked.append(true))
	var wisp: EnemySim = setup["enemy"]
	var guard := 0
	while guard < 600:
		var near := false
		for projectile: ProjectileSim in world.projectiles:
			near = near or (projectile.hostile and projectile.position.distance_to(world.player.position) < 60.0)
		if near:
			break
		_step(world, 1, _input({}))
		guard += 1
	var health: float = world.player.health
	_check(world.projectiles.size() == 1, "(preparacion) hay un proyectil a punto de llegar")
	_step(world, 1, _input({"special": true}))
	_step(world, 120, _input({}))
	_check(blocked.size() == 1 and is_equal_approx(world.player.health, health), "Iron Counter bloquea un proyectil enemigo")


# --- Jefe --------------------------------------------------------------------


func _test_boss_phases_and_roar() -> void:
	var setup := _make(&"brood_beetle", Vector2(600, 0))
	var world: CombatWorld = setup["world"]
	var boss: EnemySim = setup["enemy"]
	var phases: Array = []
	boss.phase_changed.connect(func(index: int, phase_name: String) -> void: phases.append([index, phase_name]))
	_check(boss.phase == 0 and boss.phase_name() == "Brood Guardian" and boss.is_boss(), "el jefe empieza en la fase 1")
	_damage_to_fraction(boss, 0.60)
	_check(boss.phase == 1 and phases == [[1, "Brood Hunter"]], "al bajar del 66 % entra en la fase 2")
	_check(boss.state == EnemySim.State.PHASE, "con un rugido")
	var health := boss.health
	_check(is_zero_approx(boss.take_damage(500.0)) and is_equal_approx(boss.health, health), "invulnerable durante el rugido")
	_step(world, int(EnemySim.PHASE_PAUSE / DT) + 5, _input({}))
	_check(boss.state != EnemySim.State.PHASE and boss.take_damage(10.0) > 0.0, "y vulnerable otra vez al acabar")
	_damage_to_fraction(boss, 0.30)
	_check(boss.phase == 2 and phases.size() == 2, "al bajar del 33 % entra en la fase 3")
	_check(is_equal_approx(boss._speed_mult(), 1.5), "la fase 3 es un 50 %% mas rapida")


func _test_boss_attacks_per_phase() -> void:
	var boss := _make(&"brood_beetle", Vector2(600, 0))["enemy"] as EnemySim
	_check(boss._allowed_attack_ids() == ["crush"], "fase 1: solo Crush")
	boss.phase = 1
	_check(boss._allowed_attack_ids() == ["crush", "charge", "spit"], "fase 2: Crush, Charge y Spit")
	boss.phase = 2
	_check(boss._allowed_attack_ids().has("quake"), "fase 3: se suma Quake")
	boss.phase = 0
	var used: Dictionary = {}
	boss.telegraph_started.connect(func(attack: Dictionary, _d: Vector2) -> void: used[attack["id"]] = true)
	var setup := _make(&"brood_beetle", Vector2(60, 0))
	var world: CombatWorld = setup["world"]
	var fresh: EnemySim = setup["enemy"]
	fresh.telegraph_started.connect(func(attack: Dictionary, _d: Vector2) -> void: used[attack["id"]] = true)
	world.player.set_level(30)
	for i: int in range(900):
		world.player.health = world.player.max_health
		world.submit_input(_input({}))
		world.step(DT)
	_check(used.keys() == ["crush"], "en la fase 1 nunca usa nada mas que Crush (%s)" % str(used.keys()))


func _test_boss_summons_and_cleanup() -> void:
	var setup := _make(&"brood_beetle", Vector2(600, 0))
	var world: CombatWorld = setup["world"]
	var boss: EnemySim = setup["enemy"]
	var spawned: Array = []
	world.enemy_spawned.connect(func(enemy: EnemySim) -> void: spawned.append(enemy))
	_damage_to_fraction(boss, 0.60)
	_check(spawned.size() == 2 and spawned.all(func(e: EnemySim) -> bool: return e.def_id == &"slime" and e.summoned), "la fase 2 invoca 2 slimes")
	_check(spawned.all(func(e: EnemySim) -> bool: return e.state == EnemySim.State.CHASE), "que van directos a por el jugador")
	spawned[0].take_damage(100000.0)
	_step(world, 600, _input({}))
	_check(not spawned[0].alive, "una cria muerta no reaparece")
	_step(world, int(EnemySim.PHASE_PAUSE / DT) + 5, _input({}))
	_damage_to_fraction(boss, 0.30)
	_check(spawned.size() == 4 and spawned[2].def_id == &"bat", "la fase 3 invoca 2 murcielagos")
	world.reset()
	_check(world.enemies.size() == 1 and world.enemies[0] == boss, "world.reset() retira las crias y deja al jefe")
	_check(boss.phase == 0 and is_equal_approx(boss.health, boss.max_health), "y el jefe vuelve a la fase 1 con la vida llena")


func _test_boss_skips_phases_on_big_damage() -> void:
	var setup := _make(&"brood_beetle", Vector2(600, 0))
	var world: CombatWorld = setup["world"]
	var boss: EnemySim = setup["enemy"]
	var phases: Array = []
	boss.phase_changed.connect(func(index: int, _n: String) -> void: phases.append(index))
	var spawned: Array = []
	world.enemy_spawned.connect(func(enemy: EnemySim) -> void: spawned.append(enemy.def_id))
	_damage_to_fraction(boss, 0.20)
	_check(phases == [2] and boss.phase == 2, "un golpe enorme salta directamente a la fase 3 (una sola vez)")
	_check(spawned == [&"bat", &"bat"], "y solo invoca lo de esa fase")


func _test_boss_death_and_respawn() -> void:
	var setup := _make(&"brood_beetle", Vector2(44, 0))
	var world: CombatWorld = setup["world"]
	var boss: EnemySim = setup["enemy"]
	var deaths: Array = []
	boss.died.connect(func() -> void: deaths.append(true))
	boss.health = 1.0
	var xp_events: Array = []
	world.player.xp_gained.connect(func(amount: int, _p: Vector2) -> void: xp_events.append(amount))
	_step(world, 1, _input({"m1": true}))
	_step(world, 40, _input({}))
	_check(not boss.alive and deaths.size() == 1, "el jefe muere")
	_check(xp_events == [300], "y da su XP de jefe (%s)" % str(xp_events))
	var respawn := float(boss.data["respawn_seconds"])
	_step(world, int(respawn / DT) + 30, _input({}))
	_check(boss.alive and boss.phase == 0, "reaparece a los %.0f s en su primera fase" % respawn)


func _test_boss_fight_is_deterministic() -> void:
	var a := _fight_snapshot(41)
	var b := _fight_snapshot(41)
	var c := _fight_snapshot(42)
	_check(a == b, "la misma semilla da el mismo combate contra el jefe")
	_check(a != c, "otra semilla lo cambia")


func _fight_snapshot(seed_value: int) -> String:
	var world: CombatWorld = CombatWorldScript.new(seed_value)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.player.set_level(10)
	world.add_enemy(&"brood_beetle", world.player.position + Vector2(0, -200))
	var bot := BotBrain.new()
	bot.dodge_enemies = true
	for i: int in range(1500):
		world.submit_input(bot.decide(world))
		world.step(DT)
	return var_to_str(world.snapshot())


# --- Helpers ----------------------------------------------------------------


## Hace al enemigo el dano justo (contando su armadura) para dejarlo al
## `fraction` de su vida maxima.
func _damage_to_fraction(enemy: EnemySim, fraction: float) -> void:
	var armor := float(enemy.data["stats"].get("armor", 0.0))
	var keep := 1.0 - armor / (armor + 100.0)
	enemy.take_damage((enemy.health - enemy.max_health * fraction) / keep + 0.01)


func _make(enemy_id: StringName, offset: Vector2) -> Dictionary:
	var world: CombatWorld = CombatWorldScript.new(6)
	world.setup_arena(Rect2(0, 0, 900, 600))
	var enemy := world.add_enemy(enemy_id, world.player.position + offset)
	return {"world": world, "enemy": enemy}


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
