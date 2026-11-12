## MapAnalysis — un mapa generado (TileGrid) con lo que hace falta para colocar
## contenido sobre el: entrada, salida, distancia de camino desde la entrada y holgura
## de cada casilla.
##
## `pick_spot()` es la pieza clave de los generadores: elige un punto alcanzable, con
## holgura suficiente, a cierta fraccion del camino entre entrada y salida (0 = la
## entrada, 1 = lo mas lejano) y lejos de lo ya colocado. Todo lo que se coloca asi es
## alcanzable por construccion, que es lo que garantiza que una mision se pueda cumplir.
class_name MapAnalysis
extends RefCounted

var grid: TileGrid
var spawn: Vector2i
var exit: Vector2i
## Distancia de camino (casillas) desde la entrada; -1 = inaccesible.
var dist: PackedInt32Array
var max_dist: int = 1
## Distancia chebyshev a la casilla bloqueada mas cercana (tope 9).
var clearance: PackedByteArray
## Casillas libres alcanzables.
var reach: Array[Vector2i] = []


func _init(p_grid: TileGrid, p_spawn: Vector2i) -> void:
	grid = p_grid
	spawn = p_spawn
	refresh()


## Recalcula distancias, holgura y casillas alcanzables (tras cambiar el mapa).
func refresh() -> void:
	dist = grid.distance_field(spawn, 100000)
	max_dist = 1
	reach = []
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			var value := dist[r * grid.cols + c]
			if value >= 0:
				reach.append(Vector2i(c, r))
				max_dist = maxi(max_dist, value)
	clearance = _compute_clearance()


func _compute_clearance() -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(grid.cols * grid.rows)
	var queue: Array[Vector2i] = []
	var seen := PackedByteArray()
	seen.resize(grid.cols * grid.rows)
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if grid.blocks_move(c, r):
				seen[r * grid.cols + c] = 1
				queue.append(Vector2i(c, r))
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var here := out[cell.y * grid.cols + cell.x]
		if here >= 9:
			continue
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var nc := cell.x + dx
				var nr := cell.y + dy
				if not grid.in_bounds(nc, nr) or seen[nr * grid.cols + nc] == 1:
					continue
				seen[nr * grid.cols + nc] = 1
				out[nr * grid.cols + nc] = here + 1
				queue.append(Vector2i(nc, nr))
	for i: int in range(out.size()):
		if seen[i] == 0:
			out[i] = 9
	return out


func path_fraction(cell: Vector2i) -> float:
	var value := dist[cell.y * grid.cols + cell.x]
	return 0.0 if value < 0 else float(value) / float(max_dist)


func clearance_at(cell: Vector2i) -> int:
	return clearance[cell.y * grid.cols + cell.x]


func cell_center(cell: Vector2i) -> Vector2:
	return grid.cell_center(cell.x, cell.y)


func spawn_position() -> Vector2:
	return cell_center(spawn)


func exit_position() -> Vector2:
	return cell_center(exit)


## Un punto alcanzable con holgura >= `min_clear` casillas, a una fraccion del camino
## entre `t_min` y `t_max`, a mas de `avoid_distance` px de cada punto de `avoid`.
## Si no hay ninguno que cumpla, relaja primero la separacion y luego el tramo; null
## solo si el mapa no tiene ninguna casilla con esa holgura.
func pick_spot(rng: RandomNumberGenerator, t_min: float, t_max: float, min_clear: int, avoid: Array, avoid_distance: float) -> Variant:
	for relax: int in range(4):
		var spacing := avoid_distance * (1.0 - 0.35 * float(relax))
		var lo := maxf(0.0, t_min - 0.15 * float(maxi(relax - 1, 0)))
		var hi := minf(1.0, t_max + 0.15 * float(maxi(relax - 1, 0)))
		var candidates: Array[Vector2i] = []
		for cell: Vector2i in reach:
			var fraction := path_fraction(cell)
			if fraction < lo or fraction > hi or clearance_at(cell) < min_clear:
				continue
			candidates.append(cell)
		if candidates.is_empty():
			continue
		for attempt: int in range(40):
			var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
			var point := cell_center(cell)
			var ok := true
			for other: Variant in avoid:
				if point.distance_to(other as Vector2) < spacing:
					ok = false
					break
			if ok:
				return point
	return null


## Casilla cuyo centro esta mas cerca de `point`.
func cell_at(point: Vector2) -> Vector2i:
	return grid.world_to_cell(point)
