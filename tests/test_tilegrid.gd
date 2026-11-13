## Mapa de casillas: colision de circulos, tiros, linea de vision, campo de flujo,
## conectividad, y su integracion en la simulacion (jugador, proyectiles, enemigos
## que rodean muros, puertas).
##
##   godot --headless --path . --script tests/test_tilegrid.gd
extends SceneTree

const CombatWorldScript: GDScript = preload("res://game/sim/combat_world.gd")
const DT: float = 1.0 / 60.0

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_tilegrid (mapa de casillas) ==")
	_test_basics()
	_test_push_out()
	_test_shots_and_sight()
	_test_flow_and_reachability()
	_test_player_collision()
	_test_projectiles()
	_test_enemy_paths_around_walls()
	_test_gate()
	_test_tree_wall_margin()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


## Sala de 20x12 con un muro vertical en la columna 10 (hueco abajo, filas 9-10).
func _walled_room() -> TileGrid:
	var grid := TileGrid.new(20, 12, TileGrid.WALL)
	for r: int in range(1, 11):
		for c: int in range(1, 19):
			grid.set_cell(c, r, TileGrid.FLOOR)
	for r: int in range(1, 9):
		grid.set_cell(10, r, TileGrid.WALL)
	return grid


func _world(grid: TileGrid) -> CombatWorld:
	var world: CombatWorld = CombatWorldScript.new(3)
	world.setup_arena(Rect2(Vector2.ZERO, grid.pixel_size()), [], grid)
	return world


func _test_basics() -> void:
	var grid := TileGrid.new(10, 8, TileGrid.FLOOR)
	_check(grid.pixel_size() == Vector2(320, 256) and grid.world_to_cell(Vector2(70, 40)) == Vector2i(2, 1), "tamano y conversion de casillas")
	_check(grid.get_cell(-1, 0) == TileGrid.WALL and grid.get_cell(10, 0) == TileGrid.WALL, "fuera del mapa cuenta como muro")
	var before := grid.version
	grid.set_cell(3, 3, TileGrid.WATER)
	grid.set_cell(3, 3, TileGrid.WATER)
	_check(grid.version == before + 1 and grid.blocks_move(3, 3) and not grid.blocks_shot(3, 3), "el agua bloquea el paso pero no los tiros")
	grid.set_cell(4, 4, TileGrid.GATE)
	_check(grid.blocks_move(4, 4) and grid.blocks_shot(4, 4), "la puerta cerrada bloquea paso y tiros")
	_check(grid.count_of(TileGrid.WATER) == 1 and grid.is_walkable_point(Vector2(16, 16)) and not grid.is_walkable_point(Vector2(112, 112)), "conteo y puntos caminables")


func _test_push_out() -> void:
	var grid := _walled_room()
	var inside := grid.push_out(Vector2(100, 100), 14.0)
	_check(inside == Vector2(100, 100), "en suelo libre no se mueve")
	var near_wall := grid.push_out(Vector2(10 * 32 - 5, 100), 14.0)
	_check(near_wall.x <= 10 * 32 - 14.0 + 0.01 and absf(near_wall.y - 100.0) < 0.01, "se separa de un muro y conserva la otra coordenada (desliza)")
	var in_wall := grid.push_out(Vector2(10 * 32 + 16, 100), 14.0)
	_check(not grid.blocks_move(grid.world_to_cell(in_wall).x, grid.world_to_cell(in_wall).y), "si el centro esta dentro de un muro sale por el lado mas cercano")
	var corner := grid.push_out(Vector2(10 * 32 - 3, 9 * 32 - 3), 14.0)
	_check(corner.distance_to(Vector2(10 * 32 - 3, 9 * 32 - 3)) > 0.0 and not _circle_overlaps_wall(grid, corner, 13.9), "una esquina tambien lo separa")
	var squeezed := grid.push_out(Vector2(1 * 32 + 1, 100), 14.0)
	_check(squeezed.x >= 32.0 + 14.0 - 0.01, "el borde exterior del mapa tambien bloquea")


