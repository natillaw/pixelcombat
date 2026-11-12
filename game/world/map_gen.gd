## MapGen — genera mapas grandes de casillas de varios estilos: campo abierto, cuevas,
## ruinas (salas y pasillos) y mixto (campo con recintos de ruinas).
##
## Todos los estilos pasan por los mismos pasos finales: se podan los pasillos
## estrechos (la anchura minima es 3 casillas, para que quepan los jefes), se reserva
## una sala segura en la entrada, se conecta todo con la entrada (lo inconexo se une
## con un pasillo o se rellena) y se elige la salida en lo mas lejano. El resultado es
## un `MapAnalysis` con todo lo necesario para colocar contenido alcanzable.
class_name MapGen
extends RefCounted

const STYLES := ["field", "caves", "ruins", "mixed"]
const BORDER := 2
const SAFE_RADIUS := 4
const EXIT_RADIUS := 3


## Tamano (casillas) del mapa de un piso: los tres primeros son medianos; despues crece
## con el tier hasta casi el doble.
static func map_size(floor_number: int, rng: RandomNumberGenerator) -> Vector2i:
	if floor_number <= 3:
		return Vector2i(64 + rng.randi_range(0, 2) * 4, 48 + rng.randi_range(0, 2) * 4)
	var tier := TowerCatalog.tier_of_floor(floor_number)
	var growth := tier - 1
	return Vector2i(84 + growth * 4 + rng.randi_range(0, 3) * 4, 64 + growth * 3 + rng.randi_range(0, 3) * 4)


static func build(style: String, cols: int, rows: int, rng: RandomNumberGenerator) -> MapAnalysis:
	var grid := TileGrid.new(cols, rows, TileGrid.WALL)
	match style:
		"caves":
			_caves(grid, rng)
		"ruins":
			_ruins(grid, rng)
		"mixed":
			_mixed(grid, rng)
		_:
			_field(grid, rng)
	_border(grid)
	var spawn_cell := _choose_spawn(grid, rng)
	_clear_square(grid, spawn_cell, SAFE_RADIUS)
	_prune_thin(grid, spawn_cell)
	_connect(grid, rng, spawn_cell)
	var analysis := MapAnalysis.new(grid, spawn_cell)
	analysis.exit = _choose_exit(analysis, rng)
	_clear_square(grid, analysis.exit, EXIT_RADIUS)
	_border(grid)
	analysis.refresh()
	return analysis


# --- Estilos ----------------------------------------------------------------------


## Campo abierto: terreno libre con bosquetes, rocas y estanques.
static func _field(grid: TileGrid, rng: RandomNumberGenerator) -> void:
	_fill(grid, TileGrid.FLOOR)
	var area := grid.cols * grid.rows
	_blobs(grid, rng, TileGrid.WALL, area / 420, 2, 5)
	_blobs(grid, rng, TileGrid.WATER, area / 1400, 3, 7)
	_scatter(grid, rng, TileGrid.WALL, area / 90)


## Cuevas: automata celular sobre ruido.
static func _caves(grid: TileGrid, rng: RandomNumberGenerator) -> void:
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			grid.set_cell(c, r, TileGrid.WALL if rng.randf() < 0.44 else TileGrid.FLOOR)
	for i: int in range(5):
		_smooth(grid)
	_blobs(grid, rng, TileGrid.WATER, grid.cols * grid.rows / 2200, 2, 4)


