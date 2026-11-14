## Aldeas refugio y misiones sin combate: sitio seguro, edificios, aldeanos, zona segura, interrogar y seguir pistas.
extends SceneTree

var _checks: int = 0
var _failures: int = 0
const DT := 1.0 / 60.0
const VILLAGE_FLOORS := [2, 4, 6, 8]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_placement()
	_test_refuge()
	_test_interrogate()
	_test_clues()
	_test_distance()
	_test_scenes()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_placement() -> void:
	for floor_number: int in range(1, 11):
		for seed_value: int in [20261110, 7, 99, 4242]:
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			if not VILLAGE_FLOORS.has(floor_number):
				_check(layout.village.is_empty(), "piso %d seed %d: sin aldea" % [floor_number, seed_value]) if seed_value == 20261110 else null
				continue
			_check(not layout.village.is_empty(), "piso %d seed %d: tiene aldea" % [floor_number, seed_value])
			if layout.village.is_empty():
				continue
			var center: Vector2 = layout.village["position"]
			var closest := 1.0e9
			for spec: Dictionary in layout.enemies:
				closest = minf(closest, center.distance_to(spec["position"]))
			_check(closest >= VillageGen.SAFE_RADIUS, "piso %d seed %d: enemigo mas cercano a %.0f px (>= %d)" % [floor_number, seed_value, closest, int(VillageGen.SAFE_RADIUS)])
			var stations := layout.portals.filter(func(p: Dictionary) -> bool: return String(p["action"]) in ["building:tavern", "building:merchant"]).size()
			_check(stations == 2, "piso %d seed %d: posada y mercader" % [floor_number, seed_value])
			var villagers := layout.npcs.filter(func(n: Dictionary) -> bool: return String(n["id"]).begins_with("vil_")).size()
			_check(villagers >= 3, "piso %d seed %d: %d aldeanos" % [floor_number, seed_value, villagers])
			var talk := layout.portals.filter(func(p: Dictionary) -> bool: return String(p["action"]).begins_with("talk:")).size()
			_check(talk == villagers, "piso %d seed %d: cada aldeano tiene portal de hablar" % [floor_number, seed_value])
			_check(MissionGen.check(layout).is_empty(), "piso %d seed %d: el piso sigue siendo completable %s" % [floor_number, seed_value, str(MissionGen.check(layout))])
	var a := TowerGenerator.generate(4, 20261110, 1)
	var b := TowerGenerator.generate(4, 20261110, 1)
	_check(a.village == b.village and a.enemies.size() == b.enemies.size(), "la aldea es determinista")


func _test_refuge() -> void:
	var world := CombatWorld.new(5)
	world.load_layout(TowerGenerator.generate(2, 20261110, 1))
	var center: Vector2 = world.layout.village["position"]
	world.player.position = center
	world.step(DT)
	_check(world.player.safe_zone and world.in_village(center), "dentro de la aldea el jugador esta en zona segura")
	world.player.position = center + Vector2(600, 0)
	world.step(DT)
	_check(not world.player.safe_zone, "fuera de la aldea deja de estarlo")
	# Un enemigo que persigue se detiene al entrar en la aldea.
	var enemy := world.spawn_from_spec({"id": &"bandit_thug", "position": center + Vector2(260, 0), "required": false}, 1.0)
	world.player.position = center + Vector2(40, 0)
	enemy.take_damage(1.0)
	for i: int in range(120):
		world.step(DT)
	_check(enemy.state == EnemySim.State.IDLE, "los enemigos pierden al jugador dentro de la aldea")
	# Consumir la posada: el servicio es la taberna normal.
	var session := GameSession.new(CombatWorld.new(9), "")
	session.tower.complete(1)
	session.go_to_floor(2)
	var stations: Array = []
	session.service_opened.connect(func(station: String) -> void: stations.append(station))
	for portal: Dictionary in session.layout.portals:
		if String(portal["action"]) == "building:tavern":
			session.world.player.position = portal["position"]
			session.try_interact()
	_check(stations == ["tavern"], "la posada de la aldea abre la taberna")


func _test_interrogate() -> void:
	var session := GameSession.new(CombatWorld.new(21), "")
	for n: int in range(1, 4):
		session.tower.complete(n)
	session.go_to_floor(4)
	var interrogate: Mission = null
	for mission: Mission in session.missions:
		if String(mission.spec["kind"]) == "interrogate":
			interrogate = mission
	_check(interrogate != null and not interrogate.optional, "el piso 4 tiene la mision de interrogar")
	var combat_missions := session.missions.filter(func(m: Mission) -> bool: return not m.optional and ["clear", "kill_group", "slay"].has(String(m.spec["kind"]))).size()
	_check(combat_missions == 0, "y ninguna mision principal obliga a combatir")
	var witnesses := session.layout.npcs.filter(func(n: Dictionary) -> bool: return String(n.get("group", "")) == "witness")
	_check(witnesses.size() == 3 and interrogate.target == 3, "hay 3 testigos")
	var messages: Array = []
	session.message.connect(func(text: String) -> void: messages.append(text))
	for index: int in range(witnesses.size()):
		var id := String((witnesses[index] as Dictionary)["id"]).trim_prefix("vil_")
		session._talk_to(id)
		_check(interrogate.progress == index + 1 and (index < 2) != interrogate.done, "hablar con el testigo %d: progreso %d / 3" % [index + 1, interrogate.progress])
	session._talk_to(String((witnesses[0] as Dictionary)["id"]).trim_prefix("vil_"))
	_check(interrogate.progress == 3, "hablar dos veces con el mismo no cuenta doble")
	_check(messages.size() >= 3 and String(messages[0]).find(":") > 0, "los testigos cuentan lo que saben")
	for i: int in range(5):
		session.world.step(DT)
	_check(session.is_floor_done(), "con el interrogatorio hecho el piso esta completo (sin combate)")


