## Misiones de los pisos: catalogo, sorteo (normal, x5 con mision doble, x10 con jefe),
## que SIEMPRE se puedan cumplir (verificacion estructural en cientos de pisos), y que
## cada tipo se complete de verdad jugando la simulacion.
##
##   godot --headless --path . --script tests/test_missions.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const DT: float = 1.0 / 60.0
const SEED := 20261110

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_missions (misiones de piso) ==")
	_test_catalog()
	_test_feasibility_everywhere()
	_test_plan_shapes()
	_test_determinism_and_visits()
	_test_every_kind_is_playable()
	_test_spike_mid_floor()
	_test_boss_floor_variants()
	_test_time_limit_and_optional()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _new_session() -> GameSession:
	return GameSession.new(CombatWorldScript.new(11), "")


## Entra a un piso con misiones forzadas y deja al jugador inmortal (las pruebas
## juegan las misiones, no el combate).
func _enter(session: GameSession, floor_number: int, forced: Array, visit: int = 1) -> void:
	session.tower.floors = {}
	for n: int in range(1, floor_number):
		session.tower.complete(n)
	session.world.player.safe_zone = false
	session.world.player.set_level(45)
	session._enter(TowerGenerator.generate(floor_number, SEED, visit, forced), false)
	session.tower.visit(floor_number)


func _tick(session: GameSession, count: int = 1) -> void:
	for i: int in range(count):
		session.world.player.health = session.world.player.max_health
		session.world.step(DT)


func _kill(session: GameSession, predicate: Callable) -> int:
	var killed := 0
	for enemy: EnemySim in session.world.enemies.duplicate():
		if enemy.alive and predicate.call(enemy):
			enemy.take_damage(1.0e9)
			killed += 1
	return killed


## Va hasta el objeto, hace clic y espera a que termine el canalizado.
func _use(session: GameSession, point: Vector2) -> String:
	var world := session.world
	# Los guardias cercanos interrumpirian el canalizado: se retiran (menos jefes).
	for enemy: EnemySim in world.enemies.duplicate():
		if enemy.alive and enemy.group != "boss" and enemy.group != "mini" and enemy.position.distance_to(point) < 700.0:
			enemy.take_damage(1.0e9)
	world.player.position = point + Vector2(24, 0)
	var result := world.try_click(point)
	var guard := 0
	while world.gather_node != null and guard < 1000:
		_tick(session)
		guard += 1
	return result


func _mission(session: GameSession, id: String) -> Mission:
	for mission: Mission in session.missions:
		if String(mission.spec["id"]) == id:
			return mission
	return null


# --- Catalogo y viabilidad ---------------------------------------------------------


func _test_catalog() -> void:
	_check(MissionCatalog.errors().is_empty(), "missions.json valido: %s" % str(MissionCatalog.errors()))
	var kinds := {}
	for entry: Dictionary in MissionCatalog.missions():
		kinds[String(entry["kind"])] = true
	_check(kinds.size() == MissionCatalog.KINDS.size(), "hay una plantilla de cada tipo (%d tipos)" % kinds.size())
	_check(MissionCatalog.missions().size() >= 10, "al menos diez misiones distintas")
	_check(not MissionCatalog.validate({"missions": [{"id": "x", "kind": "inventada", "name": "x", "desc": "x", "weight": 1, "tier_min": 1, "xp_mult": 1}]}).is_empty(), "un tipo de mision desconocido no valida")
	_check(TowerCatalog.errors().is_empty(), "tower.json valido con estilos, bioma y segundo mini-jefe: %s" % str(TowerCatalog.errors()))
	var nest := EnemyCatalog.enemy(&"brood_nest")
	_check(EnemyCatalog.has_enemy(StringName(String(nest["spawner"]["id"]))) and bool(nest["stationary"]), "el nido es estatico y engendra un enemigo que existe")
	_check(bool(EnemyCatalog.enemy(&"hornet_queen")["boss"]), "la Hornet Queen es un jefe")


func _test_feasibility_everywhere() -> void:
	var floors: Array = []
	for n: int in range(1, 101):
		if n <= 12 or n % 5 == 0 or n % 17 == 0:
			floors.append(n)
	var bad: Array = []
	var seen_ids := {}
	var generated := 0
	for floor_number: int in floors:
		for visit: int in range(1, 3):
			var layout := TowerGenerator.generate(floor_number, SEED, visit)
			generated += 1
			var problems := MissionGen.check(layout)
			if not problems.is_empty():
				bad.append("piso %d visita %d: %s" % [floor_number, visit, str(problems)])
			for spec: Dictionary in layout.mission_plan["missions"]:
				seen_ids[String(spec["id"])] = true
	_check(bad.is_empty(), "las misiones de %d pisos generados son cumplibles (%s)" % [generated, str(bad.slice(0, 2))])
	_check(seen_ids.size() >= 10, "el sorteo reparte variedad: %d misiones distintas vistas" % seen_ids.size())


