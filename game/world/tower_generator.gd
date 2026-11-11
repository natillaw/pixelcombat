## TowerGenerator — genera de forma determinista los pisos de la torre.
##
## `generate(piso, semilla_del_mundo)` devuelve siempre el mismo FloorLayout para la
## misma pareja: por eso un piso "se guarda" con solo recordar su numero y la
## semilla del mundo. El tier fija el tema, los enemigos y los jefes (data/tower.json);
## los pisos 5 y 10 de cada tier son pisos de pico (mini-jefe y jefe).
class_name TowerGenerator
extends RefCounted

const WALL := 40.0
const SIZES := [Vector2(960.0, 640.0), Vector2(1040.0, 700.0), Vector2(1120.0, 740.0)]
## Un enemigo normal nace al menos a esta distancia de la entrada.
const MIN_SPAWN_DISTANCE := 260.0
const MIN_ENEMY_SEPARATION := 64.0
const OBSTACLE_RADIUS := 21.0


static func generate(floor_number: int, world_seed: int) -> FloorLayout:
	var tier_number := TowerCatalog.tier_of_floor(floor_number)
	var tier_data := TowerCatalog.tier(tier_number)
	var spike := TowerCatalog.spike_kind(floor_number)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 1000003 + floor_number * 7919

	var layout := FloorLayout.new()
	layout.id = "tower_%d" % floor_number
	layout.kind = FloorLayout.KIND_FLOOR
	layout.floor_number = floor_number
	layout.tier = tier_number
	layout.seed_value = int(rng.seed)
	layout.size = SIZES[rng.randi_range(0, SIZES.size() - 1)]
	layout.wall = WALL
	layout.title = "Piso %d" % floor_number
	layout.theme = FloorLayout.make_theme(tier_data["theme"])
	layout.theme["name"] = String(tier_data["name"])
	layout.enemy_scale = TowerCatalog.enemy_scale(floor_number)

	var bounds := layout.bounds()
	var center_x := bounds.get_center().x
	layout.player_spawn = Vector2(center_x, bounds.end.y - 54.0)
	var exit_position := Vector2(center_x, bounds.position.y + 40.0)
	var entrance_position := Vector2(layout.player_spawn.x - 130.0, layout.player_spawn.y)
	layout.portals = [
		{"id": "exit", "position": exit_position, "radius": 42.0,
			"label": "Subir al piso %d" % (floor_number + 1) if floor_number < TowerCatalog.floors() else "Cima de la torre",
			"action": "next_floor" if floor_number < TowerCatalog.floors() else "to_city", "requires_complete": true},
		{"id": "entrance", "position": entrance_position, "radius": 34.0, "label": "Volver a la ciudad", "action": "to_city", "requires_complete": false},
	]

	_place_obstacles(layout, rng, [layout.player_spawn, exit_position, entrance_position])
	_place_enemies(layout, rng, tier_data, spike)
	layout.torches = Layouts._torches(layout)
	layout.objective = _objective(layout, spike)
	_place_resources(layout, rng, spike)
	return layout


static func _place_obstacles(layout: FloorLayout, rng: RandomNumberGenerator, keep_clear: Array) -> void:
	var bounds := layout.bounds()
	var target := rng.randi_range(4, 8)
	var attempts := 0
	while layout.obstacles.size() < target and attempts < 200:
		attempts += 1
		var point := Vector2(
			rng.randf_range(bounds.position.x + 90.0, bounds.end.x - 90.0),
			rng.randf_range(bounds.position.y + 110.0, bounds.end.y - 110.0)
		)
		var fits := true
		for clear: Vector2 in keep_clear:
			if point.distance_to(clear) < 130.0:
				fits = false
		for other: Dictionary in layout.obstacles:
			if point.distance_to(other["position"]) < 95.0:
				fits = false
		if fits:
			layout.obstacles.append({"position": point, "radius": OBSTACLE_RADIUS})