func _test_clues() -> void:
	var session := GameSession.new(CombatWorld.new(22), "")
	for n: int in range(1, 7):
		session.tower.complete(n)
	session.go_to_floor(7)
	var clues: Mission = null
	for mission: Mission in session.missions:
		if String(mission.spec["id"]) == "clues":
			clues = mission
	_check(clues != null and not clues.optional, "el piso 7 tiene la mision de seguir pistas")
	var combat_missions := session.missions.filter(func(m: Mission) -> bool: return not m.optional and ["clear", "kill_group", "slay"].has(String(m.spec["kind"]))).size()
	_check(combat_missions == 0, "y ninguna mision principal obliga a combatir")
	var objects := session.world.interactables.filter(func(o: Interactable) -> bool: return o.kind == "clue")
	_check(objects.size() == clues.target and objects.size() >= 3, "hay %d pistas" % objects.size())
	for object: Interactable in objects:
		session.world.player.position = object.position + Vector2(10, 0)
		session.world.gather_node = object
		session.world.gather_left = 0.0
		session.world._gather_from = session.world.player.position
		session.world._gather_health = session.world.player.health
		session.world._step_gather(DT)
	for i: int in range(5):
		session.world.step(DT)
	_check(clues.done and session.is_floor_done(), "examinar todas las pistas completa el piso")


## El piso del interrogatorio no puede ser un paseo: la aldea esta a una distancia razonable de la entrada.
func _test_distance() -> void:
	for seed_value: int in [20261110, 7, 99, 4242, 31337]:
		var layout := TowerGenerator.generate(4, seed_value, 1)
		var distance := layout.player_spawn.distance_to(layout.village["position"])
		_check(distance >= 900.0, "piso 4 seed %d: la aldea esta a %.0f px de la entrada (>= 900)" % [seed_value, distance])


## Cada aldea tiene su escena propia (2 opciones exclusivas) y su decorado.
func _test_scenes() -> void:
	for floor_number: int in VILLAGE_FLOORS:
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		var options := layout.interactables.filter(func(o: Dictionary) -> bool: return String(o.get("exclusive", "")) == "village_scene_%d" % floor_number)
		_check(options.size() == 2, "aldea del piso %d: escena propia con 2 opciones" % floor_number)
		var center: Vector2 = layout.village["position"]
		var near := true
		for option: Dictionary in options:
			near = near and center.distance_to(option["position"]) <= VillageGen.REFUGE_RADIUS
		_check(near, "aldea del piso %d: la escena esta dentro del refugio" % floor_number)
		var decor := layout.props.filter(func(p: Dictionary) -> bool: return center.distance_to(p["position"]) <= 200.0).size()
		_check(decor >= 8, "aldea del piso %d: %d props en la aldea" % [floor_number, decor])
	# Efectos de las escenas: ración gratis del piso 8 y pago del piso 2.
	var world := CombatWorld.new(14)
	world.load_layout(TowerGenerator.generate(8, 20261110, 1))
	var free: Dictionary = {}
	for object: Interactable in world.interactables:
		if object.exclusive == "village_scene_8" and not object.effects.is_empty() and String(object.effects[0]["type"]) == "consumable":
			free = {"object": object}
	_check(not free.is_empty(), "el piso 8 ofrece el menu del veterano")
	var object8: Interactable = free["object"]
	world.player.position = object8.position + Vector2(10, 0)
	world.gather_node = object8
	world.gather_left = 0.0
	world._gather_from = world.player.position
	world._gather_health = world.player.health
	world._step_gather(DT)
	_check(world.player.consumable_count("roast_meal") == 2 and world.player.consumable_count("travel_ration") == 2, "el menu del veterano da 2 asados y 2 raciones")
	var world2 := CombatWorld.new(15)
	world2.load_layout(TowerGenerator.generate(2, 20261110, 1))
	var pay: Interactable = null
	for object: Interactable in world2.interactables:
		if object.exclusive == "village_scene_2" and String(object.effects[0]["type"]) == "pay":
			pay = object
	world2.player.spend_gold(world2.player.gold)
	world2.player.position = pay.position + Vector2(10, 0)
	world2.gather_node = pay
	world2.gather_left = 0.0
	world2._gather_from = world2.player.position
	world2._gather_health = world2.player.health
	world2._step_gather(DT)
	_check(not pay.done and world2.player.consumable_count("travel_ration") == 0, "sin oro la donacion no se consume")