func _test_plan_shapes() -> void:
	var normal := TowerGenerator.generate(3, SEED, 1)
	var mains: Array = normal.mission_plan["missions"].filter(func(s: Dictionary) -> bool: return not bool(s["optional"]))
	_check(mains.size() == 1 and float(normal.mission_plan["time_limit"]) == 0.0, "un piso normal tiene una mision principal y sin limite de tiempo")
	var mid := TowerGenerator.generate(5, SEED, 1)
	var mid_ids: Array = mid.mission_plan["missions"].map(func(s: Dictionary) -> String: return String(s["id"]))
	_check(mid_ids.has("bosses") and mid.mission_plan["missions"].filter(func(s: Dictionary) -> bool: return not bool(s["optional"])).size() == 2, "el piso 5 es una mision doble con los dos mini-jefes")
	var mini_ids: Array = mid.enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == "mini").map(func(e: Dictionary) -> String: return String(e["id"]))
	_check(mini_ids.size() == 2 and mini_ids.has("elder_spider") and mini_ids.has("hornet_queen"), "los dos mini-jefes son distintos (Elder Spider y Hornet Queen)")
	var time_limited := 0
	var optional_seen := 0
	for visit: int in range(1, 31):
		var layout := TowerGenerator.generate(5, SEED, visit)
		if float(layout.mission_plan["time_limit"]) > 0.0:
			time_limited += 1
			_check_limit_range(float(layout.mission_plan["time_limit"]))
		if layout.mission_plan["missions"].size() > 2:
			optional_seen += 1
	_check(time_limited > 5 and time_limited < 28, "algunas visitas al piso 5 traen limite de tiempo (%d de 30)" % time_limited)
	_check(optional_seen > 5, "y a veces una mision opcional (%d de 30)" % optional_seen)
	var variants := {}
	for visit: int in range(1, 31):
		variants[String(TowerGenerator.generate(10, SEED, visit).mission_plan["variant"])] = true
	_check(variants.has("seals") and variants.has("gauntlet") and variants.has("elites"), "el piso 10 sortea sus tres pruebas distintas")
	var boss_layout := TowerGenerator.generate(10, SEED, 1, ["seals"])
	var boss_specs: Array = boss_layout.enemies.filter(func(e: Dictionary) -> bool: return String(e["group"]) == "boss")
	_check(boss_specs.size() == 1 and boss_specs[0].has("boost") and float(boss_specs[0]["boost"][0]) >= 1.5, "el jefe del piso 10 sale reforzado (boost de vida y dano)")


func _check_limit_range(seconds: float) -> void:
	var cfg := MissionCatalog.config("spike_mid")["time_limit_seconds"] as Array
	if seconds < float(cfg[0]) or seconds > float(cfg[1]):
		_check(false, "el limite de tiempo (%d s) esta en el rango" % int(seconds))


func _test_determinism_and_visits() -> void:
	var a := TowerGenerator.generate(7, SEED, 1)
	var b := TowerGenerator.generate(7, SEED, 1)
	_check(JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()), "mismo piso, semilla y visita: mismo layout")
	var c := TowerGenerator.generate(7, SEED, 2)
	_check(a.grid.cells == c.grid.cells and a.player_spawn == c.player_spawn, "el terreno es el mismo en todas las visitas")
	var different := false
	for visit: int in range(2, 12):
		if JSON.stringify(TowerGenerator.generate(7, SEED, visit).mission_plan) != JSON.stringify(a.mission_plan):
			different = true
	_check(different, "las misiones cambian de una visita a otra")
	_check(JSON.stringify(a.enemies) != JSON.stringify(c.enemies), "tambien los enemigos")


# --- Jugar cada tipo ----------------------------------------------------------------


