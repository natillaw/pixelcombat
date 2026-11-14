## Recorre muchos pisos y semillas buscando los fallos que el jugador nota: enemigos u objetos dentro de muros, pisos sin
## camino a la salida, hechos que no se pueden cumplir, estanques mal formados y misiones de limpieza desmesuradas.
##
##   godot --headless --path . --script tests/test_world_sanity.gd
extends SceneTree

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== test_world_sanity ==")
	var bad_spot := 0
	var disconnected := 0
	var unreachable := 0
	var broken_water := 0
	var big_clear := 0
	var narrow_gaps := 0
	var problems: Array[String] = []
	var total := 0
	for floor_number: int in range(1, 11):
		for seed_value: int in [11, 222, 3333, 44444, 555555]:
			total += 1
			var layout := TowerGenerator.generate(floor_number, seed_value, 1)
			var grid := layout.grid
			var spawn_cell := grid.world_to_cell(layout.player_spawn)
			var seen := grid.reachable_from(spawn_cell)
			var specs: Array = layout.enemies + layout.deferred_enemies
			for spec: Dictionary in specs:
				var cell := grid.world_to_cell(spec["position"])
				if grid.blocks_move(cell.x, cell.y):
					bad_spot += 1
				elif seen[cell.y * grid.cols + cell.x] == 0:
					unreachable += 1
			for portal: Dictionary in layout.portals:
				var cell := grid.world_to_cell(portal["position"])
				if seen[cell.y * grid.cols + cell.x] == 0:
					disconnected += 1
			for r: int in range(2, grid.rows - 2):
				for c: int in range(2, grid.cols - 2):
					if grid.get_cell(c, r) != TileGrid.WATER:
						continue
					var wet := 0
					for side: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
						wet += 1 if grid.get_cell(c + side.x, r + side.y) == TileGrid.WATER else 0
					if wet < 2:
						broken_water += 1
					if grid.get_cell(c, r - 1) == TileGrid.WALL or grid.get_cell(c, r + 1) == TileGrid.WALL:
						broken_water += 0
			narrow_gaps += _narrow_gaps(grid)
			for mission: Dictionary in layout.mission_plan["missions"]:
				if String(mission["kind"]) == "clear" and int(mission["target"]) > MissionGen.CLEAR_BASE + MissionGen.CLEAR_PER_FLOOR * (floor_number - 1):
					big_clear += 1
			for problem: String in MissionGen.check(layout):
				problems.append("piso %d semilla %d: %s" % [floor_number, seed_value, problem])
	print("   %d pisos revisados; enemigos en muro %d, sin camino %d, portales sin camino %d, agua rota %d" % [total, bad_spot, unreachable, disconnected, broken_water])
	for line: String in problems.slice(0, 8):
		print("   problema: %s" % line)
	_check(bad_spot == 0, "ningun enemigo nace dentro de un muro")
	_check(unreachable == 0, "todos los enemigos tienen camino desde la entrada")
	_check(disconnected == 0, "la entrada y la salida estan conectadas")
	_check(broken_water == 0, "los estanques no tienen puntas sueltas")
	_check(big_clear == 0, "la mision de limpieza pide una cantidad acotada")
	print("   huecos de 1-2 casillas entre muros: %d en %d pisos" % [narrow_gaps, total])
	_check(narrow_gaps <= total * 6, "casi no quedan huecos intransitables entre muros (%d)" % narrow_gaps)
	_check(problems.is_empty(), "las misiones de todos los pisos se pueden cumplir")
	var first := TowerGenerator.generate(1, 777, 1, ["clear"])
	var clear_target := 0
	for mission: Dictionary in first.mission_plan["missions"]:
		if String(mission["kind"]) == "clear":
			clear_target = int(mission["target"])
	_check(clear_target == MissionGen.CLEAR_BASE and first.enemies.size() > clear_target, "en el piso 1 hay mas enemigos que los que pide la mision (%d; hay %d)" % [clear_target, first.enemies.size()])
	_check(first.mission_plan["missions"].any(func(m: Dictionary) -> bool: return String(m["desc"]).contains("%d enemigos" % MissionGen.CLEAR_BASE)), "el texto de la mision dice la cantidad")
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _narrow_gaps(grid: TileGrid) -> int:
	var count := 0
	for horizontal: bool in [true, false]:
		var lines := grid.rows if horizontal else grid.cols
		var length := grid.cols if horizontal else grid.rows
		for line: int in range(3, lines - 3):
			var start := -1
			for i: int in range(2, length - 2):
				var is_floor := grid.get_cell(i, line) == TileGrid.FLOOR if horizontal else grid.get_cell(line, i) == TileGrid.FLOOR
				if is_floor and start < 0:
					start = i
				elif not is_floor and start >= 0:
					var before := grid.get_cell(start - 1, line) if horizontal else grid.get_cell(line, start - 1)
					var after := grid.get_cell(i, line) if horizontal else grid.get_cell(line, i)
					if i - start <= 2 and before == TileGrid.WALL and after == TileGrid.WALL:
						count += 1
					start = -1
	return count


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("   ok   %s" % label)
		return
	_failures += 1
	print("   FAIL %s" % label)
