## Enemigos por datos con telegraph (Fase 1.5): catalogo, IA, aviso antes del
## golpe, zonas, dash, cooldowns, muerte/respawn y determinismo.
##
##   godot --headless --path . --script tests/test_enemies.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const InputMessageScript: GDScript = preload("res://net/input_message.gd")

const DT: float = 1.0 / 60.0
## Un telegraph por debajo de esto no se puede reaccionar (reaccion + esquiva).
const MIN_READABLE_WINDUP := 0.45

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_enemies (enemigos con telegraph) ==")
	_test_catalog_loads_and_is_valid()
	_test_bandits_are_tier_one_enemies()
	_test_bandit_item_drops()
	_test_validator_rejects_bad_data()
	_test_idle_outside_aggro()
	_test_chase_and_leash()
	_test_telegraph_comes_before_the_hit()
	_test_stepping_out_of_the_zone_dodges_it()
	_test_attack_cooldown()
	_test_zone_geometry()
	_test_line_attack_dashes()
	_test_armor_death_and_respawn()
	_test_aggro_on_damage()
	_test_warrior_hits_enemies()
	_test_collision()
	_test_determinism()
	_test_snapshot_and_reset()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


# --- Catalogo ----------------------------------------------------------------


## Un enemigo LPC: cada pieza y variante existe en el indice y se compone con todas las animaciones.
func _check_lpc_sprite(id: StringName, lpc: Dictionary) -> void:
	var pieces: Dictionary = LpcComposer.index()["pieces"]
	var ok := true
	for slot: String in lpc["equipment"]:
		var pair: Array = lpc["equipment"][slot]
		var layers: Array = pieces.get(String(pair[0]), {}).get("layers", [])
		var found := false
		for layer: Dictionary in layers:
			if (layer["files"] as Dictionary).get(String(lpc["look"].get("body", "male")), {}).has(String(pair[1])):
				found = true
		ok = ok and found
	_check(ok, "%s: todas las piezas LPC existen" % id)
	var frames := LpcComposer.build_frames_for(lpc["look"], "enemy." + String(id), lpc["equipment"])
	var anims_ok := true
	for anim: String in ["combat_idle", "walk", "slash", "thrust", "shoot", "spellcast", "hurt"]:
		for dir: String in ["up", "down", "left", "right"]:
			anims_ok = anims_ok and frames.has_animation("%s_%s" % [anim, dir])
	_check(anims_ok, "%s: el sprite LPC tiene todas las animaciones" % id)


## Los bandidos y jefes sueltan sus propios items con probabilidad (loot.items), todos existen.
func _test_bandit_item_drops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for id: StringName in EnemyCatalog.all_ids():
		if not String(id).begins_with("bandit_"):
			continue
		var table: Dictionary = EnemyCatalog.enemy(id)["loot"]
		var entries: Array = table.get("items", [])
		_check(entries.size() >= 3, "%s tiene al menos 3 items propios en su botin" % id)
		var valid := true
		for entry: Dictionary in entries:
			valid = valid and ItemCatalog.has_item(String(entry["id"])) and float(entry["chance"]) > 0.0 and float(entry["chance"]) <= 1.0
		_check(valid, "%s: sus items propios existen y la probabilidad es valida" % id)
		var own := {}
		for entry: Dictionary in entries:
			own[String(entry["id"])] = true
		var seen := {}
		for i: int in range(3000):
			var drop := ItemGen.roll_drop(rng, 1, "boss" if EnemyCatalog.enemy(id).get("boss", false) else "normal", table)
			if not drop.is_empty() and own.has(String(drop["id"])):
				seen[String(drop["id"])] = true
		_check(seen.size() == own.size(), "%s: en 3000 muertes suelta todos sus items propios (%d/%d)" % [id, seen.size(), own.size()])


