## VillageGen — aldeas refugio de los pisos (data/villages.json): sin enemigos cerca, con posada (taberna), mercader y
## aldeanos con los que hablar. Se coloca DESPUES de todo lo demas y elige el sitio mas despejado, asi no altera
## ni rompe el reparto de enemigos y misiones del piso. Dentro de su radio el jugador esta a salvo (puede cambiar de
## equipo y los enemigos no entran).
class_name VillageGen
extends RefCounted

const PATH := "res://data/villages.json"
## Ningun enemigo (salvo jefes y misiones) a menos de esta distancia del centro.
const SAFE_RADIUS := 300.0
## Radio de la zona segura (refugio).
const REFUGE_RADIUS := 190.0

static var _data: Dictionary = {}
static var _loaded: bool = false


static func village_for_floor(floor_number: int) -> Dictionary:
	_ensure_loaded()
	return ((_data.get("villages", {}) as Dictionary).get(str(floor_number), {}) as Dictionary).duplicate(true)


static func find_villager(id: String) -> Dictionary:
	_ensure_loaded()
	for key: String in (_data.get("villages", {}) as Dictionary):
		for entry: Variant in ((_data["villages"][key] as Dictionary)["villagers"] as Array):
			if String((entry as Dictionary)["id"]) == id:
				return entry
	return {}


static func witnesses(floor_number: int) -> Array:
	return (village_for_floor(floor_number).get("villagers", []) as Array).filter(func(v: Dictionary) -> bool: return bool(v.get("witness", false)))


## Coloca la aldea del piso (si le toca). Devuelve true si la puso. `force` (pisos con mision de interrogar) siempre la
## coloca, retirando enemigos ambientales si hace falta.
static func place(layout: FloorLayout, analysis: MapAnalysis, frng: RandomNumberGenerator, floor_number: int, force: bool = false) -> bool:
	var def := village_for_floor(floor_number)
	if def.is_empty():
		return false
	var avoid: Array = [analysis.spawn_position(), analysis.exit_position()]
	var best := Vector2.INF
	var best_score := -1.0
	for clearance: int in [4, 3, 2]:
		for attempt: int in range(40):
			var candidate: Variant = analysis.pick_spot(frng, 0.05, 0.95, clearance, avoid, 380.0)
			if candidate == null:
				continue
			var score := _site_score(layout, candidate as Vector2)
			if score > best_score:
				best_score = score
				best = candidate as Vector2
		if best_score >= SAFE_RADIUS + 40.0 or (best != Vector2.INF and clearance == 3):
			break
	if best == Vector2.INF:
		return false
	if best_score < SAFE_RADIUS and not force and best_score < 160.0:
		return false
	_clear_site(layout, best, force)
	_build(layout, analysis, frng, def, best, floor_number)
	return true


## Distancia al enemigo "inamovible" mas cercano (mision, jefe, elite): cuanto mayor, mejor sitio.
static func _site_score(layout: FloorLayout, point: Vector2) -> float:
	var nearest := 1.0e9
	for spec: Dictionary in layout.enemies:
		if _removable(spec):
			continue
		nearest = minf(nearest, point.distance_to(spec["position"]))
	for object: Dictionary in layout.interactables:
		if String(object.get("group", "")) != "":
			nearest = minf(nearest, point.distance_to(object["position"]) + 80.0)
	return nearest


## Enemigos ambientales (campamentos, patrullas, barriles) que se pueden retirar sin romper misiones.
static func _removable(spec: Dictionary) -> bool:
	var group := String(spec.get("group", ""))
	return (group.begins_with("camp_") or group == "prop") and not bool(spec.get("required", false))


static func _clear_site(layout: FloorLayout, center: Vector2, force: bool) -> void:
	layout.enemies = layout.enemies.filter(func(spec: Dictionary) -> bool:
		var close: bool = (spec["position"] as Vector2).distance_to(center) < SAFE_RADIUS
		return not (close and (_removable(spec) or (force and not bool(spec.get("required", false))))))
	layout.props = layout.props.filter(func(prop: Dictionary) -> bool:
		return not (String(prop["kind"]).begins_with("camp_") and (prop["position"] as Vector2).distance_to(center) < SAFE_RADIUS + 20.0))
	layout.hazards = layout.hazards.filter(func(h: Dictionary) -> bool: return (h["position"] as Vector2).distance_to(center) > REFUGE_RADIUS + float(h["radius"]) + 30.0)
	layout.interactables = layout.interactables.filter(func(o: Dictionary) -> bool:
		return String(o.get("group", "")) != "" or (o["position"] as Vector2).distance_to(center) > REFUGE_RADIUS)
	layout.camps = layout.camps.filter(func(c: Dictionary) -> bool: return (c["position"] as Vector2).distance_to(center) >= SAFE_RADIUS)


