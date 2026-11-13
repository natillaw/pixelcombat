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
	_giant_tower(layout, grid)
	var slots := [
		# Fila norte (puertas hacia la calle de la plaza).
		[8, 27, "house", "stone_house", "Casa"], [15, 27, "store", "general_store", "Tienda"], [22, 27, "blacksmith", "blacksmith", "Herreria"],
		[62, 27, "tailor", "tailor", "Sastreria"], [69, 27, "library", "library", "Biblioteca"], [76, 27, "church", "church", "Iglesia"],
		# Fila central.
		[8, 43, "cottage_a", "cottage", "Casa"], [15, 43, "carpenter", "carpenter", "Carpinteria"], [22, 43, "alchemist", "herbalist", "Alquimia"],
		[62, 43, "tavern", "tavern", "Taberna"], [69, 43, "guild", "guild", "Gremio de aventureros"], [76, 43, "merchant", "merchant_house", "Mercader"],
		# Fila sur.
		[8, 58, "town_house", "town_house", "Casa"], [15, 58, "bakery", "bakery", "Panaderia"], [22, 58, "bank", "noble_house", "Banco"],
		[62, 58, "guard", "guard_house", "Guardia"], [69, 58, "hall", "town_hall", "Ayuntamiento"], [76, 58, "wizard", "wizard_hut", "Mago"],
	]
	var functional := ["blacksmith", "tailor", "carpenter", "alchemist", "tavern", "guild", "merchant", "bank"]
	for slot: Array in slots:
		var id := String(slot[2])
		var has_door := functional.has(id)
		_building(layout, grid, {"id": id, "sprite": String(slot[3]), "label": String(slot[4]), "scale": 2.0, "cx": int(slot[0]), "base": int(slot[1]), "half": 2, "door": has_door, "action": "building:" + id})
	layout.portals.append({"id": "to_training", "position": Vector2(77.0 * 32.0, 31.5 * 32.0), "radius": 38.0, "label": "Patio de entrenamiento", "action": "to_training", "requires_complete": false})
	_decorate_city(layout, grid)
	_townsfolk(layout)
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