## Ruinas: salas por particion binaria unidas por pasillos de 3 casillas.
static func _ruins(grid: TileGrid, rng: RandomNumberGenerator) -> void:
	var rooms: Array[Rect2i] = []
	_split(grid, rng, Rect2i(BORDER + 1, BORDER + 1, grid.cols - BORDER * 2 - 2, grid.rows - BORDER * 2 - 2), 0, rooms)
	for i: int in range(rooms.size() - 1):
		_carve_corridor(grid, rooms[i].get_center(), rooms[i + 1].get_center())
	for i: int in range(rooms.size()):
		var extra := rng.randi_range(0, rooms.size() - 1)
		if extra != i and rng.randf() < 0.35:
			_carve_corridor(grid, rooms[i].get_center(), rooms[extra].get_center())
	for room: Rect2i in rooms:
		if room.size.x >= 12 and room.size.y >= 10 and rng.randf() < 0.7:
			# Columnas en las salas grandes.
			var x := room.position.x + 3
			while x < room.end.x - 3:
				var y := room.position.y + 3
				while y < room.end.y - 3:
					grid.set_cell(x, y, TileGrid.WALL)
					y += 4
				x += 4
		if room.size.x >= 14 and room.size.y >= 12 and rng.randf() < 0.3:
			var middle := room.get_center()
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					grid.set_cell(middle.x + dx, middle.y + dy, TileGrid.WATER)


## Mixto: campo abierto con recintos de ruinas (muros con huecos) repartidos.
static func _mixed(grid: TileGrid, rng: RandomNumberGenerator) -> void:
	_field(grid, rng)
	var compounds := maxi(2, grid.cols * grid.rows / 1700)
	for i: int in range(compounds):
		var w := rng.randi_range(12, 20)
		var h := rng.randi_range(10, 16)
		var x := rng.randi_range(BORDER + 4, grid.cols - w - BORDER - 4)
		var y := rng.randi_range(BORDER + 4, grid.rows - h - BORDER - 4)
		for cx: int in range(x, x + w):
			for cy: int in range(y, y + h):
				var edge := cx == x or cx == x + w - 1 or cy == y or cy == y + h - 1
				grid.set_cell(cx, cy, TileGrid.WALL if edge else TileGrid.FLOOR)
		# Cuatro huecos de 3 casillas, uno por lado.
		var mid_x := x + w / 2
		var mid_y := y + h / 2
		for k: int in range(-1, 2):
			grid.set_cell(mid_x + k, y, TileGrid.FLOOR)
			grid.set_cell(mid_x + k, y + h - 1, TileGrid.FLOOR)
			grid.set_cell(x, mid_y + k, TileGrid.FLOOR)
			grid.set_cell(x + w - 1, mid_y + k, TileGrid.FLOOR)


# --- Piezas -----------------------------------------------------------------------


static func _fill(grid: TileGrid, kind: int) -> void:
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			grid.set_cell(c, r, kind)


static func _border(grid: TileGrid) -> void:
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if c < BORDER or r < BORDER or c >= grid.cols - BORDER or r >= grid.rows - BORDER:
				grid.set_cell(c, r, TileGrid.WALL)


static func _blobs(grid: TileGrid, rng: RandomNumberGenerator, kind: int, count: int, min_radius: int, max_radius: int) -> void:
	for i: int in range(count):
		var cx := rng.randi_range(BORDER + 2, grid.cols - BORDER - 3)
		var cy := rng.randi_range(BORDER + 2, grid.rows - BORDER - 3)
		var radius := rng.randi_range(min_radius, max_radius)
		for dy: int in range(-radius, radius + 1):
			for dx: int in range(-radius, radius + 1):
				var jitter := rng.randf_range(-0.8, 0.8)
				if float(dx * dx + dy * dy) <= float(radius * radius) + jitter * float(radius):
					grid.set_cell(cx + dx, cy + dy, kind)


static func _scatter(grid: TileGrid, rng: RandomNumberGenerator, kind: int, count: int) -> void:
	for i: int in range(count):
		grid.set_cell(rng.randi_range(BORDER, grid.cols - BORDER - 1), rng.randi_range(BORDER, grid.rows - BORDER - 1), kind)


