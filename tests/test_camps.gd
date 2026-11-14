## Campamentos y comportamientos enemigos: estructura, densidad por piso, dormir / patrullar / vigilar.
extends SceneTree

var _checks: int = 0
var _failures: int = 0
const DT := 1.0 / 60.0
const MAX_ENEMIES := {1: 20, 2: 50, 3: 60, 4: 70, 5: 70, 6: 80, 7: 75, 8: 75, 9: 75}
const MIN_ENEMIES := {1: 8, 2: 25, 3: 30, 4: 35, 5: 35, 6: 40, 7: 34, 8: 40, 9: 40}


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_density_and_structure()
	_test_behaviors()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_density_and_structure() -> void:
	var sleepers_total := 0
	var patrols_total := 0
	for floor_number: int in range(1, 10):
		for seed_value: int in [20261110, 7, 99]:
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			var enemies := layout.enemies.filter(func(e: Dictionary) -> bool: return not String(e["id"]).begins_with("barrel_"))
			var area := float(layout.grid.cols * layout.grid.rows)
			_check(enemies.size() <= int(MAX_ENEMIES[floor_number]) and enemies.size() >= int(MIN_ENEMIES[floor_number]) - (10 if not layout.village.is_empty() else 0), "piso %d seed %d: %d enemigos (entre %d y %d)" % [floor_number, seed_value, enemies.size(), int(MIN_ENEMIES[floor_number]), int(MAX_ENEMIES[floor_number])])
			_check(float(enemies.size()) / area * 1000.0 < 9.0, "piso %d seed %d: densidad %.2f por 1000 casillas (< 9)" % [floor_number, seed_value, float(enemies.size()) / area * 1000.0])
			var camps := layout.camps.filter(func(c: Dictionary) -> bool: return String(c["kind"]) == "camp")
			var tents := layout.props.filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "camp_tent").size()
			var fires := layout.props.filter(func(p: Dictionary) -> bool: return String(p["kind"]) == "camp_fire").size()
			var extra_fire := 1 if not layout.village.is_empty() else 0
			_check(camps.size() > 0 and fires == camps.size() + extra_fire and tents >= camps.size(), "piso %d seed %d: %d campamentos con fogata (%d) y tiendas (%d)" % [floor_number, seed_value, camps.size(), fires, tents])
			var near_spawn := enemies.filter(func(e: Dictionary) -> bool: return (e["position"] as Vector2).distance_to(layout.player_spawn) < 420.0).size()
			_check(near_spawn <= 4, "piso %d seed %d: %d enemigos a menos de 420 px de la entrada (max 4)" % [floor_number, seed_value, near_spawn])
			var apart := true
			for i: int in range(layout.camps.size()):
				for j: int in range(i + 1, layout.camps.size()):
					if (layout.camps[i]["position"] as Vector2).distance_to(layout.camps[j]["position"]) < 110.0:
						apart = false
			_check(apart, "piso %d seed %d: campamentos separados al menos 110 px" % [floor_number, seed_value])
			var guards_ok := true
			for camp: Dictionary in camps:
				var members := enemies.filter(func(e: Dictionary) -> bool: return String(e.get("group", "")) == String(camp["group"]))
				var awake := members.filter(func(e: Dictionary) -> bool: return String(e.get("behavior", "guard")) != "sleep")
				guards_ok = guards_ok and (members.is_empty() or awake.size() >= 1)
				for e: Dictionary in members:
					sleepers_total += 1 if String(e.get("behavior", "")) == "sleep" else 0
					patrols_total += 1 if String(e.get("behavior", "")) == "patrol" else 0
			_check(guards_ok, "piso %d seed %d: ningun campamento esta dormido entero" % [floor_number, seed_value])
			var walkable := true
			for prop: Dictionary in layout.props:
				walkable = walkable and layout.grid.in_bounds(layout.grid.world_to_cell(prop["position"]).x, layout.grid.world_to_cell(prop["position"]).y)
			_check(walkable, "piso %d seed %d: los props estan dentro del mapa" % [floor_number, seed_value])
	_check(sleepers_total > 0 and patrols_total > 0, "hay enemigos dormidos (%d) y patrullando (%d)" % [sleepers_total, patrols_total])
	var layout10 := TowerGenerator.generate(10, 20261110, 1)
	_check(layout10.camps.size() >= 6 and layout10.enemies.any(func(e: Dictionary) -> bool: return String(e.get("group", "")) == "boss"), "el piso 10 (a mano) tiene sus campamentos y su jefe")