func _test_bandits_are_tier_one_enemies() -> void:
	var tier := TowerCatalog.tier(1)
	var bandit_weight := 0.0
	var beast_weight := 0.0
	for entry: Dictionary in tier["pool"]:
		if String(entry["id"]).begins_with("bandit_"):
			bandit_weight += float(entry["weight"])
		else:
			beast_weight += float(entry["weight"])
	_check(bandit_weight > beast_weight * 3.0, "en el tier 1 los bandidos son la mayoria (%.0f vs %.0f)" % [bandit_weight, beast_weight])
	_check(String(tier["boss"]).begins_with("bandit_") and String(tier["mid_boss"]).begins_with("bandit_") and String(tier["mid_boss_2"]).begins_with("bandit_"), "los jefes del tier 1 son bandidos")
	for id: String in ["slime", "bat", "spider", "beetle", "wisp", "hornet", "carrion_crow", "acid_slime"]:
		var beast := EnemyCatalog.enemy(StringName(id))
		_check(not beast.has("loot") and not (beast["materials"] as Dictionary).is_empty(), "%s solo da materiales (sin equipo)" % id)
	# Las piezas vistosas se guardan para pisos altos: los bandidos solo llevan ropa corriente y solo el jefe es grande.
	var reserved := ["armour_plate", "chainmail", "legs_plate", "helmet_barbuta", "helmet_barbarian", "weapon_longsword", "weapon_staff_red", "weapon_staff_green", "shield_spartan", "gloves", "armour_leather"]
	for id: StringName in EnemyCatalog.all_ids():
		var sprite: Dictionary = EnemyCatalog.enemy(id)["sprite"]
		if not String(id).begins_with("bandit_"):
			continue
		for slot: String in sprite["lpc"]["equipment"]:
			_check(not reserved.has(String(sprite["lpc"]["equipment"][slot][0])), "%s: %s es ropa corriente" % [id, slot])
		_check((float(sprite["scale"]) > 1.2) == (id == &"bandit_garrick"), "%s: solo Garrick es grande" % id)
	for id: String in ["bandit_thug", "bandit_swordsman", "bandit_archer", "bandit_hexer", "bandit_cutthroat", "bandit_shieldman", "bandit_brute", "bandit_sapper", "bandit_shaman"]:
		var bandit := EnemyCatalog.enemy(StringName(id))
		_check(bandit["sprite"].has("lpc") and (bandit["loot"]["slots"] as Array).size() > 0 and (bandit["attacks"] as Array).size() >= 2, "%s: sprite LPC, kit de 2+ ataques y botin de equipo" % id)


func _test_catalog_loads_and_is_valid() -> void:
	for error: String in EnemyCatalog.errors():
		print("   error de carga: %s" % error)
	_check(EnemyCatalog.errors().is_empty(), "todos los JSON de data/enemies cargan sin errores")
	_check(EnemyCatalog.all_ids().size() >= 4, "hay al menos 4 enemigos")
	for id: StringName in EnemyCatalog.all_ids():
		var data := EnemyCatalog.enemy(id)
		_check(EnemyCatalog.validate(data).is_empty(), "%s cumple el esquema" % id)
		if data["sprite"].has("lpc"):
			_check_lpc_sprite(id, data["sprite"]["lpc"])
		else:
			_check(ResourceLoader.exists(String(data["sprite"]["sheet"])), "%s: la hoja de sprites existe" % id)
		for attack: Dictionary in data["attacks"]:
			_check(float(attack["windup"]) >= MIN_READABLE_WINDUP, "%s/%s: el telegraph dura al menos %.2f s" % [id, attack["id"], MIN_READABLE_WINDUP])
		# La copia es independiente del catalogo.
		data["stats"]["health"] = 99999.0
		_check(float(EnemyCatalog.enemy(id)["stats"]["health"]) != 99999.0, "%s se devuelve como copia" % id)
	_check(EnemyCatalog.enemy(&"no_existe").is_empty(), "un id desconocido devuelve {}")


func _test_validator_rejects_bad_data() -> void:
	var good := EnemyCatalog.enemy(&"slime")
	var no_attacks := good.duplicate(true)
	no_attacks["attacks"] = []
	_check(not EnemyCatalog.validate(no_attacks).is_empty(), "un enemigo sin ataques es invalido")
	var no_windup := good.duplicate(true)
	no_windup["attacks"][0]["windup"] = 0.0
	_check(not EnemyCatalog.validate(no_windup).is_empty(), "un ataque sin telegraph (windup 0) es invalido")
	var bad_shape := good.duplicate(true)
	bad_shape["attacks"][0]["shape"] = "cubo"
	_check(not EnemyCatalog.validate(bad_shape).is_empty(), "rechaza una forma desconocida")
	var no_width := EnemyCatalog.enemy(&"bat")
	no_width["attacks"][0].erase("width")
	_check(not EnemyCatalog.validate(no_width).is_empty(), "una line sin width es invalida")
	var bad_dash := EnemyCatalog.enemy(&"bat")
	bad_dash["attacks"][0]["active"] = 0.0
	_check(not EnemyCatalog.validate(bad_dash).is_empty(), "un dash sin duracion activa es invalido")
	var no_hp := good.duplicate(true)
	no_hp["stats"]["health"] = 0.0
	_check(not EnemyCatalog.validate(no_hp).is_empty(), "rechaza vida 0")


