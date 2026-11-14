## AuthoredFloor — pisos hechos a mano (data/floors/floor_NN.txt + floor_NN.json).
##
## El .txt es el MAPA: una linea por fila y un caracter por casilla (32 px):
##     .  suelo (hierba)        =  camino / puente (suelo transitable que se dibuja como camino)
##     ~  agua (rio, lago)      #  muro (bosque denso, risco, muralla)
##     S  entrada del jugador   X  salida (suelo, marcadas aparte)
## El .json lleva los PUNTOS DE DISENO (`anchors`: clave -> lista de [columna, fila]) y decorado (`props`). Un ancla
## sustituye al sorteo de posiciones del generador de contenido (MissionGen): campamentos (`camp`, `pack`), aldea
## (`village`), misiones (`waypoint`, `nest`, `altar`, `cage`, `hunt`, `beacon`, `relic`, `relic_altar`, `boss`...),
## cofres, notas, eventos, alijos de heroes (`cache_<id>`), peligros (`hazard_<tipo>`)... Si una clave tiene varios
## candidatos, cada visita elige uno (variacion ligera); sin ancla, el generador sortea como siempre.
## El generador procedural NO se toca: un piso sin archivo en data/floors/ sigue siendo procedural.
class_name AuthoredFloor
extends RefCounted

const DIR := "res://data/floors/"
const TILES := {".": TileGrid.FLOOR, "=": TileGrid.ROAD, "~": TileGrid.WATER, "#": TileGrid.WALL, "S": TileGrid.FLOOR, "X": TileGrid.FLOOR}

## Pruebas: false = ignora los pisos a mano (todos procedurales).
static var enabled: bool = true
static var _meta_cache: Dictionary = {}


static func has(floor_number: int) -> bool:
	return enabled and FileAccess.file_exists(DIR + "floor_%02d.txt" % floor_number)


static func meta(floor_number: int) -> Dictionary:
	if _meta_cache.has(floor_number):
		return _meta_cache[floor_number]
	var path := DIR + "floor_%02d.json" % floor_number
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	var out: Dictionary = parsed if parsed is Dictionary else {}
	_meta_cache[floor_number] = out
	return out


## Lee el mapa y devuelve su analisis (rejilla, entrada y salida).
static func build(floor_number: int) -> MapAnalysis:
	var lines: Array[String] = []
	for line: String in FileAccess.get_file_as_string(DIR + "floor_%02d.txt" % floor_number).split("\n"):
		var trimmed := line.strip_edges(false, true)
		if not trimmed.is_empty():
			lines.append(trimmed)
	var rows := lines.size()
	var cols := 0
	for line: String in lines:
		cols = maxi(cols, line.length())
	var grid := TileGrid.new(cols, rows, TileGrid.WALL)
	var spawn := Vector2i(-1, -1)
	var exit := Vector2i(-1, -1)
	for r: int in range(rows):
		var line := lines[r]
		for c: int in range(line.length()):
			var ch := line.substr(c, 1)
			if TILES.has(ch):
				grid.set_cell(c, r, int(TILES[ch]))
			if ch == "S":
				spawn = Vector2i(c, r)
			elif ch == "X":
				exit = Vector2i(c, r)
	var analysis := MapAnalysis.new(grid, spawn)
	analysis.exit = exit
	analysis.refresh()
	return analysis


## Anclas en coordenadas de mundo (centro de casilla): clave -> Array de Vector2.
static func anchors(floor_number: int, grid: TileGrid) -> Dictionary:
	var out: Dictionary = {}
	var raw: Dictionary = meta(floor_number).get("anchors", {})
	for key: String in raw:
		var points: Array = []
		for cell: Variant in raw[key]:
			var pair: Array = cell
			points.append(grid.cell_center(int(pair[0]), int(pair[1])))
		out[key] = points
	return out


## Decorado fijo del piso (props de campamento, torres, empalizadas...) en coordenadas de mundo.
static func props(floor_number: int, grid: TileGrid) -> Array:
	var out: Array = []
	for entry: Variant in meta(floor_number).get("props", []):
		var prop: Dictionary = entry
		var at: Array = prop["at"]
		out.append({"kind": String(prop["kind"]), "position": grid.cell_center(int(at[0]), int(at[1])) + Vector2(0.0, 12.0), "variant": int(prop.get("variant", 0))})
	return out
