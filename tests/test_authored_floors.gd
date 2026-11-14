## Pisos hechos a mano (data/floors/): tamano, mapa, conexion, anclas, variacion por visita, aldeas y el piso 10.
## El generador procedural sigue disponible: AuthoredFloor.enabled = false los ignora.
extends SceneTree

var _checks: int = 0
var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("   %s %s" % ["ok  " if ok else "FAIL", label])


func _init() -> void:
	_test_files_and_maps()
	_test_content()
	_test_variation()
	_test_push_does_not_tunnel()
	_test_procedural_still_available()
	print("== %d checks, %d failed ==" % [_checks, _failures])
	print("RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)


func _test_files_and_maps() -> void:
	for floor_number: int in range(1, 11):
		_check(AuthoredFloor.has(floor_number), "el piso %d esta hecho a mano" % floor_number)
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		var grid := layout.grid
		_check(layout.style == "authored", "piso %d: se carga el mapa a mano" % floor_number)
		_check(grid.cols >= 80 and grid.cols <= 100 and grid.rows >= 56 and grid.rows <= 70, "piso %d: tamano %dx%d dentro de 80-100 x 56-70" % [floor_number, grid.cols, grid.rows])
		var seen := grid.reachable_from(grid.world_to_cell(layout.player_spawn))
		var exit_ok := false
		for portal: Dictionary in layout.portals:
			var cell := grid.world_to_cell(portal["position"])
			if String(portal["id"]) == "exit":
				exit_ok = seen[cell.y * grid.cols + cell.x] == 1
		_check(exit_ok, "piso %d: la salida es alcanzable desde la entrada" % floor_number)
		var unreachable := 0
		var in_wall := 0
		for spec: Dictionary in layout.enemies + layout.deferred_enemies:
			var cell := grid.world_to_cell(spec["position"])
			if grid.blocks_move(cell.x, cell.y):
				in_wall += 1
			elif seen[cell.y * grid.cols + cell.x] == 0:
				unreachable += 1
		for object: Dictionary in layout.interactables:
			var cell2 := grid.world_to_cell(object["position"])
			if seen[cell2.y * grid.cols + cell2.x] == 0:
				unreachable += 1
		_check(unreachable == 0 and in_wall == 0, "piso %d: enemigos y objetos en suelo alcanzable (muro %d, sin camino %d)" % [floor_number, in_wall, unreachable])
		_check(MissionGen.check(layout).is_empty(), "piso %d: las misiones se pueden cumplir %s" % [floor_number, str(MissionGen.check(layout))])
		var water := 0
		var cells := grid.cols * grid.rows
		for i: int in range(cells):
			water += 1 if grid.get_cell(i % grid.cols, i / grid.cols) == TileGrid.WATER else 0
		if floor_number in [2, 4, 8, 10]:
			_check(water > cells / 25, "piso %d: tiene rio o lago (%d %% de agua)" % [floor_number, water * 100 / cells])


func _test_content() -> void:
	var village_floors := []
	for floor_number: int in range(1, 11):
		var layout := TowerGenerator.generate(floor_number, 20261110, 1)
		if not layout.village.is_empty():
			village_floors.append(floor_number)
			var anchor: Vector2 = layout.authored_anchors["village"][0]
			_check(anchor.distance_to(layout.village["position"]) < 1.0, "piso %d: la aldea esta donde se diseno" % floor_number)
		var camps := layout.camps.filter(func(c: Dictionary) -> bool: return String(c["kind"]) == "camp").size()
		var packs := layout.camps.filter(func(c: Dictionary) -> bool: return String(c["kind"]) == "pack").size()
		_check(camps >= 3 and (floor_number == 1 or packs >= 2), "piso %d: %d campamentos y %d patrullas" % [floor_number, camps, packs])
	_check(village_floors == [2, 4, 6, 8], "las aldeas estan en los pisos 2, 4, 6 y 8 (%s)" % str(village_floors))
	var floor10 := TowerGenerator.generate(10, 20261110, 1)
	var boss: Dictionary = {}
	for spec: Dictionary in floor10.enemies:
		if String(spec.get("group", "")) == "boss":
			boss = spec
	_check(not boss.is_empty() and String(boss["id"]) == "bandit_garrick", "el piso 10 tiene a Garrick")
	var arena: Vector2 = floor10.authored_anchors["boss"][0]
	_check(boss["position"] == arena, "Garrick esta en el centro de la arena disenada")
	var stats := EnemyCatalog.enemy(&"bandit_garrick")
	_check(int(stats["stats"]["health"]) > 0 and (stats["phases"] as Array).size() >= 2, "las fases de Garrick no se han tocado (%d fases)" % (stats["phases"] as Array).size())


func _test_variation() -> void:
	var a := TowerGenerator.generate(3, 20261110, 1)
	var b := TowerGenerator.generate(3, 20261110, 1)
	_check(a.grid.cols == b.grid.cols and a.enemies.size() == b.enemies.size() and a.camps.size() == b.camps.size(), "la misma visita da el mismo piso")
	var chests := {}
	var positions := {}
	for visit: int in range(1, 9):
		var layout := TowerGenerator.generate(3, 20261110, visit)
		for object: Dictionary in layout.interactables:
			if String(object["kind"]) == "chest" and String(object.get("tier", "")) == "wood":
				chests[str(object["position"])] = true
		for spec: Dictionary in layout.enemies:
			if String(spec.get("behavior", "")) == "sleep":
				positions[str(spec["position"])] = true
	_check(chests.size() >= 2, "los cofres cambian de sitio entre visitas (%d sitios distintos)" % chests.size())
	_check(positions.size() >= 2, "los que duermen cambian entre visitas")
	var same_terrain := true
	for visit: int in range(1, 5):
		same_terrain = same_terrain and TowerGenerator.generate(5, 20261110, visit).grid.cols == TowerGenerator.generate(5, 99, 1).grid.cols
	_check(same_terrain, "el terreno es el mismo con cualquier semilla (piso a mano)")


func _test_push_does_not_tunnel() -> void:
	# Un empuje largo no debe dejar al personaje al otro lado de una fila fina de muros (quedaba en una bolsa cerrada).
	var world := CombatWorld.new(1)
	var cols := 20
	var rows := 9
	var grid := TileGrid.new(cols, rows, TileGrid.FLOOR)
	for r: int in range(rows):
		grid.set_cell(10, r, TileGrid.WALL)
	world.grid = grid
	world.bounds = Rect2(0, 0, cols * TileGrid.TILE, rows * TileGrid.TILE)
	var from := grid.cell_center(7, 4)
	var landed := world.swept_position(from, from + Vector2(260.0, 0.0), 14.0)
	_check(landed.x < 10.0 * TileGrid.TILE, "un empuje de 260 px no atraviesa un muro de una casilla (x=%.0f)" % landed.x)


func _test_procedural_still_available() -> void:
	AuthoredFloor.enabled = false
	var procedural := TowerGenerator.generate(2, 20261110, 1)
	_check(procedural.style != "authored" and procedural.grid.cols >= 120, "con los pisos a mano desactivados el generador procedural sigue funcionando (%dx%d)" % [procedural.grid.cols, procedural.grid.rows])
	_check(MissionGen.check(procedural).is_empty(), "y sus misiones se pueden cumplir")
	AuthoredFloor.enabled = true