func _circle_overlaps_wall(grid: TileGrid, position: Vector2, radius: float) -> bool:
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if not grid.blocks_move(c, r):
				continue
			var rect_min := Vector2(float(c), float(r)) * TileGrid.TILE
			var nearest := Vector2(clampf(position.x, rect_min.x, rect_min.x + TileGrid.TILE), clampf(position.y, rect_min.y, rect_min.y + TileGrid.TILE))
			if position.distance_to(nearest) < radius:
				return true
	return false


func _test_shots_and_sight() -> void:
	var grid := _walled_room()
	_check(grid.shot_blocked(Vector2(10 * 32 + 16, 100), 5.0) and not grid.shot_blocked(Vector2(100, 100), 5.0), "los tiros chocan con muros")
	_check(grid.line_clear(Vector2(100, 100), Vector2(250, 100)) and not grid.line_clear(Vector2(100, 100), Vector2(500, 100)), "linea de vision libre y cortada por el muro")
	_check(grid.line_clear(Vector2(100, 330), Vector2(500, 330)), "se ve a traves del hueco del muro")


func _test_flow_and_reachability() -> void:
	var grid := _walled_room()
	var field := grid.distance_field(Vector2i(15, 3))
	_check(field[3 * grid.cols + 15] == 0 and field[3 * grid.cols + 5] > 12, "el camino al otro lado del muro es largo (rodea por el hueco)")
	_check(field[9 * grid.cols + 10] > 0 and field[0] == -1, "las casillas de muro no tienen distancia")
	var position := Vector2(5 * 32 + 16, 3 * 32 + 16)
	var steps := 0
	while steps < 300:
		var direction := grid.flow_direction(field, position)
		if direction == Vector2.ZERO:
			break
		position += direction * 8.0
		position = grid.push_out(position, 10.0)
		steps += 1
	_check(position.distance_to(Vector2(15 * 32 + 16, 3 * 32 + 16)) < 40.0 and steps < 200, "seguir el campo lleva al objetivo rodeando el muro")
	var seen := grid.reachable_from(Vector2i(2, 2))
	_check(seen[3 * grid.cols + 17] == 1 and seen[5 * grid.cols + 10] == 0, "flood fill: se llega al otro lado, no a los muros")
	var split := _walled_room()
	split.set_cell(10, 9, TileGrid.WALL)
	split.set_cell(10, 10, TileGrid.WALL)
	var seen_split := split.reachable_from(Vector2i(2, 2))
	_check(seen_split[3 * split.cols + 17] == 0, "tapar el hueco deja el otro lado inaccesible")
	_check(split.distance_field(Vector2i(15, 3))[3 * split.cols + 5] == -1, "y el campo de flujo lo marca inaccesible")
	var limited := _walled_room().distance_field(Vector2i(2, 2), 4)
	_check(limited[2 * 20 + 7] == -1 and limited[2 * 20 + 6] == 4, "el campo respeta su alcance maximo")


func _test_player_collision() -> void:
	var world := _world(_walled_room())
	world.player.position = Vector2(9 * 32, 100)
	var move := InputMessage.new()
	move.move_dir = Vector2.RIGHT
	for i: int in range(120):
		world.submit_input(move)
		world.step(DT)
	_check(world.player.position.x < 10 * 32 - 13.0 and world.player.position.x > 9 * 32, "el jugador no atraviesa un muro")
	world.player.position = Vector2(9 * 32, 100)
	var diagonal := InputMessage.new()
	diagonal.move_dir = Vector2(1, 1).normalized()
	for i: int in range(40):
		world.submit_input(diagonal)
		world.step(DT)
	_check(world.player.position.y > 130.0, "contra un muro en diagonal desliza a lo largo")
	world.player.position = Vector2(9 * 32, 9.5 * 32)
	for i: int in range(120):
		world.submit_input(move)
		world.step(DT)
	_check(world.player.position.x > 12 * 32, "por el hueco si pasa")


