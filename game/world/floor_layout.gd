## FloorLayout — descripcion de un escenario jugable: el patio de entrenamiento,
## la ciudad o un piso de la torre.
##
## Es solo datos (limites, obstaculos, enemigos, portales, edificios, tema de
## color). Lo producen `Layouts` (patio y ciudad) y `TowerGenerator` (pisos); lo
## consume `CombatWorld.load_layout()` para simular y `Arena` para dibujar. Todo
## lo que ve el jugador de un piso sale de aqui, por eso es determinista: la misma
## semilla da el mismo layout.
class_name FloorLayout
extends RefCounted

const KIND_TRAINING := "training"
const KIND_CITY := "city"
const KIND_FLOOR := "floor"

var id: String = ""
var kind: String = KIND_TRAINING
var title: String = ""
## Tamaño total del mapa, muros incluidos.
var size: Vector2 = Vector2(960.0, 640.0)
var wall: float = 40.0
## Zona jugable si no es "todo menos los muros" (la ciudad reserva arriba el borde
## de los edificios). Rect2() vacio = usar size menos muros.
var play_area: Rect2 = Rect2()
var theme: Dictionary = {}
## [{position: Vector2, radius: float}]
var obstacles: Array = []
## [{position: Vector2, auto_attack: bool}]
var dummies: Array = []
## [{id: StringName, position: Vector2, required: bool}]
var enemies: Array = []
## Puntos de interaccion: [{id, position, radius, label, action, requires_complete}]
## action: "to_city", "to_training", "to_floor:N", "next_floor" o "building:id".
var portals: Array = []
## Fachadas decorativas (ciudad): [{id, rect, label, color}]
var buildings: Array = []
var torches: Array = []
## Nodos de recoleccion: [{kind: "ore"|"herb"|"wood", position: Vector2}]
var resources: Array = []
var player_spawn: Vector2 = Vector2.ZERO
var floor_number: int = 0
var tier: int = 0
## Escala de vida/dano/XP de los enemigos del piso (1 = base).
var enemy_scale: float = 1.0
## {type: "clear"|"boss", label: String}
var objective: Dictionary = {}
var seed_value: int = 0


## Zona jugable (donde se mueve el jugador).
func bounds() -> Rect2:
	if play_area.size.x > 0.0 and play_area.size.y > 0.0:
		return play_area
	return Rect2(wall, wall, size.x - wall * 2.0, size.y - wall * 2.0)


## Tema por defecto: la piedra azulada del patio de entrenamiento.
static func default_theme() -> Dictionary:
	return {
		"name": "Patio",
		"background": Color(0.045, 0.05, 0.07),
		"floor": Color(0.13, 0.14, 0.18),
		"floor_dark": Color(0.10, 0.11, 0.145),
		"floor_light": Color(0.165, 0.175, 0.215),
		"wall": Color(0.17, 0.18, 0.23),
		"wall_dark": Color(0.11, 0.12, 0.155),
		"wall_light": Color(0.24, 0.25, 0.31),
		"accent": Color(0.78, 0.60, 0.28),
		"emblem": false,
	}


## Completa un tema parcial (por ejemplo de data/tower.json, con colores en listas
## [r, g, b]) con los valores por defecto y convierte las listas en Color.
static func make_theme(partial: Dictionary) -> Dictionary:
	var theme := default_theme()
	for key: String in partial:
		var value: Variant = partial[key]
		if value is Array and (value as Array).size() >= 3:
			var color: Array = value
			theme[key] = Color(float(color[0]), float(color[1]), float(color[2]), float(color[3]) if color.size() > 3 else 1.0)
		else:
			theme[key] = value
	return theme


## Volcado a diccionario (tests de determinismo y depuracion).
func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"size": [size.x, size.y],
		"bounds": [bounds().position.x, bounds().position.y, bounds().size.x, bounds().size.y],
		"floor": floor_number,
		"tier": tier,
		"scale": enemy_scale,
		"spawn": [player_spawn.x, player_spawn.y],
		"obstacles": obstacles.map(func(o: Dictionary) -> Array: return [o["position"].x, o["position"].y, o["radius"]]),
		"enemies": enemies.map(func(e: Dictionary) -> Array: return [String(e["id"]), e["position"].x, e["position"].y, bool(e.get("required", true))]),
		"resources": resources.map(func(r: Dictionary) -> Array: return [String(r["kind"]), r["position"].x, r["position"].y]),
		"portals": portals.map(func(p: Dictionary) -> Array: return [String(p["id"]), p["position"].x, p["position"].y, String(p["action"])]),
		"objective": objective,
	}