static func _open(analysis: MapAnalysis, point: Vector2) -> bool:
	var cell := analysis.cell_at(point)
	if not analysis.grid.in_bounds(cell.x, cell.y):
		return false
	return analysis.dist[cell.y * analysis.grid.cols + cell.x] >= 0 and analysis.clearance_at(cell) >= 1


static func _ring_point(analysis: MapAnalysis, center: Vector2, angle: float, r_min: float, r_max: float, frng: RandomNumberGenerator) -> Vector2:
	for attempt: int in range(10):
		var point := center + Vector2.from_angle(angle + frng.randf_range(-0.25, 0.25)) * frng.randf_range(r_min, r_max)
		if _open(analysis, point):
			return point
	return center + Vector2.from_angle(angle) * r_min


static func _build(layout: FloorLayout, analysis: MapAnalysis, frng: RandomNumberGenerator, def: Dictionary, center: Vector2, floor_number: int) -> void:
	layout.village = {"position": center, "radius": REFUGE_RADIUS, "name": String(def["name"])}
	layout.props.append({"kind": "camp_fire", "position": center, "variant": 0})
	for entry: Array in [["bench", Vector2(-34.0, 30.0)], ["bench", Vector2(34.0, 30.0)], ["planter", Vector2(-62.0, 8.0)], ["planter", Vector2(62.0, 8.0)], ["lamppost", Vector2(0.0, -48.0)]]:
		layout.props.append({"kind": String(entry[0]), "position": center + (entry[1] as Vector2), "variant": frng.randi_range(0, 3)})
	# Edificios: posada (taberna) y mercader, uno a cada lado, con su puerta como portal.
	var specs := [
		{"sprite": "tavern", "offset": Vector2(-118.0, -62.0), "station": "tavern", "label": String(def["inn_label"]), "id": "village_inn"},
		{"sprite": "merchant_house", "offset": Vector2(118.0, -62.0), "station": "merchant", "label": String(def["merchant_label"]), "id": "village_merchant"},
	]
	for spec: Dictionary in specs:
		var foot: Vector2 = center + (spec["offset"] as Vector2)
		var scale := 1.3
		layout.buildings.append({"id": String(spec["id"]), "sprite": "res://assets/pixel/village/%s.png" % String(spec["sprite"]), "foot": foot, "scale": scale, "label": String(spec["label"]),
			"rect": Rect2(foot.x - 40.0 * scale, foot.y - 73.0 * scale, 80.0 * scale, 73.0 * scale), "color": Color(0.5, 0.35, 0.25)})
		for dx: float in [-32.0, 0.0, 32.0]:
			layout.obstacles.append({"position": foot + Vector2(dx, -8.0), "radius": 24.0, "hidden": true})
		layout.portals.append({"id": "door_" + String(spec["id"]), "position": foot + Vector2(0.0, 30.0), "radius": 40.0, "label": String(spec["label"]), "action": "building:" + String(spec["station"]), "requires_complete": false})
	# Aldeanos en corro alrededor de la fogata.
	var villagers: Array = def["villagers"]
	for i: int in range(villagers.size()):
		var entry: Dictionary = villagers[i]
		var angle := TAU * (float(i) + 0.5) / float(villagers.size()) + 0.5 * PI
		var spot := _ring_point(analysis, center, angle, 64.0, 92.0, frng)
		var npc := {"id": "vil_" + String(entry["id"]), "name": String(entry["name"]), "position": spot, "look": Residents.look_of(entry), "equipment": Residents.OUTFITS[String(entry["outfit"])],
			"face": String(entry.get("face", "down")), "bubble": bool(entry.get("bubble", true))}
		if bool(entry.get("witness", false)):
			npc["group"] = "witness"
		layout.npcs.append(npc)
		layout.obstacles.append({"position": spot, "radius": 13.0, "hidden": true})
		layout.portals.append({"id": "talk_" + String(entry["id"]), "position": spot, "radius": 46.0, "label": "Hablar con " + String(entry["name"]), "action": "talk:" + String(entry["id"]), "requires_complete": false})


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