func _test_projectiles() -> void:
	var world := _world(_walled_room())
	world.player.position = Vector2(2 * 32, 9 * 32)
	var wall_hit := ProjectileSim.hostile_from_attack(world.player, {"projectile": {"speed": 400.0, "range": 600.0, "radius": 6.0, "pierce": 0, "visual": "spit"}}, Vector2.RIGHT, Vector2(5 * 32, 100), 1.0)
	var alive_ticks := 0
	world.spawn_projectile(wall_hit)
	for i: int in range(120):
		world.step(DT)
		if wall_hit.alive:
			alive_ticks += 1
	_check(not wall_hit.alive and wall_hit.position.x < 10 * 32 + 8.0, "un proyectil muere contra un muro")
	var grid := _walled_room()
	grid.set_cell(10, 3, TileGrid.WATER)
	var water_world := _world(grid)
	water_world.player.position = Vector2(2 * 32, 9 * 32)
	var over_water := ProjectileSim.hostile_from_attack(water_world.player, {"projectile": {"speed": 400.0, "range": 90.0, "radius": 6.0, "pierce": 0, "visual": "spit"}}, Vector2.RIGHT, Vector2(9 * 32 + 10, 3 * 32 + 16), 1.0)
	water_world.spawn_projectile(over_water)
	for i: int in range(20):
		water_world.step(DT)
	_check(over_water.travelled > 60.0, "un proyectil cruza el agua")


func _test_enemy_paths_around_walls() -> void:
	var world := _world(_walled_room())
	world.player.position = Vector2(15 * 32, 3 * 32 + 16)
	var enemy := world.add_enemy(&"slime", Vector2(4 * 32, 3 * 32 + 16))
	_check(not world.line_of_sight(enemy.position, world.player.position), "el muro corta la vista entre el enemigo y el jugador")
	for i: int in range(60 * 6):
		world.step(DT)
	_check(enemy.state == EnemySim.State.IDLE and enemy.position.distance_to(Vector2(4 * 32, 3 * 32 + 16)) < 1.0, "sin linea de vision el enemigo no detecta al jugador")
	# Una vez en combate, rodea el muro para alcanzarlo.
	var chaser := world.add_enemy(&"slime", Vector2(8 * 32, 3 * 32 + 16))
	chaser.state = EnemySim.State.CHASE
	var reached := false
	for i: int in range(60 * 14):
		world.player.position = Vector2(15 * 32, 3 * 32 + 16)
		world.step(DT)
		if chaser.position.distance_to(world.player.position) < 60.0:
			reached = true
			break
	_check(reached and chaser.position.x > 10 * 32, "un enemigo en persecucion rodea el muro hasta el jugador")
	var always_blocked := true
	for i: int in range(60):
		world.step(DT)
		if chaser.position.x > 9 * 32 and chaser.position.x < 11 * 32 and chaser.position.y < 8 * 32:
			always_blocked = false
	_check(always_blocked, "los enemigos nunca estan dentro del muro")


func _test_gate() -> void:
	var grid := _walled_room()
	grid.set_cell(10, 9, TileGrid.GATE)
	grid.set_cell(10, 10, TileGrid.GATE)
	var world := _world(grid)
	world.player.position = Vector2(15 * 32, 3 * 32 + 16)
	var slime := world.add_enemy(&"slime", Vector2(8 * 32, 3 * 32 + 16))
	slime.state = EnemySim.State.CHASE
	for i: int in range(60 * 3):
		world.player.position = Vector2(15 * 32, 3 * 32 + 16)
		world.step(DT)
	_check(slime.position.x < 10 * 32, "con la puerta cerrada no hay camino")
	grid.set_cell(10, 9, TileGrid.FLOOR)
	grid.set_cell(10, 10, TileGrid.FLOOR)
	var crossed := false
	for i: int in range(60 * 12):
		world.player.position = Vector2(15 * 32, 3 * 32 + 16)
		world.step(DT)
		if slime.position.x > 11 * 32:
			crossed = true
			break
	_check(crossed, "al abrir la puerta el campo de flujo se recalcula y el enemigo pasa")


