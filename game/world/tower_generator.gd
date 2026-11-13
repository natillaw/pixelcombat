## TowerGenerator — genera de forma determinista los pisos de la torre.
##
## `generate(piso, semilla_del_mundo, visita)`:
##  - El **terreno** (estilo, tamano, mapa, entrada y salida) sale solo de la semilla del
##    mundo y el numero de piso: es siempre el mismo, asi un piso "se guarda" con solo
##    recordar su numero.
##  - El **contenido** (misiones, enemigos, objetos, nodos) sale ademas del numero de
##    visita: cada vez que se entra a un piso se sortean misiones nuevas, pero siempre
##    cumplibles en ese terreno (ver MissionGen).
## El tier fija el bioma, los estilos de mapa, los enemigos y los jefes (data/tower.json);
## los pisos 5 y 10 de cada tier son de pico (mini-jefes y jefe).
class_name TowerGenerator
extends RefCounted


## `forced` (solo pruebas): ids de mision que sustituyen al sorteo (principal, opcional)
## o, en un piso x10, la variante de la prueba (seals, gauntlet, elites).
static func generate(floor_number: int, world_seed: int, visit: int = 1, forced: Array = [], with_elite: bool = false) -> FloorLayout:
	var tier_number := TowerCatalog.tier_of_floor(floor_number)
	var tier_data := TowerCatalog.tier(tier_number)
	var spike := TowerCatalog.spike_kind(floor_number)
	var terrain_rng := RandomNumberGenerator.new()
	terrain_rng.seed = world_seed * 1000003 + floor_number * 7919

	var layout := FloorLayout.new()
	layout.id = "tower_%d" % floor_number
	layout.kind = FloorLayout.KIND_FLOOR
	layout.floor_number = floor_number
	layout.tier = tier_number
	layout.seed_value = int(terrain_rng.seed)
	layout.title = Lore.floor_title(floor_number)
	layout.theme = FloorLayout.make_theme(tier_data["theme"])
	layout.theme["name"] = String(tier_data["name"])
	layout.biome = TowerCatalog.biome(tier_number)
	layout.enemy_scale = TowerCatalog.enemy_scale(floor_number)

	layout.style = _pick_style(terrain_rng, TowerCatalog.styles(tier_number))
	var size := MapGen.map_size(floor_number, terrain_rng)
	var analysis := MapGen.build(layout.style, size.x, size.y, terrain_rng)
	layout.grid = analysis.grid
	layout.wall_margin = TowerCatalog.biome_wall_margin(layout.biome)
	layout.size = analysis.grid.pixel_size()
	layout.wall = 0.0
	layout.play_area = Rect2(Vector2.ZERO, layout.size)
	layout.player_spawn = analysis.spawn_position()
	var exit_position := analysis.exit_position()
	# La entrada va dentro de la sala segura, algo apartada de donde aparece el jugador.
	var entrance_position := layout.player_spawn + Vector2(-72.0, 0.0)
	if not analysis.grid.is_walkable_point(entrance_position):
		entrance_position = layout.player_spawn + Vector2(72.0, 0.0)
	layout.portals = [
		{"id": "exit", "position": exit_position, "radius": 54.0,
			"label": "Subir al piso %d" % (floor_number + 1) if floor_number < TowerCatalog.floors() else "Cima de la torre",
			"action": "next_floor" if floor_number < TowerCatalog.floors() else "to_city", "requires_complete": true},
		{"id": "entrance", "position": entrance_position, "radius": 36.0, "label": "Volver a la ciudad", "action": "to_city", "requires_complete": false},
	]

	var content_rng := RandomNumberGenerator.new()
	content_rng.seed = int(terrain_rng.seed) * 31 + visit * 104729
	MissionGen.populate(layout, analysis, content_rng, floor_number, tier_data, spike, forced)
	layout.modifier = FloorModifiers.pick(floor_number, layout.seed_value, float(layout.features.get("modifier_chance", 0.0)))
	if with_elite:
		MissionGen.add_wandering_elite(layout, analysis, content_rng)
	MissionGen.add_campfire(layout, analysis, content_rng, floor_number)
	layout.wall_margin = _safe_margin(layout)
	return layout