static func _smooth(grid: TileGrid) -> void:
	var copy := grid.cells.duplicate()
	for r: int in range(1, grid.rows - 1):
		for c: int in range(1, grid.cols - 1):
			var walls := 0
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if copy[(r + dy) * grid.cols + c + dx] != TileGrid.FLOOR:
						walls += 1
			grid.set_cell(c, r, TileGrid.WALL if walls >= 5 else TileGrid.FLOOR)


static func _split(grid: TileGrid, rng: RandomNumberGenerator, area: Rect2i, depth: int, rooms: Array[Rect2i]) -> void:
	var can_split_x := area.size.x >= 26
	var can_split_y := area.size.y >= 22
	if depth < 6 and (can_split_x or can_split_y) and (depth < 2 or rng.randf() < 0.8):
		var horizontal := can_split_y if not can_split_x else (not can_split_y or rng.randf() < 0.5)
		if horizontal:
			var cut := rng.randi_range(area.position.y + 10, area.end.y - 10)
			_split(grid, rng, Rect2i(area.position.x, area.position.y, area.size.x, cut - area.position.y), depth + 1, rooms)
			_split(grid, rng, Rect2i(area.position.x, cut, area.size.x, area.end.y - cut), depth + 1, rooms)
		else:
			var cut_x := rng.randi_range(area.position.x + 12, area.end.x - 12)
			_split(grid, rng, Rect2i(area.position.x, area.position.y, cut_x - area.position.x, area.size.y), depth + 1, rooms)
			_split(grid, rng, Rect2i(cut_x, area.position.y, area.end.x - cut_x, area.size.y), depth + 1, rooms)
		return
	var w := rng.randi_range(maxi(8, area.size.x - 8), maxi(8, area.size.x - 2))
	var h := rng.randi_range(maxi(8, area.size.y - 8), maxi(8, area.size.y - 2))
	w = mini(w, area.size.x - 2)
	h = mini(h, area.size.y - 2)
	var room := Rect2i(area.position.x + rng.randi_range(1, maxi(1, area.size.x - w - 1)), area.position.y + rng.randi_range(1, maxi(1, area.size.y - h - 1)), w, h)
	for y: int in range(room.position.y, room.end.y):
		for x: int in range(room.position.x, room.end.x):
			grid.set_cell(x, y, TileGrid.FLOOR)
	rooms.append(room)


## Pasillo de 3 casillas de ancho en L entre dos puntos.
static func _carve_corridor(grid: TileGrid, from: Vector2i, to: Vector2i) -> void:
	# Los centros se mantienen lejos del borde para que el pasillo mida siempre 3.
	var a := Vector2i(clampi(from.x, BORDER + 1, grid.cols - BORDER - 2), clampi(from.y, BORDER + 1, grid.rows - BORDER - 2))
	var b := Vector2i(clampi(to.x, BORDER + 1, grid.cols - BORDER - 2), clampi(to.y, BORDER + 1, grid.rows - BORDER - 2))
	var x := a.x
	while x != b.x:
		for w: int in range(-1, 2):
			grid.set_cell(x, a.y + w, TileGrid.FLOOR)
		x += 1 if b.x > x else -1
	var y := a.y
	while y != b.y:
		for w: int in range(-1, 2):
			grid.set_cell(b.x + w, y, TileGrid.FLOOR)
		y += 1 if b.y > y else -1
	for w: int in range(-1, 2):
		for v: int in range(-1, 2):
			grid.set_cell(b.x + w, b.y + v, TileGrid.FLOOR)


