## Layouts — escenarios fijos: el patio de entrenamiento y la ciudad hub.
##
## Los pisos de la torre los genera `TowerGenerator`.
class_name Layouts
extends RefCounted

## Edificios con taller (por orden de estacion); el resto de la ciudad es decoracion.
const CITY_BUILDINGS := [
	{"id": "blacksmith", "label": "Herreria"},
	{"id": "alchemist", "label": "Alquimia"},
	{"id": "carpenter", "label": "Carpinteria"},
	{"id": "tailor", "label": "Sastreria"},
	{"id": "tavern", "label": "Taberna"},
]


## El patio de entrenamiento: muñecos, los enemigos del tier 1 acampados en las
## esquinas y el jefe, para probar el combate sin avanzar por la torre.
static func training() -> FloorLayout:
	var layout := FloorLayout.new()
	layout.id = "training"
	layout.kind = FloorLayout.KIND_TRAINING
	layout.title = "Patio de entrenamiento"
	layout.theme = FloorLayout.default_theme()
	layout.theme["emblem"] = true
	for point: Vector2 in [Vector2(145, 145), Vector2(815, 145), Vector2(145, 495), Vector2(815, 495), Vector2(185, 320), Vector2(775, 320)]:
		layout.obstacles.append({"position": point, "radius": 21.0})
	layout.dummies = [
		{"position": Vector2(480, 196), "auto_attack": true},
		{"position": Vector2(660, 390), "auto_attack": false},
		{"position": Vector2(300, 410), "auto_attack": false},
	]
	for spawn: Array in [
		[&"slime", Vector2(820, 560)], [&"bat", Vector2(110, 575)], [&"spider", Vector2(840, 80)],
		[&"beetle", Vector2(480, 590)], [&"wisp", Vector2(860, 330)], [&"hornet", Vector2(100, 330)],
		[&"brood_beetle", Vector2(480, 62)],
	]:
		layout.enemies.append({"id": spawn[0], "position": spawn[1], "required": false})
	layout.resources = [
		{"kind": "ore", "position": Vector2(300, 250)},
		{"kind": "herb", "position": Vector2(560, 300)},
		{"kind": "wood", "position": Vector2(380, 470)},
	]
	layout.portals = [{"id": "to_city", "position": Vector2(92, 86), "radius": 34.0, "label": "Volver a la ciudad", "action": "to_city", "requires_complete": false}]
	layout.torches = _torches(layout)
	layout.player_spawn = layout.bounds().get_center()
	return layout