func _test_every_kind_is_playable() -> void:
	for id: String in ["clear", "hunt", "slay", "collect", "altars", "waypoints", "rescue", "nests", "survive", "relic"]:
		var session := _new_session()
		_enter(session, 2, [id])
		var mission := _mission(session, id)
		var world := session.world
		var label := "[%s] " % id
		_check(mission != null and not mission.done and not session.is_floor_done(), label + "empieza sin cumplir")
		match id:
			"clear":
				_kill(session, func(e: EnemySim) -> bool: return e.required)
			"hunt":
				var elites := world.enemies.filter(func(e: EnemySim) -> bool: return e.elite)
				_check(elites.size() >= mission.target and elites.all(func(e: EnemySim) -> bool: return e.max_health > 200.0 or e.elite), label + "hay elites suficientes y son elites")
				_kill(session, func(e: EnemySim) -> bool: return e.group == "hunt")
			"slay":
				_kill(session, func(e: EnemySim) -> bool: return String(e.def_id) == String(mission.spec["enemy_id"]))
			"collect":
				for node: ResourceNode in world.resource_nodes.duplicate():
					if node.kind == String(mission.spec["material_kind"]) and node.rich and not mission.done:
						_use(session, node.position)
			"altars":
				for object: Interactable in world.interactables.duplicate():
					if object.group == "altar":
						_use(session, object.position)
			"waypoints":
				for object: Interactable in world.interactables.duplicate():
					if object.kind == "waypoint":
						world.player.position = object.position
						_tick(session)
			"rescue":
				for object: Interactable in world.interactables.duplicate():
					if object.kind == "cage":
						_use(session, object.position)
			"nests":
				_check(world.enemies.filter(func(e: EnemySim) -> bool: return e.group == "nest").size() >= mission.target, label + "hay nidos suficientes")
				_kill(session, func(e: EnemySim) -> bool: return e.group == "nest")
			"survive":
				var beacon: Interactable = world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "beacon")[0]
				_use(session, beacon.position)
				world.player.position = beacon.position
				var guard := 0
				while not mission.done and guard < 60 * 130:
					world.player.position = beacon.position
					_tick(session)
					guard += 1
				_check(world.enemies.any(func(e: EnemySim) -> bool: return e.group == "wave"), label + "la resistencia genera oleadas")
			"relic":
				var altar: Interactable = world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "relic_altar")[0]
				var relic: Interactable = world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "relic")[0]
				_check(_use(session, altar.position) == "needs" and not altar.done, label + "el altar de entrega exige la reliquia")
				_use(session, relic.position)
				_check(world.relics_carried == 1, label + "se recoge la reliquia")
				_use(session, altar.position)
				_check(world.relics_carried == 0, label + "se entrega")
		_tick(session, 3)
		_check(mission.done and session.is_floor_done() and session.tower.is_completed(2), label + "se cumple y completa el piso")
		var exit_portal: Dictionary = {}
		for portal: Dictionary in session.layout.portals:
			if String(portal["id"]) == "exit":
				exit_portal = portal
		_check(session.portal_active(exit_portal), label + "la salida se abre")


func _test_spike_mid_floor() -> void:
	var session := _new_session()
	_enter(session, 5, ["hunt"])
	var world := session.world
	var bosses := _mission(session, "bosses")
	var hunt := _mission(session, "hunt")
	_check(bosses != null and hunt != null and session.missions.filter(func(m: Mission) -> bool: return not m.optional).size() == 2, "el piso 5 tiene dos misiones principales a la vez")
	_kill(session, func(e: EnemySim) -> bool: return e.group == "hunt")
	_tick(session, 2)
	_check(hunt.done and not session.is_floor_done(), "cumplir solo una no completa el piso")
	_kill(session, func(e: EnemySim) -> bool: return e.group == "mini" and String(e.def_id) == "elder_spider")
	_tick(session, 2)
	_check(bosses.progress == 1 and not session.is_floor_done(), "con un mini-jefe muerto aun falta el otro")
	_kill(session, func(e: EnemySim) -> bool: return e.group == "mini")
	_tick(session, 2)
	_check(session.is_floor_done() and world.player.alive, "con los dos mini-jefes y la otra mision, el piso se completa")