## Mayor holgura (de la del bioma hacia 0) con la que la entrada sigue conectada con la salida y con todos los
## enemigos y objetos del piso para un circulo del tamano del jugador mas la holgura (la mayor, al norte de un muro).
static func _safe_margin(layout: FloorLayout) -> float:
	var wanted := layout.wall_margin
	if wanted <= 0.0 or layout.grid == null:
		return wanted
	var grid := layout.grid
	var points: Array[Vector2] = [layout.player_spawn]
	for portal: Dictionary in layout.portals:
		points.append(portal["position"])
	for enemy: Dictionary in layout.enemies:
		points.append(enemy["position"])
	for enemy: Dictionary in layout.deferred_enemies:
		points.append(enemy["position"])
	for object: Dictionary in layout.interactables:
		points.append(object["position"])
	for node: Dictionary in layout.resources:
		points.append(node["position"])
	var clearance := _clearance_px(grid)
	for candidate: float in [wanted, wanted * 0.75, wanted * 0.5, wanted * 0.25]:
		if _connected(grid, clearance, 20.0 + candidate * TileGrid.NORTH_MARGIN_FACTOR, points):
			return candidate
	return 0.0


## Distancia (px) del centro de cada casilla a la pared mas cercana (transformada de distancia aproximada).
static func _clearance_px(grid: TileGrid) -> PackedFloat32Array:
	var cells := grid.cols * grid.rows
	var dist := PackedFloat32Array()
	dist.resize(cells)
	for i: int in range(cells):
		dist[i] = 0.0 if grid.get_cell(i % grid.cols, i / grid.cols) == TileGrid.WALL else 1.0e6
	var steps := [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			for step: Vector2i in steps:
				var nc := c + step.x
				var nr := r + step.y
				if nc >= 0 and nc < grid.cols and nr >= 0:
					dist[r * grid.cols + c] = minf(dist[r * grid.cols + c], dist[nr * grid.cols + nc] + (1.0 if step.x == 0 or step.y == 0 else 1.4142))
	var back := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)]
	for r: int in range(grid.rows - 1, -1, -1):
		for c: int in range(grid.cols - 1, -1, -1):
			for step: Vector2i in back:
				var nc := c + step.x
				var nr := r + step.y
				if nc >= 0 and nc < grid.cols and nr < grid.rows:
					dist[r * grid.cols + c] = minf(dist[r * grid.cols + c], dist[nr * grid.cols + nc] + (1.0 if step.x == 0 or step.y == 0 else 1.4142))
	var out := PackedFloat32Array()
	out.resize(cells)
	for i: int in range(cells):
		out[i] = dist[i] * float(TileGrid.TILE) - float(TileGrid.TILE) * 0.5
	return out


static func _connected(grid: TileGrid, clearance: PackedFloat32Array, radius: float, points: Array[Vector2]) -> bool:
	var cells := grid.cols * grid.rows
	var open := PackedByteArray()
	open.resize(cells)
	for i: int in range(cells):
		open[i] = 1 if clearance[i] >= radius and not grid.blocks_move(i % grid.cols, i / grid.cols) else 0
	var start := _nearest_open(grid, open, points[0])
	if start.x < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(cells)
	var queue: Array[Vector2i] = [start]
	seen[start.y * grid.cols + start.x] = 1
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := current + offset
			if next.x >= 0 and next.y >= 0 and next.x < grid.cols and next.y < grid.rows and open[next.y * grid.cols + next.x] == 1 and seen[next.y * grid.cols + next.x] == 0:
				seen[next.y * grid.cols + next.x] = 1
				queue.append(next)
	for point: Vector2 in points:
		var cell := grid.world_to_cell(point)
		if not grid.in_bounds(cell.x, cell.y):
			continue
		# Un objetivo cuyo entorno inmediato esta cerrado por la holgura se acepta si hay una casilla abierta alcanzada en la casilla contigua (a alcance de golpe).
		var reached := false
		for dr: int in range(-1, 2):
			for dc: int in range(-1, 2):
				if grid.in_bounds(cell.x + dc, cell.y + dr) and seen[(cell.y + dr) * grid.cols + cell.x + dc] == 1:
					reached = true
		if not reached:
			return false
	return true


static func _nearest_open(grid: TileGrid, open: PackedByteArray, point: Vector2) -> Vector2i:
	var origin := grid.world_to_cell(point)
	for radius: int in range(0, 6):
		for dr: int in range(-radius, radius + 1):
			for dc: int in range(-radius, radius + 1):
				var c := origin.x + dc
				var r := origin.y + dr
				if grid.in_bounds(c, r) and open[r * grid.cols + c] == 1:
					return Vector2i(c, r)
	return Vector2i(-1, -1)


static func _pick_style(rng: RandomNumberGenerator, styles: Array) -> String:
	var total := 0.0
	for entry: Dictionary in styles:
		total += float(entry["weight"])
	var roll := rng.randf() * total
	for entry: Dictionary in styles:
		roll -= float(entry["weight"])
		if roll <= 0.0:
			return String(entry["style"])
	return String((styles[styles.size() - 1] as Dictionary)["style"])