## La ciudad al pie de la torre: un mapa de casillas grande (84 x 64) con una avenida
## que sube de la puerta sur a la torre, dos calles transversales, una plaza con fuente y
## tres filas de edificios a cada lado. Los edificios de oficio abren su taller; el resto
## son decoracion (por ahora). La torre cierra el norte.
static func city() -> FloorLayout:
	var layout := FloorLayout.new()
	layout.id = "city"
	layout.kind = FloorLayout.KIND_CITY
	layout.title = "Ciudad"
	layout.biome = "town"
	var cols := 84
	var rows := 64
	var grid := TileGrid.new(cols, rows, TileGrid.WALL)
	for r: int in range(3, rows - 3):
		for c: int in range(3, cols - 3):
			grid.set_cell(c, r, TileGrid.FLOOR)
	_road(grid, 40, 16, 5, 45)
	_road(grid, 6, 30, 73, 4)
	_road(grid, 6, 46, 73, 4)
	for r: int in range(-7, 8):
		for c: int in range(-7, 8):
			if c * c + r * r <= 49:
				grid.set_cell(42 + c, 31 + r, TileGrid.ROAD)
	layout.grid = grid
	layout.size = grid.pixel_size()
	layout.wall = 0.0
	layout.play_area = Rect2(Vector2.ZERO, layout.size)
	layout.theme = FloorLayout.make_theme({
		"name": "Ciudad", "background": [0.05, 0.05, 0.05],
		"floor": [0.20, 0.30, 0.16], "floor_dark": [0.16, 0.26, 0.13], "floor_light": [0.24, 0.34, 0.2],
		"wall": [0.24, 0.21, 0.17], "wall_dark": [0.14, 0.12, 0.10], "wall_light": [0.34, 0.30, 0.24],
		"accent": [0.90, 0.72, 0.35],
	})
	layout.player_spawn = Vector2(42.5 * 32.0, 58.0 * 32.0)
	# La fuente de la plaza (circulo de colision).
	layout.obstacles = [{"position": Vector2(42.5 * 32.0, 31.5 * 32.0), "radius": 34.0}]

	# Torre: cierra el norte de la avenida.
	_building(layout, grid, {"id": "tower", "sprite": "clock_tower", "label": "Torre", "scale": 3.2, "cx": 42, "base": 14, "half": 3, "door": true, "action": "tower"})
	var slots := [
		# Fila norte (puertas hacia la calle de la plaza).
		[8, 27, "house", "stone_house", "Casa"], [15, 27, "store", "general_store", "Tienda"], [22, 27, "blacksmith", "blacksmith", "Herreria"],
		[62, 27, "tailor", "tailor", "Sastreria"], [69, 27, "library", "library", "Biblioteca"], [76, 27, "church", "church", "Iglesia"],
		# Fila central.
		[8, 43, "cottage_a", "cottage", "Casa"], [15, 43, "carpenter", "carpenter", "Carpinteria"], [22, 43, "alchemist", "herbalist", "Alquimia"],
		[62, 43, "tavern", "tavern", "Taberna"], [69, 43, "guild", "guild", "Gremio de aventureros"], [76, 43, "merchant", "merchant_house", "Mercader"],
		# Fila sur.
		[8, 58, "town_house", "town_house", "Casa"], [15, 58, "bakery", "bakery", "Panaderia"], [22, 58, "noble", "noble_house", "Casa noble"],
		[62, 58, "guard", "guard_house", "Guardia"], [69, 58, "hall", "town_hall", "Ayuntamiento"], [76, 58, "wizard", "wizard_hut", "Mago"],
	]
	var functional := ["blacksmith", "tailor", "carpenter", "alchemist", "tavern", "guild"]
	for slot: Array in slots:
		var id := String(slot[2])
		var has_door := functional.has(id)
		_building(layout, grid, {"id": id, "sprite": String(slot[3]), "label": String(slot[4]), "scale": 2.0, "cx": int(slot[0]), "base": int(slot[1]), "half": 2, "door": has_door, "action": "building:" + id})
	layout.portals.append({"id": "to_training", "position": Vector2(77.0 * 32.0, 31.5 * 32.0), "radius": 38.0, "label": "Patio de entrenamiento", "action": "to_training", "requires_complete": false})
	layout.torches = []
	for y: int in [20, 25, 36, 41, 52, 57]:
		layout.torches.append(Vector2(39.0 * 32.0, float(y) * 32.0))
		layout.torches.append(Vector2(46.0 * 32.0, float(y) * 32.0))
	return layout


static func _road(grid: TileGrid, x: int, y: int, width: int, height: int) -> void:
	for r: int in range(y, y + height):
		for c: int in range(x, x + width):
			if grid.get_cell(c, r) == TileGrid.FLOOR:
				grid.set_cell(c, r, TileGrid.ROAD)


## Coloca un edificio: bloquea sus 4 filas inferiores y, si tiene puerta, crea el portal
## justo debajo del centro. `cx`/`base` son la casilla del centro y la fila de la base.
static func _building(layout: FloorLayout, grid: TileGrid, spec: Dictionary) -> void:
	var cx: int = spec["cx"]
	var base: int = spec["base"]
	var half: int = spec["half"]
	for r: int in range(base - 3, base + 1):
		for c: int in range(cx - half, cx + half + 1):
			grid.set_cell(c, r, TileGrid.SOLID)
	var foot := Vector2((float(cx) + 0.5) * 32.0, float(base + 1) * 32.0 - 2.0)
	var scale: float = spec["scale"]
	layout.buildings.append({
		"id": String(spec["id"]), "sprite": "res://assets/pixel/village/%s.png" % String(spec["sprite"]),
		"foot": foot, "scale": scale, "label": String(spec["label"]),
		"rect": Rect2(foot.x - 40.0 * scale, foot.y - 73.0 * scale, 80.0 * scale, 73.0 * scale), "color": Color(0.5, 0.35, 0.25),
	})
	if bool(spec["door"]):
		layout.portals.append({"id": "door_" + String(spec["id"]), "position": foot + Vector2(0.0, 26.0), "radius": 40.0 if String(spec["id"]) != "tower" else 60.0, "label": String(spec["label"]), "action": String(spec["action"]), "requires_complete": false})


static func _torches(layout: FloorLayout) -> Array:
	var bounds := layout.bounds()
	return [
		Vector2(bounds.position.x + 8.0, 172.0), Vector2(bounds.position.x + 8.0, 468.0),
		Vector2(bounds.end.x - 8.0, 172.0), Vector2(bounds.end.x - 8.0, 468.0),
	]