func _world() -> CombatWorld:
	var world := CombatWorld.new(5)
	world.player.position = Vector2(300, 300)
	return world


func _spawn(world: CombatWorld, id: StringName, at: Vector2, behavior: String, group: String = "g") -> EnemySim:
	var enemy := world.spawn_from_spec({"id": id, "position": at, "required": false, "group": group, "behavior": behavior}, 1.0)
	return enemy


func _test_behaviors() -> void:
	# Dormido: no nota al jugador a distancia normal, si muy cerca.
	var world := _world()
	var sleeper := _spawn(world, &"bandit_thug", Vector2(300, 480), "sleep")
	for i: int in range(120):
		world.step(DT)
	_check(sleeper.state == EnemySim.State.IDLE and sleeper.behavior == "sleep", "un dormido no nota al jugador a 180 px")
	world.player.position = Vector2(300, 450)
	for i: int in range(30):
		world.step(DT)
	_check(sleeper.state != EnemySim.State.IDLE and sleeper.behavior == "guard", "un dormido despierta si el jugador esta a ~30 px")
	# El dano despierta.
	var w2 := _world()
	var hurt := _spawn(w2, &"bandit_thug", Vector2(300, 600), "sleep")
	hurt.take_damage(5.0)
	_check(hurt.state == EnemySim.State.CHASE and hurt.behavior == "guard", "el dano despierta al dormido")
	# Un companero que despierta alerta a los demas del grupo.
	var w3 := _world()
	var a := _spawn(w3, &"bandit_thug", Vector2(300, 520), "guard", "camp_x")
	var b := _spawn(w3, &"bandit_thug", Vector2(330, 530), "sleep", "camp_x")
	a.take_damage(5.0)
	_check(b.state != EnemySim.State.IDLE, "los dormidos despiertan cuando su campamento da la alarma")
	# Patrulla: se mueve por su zona sin alejarse demasiado.
	var w4 := _world()
	w4.player.position = Vector2(2500, 2500)
	var patrol := _spawn(w4, &"bandit_thug", Vector2(600, 600), "patrol")
	patrol.patrol_radius = 100.0
	var start := patrol.position
	var farthest := 0.0
	for i: int in range(60 * 30):
		w4.step(DT)
		farthest = maxf(farthest, patrol.position.distance_to(start))
	_check(farthest > 30.0, "el que patrulla se mueve (%.0f px)" % farthest)
	_check(farthest < 100.0 + 30.0, "y no se aleja de su zona (%.0f px)" % farthest)
	# Guardia: se queda quieto.
	var w5 := _world()
	w5.player.position = Vector2(2500, 2500)
	var guard := _spawn(w5, &"bandit_thug", Vector2(600, 600), "guard")
	for i: int in range(600):
		w5.step(DT)
	_check(guard.position.distance_to(Vector2(600, 600)) < 1.0, "el de guardia no se mueve")
	# Determinismo de la patrulla.
	var paths: Array = []
	for run: int in range(2):
		var w := _world()
		w.player.position = Vector2(2500, 2500)
		var p := _spawn(w, &"bandit_thug", Vector2(600, 600), "patrol")
		for i: int in range(60 * 10):
			w.step(DT)
		paths.append(p.position)
	_check(paths[0] == paths[1], "la patrulla es determinista")
