## TileGrid — mapa de casillas de un escenario grande (muros, agua, puertas) para la
## simulacion: colision de circulos, tiros, linea de vision y campo de flujo para que
## los enemigos rodeen los muros.
##
## Es solo datos y geometria determinista (sin RNG ni tiempo). La generan `MapGen`
## (pisos) y `Layouts` (ciudad); `CombatWorld` la consulta al mover unidades y
## proyectiles; `Arena` la dibuja con el tileset.
class_name TileGrid
extends RefCounted

const TILE := 32.0
## Tipos de casilla.
const FLOOR := 0
const WALL := 1      # bloquea el paso y los tiros
const WATER := 2     # bloquea el paso, no los tiros
const GATE := 3      # puerta cerrada: bloquea el paso y los tiros (se abre con una condicion)
const ROAD := 4      # suelo transitable que se dibuja como adoquin (ciudad)
const SOLID := 5     # bloque invisible (edificios, fuentes): bloquea paso y tiros, se dibuja como suelo

var cols: int
var rows: int
var cells: PackedByteArray
## Sube cada vez que cambia una casilla (invalida la cache del campo de flujo).
var version: int = 0


func _init(p_cols: int, p_rows: int, fill: int = WALL) -> void:
	cols = p_cols
	rows = p_rows
	cells = PackedByteArray()
	cells.resize(cols * rows)
	cells.fill(fill)