## PNJ de los talleres: aspecto LPC (cuerpo, piel, pelo...) y la ropa que llevan.
const NPCS := {
	"blacksmith": {"name": "Brann, el herrero", "look": {"body": "male", "skin": "amber", "eyes": "brown", "head": "head_human_male", "hair": "hair_buzzcut", "hair_color": "black", "beard": "beard_trimmed"},
		"equipment": {"chest": ["shirt_sleeveless", "charcoal"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"], "main_hand": ["weapon_mace", "default"]}},
	"alchemist": {"name": "Mira, la alquimista", "look": {"body": "female", "skin": "light", "eyes": "green", "head": "head_human_female", "hair": "hair_bob", "hair_color": "ginger", "beard": ""},
		"equipment": {"chest": ["shirt_longsleeve", "navy"], "legs": ["pants_dyed", "navy"], "feet": ["shoes_basic", "leather"], "main_hand": ["weapon_wand", "default"]}},
	"carpenter": {"name": "Tomas, el carpintero", "look": {"body": "male", "skin": "olive", "eyes": "brown", "head": "head_human_male", "hair": "hair_plain", "hair_color": "dark_brown", "beard": ""},
		"equipment": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants", "brown"], "feet": ["shoes_basic", "leather"]}},
	"tailor": {"name": "Lena, la sastre", "look": {"body": "female", "skin": "taupe", "eyes": "blue", "head": "head_human_female", "hair": "hair_plain", "hair_color": "blonde", "beard": ""},
		"equipment": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants_dyed", "walnut"], "feet": ["boots_basic", "leather"]}},
	"guild": {"name": "Dara, capitana del gremio", "look": {"body": "female", "skin": "olive", "eyes": "brown", "head": "head_human_female", "hair": "hair_plain", "hair_color": "black", "beard": ""},
		"equipment": {"chest": ["shirt_sleeveless", "charcoal"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"], "head": ["bandana", "maroon"], "main_hand": ["weapon_arming", "default"]}},
	"merchant": {"name": "Orla, la mercader", "look": {"body": "female", "skin": "amber", "eyes": "green", "head": "head_human_female", "hair": "hair_bob", "hair_color": "chestnut", "beard": ""},
		"equipment": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants_dyed", "walnut"], "feet": ["shoes_basic", "leather"], "bag": ["cape", "maroon"]}},
	"bank": {"name": "Tessin, el banquero", "look": {"body": "male", "skin": "light", "eyes": "gray", "head": "head_human_male", "hair": "hair_plain", "hair_color": "white", "beard": "beard_trimmed"},
		"equipment": {"chest": ["shirt_longsleeve", "navy"], "legs": ["pants", "charcoal"], "feet": ["shoes_basic", "leather"]}},
	"tavern": {"name": "Ottis, el tabernero", "look": {"body": "male", "skin": "bronze", "eyes": "gray", "head": "head_human_male", "hair": "hair_buzzcut", "hair_color": "gray", "beard": "beard_trimmed"},
		"equipment": {"chest": ["shirt_longsleeve", "tan"], "legs": ["pants", "brown"], "feet": ["shoes_basic", "leather"]}},
}


## Gente que pasea por la avenida (solo ambiente: van y vienen entre dos puntos, sin colision ni dialogo).
const TOWNSFOLK := [
	["Aldeano", Vector2(40.5, 21.0), Vector2(45.0, 21.0)], ["Viajera", Vector2(41.0, 37.0), Vector2(41.0, 47.0)],
	["Aldeano", Vector2(44.5, 38.0), Vector2(44.5, 55.0)], ["Peregrina", Vector2(40.5, 56.0), Vector2(45.5, 50.0)],
	["Aldeano", Vector2(43.0, 24.0), Vector2(43.0, 27.5)], ["Viajero", Vector2(45.5, 44.0), Vector2(40.5, 44.0)],
]


static func _townsfolk(layout: FloorLayout) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var outfits := [
		{"chest": ["shirt_longsleeve", "tan"], "legs": ["pants", "brown"], "feet": ["shoes_basic", "leather"]},
		{"chest": ["shirt_sleeveless", "charcoal"], "legs": ["pants", "charcoal"], "feet": ["boots_basic", "black"]},
		{"chest": ["shirt_longsleeve", "navy"], "legs": ["pants_dyed", "navy"], "feet": ["shoes_basic", "leather"]},
	]
	for i: int in range(TOWNSFOLK.size()):
		var entry: Array = TOWNSFOLK[i]
		var from: Vector2 = (entry[1] as Vector2) * 32.0
		var to: Vector2 = (entry[2] as Vector2) * 32.0
		layout.npcs.append({"id": "folk_%d" % i, "name": String(entry[0]), "position": from, "look": LpcWardrobe.random_look(rng), "equipment": outfits[i % outfits.size()],
			"wander": {"from": from, "to": to, "speed": rng.randf_range(16.0, 26.0)}})


## La Torre de las Cien Puertas: una aguja gigantesca que domina el norte de la ciudad y se
## pierde entre las nubes (no se ve su cima). Ocupa un bloque solido de 23 x 12 casillas; su
## puerta, al pie, es el portal de entrada a la torre.
static func _giant_tower(layout: FloorLayout, grid: TileGrid) -> void:
	for r: int in range(3, 15):
		for c: int in range(35, 51):
			grid.set_cell(c, r, TileGrid.SOLID)
			layout.footprints.append(Vector2i(c, r))
	var foot := Vector2(42.5 * 32.0, 15.0 * 32.0)
	layout.landmarks.append({"kind": "giant_tower", "position": foot, "width": 15.0 * 32.0})
	layout.portals.append({"id": "door_tower", "position": foot + Vector2(0.0, 22.0), "radius": 64.0, "label": "Torre de las Cien Puertas", "action": "tower", "requires_complete": false})


## Coloca un edificio: bloquea sus 4 filas inferiores (y las marca como cimientos) y, si
## tiene puerta, crea el portal justo debajo del centro. Los edificios con taller llevan
## a su PNJ delante de la puerta: hablar con el abre el taller. `cx`/`base` son la casilla
## del centro y la fila de la base.
static func _building(layout: FloorLayout, grid: TileGrid, spec: Dictionary) -> void:
	var cx: int = spec["cx"]
	var base: int = spec["base"]
	var half: int = spec["half"]
	for r: int in range(base - 3, base + 1):
		for c: int in range(cx - half, cx + half + 1):
			grid.set_cell(c, r, TileGrid.SOLID)
			layout.footprints.append(Vector2i(c, r))
	var foot := Vector2((float(cx) + 0.5) * 32.0, float(base + 1) * 32.0 - 2.0)
	var scale: float = spec["scale"]
	layout.buildings.append({
		"id": String(spec["id"]), "sprite": "res://assets/pixel/village/%s.png" % String(spec["sprite"]),
		"foot": foot, "scale": scale, "label": String(spec["label"]),
		"rect": Rect2(foot.x - 40.0 * scale, foot.y - 73.0 * scale, 80.0 * scale, 73.0 * scale), "color": Color(0.5, 0.35, 0.25),
	})
	var id := String(spec["id"])
	if NPCS.has(id):
		var npc: Dictionary = NPCS[id]
		var spot := foot + Vector2(-34.0, 40.0)
		layout.npcs.append({"id": "npc_" + id, "name": String(npc["name"]), "station": id, "position": spot, "look": npc["look"], "equipment": npc["equipment"]})
		layout.obstacles.append({"position": spot, "radius": 13.0, "hidden": true})
		layout.portals.append({"id": "door_" + id, "position": spot, "radius": 46.0, "label": "Hablar con " + String(npc["name"]), "action": String(spec["action"]), "requires_complete": false})
	elif bool(spec["door"]):
		layout.portals.append({"id": "door_" + id, "position": foot + Vector2(0.0, 26.0), "radius": 40.0 if id != "tower" else 60.0, "label": String(spec["label"]), "action": String(spec["action"]), "requires_complete": false})


## Adorna la ciudad: dos estanques, barriles y cajas junto a los talleres, arboles sueltos
## por las zonas verdes (con colision) y arbustos (solo decoracion). Todo es determinista.
static func _decorate_city(layout: FloorLayout, grid: TileGrid) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for pond: Vector2i in [Vector2i(30, 37), Vector2i(54, 37), Vector2i(30, 52), Vector2i(54, 52)]:
		for dy: int in range(-3, 4):
			for dx: int in range(-3, 4):
				if dx * dx + dy * dy <= 8:
					grid.set_cell(pond.x + dx, pond.y + dy, TileGrid.WATER)
	for building: Dictionary in layout.buildings:
		if not NPCS.has(String(building["id"])):
			continue
		var foot: Vector2 = building["foot"]
		for entry: Array in [[Vector2(78.0, 22.0), "barrel"], [Vector2(104.0, 20.0), "crate"], [Vector2(-96.0, 22.0), "barrel"]]:
			var spot := foot + (entry[0] as Vector2)
			var cell := grid.world_to_cell(spot)
			if grid.get_cell(cell.x, cell.y) == TileGrid.FLOOR:
				grid.set_cell(cell.x, cell.y, TileGrid.SOLID)
				layout.decor.append({"kind": String(entry[1]), "position": grid.cell_center(cell.x, cell.y) + Vector2(0.0, 12.0)})
	var trees: Array[Vector2i] = []
	for attempt: int in range(900):
		var cell := Vector2i(rng.randi_range(5, grid.cols - 6), rng.randi_range(5, grid.rows - 6))
		if grid.get_cell(cell.x, cell.y) != TileGrid.FLOOR or not _clear_of_paths(grid, cell, 3):
			continue
		var spaced := true
		for other: Vector2i in trees:
			if absi(other.x - cell.x) < 5 and absi(other.y - cell.y) < 5:
				spaced = false
		var near_portal := false
		for portal: Dictionary in layout.portals:
			if (portal["position"] as Vector2).distance_to(grid.cell_center(cell.x, cell.y)) < 120.0:
				near_portal = true
		if spaced and not near_portal and grid.cell_center(cell.x, cell.y).distance_to(layout.player_spawn) > 160.0:
			trees.append(cell)
			layout.obstacles.append({"position": grid.cell_center(cell.x, cell.y) + Vector2(0.0, 6.0), "radius": 24.0, "hidden": true})
			layout.decor.append({"kind": "tree", "position": grid.cell_center(cell.x, cell.y) + Vector2(0.0, 12.0)})
	for attempt: int in range(500):
		var cell := Vector2i(rng.randi_range(5, grid.cols - 6), rng.randi_range(5, grid.rows - 6))
		if grid.get_cell(cell.x, cell.y) == TileGrid.FLOOR and _clear_of_paths(grid, cell, 1):
			var spot := grid.cell_center(cell.x, cell.y) + Vector2(rng.randf_range(-8.0, 8.0), 12.0)
			var in_the_way := spot.distance_to(layout.player_spawn) < 100.0
			for portal: Dictionary in layout.portals:
				in_the_way = in_the_way or (portal["position"] as Vector2).distance_to(spot) < 70.0
			if in_the_way:
				continue
			layout.decor.append({"kind": "bush", "position": spot})
			layout.obstacles.append({"position": spot + Vector2(0.0, -6.0), "radius": 14.0, "hidden": true})


## Si no hay calle, edificio ni agua a `distance` casillas de `cell`.
static func _clear_of_paths(grid: TileGrid, cell: Vector2i, distance: int) -> bool:
	for dy: int in range(-distance, distance + 1):
		for dx: int in range(-distance, distance + 1):
			var kind := grid.get_cell(cell.x + dx, cell.y + dy)
			if kind == TileGrid.ROAD or kind == TileGrid.SOLID or kind == TileGrid.WATER:
				return false
	return true


static func _torches(layout: FloorLayout) -> Array:
	var bounds := layout.bounds()
	return [
		Vector2(bounds.position.x + 8.0, 172.0), Vector2(bounds.position.x + 8.0, 468.0),
		Vector2(bounds.end.x - 8.0, 172.0), Vector2(bounds.end.x - 8.0, 468.0),
	]