func _test_boss_floor_variants() -> void:
	# Sellos: el jefe es invulnerable hasta romperlos todos.
	var seals_session := _new_session()
	_enter(seals_session, 10, ["seals"])
	var boss: EnemySim = seals_session.world.enemies.filter(func(e: EnemySim) -> bool: return e.group == "boss")[0]
	_check(boss.invulnerable and is_zero_approx(boss.take_damage(1.0e6)) and boss.health == boss.max_health, "con los sellos intactos el jefe no recibe dano")
	_check(boss.max_health > float(EnemyCatalog.enemy(boss.def_id)["stats"]["health"]) * 1.5, "el jefe del piso 10 es mucho mas duro que el normal")
	var seals: Array = seals_session.world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "seal")
	for i: int in range(seals.size() - 1):
		_use(seals_session, (seals[i] as Interactable).position)
	_tick(seals_session)
	_check(boss.invulnerable, "con un sello sin romper el escudo sigue")
	_use(seals_session, (seals[seals.size() - 1] as Interactable).position)
	_tick(seals_session)
	_check(not boss.invulnerable and not seals_session.is_floor_done(), "al romper todos los sellos cae el escudo pero el piso sigue abierto")
	boss.take_damage(1.0e9)
	_tick(seals_session, 2)
	_check(seals_session.is_floor_done(), "matar al jefe completa el piso")

	# Oleadas: el jefe no existe hasta resistir.
	var gauntlet := _new_session()
	_enter(gauntlet, 10, ["gauntlet"])
	_check(gauntlet.world.enemies.filter(func(e: EnemySim) -> bool: return e.group == "boss").is_empty(), "en la prueba de oleadas el jefe aun no esta")
	var survive := _mission(gauntlet, "gauntlet")
	var beacon: Interactable = gauntlet.world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "beacon")[0]
	_use(gauntlet, beacon.position)
	gauntlet.world.player.position = beacon.position
	var guard := 0
	while not survive.done and guard < 60 * 130:
		gauntlet.world.player.position = beacon.position
		_tick(gauntlet)
		guard += 1
	var appeared := gauntlet.world.enemies.filter(func(e: EnemySim) -> bool: return e.group == "boss" and e.alive)
	_check(survive.done and appeared.size() == 1 and not gauntlet.is_floor_done(), "al terminar las oleadas aparece el jefe (hecho %s, jefes %d, piso %s, vivo %s, guard %d, prog %d/%d)" % [survive.done, appeared.size(), gauntlet.is_floor_done(), gauntlet.world.player.alive, guard, survive.progress, survive.target])
	appeared[0].take_damage(1.0e9)
	_tick(gauntlet, 2)
	_check(gauntlet.is_floor_done(), "y al matarlo se completa el piso")

	# Guardianes: dos elites protegen al jefe.
	var elites := _new_session()
	_enter(elites, 10, ["elites"])
	var shielded: EnemySim = elites.world.enemies.filter(func(e: EnemySim) -> bool: return e.group == "boss")[0]
	_check(shielded.invulnerable, "con guardianes vivos el jefe esta protegido")
	_kill(elites, func(e: EnemySim) -> bool: return e.group == "elite_guard")
	_tick(elites)
	_check(not shielded.invulnerable, "al caer los guardianes se rompe el escudo")
	shielded.take_damage(1.0e9)
	_tick(elites, 2)
	_check(elites.is_floor_done(), "y al matar al jefe se completa el piso")


func _test_time_limit_and_optional() -> void:
	var session := _new_session()
	var failed: Array = []
	session.floor_failed.connect(func(reason: String) -> void: failed.append(reason))
	var layout := TowerGenerator.generate(5, SEED, 1, ["hunt"])
	layout.mission_plan["time_limit"] = 30.0
	session.tower.complete(1)
	session.tower.complete(2)
	session.tower.complete(3)
	session.tower.complete(4)
	session._enter(layout, false)
	_check(is_equal_approx(session.time_left, 30.0), "el limite de tiempo empieza completo")
	_tick(session, 60 * 10)
	_check(session.time_left > 19.0 and session.time_left < 21.0 and failed.is_empty(), "el tiempo corre mientras juegas")
	_tick(session, 60 * 21)
	_check(failed == ["time"] and session.layout.kind == FloorLayout.KIND_CITY and not session.tower.is_completed(5), "al agotarse el tiempo la mision falla y vuelves a la ciudad")
	# Mision opcional: da recompensa extra, no hace falta para completar.
	var optional_session := _new_session()
	var rewards: Array = []
	optional_session.mission_completed.connect(func(m: Mission, xp: int) -> void: rewards.append([m.optional, xp]))
	_enter(optional_session, 2, ["clear", "waypoints"])
	var optional_mission := _mission(optional_session, "waypoints")
	_check(optional_mission != null and optional_mission.optional, "la segunda mision forzada es opcional")
	_kill(optional_session, func(e: EnemySim) -> bool: return e.required)
	_tick(optional_session, 2)
	var gold_before := optional_session.world.player.gold
	var bag_before := optional_session.world.player.bag.size()
	_check(optional_session.is_floor_done() and not optional_mission.done, "se completa el piso sin hacer la opcional")
	_check(optional_session.world.player.gold == gold_before and rewards.size() == 1 and rewards[0][0] == false, "las principales no pagan por separado")
	for object: Interactable in optional_session.world.interactables:
		if object.kind == "waypoint":
			optional_session.world.player.position = object.position
			_tick(optional_session)
	_check(optional_mission.done and optional_session.world.player.gold > gold_before and optional_session.world.player.bag.size() > bag_before, "la opcional, si se hace, da oro y un item")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