func in_bounds(c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < cols and r < rows


func get_cell(c: int, r: int) -> int:
	if not in_bounds(c, r):
		return WALL
	return cells[r * cols + c]


func set_cell(c: int, r: int, kind: int) -> void:
	if in_bounds(c, r) and cells[r * cols + c] != kind:
		cells[r * cols + c] = kind
		version += 1


func pixel_size() -> Vector2:
	return Vector2(float(cols), float(rows)) * TILE


func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(int(floor(point.x / TILE)), int(floor(point.y / TILE)))


func cell_center(c: int, r: int) -> Vector2:
	return Vector2((float(c) + 0.5) * TILE, (float(r) + 0.5) * TILE)


func blocks_move(c: int, r: int) -> bool:
	var kind := get_cell(c, r)
	return kind != FLOOR and kind != ROAD


func blocks_shot(c: int, r: int) -> bool:
	var kind := get_cell(c, r)
	return kind == WALL or kind == GATE or kind == SOLID


## Holgura extra (px) contra las casillas WALL: la copa de los arboles de los muros sobresale de su casilla,
## asi que el centro de un personaje no se acerca a ellos tanto como a otros obstaculos.
var wall_margin: float = 0.0
## Al norte de un muro (donde la copa se alza sobre el suelo) la holgura es mayor: el personaje queda lejos del follaje.
const NORTH_MARGIN_FACTOR := 1.4


func is_walkable_point(point: Vector2) -> bool:
	var cell := world_to_cell(point)
	return not blocks_move(cell.x, cell.y)


## Saca un circulo de las casillas que bloquean el paso (desliza por las paredes).
func push_out(position: Vector2, radius: float) -> Vector2:
	var pos := position
	var base_radius := radius
	for pass_index: int in range(2):
		var cell := world_to_cell(pos)
		var span := int(ceil((base_radius + wall_margin * NORTH_MARGIN_FACTOR) / TILE)) + 1
		for r: int in range(cell.y - span, cell.y + span + 1):
			for c: int in range(cell.x - span, cell.x + span + 1):
				if not blocks_move(c, r):
					continue
				var rect_min := Vector2(float(c), float(r)) * TILE
				radius = base_radius
				if get_cell(c, r) == WALL:
					radius += wall_margin * (NORTH_MARGIN_FACTOR if pos.y < rect_min.y else 1.0)
				var nearest := Vector2(clampf(pos.x, rect_min.x, rect_min.x + TILE), clampf(pos.y, rect_min.y, rect_min.y + TILE))
				var diff := pos - nearest
				var dist_sq := diff.length_squared()
				if dist_sq >= radius * radius:
					continue
				if dist_sq < 0.0001:
					# Centro dentro de la casilla: sale por el lado libre mas cercano.
					var sides := [
						[pos.x - rect_min.x, Vector2i(c - 1, r), Vector2(rect_min.x - radius, pos.y)],
						[rect_min.x + TILE - pos.x, Vector2i(c + 1, r), Vector2(rect_min.x + TILE + radius, pos.y)],
						[pos.y - rect_min.y, Vector2i(c, r - 1), Vector2(pos.x, rect_min.y - radius)],
						[rect_min.y + TILE - pos.y, Vector2i(c, r + 1), Vector2(pos.x, rect_min.y + TILE + radius)],
					]
					var best_distance := INF
					var best_exit := pos
					for side: Array in sides:
						var neighbor: Vector2i = side[1]
						if blocks_move(neighbor.x, neighbor.y):
							continue
						if float(side[0]) < best_distance:
							best_distance = float(side[0])
							best_exit = side[2]
					pos = best_exit
				else:
					# Contacto con una esquina: si una casilla vecina que comparte esa
					# arista tambien es muro, su cara plana ya se encarga (evita que
					# las juntas de un muro recto empujen en diagonal).
					if absf(diff.x) > 0.0001 and absf(diff.y) > 0.0001:
						var side_x := -1 if pos.x < rect_min.x else 1
						var side_y := -1 if pos.y < rect_min.y else 1
						if blocks_move(c + side_x, r) or blocks_move(c, r + side_y):
							continue
					pos = nearest + diff / sqrt(dist_sq) * radius
	return pos


## Si un circulo (proyectil) toca una casilla que bloquea tiros.
func shot_blocked(position: Vector2, radius: float) -> bool:
	var cell := world_to_cell(position)
	var span := int(ceil(radius / TILE))
	for r: int in range(cell.y - span, cell.y + span + 1):
		for c: int in range(cell.x - span, cell.x + span + 1):
			if not blocks_shot(c, r):
				continue
			var rect_min := Vector2(float(c), float(r)) * TILE
			var nearest := Vector2(clampf(position.x, rect_min.x, rect_min.x + TILE), clampf(position.y, rect_min.y, rect_min.y + TILE))
			if position.distance_squared_to(nearest) < radius * radius:
				return true
	return false


## Linea de vision / paso libre entre dos puntos (muestrea cada medio TILE).
func line_clear(a: Vector2, b: Vector2) -> bool:
	var distance := a.distance_to(b)
	var steps := int(ceil(distance / (TILE * 0.5)))
	for i: int in range(steps + 1):
		var point := a.lerp(b, float(i) / float(maxi(steps, 1)))
		var cell := world_to_cell(point)
		if blocks_move(cell.x, cell.y):
			return false
	return true


## Distancia en casillas desde `target` por casillas libres (BFS de 8 vecinos sin
## cortar esquinas). -1 = fuera de alcance o inaccesible. `max_distance` acota el coste.
func distance_field(target: Vector2i, max_distance: int = 70) -> PackedInt32Array:
	var field := PackedInt32Array()
	field.resize(cols * rows)
	field.fill(-1)
	if not in_bounds(target.x, target.y) or blocks_move(target.x, target.y):
		return field
	var queue: Array[Vector2i] = [target]
	field[target.y * cols + target.x] = 0
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var here := field[cell.y * cols + cell.x]
		if here >= max_distance:
			continue
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nc := cell.x + dx
				var nr := cell.y + dy
				if blocks_move(nc, nr) or field[nr * cols + nc] != -1:
					continue
				if dx != 0 and dy != 0 and (blocks_move(cell.x + dx, cell.y) or blocks_move(cell.x, cell.y + dy)):
					continue
				field[nr * cols + nc] = here + 1
				queue.append(Vector2i(nc, nr))
	return field


## Direccion (unitaria) para bajar por el campo desde `position`; ZERO si ya esta en el
## objetivo o fuera del campo.
func flow_direction(field: PackedInt32Array, position: Vector2) -> Vector2:
	var cell := world_to_cell(position)
	if not in_bounds(cell.x, cell.y):
		return Vector2.ZERO
	var here := field[cell.y * cols + cell.x]
	if here <= 0:
		return Vector2.ZERO
	var best := here
	var best_cell := cell
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nc := cell.x + dx
			var nr := cell.y + dy
			if not in_bounds(nc, nr):
				continue
			var value := field[nr * cols + nc]
			if value < 0 or value >= best:
				continue
			if dx != 0 and dy != 0 and (blocks_move(cell.x + dx, cell.y) or blocks_move(cell.x, cell.y + dy)):
				continue
			best = value
			best_cell = Vector2i(nc, nr)
	if best_cell == cell:
		return Vector2.ZERO
	var goal := cell_center(best_cell.x, best_cell.y)
	return (goal - position).normalized()


## Casillas libres alcanzables desde `start` (flood fill de 4 vecinos). Sirve para
## comprobar la conectividad de un mapa generado.
func reachable_from(start: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(cols * rows)
	if not in_bounds(start.x, start.y) or blocks_move(start.x, start.y):
		return seen
	var stack: Array[Vector2i] = [start]
	seen[start.y * cols + start.x] = 1
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := cell + offset
			if blocks_move(n.x, n.y) or seen[n.y * cols + n.x] == 1:
				continue
			seen[n.y * cols + n.x] = 1
			stack.append(n)
	return seen


func count_of(kind: int) -> int:
	var total := 0
	for value: int in cells:
		if value == kind:
			total += 1
	return total