# --- IA ----------------------------------------------------------------------


func _test_idle_outside_aggro() -> void:
	var setup := _make(&"slime", Vector2(400, 0))
	var enemy: EnemySim = setup["enemy"]
	var start := enemy.position
	_step(setup["world"], 120, _input({}))
	_check(enemy.state == EnemySim.State.IDLE and enemy.position == start, "an enemy outside its aggro range stays idle and still")


func _test_chase_and_leash() -> void:
	var setup := _make(&"slime", Vector2(150, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var aggroed: Array = []
	enemy.aggroed.connect(func() -> void: aggroed.append(true))
	var before := enemy.position.distance_to(world.player.position)
	_step(world, 45, _input({}))
	_check(aggroed.size() == 1, "entering the aggro range emits aggroed once")
	_check(enemy.position.distance_to(world.player.position) < before - 20.0, "an aggroed enemy closes the distance")
	# Si el jugador se aleja mas que aggro * leash, vuelve a IDLE.
	world.player.position = enemy.position + Vector2(float(enemy.data["ai"]["aggro_range"]) * float(enemy.data["ai"]["leash"]) + 80.0, 0)
	_step(world, 2, _input({}))
	_check(enemy.state == EnemySim.State.IDLE, "the enemy gives up past aggro_range * leash")


func _test_telegraph_comes_before_the_hit() -> void:
	var setup := _make(&"slime", Vector2(34, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var events: Dictionary = {}
	# Solo el primer aviso y el primer golpe (en 150 ticks puede empezar un segundo ataque).
	enemy.telegraph_started.connect(func(_a: Dictionary, _d: Vector2) -> void:
		if not events.has("telegraph"):
			events["telegraph"] = world.tick)
	enemy.attack_landed.connect(func(damage: float) -> void:
		if not events.has("landed"):
			events["landed"] = world.tick
			events["damage"] = damage)
	var health_before: float = world.player.health
	_step(world, 100, _input({}))
	_check(events.has("telegraph") and events.has("landed"), "the slime telegraphs and then hits")
	if events.has("telegraph") and events.has("landed"):
		var windup_ticks := int(round(float(enemy.data["attacks"][0]["windup"]) / DT))
		var gap := int(events["landed"]) - int(events["telegraph"])
		_check(gap >= windup_ticks - 1, "the hit lands only after the full telegraph (%d ticks, windup %d)" % [gap, windup_ticks])
		var expected := float(enemy.data["stats"]["damage"]) * (1.0 - world.player.armor_reduction())
		_check(absf(float(events["damage"]) - expected) < 0.01, "the hit deals stats.damage after armor (%.2f)" % float(events["damage"]))
		_check(is_equal_approx(health_before - world.player.health, float(events["damage"])), "the warrior loses exactly the reported damage")


func _test_stepping_out_of_the_zone_dodges_it() -> void:
	var setup := _make(&"slime", Vector2(34, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var missed: Array = []
	var landed: Array = []
	enemy.attack_missed.connect(func() -> void: missed.append(true))
	enemy.attack_landed.connect(func(damage: float) -> void: landed.append(damage))
	var guard := 0
	while not enemy.is_telegraphing() and guard < 200:
		_step(world, 1, _input({}))
		guard += 1
	_check(enemy.is_telegraphing(), "the enemy reaches its telegraph")
	var health_before: float = world.player.health
	# El jugador lee la zona y se aparta: la direccion ya esta fijada.
	world.player.position = enemy.position + Vector2(0, 90)
	_step(world, 90, _input({}))
	_check(missed.size() == 1 and landed.is_empty(), "leaving the telegraphed zone makes the attack miss")
	_check(is_equal_approx(world.player.health, health_before), "a dodged attack deals no damage")


func _test_attack_cooldown() -> void:
	var setup := _make(&"slime", Vector2(34, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var swings: Array = []
	enemy.attack_active.connect(func(_a: Dictionary, _d: Vector2) -> void: swings.append(world.tick))
	_step(world, 120, _input({}))
	_check(swings.size() == 1, "one swing in the first 2 s (the cooldown holds the next one) (%d)" % swings.size())
	_step(world, 300, _input({}))
	_check(swings.size() >= 2, "it swings again once the cooldown is over (%d)" % swings.size())


# --- Zonas -------------------------------------------------------------------


func _test_zone_geometry() -> void:
	var cone := _make(&"slime", Vector2(500, 0))["enemy"] as EnemySim
	cone.current_attack = cone.data["attacks"][0]
	cone.attack_direction = Vector2.RIGHT
	var reach := float(cone.current_attack["range"]) + EnemySim.WARRIOR_RADIUS
	var half_arc := float(cone.current_attack["arc"]) * 0.5
	_check(cone._in_zone(cone.position + Vector2.RIGHT * (reach - 2.0)), "cone: a point in front and in reach is inside")
	_check(not cone._in_zone(cone.position + Vector2.RIGHT * (reach + 6.0)), "cone: beyond the reach is outside")
	_check(cone._in_zone(cone.position + Vector2.from_angle(deg_to_rad(half_arc - 5.0)) * 20.0), "cone: just inside the arc edge")
	_check(not cone._in_zone(cone.position + Vector2.from_angle(deg_to_rad(half_arc + 8.0)) * 20.0), "cone: just outside the arc edge")
	_check(not cone._in_zone(cone.position + Vector2.LEFT * 20.0), "cone: behind the enemy is outside")

	var line := _make(&"bat", Vector2(500, 0))["enemy"] as EnemySim
	line.current_attack = line.data["attacks"][0]
	line.attack_direction = Vector2.RIGHT
	var line_reach := float(line.current_attack["range"]) + EnemySim.WARRIOR_RADIUS
	var half_width := float(line.current_attack["width"]) * 0.5 + EnemySim.WARRIOR_RADIUS
	_check(line._in_zone(line.position + Vector2(60, half_width - 2.0)), "line: inside the width")
	_check(not line._in_zone(line.position + Vector2(60, half_width + 4.0)), "line: beside the line is outside")
	_check(not line._in_zone(line.position + Vector2(line_reach + 6.0, 0)), "line: past its length is outside")
	_check(not line._in_zone(line.position + Vector2(-20, 0)), "line: behind the origin is outside")

	var circle := _make(&"spider", Vector2(500, 0))["enemy"] as EnemySim
	for attack: Dictionary in circle.data["attacks"]:
		if attack["shape"] == "circle":
			circle.current_attack = attack
	circle.attack_direction = Vector2.RIGHT
	var circle_reach := float(circle.current_attack["range"]) + EnemySim.WARRIOR_RADIUS
	_check(circle._in_zone(circle.position + Vector2.LEFT * (circle_reach - 2.0)), "circle: hits in every direction (behind too)")
	_check(not circle._in_zone(circle.position + Vector2.UP * (circle_reach + 6.0)), "circle: outside beyond the radius")


func _test_line_attack_dashes() -> void:
	var setup := _make(&"bat", Vector2(100, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var origin: Array = []
	enemy.attack_active.connect(func(_a: Dictionary, _d: Vector2) -> void: origin.append(enemy.position))
	var guard := 0
	while enemy.state != EnemySim.State.RECOVER and guard < 400:
		_step(world, 1, _input({}))
		guard += 1
	_check(enemy.state == EnemySim.State.RECOVER and origin.size() == 1, "the bat dives and recovers")
	if origin.size() == 1:
		var travelled: float = enemy.position.distance_to(origin[0])
		var dash := float(enemy.data["attacks"][0]["dash_distance"])
		_check(absf(travelled - dash) < 3.0, "the dive covers dash_distance (%.1f vs %.1f)" % [travelled, dash])
		var moved_toward: float = (enemy.position - origin[0]).dot(enemy.attack_direction)
		_check(moved_toward > dash - 3.0, "the dash goes along the telegraphed direction")


# --- Vida, muerte y blancos ---------------------------------------------------


func _test_armor_death_and_respawn() -> void:
	var beetle := _make(&"beetle", Vector2(500, 0))["enemy"] as EnemySim
	var armor := float(beetle.data["stats"]["armor"])
	var dealt := beetle.take_damage(100.0)
	_check(absf(dealt - 100.0 * (1.0 - armor / (armor + 100.0))) < 0.01, "armor reduces the damage an enemy takes (%.1f)" % dealt)

	var setup := _make(&"slime", Vector2(500, 0))
	var world: CombatWorld = setup["world"]
	var slime: EnemySim = setup["enemy"]
	var deaths: Array = []
	var revives: Array = []
	slime.died.connect(func() -> void: deaths.append(true))
	slime.revived.connect(func() -> void: revives.append(true))
	slime.position += Vector2(30, 0)
	slime.take_damage(10000.0)
	_check(not slime.alive and deaths.size() == 1, "lethal damage kills the enemy once")
	_check(is_zero_approx(slime.take_damage(50.0)), "a dead enemy takes no damage")
	var respawn := float(slime.data["respawn_seconds"])
	_step(world, int(respawn / DT) - 30, _input({}))
	_check(not slime.alive, "it stays dead before respawn_seconds")
	_step(world, 60, _input({}))
	_check(slime.alive and revives.size() == 1, "it respawns after respawn_seconds")
	_check(is_equal_approx(slime.health, slime.max_health) and slime.position == slime.spawn_position, "a respawned enemy has full health at its spawn")


func _test_aggro_on_damage() -> void:
	var setup := _make(&"slime", Vector2(400, 0))
	var enemy: EnemySim = setup["enemy"]
	enemy.take_damage(5.0)
	_check(enemy.state == EnemySim.State.CHASE, "damage wakes up an idle enemy")


func _test_warrior_hits_enemies() -> void:
	var setup := _make(&"slime", Vector2(48, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	_check(world.get_living_targets().has(enemy), "living enemies are valid targets")
	var hits: Array = []
	world.player.attack_hit.connect(func(_s: Dictionary, target: Object, _d: float, _c: bool, _p: Vector2) -> void: hits.append(target))
	_step(world, 1, _input({"m1": true}))
	_step(world, 40, _input({}))
	_check(hits.has(enemy) and enemy.health < enemy.max_health, "the Warrior's M1 damages an enemy")
	enemy.take_damage(100000.0)
	_check(not world.get_living_targets().has(enemy), "dead enemies stop being targets")


func _test_collision() -> void:
	var setup := _make(&"beetle", Vector2(40, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var pushed := world.resolve_position(enemy.position + Vector2(2, 0), PlayerSim.RADIUS)
	_check(pushed.distance_to(enemy.position) >= PlayerSim.RADIUS + enemy.radius - 0.01, "the Warrior cannot walk through an enemy")
	var own := world.resolve_position(enemy.position, enemy.radius, enemy)
	_check(own.is_equal_approx(enemy.position), "an enemy does not collide with itself")


# --- Determinismo y estado ------------------------------------------------------


func _test_determinism() -> void:
	var a := _run_fight(77)
	var b := _run_fight(77)
	var c := _run_fight(78)
	_check(a == b, "the same seed gives the same fight")
	_check(a != c, "a different seed changes the fight")


func _run_fight(seed_value: int) -> String:
	var world: CombatWorld = CombatWorldScript.new(seed_value)
	world.setup_arena(Rect2(0, 0, 900, 600))
	world.add_enemy(&"spider", world.player.position + Vector2(70, 0))
	world.add_enemy(&"slime", world.player.position + Vector2(-90, 20))
	for i: int in range(900):
		world.submit_input(_input({"m1": i % 90 < 30}))
		world.step(DT)
	return var_to_str(world.snapshot())


func _test_snapshot_and_reset() -> void:
	var setup := _make(&"slime", Vector2(500, 0))
	var world: CombatWorld = setup["world"]
	var enemy: EnemySim = setup["enemy"]
	var snap: Dictionary = world.snapshot()
	_check(snap.has("enemies") and (snap["enemies"] as Array).size() == 1 and snap["enemies"][0]["id"] == "slime", "the world snapshot lists the enemies")
	enemy.take_damage(10000.0)
	world.reset()
	_check(enemy.alive and is_equal_approx(enemy.health, enemy.max_health), "world.reset() revives the enemies")


# --- Helpers ----------------------------------------------------------------


## Mundo 900x600 con el guerrero en el centro y un enemigo a `offset` de el.
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