static func _clear_square(grid: TileGrid, center: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if center.x + dx >= BORDER and center.y + dy >= BORDER and center.x + dx < grid.cols - BORDER and center.y + dy < grid.rows - BORDER:
				grid.set_cell(center.x + dx, center.y + dy, TileGrid.FLOOR)


## La entrada va en uno de los cuatro lados (al azar), a ~12 % del mapa.
static func _choose_spawn(grid: TileGrid, rng: RandomNumberGenerator) -> Vector2i:
	var corner := rng.randi_range(0, 3)
	var margin_x := maxi(int(float(grid.cols) * 0.1), SAFE_RADIUS + BORDER + 2)
	var margin_y := maxi(int(float(grid.rows) * 0.12), SAFE_RADIUS + BORDER + 2)
	var x := margin_x if corner % 2 == 0 else grid.cols - 1 - margin_x
	var y := margin_y if corner < 2 else grid.rows - 1 - margin_y
	return Vector2i(x, y)


## Quita lo estrecho: las casillas libres que no pertenecen a ningun bloque libre de
## 3x3 pasan a muro (queda anchura minima 3 salvo en la sala de entrada).
static func _prune_thin(grid: TileGrid, _keep_near: Vector2i) -> void:
	var keep := PackedByteArray()
	keep.resize(grid.cols * grid.rows)
	for r: int in range(1, grid.rows - 1):
		for c: int in range(1, grid.cols - 1):
			var full := true
			for dy: int in range(-1, 2):
				if not full:
					break
				for dx: int in range(-1, 2):
					if grid.get_cell(c + dx, r + dy) != TileGrid.FLOOR:
						full = false
						break
			if full:
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						keep[(r + dy) * grid.cols + c + dx] = 1
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if grid.get_cell(c, r) == TileGrid.FLOOR and keep[r * grid.cols + c] == 0:
				grid.set_cell(c, r, TileGrid.WALL)


## Une al mapa principal (el de la entrada) las zonas separadas con un pasillo, y rellena
## de muro las pequenas.
static func _connect(grid: TileGrid, rng: RandomNumberGenerator, spawn: Vector2i) -> void:
	for iteration: int in range(40):
		var main := grid.reachable_from(spawn)
		var loose: Vector2i = Vector2i(-1, -1)
		for r: int in range(grid.rows):
			for c: int in range(grid.cols):
				if grid.get_cell(c, r) == TileGrid.FLOOR and main[r * grid.cols + c] == 0:
					loose = Vector2i(c, r)
					break
			if loose.x >= 0:
				break
		if loose.x < 0:
			return
		var region := grid.reachable_from(loose)
		var size := 0
		for value: int in region:
			size += value
		if size < 40:
			for r: int in range(grid.rows):
				for c: int in range(grid.cols):
					if region[r * grid.cols + c] == 1:
						grid.set_cell(c, r, TileGrid.WALL)
			continue
		# Pasillo desde la region suelta hasta la casilla del mapa principal mas cercana.
		var best := spawn
		var best_distance := INF
		for r: int in range(0, grid.rows, 2):
			for c: int in range(0, grid.cols, 2):
				if main[r * grid.cols + c] == 1:
					var d := float((c - loose.x) * (c - loose.x) + (r - loose.y) * (r - loose.y))
					if d < best_distance:
						best_distance = d
						best = Vector2i(c, r)
		_carve_corridor(grid, loose, best)
		_border(grid)
	# Si tras 40 pasadas queda algo suelto, se rellena.
	var final_main := grid.reachable_from(spawn)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if grid.get_cell(c, r) == TileGrid.FLOOR and final_main[r * grid.cols + c] == 0:
				grid.set_cell(c, r, TileGrid.WALL)


## La salida: una casilla con holgura entre el 5 % mas lejano del camino.
static func _choose_exit(analysis: MapAnalysis, rng: RandomNumberGenerator) -> Vector2i:
	var far: Array[Vector2i] = []
	var threshold := int(float(analysis.max_dist) * 0.93)
	for cell: Vector2i in analysis.reach:
		if analysis.dist[cell.y * analysis.grid.cols + cell.x] >= threshold and analysis.clearance_at(cell) >= 2:
			far.append(cell)
	if far.is_empty():
		for cell: Vector2i in analysis.reach:
			if analysis.dist[cell.y * analysis.grid.cols + cell.x] >= threshold:
				far.append(cell)
	return far[rng.randi_range(0, far.size() - 1)]