static func _place_enemies(layout: FloorLayout, rng: RandomNumberGenerator, tier_data: Dictionary, spike: String) -> void:
	var bounds := layout.bounds()
	var placed: Array = []
	if spike != "":
		var boss_id := StringName(String(tier_data["boss" if spike == "boss" else "mid_boss"]))
		var boss_position := Vector2(bounds.get_center().x, bounds.position.y + 150.0)
		layout.enemies.append({"id": boss_id, "position": boss_position, "required": true})
		placed.append(boss_position)
		var add_count := 3 if spike == "boss" else 2
		for i: int in range(add_count):
			var add_id := StringName(String((tier_data["adds"] as Array)[rng.randi_range(0, (tier_data["adds"] as Array).size() - 1)]))
			var position := _free_spot(layout, rng, placed, MIN_SPAWN_DISTANCE)
			layout.enemies.append({"id": add_id, "position": position, "required": false})
			placed.append(position)
		return
	var position_in_tier := TowerCatalog.position_in_tier(layout.floor_number)
	var count := 3 + position_in_tier / 3 + (layout.tier - 1) / 2
	var pool: Array = tier_data["pool"]
	var total := 0.0
	for entry: Dictionary in pool:
		total += float(entry["weight"])
	for i: int in range(count):
		var roll := rng.randf() * total
		var chosen: StringName = StringName(String(pool[pool.size() - 1]["id"]))
		for entry: Dictionary in pool:
			roll -= float(entry["weight"])
			if roll <= 0.0:
				chosen = StringName(String(entry["id"]))
				break
		var spot := _free_spot(layout, rng, placed, MIN_SPAWN_DISTANCE)
		layout.enemies.append({"id": chosen, "position": spot, "required": true})
		placed.append(spot)


## Un punto libre: dentro de la zona, lejos de la entrada, de los obstaculos y de
## los demas enemigos. Si no encuentra uno tras varios intentos, devuelve el mejor.
static func _free_spot(layout: FloorLayout, rng: RandomNumberGenerator, placed: Array, min_spawn_distance: float, separation: float = MIN_ENEMY_SEPARATION) -> Vector2:
	var bounds := layout.bounds()
	var best := bounds.get_center()
	var best_score := -INF
	for attempt: int in range(60):
		var point := Vector2(
			rng.randf_range(bounds.position.x + 60.0, bounds.end.x - 60.0),
			rng.randf_range(bounds.position.y + 60.0, bounds.end.y - 60.0)
		)
		var score := 0.0
		var ok := point.distance_to(layout.player_spawn) >= min_spawn_distance
		for other: Dictionary in layout.obstacles:
			if point.distance_to(other["position"]) < float(other["radius"]) + 40.0:
				ok = false
		for other_position: Vector2 in placed:
			var gap := point.distance_to(other_position)
			if gap < separation:
				ok = false
			score = maxf(score, 0.0) + minf(gap, 200.0)
		if ok:
			return point
		score += point.distance_to(layout.player_spawn)
		if score > best_score:
			best_score = score
			best = point
	return best


## Nodos de recoleccion: 3-5 en un piso normal, 1-2 en uno de pico. Lejos de la
## entrada, de los obstaculos y de los enemigos; el tipo es aleatorio.
static func _place_resources(layout: FloorLayout, rng: RandomNumberGenerator, spike: String) -> void:
	var kinds := MaterialCatalog.gatherable_kinds()
	var count := rng.randi_range(3, 5) if spike == "" else rng.randi_range(1, 2)
	var placed: Array = []
	for spec: Dictionary in layout.enemies:
		placed.append(spec["position"])
	for i: int in range(count):
		var spot := _free_spot(layout, rng, placed, 120.0, 110.0)
		layout.resources.append({"kind": String(kinds[rng.randi_range(0, kinds.size() - 1)]), "position": spot})
		placed.append(spot)


static func _objective(layout: FloorLayout, spike: String) -> Dictionary:
	if spike == "":
		return {"type": "clear", "label": "Elimina a todos los enemigos"}
	for enemy: Dictionary in layout.enemies:
		if bool(enemy["required"]):
			var name := String(EnemyCatalog.enemy(enemy["id"])["name"])
			return {"type": "boss", "label": "Derrota a %s" % name, "kind": spike}
	return {"type": "clear", "label": "Elimina a todos los enemigos"}
