## Generacion de mapas grandes: los cuatro estilos son conexos, anchos, deterministas, con
## la salida lejos de la entrada, y `pick_spot` solo da puntos alcanzables.
##
##   godot --headless --path . --script tests/test_mapgen.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run() -> void:
	print("== test_mapgen (mapas grandes) ==")
	_test_sizes()
	_test_styles()
	_test_determinism()
	_test_pick_spot()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_sizes() -> void:
	var small_ok := true
	var large_ok := true
	for seed_value: int in range(20):
		for floor_number: int in [1, 2, 3]:
			var size := MapGen.map_size(floor_number, _rng(seed_value))
			if size.x < 64 or size.x > 72 or size.y < 48 or size.y > 56:
				small_ok = false
		for floor_number: int in [4, 15, 40, 100]:
			var size := MapGen.map_size(floor_number, _rng(seed_value))
			if size.x < 84 or size.y < 64:
				large_ok = false
	_check(small_ok, "los tres primeros pisos son medianos (64-72 x 48-56 casillas)")
	_check(large_ok, "del 4 en adelante son grandes (>= 84 x 64)")
	var growth := MapGen.map_size(100, _rng(1)).x * MapGen.map_size(100, _rng(1)).y > MapGen.map_size(4, _rng(1)).x * MapGen.map_size(4, _rng(1)).y * 1.4
	_check(growth, "los pisos de los ultimos tiers son bastante mayores que los primeros")
	var big := MapGen.map_size(100, _rng(2))
	_check(big.x * 32 >= 3500, "un piso del tier 10 mide mas de 3500 px de ancho")


func _min_width_ok(grid: TileGrid) -> bool:
	# Cada casilla libre debe pertenecer a algun bloque libre de 3x3 (salvo el borde).
	for r: int in range(1, grid.rows - 1):
		for c: int in range(1, grid.cols - 1):
			if grid.get_cell(c, r) != TileGrid.FLOOR:
				continue
			var covered := false
			for oy: int in range(-1, 2):
				for ox: int in range(-1, 2):
					var all_floor := true
					for dy: int in range(-1, 2):
						for dx: int in range(-1, 2):
							if grid.get_cell(c + ox + dx, r + oy + dy) != TileGrid.FLOOR:
								all_floor = false
					if all_floor:
						covered = true
			if not covered:
				return false
	return true


func _test_styles() -> void:
	for style: String in MapGen.STYLES:
		var all_connected := true
		var wide := true
		var exit_far := true
		var open_enough := true
		var started := Time.get_ticks_msec()
		for seed_value: int in range(4):
			var rng := _rng(100 + seed_value)
			var size := Vector2i(80, 60)
			var analysis := MapGen.build(style, size.x, size.y, rng)
			var grid := analysis.grid
			var seen := grid.reachable_from(analysis.spawn)
			for r: int in range(grid.rows):
				for c: int in range(grid.cols):
					if grid.get_cell(c, r) == TileGrid.FLOOR and seen[r * grid.cols + c] == 0:
						all_connected = false
			if not _min_width_ok(grid):
				wide = false
			var path := analysis.dist[analysis.exit.y * grid.cols + analysis.exit.x]
			if path < int(float(maxi(size.x, size.y)) * 0.55):
				exit_far = false
			var floor_cells := grid.cols * grid.rows - grid.count_of(TileGrid.WALL) - grid.count_of(TileGrid.WATER)
			if float(floor_cells) / float(grid.cols * grid.rows) < 0.25:
				open_enough = false
		var elapsed := Time.get_ticks_msec() - started
		_check(all_connected, "%s: todo el suelo es alcanzable desde la entrada" % style)
		_check(wide, "%s: ningun pasillo mas estrecho que 3 casillas" % style)
		_check(exit_far, "%s: la salida esta lejos de la entrada" % style)
		_check(open_enough, "%s: al menos el 25 %% del mapa es transitable" % style)
		_check(elapsed < 12000, "%s: genera 4 mapas de 80x60 en %d ms" % [style, elapsed])


func _test_determinism() -> void:
	var a := MapGen.build("mixed", 72, 56, _rng(77))
	var b := MapGen.build("mixed", 72, 56, _rng(77))
	var c := MapGen.build("mixed", 72, 56, _rng(78))
	_check(a.grid.cells == b.grid.cells and a.spawn == b.spawn and a.exit == b.exit, "misma semilla, mismo mapa")
	_check(a.grid.cells != c.grid.cells, "otra semilla, otro mapa")


func _test_pick_spot() -> void:
	var analysis := MapGen.build("field", 80, 60, _rng(5))
	var rng := _rng(9)
	var placed: Array = []
	var ok := true
	for i: int in range(40):
		var spot: Variant = analysis.pick_spot(rng, 0.2, 0.9, 2, placed, 90.0)
		if spot == null:
			ok = false
			break
		var cell := analysis.cell_at(spot as Vector2)
		if analysis.dist[cell.y * analysis.grid.cols + cell.x] < 0 or analysis.clearance_at(cell) < 2:
			ok = false
		placed.append(spot)
	_check(ok, "pick_spot solo da puntos alcanzables con holgura")
	var spaced := true
	for i: int in range(placed.size()):
		for j: int in range(i + 1, placed.size()):
			if (placed[i] as Vector2).distance_to(placed[j]) < 40.0:
				spaced = false
	_check(spaced, "los puntos elegidos no se amontonan")
	var late := analysis.pick_spot(_rng(1), 0.8, 1.0, 2, [], 0.0) as Vector2
	var early := analysis.pick_spot(_rng(1), 0.0, 0.1, 2, [], 0.0) as Vector2
	_check(analysis.path_fraction(analysis.cell_at(late)) > analysis.path_fraction(analysis.cell_at(early)), "t_min/t_max reparten por el camino de la entrada a la salida")
	_check(analysis.spawn_position().distance_to(analysis.exit_position()) > 600.0, "entrada y salida estan separadas")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
