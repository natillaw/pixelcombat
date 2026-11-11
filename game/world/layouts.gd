## Layouts — escenarios fijos: el patio de entrenamiento y la ciudad hub.
##
## Los pisos de la torre los genera `TowerGenerator`.
class_name Layouts
extends RefCounted

const CITY_BUILDINGS := [
	{"id": "blacksmith", "label": "Herreria", "color": Color(0.55, 0.30, 0.22)},
	{"id": "alchemist", "label": "Alquimia", "color": Color(0.30, 0.42, 0.55)},
	{"id": "carpenter", "label": "Carpinteria", "color": Color(0.50, 0.38, 0.22)},
	{"id": "tailor", "label": "Sastreria", "color": Color(0.48, 0.30, 0.50)},
	{"id": "tavern", "label": "Taberna", "color": Color(0.58, 0.40, 0.18)},
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


## La ciudad al pie de la torre: plaza con la puerta de la torre, el acceso al
## patio y los edificios de oficios (aun sin funcion) en el borde superior.
static func city() -> FloorLayout:
	var layout := FloorLayout.new()
	layout.id = "city"
	layout.kind = FloorLayout.KIND_CITY
	layout.title = "Ciudad"
	layout.size = Vector2(1120.0, 760.0)
	layout.play_area = Rect2(40.0, 200.0, 1040.0, 520.0)
	layout.theme = FloorLayout.make_theme({
		"name": "Ciudad",
		"background": [0.05, 0.05, 0.05],
		"floor": [0.20, 0.19, 0.17], "floor_dark": [0.155, 0.15, 0.13], "floor_light": [0.25, 0.24, 0.21],
		"wall": [0.24, 0.21, 0.17], "wall_dark": [0.14, 0.12, 0.10], "wall_light": [0.34, 0.30, 0.24],
		"accent": [0.90, 0.72, 0.35],
	})
	layout.player_spawn = Vector2(560.0, 610.0)
	# Fuente y arboles como obstaculos redondos.
	layout.obstacles = [
		{"position": Vector2(330, 470), "radius": 34.0},
		{"position": Vector2(790, 470), "radius": 34.0},
		{"position": Vector2(95, 260), "radius": 20.0}, {"position": Vector2(1025, 260), "radius": 20.0},
		{"position": Vector2(95, 670), "radius": 20.0}, {"position": Vector2(1025, 670), "radius": 20.0},
	]
	var width := 164.0
	var gap := 28.0
	var start := (layout.size.x - (width * float(CITY_BUILDINGS.size()) + gap * float(CITY_BUILDINGS.size() - 1))) * 0.5
	for i: int in range(CITY_BUILDINGS.size()):
		var spec: Dictionary = CITY_BUILDINGS[i]
		var x := start + float(i) * (width + gap)
		layout.buildings.append({"id": spec["id"], "rect": Rect2(x, 52.0, width, 134.0), "label": spec["label"], "color": spec["color"]})
		layout.portals.append({"id": "door_" + String(spec["id"]), "position": Vector2(x + width * 0.5, 212.0), "radius": 34.0, "label": String(spec["label"]), "action": "building:" + String(spec["id"]), "requires_complete": false})
	layout.portals.append({"id": "tower", "position": Vector2(560.0, 340.0), "radius": 54.0, "label": "Torre", "action": "tower", "requires_complete": false})
	layout.portals.append({"id": "to_training", "position": Vector2(1000.0, 480.0), "radius": 38.0, "label": "Patio de entrenamiento", "action": "to_training", "requires_complete": false})
	layout.torches = []
	for x: float in [start - 14.0, start + width + gap * 0.5, layout.size.x - start + 14.0]:
		layout.torches.append(Vector2(x, 196.0))
	return layout


static func _torches(layout: FloorLayout) -> Array:
	var bounds := layout.bounds()
	return [
		Vector2(bounds.position.x + 8.0, 172.0), Vector2(bounds.position.x + 8.0, 468.0),
		Vector2(bounds.end.x - 8.0, 172.0), Vector2(bounds.end.x - 8.0, 468.0),
	]