## Los muros de arboles tienen holgura extra (la copa sobresale de la casilla): el personaje no se mete bajo ella,
## pero los pasillos de 3 casillas siguen siendo transitables de punta a punta.
func _test_tree_wall_margin() -> void:
	var grid := _walled_room()
	var near_wall := Vector2(52.0, 5.0 * 32.0)
	var plain := grid.push_out(near_wall, 14.0)
	grid.wall_margin = 20.0
	var padded := grid.push_out(near_wall, 14.0)
	_check(padded.x > plain.x + 10.0, "con holgura el personaje se queda mas lejos del muro de arboles (%.0f vs %.0f)" % [padded.x, plain.x])
	_check(TowerCatalog.biome_wall_margin("forest") > 0.0 and TowerCatalog.biome_wall_margin("cave") == 0.0, "el bosque lleva holgura y las cuevas (cliffs) no")
	var layout := TowerGenerator.generate(3, 20261110, 1)
	_check(layout.wall_margin > 0.0, "los pisos del bosque llevan la holgura en su layout")
	# Los pasillos siguen siendo transitables: un circulo del tamano del jugador mas la holgura (la mayor, al norte
	# de un muro) conecta la entrada con la salida en varios pisos (erosion de casillas por su distancia a los muros).
	var connected := 0
	var tried := 0
	for floor_number: int in [1, 2, 4, 6, 8, 9]:
		for world_seed: int in [20261110, 777]:
			tried += 1
			var floor_layout := TowerGenerator.generate(floor_number, world_seed, 1)
			var floor_grid := floor_layout.grid
			var radius := PlayerSim.RADIUS + floor_layout.wall_margin * 1.0
			var exit_point: Vector2 = (floor_layout.portals.filter(func(p: Dictionary) -> bool: return String(p["id"]) == "exit")[0] as Dictionary)["position"]
			var open := PackedByteArray()
			open.resize(floor_grid.cols * floor_grid.rows)
			for r: int in range(floor_grid.rows):
				for c: int in range(floor_grid.cols):
					var center := floor_grid.cell_center(c, r)
					var free := not floor_grid.blocks_move(c, r)
					for dr: int in range(-2, 3):
						for dc: int in range(-2, 3):
							if free and floor_grid.get_cell(c + dc, r + dr) == TileGrid.WALL:
								var rect_min := Vector2(float(c + dc), float(r + dr)) * 32.0
								var nearest := Vector2(clampf(center.x, rect_min.x, rect_min.x + 32.0), clampf(center.y, rect_min.y, rect_min.y + 32.0))
								if center.distance_to(nearest) < radius:
									free = false
					open[r * floor_grid.cols + c] = 1 if free else 0
			# Arranca en la casilla abierta mas cercana a la entrada y busca la mas cercana a la salida.
			var start := _nearest_open(floor_grid, open, floor_layout.player_spawn)
			var goal := _nearest_open(floor_grid, open, exit_point)
			var seen := PackedByteArray()
			seen.resize(floor_grid.cols * floor_grid.rows)
			var queue: Array[Vector2i] = [start]
			seen[start.y * floor_grid.cols + start.x] = 1
			while not queue.is_empty():
				var current: Vector2i = queue.pop_back()
				for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var next := current + offset
					if floor_grid.in_bounds(next.x, next.y) and open[next.y * floor_grid.cols + next.x] == 1 and seen[next.y * floor_grid.cols + next.x] == 0:
						seen[next.y * floor_grid.cols + next.x] = 1
						queue.append(next)
			var ok := seen[goal.y * floor_grid.cols + goal.x] == 1
			connected += 1 if ok else 0
			if not ok:
				print("   piso %d semilla %d: inicio %s (a %.0f px), meta %s (a %.0f px)" % [floor_number, world_seed, str(start), floor_grid.cell_center(start.x, start.y).distance_to(floor_layout.player_spawn), str(goal), floor_grid.cell_center(goal.x, goal.y).distance_to(exit_point)])
	_check(connected == tried, "con la holgura elegida por el generador un circulo del jugador conecta la entrada con la salida (%d de %d pisos)" % [connected, tried])


func _nearest_open(grid: TileGrid, open: PackedByteArray, point: Vector2) -> Vector2i:
	var best := Vector2i.ZERO
	var best_distance := INF
	for r: int in range(grid.rows):
		for c: int in range(grid.cols):
			if open[r * grid.cols + c] == 1:
				var distance := grid.cell_center(c, r).distance_to(point)
				if distance < best_distance:
					best_distance = distance
					best = Vector2i(c, r)
	return best


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
